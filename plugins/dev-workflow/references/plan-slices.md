# Slices

How a plan is broken into slices. Shared by the planner and the architect's test planner.

Break the work into **tracer bullet** slices. The default is one slice covering the whole test scenario table. Split only when the work genuinely needs sequencing or outgrows a single fresh context window. Fill the plan with the slices using the template below.

Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."

<vertical-slice-rules>

- Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests): vertical, NOT a horizontal slice of one layer
- A completed slice is demoable or verifiable on its own
- Each slice is sized to fit in a single fresh context window
- Any prefactoring should be done first

</vertical-slice-rules>

Give each slice its **blocking edges**: the other slices that must complete before it can start. A slice with no blockers can start immediately.

**Wide refactors are the exception to vertical slicing.** A **wide refactor** is one mechanical change (rename a column, retype a shared symbol) whose **blast radius** fans across the whole codebase, so a single edit breaks thousands of call sites at once and no vertical slice can land green. Don't force it into a tracer bullet; sequence it as **expand–contract**. First expand: add the new form beside the old so nothing breaks. Then migrate the call sites over in batches sized by blast radius (per package, per directory), each batch its own slice blocked by the expand, keeping CI green batch to batch because the old form still exists. Finally contract: delete the old form once no caller remains, in a slice blocked by every migrate batch. When even the batches can't stay green alone, keep the sequence but let them share an integration branch that all block a final integrate-and-verify slice; green is promised only there.

<plan-slices-template>
## Slices

One entry per slice, in dependency order (blockers first). A feature that needs no breakdown has exactly one slice covering the whole test scenario table.

### S<N>: <slice-title>

**What to build:** the end-to-end behaviour or technical change this slice makes work, from the user's perspective, not a layer-by-layer implementation list.

**Blocked by:** the IDs/titles of the slices that gate this one, or "None (can start immediately)".

**Requirements:** the `R<N>` IDs this slice delivers, in full or in the part named.

**Test scenarios:** the `T<N>` IDs this slice turns green, in order, or "None".

- [ ] Acceptance criterion 1
- [ ] Acceptance criterion 2

A requirement this slice delivers that is verified without a test appears as an acceptance criterion naming its check.

Avoid specific file paths or code snippets in a slice: they go stale fast. The exception is the same as for implementation decisions.
</plan-slices-template>
