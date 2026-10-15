---
name: why
description: "Use for 'why does X work this way', 'why we picked Y', design rationale, regressions, or where a threshold came from. Searches git history and PRs alongside plans/ in parallel, then returns a cited read on decisions and tradeoffs. Use how for runtime behavior."
disable-model-invocation: true
metadata:
  internal: true
---

# Why

Investigate the motivation and intent behind code.

Companion to the `how` skill. `how` answers what the code does and how it works. `why` answers what forces led to its shape.

The evidence lives in two places: source control (git history, PRs, code comments, tests) and `plans/` (each change's `plan.md` and `development-logs.md`). Never use `research/` as evidence.

## Step 1. Understand the Target and the Question

Parse what the user is asking. The **target** is usually a chunk of code, a pattern, a feature, or a named design decision. The **question** is usually a design rationale, a tradeoff, a motivating edge case, an external constraint, dead code, or a broad history sweep.

If the target is vague ("why do we do it this way?" with no clear referent), make your best guess from conversation context (open files, recent edits, what was just discussed). State your interpretation briefly so the user can redirect if you're off, then proceed.

## Step 2. Establish the Code Anchor

Before spawning investigators, anchor the investigation in concrete code. Build this inline:

- The relevant file path(s) and line range(s)
- The key symbols (function names, type names, constants)
- An initial commit list: the last few commits touching the target
- PR numbers from merge commits (pattern `(#1234)` in the subject line), if any
- Plan directories: `feature/<NNN-slug>` branches containing those commits map to `plans/<NNN-slug>/`

```bash
git blame -L <start>,<end> <file>
git log --oneline -20 -- <file>
git log -1 --format=%B <commit>
git branch -a --contains <commit>
```

Also note whether the target looks defensive (null checks, retries, timeouts, guards, fallbacks, feature flags).

## Step 3. Spawn Parallel Investigators

Spawn two `why-investigator` subagents from this plugin in a single message, one assigned **source control** and one assigned **plans**. Pass each:

1. Its assigned source
2. The code anchor from Step 2
3. Whether the target looks defensive
4. The user's original question

## Step 4. Synthesize

Once both have returned, spawn one `why-synthesizer` subagent from this plugin. Pass it:

1. Both investigators' findings verbatim, including null results
2. The code anchor from Step 2
3. The user's original question

## Step 5. Present

Present the synthesizer's output to the user. You may lightly edit for clarity or add context from the conversation, but **do not rewrite the confidence language** or drop the What We Don't Know and Sources Consulted sections.

If the user's `why` question is a precursor to changing this code, follow the Sources Consulted block with a Preserve / Change / Avoid / Risk constraint set derived from the findings, suitable for planning the change.

## Common Failure Modes to Avoid

- **Recency bias.** Assuming the most recent commit or plan is authoritative. The current shape is often the accretion of many earlier decisions. Trace back.
