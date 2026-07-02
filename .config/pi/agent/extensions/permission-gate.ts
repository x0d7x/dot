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
import { DynamicBorder } from "@earendil-works/pi-coding-agent";
import { Container, Spacer, Text, SelectList } from "@earendil-works/pi-tui";
import * as crypto from "crypto";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

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

interface ActionChoice {
	value: boolean;
	label: string;
	description?: string;
}

const CHOICES: ActionChoice[] = [
	{ value: true, label: "Allow", description: "Approve this operation" },
	{ value: false, label: "Deny", description: "Block this operation" },
];

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

	const title = `🔒 ${toolName.toUpperCase()} — ${action}`;

	return ctx.ui.custom<boolean>((tui, theme, _kb, done) => {
		const container = new Container();
		container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
		container.addChild(new Text(theme.fg("warning", theme.bold(title)), 1, 0));
		container.addChild(new Spacer(1));
		container.addChild(new Text(theme.fg("dim", details), 1, 0));
		container.addChild(new Spacer(1));

		const selectList = new SelectList(CHOICES, 2, {
			selectedPrefix: (t: string) => theme.fg("accent", t),
			selectedText: (t: string) => theme.fg("accent", t),
			description: (t: string) => theme.fg("dim", t),
			scrollInfo: (t: string) => theme.fg("dim", t),
			noMatch: (t: string) => theme.fg("warning", t),
		});
		selectList.onSelect = (item) => done(item.value as boolean);
		selectList.onCancel = () => done(false);
		container.addChild(selectList);

		container.addChild(new Spacer(1));
		container.addChild(new Text(theme.fg("dim", "↑↓/jk navigate  ↵ select  esc = deny"), 1, 0));
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
		overlayOptions: { width: "65%", minWidth: 50, maxHeight: "60%", anchor: "center" },
	});
}

// ── Sudo password state ──────────────────────────────────────────────

let sudoPasswordFile: string | undefined;

function cleanupSudoPassword(): void {
	if (sudoPasswordFile) {
		try {
			fs.unlinkSync(sudoPasswordFile);
		} catch { /* ignore */ }
		sudoPasswordFile = undefined;
	}
}

// ── Password input component ─────────────────────────────────────────

class PasswordInput {
	private buffer: string[] = [];
	onSubmit: ((password: string) => void) | null = null;
	onCancel: (() => void) | null = null;
	private theme: any;

	constructor(theme: any) {
		this.theme = theme;
	}

	handleInput(data: string): void {
		if (data === "\r" || data === "\n") {
			this.onSubmit?.(this.buffer.join(""));
			return;
		}
		if (data === "\x1b" || data === "\x03") {
			this.onCancel?.();
			return;
		}
		if (data === "\x7f" || data === "\b") {
			if (this.buffer.length > 0) this.buffer.pop();
			return;
		}
		// Accept printable characters only
		if (data.length === 1 && data.charCodeAt(0) >= 32 && data.charCodeAt(0) <= 126) {
			this.buffer.push(data);
		}
	}

	render(): string[] {
		const masked = this.buffer.map(() => "*").join("");
		const prompt = "Password: ";
		const cursor = this.theme.fg("accent", "█");
		return [prompt + masked + cursor];
	}

	invalidate(): void {}
}

async function showPasswordOverlay(ctx: any): Promise<string | undefined> {
	if (!ctx.hasUI) return undefined;

	return ctx.ui.custom<string | undefined>((tui, theme, _kb, done) => {
		const container = new Container();
		container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
		container.addChild(new Text(theme.fg("warning", theme.bold("🔑 Sudo Password")), 1, 0));
		container.addChild(new Spacer(1));
		container.addChild(new Text(theme.fg("dim", "Enter your sudo password:"), 1, 0));
		container.addChild(new Spacer(1));

		const pwInput = new PasswordInput(theme);
		container.addChild({
			render: (w: number) => pwInput.render(),
			invalidate: () => pwInput.invalidate(),
			w: 0, h: 1,
		} as any);

		container.addChild(new Spacer(1));
		container.addChild(new Text(theme.fg("dim", "↵ submit  esc = cancel"), 1, 0));
		container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));

		let resolved = false;

		pwInput.onSubmit = (pw) => {
			if (!resolved) { resolved = true; done(pw); }
		};
		pwInput.onCancel = () => {
			if (!resolved) { resolved = true; done(undefined); }
		};

		return {
			render: (w: number) => container.render(w),
			invalidate: () => container.invalidate(),
			handleInput: (d: string) => {
				pwInput.handleInput(d);
				tui.requestRender();
			},
		};
	}, {
		overlay: true,
		overlayOptions: { width: "50%", minWidth: 40, maxHeight: "40%", anchor: "center" },
	});
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

				// If sudo command, ask for password
				if (/\bsudo\b/i.test(command)) {
					const password = await showPasswordOverlay(ctx);
					if (!password) {
						return { block: true, reason: "Sudo password not provided" };
					}

					// Write password to temp file with restricted permissions
					const tmpDir = os.tmpdir();
					const randHex = crypto.randomBytes(12).toString("hex");
					const pwFile = path.join(tmpDir, `.pi-sudo-pw-${randHex}`);
					try {
						fs.writeFileSync(pwFile, password + "\n", { mode: 0o600 });
						sudoPasswordFile = pwFile;

						// Rewrite command to use password from file
						const rest = command.replace(/\bsudo\b/i, "").trim();
						(event.input as any).command = `sudo -S ${rest} < ${pwFile}`;
					} catch (err) {
						return { block: true, reason: `Failed to write sudo password: ${err}` };
					}
				}
			}
		}
	});

	// ── Tool result: cleanup sudo password file ──
	pi.on("tool_result", async (event) => {
		if (event.toolName === "bash") {
			cleanupSudoPassword();
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
