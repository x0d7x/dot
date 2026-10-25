# Subagents extension for pi

Delegate work to focused child `pi` processes with isolated context windows:
code review, scouting, research, planning, implementation, parallel audits, and
background jobs. Modeled after the `pi-subagents` npm package and pi's own
`examples/extensions/subagent`.

Highlights:
- **Background queueing** — async runs are gated by `maxConcurrency`; excess
  runs wait in a queue and start as running runs complete (shown in the fleet
  widget as `⏸ N queued`).
- **Git worktree isolation** — set `isolation: "worktree"` (or agent
  frontmatter `isolation: worktree`) to run a subagent in an isolated git
  worktree checked out at current HEAD; its changes are committed to a
  `pi-subagent/*` branch on completion and the worktree is removed.

## Layout

```
~/.config/pi/agent/extensions/subagents/
├── index.ts        # extension entry: subagent tool, async manager, commands, UI
├── agents.ts       # agent discovery (builtin + user + project)
├── async.ts        # background run manager (persistence, restore, notify)
├── fleet.ts        # fleet widget + interactive inspector
├── config.json     # extension config
├── agents/         # builtin agent definitions (markdown + frontmatter)
├── skills/         # pi-subagents skill (loaded via resources_discover)
└── prompts/        # workflow prompt templates (/implement, /parallel-review, ...)
```

## Install

The extension is auto-discovered from `~/.config/pi/agent/extensions/subagents/index.ts`.
If you already have a pi session open, run `/reload`. Then:

- `/subagents` — list agents and active runs
- `/subagents-fleet` — interactive inspector (view transcripts, stop runs)
- `/subagents-doctor` — health check
- Ask in plain language: *"Use reviewer to review this diff"*, *"Run this in the background"*,
  *"Use scout to inspect the auth flow before planning"*.

## Builtin agents

| Agent | Purpose | Tools |
|-------|---------|-------|
| `scout` | fast codebase recon | read, grep, find, ls, bash, write |
| `researcher` | web research brief | read, write, web_search, web_fetch |
| `planner` | implementation plan (no edits) | read, grep, find, ls |
| `worker` | implementation (edits + validation) | read, grep, find, ls, bash, edit, write |
| `reviewer` | code/plan review (+small fixes) | read, grep, find, ls, bash, edit, write |
| `context-builder` | requirements-to-context handoff | + web_search, web_fetch |
| `delegate` | lightweight general agent | same as worker, appends to parent prompt |

Agent files live in `agents/`. Override or extend them from
`~/.config/pi/agent/agents/<name>.md` (user scope) or `.pi/agents/<name>.md`
(project scope, trusted repos only). User/project definitions win over builtins
on name collision. Frontmatter fields: `name`, `aliases`, `description`,
`tools` (comma list), `model`, `thinking`, `isolation` (`worktree`),
`systemPromptMode`, `inheritProjectContext`.

## Usage

The `subagent` tool supports four modes:

```text
{ "agent": "reviewer", "task": "Review this diff." }              # single
{ "tasks": [ {"agent":"reviewer","task":"..."}, ... ] }           # parallel
{ "chain": [ {"agent":"scout","task":"..."}, {"agent":"planner","task":"Plan from {previous}"} ] }  # chain
{ "workflowScript": "const a = await runs.run('scout', {...}); await runs.all([...]);" }            # scripted
```

- `async: true` runs in the background — the tool returns a run id, a live
  fleet widget appears, and a completion summary is delivered when done.
  Runs are persisted under `~/.config/pi/agent/state/subagents/runs/<runId>/`
  and restored across restarts. Background runs queue behind `maxConcurrency`.
- `model` / `thinking` override the agent defaults per call.
- `isolation: "worktree"` runs the subagent in an isolated git worktree
  (created at `<repoRoot>/.pi-subagents-worktrees`, or `worktreesDir` from
  config). The child works on a detached copy of HEAD; on completion any
  changes are committed to `pi-subagent/<agent>-<base-commit>` and the
  worktree is removed. Works in single, parallel (per-task), chain (per-step),
  workflow lanes, and async runs. Also settable per-agent via frontmatter
  `isolation: worktree`.
- `context: "fork"` prepends a compact parent-conversation excerpt.
- `timeoutMs` caps a run (default 30 minutes).

## Config (`config.json`)

| Key | Default | Meaning |
|-----|---------|---------|
| `asyncByDefault` | `false` | run `async:true` unless the call says otherwise |
| `maxConcurrency` | `4` | parallel task concurrency AND background-run queue limit |
| `maxParallelTasks` | `8` | hard cap on parallel tasks |
| `fleetWidget` | `true` | live widget while background runs are active or queued |
| `worktreesDir` | `<repoRoot>/.pi-subagents-worktrees` | where isolated worktrees are created |

## How children are launched

Each subagent runs `pi --mode json -p` in a fresh process with:

- `--no-session` + isolated JSONL output (captured for streaming + transcript)
- `--model <model>` when overridden, with `:thinking` suffix when set
- `--tools <allowlist>` from the agent definition
- `--append-system-prompt <agent.md body>`
- `--no-extensions` + an explicit extension allowlist: all of your
  `~/.config/pi/agent/extensions/*` **except** `permission-gate.ts` (its strict
  mode blocks edits in non-interactive children) — `web-access.ts` and friends
  still load, so `web_search` / `web_fetch` work in children.

`PI_SUBAGENTS_CHILD=1` is set in the child env and the extension factory returns
early, so subagents never spawn subagents recursively.

## Worktree isolation notes

- The parent repo must be a git repository; otherwise the run fails with a
  clear error.
- Worktrees are created at `<repoRoot>/.pi-subagents-worktrees/<runId>`
  (override with `worktreesDir` in config) and removed after commit, so they
  never pollute `git status`.
- Changes land on a `pi-subagent/<agent>-<base-commit>` branch — nothing is
  pushed, merged, or touched in your working copy.
- The result includes a `**Worktree isolation**` section naming the branch,
  commit, and changed-file count.
- If pi dies mid-run, the worktree is cleaned up on the next session start
  (restore removes abandoned worktrees). Queued background worktree runs
  re-launch on restore, reusing their worktree directory.

## Security notes

- Agents are prompts + tool allowlists; a child process runs with your pi
  credentials and shell access. Only use agent definitions you trust.
- Project-scope agents (`.pi/agents`) prompt for confirmation before running.
- `workflowScript` executes inline JavaScript in the extension process — treat
  it as trusted (it originates from your model's tool call, same trust as bash).

## Prompt templates

`/implement`, `/scout-and-plan`, `/implement-and-review`, `/parallel-review`,
`/review-loop` expand into delegation workflows.
