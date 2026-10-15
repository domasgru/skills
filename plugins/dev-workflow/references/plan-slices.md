# Slices

How a plan is broken into slices. Shared by the planner and the architect's test planner.

Break the work into **tracer bullet** slices. The default is one slice covering the whole test scenario table. Split when the work genuinely needs sequencing, or when one slice would be more than one implementer can hold (below). Each slice is its own file, `slices/S<N>.md`, numbered in dependency order (blockers first), written with the template below. (An older plan holds its slices under `## Slices` in `plan.md`, each as `### S<N>: <slice-title>`.)

Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."

<vertical-slice-rules>

- Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests): vertical, NOT a horizontal slice of one layer
- A completed slice is demoable or verifiable on its own
- Each slice is small enough for one implementer to finish in a context that stays well within its working range: as a guide, it turns about 10 test rows or fewer green, touches about 8 source and test files or fewer, and its read set (its slice, its test rows and the design sections it names) with its skills' references stays well under a hundred thousand tokens
- Test harness work that several slices share is a slice of its own, first
- Any prefactoring should be done first

</vertical-slice-rules>

Give each slice its **blocking edges**: the other slices that must complete before it can start. A slice with no blockers can start immediately.

**Wide refactors are the exception to vertical slicing.** A **wide refactor** is one mechanical change (rename a column, retype a shared symbol) whose **blast radius** fans across the whole codebase, so a single edit breaks thousands of call sites at once and no vertical slice can land green. Don't force it into a tracer bullet; sequence it as **expand–contract**. First expand: add the new form beside the old so nothing breaks. Then migrate the call sites over in batches sized by blast radius (per package, per directory), each batch its own slice blocked by the expand, keeping CI green batch to batch because the old form still exists. Finally contract: delete the old form once no caller remains, in a slice blocked by every migrate batch. When even the batches can't stay green alone, keep the sequence but let them share an integration branch that all block a final integrate-and-verify slice; green is promised only there.

<plan-slices-template>
# S<N>: <slice-title>

**What to build:** the end-to-end behaviour or technical change this slice makes work, from the user's perspective, not a layer-by-layer implementation list, in a short paragraph. The design says how; don't restate it.

**Blocked by:** the IDs/titles of the slices that gate this one, or "None (can start immediately)".

**Requirements:** the `R<N>` IDs this slice delivers, in full or in the part named.

**Test scenarios:** the `T<N>` IDs this slice turns green, in order, or "None".

**Design sections:** the exact headings in `design.md` this slice builds, separated by `;`. `plan.py slice` gives the implementer these sections and no others.

**Skills:** one line per installed skill whose guidance bears on this slice's work, per [Skills](#skills) below:
- invoke `<skill>`: <what in this slice it guides>; references: <the reference files that cover it>
- covered `<skill>`: by <plan file and heading, or repo doc and heading>, which state <what>

or "None: no installed skill bears on this slice."

- [ ] Acceptance criterion 1
- [ ] Acceptance criterion 2

A requirement this slice delivers that is verified without a test appears as an acceptance criterion naming its check.

Avoid specific file paths or code snippets in a slice: they go stale fast. The exception is the same as for implementation decisions. Implementers append `## Implementation notes` below the criteria: deviations, manual checks, and a `### Handoff` when one stops early.
</plan-slices-template>

## Skills

Installed skills carry guidance a plan rarely restates: an API's current shape, a framework's pitfalls, a testing library's idioms. Each slice says which ones its implementer uses, so the choice is made once, by the agent that sees the whole plan, and the implementation review can check the code against them.

- **Which skills exist.** The Skill tool lists the skills installed for this project, each with what it is for, and the repo's `AGENTS.md` or `CLAUDE.md` may name skills for an area. Never name a skill that is not listed. Never assume one is installed because another project had it.
- **Which bear on a slice.** A skill bears on a slice when its description covers a language, framework, library, platform or kind of test the slice's work uses. Invoke each candidate with the Skill tool and read its own index of references; name the references that cover the slice's work, not all of them.
- **`invoke` or `covered`.** A skill is `covered` only when you invoked it, and a plan file or a repo doc the implementer reads anyway states every rule from it that this slice needs; name where. Otherwise it is `invoke`. When unsure, `invoke`: a skill read twice costs a few thousand tokens, guidance missed costs a review round.
- **Size.** A slice whose skills and references would run to several large files spans too many areas: split it.
