---
name: implement
description: "Implement the plan slice by slice in implementer subagents. Pass it like this: /implement <pointer-to-plan>."
disable-model-invocation: true
metadata:
  internal: true
---

Resume following `${CLAUDE_PLUGIN_ROOT}/skills/worktree/SKILL.md`, then run the steps below yourself, from the `plans/<NNN-slug>/plan.md` pointer. Invoke the `codebase-design` skill from this plugin before step 1.

Communication to and from subagents should be sparse, so your context stays small across the whole loop. An implementer works from a **slice brief**, one self-contained file per dispatch, and never from the plan or the docs: you are the one agent of this stage that reads those, and the brief carries what an implementer needs from them. Dispatch it with the brief's path and nothing else.

**Waiting.** Every implementer and reviewer notifies you directly. One that stops while its own background work runs sends a waiting line: that is interim, so end your turn and its next notification brings the next report (`${CLAUDE_PLUGIN_ROOT}/references/waiting.md`). Its final report moves you to the next step.

**Watcher.** While the steps run, keep a watcher on the worktree: a Monitor at its 30-minute maximum, re-armed on each expiry, whose script reports new commits on the feature branch and every test or build process of the worktree older than 30 minutes (macOS `ps` has `etime`, as `[[dd-]hh:]mm:ss`, not `etimes`). A hung command notifies no one, so an old process or 30 minutes without a commit is a stall to investigate, not progress: sample the process, then kill its tree and resume the implementer with SendMessage, or dispatch it again.

## Steps

1. Read the implementation plan, `docs/architecture.md` and `docs/domain-model.md`. When relevant use an **exploration subagent** to conduct any exploration required by the slices - relevant codebase files or external documentation. Exploration subagent saves its markdown notes in `plans/<NNN-slug>/.temp/`, where all later subagents can read them.

2. You run inside the feature's worktree on `feature/<NNN-slug>`, named after the plan directory. If `git branch --show-current` disagrees, stop and tell the human rather than switch or create branches. Commit the `plans/<NNN-slug>/` directory and any updated `docs/` files as the first commit on the branch.

3. Go through each slice one by one. Write its brief to `plans/<NNN-slug>/.temp/slices/S<N>.md` following `${CLAUDE_PLUGIN_ROOT}/references/slice-brief-template.md`, then dispatch the `implementer` subagent from this plugin with the brief's path. A brief is done when an implementer could build the slice from it and the code alone. Its Tests section names the UI tests the slice adds or changes, the one UI run the implementer makes; a slice that changes what the user sees gets the plan's design references for that view in its Design section and the one screenshot in Done when.

4. Once an **implementer subagent** successfully completes, check its report before committing, without rerunning its tests yourself: its UI run was the slice's own tests, a visual slice has its screenshot compared with the design, and each failure it judged not its slice's says why. Record those failures under **Open** in the implement report (step 8) and dispatch no fix for them. Commit its work to the feature branch. Each implemented slice is one commit on the feature branch. An implementer that reports it could not finish its slice: pass its report to the human and stop, with the worktree as it is.

5. Once all slices are committed, if the repo has a verification skill (`.claude/skills/verify-*/`), dispatch one **implementer subagent** to follow Branch mode in `${CLAUDE_PLUGIN_ROOT}/skills/maintain-verification-skill/SKILL.md`, passing it only the plan path. Commit any edits it leaves to the feature branch and log its outcome line under Implement in `plans/<NNN-slug>/development-logs.md`. A `failed` outcome is a bug in the branch: hand it to the fix in step 7.

6. Run the `implementation-reviewer` subagent from this plugin, passing it the plan path and `main` as the fixed point. Tell it that a verification-skill commit from step 5 is upkeep, not scope creep.

7. Once the review completes, decide which findings to fix. Write them, together with any `failed` verification outcome, to `plans/<NNN-slug>/.temp/slices/fixes.md`: each finding with its file and lines, the rule it breaks quoted, and the fix you decided. Dispatch a single **implementer subagent** with that path, and wait for its final report. Log the fixes under Implement in `plans/<NNN-slug>/development-logs.md`, and commit the fixes and the log to the feature branch.

8. Write what the human needs before merging to `plans/<NNN-slug>/.temp/implement-report.md`: how each `R<N>` holds, every review finding you declined with why, the verification outcome with its evidence path, and under **Open** each test failure an implementer judged not its slice's. The development log holds accepted findings only, so this file is the one place the declined ones reach the human.

9. Finish following `${CLAUDE_PLUGIN_ROOT}/skills/worktree/SKILL.md`. It runs the full gate.
