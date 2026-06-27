/**
 * Permission Gate Extension - Like OpenCode's permission system
 *
 * Prompts for confirmation before:
 *   - Editing files
 *   - Writing new files
 *   - Reading files (optional, toggle with /perm read)
 *   - Running dangerous bash commands (rm -rf, sudo, chmod, etc.)
 *
 * Commands:
 *   /perm          - Show current permission settings
 *   /perm read     - Toggle confirmation for read operations
 *   /perm strict   - Toggle strict mode (block if no UI)
 *
 * The extension remembers settings across the session.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

interface PermSettings {
	confirmRead: boolean;   // Ask before read tool
	strictMode: boolean;    // Block when no UI (vs allow)
}

const DEFAULT_SETTINGS: PermSettings = {
	confirmRead: false,
	strictMode: true,
};

let settings: PermSettings = { ...DEFAULT_SETTINGS };

const DANGEROUS_PATTERNS = [
	/\brm\s+(-rf?|--recursive)\b/i,
	/\bsudo\b/i,
	/\b(chmod|chown)\b.*777/i,
	/\bdd\s+if=/i,
	/\b>:?\s*\//,       // redirect to root
	/\|?\s*shutdown\b/i,
	/\|?\s*reboot\b/i,
	/\bmv\s+\/[\w\/]+\s+\/dev\/null/i,
	/\b>\s*\/dev\/(sda|sdb|nvme|mmc)/i,
];

function isDangerousCommand(command: string): boolean {
	return DANGEROUS_PATTERNS.some((p) => p.test(command));
}

async function confirmAction(
	ctx: ExtensionContext,
	toolName: string,
	action: string,
	details: string,
): Promise<boolean> {
	if (!ctx.hasUI) {
		if (settings.strictMode) {
			return false; // Block in non-interactive mode
		}
		return true; // Allow in non-interactive mode if not strict
	}

	const choice = await ctx.ui.select(
		`🔒 ${toolName.toUpperCase()} — ${action}\n\n${details}\n\nAllow?`,
		["Allow", "Deny"],
	);

	return choice === "Allow";
}

export default function (pi: ExtensionAPI) {
	// ── Tool: edit ──
	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName === "edit") {
			const path = (event.input as { path?: string }).path ?? "unknown";
			const oldText = (event.input as { oldText?: string }).oldText ?? "";
			const newText = (event.input as { newText?: string }).newText ?? "";
			const oldPreview = oldText.split("\n").slice(0, 3).join("\n");
			const newPreview = newText.split("\n").slice(0, 3).join("\n");
			const summary = `${oldText.length}→${newText.length} chars`;

			const details = `📄 ${path}\n   ${summary}\n\n-${oldPreview}\n+${newPreview}`;
			const allowed = await confirmAction(ctx, "edit", "Edit file", details);
			if (!allowed) {
				return { block: true, reason: "Edit denied by user" };
			}
		}
	});

	// ── Tool: write ──
	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName === "write") {
			const path = (event.input as { path?: string }).path ?? "unknown";
			const content = (event.input as { content?: string }).content ?? "";
			const lineCount = content.split("\n").length;
			const preview = content.split("\n").slice(0, 5).join("\n");

			const details = `📄 ${path}\n   ${lineCount} lines\n\n${preview}`;
			const allowed = await confirmAction(ctx, "write", "Create file", details);
			if (!allowed) {
				return { block: true, reason: "Write denied by user" };
			}
		}
	});

	// ── Tool: read (optional, off by default) ──
	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName === "read" && settings.confirmRead) {
			const path = (event.input as { path?: string }).path ?? "unknown";

			const details = `📄 ${path}`;
			const allowed = await confirmAction(ctx, "read", "Read file", details);
			if (!allowed) {
				return { block: true, reason: "Read denied by user" };
			}
		}
	});

	// ── Tool: bash (dangerous commands only) ──
	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName === "bash") {
			const command = (event.input as { command?: string }).command ?? "";

			if (isDangerousCommand(command)) {
				const details = `💻 ${command.slice(0, 200)}`;
				const allowed = await confirmAction(ctx, "bash", "Dangerous command", details);
				if (!allowed) {
					return { block: true, reason: "Dangerous command denied by user" };
				}
			}
		}
	});

	// ── Command: /perm to view/toggle settings ──
	pi.registerCommand("perm", {
		description: "Show or toggle permission settings. Usage: /perm [read|strict]",
		handler: async (args, ctx) => {
			const arg = args?.trim().toLowerCase();

			if (arg === "read") {
				settings.confirmRead = !settings.confirmRead;
				ctx.ui.notify(
					`Read confirmation: ${settings.confirmRead ? "ON" : "OFF"}`,
					settings.confirmRead ? "warning" : "info",
				);
				return;
			}

			if (arg === "strict") {
				settings.strictMode = !settings.strictMode;
				ctx.ui.notify(
					`Strict mode: ${settings.strictMode ? "ON" : "OFF"} (non-interactive: ${settings.strictMode ? "block" : "allow"})`,
					"info",
				);
				return;
			}

			// Show current settings
			const theme = ctx.ui.theme;
			ctx.ui.notify(
				`🔒 Permissions\n` +
					`  Edit:     ${theme.fg("warning", "ALWAYS ASK")}\n` +
					`  Write:    ${theme.fg("warning", "ALWAYS ASK")}\n` +
					`  Read:     ${settings.confirmRead ? theme.fg("warning", "ASK") : theme.fg("success", "ALLOW")}\n` +
					`  Bash:     ${theme.fg("warning", "DANGEROUS ONLY")}\n` +
					`  Strict:   ${settings.strictMode ? theme.fg("warning", "ON") : theme.fg("success", "OFF")}\n` +
					`\nCommands:\n` +
					`  /perm read    toggle read confirmation\n` +
					`  /perm strict  toggle strict mode`,
				"info",
			);
		},
	});

	// ── Reset settings on session start ──
	pi.on("session_start", async () => {
		settings = { ...DEFAULT_SETTINGS };
	});
}
