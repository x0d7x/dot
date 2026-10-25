/**
 * Subagents - delegate work to focused child pi processes.
 *
 * A "subagent" is a separate `pi` process with its own isolated context, an
 * agent-defined system prompt, a tool allowlist, and an optional model/thinking
 * override. The parent session stays in control; the subagent reports back.
 *
 * Modes:
 *   - single:        { agent, task }                       (foreground or async)
 *   - parallel:      { tasks: [{agent, task}, ...] }       (foreground)
 *   - chain:         { chain: [{agent, task}, ...] }       (foreground, {previous} passing)
 *   - workflowScript: { workflowScript, async? }           (scripted orchestration)
 *
 * Async runs are tracked, persisted under
 *   ~/.config/pi/agent/state/subagents/runs/<runId>/
 * restored across restarts, shown in a live fleet widget, and reported with a
 * completion summary via a custom notification message.
 *
 * Children launch with `--no-extensions` and an explicit extension allowlist
 * (all user extensions except permission-gate, which would block edits in
 * non-interactive children), and never re-register this extension
 * (PI_SUBAGENTS_CHILD=1), preventing subagent-in-subagent recursion.
 */

import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { AgentToolResult } from "@earendil-works/pi-agent-core";
import type { Message } from "@earendil-works/pi-ai";
import { StringEnum } from "@earendil-works/pi-ai";
import {
	CONFIG_DIR_NAME,
	defineTool,
	type ExtensionAPI,
	getAgentDir,
	getMarkdownTheme,
	withFileMutationQueue,
} from "@earendil-works/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { type AgentConfig, type AgentScope, discoverAgents, findAgent } from "./agents.ts";
import {
	AsyncRunManager,
	getRunsDir,
	transcriptFile,
	type AsyncRunMeta,
	type AsyncRunResult,
} from "./async.ts";
import { createFleetWidget, openFleetInspector } from "./fleet.ts";

const MAX_PARALLEL_TASKS = 8;
const DEFAULT_CONCURRENCY = 4;
const COLLAPSED_ITEM_COUNT = 10;
const PER_TASK_OUTPUT_CAP = 50 * 1024;
const DEFAULT_TIMEOUT_MS = 30 * 60 * 1000;
const TASK_ARG_LIMIT = 8000;
const CHILD_ENV = "PI_SUBAGENTS_CHILD";
const NOTIFY_TYPE = "subagents-notify";
const LIST_TYPE = "subagents-list";
const WIDGET_KEY = "subagents-fleet";
const THINKING_LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"];

/* ------------------------------------------------------------------ */
/* Config                                                              */
/* ------------------------------------------------------------------ */

interface ExtensionConfig {
	asyncByDefault?: boolean;
	maxConcurrency?: number;
	maxParallelTasks?: number;
	fleetWidget?: boolean;
	/** Absolute path for isolated git worktrees. Defaults to <repoRoot>/.pi-subagents-worktrees */
	worktreesDir?: string;
}

function loadConfig(): ExtensionConfig {
	try {
		const p = path.join(__dirname, "config.json");
		if (fs.existsSync(p)) {
			const parsed = JSON.parse(fs.readFileSync(p, "utf-8"));
			if (parsed && typeof parsed === "object") return parsed as ExtensionConfig;
		}
	} catch (error) {
		console.error("[subagents] failed to load config.json:", error);
	}
	return {};
}

/* ------------------------------------------------------------------ */
/* Small formatting helpers                                            */
/* ------------------------------------------------------------------ */

function formatTokens(count: number): string {
	if (count < 1000) return count.toString();
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	return `${(count / 1000000).toFixed(1)}M`;
}

function formatUsageStats(
	usage: {
		input: number;
		output: number;
		cacheRead: number;
		cacheWrite: number;
		cost: number;
		contextTokens?: number;
		turns?: number;
	},
	model?: string,
): string {
	const parts: string[] = [];
	if (usage.turns) parts.push(`${usage.turns} turn${usage.turns > 1 ? "s" : ""}`);
	if (usage.input) parts.push(`↑${formatTokens(usage.input)}`);
	if (usage.output) parts.push(`↓${formatTokens(usage.output)}`);
	if (usage.cacheRead) parts.push(`R${formatTokens(usage.cacheRead)}`);
	if (usage.cacheWrite) parts.push(`W${formatTokens(usage.cacheWrite)}`);
	if (usage.cost) parts.push(`$${usage.cost.toFixed(4)}`);
	if (usage.contextTokens && usage.contextTokens > 0) {
		parts.push(`ctx:${formatTokens(usage.contextTokens)}`);
	}
	if (model) parts.push(model);
	return parts.join(" ");
}

function formatToolCall(
	toolName: string,
	args: Record<string, unknown>,
	themeFg: (color: any, text: string) => string,
): string {
	const shortenPath = (p: string) => {
		const home = os.homedir();
		return p.startsWith(home) ? `~${p.slice(home.length)}` : p;
	};

	switch (toolName) {
		case "bash": {
			const command = (args.command as string) || "...";
			const preview = command.length > 60 ? `${command.slice(0, 60)}...` : command;
			return themeFg("muted", "$ ") + themeFg("toolOutput", preview);
		}
		case "read": {
			const rawPath = (args.file_path || args.path || "...") as string;
			const filePath = shortenPath(rawPath);
			const offset = args.offset as number | undefined;
			const limit = args.limit as number | undefined;
			let text = themeFg("accent", filePath);
			if (offset !== undefined || limit !== undefined) {
				const startLine = offset ?? 1;
				const endLine = limit !== undefined ? startLine + limit - 1 : "";
				text += themeFg("warning", `:${startLine}${endLine ? `-${endLine}` : ""}`);
			}
			return themeFg("muted", "read ") + text;
		}
		case "write": {
			const rawPath = (args.file_path || args.path || "...") as string;
			const filePath = shortenPath(rawPath);
			const content = (args.content || "") as string;
			const lines = content.split("\n").length;
			let text = themeFg("muted", "write ") + themeFg("accent", filePath);
			if (lines > 1) text += themeFg("dim", ` (${lines} lines)`);
			return text;
		}
		case "edit": {
			const rawPath = (args.file_path || args.path || "...") as string;
			return themeFg("muted", "edit ") + themeFg("accent", shortenPath(rawPath));
		}
		case "ls": {
			const rawPath = (args.path || ".") as string;
			return themeFg("muted", "ls ") + themeFg("accent", shortenPath(rawPath));
		}
		case "find": {
			const pattern = (args.pattern || "*") as string;
			const rawPath = (args.path || ".") as string;
			return themeFg("muted", "find ") + themeFg("accent", pattern) + themeFg("dim", ` in ${shortenPath(rawPath)}`);
		}
		case "grep": {
			const pattern = (args.pattern || "") as string;
			const rawPath = (args.path || ".") as string;
			return (
				themeFg("muted", "grep ") +
				themeFg("accent", `/${pattern}/`) +
				themeFg("dim", ` in ${shortenPath(rawPath)}`)
			);
		}
		default: {
			const argsStr = JSON.stringify(args);
			const preview = argsStr.length > 50 ? `${argsStr.slice(0, 50)}...` : argsStr;
			return themeFg("accent", toolName) + themeFg("dim", ` ${preview}`);
		}
	}
}

interface UsageStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	contextTokens: number;
	turns: number;
}

function emptyUsage(): UsageStats {
	return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 };
}

function taskPreview(task: string, max = 80): string {
	const oneLine = task.replace(/\s+/g, " ").trim();
	return oneLine.length > max ? `${oneLine.slice(0, max)}...` : oneLine;
}

interface SingleResult {
	agent: string;
	agentSource: "builtin" | "user" | "project" | "unknown";
	task: string;
	exitCode: number;
	messages: Message[];
	stderr: string;
	usage: UsageStats;
	model?: string;
	stopReason?: string;
	errorMessage?: string;
	step?: number;
	asyncStarted?: boolean;
	runId?: string;
	/** Set when the run used an isolated worktree. */
	worktree?: { repoRoot: string; worktreeDir: string };
}

interface SubagentDetails {
	mode: "single" | "parallel" | "chain" | "workflow";
	agentScope: AgentScope;
	projectAgentsDir: string | null;
	results: SingleResult[];
	async?: boolean;
}

function getFinalOutput(messages: Message[]): string {
	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i];
		if (msg.role === "assistant") {
			for (const part of msg.content) {
				if (part.type === "text") return part.text;
			}
		}
	}
	return "";
}

function isFailedResult(result: SingleResult): boolean {
	return result.exitCode !== 0 || result.stopReason === "error" || result.stopReason === "aborted";
}

function getResultOutput(result: SingleResult): string {
	if (isFailedResult(result)) {
		return result.errorMessage || result.stderr || getFinalOutput(result.messages) || "(no output)";
	}
	return getFinalOutput(result.messages) || "(no output)";
}

function truncateParallelOutput(output: string): string {
	const byteLength = Buffer.byteLength(output, "utf8");
	if (byteLength <= PER_TASK_OUTPUT_CAP) return output;

	let truncated = output.slice(0, PER_TASK_OUTPUT_CAP);
	while (Buffer.byteLength(truncated, "utf8") > PER_TASK_OUTPUT_CAP) {
		truncated = truncated.slice(0, -1);
	}
	return `${truncated}\n\n[Output truncated: ${byteLength - Buffer.byteLength(truncated, "utf8")} bytes omitted. Full output preserved in tool details.]`;
}

type DisplayItem = { type: "text"; text: string } | { type: "toolCall"; name: string; args: Record<string, any> };

function getDisplayItems(messages: Message[]): DisplayItem[] {
	const items: DisplayItem[] = [];
	for (const msg of messages) {
		if (msg.role === "assistant") {
			for (const part of msg.content) {
				if (part.type === "text") items.push({ type: "text", text: part.text });
				else if (part.type === "toolCall") items.push({ type: "toolCall", name: part.name, args: part.arguments });
			}
		}
	}
	return items;
}

function usageToString(usage: UsageStats, model?: string): string {
	return formatUsageStats(usage, model);
}

async function mapWithConcurrencyLimit<TIn, TOut>(
	items: TIn[],
	concurrency: number,
	fn: (item: TIn, index: number) => Promise<TOut>,
): Promise<TOut[]> {
	if (items.length === 0) return [];
	const limit = Math.max(1, Math.min(concurrency, items.length));
	const results: TOut[] = new Array(items.length);
	let nextIndex = 0;
	const workers = new Array(limit).fill(null).map(async () => {
		while (true) {
			const current = nextIndex++;
			if (current >= items.length) return;
			results[current] = await fn(items[current], current);
		}
	});
	await Promise.all(workers);
	return results;
}

async function writePromptToTempFile(agentName: string, prompt: string): Promise<{ dir: string; filePath: string }> {
	const tmpDir = await fs.promises.mkdtemp(path.join(os.tmpdir(), "pi-subagent-"));
	const safeName = agentName.replace(/[^\w.-]+/g, "_");
	const filePath = path.join(tmpDir, `prompt-${safeName}.md`);
	await withFileMutationQueue(filePath, async () => {
		await fs.promises.writeFile(filePath, prompt, { encoding: "utf-8", mode: 0o600 });
	});
	return { dir: tmpDir, filePath };
}

/* ------------------------------------------------------------------ */
/* pi CLI resolution and child process launch                          */
/* ------------------------------------------------------------------ */

function getPiInvocation(args: string[]): { command: string; args: string[] } {
	const currentScript = process.argv[1];
	const isBunVirtualScript = currentScript?.startsWith("/$bunfs/root/");
	if (currentScript && !isBunVirtualScript && fs.existsSync(currentScript)) {
		return { command: process.execPath, args: [currentScript, ...args] };
	}

	const execName = path.basename(process.execPath).toLowerCase();
	const isGenericRuntime = /^(node|bun)(\.exe)?$/.test(execName);
	if (!isGenericRuntime) {
		return { command: process.execPath, args };
	}

	return { command: "pi", args };
}

function applyThinkingSuffix(model: string | undefined, thinking: string | undefined): string | undefined {
	if (!model || !thinking) return model;
	const colonIdx = model.lastIndexOf(":");
	const suffix = model.slice(colonIdx + 1);
	if (THINKING_LEVELS.includes(suffix)) {
		return `${model.slice(0, colonIdx)}:${thinking}`;
	}
	return `${model}:${thinking}`;
}

/* ------------------------------------------------------------------ */
/* Git worktree isolation                                             */
/* ------------------------------------------------------------------ */

interface WorktreeInfo {
	repoRoot: string;
	worktreeDir: string;
	baseCommit: string;
	branch: string;
	commit: string;
	changedFiles: number;
}

const GIT_TIMEOUT_MS = 60_000;

function runGit(args: string[], cwd: string): Promise<{ code: number; stdout: string; stderr: string }> {
	return new Promise((resolve) => {
		const proc = spawn("git", args, { cwd, shell: false, stdio: ["ignore", "pipe", "pipe"] });
		let stdout = "";
		let stderr = "";
		proc.stdout.on("data", (d) => (stdout += d.toString()));
		proc.stderr.on("data", (d) => (stderr += d.toString()));
		const timer = setTimeout(() => proc.kill("SIGKILL"), GIT_TIMEOUT_MS);
		proc.on("close", (code) => {
			clearTimeout(timer);
			resolve({ code: code ?? 1, stdout: stdout.trim(), stderr: stderr.trim() });
		});
		proc.on("error", (error) => {
			clearTimeout(timer);
			resolve({ code: 1, stdout: "", stderr: String(error) });
		});
	});
}

/**
 * Create (or reuse) an isolated worktree for a run at
 * <worktreesDir>/<key>, checked out at the repo's current HEAD.
 * When worktreesDir is not configured, worktrees are created under
 * <repoRoot>/.pi-subagents-worktrees.
 */
async function setupWorktree(
	key: string,
	cwd: string,
	configuredWorktreesDir: string | undefined,
): Promise<WorktreeInfo> {
	const root = await runGit(["rev-parse", "--show-toplevel"], cwd);
	if (root.code !== 0 || !root.stdout) {
		throw new Error(`isolation:worktree requires a git repository at "${cwd}": ${root.stderr || "not a git repository"}`);
	}
	const repoRoot = root.stdout;

	const head = await runGit(["rev-parse", "HEAD"], repoRoot);
	if (head.code !== 0 || !head.stdout) {
		throw new Error(`isolation:worktree: cannot resolve HEAD in ${repoRoot}: ${head.stderr}`);
	}
	const baseCommit = head.stdout;

	const worktreesDir = configuredWorktreesDir ?? path.join(repoRoot, ".pi-subagents-worktrees");
	fs.mkdirSync(worktreesDir, { recursive: true });
	const worktreeDir = path.join(worktreesDir, key);
	if (!fs.existsSync(path.join(worktreeDir, ".git"))) {
		const add = await runGit(["worktree", "add", "--detach", worktreeDir, baseCommit], repoRoot);
		if (add.code !== 0) {
			throw new Error(`isolation:worktree: git worktree add failed: ${add.stderr || add.stdout}`);
		}
	}
	return { repoRoot, worktreeDir, baseCommit, branch: "", commit: baseCommit, changedFiles: 0 };
}

/** Commit any changes to a branch and remove the worktree. Best-effort. */
async function finalizeWorktree(
	info: WorktreeInfo,
	agentName: string,
	taskPreview: string,
	failed: boolean,
): Promise<void> {
	try {
		const status = await runGit(["status", "--porcelain"], info.worktreeDir);
		const changed = status.stdout ? status.stdout.split("\n").filter(Boolean) : [];
		info.changedFiles = changed.length;

		if (changed.length > 0) {
			const safeAgent = agentName.toLowerCase().replace(/[^\w.-]+/g, "-").replace(/-+/g, "-").slice(0, 40);
			const runKey = path.basename(info.worktreeDir).replace(/[^\w.-]+/g, "").slice(0, 8) || "run";
			const branchName = `pi-subagent/${safeAgent}-${info.baseCommit.slice(0, 7)}-${runKey}`;
			await runGit(["checkout", "-b", branchName], info.worktreeDir);
			await runGit(["add", "-A"], info.worktreeDir);
			const message = (failed ? `subagent: ${agentName} (failed) — ` : `subagent: ${agentName} — `) + taskPreview;
			const commit = await runGit(["commit", "-m", message.slice(0, 200)], info.worktreeDir);
			if (commit.code === 0) {
				info.branch = branchName;
				const rev = await runGit(["rev-parse", "HEAD"], info.worktreeDir);
				if (rev.code === 0 && rev.stdout) info.commit = rev.stdout;
			}
		}
	} catch {
		/* keep going — cleanup must still run */
	}
	try {
		await runGit(["worktree", "remove", "--force", info.worktreeDir], info.repoRoot);
		await runGit(["worktree", "prune"], info.repoRoot);
	} catch {
		/* best effort */
	}
}

/**
 * Children launch with --no-extensions plus an explicit allowlist so that:
 *  - permission-gate (strict mode blocks edits without UI) is excluded
 *  - web_search / web_fetch etc. (from web-access.ts) still work
 *  - this extension is excluded (its factory no-ops in children anyway)
 */
function getChildExtensionArgs(): string[] {
	const extDir = path.join(getAgentDir(), "extensions");
	const excluded = new Set(["permission-gate.ts", "subagents"]);
	const args: string[] = [];
	if (!fs.existsSync(extDir)) return args;
	let entries: fs.Dirent[];
	try {
		entries = fs.readdirSync(extDir, { withFileTypes: true });
	} catch {
		return args;
	}
	for (const entry of entries) {
		if (excluded.has(entry.name)) continue;
		if (entry.name.endsWith(".ts") && entry.isFile()) {
			args.push("--extension", path.join(extDir, entry.name));
		} else if (entry.isDirectory()) {
			const indexPath = path.join(extDir, entry.name, "index.ts");
			if (fs.existsSync(indexPath)) args.push("--extension", indexPath);
		}
	}
	return args;
}

export interface RunSingleAgentOptions {
	defaultCwd: string;
	agents: AgentConfig[];
	agentName: string;
	task: string;
	cwd?: string;
	step?: number;
	model?: string;
	thinking?: string;
	timeoutMs?: number;
	isolation?: string;
	signal?: AbortSignal;
	onUpdate?: (partial: AgentToolResult<SubagentDetails>) => void;
	makeDetails: (results: SingleResult[]) => SubagentDetails;
	transcriptPath?: string;
	onProcess?: (pid: number) => void;
	/** Directory for isolated worktrees (from config). */
	worktreesDir?: string;
}

async function runSingleAgent(opts: RunSingleAgentOptions): Promise<SingleResult> {
	const { agents, agentName } = opts;
	const agent = findAgent(agents, agentName);

	if (!agent) {
		const available = agents.map((a) => `"${a.name}"`).join(", ") || "none";
		return {
			agent: agentName,
			agentSource: "unknown",
			task: opts.task,
			exitCode: 1,
			messages: [],
			stderr: `Unknown agent: "${agentName}". Available agents: ${available}.`,
			usage: emptyUsage(),
			step: opts.step,
		};
	}

	const modelArg = applyThinkingSuffix(opts.model ?? agent.model, opts.thinking ?? agent.thinking);
	const args: string[] = ["--mode", "json", "-p", "--no-session", "--no-extensions"];
	if (modelArg) args.push("--model", modelArg);
	if (agent.tools && agent.tools.length > 0) args.push("--tools", agent.tools.join(","));
	args.push(...getChildExtensionArgs());

	let tmpPromptDir: string | null = null;
	let tmpPromptPath: string | null = null;

	const currentResult: SingleResult = {
		agent: agentName,
		agentSource: agent.source,
		task: opts.task,
		exitCode: 0,
		messages: [],
		stderr: "",
		usage: emptyUsage(),
		model: modelArg,
		step: opts.step,
	};

	const emitUpdate = () => {
		opts.onUpdate?.({
			content: [{ type: "text", text: getFinalOutput(currentResult.messages) || "(running...)" }],
			details: opts.makeDetails([currentResult]),
		});
	};

	/* ----- worktree isolation ----- */
	const isolation = opts.isolation === "worktree" ? ("worktree" as const) : agent.isolation;
	let childCwd = opts.cwd ?? opts.defaultCwd;
	let worktree: WorktreeInfo | null = null;
	if (isolation === "worktree") {
		const key =
			opts.transcriptPath
				? path.basename(path.dirname(opts.transcriptPath))
				: `wt-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
		try {
			worktree = await setupWorktree(key, childCwd, opts.worktreesDir);
			const rel = path.relative(worktree.repoRoot, childCwd);
			childCwd =
				rel && !rel.startsWith("..") && !path.isAbsolute(rel)
					? path.join(worktree.worktreeDir, rel)
					: worktree.worktreeDir;
		} catch (error) {
			return {
				agent: agentName,
				agentSource: agent.source,
				task: opts.task,
				exitCode: 1,
				messages: [],
				stderr: error instanceof Error ? error.message : String(error),
				usage: emptyUsage(),
				step: opts.step,
			};
		}
	}

	try {
		if (agent.systemPrompt.trim()) {
			const tmp = await writePromptToTempFile(agent.name, agent.systemPrompt);
			tmpPromptDir = tmp.dir;
			tmpPromptPath = tmp.filePath;
			args.push("--append-system-prompt", tmpPromptPath);
		}

		if (opts.task.length > TASK_ARG_LIMIT) {
			const taskFile = path.join(tmpPromptDir ?? os.tmpdir(), `task-${Date.now()}.md`);
			await withFileMutationQueue(taskFile, async () => {
				await fs.promises.writeFile(taskFile, `Task: ${opts.task}`, { encoding: "utf-8", mode: 0o600 });
			});
			args.push(`@${taskFile}`);
		} else {
			args.push(`Task: ${opts.task}`);
		}

		let wasAborted = false;
		let timedOut = false;
		let timeoutTimer: NodeJS.Timeout | null = null;

		const exitCode = await new Promise<number>((resolve) => {
			const invocation = getPiInvocation(args);
			const env = { ...process.env, [CHILD_ENV]: "1" };
			const proc = spawn(invocation.command, invocation.args, {
				cwd: childCwd,
				env,
				shell: false,
				stdio: ["ignore", "pipe", "pipe"],
			});
			opts.onProcess?.(proc.pid ?? 0);
			let buffer = "";

			const processLine = (line: string) => {
				if (!line.trim()) return;
				let event: any;
				try {
					event = JSON.parse(line);
				} catch {
					return;
				}
				if (opts.transcriptPath) {
					try {
						fs.appendFileSync(opts.transcriptPath, `${line}\n`);
					} catch {
						/* best effort */
					}
				}

				if (event.type === "message_end" && event.message) {
					const msg = event.message as Message;
					currentResult.messages.push(msg);

					if (msg.role === "assistant") {
						currentResult.usage.turns++;
						const usage = msg.usage;
						if (usage) {
							currentResult.usage.input += usage.input || 0;
							currentResult.usage.output += usage.output || 0;
							currentResult.usage.cacheRead += usage.cacheRead || 0;
							currentResult.usage.cacheWrite += usage.cacheWrite || 0;
							currentResult.usage.cost += usage.cost?.total || 0;
							currentResult.usage.contextTokens = usage.totalTokens || 0;
						}
						if (!currentResult.model && msg.model) currentResult.model = msg.model;
						if (msg.stopReason) currentResult.stopReason = msg.stopReason;
						if (msg.errorMessage) currentResult.errorMessage = msg.errorMessage;
					}
					emitUpdate();
				}

				if (event.type === "tool_result_end" && event.message) {
					currentResult.messages.push(event.message as Message);
					emitUpdate();
				}
			};

			proc.stdout.on("data", (data) => {
				buffer += data.toString();
				const lines = buffer.split("\n");
				buffer = lines.pop() || "";
				for (const line of lines) processLine(line);
			});

			proc.stderr.on("data", (data) => {
				currentResult.stderr += data.toString();
			});

			proc.on("close", (code) => {
				if (buffer.trim()) processLine(buffer);
				if (timeoutTimer) clearTimeout(timeoutTimer);
				resolve(code ?? 0);
			});

			proc.on("error", () => {
				if (timeoutTimer) clearTimeout(timeoutTimer);
				resolve(1);
			});

			const killProc = () => {
				wasAborted = true;
				proc.kill("SIGTERM");
				setTimeout(() => {
					if (!proc.killed) proc.kill("SIGKILL");
				}, 5000);
			};

			if (opts.signal) {
				if (opts.signal.aborted) killProc();
				else opts.signal.addEventListener("abort", killProc, { once: true });
			}

			const timeoutMs = opts.timeoutMs ?? DEFAULT_TIMEOUT_MS;
			if (timeoutMs > 0) {
				timeoutTimer = setTimeout(() => {
					timedOut = true;
					killProc();
				}, timeoutMs);
			}
		});

		currentResult.exitCode = exitCode;
		if (timedOut) {
			currentResult.errorMessage = `Subagent timed out after ${Math.round((opts.timeoutMs ?? DEFAULT_TIMEOUT_MS) / 60000)} minutes.`;
			currentResult.stopReason = "timed_out";
		} else if (wasAborted) {
			currentResult.errorMessage = "Subagent was aborted";
			currentResult.stopReason = "aborted";
		}

		/* commit worktree changes + report */
		if (worktree) {
			await finalizeWorktree(
				worktree,
				agentName,
				taskPreview(opts.task, 80),
				exitCode !== 0 || timedOut || wasAborted,
			);
			const branchLine = worktree.branch
				? `Branch \`${worktree.branch}\` · commit \`${worktree.commit.slice(0, 7)}\` · ${worktree.changedFiles} file${worktree.changedFiles === 1 ? "" : "s"} changed`
				: `No changes to commit (base commit \`${worktree.baseCommit.slice(0, 7)}\`)`;
			const note =
				`\n\n---\n**Worktree isolation** (repo: ${worktree.repoRoot})\n${branchLine}\n` +
				`Worktree removed. To inspect the branch: git fetch origin && git checkout ${worktree.branch || worktree.baseCommit.slice(0, 7)}`;
			currentResult.messages.push({
				role: "assistant",
				content: [{ type: "text", text: note }],
			} as Message);
			currentResult.worktree = { repoRoot: worktree.repoRoot, worktreeDir: worktree.worktreeDir };
		}
		return currentResult;
	} finally {
		if (tmpPromptPath)
			try {
				fs.unlinkSync(tmpPromptPath);
			} catch {
				/* ignore */
			}
		if (tmpPromptDir)
			try {
				fs.rmdirSync(tmpPromptDir);
			} catch {
				/* ignore */
			}
	}
}

/* ------------------------------------------------------------------ */
/* Workflow scripts                                                    */
/* ------------------------------------------------------------------ */

interface WorkflowLaneResult {
	key: string;
	agent: string;
	output: string;
	usageText: string;
	error?: string;
}

interface WorkflowContext {
	launchSingle: (spec: {
		agent: string;
		task: string;
		cwd?: string;
		model?: string;
		thinking?: string;
		timeoutMs?: number;
		isolation?: "worktree";
	}) => Promise<SingleResult>;
	maxConcurrency: number;
}

async function executeWorkflowScript(script: string, wf: WorkflowContext, signal: AbortSignal | undefined): Promise<WorkflowLaneResult[]> {
	const results = new Map<string, WorkflowLaneResult>();
	const outputs: string[] = [];

	const formatResult = (key: string, r: SingleResult): WorkflowLaneResult => ({
		key,
		agent: r.agent,
		output: getResultOutput(r),
		usageText: usageToString(r.usage, r.model),
		error: isFailedResult(r) ? r.errorMessage || r.stderr || undefined : undefined,
	});

	const runs: Record<string, unknown> = {
		async run(key: string, spec: { agent: string; task: string; cwd?: string; model?: string; thinking?: string; timeoutMs?: number; isolation?: "worktree" }) {
			const result = await wf.launchSingle({
				agent: spec.agent,
				task: spec.task,
				cwd: spec.cwd,
				model: spec.model,
				thinking: spec.thinking,
				timeoutMs: spec.timeoutMs,
				isolation: spec.isolation,
			});
			const formatted = formatResult(key, result);
			results.set(key, formatted);
			return { key, agent: result.agent, output: formatted.output, error: formatted.error };
		},
		async all(items: { key: string; agent: string; task: string; cwd?: string; model?: string; thinking?: string; isolation?: "worktree" }[]) {
			const list = await mapWithConcurrencyLimit(items, wf.maxConcurrency, async (item) => {
				const result = await wf.launchSingle({
					agent: item.agent,
					task: item.task,
					cwd: item.cwd,
					model: item.model,
					thinking: item.thinking,
					isolation: item.isolation,
				});
				const formatted = formatResult(item.key, result);
				results.set(item.key, formatted);
				return { key: item.key, agent: result.agent, output: formatted.output, error: formatted.error };
			});
			return list;
		},
		status(key: string) {
			const r = results.get(key);
			return r ? { key, agent: r.agent, status: r.error ? "failed" : "completed", output: r.output } : { key, status: "unknown" };
		},
		ref(key: string) {
			const r = results.get(key);
			return r ? { key, agent: r.agent, output: r.output, error: r.error } : undefined;
		},
	};

	const sandboxConsole = {
		log: (...parts: unknown[]) => outputs.push(parts.map((p) => (typeof p === "string" ? p : JSON.stringify(p))).join(" ")),
		error: (...parts: unknown[]) => outputs.push(`error: ${parts.map((p) => (typeof p === "string" ? p : JSON.stringify(p))).join(" ")}`),
	};

	const factory = new Function("runs", "console", "emit", `return (async () => {\n${script}\n})();`);
	await factory(runs, sandboxConsole, (value: unknown) => outputs.push(typeof value === "string" ? value : JSON.stringify(value)));

	const ordered: WorkflowLaneResult[] = Array.from(results.values());
	const summary: WorkflowLaneResult[] = ordered.map((r) => ({
		...r,
		output: r.error
			? `### [${r.agent}] failed\n\n${r.output}`
			: `### [${r.agent}] completed\n\n${r.output}`,
	}));
	if (outputs.length > 0) {
		summary.push({ key: "emit", agent: "workflow", output: outputs.join("\n"), usageText: "" });
	}
	return summary;
}

/* ------------------------------------------------------------------ */
/* Extension                                                           */
/* ------------------------------------------------------------------ */

const TaskItem = Type.Object({
	agent: Type.String({ description: "Name of the agent to invoke" }),
	task: Type.String({ description: "Task to delegate to the agent" }),
	cwd: Type.Optional(Type.String({ description: "Working directory for the agent process" })),
	model: Type.Optional(Type.String({ description: "Model override for this task" })),
	thinking: Type.Optional(Type.String({ description: "Thinking level override for this task" })),
	isolation: Type.Optional(Type.String({ description: "Isolation mode for this task: \"worktree\" runs it in an isolated git worktree" })),
});

const ChainItem = Type.Object({
	agent: Type.String({ description: "Name of the agent to invoke" }),
	task: Type.String({ description: "Task with optional {previous} placeholder for prior output" }),
	cwd: Type.Optional(Type.String({ description: "Working directory for the agent process" })),
	model: Type.Optional(Type.String({ description: "Model override for this step" })),
	thinking: Type.Optional(Type.String({ description: "Thinking level override for this step" })),
	isolation: Type.Optional(Type.String({ description: "Isolation mode for this step: \"worktree\" runs it in an isolated git worktree" })),
});

const AgentScopeSchema = StringEnum(["user", "project", "both"] as const, {
	description: 'Which agent directories to use. Default: "user". Use "both" to include project-local agents.',
	default: "user",
});

const ThinkingSchema = StringEnum(["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const, {
	description: "Thinking level for the subagent (applies to the resolved model)",
});

const SubagentParams = Type.Object({
	agent: Type.Optional(Type.String({ description: "Name of the agent to invoke (for single mode)" })),
	task: Type.Optional(Type.String({ description: "Task to delegate (for single mode)" })),
	tasks: Type.Optional(Type.Array(TaskItem, { description: "Array of {agent, task} for parallel execution" })),
	chain: Type.Optional(Type.Array(ChainItem, { description: "Array of {agent, task} for sequential execution with {previous} passing" })),
	workflowScript: Type.Optional(Type.String({
		minLength: 1,
		description:
			"Trusted inline JavaScript orchestration. Use await runs.run(key, {agent, task, cwd?, model?}), await runs.all([...]) for parallel, runs.status(key), runs.ref(key), emit(value), and console.log. Ordinary loops/branches/awaits work. Returns an aggregate summary.",
	})),
	async: Type.Optional(Type.Boolean({ description: "Run in the background. The tool returns immediately with a run id; a summary is delivered when it finishes. Defaults to config (asyncByDefault) or false." })),
	isolation: Type.Optional(Type.String({
		description: 'Isolation mode: "worktree" runs the subagent in an isolated git worktree (checked out at current HEAD); changes are committed to a pi-subagent/* branch on completion. Overrides agent frontmatter isolation.',
	})),
	model: Type.Optional(Type.String({ description: "Model override for single mode (e.g. 'opencode/big-pickle')" })),
	thinking: Type.Optional(ThinkingSchema),
	agentScope: Type.Optional(AgentScopeSchema),
	confirmProjectAgents: Type.Optional(
		Type.Boolean({ description: "Prompt before running project-local agents. Default: true.", default: true }),
	),
	cwd: Type.Optional(Type.String({ description: "Working directory for the agent process (single mode)" })),
	timeoutMs: Type.Optional(Type.Integer({ minimum: 1, description: "Timeout in ms (default 30 minutes)" })),
	context: Type.Optional(StringEnum(["fresh", "fork"] as const, {
		description: '"fresh" (default) starts with no parent context; "fork" prepends a compact excerpt of the parent conversation.',
	})),
});

export default function (pi: ExtensionAPI) {
	if (process.env[CHILD_ENV] === "1") return;

	const config = loadConfig();
	const asyncByDefault = config.asyncByDefault === true;
	const maxConcurrency = Math.max(1, config.maxConcurrency ?? DEFAULT_CONCURRENCY);
	const maxParallelTasks = Math.max(1, config.maxParallelTasks ?? MAX_PARALLEL_TASKS);
	const fleetWidgetEnabled = config.fleetWidget !== false;
	const worktreesDir = config.worktreesDir;

	fs.mkdirSync(getRunsDir(), { recursive: true });

	const manager = new AsyncRunManager({
		launch: async (runId, spec, hooks, signal) => {
			const discovery = discoverAgents(spec.cwd, "both");
			const agents = discovery.agents;
			if (spec.agent === "__workflow__") {
				const lanes = await executeWorkflowScript(
					spec.task,
					{
						maxConcurrency,
						launchSingle: (childSpec) =>
							runSingleAgent({
								defaultCwd: spec.cwd,
								agents,
								agentName: childSpec.agent,
								task: childSpec.task,
								cwd: childSpec.cwd,
								model: childSpec.model,
								thinking: childSpec.thinking,
								timeoutMs: childSpec.timeoutMs ?? spec.timeoutMs,
								isolation: childSpec.isolation,
								signal,
								makeDetails: (results) => ({ mode: "workflow", agentScope: "both", projectAgentsDir: null, results }),
								transcriptPath: transcriptFile(runId),
								worktreesDir,
							}),
					},
					signal,
				);
				const text = lanes.map((l) => `${l.output}`).join("\n\n---\n\n");
				return {
					exitCode: 0,
					output: text,
					usageText: "",
				} satisfies AsyncRunResult;
			}

			const result = await runSingleAgent({
				defaultCwd: spec.cwd,
				agents,
				agentName: spec.agent,
				task: spec.task,
				cwd: spec.cwd,
				model: spec.model,
				thinking: spec.thinking,
				timeoutMs: spec.timeoutMs,
				isolation: spec.isolation,
				signal,
				onUpdate: (partial) => {
					const current = partial.details?.results[0];
					if (current) {
						hooks.onProgress?.({
							agent: current.agent,
							task: current.task,
							cwd: spec.cwd,
							status: "running",
							output: getFinalOutput(current.messages),
						});
					}
				},
				makeDetails: (results) => ({ mode: "single", agentScope: "both", projectAgentsDir: null, results }),
				transcriptPath: transcriptFile(runId),
				onProcess: (pid) => hooks.onProcess?.(pid),
			});
			return {
				exitCode: result.exitCode,
				error: isFailedResult(result) ? result.errorMessage || result.stderr || undefined : undefined,
				output: getResultOutput(result),
				usageText: usageToString(result.usage, result.model),
				worktree: result.worktree,
			} satisfies AsyncRunResult;
		},
		onFinalize: (runId, meta) => {
			notifyCompletion(meta);
			refreshFleetWidget();
		},
		maxConcurrency,
	});

	/* ----- parent conversation excerpt for context: "fork" ----- */
	const buildForkContext = (ctx: { sessionManager: { getEntries(): unknown[] } }): string => {
		try {
			const entries = ctx.sessionManager.getEntries();
			const parts: string[] = [];
			for (let i = entries.length - 1; i >= 0 && parts.length < 8; i--) {
				const entry = entries[i] as any;
				if (entry?.type !== "message" || !entry.role) continue;
				if (entry.role !== "user" && entry.role !== "assistant") continue;
				const text = Array.isArray(entry.content)
					? entry.content
							.map((part: any) => (part?.type === "text" ? part.text : null))
							.filter(Boolean)
							.join(" ")
					: "";
				if (!text.trim()) continue;
				parts.unshift(`${entry.role}: ${text.slice(0, 2000)}`);
			}
			if (parts.length === 0) return "";
			return `<parent-context>\n${parts.join("\n\n")}\n</parent-context>`;
		} catch {
			return "";
		}
	};

	const withForkContext = (
		task: string,
		context: string | undefined,
		ctx: { sessionManager: { getEntries(): unknown[] } },
	): string => {
		if (context !== "fork") return task;
		const excerpt = buildForkContext(ctx);
		return excerpt ? `${excerpt}\n\n${task}` : task;
	};

	/* ----- completion notification ----- */
	const notifyCompletion = (meta: AsyncRunMeta) => {
		try {
			const preview = (meta.output ?? "").replace(/\s+/g, " ").trim();
			const previewText = preview ? preview.slice(0, 600) : meta.error ? meta.error : "(no output)";
			const durationMs = (meta.endedAt ?? Date.now()) - meta.startedAt;
			pi.sendMessage({
				customType: NOTIFY_TYPE,
				content: previewText,
				display: true,
				details: {
					agent: meta.agent,
					status: meta.status,
					durationMs,
					runId: meta.runId,
					error: meta.error,
				},
			});
		} catch {
			/* stale ctx (print mode / session replaced) — drop the notification */
		}
		if (manager.lastUiContext?.hasUI) {
			try {
				manager.lastUiContext.ui.notify(
					`Subagent ${meta.agent}: ${meta.status}${meta.error ? ` — ${meta.error}` : ""}`,
					meta.status === "completed" ? "info" : "warning",
				);
			} catch {
				/* stale ctx */
			}
		}
	};

	const refreshFleetWidget = () => {
		try {
			const ctx = manager.lastUiContext;
			if (!ctx?.hasUI) return;
			const active = manager.active();
			const queued = manager.queuedRuns();
			if (fleetWidgetEnabled && (active.length > 0 || queued.length > 0)) {
				ctx.ui.setWidget(WIDGET_KEY, (tui, theme) => createFleetWidget(manager, theme));
			} else {
				ctx.ui.setWidget(WIDGET_KEY, undefined);
			}
		} catch {
			/* stale ctx (session replaced/reloaded) — ignore */
		}
	};

	/* ----- the tool ----- */
	const tool = defineTool({
		name: "subagent",
		label: "Subagent",
		description: [
			"Delegate tasks to specialized subagents with isolated context windows.",
			"Modes: single ({agent, task}), parallel ({tasks: [...]}), chain ({chain: [...]} with {previous} passing), workflowScript (inline JS orchestration).",
			"Set async:true to run in the background — the tool returns a run id immediately and a completion summary is delivered later.",
			"Set isolation:'worktree' to run the subagent in an isolated git worktree; its changes are committed to a pi-subagent/* branch on completion (also via agent frontmatter isolation: worktree).",
			"Background runs are queued behind maxConcurrency (config).",
			"Available agents and their purposes: scout (fast codebase recon), researcher (web research), planner (implementation plan), worker (implementation), reviewer (code review), context-builder (requirements-to-context handoff), delegate (lightweight general).",
			`Default agent scope is "user". Set agentScope: "both" to include project-local agents (.${CONFIG_DIR_NAME}/agents).`,
		].join(" "),
		parameters: SubagentParams,

		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const agentScope: AgentScope = params.agentScope ?? "user";
			const discovery = discoverAgents(ctx.cwd, agentScope);
			const agents = discovery.agents;
			const confirmProjectAgents = params.confirmProjectAgents ?? true;
			const parentSession = ctx.sessionManager.getSessionFile() ?? undefined;

			const hasWorkflow = Boolean(params.workflowScript);
			const hasChain = (params.chain?.length ?? 0) > 0;
			const hasTasks = (params.tasks?.length ?? 0) > 0;
			const hasSingle = Boolean(params.agent && params.task);
			const modeCount = Number(hasWorkflow) + Number(hasChain) + Number(hasTasks) + Number(hasSingle);

			const makeDetails =
				(mode: "single" | "parallel" | "chain" | "workflow") =>
				(results: SingleResult[]): SubagentDetails => ({
					mode,
					agentScope,
					projectAgentsDir: discovery.projectAgentsDir,
					results,
				});

			if (modeCount !== 1) {
				const available = agents.map((a) => `${a.name} (${a.source})`).join(", ") || "none";
				return {
					content: [{ type: "text", text: `Invalid parameters. Provide exactly one mode.\nAvailable agents: ${available}` }],
					details: makeDetails("single")([]),
				};
			}

			if ((agentScope === "project" || agentScope === "both") && confirmProjectAgents && ctx.hasUI) {
				const requested = new Set<string>();
				if (params.chain) for (const step of params.chain) requested.add(step.agent);
				if (params.tasks) for (const t of params.tasks) requested.add(t.agent);
				if (params.agent) requested.add(params.agent);

				const projectAgentsRequested = Array.from(requested)
					.map((name) => findAgent(agents, name))
					.filter((a): a is AgentConfig => a?.source === "project");

				if (projectAgentsRequested.length > 0) {
					const names = projectAgentsRequested.map((a) => a.name).join(", ");
					const dir = discovery.projectAgentsDir ?? "(unknown)";
					const ok = await ctx.ui.confirm(
						"Run project-local agents?",
						`Agents: ${names}\nSource: ${dir}\n\nProject agents are repo-controlled. Only continue for trusted repositories.`,
					);
					if (!ok)
						return {
							content: [{ type: "text", text: "Canceled: project-local agents not approved." }],
							details: makeDetails(hasWorkflow ? "workflow" : hasChain ? "chain" : hasTasks ? "parallel" : "single")([]),
						};
				}
			}

			/* ----- workflowScript ----- */
			if (params.workflowScript) {
				const runAsync = params.async ?? asyncByDefault;
				const script = params.workflowScript;

				const wfCtx = {
					maxConcurrency,
					launchSingle: (childSpec: { agent: string; task: string; cwd?: string; model?: string; thinking?: string; timeoutMs?: number; isolation?: "worktree" }) =>
						runSingleAgent({
							defaultCwd: ctx.cwd,
							agents,
							agentName: childSpec.agent,
							task: withForkContext(childSpec.task, params.context, ctx),
							cwd: childSpec.cwd ?? params.cwd,
							model: childSpec.model ?? params.model,
							thinking: childSpec.thinking ?? params.thinking,
							timeoutMs: childSpec.timeoutMs ?? params.timeoutMs,
							isolation: childSpec.isolation ?? params.isolation,
							signal,
							onUpdate: (partial) => {
								const current = partial.details?.results[0];
								if (current) onUpdate?.({
									content: [{ type: "text", text: `Workflow lane ${current.agent}: ${getResultOutput(current).slice(0, 200)}` }],
									details: makeDetails("workflow")([current]),
								});
							},
							makeDetails: makeDetails("workflow"),
						}),
				};

				if (runAsync) {
					const runId = manager.start({
						agent: "__workflow__",
						task: script,
						cwd: ctx.cwd,
						model: params.model,
						thinking: params.thinking,
						timeoutMs: params.timeoutMs,
					}, parentSession);
					refreshFleetWidget();
					return {
						content: [{ type: "text", text: `Started workflow in the background (run ${runId.slice(0, 8)}). A summary will be delivered when it finishes. Use /subagents-fleet to inspect.` }],
						details: makeDetails("workflow")([{ agent: "workflow", agentSource: "unknown", task: script.slice(0, 200), exitCode: 0, messages: [], stderr: "", usage: emptyUsage(), asyncStarted: true, runId }]),
					};
				}

				const lanes = await executeWorkflowScript(script, wfCtx, signal);
				const text = lanes.map((l) => l.output).join("\n\n---\n\n");
				return {
					content: [{ type: "text", text: text || "(no output)" }],
					details: makeDetails("workflow")(lanes.map((l) => ({
						agent: l.agent,
						agentSource: "unknown",
						task: l.key,
						exitCode: l.error ? 1 : 0,
						messages: [],
						stderr: l.error ?? "",
						usage: emptyUsage(),
					}))),
				};
			}

			/* ----- chain ----- */
			if (params.chain && params.chain.length > 0) {
				const results: SingleResult[] = [];
				let previousOutput = "";

				for (let i = 0; i < params.chain.length; i++) {
					const step = params.chain[i];
					const taskWithContext = step.task.replace(/\{previous\}/g, previousOutput);

					const chainUpdate = onUpdate
						? (partial: AgentToolResult<SubagentDetails>) => {
								const currentResult = partial.details?.results[0];
								if (currentResult) {
									onUpdate({
										content: partial.content,
										details: makeDetails("chain")([...results, currentResult]),
									});
								}
							}
						: undefined;

					const result = await runSingleAgent({
						defaultCwd: ctx.cwd,
						agents,
						agentName: step.agent,
						task: withForkContext(taskWithContext, params.context, ctx),
						cwd: step.cwd,
						step: i + 1,
						model: step.model ?? params.model,
						thinking: step.thinking ?? params.thinking,
						timeoutMs: params.timeoutMs,
						isolation: step.isolation,
						signal,
						onUpdate: chainUpdate,
						makeDetails: makeDetails("chain"),
					});
					results.push(result);

					if (isFailedResult(result)) {
						const errorMsg = getResultOutput(result);
						return {
							content: [{ type: "text", text: `Chain stopped at step ${i + 1} (${step.agent}): ${errorMsg}` }],
							details: makeDetails("chain")(results),
							isError: true,
						};
					}
					previousOutput = getFinalOutput(result.messages);
				}
				return {
					content: [{ type: "text", text: getFinalOutput(results[results.length - 1].messages) || "(no output)" }],
					details: makeDetails("chain")(results),
				};
			}

			/* ----- parallel ----- */
			if (params.tasks && params.tasks.length > 0) {
				if (params.tasks.length > maxParallelTasks)
					return {
						content: [{ type: "text", text: `Too many parallel tasks (${params.tasks.length}). Max is ${maxParallelTasks}.` }],
						details: makeDetails("parallel")([]),
					};

				const allResults: SingleResult[] = new Array(params.tasks.length);
				for (let i = 0; i < params.tasks.length; i++) {
					allResults[i] = {
						agent: params.tasks[i].agent,
						agentSource: "unknown",
						task: params.tasks[i].task,
						exitCode: -1,
						messages: [],
						stderr: "",
						usage: emptyUsage(),
					};
				}

				const emitParallelUpdate = () => {
					if (onUpdate) {
						const running = allResults.filter((r) => r.exitCode === -1).length;
						const done = allResults.length - running;
						onUpdate({
							content: [{ type: "text", text: `Parallel: ${done}/${allResults.length} done, ${running} running...` }],
							details: makeDetails("parallel")([...allResults]),
						});
					}
				};

				const results = await mapWithConcurrencyLimit(params.tasks, maxConcurrency, async (t, index) => {
					const result = await runSingleAgent({
						defaultCwd: ctx.cwd,
						agents,
						agentName: t.agent,
						task: withForkContext(t.task, params.context, ctx),
						cwd: t.cwd ?? params.cwd,
						model: t.model ?? params.model,
						thinking: t.thinking ?? params.thinking,
						timeoutMs: params.timeoutMs,
						isolation: t.isolation,
						signal,
						onUpdate: (partial) => {
							if (partial.details?.results[0]) {
								allResults[index] = partial.details.results[0];
								emitParallelUpdate();
							}
						},
						makeDetails: makeDetails("parallel"),
					});
					allResults[index] = result;
					emitParallelUpdate();
					return result;
				});

				const successCount = results.filter((r) => !isFailedResult(r)).length;
				const summaries = results.map((r) => {
					const output = truncateParallelOutput(getResultOutput(r));
					const status = isFailedResult(r)
						? `failed${r.stopReason && r.stopReason !== "end" ? ` (${r.stopReason})` : ""}`
						: "completed";
					return `### [${r.agent}] ${status}\n\n${output}`;
				});
				return {
					content: [{ type: "text", text: `Parallel: ${successCount}/${results.length} succeeded\n\n${summaries.join("\n\n---\n\n")}` }],
					details: makeDetails("parallel")(results),
				};
			}

			/* ----- single ----- */
			if (params.agent && params.task) {
				const runAsync = params.async ?? asyncByDefault;

				if (runAsync) {
					const runId = manager.start({
						agent: params.agent,
						task: withForkContext(params.task, params.context, ctx),
						cwd: params.cwd ?? ctx.cwd,
						model: params.model,
						thinking: params.thinking,
						timeoutMs: params.timeoutMs,
						isolation: params.isolation,
					}, parentSession);
					refreshFleetWidget();
					return {
						content: [{ type: "text", text: `Started ${params.agent} in the background (run ${runId.slice(0, 8)}). A summary will be delivered when it finishes. Use /subagents-fleet to inspect.` }],
						details: makeDetails("single")([{
							agent: params.agent,
							agentSource: "unknown",
							task: params.task,
							exitCode: 0,
							messages: [],
							stderr: "",
							usage: emptyUsage(),
							asyncStarted: true,
							runId,
						}]),
					};
				}

				const result = await runSingleAgent({
					defaultCwd: ctx.cwd,
					agents,
					agentName: params.agent,
					task: withForkContext(params.task, params.context, ctx),
					cwd: params.cwd,
					model: params.model,
					thinking: params.thinking,
					timeoutMs: params.timeoutMs,
					isolation: params.isolation,
					signal,
					onUpdate,
					makeDetails: makeDetails("single"),
				});
				const isError = isFailedResult(result);
				if (isError) {
					const errorMsg = getResultOutput(result);
					return {
						content: [{ type: "text", text: `Agent ${result.stopReason || "failed"}: ${errorMsg}` }],
						details: makeDetails("single")([result]),
						isError: true,
					};
				}
				return {
					content: [{ type: "text", text: getFinalOutput(result.messages) || "(no output)" }],
					details: makeDetails("single")([result]),
				};
			}

			const available = agents.map((a) => `${a.name} (${a.source})`).join(", ") || "none";
			return {
				content: [{ type: "text", text: `Invalid parameters. Available agents: ${available}` }],
				details: makeDetails("single")([]),
			};
		},

		renderCall(args, theme) {
			const scope = args.agentScope ?? "user";
			const asyncLabel = args.async === true ? theme.fg("warning", " [async]") : "";

			if (args.workflowScript) {
				return new Text(
					theme.fg("toolTitle", theme.bold("subagent ")) +
						theme.fg("accent", "workflow") +
						theme.fg("muted", ` [${scope}]`) +
						asyncLabel,
					0,
					0,
				);
			}
			if (args.chain && args.chain.length > 0) {
				let text =
					theme.fg("toolTitle", theme.bold("subagent ")) +
					theme.fg("accent", `chain (${args.chain.length} steps)`) +
					theme.fg("muted", ` [${scope}]`) +
					asyncLabel;
				for (let i = 0; i < Math.min(args.chain.length, 3); i++) {
					const step = args.chain[i];
					const cleanTask = step.task.replace(/\{previous\}/g, "").trim();
					const preview = cleanTask.length > 40 ? `${cleanTask.slice(0, 40)}...` : cleanTask;
					text += "\n  " + theme.fg("muted", `${i + 1}.`) + " " + theme.fg("accent", step.agent) + theme.fg("dim", ` ${preview}`);
				}
				if (args.chain.length > 3) text += `\n  ${theme.fg("muted", `... +${args.chain.length - 3} more`)}`;
				return new Text(text, 0, 0);
			}
			if (args.tasks && args.tasks.length > 0) {
				let text =
					theme.fg("toolTitle", theme.bold("subagent ")) +
					theme.fg("accent", `parallel (${args.tasks.length} tasks)`) +
					theme.fg("muted", ` [${scope}]`) +
					asyncLabel;
				for (const t of args.tasks.slice(0, 3)) {
					const preview = t.task.length > 40 ? `${t.task.slice(0, 40)}...` : t.task;
					text += `\n  ${theme.fg("accent", t.agent)}${theme.fg("dim", ` ${preview}`)}`;
				}
				if (args.tasks.length > 3) text += `\n  ${theme.fg("muted", `... +${args.tasks.length - 3} more`)}`;
				return new Text(text, 0, 0);
			}
			const agentName = args.agent || "...";
			const preview = args.task ? (args.task.length > 60 ? `${args.task.slice(0, 60)}...` : args.task) : "...";
			let text =
				theme.fg("toolTitle", theme.bold("subagent ")) +
				theme.fg("accent", agentName) +
				theme.fg("muted", ` [${scope}]`) +
				asyncLabel;
			text += `\n  ${theme.fg("dim", preview)}`;
			return new Text(text, 0, 0);
		},

		renderResult(result, { expanded }, theme) {
			const details = result.details as SubagentDetails | undefined;
			if (!details || details.results.length === 0) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
			}

			const mdTheme = getMarkdownTheme();

			const renderDisplayItems = (items: DisplayItem[], limit?: number) => {
				const toShow = limit ? items.slice(-limit) : items;
				const skipped = limit && items.length > limit ? items.length - limit : 0;
				let text = "";
				if (skipped > 0) text += theme.fg("muted", `... ${skipped} earlier items\n`);
				for (const item of toShow) {
					if (item.type === "text") {
						const preview = expanded ? item.text : item.text.split("\n").slice(0, 3).join("\n");
						text += `${theme.fg("toolOutput", preview)}\n`;
					} else {
						text += `${theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme))}\n`;
					}
				}
				return text.trimEnd();
			};

			/* async started state */
			if (details.results[0]?.asyncStarted) {
				const r = details.results[0];
				return new Text(
					`${theme.fg("warning", "⏳")} ${theme.fg("toolTitle", theme.bold(r.agent))} ${theme.fg("muted", "started in background")}\n` +
						`  ${theme.fg("dim", `run ${r.runId?.slice(0, 8)}`)} — a summary will be delivered when it finishes.\n` +
						theme.fg("muted", "  /subagents-fleet to inspect"),
					0,
					0,
				);
			}

			if (details.mode === "single" && details.results.length === 1) {
				const r = details.results[0];
				const isError = isFailedResult(r);
				const icon = isError ? theme.fg("error", "✗") : theme.fg("success", "✓");
				const displayItems = getDisplayItems(r.messages);
				const finalOutput = getFinalOutput(r.messages);

				if (expanded) {
					const container = new Container();
					let header = `${icon} ${theme.fg("toolTitle", theme.bold(r.agent))}${theme.fg("muted", ` (${r.agentSource})`)}`;
					if (isError && r.stopReason) header += ` ${theme.fg("error", `[${r.stopReason}]`)}`;
					container.addChild(new Text(header, 0, 0));
					if (isError && r.errorMessage)
						container.addChild(new Text(theme.fg("error", `Error: ${r.errorMessage}`), 0, 0));
					container.addChild(new Spacer(1));
					container.addChild(new Text(theme.fg("muted", "─── Task ───"), 0, 0));
					container.addChild(new Text(theme.fg("dim", r.task), 0, 0));
					container.addChild(new Spacer(1));
					container.addChild(new Text(theme.fg("muted", "─── Output ───"), 0, 0));
					if (displayItems.length === 0 && !finalOutput) {
						container.addChild(new Text(theme.fg("muted", "(no output)"), 0, 0));
					} else {
						for (const item of displayItems) {
							if (item.type === "toolCall")
								container.addChild(
									new Text(
										theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme)),
										0,
										0,
									),
								);
						}
						if (finalOutput) {
							container.addChild(new Spacer(1));
							container.addChild(new Markdown(finalOutput.trim(), 0, 0, mdTheme));
						}
					}
					const usageStr = formatUsageStats(r.usage, r.model);
					if (usageStr) {
						container.addChild(new Spacer(1));
						container.addChild(new Text(theme.fg("dim", usageStr), 0, 0));
					}
					return container;
				}

				let text = `${icon} ${theme.fg("toolTitle", theme.bold(r.agent))}${theme.fg("muted", ` (${r.agentSource})`)}`;
				if (isError && r.stopReason) text += ` ${theme.fg("error", `[${r.stopReason}]`)}`;
				if (isError && r.errorMessage) text += `\n${theme.fg("error", `Error: ${r.errorMessage}`)}`;
				else if (displayItems.length === 0) text += `\n${theme.fg("muted", "(no output)")}`;
				else {
					text += `\n${renderDisplayItems(displayItems, COLLAPSED_ITEM_COUNT)}`;
					if (displayItems.length > COLLAPSED_ITEM_COUNT) text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
				}
				const usageStr = formatUsageStats(r.usage, r.model);
				if (usageStr) text += `\n${theme.fg("dim", usageStr)}`;
				return new Text(text, 0, 0);
			}

			const aggregateUsage = (results: SingleResult[]) => {
				const total = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, turns: 0 };
				for (const r of results) {
					total.input += r.usage.input;
					total.output += r.usage.output;
					total.cacheRead += r.usage.cacheRead;
					total.cacheWrite += r.usage.cacheWrite;
					total.cost += r.usage.cost;
					total.turns += r.usage.turns;
				}
				return total;
			};

			/* workflow */
			if (details.mode === "workflow") {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
			}

			if (details.mode === "chain") {
				const successCount = details.results.filter((r) => r.exitCode === 0).length;
				const icon = successCount === details.results.length ? theme.fg("success", "✓") : theme.fg("error", "✗");

				if (expanded) {
					const container = new Container();
					container.addChild(
						new Text(
							icon + " " + theme.fg("toolTitle", theme.bold("chain ")) + theme.fg("accent", `${successCount}/${details.results.length} steps`),
							0,
							0,
						),
					);

					for (const r of details.results) {
						const rIcon = r.exitCode === 0 ? theme.fg("success", "✓") : theme.fg("error", "✗");
						const displayItems = getDisplayItems(r.messages);
						const finalOutput = getFinalOutput(r.messages);

						container.addChild(new Spacer(1));
						container.addChild(
							new Text(`${theme.fg("muted", `─── Step ${r.step}: `) + theme.fg("accent", r.agent)} ${rIcon}`, 0, 0),
						);
						container.addChild(new Text(theme.fg("muted", "Task: ") + theme.fg("dim", r.task), 0, 0));

						for (const item of displayItems) {
							if (item.type === "toolCall") {
								container.addChild(
									new Text(
										theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme)),
										0,
										0,
									),
								);
							}
						}

						if (finalOutput) {
							container.addChild(new Spacer(1));
							container.addChild(new Markdown(finalOutput.trim(), 0, 0, mdTheme));
						}

						const stepUsage = formatUsageStats(r.usage, r.model);
						if (stepUsage) container.addChild(new Text(theme.fg("dim", stepUsage), 0, 0));
					}

					const usageStr = formatUsageStats(aggregateUsage(details.results));
					if (usageStr) {
						container.addChild(new Spacer(1));
						container.addChild(new Text(theme.fg("dim", `Total: ${usageStr}`), 0, 0));
					}
					return container;
				}

				let text =
					icon +
					" " +
					theme.fg("toolTitle", theme.bold("chain ")) +
					theme.fg("accent", `${successCount}/${details.results.length} steps`);
				for (const r of details.results) {
					const rIcon = r.exitCode === 0 ? theme.fg("success", "✓") : theme.fg("error", "✗");
					const displayItems = getDisplayItems(r.messages);
					text += `\n\n${theme.fg("muted", `─── Step ${r.step}: `)}${theme.fg("accent", r.agent)} ${rIcon}`;
					if (displayItems.length === 0) text += `\n${theme.fg("muted", "(no output)")}`;
					else text += `\n${renderDisplayItems(displayItems, 5)}`;
				}
				const usageStr = formatUsageStats(aggregateUsage(details.results));
				if (usageStr) text += `\n\n${theme.fg("dim", `Total: ${usageStr}`)}`;
				text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
				return new Text(text, 0, 0);
			}

			if (details.mode === "parallel") {
				const running = details.results.filter((r) => r.exitCode === -1).length;
				const successCount = details.results.filter((r) => r.exitCode !== -1 && !isFailedResult(r)).length;
				const failCount = details.results.filter((r) => r.exitCode !== -1 && isFailedResult(r)).length;
				const isRunning = running > 0;
				const icon = isRunning
					? theme.fg("warning", "⏳")
					: failCount > 0
						? theme.fg("warning", "◐")
						: theme.fg("success", "✓");
				const status = isRunning
					? `${successCount + failCount}/${details.results.length} done, ${running} running`
					: `${successCount}/${details.results.length} tasks`;

				if (expanded && !isRunning) {
					const container = new Container();
					container.addChild(
						new Text(`${icon} ${theme.fg("toolTitle", theme.bold("parallel "))}${theme.fg("accent", status)}`, 0, 0),
					);

					for (const r of details.results) {
						const rIcon = isFailedResult(r) ? theme.fg("error", "✗") : theme.fg("success", "✓");
						const displayItems = getDisplayItems(r.messages);
						const finalOutput = getFinalOutput(r.messages);

						container.addChild(new Spacer(1));
						container.addChild(
							new Text(`${theme.fg("muted", "─── ") + theme.fg("accent", r.agent)} ${rIcon}`, 0, 0),
						);
						container.addChild(new Text(theme.fg("muted", "Task: ") + theme.fg("dim", r.task), 0, 0));

						for (const item of displayItems) {
							if (item.type === "toolCall") {
								container.addChild(
									new Text(
										theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme)),
										0,
										0,
									),
								);
							}
						}

						if (finalOutput) {
							container.addChild(new Spacer(1));
							container.addChild(new Markdown(finalOutput.trim(), 0, 0, mdTheme));
						}

						const taskUsage = formatUsageStats(r.usage, r.model);
						if (taskUsage) container.addChild(new Text(theme.fg("dim", taskUsage), 0, 0));
					}

					const usageStr = formatUsageStats(aggregateUsage(details.results));
					if (usageStr) {
						container.addChild(new Spacer(1));
						container.addChild(new Text(theme.fg("dim", `Total: ${usageStr}`), 0, 0));
					}
					return container;
				}

				let text = `${icon} ${theme.fg("toolTitle", theme.bold("parallel "))}${theme.fg("accent", status)}`;
				for (const r of details.results) {
					const rIcon =
						r.exitCode === -1
							? theme.fg("warning", "⏳")
							: isFailedResult(r)
								? theme.fg("error", "✗")
								: theme.fg("success", "✓");
					const displayItems = getDisplayItems(r.messages);
					text += `\n\n${theme.fg("muted", "─── ")}${theme.fg("accent", r.agent)} ${rIcon}`;
					if (displayItems.length === 0)
						text += `\n${theme.fg("muted", r.exitCode === -1 ? "(running...)" : "(no output)")}`;
					else text += `\n${renderDisplayItems(displayItems, 5)}`;
				}
				if (!isRunning) {
					const usageStr = formatUsageStats(aggregateUsage(details.results));
					if (usageStr) text += `\n\n${theme.fg("dim", `Total: ${usageStr}`)}`;
				}
				if (!expanded) text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
				return new Text(text, 0, 0);
			}

			const text = result.content[0];
			return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
		},
	});

	pi.registerTool(tool);

	/* ----- notify renderer ----- */
	pi.registerMessageRenderer<{
		agent: string;
		status: string;
		durationMs: number;
		runId?: string;
		error?: string;
	}>(NOTIFY_TYPE, (message, options, theme) => {
		const details = message.details;
		const content = typeof message.content === "string" ? message.content : "";
		if (!details) return new Text(content, 0, 0);
		const icon =
			details.status === "completed"
				? theme.fg("success", "✓")
				: details.status === "running"
					? theme.fg("warning", "■")
					: theme.fg("error", "✗");
		const duration = formatDurationText(details.durationMs);
		let text = `${icon} ${theme.bold(details.agent)} ${theme.fg("dim", details.status)}${details.runId ? ` ${theme.fg("dim", `· ${details.runId.slice(0, 8)}`)}` : ""}`;
		if (duration) text += ` ${theme.fg("dim", `· ${duration}`)}`;
		if (details.error) text += `\n${theme.fg("error", `error: ${details.error}`)}`;
		const preview = content.replace(/\s+/g, " ").trim();
		const previewLines = options.expanded
			? preview.split(". ")
			: [preview.slice(0, 240)];
		for (const line of previewLines.filter((l) => l.trim())) {
			text += `\n  ${theme.fg("dim", `⎿  ${line}`)}`;
		}
		return new Text(text, 0, 0);
	});

	/* ----- list/doctor renderer ----- */
	pi.registerMessageRenderer<string>(LIST_TYPE, (message, _options, theme) => {
		const content = typeof message.content === "string" ? message.content : "";
		return new Text(theme.fg("toolOutput", content), 0, 0);
	});

	function formatDurationText(ms: number): string {
		if (!ms) return "";
		const s = Math.max(0, Math.floor(ms / 1000));
		if (s < 60) return `${s}s`;
		return `${Math.floor(s / 60)}m${(s % 60).toString().padStart(2, "0")}s`;
	}

	/* ----- commands ----- */
	pi.registerCommand("subagents", {
		description: "List available subagents and active runs",
		handler: async (_args, ctx) => {
			const discovery = discoverAgents(ctx.cwd, "both");
			const lines: string[] = ["Available agents:"];
			for (const a of discovery.agents) {
				const tools = a.tools?.length ? ` · tools: ${a.tools.join(",")}` : "";
				const model = a.model ? ` · model: ${a.model}` : "";
				lines.push(`  ${a.name} (${a.source}) — ${a.description}${model}${tools}`);
			}
			const active = manager.active();
			const queued = manager.queuedRuns();
			lines.push("");
			if (active.length === 0 && queued.length === 0) {
				lines.push("No active runs.");
			} else {
				if (active.length > 0) {
					lines.push(`Active runs (${active.length}/${maxConcurrency}):`);
					for (const run of active) {
						lines.push(`  ⏳ ${run.agent} · run ${run.runId.slice(0, 8)} · started ${new Date(run.startedAt).toLocaleTimeString()}`);
					}
				}
				if (queued.length > 0) {
					lines.push(`Queued (${queued.length}):`);
					for (const run of queued) {
						lines.push(`  ⏸ ${run.agent} · run ${run.runId.slice(0, 8)} · queued ${new Date(run.startedAt).toLocaleTimeString()}`);
					}
				}
			}
			pi.sendMessage({ customType: LIST_TYPE, content: lines.join("\n"), display: true });
		},
	});

	pi.registerCommand("subagents-fleet", {
		description: "Open the interactive subagent fleet inspector",
		handler: async (_args, ctx) => {
			if (ctx.mode !== "tui" || !ctx.hasUI) {
				ctx.ui.notify("Subagents fleet requires interactive mode", "error");
				return;
			}
			await ctx.ui.custom((tui, theme, _kb, done) => {
				return openFleetInspector(manager, tui, theme, () => done(undefined));
			});
		},
	});

	pi.registerCommand("subagents-doctor", {
		description: "Check subagent configuration and runtime health",
		handler: async (_args, ctx) => {
			const lines: string[] = ["Subagents doctor:"];
			try {
				const invocation = getPiInvocation(["--version"]);
				lines.push(`  pi binary: ${invocation.command} ${invocation.args.join(" ")}`);
			} catch (error) {
				lines.push(`  pi binary: ERROR ${error}`);
			}
			const discovery = discoverAgents(ctx.cwd, "both");
			lines.push(`  agents: ${discovery.agents.length} discovered (${discovery.agents.map((a) => a.source).join(", ")})`);
			lines.push(`  state dir: ${getRunsDir()}`);
			lines.push(`  async runs: ${manager.list().length} tracked, ${manager.active().length} active, ${manager.queuedRuns().length} queued (maxConcurrency: ${maxConcurrency})`);
			lines.push(`  worktrees: ${config.worktreesDir ?? "<repoRoot>/.pi-subagents-worktrees (default)"}`);
			lines.push(`  child extensions: ${getChildExtensionArgs().length / 2} loaded (permission-gate excluded)`);
			lines.push(`  config: ${JSON.stringify(config)}`);
			pi.sendMessage({ customType: LIST_TYPE, content: lines.join("\n"), display: true });
		},
	});

	/* ----- session lifecycle ----- */
	pi.on("session_start", (event, ctx) => {
		manager.lastUiContext = ctx;
		manager.restore();
		refreshFleetWidget();
	});

	pi.on("session_shutdown", () => {
		manager.lastUiContext = null;
		manager.dispose();
	});

	pi.on("tool_result", (event, ctx) => {
		if (event.toolName !== "subagent") return;
		manager.lastUiContext = ctx;
		refreshFleetWidget();
	});

	pi.on("resources_discover", () => {
		return {
			skillPaths: [path.join(__dirname, "skills")],
			promptPaths: [path.join(__dirname, "prompts")],
		};
	});

	/* keep the fleet widget live while runs are active or queued */
	const liveTimer = setInterval(() => {
		if (manager.active().length > 0 || manager.queuedRuns().length > 0) refreshFleetWidget();
	}, 2000);
	liveTimer.unref?.();
}
