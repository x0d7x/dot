---
name: pi-subagents
description: |
  Delegate work to specialized subagents (scout, researcher, planner, worker,
  reviewer, context-builder, delegate) with isolated context windows, optional
  background execution, parallel and scripted workflows. Use for code review,
  codebase recon, research, planning, implementation handoffs, and second
  opinions. Use the `subagent` tool when a focused child session is better than
  doing the work inline.
---

# Pi Subagents

This skill is for the main parent orchestrator only. Do not inject or follow it inside spawned child subagents. The parent session owns delegation, orchestration, and final decision-making.

Use the `subagent` tool when the work benefits from a focused child session with its own context window: review, scouting, research, planning, implementation handoffs, parallel audits, or anything that would pollute or overflow the parent context.

## Choosing an agent

| Agent | Use it when you want... |
|-------|--------------------------|
| `scout` | Fast local codebase recon: relevant files, entry points, data flow, risks. |
| `researcher` | Web/docs research with sources and a concise research brief. |
| `planner` | A concrete implementation plan from existing context. Reads and plans, does not edit. |
| `worker` | Implementation work. Edits files, validates, escalates unapproved decisions instead of guessing. |
| `reviewer` | Code review and small fixes against the task/plan, tests, edge cases, and simplicity. |
| `context-builder` | A setup pass before planning: gathers code context and writes handoff material. |
| `delegate` | A lightweight general delegate that behaves close to the parent session. |

Rule of thumb: `scout` before you understand the code, `researcher` before you trust external facts, `planner` before a bigger change, `worker` to implement, `reviewer` to check.

## How to delegate

- **Single**: `{ "agent": "reviewer", "task": "Review this diff..." }`
- **Parallel**: `{ "tasks": [{ "agent": "reviewer", "task": "..." }, ...] }`
- **Chain**: `{ "chain": [{ "agent": "scout", "task": "..." }, { "agent": "planner", "task": "Plan using {previous}" }, ...] }`
- **Scripted**: `{ "workflowScript": "const a = await runs.run('scout', {...}); await runs.all([...]); return;" }` — starts in the background by default; pass `async: false` for a small foreground run.
- **Background**: set `async: true` (or rely on `asyncByDefault` config). The tool returns a run id immediately; a completion summary is delivered later. Use `/subagents-fleet` to inspect running work, or ask "show me the active subagent runs".

## Common workflows

| Want | Ask naturally |
|------|---------------|
| Review a diff | "Use reviewer to review this diff." |
| Run parallel reviewers | "Run reviewers for correctness, tests, and cleanup." |
| Implement then review | "Implement this, then review it." |
| Review until clean | "Run a review loop on this change with a max of 3 rounds." |
| Execute a plan carefully | "Have worker implement this approved plan, then run reviewers and apply the feedback." |
| Scout before planning | "Use scout to inspect the auth flow before planning." |
| Run in the background | "Run this in the background." |

## Always-on constraints

- Keep the parent as orchestrator and final decision-maker.
- Use one writer per cwd unless isolated worktrees are intentional.
- For cross-codebase work, record the target repo, explicit `cwd`, and expected output before launch.
- For parallel fanout, compare child prompts before launch. Do not send clone prompts with only issue numbers or file globs swapped; each child needs a lane-specific task.
- Use async/background by default when work can proceed independently.
- Background runs are queued behind `maxConcurrency` — expect queued runs to
  wait, and tell the user when you spawned more runs than the limit.
- For parallel work that edits files, set `isolation: "worktree"` so each
  lane works on its own copy and lands on a `pi-subagent/*` branch.
- Escalate unresolved product, architecture, authority, or safety decisions upward instead of letting a child decide silently.
- A subagent's final output is the contract: read it fully before acting on it, and verify claims against the code when they matter.

## Management

- `/subagents` — list agents and active runs
- `/subagents-fleet` — interactive inspector (view transcripts, stop runs)
- `/subagents-doctor` — health check for the subagents setup
