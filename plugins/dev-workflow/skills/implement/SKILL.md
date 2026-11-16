---
name: implement
description: "Run the implementation orchestrator for the plan. Pass it like this: /implement <pointer-to-plan>."
disable-model-invocation: true
metadata:
  internal: true
---

Resume following `${CLAUDE_PLUGIN_ROOT}/skills/worktree/SKILL.md`. Run the `implementation-orchestrator` subagent from this plugin and pass it the plan via `plans/<NNN-slug>/plan.md` pointer.

Once the orchestrator reports every slice committed, Finish following `${CLAUDE_PLUGIN_ROOT}/skills/worktree/SKILL.md`. A report that is only interim, one that says it is waiting or leaves slices uncommitted with nothing failed, is not the final report. When its notification says the orchestrator stopped with background work still running, end your turn: its next notification brings the next report (`${CLAUDE_PLUGIN_ROOT}/references/waiting.md`). Otherwise check the branch and resume the orchestrator with SendMessage. On any other report, pass it to the human and stop, with the worktree as it is.