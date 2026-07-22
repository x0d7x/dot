---
description: Run a review loop on a change, applying feedback, up to N rounds
argument-hint: "[change] [max-rounds]"
---
Use the subagent tool to run a review loop on: $@

1. Run the "reviewer" agent to review the change.
2. Apply the actionable feedback with the "worker" agent.
3. Re-run the reviewer on the updated change.
4. Repeat until the reviewer reports no blockers, or up to ${2:-3} rounds.

Keep the loop tight: skip rounds when feedback is empty or cosmetic.
