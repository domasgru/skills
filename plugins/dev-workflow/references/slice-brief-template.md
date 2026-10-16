# Slice brief

What an implementer works from: one slice, self-contained. The implementation orchestrator writes it to `plans/<NNN-slug>/.temp/slices/S<N>.md` just before dispatching the slice, from the plan, the docs, and what the earlier slices actually built. The implementer reads the brief and the code, nothing else, so whatever it needs from `plan.md` or `docs/` is copied in here, not pointed at.

<slice-brief-template>
# S<N>: <slice-title>

## Goal

What this slice makes work, end to end, in two or three sentences.

## Requirements

Each `R<N>` this slice delivers, its text quoted from the plan, cut to the part this slice delivers.

## Design

The part of the plan's design this slice builds, copied: the types, signatures and module placement it adds or changes, the files it touches, and the invariants and lifecycle rules they carry. Leave out the parts of the design other slices build.

## Rules that apply

Each rule from `docs/architecture.md`, `docs/domain-model.md` or the repo's standards that this slice's code can break, quoted with its section, e.g. a threading rule for a new queue, a dependency rule for a new import, a naming rule for a new type. Only the rules this slice can break.

## Tests

Each `T<N>` row this slice turns green, copied whole: its seam, setup, action and expected result. Then each check under Verified without a test that this slice owns.

## Starting point

What the earlier slices built that this one builds on, and every place they departed from the plan, from their reports and commits. "None" for the first slice.

## Done when

The slice's acceptance criteria, copied, and the repo's quick gate is green.
</slice-brief-template>
