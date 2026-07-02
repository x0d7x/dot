/**
 * Session Switcher & Theme Switcher Extension
 *
 * Features:
 *   - Ctrl+X then S — open session picker and switch (overlay UI)
 *   - Ctrl+X then T — open theme picker and switch (overlay UI)
 *   - Ctrl+X then K — show all keymaps (overlay UI)
 *   - /sessions     — list sessions and switch
 *   - /theme        — list themes and switch
 *   - /keymaps      — show all keybindings
 */

import type { ExtensionAPI, SessionInfo } from "@earendil-works/pi-coding-agent";
import { SessionManager, CustomEditor, DynamicBorder } from "@earendil-works/pi-coding-agent";
import { matchesKey, Key, visibleWidth } from "@earendil-works/pi-tui";
import { Container, Spacer, Text, SelectList } from "@earendil-works/pi-tui";

// ── Shared state ─────────────────────────────────────────────────────

let pendingSessionPath: string | undefined;

// ── Formatting helpers ───────────────────────────────────────────────

function formatSessionLabel(session: SessionInfo): string {
	const name = session.name ?? session.firstMessage.slice(0, 80);
	const cwd = session.cwd ? session.cwd.replace(/^\/home\/[^/]+/, "~") : "?";
	const date = session.modified.toLocaleDateString();
	const count = session.messageCount;
	return `${name}  ${cwd}  ${date}  (${count} msgs)`;
}

// ── Keymaps overlay ────────────────────────────────────────────────

async function showKeymapsOverlay(ctx: any): Promise<void> {
	if (!ctx.hasUI) return;

	return ctx.ui.custom<void>((tui, theme, kb, done) => {
		// Build keymap entries from the keybindings manager
		const resolved = kb.getResolvedBindings();
		const ids = Object.keys(resolved).sort();
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
		const container = new Container();
		container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
		container.addChild(new Text(theme.fg("accent", theme.bold("⌨️  Keymaps")), 1, 0));
		container.addChild(new Spacer(1));

		const maxVisible = Math.min(items.length, 14);
		const selectList = new SelectList(items, maxVisible, {
			selectedPrefix: (t: string) => theme.fg("accent", t),
			selectedText: (t: string) => theme.fg("accent", t),
			description: (t: string) => theme.fg("dim", t),
			scrollInfo: (t: string) => theme.fg("dim", t),
			noMatch: (t: string) => theme.fg("warning", t),
		});
		selectList.onSelect = () => done();
		selectList.onCancel = () => done();
		container.addChild(selectList);

		container.addChild(new Spacer(1));
		container.addChild(new Text(theme.fg("dim", "↑↓/jk scroll  esc close"), 1, 0));
		container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));

		return {
			render: (w: number) => container.render(w),
			invalidate: () => container.invalidate(),
			handleInput: (d: string) => {
				if (d === "j") selectList.handleInput("\x1b[B");
				else if (d === "k") selectList.handleInput("\x1b[A");
				else selectList.handleInput(d);
				tui.requestRender();
			},
		};
	}, {
		overlay: true,
		overlayOptions: { width: "80%", minWidth: 60, maxHeight: "75%", anchor: "center" },
	});
}

// ── Session picker (overlay) ─────────────────────────────────────

async function pickSession(ctx: any): Promise<string | undefined> {
	const allSessions = await SessionManager.listAll();
	if (allSessions.length === 0) {
		ctx.ui.notify("No sessions found", "info");
		return;
	}
	allSessions.sort((a: SessionInfo, b: SessionInfo) => b.modified.getTime() - a.modified.getTime());

	const items = allSessions.map((s: SessionInfo) => ({
		value: s.path,
		label: formatSessionLabel(s),
		description: `${s.modified.toLocaleDateString()}  •  ${s.messageCount} msgs`,
	}));

	return showOverlayPicker(ctx, "📂  Switch Session", items, "No sessions found");
}

// ── Theme picker (overlay) ──────────────────────────────────────

async function pickTheme(ctx: any): Promise<void> {
	try {
		const themes = ctx.ui.getAllThemes();
		if (themes.length === 0) {
			ctx.ui.notify("No themes available", "info");
			return;
		}

		const items = themes.map((t: any) => ({
			value: t.name,
			label: t.name,
			description: t.path ?? "",
		}));

		const selected = await showOverlayPicker<string>(ctx, "🎨  Switch Theme", items, "No themes available");
		if (!selected) return;

		const result = ctx.ui.setTheme(selected);
		if (!result.success) {
			ctx.ui.notify(`Failed: ${result.error}`, "error");
		} else {
			ctx.ui.notify(`Theme switched to: ${selected}`, "info");
		}
	} catch (err) {
		ctx.ui.notify(`Theme error: ${err}`, "error");
	}
}

// ── Shared overlay picker ─────────────────────────────────────────

async function showOverlayPicker<T>(
	ctx: any,
	title: string,
	items: { value: T; label: string; description?: string }[],
	emptyMsg: string,
): Promise<T | undefined> {
	if (!ctx.hasUI) return undefined;
	if (items.length === 0) {
		ctx.ui.notify(emptyMsg, "info");
		return undefined;
	}

	return ctx.ui.custom<T | undefined>((tui, theme, _kb, done) => {
		const container = new Container();
		container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
		container.addChild(new Text(theme.fg("accent", theme.bold(title)), 1, 0));
		container.addChild(new Spacer(1));

		const maxVisible = Math.min(items.length, 10);
		const selectList = new SelectList(items, maxVisible, {
			selectedPrefix: (t: string) => theme.fg("accent", t),
			selectedText: (t: string) => theme.fg("accent", t),
			description: (t: string) => theme.fg("dim", t),
			scrollInfo: (t: string) => theme.fg("dim", t),
			noMatch: (t: string) => theme.fg("warning", t),
		});
		selectList.onSelect = (item) => done(item.value as T);
		selectList.onCancel = () => done(undefined);
		container.addChild(selectList);

		container.addChild(new Spacer(1));
		container.addChild(new Text(theme.fg("dim", "↑↓/jk navigate  ↵ select  esc cancel"), 1, 0));
		container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));

		return {
			render: (w: number) => container.render(w),
			invalidate: () => container.invalidate(),
			handleInput: (d: string) => {
				if (d === "j") selectList.handleInput("\x1b[B");
				else if (d === "k") selectList.handleInput("\x1b[A");
				else selectList.handleInput(d);
				tui.requestRender();
			},
		};
	}, {
		overlay: true,
		overlayOptions: { width: "75%", minWidth: 55, maxHeight: "65%", anchor: "center" },
	});
}

// ── Prefix command definitions ──────────────────────────────────────

interface PrefixCommand {
	key: string;
	label: string;
	action: (ctx: any) => Promise<void>;
}

const PREFIX_COMMANDS: PrefixCommand[] = [
	{ key: "s", label: "sessions", action: async (ctx) => {
		const path = await pickSession(ctx);
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
	// ── /keymaps command ──────────────────────────────────────────
	pi.registerCommand("keymaps", {
		description: "Show all keybindings in an overlay",
		handler: async (_args, ctx) => {
			await showKeymapsOverlay(ctx);
		},
	});

	// ── /sessions command ─────────────────────────────────────────
	pi.registerCommand("sessions", {
		description: "List all sessions and switch to one",
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
			const path = await pickSession(ctx);
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
