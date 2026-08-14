/**
 * Git/Jujutsu Status Extension - Shows current repo and branch in Pi's UI
 *
 * Supports both Git (.git) and Jujutsu (.jj) repositories.
 *
 * Displays in the status bar:
 *   📂 repo-name  main  ● dirty (if uncommitted changes)
 *   📂 repo-name   change-id (bookmark)  ● dirty
 *
 * Refreshes on session start, model change, and after each turn.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { execSync } from "node:child_process";

interface VcsInfo {
	repo: string;
	branch: string;
	dirty: boolean;
	ahead: number;
	behind: number;
	vcs: "git" | "jj";
}

function runCmd(cmd: string, cwd: string, timeout = 2000): string {
	try {
		return execSync(cmd, {
			cwd,
			encoding: "utf-8",
			timeout,
			stdio: ["ignore", "pipe", "ignore"],
		}).trim();
	} catch {
		return "";
	}
}

/**
 * Detect which VCS is active by checking for .git or .jj directories
 * walking up from cwd.
 */
function detectVcs(cwd: string): "git" | "jj" | null {
	let dir = cwd;
	// Walk up to 10 levels
	for (let i = 0; i < 10; i++) {
		if (existsSync(`${dir}/.jj`)) return "jj";
		if (existsSync(`${dir}/.git`)) return "git";
		const parent = dir.lastIndexOf("/");
		if (parent <= 0) break;
		dir = dir.slice(0, parent);
	}
	return null;
}

/** Get VCS info for Git repos */
function getGitInfo(cwd: string): VcsInfo | null {
	const topLevel = runCmd("git rev-parse --show-toplevel 2>/dev/null", cwd);
	if (!topLevel) return null;

	const branch = runCmd("git rev-parse --abbrev-ref HEAD 2>/dev/null", cwd);
	if (!branch) return null;

	const repo = topLevel.split("/").pop() || topLevel;
	const status = runCmd("git status --porcelain 2>/dev/null", cwd);
	const dirty = status.length > 0;

	// Ahead/behind
	const aheadBehind = runCmd(
		"git rev-list --count --left-right HEAD...@{upstream} 2>/dev/null",
		cwd,
	);
	let ahead = 0;
	let behind = 0;
	if (aheadBehind) {
		const parts = aheadBehind.split("\t");
		if (parts.length === 2) {
			behind = parseInt(parts[0]) || 0;
			ahead = parseInt(parts[1]) || 0;
		}
	}

	return { repo, branch, dirty, ahead, behind, vcs: "git" };
}

/** Get VCS info for Jujutsu repos */
function getJjInfo(cwd: string): VcsInfo | null {
	const root = runCmd("jj workspace root 2>/dev/null", cwd);
	if (!root) return null;

	const repo = root.split("/").pop() || root;

	// Get current change ID (short form)
	const changeId = runCmd(
		`jj log -r '@' --no-graph -T 'change_id.shortest(8)' 2>/dev/null`,
		cwd,
	);

	// Get bookmarks on current change
	const bookmarks = runCmd(
		`jj log -r '@' --no-graph -T 'bookmarks' 2>/dev/null`,
		cwd,
	);

	// Build a display-friendly branch name
	let branch = changeId ? ` ${changeId}` : " ???";
	if (bookmarks) {
		// bookmarks might be a space-separated list
		const bm = bookmarks.trim();
		if (bm) branch = bm;
	}

	// Check for dirty/uncommitted files
	// jj status exits 0 and shows nothing if clean
	const status = runCmd("jj status 2>/dev/null", cwd);
	const dirty = status.length > 0 && !status.startsWith("The working copy is clean");

	// jj doesn't have a direct ahead/behind concept in the same way
	// We skip ahead/behind for jj

	return { repo, branch, dirty, ahead: 0, behind: 0, vcs: "jj" };
}

function formatStatus(info: VcsInfo, theme: { fg: (style: string, text: string) => string }): string {
	const repoStr = theme.fg("accent", `📂 ${info.repo}`);

	// Different branch icon per VCS
	const branchIcon = info.vcs === "jj" ? " " : " ";
	const branchStr = theme.fg("accent", `${branchIcon} ${info.branch}`);

	let statusStr = repoStr + branchStr;

	if (info.dirty) {
		statusStr += ` ${theme.fg("warning", "●")}`;
	}

	// Only show ahead/behind for git
	if (info.vcs === "git") {
		if (info.behind > 0 && info.ahead > 0) {
			statusStr += ` ${theme.fg("error", `↓${info.behind}`)} ${theme.fg("success", `↑${info.ahead}`)}`;
		} else if (info.behind > 0) {
			statusStr += ` ${theme.fg("error", `↓${info.behind}`)}`;
		} else if (info.ahead > 0) {
			statusStr += ` ${theme.fg("success", `↑${info.ahead}`)}`;
		}
	}

	return statusStr;
}

function refreshStatus(ctx: ExtensionContext): void {
	const cwd = ctx.cwd;
	const theme = ctx.ui.theme;

	const vcs = detectVcs(cwd);

	if (vcs === "jj") {
		const info = getJjInfo(cwd);
		if (info) {
			ctx.ui.setStatus("git-status", formatStatus(info, theme));
		} else {
			ctx.ui.setStatus("git-status", theme.fg("dim", "📂 jj repo (no changes)"));
		}
	} else if (vcs === "git") {
		const info = getGitInfo(cwd);
		if (info) {
			ctx.ui.setStatus("git-status", formatStatus(info, theme));
		} else {
			ctx.ui.setStatus("git-status", theme.fg("dim", "📂 no git repo"));
		}
	} else {
		ctx.ui.setStatus("git-status", theme.fg("dim", "📂 no VCS repo"));
	}
}

export default function (pi: ExtensionAPI) {
	// Show on session start
	pi.on("session_start", async (_event, ctx) => {
		refreshStatus(ctx);
	});

	// Refresh after each turn (to catch branch switches, commits, etc.)
	pi.on("turn_end", async (_event, ctx) => {
		refreshStatus(ctx);
	});

	// Refresh on model change
	pi.on("model_select", async (_event, ctx) => {
		refreshStatus(ctx);
	});
}
