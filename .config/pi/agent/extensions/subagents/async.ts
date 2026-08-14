/**
 * Async run manager for background subagents.
 *
 * A background run is a child `pi` process owned by this extension. The
 * manager persists run metadata + transcript under
 *   ~/.config/pi/agent/state/subagents/runs/<runId>/
 * so runs survive session restarts: on session_start the manager restores
 * active runs by watching their transcript files until `agent_settled`.
 *
 * Background runs are subject to a concurrency limit (maxConcurrency).
 * Excess runs are queued and start as running runs complete.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

export type AsyncRunStatus = "queued" | "running" | "completed" | "failed" | "stopped" | "abandoned";

export interface AsyncRunMeta {
	runId: string;
	agent: string;
	task: string;
	cwd: string;
	model?: string;
	thinking?: string;
	timeoutMs?: number;
	isolation?: string;
	status: AsyncRunStatus;
	startedAt: number;
	endedAt?: number;
	pid?: number;
	exitCode?: number;
	error?: string;
	output?: string;
	usageText?: string;
	parentSession?: string;
	/** Worktree used by this run (for cleanup on restore). */
	worktree?: { repoRoot: string; worktreeDir: string };
}

export interface AsyncLaunchSpec {
	agent: string;
	task: string;
	cwd: string;
	model?: string;
	thinking?: string;
	timeoutMs?: number;
	isolation?: string;
}

export interface AsyncRunResult {
	exitCode: number;
	error?: string;
	output?: string;
	usageText?: string;
	/** Worktree used by this run (for cleanup on restore). */
	worktree?: { repoRoot: string; worktreeDir: string };
}

export interface AsyncLaunchHooks {
	onProcess?: (pid: number) => void;
	onProgress?: (patch: Partial<AsyncRunMeta>) => void;
}

export interface AsyncRunManagerDeps {
	/** Launch the child pi process for this run. Must write the transcript file itself. */
	launch: (
		runId: string,
		spec: AsyncLaunchSpec,
		hooks: AsyncLaunchHooks,
		signal: AbortSignal,
	) => Promise<AsyncRunResult>;
	/** Called when a run transitions out of "running". */
	onFinalize: (runId: string, meta: AsyncRunMeta) => void;
	/** Maximum concurrent background runs. Excess runs are queued. */
	maxConcurrency?: number;
}

export function getStateDir(): string {
	return path.join(getAgentDir(), "state", "subagents");
}

export function getRunsDir(): string {
	return path.join(getStateDir(), "runs");
}

export function runDir(runId: string): string {
	return path.join(getRunsDir(), runId);
}

export function statusFile(runId: string): string {
	return path.join(runDir(runId), "status.json");
}

export function transcriptFile(runId: string): string {
	return path.join(runDir(runId), "transcript.jsonl");
}

function isProcessAlive(pid: number | undefined): boolean {
	if (!pid || pid <= 0) return false;
	try {
		process.kill(pid, 0);
		return true;
	} catch (error) {
		return (error as NodeJS.ErrnoException).code === "EPERM";
	}
}

interface ParsedTranscript {
	output: string;
	usageText: string;
	sawSettled: boolean;
	sawError: boolean;
}

function parseTranscript(filePath: string): ParsedTranscript {
	const result: ParsedTranscript = { output: "", usageText: "", sawSettled: false, sawError: false };
	let content: string;
	try {
		content = fs.readFileSync(filePath, "utf-8");
	} catch {
		return result;
	}

	let finalText = "";
	let finalModel = "";
	for (const line of content.split("\n")) {
		if (!line.trim()) continue;
		let event: any;
		try {
			event = JSON.parse(line);
		} catch {
			continue;
		}
		if (event.type === "agent_settled") result.sawSettled = true;
		if (event.type === "error") result.sawError = true;
		if (event.type === "message_end" && event.message) {
			const msg = event.message;
			if (msg.role === "assistant") {
				for (const part of msg.content ?? []) {
					if (part.type === "text") finalText = part.text;
				}
				if (msg.model) finalModel = msg.model;
			}
		}
		if (event.type === "turn_end" && event.message?.usage) {
			const usage = event.message.usage;
			const total = usage.cost?.total ?? 0;
			const parts: string[] = [];
			if (usage.input) parts.push(`↑${usage.input}`);
			if (usage.output) parts.push(`↓${usage.output}`);
			if (total) parts.push(`$${Number(total).toFixed(4)}`);
			if (parts.length) result.usageText = parts.join(" ");
		}
	}
	result.output = finalText;
	if (finalModel && result.usageText) result.usageText = `${result.usageText} · ${finalModel}`;
	else if (finalModel) result.usageText = finalModel;
	return result;
}

function readMeta(runId: string): AsyncRunMeta | null {
	try {
		const parsed = JSON.parse(fs.readFileSync(statusFile(runId), "utf-8"));
		return parsed && typeof parsed === "object" ? (parsed as AsyncRunMeta) : null;
	} catch {
		return null;
	}
}

const RUN_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;

interface QueuedRun {
	spec: AsyncLaunchSpec;
	meta: AsyncRunMeta;
	parentSession?: string;
}

export class AsyncRunManager {
	private jobs = new Map<string, AsyncRunMeta>();
	private controllers = new Map<string, AbortController>();
	private watchers = new Map<string, NodeJS.Timeout>();
	private queued: QueuedRun[] = [];
	private disposed = false;

	/** Most recent UI context, used for fleet widget + completion notifications. */
	lastUiContext: ExtensionContext | null = null;

	constructor(private deps: AsyncRunManagerDeps) {}

	/** Start a background run (or queue it when at the concurrency limit). Returns the run id immediately. */
	start(spec: AsyncLaunchSpec, parentSession?: string): string {
		const runId = randomUUID();
		const now = Date.now();
		const meta: AsyncRunMeta = {
			runId,
			agent: spec.agent,
			task: spec.task,
			cwd: spec.cwd,
			model: spec.model,
			thinking: spec.thinking,
			timeoutMs: spec.timeoutMs,
			isolation: spec.isolation,
			status: "queued",
			startedAt: now,
			parentSession,
		};
		this.jobs.set(runId, meta);
		this.queued.push({ spec, meta, parentSession });
		this.persist(meta);
		this.maybeLaunchNext();
		return runId;
	}

	private get maxConcurrency(): number {
		return Math.max(1, this.deps.maxConcurrency ?? 4);
	}

	/** Launch queued runs until the concurrency limit is reached. */
	private maybeLaunchNext(): void {
		while (this.queued.length > 0 && this.active().length < this.maxConcurrency) {
			const next = this.queued.shift();
			if (!next) return;
			next.meta.status = "running";
			this.persist(next.meta);
			this.launchRun(next.spec, next.meta, next.parentSession);
		}
	}

	private launchRun(spec: AsyncLaunchSpec, meta: AsyncRunMeta, parentSession?: string): void {
		const runId = meta.runId;
		const controller = new AbortController();
		this.controllers.set(runId, controller);

		void this.deps
			.launch(
				runId,
				spec,
				{
					onProcess: (pid) => {
						const current = this.jobs.get(runId);
						if (current) {
							current.pid = pid;
							this.persist(current);
						}
					},
					onProgress: (patch) => {
						const current = this.jobs.get(runId);
						if (current) {
							Object.assign(current, patch);
							this.persist(current);
						}
					},
				},
				controller.signal,
			)
			.then((result) => {
				const current = this.jobs.get(runId);
				if (!current) return;
				const status: AsyncRunStatus = result.exitCode === 0 ? "completed" : "failed";
				Object.assign(current, {
					status,
					endedAt: Date.now(),
					exitCode: result.exitCode,
					error: result.error,
					output: result.output,
					usageText: result.usageText,
					worktree: result.worktree,
				});
				this.persist(current);
				this.finalize(runId, current);
			})
			.catch((error: unknown) => {
				const current = this.jobs.get(runId);
				if (!current) return;
				Object.assign(current, {
					status: "failed",
					endedAt: Date.now(),
					error: error instanceof Error ? error.message : String(error),
				});
				this.persist(current);
				this.finalize(runId, current);
			});
	}

	/** Stop a queued or running run. */
	stop(runId: string): boolean {
		// Queued runs never launched — just drop from the queue.
		const queuedIndex = this.queued.findIndex((q) => q.meta.runId === runId);
		if (queuedIndex >= 0) {
			this.queued.splice(queuedIndex, 1);
			const meta = this.jobs.get(runId);
			if (meta && meta.status === "queued") {
				meta.status = "stopped";
				meta.endedAt = Date.now();
				this.persist(meta);
				this.finalize(runId, meta);
			}
			return true;
		}

		const controller = this.controllers.get(runId);
		if (!controller) return false;
		controller.abort();
		const meta = this.jobs.get(runId);
		if (meta && meta.status === "running") {
			meta.status = "stopped";
			meta.endedAt = Date.now();
			this.persist(meta);
			this.finalize(runId, meta);
		}
		return true;
	}

	private finalize(runId: string, meta: AsyncRunMeta): void {
		this.controllers.delete(runId);
		this.clearWatcher(runId);
		this.deps.onFinalize(runId, meta);
		// A slot freed up — start the next queued run.
		this.maybeLaunchNext();
	}

	private cleanupWorktree(wt: { repoRoot: string; worktreeDir: string }): void {
		const run = (args: string[]) => {
			try {
				const proc = spawn("git", args, {
					cwd: wt.repoRoot,
					shell: false,
					stdio: "ignore",
				});
				proc.on("error", () => {});
				setTimeout(() => proc.kill("SIGKILL"), 15_000).unref();
			} catch {
				/* best effort */
			}
		};
		try {
			run(["worktree", "remove", "--force", wt.worktreeDir]);
			run(["worktree", "prune"]);
		} catch {
			/* best effort */
		}
	}

	private clearWatcher(runId: string): void {
		const timer = this.watchers.get(runId);
		if (timer) {
			clearInterval(timer);
			this.watchers.delete(runId);
		}
	}

	/** Restore active runs persisted by a previous session. */
	restore(): void {
		if (!fs.existsSync(getRunsDir())) return;
		let entries: fs.Dirent[];
		try {
			entries = fs.readdirSync(getRunsDir(), { withFileTypes: true });
		} catch {
			return;
		}
		const now = Date.now();
		for (const entry of entries) {
			if (!entry.isDirectory()) continue;
			const meta = readMeta(entry.name);
			if (!meta) continue;

			// Queued runs from a previous session: re-queue them.
			if (meta.status === "queued") {
				this.jobs.set(meta.runId, meta);
				this.queued.push({
					spec: {
						agent: meta.agent,
						task: meta.task,
						cwd: meta.cwd,
						model: meta.model,
						thinking: meta.thinking,
						timeoutMs: meta.timeoutMs,
						isolation: meta.isolation,
					},
					meta,
					parentSession: meta.parentSession,
				});
				this.persist(meta);
				continue;
			}

			// Cleanup stale completed runs
			if (meta.status !== "running") {
				const ended = meta.endedAt ?? meta.startedAt;
				if (now - ended > RUN_RETENTION_MS) {
					fs.rmSync(runDir(meta.runId), { recursive: true, force: true });
				}
				continue;
			}

			// A running run from a previous session.
			if (isProcessAlive(meta.pid)) {
				this.jobs.set(meta.runId, meta);
				this.watchTranscript(meta);
			} else {
				meta.status = "abandoned";
				meta.endedAt = now;
				meta.error = "Subagent process terminated while pi was not running.";
				this.persist(meta);
				if (meta.worktree) this.cleanupWorktree(meta.worktree);
			}
		}
		this.maybeLaunchNext();
	}

	private watchTranscript(meta: AsyncRunMeta): void {
		const runId = meta.runId;
		const file = transcriptFile(runId);
		let lastSize = 0;
		try {
			lastSize = fs.existsSync(file) ? fs.statSync(file).size : 0;
		} catch {
			lastSize = 0;
		}

		const check = () => {
			if (this.disposed) return;
			const current = this.jobs.get(runId);
			if (!current || current.status !== "running") return;

			let size = lastSize;
			try {
				size = fs.statSync(file).size;
			} catch {
				// transcript missing; keep waiting a bit
				return;
			}
			if (size <= lastSize) return;
			lastSize = size;

			const parsed = parseTranscript(file);
			if (parsed.output) current.output = parsed.output;
			if (parsed.usageText) current.usageText = parsed.usageText;
			this.persist(current);

			if (parsed.sawSettled) {
				current.status = parsed.sawError ? "failed" : "completed";
				current.endedAt = Date.now();
				current.output = parsed.output;
				current.usageText = parsed.usageText;
				this.persist(current);
				this.finalize(runId, current);
				return;
			}
			// Process died without settling?
			if (current.pid && !isProcessAlive(current.pid)) {
				current.status = "failed";
				current.endedAt = Date.now();
				current.error = "Subagent process exited before settling.";
				this.persist(current);
				this.finalize(runId, current);
			}
		};

		this.watchers.set(runId, setInterval(check, 1500));
	}

	get(runId: string): AsyncRunMeta | undefined {
		return this.jobs.get(runId);
	}

	list(): AsyncRunMeta[] {
		return Array.from(this.jobs.values());
	}

	active(): AsyncRunMeta[] {
		return this.list().filter((m) => m.status === "running");
	}

	queuedRuns(): AsyncRunMeta[] {
		return this.queued.map((q) => q.meta);
	}

	recent(limit = 20): AsyncRunMeta[] {
		return this.list()
			.filter((m) => m.status !== "queued")
			.sort((a, b) => b.startedAt - a.startedAt)
			.slice(0, limit);
	}

	private persist(meta: AsyncRunMeta): void {
		try {
			fs.mkdirSync(runDir(meta.runId), { recursive: true });
			fs.writeFileSync(statusFile(meta.runId), `${JSON.stringify(meta, null, 2)}\n`, "utf-8");
		} catch (error) {
			console.error("[subagents] failed to persist run state:", error);
		}
	}

	dispose(): void {
		this.disposed = true;
		for (const timer of this.watchers.values()) clearInterval(timer);
		this.watchers.clear();
	}
}
