---
name: do
description: Do any task in the repo.
disable-model-invocation: true
metadata:
  internal: true
---

Do any type of task in the repo - implement new features, change existing features, fix malfunctioning features, do any non-behaviour technical change or non-technical change.

The skill files below name their plugin root with a placeholder; it resolves to `${CLAUDE_PLUGIN_ROOT}`.

Route the request by what it changes:
- Changes nothing (a question, an investigation): answer and stop. No plan, no worktree.
- Changes only prose (docs, skills, agent files, comments, etc) or simple code change (changing some style, configuration, variable, etc) : Start a worktree following `${CLAUDE_PLUGIN_ROOT}/skills/worktree/SKILL.md`, with a slug derived from the request. Make the edits, then Finish following the same skill. No plan.
- A more complex code change (new feature, changed behaviour, more complex technical change, bugfix): start a worktree the same way, then write plan and run the loop below. Every plan speaks in `R<N>` requirements, whatever the kind of change.

Pick the planning skill by the size of the design: a new feature or a significant change — one that introduces a new module, data shape, or interface, or reshapes ownership or boundaries between existing ones — goes to `${CLAUDE_PLUGIN_ROOT}/skills/architect/SKILL.md`. A less complex feature or change that fits within existing modules and interfaces goes to `${CLAUDE_PLUGIN_ROOT}/skills/plan/SKILL.md`.

The human never reviews the testing decisions, though the `tdd` skill expects its seams to be agreed up front. The planning agents review their own seams and test scenarios against `${CLAUDE_PLUGIN_ROOT}/references/test-review.md`, and the plan and implementation reviewers check them again, so no test is coupled to the implementation or restates it.

If the human asks for a new feature or a change to an existing feature, specify the requirements, ask the human to review and confirm them, then implement them:
1. Follow the steps in the `${CLAUDE_PLUGIN_ROOT}/skills/specify/SKILL.md` skill for the human's request. Once done, show the user the plan and ask for confirmation to proceed.
2. After confirmation, follow the planning skill picked above with the pointer to the plan.
3. Once planning is done, follow the `${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md` skill, without human review.

If the human asks to fix a malfunctioning feature, first reproduce the bug in the worktree, in an end-to-end setting as close as possible to how the user encounters it. Then debug to find the root cause of why the feature is not working as expected. Additionally, check whether an existing test should have covered this case. If the root cause is that the product requirement itself was wrong or missing, treat it as a change in existing feature. Otherwise frame it and proceed as a technical change: restate the violated behaviour as a requirement and the reproduction as its scenario.

If the human asks for a technical change, plan and implement it without human review:
1. Write the technical change to `plans/<NNN-slug>/plan.md` using the template below.
2. Follow the planning skill picked above with the pointer to the plan.
3. Once planning is done, follow the `${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md` skill for it, without human review.

<technical-change-template>

# Plan: <technical change title>

## Problem statement

What is wrong or missing today and why it matters. Include the root cause when this is a bug fix.

## Requirements

What must hold when the change is done, in engineering terms, so a reader who has not seen the request can judge whether the implementation matches it. Same format as a feature plan: `### R<N>. <name>` with a MUST statement, numbered `R1`, `R2`, ... Scenarios (`#### Scenario:` with GIVEN/WHEN/THEN) are optional here; add one where the outcome is observable, such as a bug reproduction. Length scales with the change: a config update may be one requirement, a cleanup may be "Observable behaviour MUST not change".

<requirements-example>
### R1. CI runs the test suite on every pull request
Every pull request MUST run the full test suite and report its result on the PR.
</requirements-example>

## Non-goals

What a reader would reasonably assume is in this change and is not, each with the reason.

</technical-change-template>
