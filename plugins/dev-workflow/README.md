# Development workflow
This document describes how we turn the product vision into a complete, high-quality application.
## Vocabulary
- **Feature** — a part of the product that is specified and shipped as one unit. One feature is one `plan.md`, one branch, one worktree, one PR.
- **Slice** — the smallest unit of work that cuts a narrow but complete path through every layer of the system (schema, API, UI, tests), demoable or verifiable on its own and small enough for one agent to finish in a single fresh context window. A feature is implemented as one or more slices; a slice is never a horizontal layer.
## Docs structure
- `docs/product-overview.md` — what & why, product docs, high level, changes rarely. Every product decision lives here, or in a feature-specific product doc this one points to.
- `docs/domain-model.md` - what the data is: glossary, an example on disk, then one section per entity (meaning, relationships, invariants, deletion, conflict resolution). Low level, changes with features.
- `docs/architecture.md` — how: only the core decisions that hold across the whole codebase (process shape, module boundaries, threading rules, on-disk formats, the local store). Changes rarely. Feature-level decisions live in that feature's `plan.md` while it is being built and in the code and its tests afterwards; the codebase is the specification.
- `plans/<NNN-slug>/` — one directory per implementation of a feature or technical request, holding that feature's `plan.md` and `development-logs.md`, low level.
## Delivery phases
1. Product overview document
2. Domain model document
3. Architecture document
4. Infrastructure set up (Repo CI/CD)
5. Walking skeleton implementation — the first feature, built thin end to end
6. Iterative further features implementation
7. Security and reliability hardening
8. QA/Polish
9. Release
## Worktrees
Every write made under a workflow skill (**/specify**, **/plan**, **/architect**, **/implement**, **/do**) happens in `.claude/worktrees/<NNN-slug>` on `feature/<NNN-slug>`, cut from the latest `main`. Read-only work (questions, investigations, **/how**, **/why**, **/research**) may run on `main`. The main checkout is edited only by the human, or by an agent working outside the workflow skills. Merged worktrees are pruned automatically at the next start, or by hand with **/worktree prune**. The `worktree` skill owns the lifecycle.
## Feature development loop
### Supervised
1. **Human** triggers **/specify <feature-description>** skill. **Main-agent** starts the feature's worktree, interviews human and writes down detailed product requirements for a feature using high-level product overview document and additional human input. Reviewed by **prd-reviewer**; the main agent triages the findings and a **generic** subagent applies the accepted ones.
2. **Human** reviews and makes any needed changes, manually or by asking the agent.
3. **Human** triggers **/plan** or **/architect** skill. Either resumes the feature's worktree. **/plan**: **Planner-agent** writes down implementation decisions and testing decisions, breaks the feature into one or more slices, and updates `docs/domain-model.md` where needed. `docs/architecture.md` is touched only when the plan changes a core decision, never to record feature-level ones. Reviewed by **plan-reviewer**, fixed by **planner-agent**. **/architect**, for new features and significant changes: **Architect-agent** grounds the problem by reading the sources and probing the platform itself, has two runner agents sketch competing designs in parallel and a cross-judge score them, synthesizes one design into the plan, then has an **architect-test-planner** agent, in a fresh context, write the testing and validation decisions and slices and report what it finds wrong with the design, folds those findings back into the design, and updates the docs the same way. The arena and the test planner's findings are its review round.
4. **Human** reviews and makes any needed changes, manually or by asking the agent.
5. **Human** triggers **/implement** skill. It resumes the feature's worktree. **Implementation-orchestrator-agent** orchestrates slice-by-slice feature implementation, following the feature plan document. It first commits the plan and doc updates to the feature branch, then implements each slice in a fresh **implementer-agent** passing only the relevant context by text or pointers to other relevant documents. Each successfully implemented slice is a commit in the feature branch. Finally, the whole feature implementation is reviewed by the **implementation-reviewer** agent, which runs **implementation-plan-reviewer** and **implementation-standards-reviewer** in parallel; accepted findings are fixed by an **implementer-agent** and committed.
6. **Main agent** opens the PR from the worktree.
### Unsupervised
1. **Human** triggers **/do <request>** skill. **Main-agent** does the same steps as supervised feature development loop, except the only human review window is after **specify** step - once human approves the plan with product requirements the main agent runs the rest of development loop unsupervised and opens the PR when completed.

## The `/do` skill
Does any type of task in the repository - implements new features, changes existing features, fixes malfunctioning features, or does any technical change. Features get one human review window after **specify**. Bug fixes and technical changes state their requirements in `plans/<NNN-slug>/plan.md` and run **plan** or **architect**, and **implement**, with no human review. A bug whose root cause is a wrong or missing product requirement is treated as a feature change, so it gets the **specify** review window. Prose edits get a worktree, a branch and a PR, with no plan. Only questions and investigations are answered directly. New features and significant changes are planned with **architect**, less complex features and small to medium changes with **plan**.

## Development logs
`plans/<NNN-slug>/development-logs.md` has one section per stage of the loop. Each stage records what its review round found and what was done about it, one bullet per accepted finding, plus anything else worth remembering about that stage. A stage writes its section only after the fixes are in the documents or the code, so the log never describes a change that is not there. The log is a record for humans; later stages take their input from `plan.md`, not from the log. **specify** writes the Specify section, **planner** or **architect** writes Plan, **implementation-orchestrator** writes Implement. Whichever stage runs first creates the file from the template in [`references/development-logs-template.md`](references/development-logs-template.md). A stage with nothing to record says "None".
