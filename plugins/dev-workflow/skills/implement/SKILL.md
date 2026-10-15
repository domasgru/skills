---
name: implement
description: "Run the implementation orchestrator for the plan. Pass it like this: /implement <pointer-to-plan>."
disable-model-invocation: true
metadata:
  internal: true
---

Resume following `${CLAUDE_PLUGIN_ROOT}/skills/worktree/SKILL.md`. Run the `implementation-orchestrator` subagent from this plugin and pass it the plan via `plans/<NNN-slug>/plan.md` pointer.

Once the orchestrator reports, Finish following `${CLAUDE_PLUGIN_ROOT}/skills/worktree/SKILL.md`.