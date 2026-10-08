---
name: architect
description: "Run an architect subagent to design a new feature or significant change through parallel design exploration and create its implementation plan. Pass it like this: /architect <pointer-to-plan>"
disable-model-invocation: true
metadata:
  internal: true
---

Resume following `${CLAUDE_PLUGIN_ROOT}/skills/worktree/SKILL.md`. You have been provided new product requirements, changed product requirements or technical change request via `plans/<NNN-slug>/plan.md` pointer. Run the `architect` subagent from this plugin to prepare this document for the `/implement` step. Pass it the plan pointer and the human's instructions verbatim; its definition carries the rest.