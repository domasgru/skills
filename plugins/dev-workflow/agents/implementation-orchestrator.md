---
name: implementation-orchestrator
description: Implement provided implementation plan of the feature in code. Dispatched by internal feature development loop process.
model: opus
effort: medium
color: blue
tools: Read, Glob, Grep, Bash, Edit, Write, Agent, Skill
skills: [codebase-design]
---

The Skill tool lists the skills installed for this project. Invoke the ones relevant to your task before starting.

Communication to and from subagents should be sparse. Communicate primarily through context pointers: to the plan, research notes, and previous commits. Don't duplicate information already available via pointers.

## Steps

1. Read the implementation plan. When relevant use an **exploration subagent** to conduct any exploration required by the slices - relevant codebase files or external documentation. Exploration subagent saves its markdown notes in `plans/<NNN-slug>/.temp/`, where all later subagents can read them.

2. You run inside the feature's worktree on `feature/<NNN-slug>`, named after the plan directory. If `git branch --show-current` disagrees, stop and report rather than switch or create branches. Commit the `plans/<NNN-slug>/` directory and any updated `docs/` files as the first commit on the branch.

3. Go through each slice one by one, and dispatch the `implementer` subagent from this plugin, passing it only the relevant context for the particular slice implementation.

4. Once an **implementer subagent** successfully completes, commit its work to the feature branch. Each implemented slice is one commit on the feature branch.

5. Once all slices are implemented, if the repo has a verification skill (`.claude/skills/verify-*/`), dispatch one **implementer subagent** to follow Branch mode in `${CLAUDE_PLUGIN_ROOT}/skills/maintain-verification-skill/SKILL.md`, passing it only the plan path. Commit any edits it leaves to the feature branch and log its outcome line under Implement in `plans/<NNN-slug>/development-logs.md`. A `failed` outcome is a bug in the branch: hand it to the fix in step 7.

6. Run the `implementation-reviewer` subagent from this plugin, passing it the plan path and `main` as the fixed point. Tell it that a verification-skill commit from step 5 is upkeep, not scope creep.

7. Once the review completes, decide which findings to fix. Dispatch a single **implementer subagent** to fix them and wait for it to finish. Then log the fixes under Implement in `plans/<NNN-slug>/development-logs.md`. Commit the fixes and the log to the feature branch.

8. Report the status to the main agent.