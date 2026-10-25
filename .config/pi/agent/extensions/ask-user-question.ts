/**
 * ask-user-question.ts — Let the model ask you instead of guessing.
 *
 * Single-file port of @juicesharp/rpiv-ask-user-question (v2.4.0), rebuilt
 * for a plain pi-extension workflow: no npm package, no config file, no
 * lazy-loading / i18n / RPC machinery. Drops those, keeps the useful core:
 *
 *   • ask_user_question tool — up to 4 questions, 2–4 options each
 *   • single-select, multi-select (space toggles, Next commits), and a
 *     "Type something." free-text row on every question
 *   • optional markdown preview per option (side-by-side on wide terminals)
 *   • notes per question via `n` (travel back with the answer)
 *   • Submit review tab when several questions are asked at once
 *   • ctrl+] collapses the overlay to read the transcript, Esc abandons
 *   • same result envelope back to the model: "Q"="A", preview, notes
 *   • while the questionnaire is open, the herdr pane is reported as
 *     "blocked" (emits herdr:blocked on the shared extension event bus)
 *
 * Keys: ↑↓/jk move · ↵ select · tab next question · space toggle (multi) ·
 *       n note · ctrl+] hide · esc abandon · shift+↵ newline while typing
 *
 * Command: /askq — opens the same dialog with sample questions (test drive).
 *
 * Place in ~/.config/pi/agent/extensions/ and run /reload (or restart pi).
 */

import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import {
	Editor,
	Text,
	matchesKey,
	truncateToWidth,
	visibleWidth,
	wrapTextWithAnsi,
	type TUI,
} from "@earendil-works/pi-tui";
import { Type, type Static } from "typebox";

/**
 * pi-tui's truncateToWidth may return a string OR a string[] (multi-line
 * truncation of ANSI/non-ASCII content). Normalize to a single line so we
 * never leak an array into the line buffer — pi's overlay compositor calls
 * visibleWidth() on every rendered line and crashes on non-strings.
 */
function truncate(text: string, maxWidth: number): string {
	const r = truncateToWidth(text, maxWidth);
	return Array.isArray(r) ? (r[0] ?? "") : r;
}

// ── Limits (mirror the original) ───────────────────────────────────────

const MAX_QUESTIONS = 4;
const MIN_OPTIONS = 2;
const MAX_OPTIONS = 4;
const MAX_HEADER_LENGTH = 16;
const MAX_LABEL_LENGTH = 60;

const TYPE_LABEL = "Type something.";
const NEXT_LABEL = "Next";
const RESERVED_LABELS = ["Other", TYPE_LABEL, NEXT_LABEL] as const;

const DECLINE_MESSAGE = "User declined to answer questions";
const ENVELOPE_PREFIX = "User has answered your questions:";
const ENVELOPE_SUFFIX = "You can now continue with the user's answers in mind.";

const ERROR_NO_UI =
	"Error: UI not available (running in non-interactive mode)";
const ERROR_NO_CUSTOM_UI =
	"Error: this client cannot render the questionnaire (custom UI is unavailable, e.g. RPC/ACP hosts). The user never saw the questions — do NOT treat this as a decline. Ask the questions as plain chat text instead, without using this tool.";

// ── Tool schema ────────────────────────────────────────────────────────

const OptionSchema = Type.Object({
	label: Type.String({
		maxLength: MAX_LABEL_LENGTH,
		description: `MAX ${MAX_LABEL_LENGTH} CHARACTERS — hard limit, requests over the limit are rejected. The display text for this option that the user will see and select. Should be concise (1-5 words) and clearly describe the choice.`,
	}),
	description: Type.String({
		description:
			"Explanation of what this option means or what will happen if chosen. Useful for providing context about trade-offs or implications.",
	}),
	preview: Type.Optional(
		Type.String({
			description:
				"Optional preview content rendered when this option is focused. Use for mockups, code snippets, or visual comparisons that help users compare options. Single-select only.",
		}),
	),
});

const QuestionSchema = Type.Object({
	question: Type.String({
		description:
			'The complete question to ask the user. Should be clear, specific, and end with a question mark. Example: "Which library should we use for date formatting?" If multiSelect is true, phrase it accordingly, e.g. "Which features do you want to enable?"',
	}),
	header: Type.String({
		maxLength: MAX_HEADER_LENGTH,
		description: `MAX ${MAX_HEADER_LENGTH} CHARACTERS — hard limit. Very short chip/tag shown next to the question. Examples: "Auth method", "Library", "Approach".`,
	}),
	options: Type.Array(OptionSchema, {
		minItems: MIN_OPTIONS,
		maxItems: MAX_OPTIONS,
		description:
			"The available choices for this question. Must have 2-4 options. Each option should be a distinct, mutually exclusive choice (unless multiSelect is enabled). The 'Type something.' row is appended automatically — do NOT author it.",
	}),
	multiSelect: Type.Optional(
		Type.Boolean({
			default: false,
			description:
				"Set to true to allow the user to select multiple options instead of just one. Use when choices are not mutually exclusive.",
		}),
	),
});

const QuestionParamsSchema = Type.Object({
	questions: Type.Array(QuestionSchema, {
		minItems: 1,
		maxItems: MAX_QUESTIONS,
		description: "Questions to ask the user (1-4 questions)",
	}),
});

type OptionData = Static<typeof OptionSchema>;
type QuestionData = Static<typeof QuestionSchema>;
type QuestionParams = Static<typeof QuestionParamsSchema>;

// ── Answer / result types ──────────────────────────────────────────────

interface QuestionAnswer {
	questionIndex: number;
	question: string;
	kind: "option" | "custom" | "multi";
	answer: string | null;
	selected?: string[];
	notes?: string;
	preview?: string;
}

interface QuestionnaireResult {
	answers: QuestionAnswer[];
	cancelled: boolean;
	error?: string;
}

// ── Validation (same guards and messages as the original) ──────────────

type ValidationResult = { ok: true } | { ok: false; error: string; message: string };

const RESERVED_LABEL_SET: ReadonlySet<string> = new Set(RESERVED_LABELS);

function validateQuestionnaire(typed: QuestionParams): ValidationResult {
	if (typed.questions.length === 0) {
		return { ok: false, error: "no_questions", message: "Error: At least one question is required" };
	}
	if (typed.questions.length > MAX_QUESTIONS) {
		return {
			ok: false,
			error: "too_many_questions",
			message: `Error: At most ${MAX_QUESTIONS} questions are allowed per invocation`,
		};
	}
	const seenQuestions = new Set<string>();
	for (const q of typed.questions) {
		if (seenQuestions.has(q.question)) {
			return { ok: false, error: "duplicate_question", message: "Error: Question text must be unique within an invocation" };
		}
		seenQuestions.add(q.question);
	}
	for (const q of typed.questions) {
		if (q.options.length < MIN_OPTIONS) {
			return {
				ok: false,
				error: "empty_options",
				message: `Error: Each question requires at least ${MIN_OPTIONS} options`,
			};
		}
		const seenLabels = new Set<string>();
		for (const o of q.options) {
			if (RESERVED_LABEL_SET.has(o.label)) {
				return {
					ok: false,
					error: "reserved_label",
					message: `Error: Option label is reserved (${RESERVED_LABELS.join(", ")})`,
				};
			}
			if (seenLabels.has(o.label)) {
				return {
					ok: false,
					error: "duplicate_option_label",
					message: "Error: Option labels must be unique within a question",
				};
			}
			seenLabels.add(o.label);
		}
	}
	return { ok: true };
}

// ── Result envelope back to the model ──────────────────────────────────

function buildAnswerSegment(a: QuestionAnswer): string {
	const value = a.kind === "multi" ? (a.selected ?? []).join(", ") : (a.answer ?? "");
	const parts: string[] = [`"${a.question}"="${value}"`];
	if (a.preview && a.preview.length > 0) parts.push(`selected preview: ${a.preview}`);
	if (a.notes && a.notes.length > 0) parts.push(`user notes: ${a.notes}`);
	return `${parts.join(". ")}.`;
}

function buildEnvelope(result: QuestionnaireResult, questions: QuestionData[]) {
	if (result.cancelled) {
		return buildToolResult(DECLINE_MESSAGE, result);
	}
	const segments: string[] = [];
	for (let i = 0; i < questions.length; i++) {
		const a = result.answers.find((x) => x.questionIndex === i);
		if (a) segments.push(buildAnswerSegment(a));
	}
	if (segments.length === 0) {
		return buildToolResult(DECLINE_MESSAGE, { ...result, cancelled: true });
	}
	return buildToolResult(`${ENVELOPE_PREFIX} ${segments.join(" ")} ${ENVELOPE_SUFFIX}`, result);
}

function buildToolResult(text: string, details: QuestionnaireResult) {
	return {
		content: [{ type: "text" as const, text }],
		details,
	};
}

// ── TUI questionnaire component ────────────────────────────────────────

interface Row {
	kind: "option" | "type" | "next";
	optionIndex?: number;
}

function rowsForQuestion(q: QuestionData): Row[] {
	const rows: Row[] = q.options.map((_o, i) => ({ kind: "option", optionIndex: i }));
	rows.push({ kind: "type" });
	if (q.multiSelect) rows.push({ kind: "next" });
	return rows;
}

const editorThemeFor = (theme: Theme) => ({
	borderColor: (s: string) => theme.fg("borderMuted", s),
	selectList: {
		selectedPrefix: (t: string) => theme.fg("accent", t),
		selectedText: (t: string) => theme.fg("accent", t),
		description: (t: string) => theme.fg("dim", t),
		scrollInfo: (t: string) => theme.fg("dim", t),
		noMatch: (t: string) => theme.fg("warning", t),
	},
});

class QuestionnaireComponent {
	private readonly questions: QuestionData[];
	private readonly theme: Theme;
	private readonly tui: TUI;
	private readonly onDone: (result: QuestionnaireResult) => void;

	// tabs 0..n-1 are questions, tab === n is the submit review screen
	private tab = 0;
	private idx = 0;
	private typeMode = false;
	private notesMode = false;
	private collapsed = false;

	private readonly answers = new Map<number, QuestionAnswer>();
	private readonly checked = new Map<number, Set<number>>();
	private readonly notes = new Map<number, string>();
	private readonly typeEditor: Editor;
	private readonly notesEditor: Editor;

	private cacheW?: number;
	private cacheLines?: string[];

	constructor(opts: { questions: QuestionData[]; theme: Theme; tui: TUI; onDone: (r: QuestionnaireResult) => void }) {
		this.questions = opts.questions;
		this.theme = opts.theme;
		this.tui = opts.tui;
		this.onDone = opts.onDone;
		const et = editorThemeFor(opts.theme);
		this.typeEditor = new Editor(opts.tui, et);
		this.notesEditor = new Editor(opts.tui, et);
	}

	get n(): number {
		return this.questions.length;
	}

	// ── input routing ──────────────────────────────────────────────────

	handleInput(data: string): void {
		if (this.collapsed) {
			if (matchesKey(data, "ctrl+]" as never)) this.collapsed = false;
			this.invalidate();
			return;
		}
		if (this.typeMode) this.handleTypeInput(data);
		else if (this.notesMode) this.handleNotesInput(data);
		else this.handleListInput(data);
		this.invalidate();
		this.tui.requestRender();
	}

	private handleListInput(data: string): void {
		if (this.tab >= this.n) {
			this.handleSubmitInput(data);
			return;
		}
		const q = this.questions[this.tab];
		const rows = rowsForQuestion(q);
		const multi = !!q.multiSelect;
		const last = rows.length - 1;

		if (data === "k" || matchesKey(data, "up")) {
			this.idx = this.idx <= 0 ? last : this.idx - 1;
			return;
		}
		if (data === "j" || matchesKey(data, "down")) {
			this.idx = this.idx >= last ? 0 : this.idx + 1;
			return;
		}
		if (matchesKey(data, "tab")) {
			this.goNextTab();
			return;
		}
		if (matchesKey(data, "shift+tab" as never)) {
			this.goPrevTab();
			return;
		}
		if (matchesKey(data, "ctrl+]" as never)) {
			this.collapsed = true;
			return;
		}
		if (matchesKey(data, "escape") || data === "\x1b" || matchesKey(data, "ctrl+c")) {
			this.cancel();
			return;
		}
		if (matchesKey(data, "n")) {
			this.startNotes();
			return;
		}

		const row = rows[this.idx];
		if (matchesKey(data, "space") || data === " ") {
			if (multi && row.kind === "option") this.toggleChecked(row.optionIndex!);
			return;
		}
		if (data === "\r" || data === "\n" || matchesKey(data, "enter")) {
			if (row.kind === "option") {
				if (multi) this.toggleChecked(row.optionIndex!);
				else this.commitOption(row.optionIndex!);
			} else if (row.kind === "type") {
				this.startTypeMode();
			} else if (row.kind === "next") {
				this.commitMulti();
			}
		}
	}

	private handleSubmitInput(data: string): void {
		const last = this.n; // rows: [0]=Submit answers, 1..n = questions
		if (data === "k" || matchesKey(data, "up")) {
			this.idx = this.idx <= 0 ? last : this.idx - 1;
			return;
		}
		if (data === "j" || matchesKey(data, "down")) {
			this.idx = this.idx >= last ? 0 : this.idx + 1;
			return;
		}
		if (data === "\r" || data === "\n" || matchesKey(data, "enter")) {
			if (this.idx === 0) this.finish();
			else {
				this.tab = this.idx - 1;
				this.idx = 0;
			}
			return;
		}
		if (matchesKey(data, "escape") || data === "\x1b" || matchesKey(data, "ctrl+c")) {
			this.cancel();
			return;
		}
		if (matchesKey(data, "ctrl+]" as never)) this.collapsed = true;
	}

	private handleTypeInput(data: string): void {
		if (data === "\r" || data === "\n" || matchesKey(data, "enter")) {
			this.commitType();
			return;
		}
		if (matchesKey(data, "escape") || data === "\x1b") {
			this.exitTypeMode();
			return;
		}
		this.typeEditor.handleInput(data); // shift+↵ newline, paste, undo all flow through
	}

	private handleNotesInput(data: string): void {
		if (data === "\r" || data === "\n" || matchesKey(data, "enter")) {
			this.saveNotes();
			return;
		}
		if (matchesKey(data, "escape") || data === "\x1b") {
			this.notesMode = false;
			this.notesEditor.focused = false;
			return;
		}
		this.notesEditor.handleInput(data);
	}

	// ── state transitions ──────────────────────────────────────────────

	private goNextTab(): void {
		if (this.tab < this.n) {
			this.tab++;
			this.idx = 0;
		}
	}

	private goPrevTab(): void {
		if (this.tab > 0) {
			this.tab--;
			this.idx = 0;
		}
	}

	private commitOption(i: number): void {
		const q = this.questions[this.tab];
		const o = q.options[i];
		this.answers.set(this.tab, {
			questionIndex: this.tab,
			question: q.question,
			kind: "option",
			answer: o.label,
			preview: o.preview,
		});
		this.goNextTab();
	}

	private toggleChecked(i: number): void {
		let s = this.checked.get(this.tab);
		if (!s) {
			s = new Set();
			this.checked.set(this.tab, s);
		}
		if (s.has(i)) s.delete(i);
		else s.add(i);
	}

	private commitMulti(): void {
		const q = this.questions[this.tab];
		const s = this.checked.get(this.tab) ?? new Set<number>();
		const selected = q.options.filter((_o, i) => s.has(i)).map((o) => o.label);
		this.answers.set(this.tab, {
			questionIndex: this.tab,
			question: q.question,
			kind: "multi",
			answer: null,
			selected,
		});
		this.goNextTab();
	}

	private startTypeMode(): void {
		this.typeMode = true;
		this.typeEditor.focused = true;
	}

	private exitTypeMode(): void {
		this.typeMode = false;
		this.typeEditor.focused = false;
	}

	private commitType(): void {
		const text = this.typeEditor.getText();
		if (!text.trim()) {
			this.exitTypeMode(); // empty custom answer is not an answer
			return;
		}
		const q = this.questions[this.tab];
		this.answers.set(this.tab, {
			questionIndex: this.tab,
			question: q.question,
			kind: "custom",
			answer: text,
		});
		this.exitTypeMode();
		this.goNextTab();
	}

	private startNotes(): void {
		this.notesEditor.setText(this.notes.get(this.tab) ?? "");
		this.notesMode = true;
		this.notesEditor.focused = true;
	}

	private saveNotes(): void {
		this.notes.set(this.tab, this.notesEditor.getText());
		this.notesMode = false;
		this.notesEditor.focused = false;
	}

	private collectAnswers(): QuestionAnswer[] {
		const out: QuestionAnswer[] = [];
		for (let i = 0; i < this.n; i++) {
			const a = this.answers.get(i);
			if (!a) continue;
			const note = this.notes.get(i);
			out.push({ ...a, question: this.questions[i].question, ...(note ? { notes: note } : {}) });
		}
		return out;
	}

	private finish(): void {
		this.onDone({ answers: this.collectAnswers(), cancelled: false });
	}

	private cancel(): void {
		this.onDone({ answers: this.collectAnswers(), cancelled: true });
	}

	// ── rendering ──────────────────────────────────────────────────────

	invalidate(): void {
		this.cacheW = undefined;
		this.cacheLines = undefined;
	}

	render(width: number): string[] {
		if (this.cacheLines && this.cacheW === width) return this.cacheLines;
		const th = this.theme;
		const lines: string[] = [];

		if (this.collapsed) {
			lines.push(th.fg("dim", ` ask_user_question hidden — press ctrl+] to reopen `));
		} else if (this.typeMode) {
			lines.push(th.fg("dim", " Free-text answer — ↵ submits · shift+↵ newline · esc back "));
			lines.push(...this.typeEditor.render(Math.max(20, width - 4)).map((l) => "  " + l));
		} else if (this.notesMode) {
			lines.push(th.fg("dim", " Note on this question — ↵ saves · shift+↵ newline · esc cancels "));
			lines.push(...this.notesEditor.render(Math.max(20, width - 4)).map((l) => "  " + l));
		} else if (this.tab >= this.n) {
			lines.push(...this.renderSubmit(width));
		} else {
			lines.push(...this.renderQuestionTab(width));
		}

		this.cacheW = width;
		this.cacheLines = lines;
		return lines;
	}

	private renderQuestionTab(width: number): string[] {
		const th = this.theme;
		const q = this.questions[this.tab];
		const lines: string[] = [];

		const head = ` Question ${this.tab + 1}/${this.n} ${q.header ? `[${q.header}]` : ""} `;
		lines.push(
			th.fg("borderMuted", "─".repeat(3)) +
				th.fg("accent", head.trim()) +
				" " +
				th.fg("borderMuted", "─".repeat(Math.max(0, width - visibleWidth(head) - 7))),
		);
		if (this.n > 1) lines.push(...this.renderTabs(width));
		lines.push("");
		for (const l of wrapTextWithAnsi(q.question, Math.max(10, width - 2))) {
			lines.push(`  ${th.fg("text", th.bold(l))}`);
		}
		lines.push("");

		const multi = !!q.multiSelect;
		const rows = rowsForQuestion(q);
		const focused = rows[this.idx];
		const previewOption = !multi && focused.kind === "option" ? q.options[focused.optionIndex!] : undefined;
		const hasPreview = !!previewOption?.preview;

		const sideBySide = width >= 100 && hasPreview;
		const leftW = sideBySide ? Math.max(40, Math.floor(width * 0.45)) : width;

		if (sideBySide) {
			const rightW = width - leftW - 1;
			const left = this.renderOptionList(leftW, q, rows, multi);
			const right = this.renderPreviewBox(previewOption!.preview!, rightW);
			lines.push(...this.zipSideBySide(left, right, leftW, rightW));
		} else {
			lines.push(...this.renderOptionList(leftW, q, rows, multi));
			if (hasPreview) lines.push(...this.renderPreviewBox(previewOption!.preview!, leftW));
		}

		const note = this.notes.get(this.tab);
		if (note) {
			lines.push("");
			lines.push(`  ${th.fg("muted", "✎ note:")} ${th.fg("dim", note.split("\n")[0])}`);
		}
		lines.push("");
		lines.push(`  ${th.fg("dim", this.hintLine(multi))}`);
		return lines;
	}

	private renderTabs(width: number): string[] {
		const th = this.theme;
		let s = "  ";
		for (let i = 0; i < this.n; i++) {
			const answered = this.answers.has(i);
			const cur = i === this.tab;
			const label = `[${i + 1}${answered ? "✓" : ""}]`;
			s += cur ? th.fg("accent", th.bold(label)) : answered ? th.fg("success", label) : th.fg("muted", label);
			s += " ";
		}
		const allAnswered = this.n > 0 && this.answers.size >= this.n;
		const submitLabel = `[Submit${allAnswered ? "✓" : ""}]`;
		s += this.tab >= this.n ? th.fg("accent", th.bold(submitLabel)) : allAnswered ? th.fg("success", submitLabel) : th.fg("muted", submitLabel);
		return [truncate(s, width)];
	}

	private renderOptionList(width: number, q: QuestionData, rows: Row[], multi: boolean): string[] {
		const th = this.theme;
		const lines: string[] = [];
		const checked = this.checked.get(this.tab) ?? new Set<number>();
		const customAnswer = this.answers.get(this.tab);

		for (let r = 0; r < rows.length; r++) {
			const row = rows[r];
			const focused = r === this.idx;
			const prefix = focused ? th.fg("accent", "▸") : " ";

			if (row.kind === "option") {
				const o = q.options[row.optionIndex!];
				const mark = multi
					? (checked.has(row.optionIndex!) ? th.fg("success", "✓") : th.fg("dim", "○")) + " "
					: "";
				const label = focused ? th.fg("accent", th.bold(o.label)) : th.fg("text", o.label);
				lines.push(`  ${prefix} ${mark}${label}`);
				if (o.description) {
					for (const dl of wrapTextWithAnsi(o.description, Math.max(10, width - 6)).slice(0, 2)) {
						lines.push(`     ${th.fg("dim", dl)}`);
					}
				}
			} else if (row.kind === "type") {
				const label = focused ? th.fg("accent", th.bold(TYPE_LABEL)) : th.fg("muted", TYPE_LABEL);
				lines.push(`  ${prefix} ${label}`);
				if (customAnswer?.kind === "custom") {
					for (const l of wrapTextWithAnsi(customAnswer.answer ?? "", Math.max(10, width - 6)).slice(0, 2)) {
						lines.push(`     ${th.fg("dim", "↳ " + l)}`);
					}
				}
			} else if (row.kind === "next") {
				const label = focused ? th.fg("accent", th.bold(NEXT_LABEL)) : th.fg("muted", NEXT_LABEL);
				lines.push(`  ${prefix} ${label} ${th.fg("dim", "(commits this question)")}`);
			}

			if (r < rows.length - 1) lines.push("");
		}
		return lines;
	}

	private renderPreviewBox(content: string, width: number): string[] {
		const th = this.theme;
		const w = Math.max(14, width);
		const top =
			th.fg("borderMuted", "┌─ Preview ") + th.fg("borderMuted", "─".repeat(Math.max(0, w - 12)) + "┐");
		const inner = Math.max(4, w - 4);
		const body = content
			.split("\n")
			.flatMap((line) => wrapTextWithAnsi(line, inner))
			.slice(0, 14)
			.map((l) => th.fg("borderMuted", "│") + " " + l + " ".repeat(Math.max(0, inner - visibleWidth(l))) + th.fg("borderMuted", "│"));
		const bottom = th.fg("borderMuted", "└" + "─".repeat(Math.max(0, w - 2)) + "┘");
		return [top, ...body, bottom];
	}

	private zipSideBySide(left: string[], right: string[], leftW: number, rightW: number): string[] {
		const th = this.theme;
		const h = Math.max(left.length, right.length);
		const out: string[] = [];
		for (let i = 0; i < h; i++) {
			const l = left[i] ?? "";
			const r = right[i] ?? "";
			out.push(l + " ".repeat(Math.max(0, leftW - visibleWidth(l))) + th.fg("borderMuted", "│") + r);
		}
		return out;
	}

	private renderSubmit(width: number): string[] {
		const th = this.theme;
		const lines: string[] = [];

		const head = " Review & submit ";
		lines.push(
			th.fg("borderMuted", "─".repeat(3)) +
				th.fg("accent", head.trim()) +
				" " +
				th.fg("borderMuted", "─".repeat(Math.max(0, width - visibleWidth(head) - 7))),
		);
		lines.push("");

		const allAnswered = this.answers.size >= this.n;
		for (let i = 0; i <= this.n; i++) {
			const focused = i === this.idx;
			const prefix = focused ? th.fg("accent", "▸") : " ";
			if (i === 0) {
				const label = th.fg(allAnswered ? "success" : "accent", th.bold("Submit answers"));
				lines.push(`  ${prefix} ${label}${allAnswered ? th.fg("success", " ✓") : th.fg("dim", " (some questions unanswered)")}`);
			} else {
				const qi = i - 1;
				const q = this.questions[qi];
				const short = q.header ? `${i}. ${q.header}` : `${i}. ${q.question}`;
				lines.push(`  ${prefix} ${focused ? th.fg("accent", truncate(short, Math.max(10, width - 6))) : th.fg("text", truncate(short, Math.max(10, width - 6)))}`);
				const a = this.answers.get(qi);
				if (a) {
					const value = a.kind === "multi" ? (a.selected ?? []).join(", ") : (a.answer ?? "");
					lines.push(`     ${th.fg("success", "→")} ${th.fg("text", truncate(value, Math.max(10, width - 10)))}`);
					if (a.notes) lines.push(`     ${th.fg("dim", "✎ " + a.notes.split("\n")[0])}`);
				} else {
					lines.push(`     ${th.fg("dim", "— no answer yet")}`);
				}
			}
			if (i < this.n) lines.push("");
		}

		lines.push("");
		lines.push(`  ${th.fg("dim", "↑↓/jk move · ↵ submit · esc abandon")}`);
		return lines;
	}

	private hintLine(multi: boolean): string {
		if (multi) return "↑↓/jk move · space/↵ toggle · Next ↵ commits · tab next · n note · ctrl+] hide · esc abandon";
		return "↑↓/jk move · ↵ select · tab next · n note · ctrl+] hide · esc abandon";
	}
}

// ── Open the dialog ────────────────────────────────────────────────────

function askInTui(
	ctx: ExtensionContext,
	questions: QuestionData[],
	hooks?: { onOpen?: () => void; onClose?: () => void },
): Promise<QuestionnaireResult> {
	hooks?.onOpen?.();
	return ctx.ui.custom<QuestionnaireResult>(
		(tui, theme, _kb, done) => {
			const comp = new QuestionnaireComponent({
				questions,
				theme,
				tui,
				onDone: (result) => {
					hooks?.onClose?.();
					done(result);
				},
			});
			return {
				render: (w: number) => comp.render(w),
				invalidate: () => comp.invalidate(),
				handleInput: (d: string) => comp.handleInput(d),
			};
		},
		{
			overlay: true,
			overlayOptions: {
				anchor: "bottom-center",
				width: "100%",
				maxHeight: "100%",
				margin: { left: 0, right: 0, bottom: 0 },
			},
		},
	).finally(() => {
		// Safety net: always run onClose (finish, cancel, thrown errors).
		hooks?.onClose?.();
	}) as Promise<QuestionnaireResult>;
}

// ── Extension entry ────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
	// ── herdr pane state ──────────────────────────────────────────────────
	// While the questionnaire is open, hold the herdr pane in "blocked" so
	// herdr shows it as blocked until the user answers. Mirrors
	// herdr-permission-bridge.ts: herdr increments its blocked count on every
	// {active:true} and decrements on every {active:false}, so emit only on
	// 0→1 / 1→0 transitions to keep overlapping dialogs from wedging the count.
	const herdrBus = pi.events;
	let herdrBlockedCount = 0;
	function emitHerdrBlocked(active: boolean, label?: string): void {
		try {
			herdrBus?.emit?.("herdr:blocked", { active, label: active ? label : undefined });
		} catch {
			/* herdr not connected — ignore */
		}
	}
	function acquireHerdrBlock(label: string): void {
		if (herdrBlockedCount === 0) emitHerdrBlocked(true, label);
		herdrBlockedCount += 1;
	}
	function releaseHerdrBlock(): void {
		if (herdrBlockedCount === 0) return;
		herdrBlockedCount -= 1;
		if (herdrBlockedCount === 0) emitHerdrBlocked(false);
	}
	function questionHooks(questions: QuestionData[]) {
		const label = questions[0]?.header
			? `Waiting for answer: ${questions[0].header}`
			: "Waiting for question answers";
		return {
			onOpen: () => acquireHerdrBlock(label),
			onClose: () => releaseHerdrBlock(),
		};
	}

	pi.on("session_shutdown", () => {
		// Safety: never leak a blocked pane across sessions
		if (herdrBlockedCount > 0) {
			herdrBlockedCount = 0;
			emitHerdrBlocked(false);
		}
	});

	pi.registerTool({
		name: "ask_user_question",
		label: "Ask User Question",
		description: `Ask the user one or more structured questions during execution. Use when you need to:
1. Gather user preferences or requirements
2. Clarify ambiguous instructions
3. Get decisions on implementation choices as you work
4. Offer choices to the user about what direction to take

Usage notes:
- Users can type a custom answer via the automatically appended "Type something." row on every question or press Esc to abandon the questionnaire. Do NOT author "Other" or "Type something." labels yourself — reserved labels are rejected at runtime.
- Use multiSelect: true when multiple answers are valid. The "Type something." row is available on every question, including when options carry a preview; in preview mode it expands to the full pane width while typing so the custom answer is not cramped into the narrow options column.
- If you recommend a specific option, make that the first option in the list and add "(Recommended)" at the end of the label.

Preview feature:
Use the optional preview field on options when presenting concrete artifacts that users need to visually compare:
- ASCII mockups of UI layouts or components
- Code snippets showing different implementations
- Diagram variations
- Configuration examples

Preview content is rendered as markdown in a monospace box. Multi-line text with newlines is supported. When any option has a preview, the UI switches to a side-by-side layout with a vertical option list on the left and preview on the right. Do not use previews for simple preference questions where labels and descriptions suffice. Note: previews are only supported for single-select questions (not multiSelect).`,
		promptSnippet: `Ask the user up to ${MAX_QUESTIONS} structured questions (${MIN_OPTIONS}-${MAX_OPTIONS} options each) when requirements are ambiguous`,
		promptGuidelines: [
			`Use ask_user_question whenever the user's request is underspecified and you cannot proceed without concrete decisions — you can ask up to ${MAX_QUESTIONS} questions per invocation.`,
			`Each question MUST have ${MIN_OPTIONS}-${MAX_OPTIONS} options. Every option requires a concise label (1-5 words) and a description explaining what the choice means or its trade-offs. The user can additionally type a custom answer via the automatically appended "Type something." row on every question, or press Esc to abandon the questionnaire. Do NOT author "Other" or "Type something." labels yourself — reserved labels are rejected at runtime.`,
			`Set multiSelect: true when multiple answers are valid. Provide an options[].preview markdown string when an option benefits from richer side-by-side context (mockups, code snippets, diagrams, configs) — single-select only. If you recommend a specific option, make that the first option and append "(Recommended)" to its label.`,
			"Do not stack multiple ask_user_question calls back-to-back — group all clarifying questions into one invocation.",
		],
		parameters: QuestionParamsSchema,

		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const typed = params as unknown as QuestionParams;
			if (!ctx.hasUI) {
				return buildToolResult(ERROR_NO_UI, { answers: [], cancelled: true, error: "no_ui" });
			}
			const validation = validateQuestionnaire(typed);
			if (!validation.ok) {
				return buildToolResult(validation.message, { answers: [], cancelled: true, error: validation.error });
			}
			try {
				const result = await askInTui(ctx, typed.questions, questionHooks(typed.questions));
				if (result === undefined) {
					return buildToolResult(ERROR_NO_CUSTOM_UI, { answers: [], cancelled: true, error: "no_custom_ui" });
				}
				return buildEnvelope(result, typed.questions);
			} catch {
				return buildToolResult(ERROR_NO_CUSTOM_UI, { answers: [], cancelled: true, error: "no_custom_ui" });
			}
		},

		renderCall(args, theme, _context) {
			const questions = (args as { questions?: unknown[] }).questions ?? [];
			const multi = questions.some((q) => !!(q as { multiSelect?: boolean }).multiSelect);
			return new Text(
				theme.fg("toolTitle", theme.bold("ask_user_question ")) +
					theme.fg("muted", `${questions.length} question${questions.length === 1 ? "" : "s"}${multi ? " · multi" : ""}`),
				0,
				0,
			);
		},

		renderResult(result, { expanded }, theme, _context) {
			const details = result.details as QuestionnaireResult | undefined;
			const answers = details?.answers ?? [];
			if (details?.cancelled) return new Text(theme.fg("warning", "⤫ User declined"), 0, 0);
			if (answers.length === 0) return new Text(theme.fg("dim", "No answers"), 0, 0);
			if (!expanded) return new Text(theme.fg("success", "✓ ") + theme.fg("muted", `${answers.length} answered`), 0, 0);
			let t = "";
			for (const a of answers) {
				const value = a.kind === "multi" ? (a.selected ?? []).join(", ") : (a.answer ?? "");
				t += `${theme.fg("accent", `"${a.question}"`)} = ${theme.fg("muted", truncate(value, 60))}`;
				if (a.notes) t += ` ${theme.fg("dim", `(✎ ${a.notes.split("\n")[0]})`)}`;
				t += "\n";
			}
			return new Text(t.trimEnd(), 0, 0);
		},
	});

	// /askq — test-drive the dialog without involving the model
	pi.registerCommand("askq", {
		description: "Test the ask_user_question dialog with sample questions",
		handler: async (_args, ctx) => {
			if (ctx.mode !== "tui") {
				ctx.ui.notify("/askq requires interactive mode", "error");
				return;
			}
			const sample: QuestionData[] = [
				{
					question: "Which caching strategy should we use for the API client?",
					header: "Cache",
					options: [
						{
							label: "Redis (Recommended)",
							description: "In-memory store with TTLs; needs a running Redis instance.",
							preview: "GET /users\n  cache lookup (TTL 60s)\n  hit  -> respond\n  miss -> DB -> cache",
						},
						{
							label: "In-process LRU",
							description: "Zero infrastructure, single node only, lost on restart.",
							preview: "const cache = new LRU({ max: 1000, ttl: 60_000 })",
						},
						{
							label: "HTTP cache headers",
							description: "Leverages CDN/browser caching; no server state.",
							preview: "Cache-Control: public, max-age=60",
						},
					],
				},
				{
					question: "Which features should we enable?",
					header: "Features",
					multiSelect: true,
					options: [
						{ label: "Metrics", description: "Expose a Prometheus /metrics endpoint." },
						{ label: "Circuit breaker", description: "Fail fast when the upstream is down." },
						{ label: "Retries", description: "Idempotent retry with backoff." },
					],
				},
			];
			const result = await askInTui(ctx, sample, questionHooks(sample));
			if (result.cancelled) {
				ctx.ui.notify("Questionnaire abandoned", "warning");
				return;
			}
			const summary = result.answers
				.map((a) => `${a.question} → ${a.kind === "multi" ? (a.selected ?? []).join(", ") : a.answer}${a.notes ? ` (✎ ${a.notes})` : ""}`)
				.join("\n");
			ctx.ui.notify(`Answers:\n${summary}`, "info");
		},
	});
}
