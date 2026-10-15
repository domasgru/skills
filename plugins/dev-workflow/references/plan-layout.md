# Plan layout

The files of a feature's plan, their intended sizes, and who reads what. Shared by every agent that writes or reads a plan.

## Files

`plans/<NNN-slug>/`:

| file | holds | written by | aim |
|---|---|---|---|
| `plan.md` | the problem, the requirements (`R<N>`), the non-goals; then `## Plan files`, an index of the files below with one line each | specify, or `/do` for a technical change; the index by the architect or the planner | none |
| `design.md` | the design package (`/architect`) or the implementation decisions (`/plan`) | architect-synthesizer, or planner | readable in one Read call: under about 20k tokens (50 KB) |
| `testing.md` | Testing Decisions: Strategy, Test scenarios, Verified without a test | architect-test-planner, or planner | the same |
| `slices/S<N>.md` | one slice, per `plan-slices.md`; implementers append `## Implementation notes` | architect-test-planner, or planner; implementers | about a page |
| `development-logs.md` | one section per stage, per its template | each stage | none |
| `.temp/` | working files: `architect/` (grounding, candidates, rounds, state), `slices/S<N>-read.md` (read sets) | the agents named | none; not read by later stages |

The aims are guidance for the writer, not limits anything checks. `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/plan.py size <file>` estimates a file's tokens. A design that will not fit one Read is a sign the feature may be too large to design in one piece: the architect says so in its report, with the split the slices suggest.

Older plans hold Design (or Implementation Decisions), Testing Decisions and Slices inside `plan.md`. `plan.py` reads both layouts; don't convert an older plan unless you must revise it (`plan.py split`).

## Who reads what

Each role reads whole only what its row lists, and everything else by section, for a specific question.

| role | reads whole | reads by section, for a question |
|---|---|---|
| architect (coordinator) | `plan.md`, `grounding/index.md`, `state.md`, the round ledgers | the code anchor for `why`, a directory listing for `how` |
| grounder, platform mode | `plan.md` | sources, skill references, `research/` |
| grounder, index mode | `plan.md`, `how.md`, `why.md`, `platform.md`, `docs/architecture.md`, `docs/domain-model.md` | raw findings, code |
| runners | `plan.md`, `grounding/index.md`, `how.md`, the task | `why.md`, `docs/` sections the index cites, code |
| judge | the rubric, both candidates, `plan.md`, `grounding/index.md` | code, to check a claim |
| synthesizer, synthesize mode | `plan.md`, `grounding/index.md`, the task, the rubric, both candidates, `judge.md` | code, to settle a graft |
| synthesizer, revise mode | `plan.md`, `grounding/index.md`, `design.md`, `synthesis.md`, the findings and ledgers | the candidates (searched), code and docs a finding cites |
| synthesizer, finalize mode | `plan.md`, `design.md`, `slices/S1.md`, `docs/architecture.md`, `docs/domain-model.md` | open findings |
| verifier | `plan.md`, `design.md`, `grounding/index.md` | `docs/` sections behind the constraints the design touches, code |
| test planner, pass 1 | `plan.md`, `design.md`, `grounding/index.md` | `docs/` sections, code and existing tests |
| test planner, delta pass | the round ledger, `testing.md` | the design sections the ledger names, the requirements they cite |
| test planner, slice mode | `plan.md`, `design.md`, `testing.md` | the installed skills' indexes of references |
| plan-reviewer | every plan file | code, to check a claim |
| implementation-orchestrator | `plan.md`'s Plan files index, `plan.py slices` | a slice file, to answer an implementer |
| implementer | its read set (`plan.py slice`), its slice file | other plan files and docs, code |
| implementation-plan-reviewer | `plan.md`, `testing.md`, `slices/` | `design.md` |
| implementation-standards-reviewer | the standards sources it is given | the diff, file by file |

No agent reads another feature's plan whole: grep it, and read the section that answers the question. The shipped code and its tests are the specification.

## The human's review

After specify, the human reviews `plan.md`. After the architect or the planner, `plan.md`'s Plan files index leads to `design.md` (its Open questions and risks first), `testing.md` and `slices/`. `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/plan.py cat plans/<NNN-slug>` prints the whole plan as one document.
