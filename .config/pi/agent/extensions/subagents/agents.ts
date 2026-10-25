/**
 * Agent discovery and configuration.
 *
 * Agents are markdown files with YAML frontmatter. Discovery merges three
 * sources with increasing precedence (project wins over user, user wins over
 * builtin):
 *
 *   1. builtin  - bundled with this extension (extensions/subagents/agents)
 *   2. user     - ~/.config/pi/agent/agents  (override builtins, add your own)
 *   3. project  - .pi/agents in cwd or an ancestor (repo-controlled)
 *
 * Frontmatter fields:
 *   name                 - agent id used by the subagent tool
 *   description          - shown to the parent LLM when choosing an agent
 *   aliases              - optional comma-separated alternative names
 *   tools                - comma-separated tool allowlist
 *   model                - optional model override (e.g. "opencode/big-pickle")
 *   thinking             - optional thinking level: off|minimal|low|medium|high|xhigh|max
 *   isolation            - optional "worktree": run the agent in an isolated git worktree
 *   systemPromptMode     - "replace" (default) or "append"
 *   inheritProjectContext - true|false - inherit AGENTS.md / context files
 */

import * as fs from "node:fs";
import * as path from "node:path";
import {
	CONFIG_DIR_NAME,
	getAgentDir,
	parseFrontmatter,
} from "@earendil-works/pi-coding-agent";

export type AgentScope = "user" | "project" | "both";
export type AgentSource = "builtin" | "user" | "project";

export interface AgentConfig {
	name: string;
	aliases: string[];
	description: string;
	tools?: string[];
	model?: string;
	thinking?: string;
	isolation?: "worktree";
	systemPrompt: string;
	source: AgentSource;
	filePath: string;
}

export interface AgentDiscoveryResult {
	agents: AgentConfig[];
	projectAgentsDir: string | null;
}

function loadAgentsFromDir(
	dir: string,
	source: AgentSource,
	skipNames: Set<string> = new Set(),
): AgentConfig[] {
	const agents: AgentConfig[] = [];
	if (!fs.existsSync(dir)) return agents;

	let entries: fs.Dirent[];
	try {
		entries = fs.readdirSync(dir, { withFileTypes: true });
	} catch {
		return agents;
	}

	for (const entry of entries) {
		if (!entry.name.endsWith(".md")) continue;
		if (!entry.isFile() && !entry.isSymbolicLink()) continue;

		const filePath = path.join(dir, entry.name);
		let content: string;
		try {
			content = fs.readFileSync(filePath, "utf-8");
		} catch {
			continue;
		}

		let frontmatter: Record<string, string>;
		let body: string;
		try {
			({ frontmatter, body } = parseFrontmatter<Record<string, string>>(content));
		} catch {
			continue;
		}

		if (!frontmatter.name || !frontmatter.description) continue;

		const name = frontmatter.name.trim();
		if (skipNames.has(name)) continue;

		const tools = frontmatter.tools
			?.split(",")
			.map((t) => t.trim())
			.filter(Boolean);
		const aliases = frontmatter.aliases
			?.split(",")
			.map((a) => a.trim())
			.filter(Boolean) ?? [];

		agents.push({
			name,
			aliases,
			description: frontmatter.description.trim(),
			tools: tools && tools.length > 0 ? tools : undefined,
			model: frontmatter.model?.trim() || undefined,
			thinking: frontmatter.thinking?.trim() || undefined,
			isolation: frontmatter.isolation?.trim() === "worktree" ? "worktree" : undefined,
			systemPrompt: body,
			source,
			filePath,
		});
	}

	return agents;
}

function isDirectory(p: string): boolean {
	try {
		return fs.statSync(p).isDirectory();
	} catch {
		return false;
	}
}

function findNearestProjectAgentsDir(cwd: string): string | null {
	let currentDir = cwd;
	while (true) {
		const candidate = path.join(currentDir, CONFIG_DIR_NAME, "agents");
		if (isDirectory(candidate)) return candidate;

		const parentDir = path.dirname(currentDir);
		if (parentDir === currentDir) return null;
		currentDir = parentDir;
	}
}

/** Builtin agents bundled with this extension. */
export function getBuiltinAgentsDir(): string {
	return path.join(__dirname, "agents");
}

export function discoverAgents(cwd: string, scope: AgentScope): AgentDiscoveryResult {
	const userDir = path.join(getAgentDir(), "agents");
	const projectAgentsDir = findNearestProjectAgentsDir(cwd);
	const builtinDir = getBuiltinAgentsDir();

	const merged = new Map<string, AgentConfig>();
	const merge = (agents: AgentConfig[]) => {
		for (const agent of agents) {
			merged.set(agent.name, agent);
			for (const alias of agent.aliases) {
				if (!merged.has(alias)) merged.set(alias, { ...agent, name: alias });
			}
		}
	};

	if (scope !== "project") {
		merge(loadAgentsFromDir(builtinDir, "builtin"));
		merge(loadAgentsFromDir(userDir, "user"));
	}
	if (scope !== "user" && projectAgentsDir) {
		merge(loadAgentsFromDir(projectAgentsDir, "project"));
	}

	return {
		agents: Array.from(merged.values()),
		projectAgentsDir,
	};
}

export function findAgent(agents: AgentConfig[], name: string): AgentConfig | undefined {
	return agents.find((a) => a.name === name);
}

export function formatAgentList(agents: AgentConfig[], maxItems = 30): { text: string; remaining: number } {
	if (agents.length === 0) return { text: "none", remaining: 0 };
	const listed = agents.slice(0, maxItems);
	return {
		text: listed
			.map((a) => `${a.name} (${a.source}): ${a.description}`)
			.join("; "),
		remaining: agents.length - listed.length,
	};
}
