/**
 * Fleet UI: a live widget showing active subagent runs (setWidget), and an
 * interactive inspector for /subagents-fleet (ctx.ui.custom).
 */

import * as fs from "node:fs";
import { matchesKey } from "@earendil-works/pi-tui";
import type { Component } from "@earendil-works/pi-tui";
import type { AsyncRunManager } from "./async.ts";
import { transcriptFile } from "./async.ts";

function formatDuration(ms: number): string {
	const totalSeconds = Math.max(0, Math.floor(ms / 1000));
	if (totalSeconds < 60) return `${totalSeconds}s`;
	const minutes = Math.floor(totalSeconds / 60);
	const seconds = totalSeconds % 60;
	return `${minutes}m${seconds.toString().padStart(2, "0")}s`;
}

function taskPreview(task: string, max = 60): string {
	const oneLine = task.replace(/\s+/g, " ").trim();
	return oneLine.length > max ? `${oneLine.slice(0, max)}...` : oneLine;
}

export interface FleetTheme {
	fg: (color: any, text: string) => string;
}

/**
 * Widget shown while background runs are active.
 * Reads the manager snapshot on every render, so it stays live.
 */
export function createFleetWidget(
	manager: AsyncRunManager,
	theme: FleetTheme,
): Component {
	return {
		invalidate(): void {},
		render(width: number): string[] {
			const runs = manager.active();
			if (runs.length === 0) return [];
	const lines: string[] = [];
		const queued = manager.queuedRuns();
		lines.push(theme.fg("accent", "─ subagents fleet ─"));
		for (const run of runs) {
			const elapsed = Date.now() - run.startedAt;
			lines.push(
				`${theme.fg("warning", "⏳")} ${theme.fg("accent", run.agent)} ${theme.fg("dim", taskPreview(run.task))} ${theme.fg("muted", `· ${formatDuration(elapsed)}`)}`,
			);
		}
		if (queued.length > 0) {
			lines.push(theme.fg("muted", `⏸ ${queued.length} queued (maxConcurrency)`));
		}
		lines.push(theme.fg("muted", `/subagents-fleet to inspect · q in inspector to close`));
		return lines;
		},
	};
}

type InspectorMode = "list" | "transcript";

export class FleetInspector implements Component {
	private mode: InspectorMode = "list";
	private selected = 0;
	private items: { runId: string; label: string }[] = [];
	private transcriptRunId: string | null = null;
	private transcriptLines: string[] = [];
	private cached: string[] = [];
	private cachedWidth = -1;
	private cachedVersion = -1;
	private version = 0;

	constructor(
		private manager: AsyncRunManager,
		private tui: { requestRender: () => void },
		private theme: FleetTheme,
		private onClose: () => void,
	) {
		this.refreshList();
	}

	private refreshList(): void {
		const queued = this.manager.queuedRuns().map((m) => ({
			runId: m.runId,
			label: `⏸ ${m.agent} · queued · ${taskPreview(m.task, 50)}`,
		}));
		const recent = this.manager
			.recent(50)
			.map((m) => ({
				runId: m.runId,
				label: `${m.status === "running" ? "⏳" : m.status === "completed" ? "✓" : "✗"} ${m.agent} · ${taskPreview(m.task, 50)} · ${formatDuration((m.endedAt ?? Date.now()) - m.startedAt)}`,
			}));
		this.items = [...queued, ...recent];
		if (this.selected >= this.items.length) this.selected = Math.max(0, this.items.length - 1);
	}

	private loadTranscript(runId: string): void {
		this.transcriptRunId = runId;
		const meta = this.manager.get(runId);
		const file = transcriptFile(runId);
		const lines: string[] = [];
		try {
			const raw = fs.readFileSync(file, "utf-8").split("\n");
			for (const line of raw) {
				if (!line.trim()) continue;
				let event: any;
				try {
					event = JSON.parse(line);
				} catch {
					continue;
				}
				if (event.type === "message_end" && event.message) {
					const msg = event.message;
					if (msg.role === "user") {
						const text = msg.content?.map((p: any) => p.text ?? "").join(" ");
						lines.push(`> ${text}`);
					} else if (msg.role === "assistant") {
						for (const part of msg.content ?? []) {
							if (part.type === "text") lines.push(`✎ ${part.text}`);
						}
					}
				} else if (event.type === "tool_execution_end") {
					const out = event.result?.content
						?.filter((c: any) => c.type === "text")
						.map((c: any) => c.text)
						.join(" ")
						.trim();
					const preview = out ? ` ${taskPreview(out, 80)}` : "";
					lines.push(`→ ${event.toolName}${preview}`);
				}
			}
		} catch {
			lines.push("(transcript unavailable)");
		}
		if (meta?.output) lines.push("", "── final output ──", meta.output);
		if (meta?.error) lines.push("", `error: ${meta.error}`);
		this.transcriptLines = lines.slice(-500);
	}

	handleInput(data: string): void {
		if (matchesKey(data, "escape") || data === "q" || data === "Q") {
			if (this.mode === "transcript") {
				this.mode = "list";
				this.version++;
				this.tui.requestRender();
				return;
			}
			this.onClose();
			return;
		}
		if (this.mode === "transcript") {
			if (data === "b" || data === "B" || matchesKey(data, "backspace")) {
				this.mode = "list";
				this.version++;
				this.tui.requestRender();
			}
			return;
		}
		if (data === "r" || data === "R") {
			this.refreshList();
			this.version++;
			this.tui.requestRender();
			return;
		}
		if (matchesKey(data, "up") || data === "k" || data === "K") {
			if (this.selected > 0) {
				this.selected--;
				this.version++;
				this.tui.requestRender();
			}
			return;
		}
		if (matchesKey(data, "down") || data === "j" || data === "J") {
			if (this.selected < this.items.length - 1) {
				this.selected++;
				this.version++;
				this.tui.requestRender();
			}
			return;
		}
		if (matchesKey(data, "enter") || data === " ") {
			const item = this.items[this.selected];
			if (item) {
				this.loadTranscript(item.runId);
				this.mode = "transcript";
				this.version++;
				this.tui.requestRender();
			}
			return;
		}
		if (data === "s" || data === "S") {
			const item = this.items[this.selected];
			if (item) {
				this.manager.stop(item.runId);
				this.refreshList();
				this.version++;
				this.tui.requestRender();
			}
		}
	}

	invalidate(): void {}

	render(width: number): string[] {
		if (width === this.cachedWidth && this.version === this.cachedVersion) {
			return this.cached;
		}
		this.cachedWidth = width;
		this.cachedVersion = this.version;
		const theme = this.theme;

		if (this.mode === "transcript") {
			const lines: string[] = [
				theme.fg("accent", `╭ transcript: ${this.transcriptRunId?.slice(0, 8) ?? "?"} ╮`),
			];
			for (const line of this.transcriptLines) {
				lines.push(`│ ${line}`.slice(0, Math.max(1, width - 2)));
			}
			lines.push(theme.fg("muted", "╰ [b] back · [esc/q] close ╯"));
			return lines;
		}

		const lines: string[] = [theme.fg("accent", `╭ subagents fleet (${this.items.length}) ╮`)];
		if (this.items.length === 0) {
			lines.push(theme.fg("muted", "│ no runs"));
		} else {
			for (let i = 0; i < this.items.length; i++) {
				const marker = i === this.selected ? theme.fg("warning", "▶") : " ";
				lines.push(`${marker} ${this.items[i].label}`.slice(0, Math.max(1, width - 2)));
			}
		}
		lines.push(theme.fg("muted", "╰ ↑/↓ select · enter view · s stop · r refresh · q close ╯"));
		return lines;
	}
}

export function openFleetInspector(
	manager: AsyncRunManager,
	tui: { requestRender: () => void },
	theme: FleetTheme,
	onClose: () => void,
): Component {
	return new FleetInspector(manager, tui, theme, onClose);
}
