/**
 * Session Switcher & Theme Switcher Extension
 *
 * Features:
 *   - Ctrl+X then S — open session picker and switch (questionnaire-style overlay)
 *   - Ctrl+X then T — open theme picker and switch (questionnaire-style overlay)
 *   - Ctrl+X then K — show all keymaps (overlay UI)
 *   - /sessions     — list sessions, switch, rename (r), delete (d, with confirm), and
 *                     start a new session (n)
 *   - /theme        — list themes and switch
 *   - /keymaps      — show all keybindings
 *
 * UI mirrors the ask_user_question questionnaire: a centered box with a
 * `─── title (count) ───` header, a ▸ option list with dim descriptions
 * (j/k to navigate), an inline editor for renaming sessions (r or the
 * ✎ Rename row), an inline confirm for deleting (d or the 🗑 row), and an
 * inline title box for new sessions (n or the ✨ row; ↵ creates the
 * session with that name).
 * Renaming the current session writes through pi.setSessionName(); other
 * sessions get a session_info entry appended directly to their file
 * (clears when empty). Deletion unlinks the session file; the current
 * session cannot be deleted.
 *
 * Keys (session/theme pickers): ↑↓/jk move · ↵ select · n new (sessions) ·
 *       r rename · d delete · ctrl+] hide · esc/q close
 */

import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext, SessionInfo, Theme } from "@earendil-works/pi-coding-agent";
import { CustomEditor, SessionManager } from "@earendil-works/pi-coding-agent";
import {
	Editor,
	Key,
	matchesKey,
	SelectList,
	visibleWidth,
	wrapTextWithAnsi,
	type Keybindings,
	type TUI,
} from "@earendil-works/pi-tui";
import { resolve } from "node:path";
import { rm } from "node:fs/promises";

// ── Shared state ─────────────────────────────────────────────────────

let pendingSessionPath: string | undefined;
/** New-session name queued for the /sessions command (event-ctx path). */
let pendingNewSessionName: string | undefined;
let pendingNewSessionAt = 0;

async function createNewSession(ctx: ExtensionCommandContext, name: string): Promise<void> {
	try {
		await ctx.newSession({
			setup: async (sm) => {
				if (name) sm.appendSessionInfo(name);
			},
			withSession: async (rctx: any) => {
				rctx.ui.notify(name ? `New session “${name}” started` : "New session started", "info");
			},
		});
	} catch (err) {
		console.error("session-switcher: newSession failed:", err);
	}
}
let activeAPI: ExtensionAPI | undefined;

// ── Formatting helpers ───────────────────────────────────────────────

function shortenCwd(cwd: string): string {
	if (!cwd) return "?";
	return cwd.replace(/^\/home\/[^/]+/, "~");
}

function sessionTitle(s: SessionInfo): string {
	// First messages can be multi-line — collapse into a single line so a
	// literal \n never leaks into a rendered row and breaks the overlay.
	const name = (s.name ?? "").replace(/[\r\n]+/g, " ").trim();
	const first = s.firstMessage.replace(/[\r\n]+/g, " ").trim().slice(0, 80);
	return name || first || "(untitled)";
}

function sessionSubtitle(s: SessionInfo): string {
	const cwd = shortenCwd(s.cwd);
	const d = s.modified;
	const time = `${d.toLocaleDateString()} ${d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", hour12: false })}`;
	const shortId = s.path.slice(s.path.lastIndexOf("_") + 1, s.path.length - ".jsonl".length).slice(-4);
	return `${cwd}  •  ${time}  •  ${s.messageCount} msg${s.messageCount === 1 ? "" : "s"}  •  #${shortId}`;
}

// ── Questionnaire-style rendering helpers ────────────────────────────

function renderHeaderLine(theme: Theme, width: number, head: string): string {
	return (
		theme.fg("borderMuted", "─".repeat(3)) +
		theme.fg("accent", head.trim()) +
		" " +
		theme.fg("borderMuted", "─".repeat(Math.max(0, width - visibleWidth(head) - 7)))
	);
}

function editorThemeFor(theme: Theme) {
	return {
		borderColor: (s: string) => theme.fg("borderMuted", s),
		selectList: {
			selectedPrefix: (t: string) => theme.fg("accent", t),
			selectedText: (t: string) => theme.fg("accent", t),
			description: (t: string) => theme.fg("dim", t),
			scrollInfo: (t: string) => theme.fg("dim", t),
			noMatch: (t: string) => theme.fg("warning", t),
		},
	};
}

// ── Picker rows / component ──────────────────────────────────────────

type PickerRow<T> =
	| {
			kind: "item";
			value: T;
			label: string;
			description?: string;
			mark?: string;
			markColor?: "accent" | "success" | "dim" | "warning";
	  }
	| { kind: "action"; action?: string; label: string; description?: string };

interface PickerEditorOpts {
	prompt: string;
	prefill: () => string;
	onCommit: (text: string) => void | Promise<void>;
}

interface PickerOptions<T> {
	title: string;
	badge?: string;
	hint: string;
	rows: PickerRow<T>[];
	theme: Theme;
	tui: TUI;
	onSelect: (row: PickerRow<T>) => void;
	onCancel: () => void;
	onExtraKey?: (key: string, row: PickerRow<T>) => boolean | undefined;
	editor?: PickerEditorOpts;
	/** Inline title editor for creating a new session (n key / ✨ row). */
	newSession?: { prompt: string; onCommit: (text: string) => void | Promise<void> };
	/** Called after the user confirms deletion of an item (d → y). */
	onDelete?: (row: PickerRow<T>) => void | Promise<void>;
	/** Return true to block deletion before the confirm screen (e.g. protected item). */
	deleteGuard?: (row: PickerRow<T>) => boolean;
}

/**
 * Questionnaire-style list picker: bottom sheet with `─── title ───` header,
 * ▸ option list (dim descriptions, scroll window), optional inline editor
 * mode, collapse (ctrl+]), cancel (esc).
 */
class PickerComponent<T> {
	private readonly opts: PickerOptions<T>;
	private readonly editor: Editor;
	private readonly tui: TUI;
	private idx = 0;
	private lastItemIdx = -1;
	private collapsed = false;
	private editorMode = false;
	private newMode = false;
	private deleteTarget: PickerRow<T> | undefined;
	private cacheW?: number;
	private cacheLines?: string[];

	constructor(opts: PickerOptions<T>) {
		this.opts = opts;
		this.tui = opts.tui;
		this.editor = new Editor(opts.tui, editorThemeFor(opts.theme));
		const firstItem = opts.rows.findIndex((r) => r.kind === "item");
		if (firstItem >= 0) this.lastItemIdx = firstItem;
	}

	/** The item an action row (or the r/d keys) should target: the focused item, else the last focused item. */
	get targetItem(): PickerRow<T> | undefined {
		const row = this.opts.rows[this.idx];
		if (row?.kind === "item") return row;
		return this.lastItemIdx >= 0 ? this.opts.rows[this.lastItemIdx] : undefined;
	}

	setRows(rows: PickerRow<T>[]): void {
		this.opts.rows = rows;
		if (this.idx >= rows.length) this.idx = Math.max(0, rows.length - 1);
		if (this.lastItemIdx >= rows.length) this.lastItemIdx = -1;
		this.invalidate();
	}

	setBadge(badge: string | undefined): void {
		this.opts.badge = badge;
		this.invalidate();
	}

	invalidate(): void {
		this.cacheW = undefined;
		this.cacheLines = undefined;
	}

	startEditor(): void {
		if (!this.opts.editor) return;
		this.editor.setText(this.opts.editor.prefill());
		this.editorMode = true;
		this.editor.focused = true;
		this.invalidate();
		this.tui.requestRender();
	}

	/** Open the new-session title editor (n key / ✨ row). */
	startNew(): void {
		if (!this.opts.newSession) return;
		this.editor.setText("");
		this.newMode = true;
		this.editor.focused = true;
		this.invalidate();
		this.tui.requestRender();
	}

	startDelete(): void {
		const target = this.targetItem;
		if (!target || target.kind !== "item") return;
		if (this.opts.deleteGuard?.(target)) return;
		this.deleteTarget = target;
		this.invalidate();
		this.tui.requestRender();
	}

	requestRender(): void {
		this.tui.requestRender();
	}

	// ── input routing ──────────────────────────────────────────────────

	handleInput(data: string): void {
		if (this.collapsed) {
			if (matchesKey(data, "ctrl+]" as never)) this.collapsed = false;
			this.invalidate();
			this.tui.requestRender();
			return;
		}
		if (this.deleteTarget) {
			this.handleDeleteInput(data);
		} else if (this.newMode) {
			this.handleNewInput(data);
		} else if (this.editorMode) {
			this.handleEditorInput(data);
		} else {
			this.handleListInput(data);
		}
		this.invalidate();
		this.tui.requestRender();
	}

	private handleListInput(data: string): void {
		const rows = this.opts.rows;
		const last = rows.length - 1;

		if (data === "k" || matchesKey(data, "up")) {
			this.idx = this.idx <= 0 ? last : this.idx - 1;
			this.trackItemFocus();
			return;
		}
		if (data === "j" || matchesKey(data, "down")) {
			this.idx = this.idx >= last ? 0 : this.idx + 1;
			this.trackItemFocus();
			return;
		}
		if (matchesKey(data, "ctrl+]" as never)) {
			this.collapsed = true;
			return;
		}
		if (matchesKey(data, "escape") || data === "\x1b" || matchesKey(data, "ctrl+c") || data === "q") {
			this.opts.onCancel();
			return;
		}
		if (data.length === 1) {
			if (this.opts.onExtraKey?.(data, rows[this.idx])) return;
		}
		if (data === "\r" || data === "\n" || matchesKey(data, "enter")) {
			this.opts.onSelect(rows[this.idx]);
		}
	}

	private trackItemFocus(): void {
		if (this.opts.rows[this.idx]?.kind === "item") this.lastItemIdx = this.idx;
	}

	private handleDeleteInput(data: string): void {
		if (data === "y" || data === "Y" || matchesKey(data, "enter")) {
			const target = this.deleteTarget;
			this.deleteTarget = undefined;
			const cb = this.opts.onDelete;
			if (cb && target) {
				const r = cb(target);
				if (r) void r;
			}
			return;
		}
		if (data === "n" || data === "N" || data === "q" || matchesKey(data, "escape") || data === "\x1b" || matchesKey(data, "ctrl+c")) {
			this.deleteTarget = undefined;
			return;
		}
	}

	private handleNewInput(data: string): void {
		if (data === "\r" || data === "\n" || matchesKey(data, "enter")) {
			const text = this.editor.getText();
			this.exitNew();
			const cb = this.opts.newSession?.onCommit;
			if (cb) {
				const r = cb(text);
				if (r) void r;
			}
			return;
		}
		if (matchesKey(data, "escape") || data === "\x1b") {
			this.exitNew();
			return;
		}
		this.editor.handleInput(data); // shift+↵ newline, paste, undo all flow through
	}

	private handleEditorInput(data: string): void {
		if (data === "\r" || data === "\n" || matchesKey(data, "enter")) {
			const text = this.editor.getText();
			this.exitEditor();
			const cb = this.opts.editor?.onCommit;
			if (cb) {
				const r = cb(text);
				if (r) void r;
			}
			return;
		}
		if (matchesKey(data, "escape") || data === "\x1b") {
			this.exitEditor();
			return;
		}
		this.editor.handleInput(data); // shift+↵ newline, paste, undo all flow through
	}

	private exitNew(): void {
		this.newMode = false;
		this.editor.focused = false;
		this.invalidate();
	}

	private exitEditor(): void {
		this.editorMode = false;
		this.editor.focused = false;
		this.invalidate();
	}

	// ── rendering ──────────────────────────────────────────────────────

	render(width: number): string[] {
		if (this.cacheLines && this.cacheW === width) return this.cacheLines;
		const th = this.opts.theme;
		const lines: string[] = [];

		const head = ` ${this.opts.title}${this.opts.badge ? ` (${this.opts.badge})` : ""} `;
		lines.push(renderHeaderLine(th, width, head));
		lines.push("");

		if (this.collapsed) {
			lines.push(th.fg("dim", ` ${this.opts.title} hidden — press ctrl+] to reopen `));
		} else if (this.deleteTarget) {
			lines.push(th.fg("warning", ` ⚠  Delete session: ${th.bold(this.deleteTarget.label)}? `));
			lines.push("");
			lines.push(`  ${th.fg("dim", "This cannot be undone — y delete · n/esc cancel")}`);
		} else if (this.newMode && this.opts.newSession) {
			lines.push(th.fg("dim", ` ${this.opts.newSession.prompt} `));
			lines.push(...this.editor.render(Math.max(20, width - 4)).map((l) => "  " + l));
		} else if (this.editorMode && this.opts.editor) {
			lines.push(th.fg("dim", ` ${this.opts.editor.prompt} `));
			lines.push(...this.editor.render(Math.max(20, width - 4)).map((l) => "  " + l));
		} else {
			lines.push(...this.renderList(width));
		}

		lines.push("");
		if (!this.collapsed && !this.editorMode && !this.deleteTarget && !this.newMode) {
			lines.push(`  ${th.fg("dim", this.opts.hint)}`);
		}
		// Transparent overlay: pad every line to the full overlay width with
		// plain spaces (no background fill) so the transcript shows through.
		const filled = lines.map((l) => {
			const w = visibleWidth(l);
			return w >= width ? l : l + " ".repeat(width - w);
		});
		this.cacheW = width;
		this.cacheLines = filled;
		return filled;
	}

	private renderList(width: number): string[] {
		const th = this.opts.theme;
		const lines: string[] = [];
		const rows = this.opts.rows;
		const len = rows.length;
		// Keep the rendered box compact so header + rows + hint fit inside
		// the centered overlay's maxHeight on typical terminals.
		const maxVisible = 8;
		const start = Math.max(0, Math.min(this.idx - 3, len - maxVisible));
		const end = Math.min(start + maxVisible, len);

		for (let r = start; r < end; r++) {
			const row = rows[r];
			const focused = r === this.idx;
			const prefix = focused ? th.fg("accent", "▸") : " ";
			if (row.kind === "item") {
				const mark = row.mark ? th.fg(row.markColor ?? "dim", row.mark) : "";
				const label = focused ? th.fg("accent", th.bold(row.label)) : th.fg("text", row.label);
				lines.push(`  ${prefix} ${mark}${label}`);
				if (row.description) {
					for (const dl of wrapTextWithAnsi(row.description, Math.max(10, width - 6)).slice(0, 2)) {
						lines.push(`     ${th.fg("dim", dl)}`);
					}
				}
			} else {
				const label = focused ? th.fg("accent", th.bold(row.label)) : th.fg("muted", row.label);
				lines.push(`  ${prefix} ${label}`);
				if (row.description) {
					for (const dl of wrapTextWithAnsi(row.description, Math.max(10, width - 6)).slice(0, 1)) {
						lines.push(`     ${th.fg("dim", dl)}`);
					}
				}
			}
		}
		if (start > 0 || end < len) {
			lines.push("");
			lines.push(`  ${th.fg("dim", `(${this.idx + 1}/${len})`)}`);
		}
		return lines;
	}
}

// ── Session picker ───────────────────────────────────────────────────

/** True if the given session is the one this pi instance is currently in. */
function isCurrentSession(ctx: ExtensionContext, target: SessionInfo): boolean {
	const cur = ctx.sessionManager.getSessionFile();
	const curId = ctx.sessionManager.getSessionId();
	return (
		(cur !== undefined && resolve(cur) === resolve(target.path)) ||
		(curId !== undefined && curId === target.id)
	);
}

function buildSessionRows(sessions: SessionInfo[], currentPath: string | undefined, currentId: string | undefined): PickerRow<SessionInfo>[] {
	const cur = currentPath ? resolve(currentPath) : undefined;
	const rows: PickerRow<SessionInfo>[] = sessions.map((s) => {
		// Match by resolved path AND/OR stable session id — the id works even
		// before the current session's file is flushed to disk (listAll only
		// sees files, so an unflushed current session is simply absent here).
		const isCurrent =
			(cur !== undefined && cur === resolve(s.path)) || (currentId !== undefined && currentId === s.id);
		return {
			kind: "item",
			value: s,
			label: isCurrent ? `${sessionTitle(s)}  (current)` : sessionTitle(s),
			description: sessionSubtitle(s),
			mark: isCurrent ? "● " : "",
			markColor: "accent",
		};
	});
	rows.push({
		kind: "action",
		action: "new",
		label: "✨  Start a new session…",
		description: "n — start a fresh session",
	});
	rows.push({
		kind: "action",
		action: "rename",
		label: "✎  Rename selected session…",
		description: "r — set a friendly display name (empty clears it)",
	});
	rows.push({
		kind: "action",
		action: "delete",
		label: "🗑  Delete selected session…",
		description: "d — permanently delete (asks for confirmation)",
	});
	return rows;
}

async function renameSession(pi: ExtensionAPI, ctx: ExtensionContext, target: SessionInfo, name: string): Promise<void> {
	try {
		if (isCurrentSession(ctx, target)) {
			pi.setSessionName(name);
		} else {
			SessionManager.open(target.path).appendSessionInfo(name);
		}
		ctx.ui.notify(name ? `Session renamed to “${name}”` : "Session name cleared", "info");
	} catch (err) {
		ctx.ui.notify(`Rename failed: ${err}`, "error");
	}
}

async function showSessionPicker(ctx: ExtensionCommandContext, pi: ExtensionAPI): Promise<string | undefined> {
	const allSessions = await SessionManager.listAll();
	if (allSessions.length === 0) {
		ctx.ui.notify("No sessions found", "info");
		return undefined;
	}
	allSessions.sort((a: SessionInfo, b: SessionInfo) => b.modified.getTime() - a.modified.getTime());
	const currentPath = ctx.sessionManager.getSessionFile();
	const currentId = ctx.sessionManager.getSessionId();

	return ctx.ui.custom<string | undefined>(
		(tui, theme, _kb, done) => {
			let result: string | undefined;
			const comp: PickerComponent<SessionInfo> = new PickerComponent<SessionInfo>({
				title: "📂  Switch Session",
				badge: String(allSessions.length),
				hint: "↑↓/jk move · ↵ switch · n new · r rename · d delete · q/esc close · ctrl+] hide",
				theme,
				tui,
				rows: buildSessionRows(allSessions, currentPath, currentId),
				newSession: {
					prompt: " New session name — ↵ creates · esc back ",
					onCommit: (text) => {
						const name = text.trim();
						done(undefined);
						if (typeof (ctx as any).newSession === "function") {
							// Command ctx (via /sessions): create directly.
							void createNewSession(ctx as ExtensionCommandContext, name);
						} else {
							// Event ctx (via Ctrl+X) has no session control — route
							// through the /sessions command, which runs with a
							// command ctx (same pattern as session switching).
							pendingNewSessionName = name;
							pendingNewSessionAt = Date.now();
							ctx.ui.setEditorText("/sessions");
							ctx.ui.notify(name ? `Press Enter to create “${name}”` : "Press Enter to start a new session", "info");
						}
					},
				},
				editor: {
					prompt: " New session name — ↵ saves · shift+↵ newline · esc back ",
					prefill: () => {
						const target = comp.targetItem;
						if (!target || target.kind !== "item") return "";
						return target.value.name ?? target.value.firstMessage.slice(0, 80);
					},
					onCommit: async (text) => {
						const target = comp.targetItem;
						if (!target || target.kind !== "item") return;
						await renameSession(pi, ctx, target.value, text.trim());
						const fresh = await SessionManager.listAll();
						fresh.sort((a: SessionInfo, b: SessionInfo) => b.modified.getTime() - a.modified.getTime());
						allSessions.length = 0;
						allSessions.push(...fresh);
						comp.setRows(buildSessionRows(allSessions, currentPath, currentId));
						comp.setBadge(String(allSessions.length));
						comp.requestRender();
					},
				},
				onDelete: async (row) => {
					if (row.kind !== "item") return;
					const target = row.value;
					if (isCurrentSession(ctx, target)) {
						ctx.ui.notify("Can't delete the current session", "warning");
						return;
					}
					try {
						await rm(target.path);
						ctx.ui.notify(`Deleted session “${sessionTitle(target)}”`, "info");
						const fresh = await SessionManager.listAll();
						fresh.sort((a: SessionInfo, b: SessionInfo) => b.modified.getTime() - a.modified.getTime());
						allSessions.length = 0;
						allSessions.push(...fresh);
						comp.setRows(buildSessionRows(allSessions, currentPath, currentId));
						comp.setBadge(String(allSessions.length));
						comp.requestRender();
					} catch (err) {
						ctx.ui.notify(`Delete failed: ${err}`, "error");
					}
				},
				deleteGuard: (row) => {
					if (row.kind !== "item") return false;
					if (isCurrentSession(ctx, row.value)) {
						ctx.ui.notify("Can't delete the current session", "warning");
						return true;
					}
					return false;
				},
				onSelect: (row) => {
					if (row.kind === "item") {
						result = row.value.path;
						done(result);
					} else if (row.action === "new") {
						comp.startNew();
					} else if (row.action === "rename") {
						comp.startEditor();
					} else {
						comp.startDelete();
					}
				},
				onExtraKey: (key, _row) => {
					if (key === "n") {
						comp.startNew();
						return true;
					}
					if (key === "r") {
						if (comp.targetItem) comp.startEditor();
						return true;
					}
					if (key === "d") {
						if (comp.targetItem) comp.startDelete();
						return true;
					}
					return false;
				},
				onCancel: () => done(undefined),
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
				anchor: "center",
				width: "75%",
				minWidth: 55,
				maxHeight: "65%",
			},
		},
	) as Promise<string | undefined>;
}

// ── Theme picker ─────────────────────────────────────────────────────

async function showThemePicker(ctx: ExtensionContext): Promise<string | undefined> {
	let themes: { name: string; path: string | undefined }[];
	try {
		themes = ctx.ui.getAllThemes();
	} catch (err) {
		ctx.ui.notify(`Theme error: ${err}`, "error");
		return undefined;
	}
	if (themes.length === 0) {
		ctx.ui.notify("No themes available", "info");
		return undefined;
	}

	return ctx.ui.custom<string | undefined>(
		(tui, theme, _kb, done) => {
			const comp = new PickerComponent<string>({
				title: "🎨  Switch Theme",
				badge: String(themes.length),
				hint: "↑↓/jk move · ↵ select · q/esc close · ctrl+] hide",
				theme,
				tui,
				rows: themes.map((t) => ({
					kind: "item" as const,
					value: t.name,
					label: t.name,
					description: t.path ?? "",
				})),
				onSelect: (row) => done(row.kind === "item" ? row.value : undefined),
				onCancel: () => done(undefined),
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
	) as Promise<string | undefined>;
}

async function pickTheme(ctx: any): Promise<void> {
	const selected = await showThemePicker(ctx);
	if (!selected) return;
	const result = ctx.ui.setTheme(selected);
	if (!result.success) {
		ctx.ui.notify(`Failed: ${result.error}`, "error");
	} else {
		ctx.ui.notify(`Theme switched to: ${selected}`, "info");
	}
}

// ── Keymaps overlay ──────────────────────────────────────────────────

async function showKeymapsOverlay(ctx: ExtensionContext): Promise<void> {
	if (!ctx.hasUI) return;

	await ctx.ui.custom<void>(
		(tui, theme, kb, done) => {
			const resolved = kb.getResolvedBindings();
			const ids = Object.keys(resolved).sort() as (keyof Keybindings)[];
			const items = ids.map((id) => {
				const def = kb.getDefinition(id);
				const keys = resolved[id];
				const keyStr = Array.isArray(keys) ? keys.join(", ") : keys ?? "";
				const desc = def?.description ?? "";
				return {
					value: id,
					label: `${keyStr.padEnd(22)}  ${desc}`,
					description: id,
				};
			});
			const maxVisible = Math.min(items.length, 12);
			const selectList = new SelectList(items, maxVisible, {
				selectedPrefix: (t: string) => theme.fg("accent", t),
				selectedText: (t: string) => theme.fg("accent", t),
				description: (t: string) => theme.fg("dim", t),
				scrollInfo: (t: string) => theme.fg("dim", t),
				noMatch: (t: string) => theme.fg("warning", t),
			});
			selectList.onSelect = () => done();
			selectList.onCancel = () => done();

			return {
				render: (w: number) => {
					const lines: string[] = [];
					lines.push(renderHeaderLine(theme, w, " ⌨️  Keymaps "));
					lines.push("");
					lines.push(...selectList.render(w));
					lines.push("");
					lines.push(`  ${theme.fg("dim", "↑↓/jk scroll · type to filter · q/esc close")}`);
					return lines;
				},
				invalidate: () => selectList.invalidate(),
				handleInput: (d: string) => {
					if (d === "j") selectList.handleInput("\x1b[B");
					else if (d === "k") selectList.handleInput("\x1b[A");
					else if (d === "q") done();
					else selectList.handleInput(d);
					tui.requestRender();
				},
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
	);
}

// ── Prefix command definitions ──────────────────────────────────────

interface PrefixCommand {
	key: string;
	label: string;
	action: (ctx: any) => Promise<void>;
}

const PREFIX_COMMANDS: PrefixCommand[] = [
	{ key: "s", label: "sessions", action: async (ctx) => {
		const path = await showSessionPicker(ctx, activeAPI!);
		if (!path) return;
		pendingSessionPath = path;
		ctx.ui.setEditorText("/sessions");
		ctx.ui.notify("Press Enter to switch sessions", "info");
	}},
	{ key: "t", label: "theme", action: async (ctx) => {
		await pickTheme(ctx);
	}},
	{ key: "k", label: "keymaps", action: async (ctx) => {
		await showKeymapsOverlay(ctx);
	}},
	{ key: "b", label: "sidebar", action: async (ctx) => {
		try {
			const mod = await import("./doxs-pi-sidebar.ts");
			// Pass this extension's pi handle explicitly: the sidebar module may
			// never have been loaded as an extension (pi started before the file
			// existed), so its own activeAPI would be undefined.
			await mod.toggleSidebar(activeAPI, ctx);
		} catch (err) {
			ctx.ui.notify("Sidebar unavailable: " + err, "error");
		}
	}},
];

// ── Custom editor with Ctrl+X prefix mode ────────────────────────────

function buildPrefixHint(): string {
	return " CX- " + PREFIX_COMMANDS.map((c) => `${c.key}:${c.label}`).join("  ") + " ";
}

class SessionPrefixEditor extends CustomEditor {
	private prefixActive = false;
	private prefixTimer: ReturnType<typeof setTimeout> | null = null;
	private savedBorderColor: ((str: string) => string) | null = null;

	private onTrigger: (key: string) => void;
	private appTheme: any;

	constructor(tui: any, theme: any, keybindings: any, onTrigger: (key: string) => void, appTheme: any) {
		super(tui, theme, keybindings);
		this.onTrigger = onTrigger;
		this.appTheme = appTheme;
		this.savedBorderColor = null;
	}

	private enterPrefix(): void {
		if (this.prefixActive) {
			if (this.prefixTimer !== null) clearTimeout(this.prefixTimer);
			this.prefixTimer = setTimeout(() => this.clearPrefix(), 1500);
			return;
		}
		this.prefixActive = true;
		if (!this.savedBorderColor) this.savedBorderColor = this.borderColor;
		this.borderColor = (str: string) => this.appTheme?.fg ? this.appTheme.fg("warning", str) : str;
		this.invalidate();
		this.prefixTimer = setTimeout(() => this.clearPrefix(), 1500);
	}

	private clearPrefix(): void {
		if (!this.prefixActive) return;
		this.prefixActive = false;
		if (this.prefixTimer !== null) { clearTimeout(this.prefixTimer); this.prefixTimer = null; }
		if (this.savedBorderColor) { this.borderColor = this.savedBorderColor; this.savedBorderColor = null; }
		this.invalidate();
	}

	handleInput(data: string): void {
		if (matchesKey(data, Key.ctrl("x"))) {
			this.enterPrefix();
			return;
		}
		if (this.prefixActive) {
			this.clearPrefix();
			for (const cmd of PREFIX_COMMANDS) {
				if (data === cmd.key) {
					this.onTrigger(cmd.key);
					return;
				}
			}
		}
		super.handleInput(data);
	}

	render(width: number): string[] {
		const lines = super.render(width);
		if (this.prefixActive && lines.length > 0) {
			const hint = buildPrefixHint();
			const last = lines.length - 1;
			const lineLen = visibleWidth(lines[last]!);
			if (lineLen >= hint.length) {
				lines[last] = lines[last]!.slice(0, lineLen - hint.length) + hint;
			}
		}
		return lines;
	}
}

// ── Entry point ──────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
	activeAPI = pi;

	// ── /keymaps command ──────────────────────────────────────────
	pi.registerCommand("keymaps", {
		description: "Show all keybindings in an overlay",
		handler: async (_args, ctx) => {
			await showKeymapsOverlay(ctx);
		},
	});

	// ── /sessions command ─────────────────────────────────────────
	pi.registerCommand("sessions", {
		description: "List all sessions, switch to one, or rename (r)",
		handler: async (_args, ctx) => {
			if (pendingSessionPath) {
				const path = pendingSessionPath;
				pendingSessionPath = undefined;
				const r = await ctx.switchSession(path, {
					withSession: async (rctx: any) => { rctx.ui.notify("Switched session", "info"); },
				});
				if (r.cancelled) ctx.ui.notify("Session switch cancelled", "info");
				return;
			}
			if (pendingNewSessionName !== undefined && Date.now() - pendingNewSessionAt < 20000) {
				const name = pendingNewSessionName;
				pendingNewSessionName = undefined;
				await createNewSession(ctx, name);
				return;
			}
			// Clear stale pendings (e.g. user escaped the editor instead of Enter).
			pendingSessionPath = undefined;
			pendingNewSessionName = undefined;
			const path = await showSessionPicker(ctx, pi);
			if (!path) return;
			const r = await ctx.switchSession(path, {
				withSession: async (rctx: any) => { rctx.ui.notify("Switched session", "info"); },
			});
			if (r.cancelled) ctx.ui.notify("Session switch cancelled", "info");
		},
	});

	// ── /theme command ────────────────────────────────────────────
	pi.registerCommand("theme", {
		description: "Switch theme (gruvbox-dark, dark, light, etc.)",
		handler: async (_args, ctx) => {
			await pickTheme(ctx);
		},
	});

	// ── Wrap editor with prefix handling ──────────────────────────
	pi.on("session_start", (_event, ctx) => {
		const appTheme = (ctx.ui as any).theme;
		if (!appTheme || ctx.mode !== "tui") return;

		ctx.ui.setEditorComponent((tui, theme, keybindings) => {
			return new SessionPrefixEditor(tui, theme, keybindings, async (key) => {
				for (const cmd of PREFIX_COMMANDS) {
					if (key === cmd.key) {
						await cmd.action(ctx);
						return;
					}
				}
			}, appTheme);
		});
	});
}
