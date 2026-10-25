---
description: Run parallel reviewers (correctness, tests, simplicity) and synthesize findings
argument-hint: "[change]"
---
Use the subagent tool with the tasks parameter to run three reviewers in parallel:

1. { "agent": "reviewer", "task": "Review for correctness, bugs and edge cases: $@" }
2. { "agent": "reviewer", "task": "Review test coverage and whether tests validate the change: $@" }
3. { "agent": "reviewer", "task": "Review for unnecessary complexity and readability: $@" }

Then synthesize the findings into a single prioritized list (blockers first) and decide what to fix.
