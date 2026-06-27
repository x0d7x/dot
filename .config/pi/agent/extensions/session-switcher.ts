/**
 * Session Switcher & Theme Switcher Extension
 *
 * Features:
 *   - Ctrl+X then S — open session picker and switch
 *   - Ctrl+X then T — open theme picker and switch
 *   - /sessions     — list sessions and switch
 *   - /theme        — list themes and switch
 */

import type { ExtensionAPI, SessionInfo } from "@earendil-works/pi-coding-agent";
import { SessionManager, CustomEditor } from "@earendil-works/pi-coding-agent";
import { matchesKey, Key, visibleWidth } from "@earendil-works/pi-tui";

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

// ── Session picker ──────────────────────────────────────────────────

async function pickSession(ctx: any): Promise<string | undefined> {
	const allSessions = await SessionManager.listAll();
	if (allSessions.length === 0) {
		ctx.ui.notify("No sessions found", "info");
		return;
	}
	allSessions.sort((a: SessionInfo, b: SessionInfo) => b.modified.getTime() - a.modified.getTime());
	const pathByLabel = new Map<string, string>();
	const labels = allSessions.map((s: SessionInfo) => {
		const label = formatSessionLabel(s);
		pathByLabel.set(label, s.path);
		return label;
	});
	const selected = await ctx.ui.select("Select a session to switch to:", labels);
	if (!selected) return;
	return pathByLabel.get(selected);
}

// ── Theme picker ────────────────────────────────────────────────────

async function pickTheme(ctx: any): Promise<void> {
	try {
		const themes = ctx.ui.getAllThemes();
		if (themes.length === 0) {
			ctx.ui.notify("No themes available", "info");
			return;
		}

		const labels = themes.map((t: any) => t.name);
		const selected = await ctx.ui.select("Select a theme:", labels);
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
