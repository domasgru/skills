---
name: architect
description: "Run an architect subagent to design a new feature or significant change through parallel design exploration and create its implementation plan. Pass it like this: /architect <pointer-to-plan>"
disable-model-invocation: true
metadata:
  internal: true
---

Resume following `${CLAUDE_PLUGIN_ROOT}/skills/worktree/SKILL.md`. You have been provided new product requirements, changed product requirements or technical change request via `plans/<NNN-slug>/plan.md` pointer. Run the `architect` subagent from this plugin to prepare this document for the `/implement` step. Pass it the plan pointer and the human's instructions verbatim; its definition carries the rest. Wait for its report by ending your turn.

If the architect fails because its model is unavailable, dispatch it again once with `model: "opus"` and tell it to pass the same `model` to every agent it dispatches. If it reports `partial`, dispatch a fresh architect with the plan pointer: its `state.md` carries where it stopped. To fold in the human's answers or changes later, dispatch a fresh architect with the plan pointer and the answers verbatim; never `SendMessage` an architect that has reported.

Show the human the architect's report: the plan's files, and each open question by title.