# Seam and test review

The `tdd` skill (`${CLAUDE_PLUGIN_ROOT}/.claude/skills/tdd/`) tests only at seams agreed up front, and it bans implementation-coupled and tautological tests. In this workflow no human reviews the testing decisions, so this review stands in for that agreement:

- The planner, or the `architect-test-planner`, runs it on its own seams and test scenarios, and records the result in the plan.
- The `plan-reviewer` checks it again.
- The implementer treats the reviewed seams as the agreed ones.
- The implementation reviewer applies it to the tests as written.

## Seams

For every seam the plan names:

1. **It is a public boundary.** A seam is an interface a real caller uses: the model's public API, a port, a module's public functions, the app's UI or CLI. It is never:
   - an internal type reached only through test-only access (`@testable`, friend access, exported-for-tests);
   - the instructions the code hands a framework or library (animation keyframes, query builders, render trees, ORM calls), read back and decoded by the test.
2. **It survives a refactor.** Name one plausible refactor that keeps the behaviour and changes the internals: another algorithm, another framework API, an inlined or split helper, a cache added or removed. Every test at the seam must stay green through it. If one would break, move the seam up until it would not.
3. **Its reach is stated.** One line on what the seam catches and one on what it misses. What it misses goes to another seam or to Verified without a test.

## Test scenarios

For every test scenario:

1. **It proves a requirement's behaviour.** The Given/When/Then is something a requirement asks for, observable at the seam. A decision the plan made to deliver a requirement is not a requirement. A cache, a prefetch, a warm-up, a dedupe, a tie-break rule or a streak rule is tested only through the behaviour it serves, never on its own.
2. **Calls on a fake are the behaviour, not a mechanism.** Asserting that a faked port was called is right only when that call is what the requirement names at a system boundary, such as "the app is brought to front" or "the setting is saved". It is wrong when the call is a means to an end: prepare, preload, cache, retry or notify-internally. The red flag is a test that goes red when the mechanism is removed while the user sees no difference, or that stays green when the user sees one.
3. **The expected value is independent.** It comes from the requirements, a worked example or a fixture. It never comes from re-running the algorithm, from the code's own constants, or from values tuned to whatever the code currently does.
4. **It is not a restatement.** A test that would pass for any implementation, or only for this one, proves nothing. The test must fail when the behaviour breaks and pass when the internals change.

## Recording it

The plan's Testing Decisions → Strategy ends with a **Seam review** paragraph:

- every seam, with the refactor it survives and what it catches and misses;
- every test scenario that was moved, merged or dropped by this review, and why.

When a requirement can only be observed below a public boundary, say so there. Then prove it under Verified without a test, or name the narrowest public boundary that can observe it. Never test past an interface silently.
