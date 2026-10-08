---
name: plan
description: "Run a planner subagent to create an implementation plan. Pass it like this: /plan <pointer-to-plan>"
disable-model-invocation: true
metadata:
  internal: true
---

Resume following `${CLAUDE_PLUGIN_ROOT}/skills/worktree/SKILL.md`. You have been provided new product requirements, changed product requirements or technical change request via `plans/<NNN-slug>/plan.md` pointer. Run the `planner` subagent from this plugin to prepare this document for the `/implement` step.