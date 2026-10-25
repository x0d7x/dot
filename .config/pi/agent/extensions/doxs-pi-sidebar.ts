/**
 * dox's pi — Agent Resources Sidebar
 *
 * Toggleable full-height right-side panel listing the agent's resources:
 * skills, prompts, extension commands, extension files, subagents, and
 * themes. Everything is read-only navigation — nothing here touches the
 * header, and nothing is rendered below the header outside the panel.
 *
 * - `CX-b` (Ctrl+X then b) or `/sidebar` toggles the panel.
 * - ↑↓/jk move · ↵ show details · q/esc close · ctrl+] hide
 * - ctrl+] hides the panel (overlay stays alive); toggling again re-shows
 *   it. Toggling while visible closes it for good.
 *
 * Subagents are discovered via a dynamic import of ./subagents/agents.ts
 * (never a static import — that module must not be re-registered as an
 * extension; discovery degrades to an empty section on error).
 */

import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { CONFIG_DIR_NAME, getAgentDir } from "@earendil-works/pi-coding-agent";
import {
	matchesKey,
	truncateToWidth,
	visibleWidth,
	wrapTextWithAnsi,
	type OverlayHandle,
	type TUI,
} from "@earendil-works/pi-tui";
import * as fs from "node:fs";
import { homedir } from "node:os";
import * as path from "node:path";

// ── Shared state ─────────────────────────────────────────────────────

let activeAPI: ExtensionAPI | undefined;

type SidebarState = "closed" | "visible" | "collapsed";
let sidebarState: SidebarState = "closed";
let sidebarHandle: OverlayHandle | undefined;
let sidebarDone: (() => void) | undefined;

// ── Questionnaire-style header line (mirrors session-switcher) ───────

function renderHeaderLine(theme: Theme, width: number, head: string): string {
	return (
		theme.fg("borderMuted", "─".repeat(3)) +
		theme.fg("accent", head.trim()) +
		" " +
		theme.fg("borderMuted", "─".repeat(Math.max(0, width - visibleWidth(head) - 7)))
	);
}

// ── Extension file discovery (mirrors pi's loader rules) ─────────────

function isExtensionFile(name: string): boolean {
	return name.endsWith(".ts") || name.endsWith(".js");
}

/**
 * Subdirectory entry points: package.json with a "pi.extensions" manifest
 * first, then index.ts / index.js. Mirrors pi's resolveExtensionEntries().
 */
function resolveExtensionEntries(dir: string): string[] | null {
	try {
		const pkgPath = path.join(dir, "package.json");
		if (fs.existsSync(pkgPath)) {
			const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf-8")) as { pi?: { extensions?: unknown } };
			const entries = pkg.pi?.extensions;
			if (Array.isArray(entries) && entries.length > 0 && entries.every((e) => typeof e === "string")) {
				const resolved: string[] = [];
				for (const extPath of entries as string[]) {
					const p = path.resolve(dir, extPath);
					if (fs.existsSync(p)) resolved.push(p);
				}
				if (resolved.length > 0) return resolved;
			}
		}
	} catch {
		/* fall through to index checks */
	}
	const indexTs = path.join(dir, "index.ts");
	if (fs.existsSync(indexTs)) return [indexTs];
	const indexJs = path.join(dir, "index.js");
	if (fs.existsSync(indexJs)) return [indexJs];
	return null;
}

/**
 * Enumerate extension entry files in an extensions dir: direct *.ts/*.js
 * files plus one-level subdirectory entries. Mirrors pi's loader, so the
 * sidebar shows exactly what pi actually loads.
 */
function discoverExtensionFiles(dir: string): string[] {
	if (!fs.existsSync(dir)) return [];
	const out: string[] = [];
	try {
		const entries = fs.readdirSync(dir, { withFileTypes: true });
		for (const entry of entries) {
			const entryPath = path.join(dir, entry.name);
			if ((entry.isFile() || entry.isSymbolicLink()) && isExtensionFile(entry.name)) {
				out.push(entryPath);
				continue;
			}
			if (entry.isDirectory() || entry.isSymbolicLink()) {
				const sub = resolveExtensionEntries(entryPath);
				if (sub) out.push(...sub);
			}
		}
	} catch {
		return [];
	}
	return out;
}

/** Shorten a resource path for display: agent-dir-relative or ~-relative. */
function shortPath(p: string): string {
	const agentDir = getAgentDir();
	const home = homedir();
	if (p.startsWith(agentDir + path.sep)) return p.slice(agentDir.length + 1);
	if (p.startsWith(home + path.sep)) return "~" + p.slice(home.length);
	return p;
}

// ── Row / section model ──────────────────────────────────────────────

interface SidebarItem {
	label: string;
	description?: string;
}

interface SidebarSection {
	title: string;
	items: SidebarItem[];
}

/** Build all six resource sections. Subagents import is the only async part. */
async function buildSidebarRows(api: ExtensionAPI, ctx: ExtensionContext): Promise<SidebarSection[]> {
	const sections: SidebarSection[] = [];

	// Skills / prompts / extension commands — from the live command registry.
	let commands: { name: string; description?: string; source: string; path?: string }[] = [];
	try {
		commands = api.getCommands().map((c) => ({
			name: c.name,
			description: c.description,
			source: c.source,
			path: c.sourceInfo?.path,
		}));
	} catch {
		commands = [];
	}

	sections.push({
		title: "🧠  Skills",
		items: commands
			.filter((c) => c.source === "skill")
			.map((c) => ({
				label: c.name.startsWith("skill:") ? c.name.slice("skill:".length) : c.name,
				description: c.description ?? (c.path ? shortPath(c.path) : undefined),
			})),
	});
	sections.push({
		title: "📝  Prompts",
		items: commands
			.filter((c) => c.source === "prompt")
			.map((c) => ({
				label: c.name,
				description: c.description ?? (c.path ? shortPath(c.path) : undefined),
			})),
	});
	sections.push({
		title: "⚙️  Extension Commands",
		items: commands
			.filter((c) => c.source === "extension")
			.map((c) => ({
				label: "/" + c.name,
				description: c.description ?? (c.path ? shortPath(c.path) : undefined),
			})),
	});

	// Extension files — global + project extensions dirs, deduped.
	const extDirs = [path.join(getAgentDir(), "extensions")];
	if (ctx.cwd) extDirs.push(path.join(ctx.cwd, CONFIG_DIR_NAME, "extensions"));
	const seen = new Set<string>();
	const files: string[] = [];
	for (const dir of extDirs) {
		for (const f of discoverExtensionFiles(dir)) {
			const resolved = path.resolve(f);
			if (!seen.has(resolved)) {
				seen.add(resolved);
				files.push(f);
			}
		}
	}
	files.sort((a, b) => a.localeCompare(b));
	sections.push({
		title: "🧩  Extension Files",
		items: files.map((f) => ({ label: path.basename(f), description: shortPath(f) })),
	});

	// Subagents — dynamic import only (agents.ts must never be re-registered).
	let subagentItems: SidebarItem[] = [];
	try {
		const mod = await import("./subagents/agents.ts");
		const { agents } = mod.discoverAgents(ctx.cwd, "both");
		subagentItems = agents.map((a) => ({ label: a.name, description: a.description }));
	} catch {
		subagentItems = [];
	}
	sections.push({ title: "🤖  Subagents", items: subagentItems });

	// Themes.
	let themeItems: SidebarItem[] = [];
	try {
		themeItems = ctx.ui.getAllThemes().map((t) => ({
			label: t.name,
			description: t.path ? shortPath(t.path) : undefined,
		}));
	} catch {
		themeItems = [];
	}
	sections.push({ title: "🎨  Themes", items: themeItems });

	return sections;
}

// ── Sidebar component ────────────────────────────────────────────────

interface SidebarRow {
	kind: "section" | "item";
	section: number;
	item: number;
}

/**
 * Read-only navigable right-side panel. Section headers are separators
 * (never focusable); j/k/↑↓ move across item rows; ↵ notifies with the
 * row description; q/esc closes; ctrl+] collapses via the OverlayHandle.
 */
class SidebarComponent {
	private readonly tui: TUI;
	private readonly theme: Theme;
	private readonly ctx: ExtensionContext;
	private readonly sections: SidebarSection[];
	private readonly onClose: () => void;
	private readonly onCollapse: () => void;
	private readonly hint: string;

	private readonly rows: SidebarRow[] = [];
	private readonly itemRows: number[] = [];
	private idx = 0;
	private cacheW?: number;
	private cacheLines?: string[];

	constructor(opts: {
		theme: Theme;
		tui: TUI;
		ctx: ExtensionContext;
		sections: SidebarSection[];
		onClose: () => void;
		onCollapse: () => void;
	}) {
		this.theme = opts.theme;
		this.tui = opts.tui;
		this.ctx = opts.ctx;
		this.sections = opts.sections;
		this.onClose = opts.onClose;
		this.onCollapse = opts.onCollapse;
		this.hint = "↑↓/jk move · ↵ details · q/esc close · ctrl+] hide";

		for (let s = 0; s < this.sections.length; s++) {
			this.rows.push({ kind: "section", section: s, item: -1 });
			for (let i = 0; i < this.sections[s]!.items.length; i++) {
				const rowIdx = this.rows.length;
				this.rows.push({ kind: "item", section: s, item: i });
				this.itemRows.push(rowIdx);
			}
		}
	}

	get currentItem(): SidebarItem | undefined {
		if (this.itemRows.length === 0) return undefined;
		const row = this.rows[this.itemRows[this.idx]!]!;
		return this.sections[row.section]!.items[row.item];
	}

	invalidate(): void {
		this.cacheW = undefined;
		this.cacheLines = undefined;
	}

	handleInput(data: string): void {
		if (data === "k" || matchesKey(data, "up")) {
			if (this.itemRows.length > 0) this.idx = (this.idx - 1 + this.itemRows.length) % this.itemRows.length;
		} else if (data === "j" || matchesKey(data, "down")) {
			if (this.itemRows.length > 0) this.idx = (this.idx + 1) % this.itemRows.length;
		} else if (matchesKey(data, "ctrl+]" as never)) {
			this.onCollapse();
			return;
		} else if (matchesKey(data, "escape") || data === "\x1b" || matchesKey(data, "ctrl+c") || data === "q") {
			this.onClose();
			return;
		} else if (data === "\r" || data === "\n" || matchesKey(data, "enter")) {
			const item = this.currentItem;
			if (item) {
				const desc = item.description ? ` — ${item.description}` : "";
				this.ctx.ui.notify(`${item.label}${desc}`, "info");
			}
		}
		this.invalidate();
		this.tui.requestRender();
	}

	/** Line budget a row consumes (must match render()). */
	private rowLineCount(row: SidebarRow, width: number): number {
		if (row.kind === "section") {
			return this.sections[row.section]!.items.length === 0 ? 2 : 1;
		}
		const item = this.sections[row.section]!.items[row.item]!;
		if (!item.description) return 1;
		return 1 + Math.min(2, wrapTextWithAnsi(item.description, Math.max(10, width - 6)).length);
	}

	render(width: number): string[] {
		if (this.cacheLines && this.cacheW === width) return this.cacheLines;
		const th = this.theme;
		const totalRows = this.tui.terminal.rows;
		const lines: string[] = [];

		lines.push(renderHeaderLine(th, width, " 🗂  Agent Resources "));
		lines.push("");

		// Scroll window over this.rows so the panel always fits the terminal.
		const budget = Math.max(10, totalRows - 6); // title + blank + blank + hint (+ scroll info)
		const lineCounts = this.rows.map((r) => this.rowLineCount(r, width));
		const sum = (a: number, b: number) => {
			let t = 0;
			for (let i = a; i < b; i++) t += lineCounts[i]!;
			return t;
		};
		const f = this.itemRows.length > 0 ? this.itemRows[this.idx]! : 0;
		let start = f;
		let end = Math.min(f + 1, this.rows.length);
		while (end - start < this.rows.length && sum(start, end) < budget) {
			if (end < this.rows.length && sum(start, end + 1) <= budget) end++;
			else if (start > 0 && sum(start - 1, end) <= budget) start--;
			else break;
		}
		// Keep a section header attached to its first visible item when possible.
		while (
			start > 0 &&
			this.rows[start]!.kind === "item" &&
			this.rows[start - 1]!.kind === "section" &&
			sum(start - 1, end) <= budget
		) {
			start--;
		}

		for (let r = start; r < end; r++) {
			const row = this.rows[r]!;
			if (row.kind === "section") {
				const sec = this.sections[row.section]!;
				const title = truncateToWidth(sec.title, Math.max(4, width - 2), "…");
				lines.push(
					`  ${th.fg("accent", title)}${sec.items.length > 0 ? th.fg("dim", `  (${sec.items.length})`) : ""}`,
				);
				if (sec.items.length === 0) lines.push(`     ${th.fg("dim", "— none —")}`);
			} else {
				const focused = r === f;
				const item = this.sections[row.section]!.items[row.item]!;
				const prefix = focused ? th.fg("accent", "▸") : " ";
				const label = truncateToWidth(item.label, Math.max(4, width - 5), "…");
				const labelStr = focused ? th.fg("accent", th.bold(label)) : th.fg("text", label);
				lines.push(`  ${prefix} ${labelStr}`);
				if (item.description) {
					for (const dl of wrapTextWithAnsi(item.description, Math.max(10, width - 6)).slice(0, 2)) {
						lines.push(`     ${th.fg("dim", dl)}`);
					}
				}
			}
		}

		lines.push("");
		if (start > 0 || end < this.rows.length) {
			lines.push(`  ${th.fg("dim", `(${this.idx + 1}/${this.itemRows.length})`)}`);
		}
		lines.push(`  ${th.fg("dim", this.hint)}`);

		// Transparent panel: pad every line to the full panel width with plain
		// spaces (no background fill), then pad to full terminal height, so
		// the transcript behind shows through while the box keeps its size.
		const filled: string[] = [];
		for (const l of lines) {
			const w = visibleWidth(l);
			filled.push(w >= width ? l : l + " ".repeat(width - w));
		}
		while (filled.length < totalRows) filled.push(" ".repeat(width));
		filled.length = Math.min(filled.length, totalRows);

		this.cacheW = width;
		this.cacheLines = filled;
		return filled;
	}
}

// ── Toggle state machine ─────────────────────────────────────────────

/**
 * Toggle the sidebar. Exported for session-switcher (CX-b) and used by
 * the /sidebar command.
 *
 * `api` is passed explicitly so Ctrl+X+B works even when this module was
 * never loaded as an extension by pi (e.g. pi was started before this file
 * existed and session-switcher dynamic-imports it) — fall back to the
 * module-level `activeAPI` set by the extension loader when `api` is
 * undefined.
 *
 * - visible  → close via done() (never OverlayHandle.hide() — that leaks
 *   the pending custom() promise)
 * - collapsed → re-show via handle.setHidden(false)
 * - closed   → open a right-anchored overlay
 */
export async function toggleSidebar(api: ExtensionAPI | undefined, ctx: ExtensionContext): Promise<void> {
	if (ctx.mode !== "tui" || !ctx.hasUI) {
		ctx.ui.notify("Sidebar requires the TUI", "warning");
		return;
	}
	if (sidebarState === "visible") {
		sidebarDone?.();
		return;
	}
	if (sidebarState === "collapsed") {
		sidebarHandle?.setHidden(false);
		sidebarState = "visible";
		return;
	}
	const resolved = api ?? activeAPI;
	if (!resolved) {
		ctx.ui.notify("Sidebar unavailable: extension not loaded", "error");
		return;
	}

	sidebarState = "visible";
	try {
		const sections = await buildSidebarRows(resolved, ctx);
		await ctx.ui.custom<void>(
			(tui, theme, _kb, done) => {
				const close = () => {
					sidebarDone = undefined;
					done(undefined);
				};
				sidebarDone = close;
				return new SidebarComponent({
					theme,
					tui,
					ctx,
					sections,
					onClose: close,
					onCollapse: () => {
						sidebarHandle?.setHidden(true);
						sidebarState = "collapsed";
					},
				});
			},
			{
				overlay: true,
				overlayOptions: {
					anchor: "right-center",
					width: "35%",
					minWidth: 40,
					maxHeight: "100%",
					margin: 0,
				},
				onHandle: (handle) => {
					sidebarHandle = handle;
				},
			},
		);
	} catch (err) {
		ctx.ui.notify(`Sidebar error: ${err}`, "error");
	} finally {
		sidebarState = "closed";
		sidebarDone = undefined;
		sidebarHandle = undefined;
	}
}

// ── Entry point ──────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
	activeAPI = pi;

	pi.registerCommand("sidebar", {
		description: "Toggle the agent resources sidebar (skills, prompts, extensions, subagents, themes)",
		handler: async (_args, ctx) => {
			await toggleSidebar(pi, ctx);
		},
	});
}
