/**
 * Hunk diff integration for Pi
 *
 * Shows beautiful colored diffs inline in Pi's UI when files change,
 * and provides /hunk command to open full review in the external hunk app.
 *
 * Features:
 *   - Colored hunk diff inline in edit tool results (Ctrl+E to expand)
 *   - Diff stats: +N / -M in collapsed view
 *   - /hunk [last|staged|diff] — open in external hunk TUI
 */

import type { ExtensionAPI, EditToolDetails } from "@earendil-works/pi-coding-agent";
import { createEditTool, createWriteTool } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { writeFile, unlink } from "node:fs/promises";

export default function (pi: ExtensionAPI) {
	const cwd = process.cwd();
	let lastPatch: string | null = null;

	// ── Capture last patch for /hunk command ──
	pi.on("tool_result", async (event, _ctx) => {
		const msg = event as unknown as { toolName?: string; details?: { patch?: string } };
		if (msg.toolName === "edit" && msg.details?.patch) {
			lastPatch = msg.details.patch;
		}
	});

	// ── /hunk command (external app) ──
	pi.registerCommand("hunk", {
		description: "View diffs in external hunk TUI (usage: /hunk [last|staged|diff])",
		handler: async (args, ctx) => {
			const arg = args.trim().toLowerCase();

			try {
				if (arg === "staged") {
					await pi.exec("hunk", ["diff", "--staged"], { env: process.env });
				} else if (arg === "diff" || arg === "working") {
					await pi.exec("hunk", ["diff"], { env: process.env });
				} else if (arg === "" || arg === "last") {
					if (!lastPatch) {
						ctx.ui.notify("No recent edits. Try /hunk diff or /hunk staged", "warning");
						return;
					}

					const tmpFile = `/tmp/pi-hunk-patch-${Date.now()}.patch`;
					await writeFile(tmpFile, lastPatch, "utf-8");
					await pi.exec("hunk", ["patch", tmpFile], { env: process.env });
					try { await unlink(tmpFile); } catch {}
				} else {
					ctx.ui.notify("Usage: /hunk [last|staged|diff]", "warning");
				}
			} catch (err: any) {
				ctx.ui.notify(`hunk error: ${err.message}`, "error");
			}
		},
	});

	// ── Inline colored hunk rendering for edit tool ──
	const originalEdit = createEditTool(cwd);
	pi.registerTool({
		name: "edit",
		label: "edit",
		description: originalEdit.description,
		parameters: originalEdit.parameters,

		async execute(toolCallId, params, signal, onUpdate) {
			return originalEdit.execute(toolCallId, params, signal, onUpdate);
		},

		renderCall(args, theme, _context) {
			const path = theme.fg("accent", args.path);
			const oldLen = args.oldText?.length ?? 0;
			const newLen = args.newText?.length ?? 0;
			return new Text(
				`${theme.fg("toolTitle", theme.bold("hunk "))}${path}${theme.fg("dim", ` (~${oldLen}→~${newLen} chars)`)}`,
				0,
				0,
			);
		},

		renderResult(result, { expanded, isPartial }, theme, _context) {
			if (isPartial) {
				return new Text(theme.fg("warning", "Applying hunk..."), 0, 0);
			}

			const details = result.details as EditToolDetails | undefined;
			const content = result.content[0];

			if (content?.type === "text" && content.text.startsWith("Error")) {
				return new Text(theme.fg("error", `✗ ${content.text}`), 0, 0);
			}

			if (!details?.diff) {
				return new Text(theme.fg("success", "✓ Applied"), 0, 0);
			}

			const diffLines = details.diff.split("\n");

			// Count stats
			let additions = 0;
			let removals = 0;
			for (const line of diffLines) {
				if (line.startsWith("+") && !line.startsWith("+++")) additions++;
				if (line.startsWith("-") && !line.startsWith("---")) removals++;
			}

			// Always show full colored diff
			let text = theme.fg("toolTitle", theme.bold(" hunk ")) + theme.fg("success", `+${additions}`) + theme.fg("dim", " / ") + theme.fg("error", `-${removals}`);
			const maxLines = 50;
			let shown = 0;

			for (const rawLine of diffLines) {
				if (shown >= maxLines) {
					text += `\n${theme.fg("muted", `  ... ${diffLines.length - shown} more lines`)}`;
					break;
				}

				const line = rawLine.replace(/\r$/, "");

				if (line.startsWith("--- ") || line.startsWith("+++ ")) {
					if (line.startsWith("+++ ")) {
						const filePath = line.slice(6).replace(/^[ab]\//, "");
						text += `\n${theme.fg("borderMuted", "─".repeat(4))} ${theme.fg("accent", filePath)}`;
					}
					continue;
				}

				if (line.startsWith("@@ ")) {
					const match = line.match(/^@@\s+-\d+(?:,\d+)?\s+\+(\d+)(?:,\d+)?\s+@@\s*(.*)/);
					const lineNum = match?.[1] ?? "";
					const context = match?.[2]?.trim() ?? "";
					const header = context
						? ` @@ -${lineNum} @@  ${context}`
						: ` @@ -${lineNum} @@`;
					text += `\n${theme.fg("accent", header)}`;
					shown++;
					continue;
				}

				if (line.startsWith("+")) {
					text += `\n${theme.fg("success", `+ ${line.slice(1)}`)}`;
					shown++;
				} else if (line.startsWith("-")) {
					text += `\n${theme.fg("error", `- ${line.slice(1)}`)}`;
					shown++;
				} else if (line.startsWith(" ")) {
					text += `\n${theme.fg("dim", `  ${line.slice(1)}`)}`;
					shown++;
				} else if (line.startsWith("\\")) {
					text += `\n${theme.fg("warning", `  ${line.slice(0, 60)}`)}`;
					shown++;
				} else if (line) {
					text += `\n${theme.fg("dim", `  ${line}`)}`;
					shown++;
				}
			}

			return new Text(text, 0, 0);
		},
	});

	// ── Also enhance write tool ──
	const originalWrite = createWriteTool(cwd);
	pi.registerTool({
		name: "write",
		label: "write",
		description: originalWrite.description,
		parameters: originalWrite.parameters,

		async execute(toolCallId, params, signal, onUpdate) {
			return originalWrite.execute(toolCallId, params, signal, onUpdate);
		},

		renderCall(args, theme, _context) {
			const path = theme.fg("accent", args.path);
			const lineCount = args.content.split("\n").length;
			return new Text(
				`${theme.fg("toolTitle", theme.bold("write "))}${path}${theme.fg("dim", ` (${lineCount} lines)`)}`,
				0,
				0,
			);
		},

		renderResult(result, { isPartial, expanded }, theme, _context) {
			if (isPartial) return new Text(theme.fg("warning", "Writing..."), 0, 0);

			const content = result.content[0];
			if (content?.type === "text" && content.text.startsWith("Error")) {
				return new Text(theme.fg("error", content.text.split("\n")[0]), 0, 0);
			}

			let text = theme.fg("success", "✨ Created");

			if (expanded && content?.type === "text") {
				const lines = content.text.split("\n").slice(0, 20);
				for (const line of lines) {
					text += `\n${theme.fg("success", `+ ${line}`)}`;
				}
				if (content.text.split("\n").length > 20) {
					text += `\n${theme.fg("muted", `... ${content.text.split("\n").length - 20} more lines`)}`;
				}
			}

			return new Text(text, 0, 0);
		},
	});
}
