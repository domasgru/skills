---
name: implement
description: "Run the implementation orchestrator for the plan. Pass it like this: /implement <pointer-to-plan>."
disable-model-invocation: true
metadata:
  internal: true
---

Resume following `${CLAUDE_PLUGIN_ROOT}/skills/worktree/SKILL.md`. Run the `implementation-orchestrator` subagent from this plugin and pass it the plan via `plans/<NNN-slug>/plan.md` pointer. Wait for its report by ending your turn.

If the orchestrator fails because its model is unavailable, dispatch it again once with `model: "opus"`, and tell it to pass the same `model` on. A report without a `Status:` line is not its end: `SendMessage` it to finish. On `partial`, dispatch a fresh orchestrator with the plan pointer and `plans/<NNN-slug>/.temp/implement/state.md`. On `blocked` or `failed`, report to the human.

Only once the orchestrator reports `done`, Finish following `${CLAUDE_PLUGIN_ROOT}/skills/worktree/SKILL.md`.