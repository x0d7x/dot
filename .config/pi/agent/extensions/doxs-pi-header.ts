/**
 * dox's pi — custom startup header
 *
 * Replaces pi's built-in startup header (logo + keybinding hints) with a big
 * compact, centered "dox's pi" ANSI Shadow wordmark rendered in the active
 * theme's `accent` color, plus a small version line. No keybinding hints.
 *
 * - Colors follow the theme accent (currently gruvbox-dark blue) and adapt
 *   when you switch themes.
 * - Run `/builtin-header` to restore pi's default header.
 * - Edit this file and use `/reload` (or restart pi) to apply changes.
 */

import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import { VERSION } from "@earendil-works/pi-coding-agent";

// --- "dox's pi" rendered in the figlet "ANSI Shadow" font ---
const LOGO_LINES = [
	"██████╗  ██████╗ ██╗  ██╗███████╗    ██████╗ ██╗",
	"██╔══██╗██╔═══██╗╚██╗██╔╝██╔════╝    ██╔══██╗██║",
	"██║  ██║██║   ██║ ╚███╔╝ ███████╗    ██████╔╝██║",
	"██║  ██║██║   ██║ ██╔██╗ ╚════██║    ██╔═══╝ ██║",
	"██████╔╝╚██████╔╝██╔╝ ██╗███████║    ██║     ██║",
	"╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝    ╚═╝     ╚═╝",
];

/** Strip ANSI escape codes (colors) to get the raw visible text. */
function stripAnsi(s: string): string {
	return s.replace(/\x1b\[[0-9;]*m/g, "");
}

/** Pad a line with leading spaces so its visible text is centered in `width`. */
function centerLine(line: string, width: number): string {
	const visible = stripAnsi(line);
	// Box-drawing/block glyphs are width 1 in pi's layout, so code points == columns.
	const lineWidth = [...visible].length;
	const pad = Math.max(0, Math.floor((width - lineWidth) / 2));
	return " ".repeat(pad) + line;
}

/** Assemble the compact header: logo + version line. */
function buildHeader(theme: Theme): string[] {
	const logo = LOGO_LINES.map((line) => theme.bold(theme.fg("accent", line)));
	const version = theme.fg("dim", `  v${VERSION}`);
	return [...logo, version];
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		ctx.ui.setHeader((_tui, theme) => ({
			render(width: number): string[] {
				return buildHeader(theme).map((line) => centerLine(line, width));
			},
			invalidate() {},
		}));
	});

	// Command to restore the built-in header
	pi.registerCommand("builtin-header", {
		description: "Restore the built-in pi header",
		handler: async (_args, ctx) => {
			ctx.ui.setHeader(undefined);
			ctx.ui.notify("Built-in header restored", "info");
		},
	});
}
