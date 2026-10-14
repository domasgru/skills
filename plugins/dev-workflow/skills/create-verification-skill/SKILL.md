---
name: create-verification-skill
description: "Generate a project-local verification skill that drives your app the way a user does — any language, framework, or platform. Use for /create-verification-skill, \"make a control skill for this repo\", or when a project has no scripted way to prove UI/CLI/service behavior."
disable-model-invocation: true
---

# Create a verification skill

Every serious project needs a scripted way to drive the real app and prove behavior: launch it, exercise a feature the way a user would, and capture evidence. This skill generates that as a project-local skill (`.claude/skills/verify-<app>/`) tailored to the repo. You write the generator's output for the next agent, not for a human: it will be read cold, mid-task, by an agent that has never seen the app.

The generated skill is not a regression suite. It does what automated tests can't do, or can't do yet:
- reproducing a bug the way the user met it, and exploring before you know what to assert;
- driving paths that cross processes or apps that no test drives end to end;
- judging how something looks;
- one-off proof that a change does what it says.

Behaviour that must keep holding belongs in the repo's tests, at the lowest layer that can prove it. A recipe that repeats what a test already proves costs upkeep and adds no confidence.

## 1. Interview the repo, not the user

Answer these from the codebase and only ask the user what you cannot observe:

- **Surface:** what does a user actually touch? A web UI, a CLI/TUI, a desktop app, an API, a mobile app, a library? A repo can have several; pick the primary one and note the rest.
- **Run:** how does the app start locally? Prefer the repo's own documented dev command (package scripts, Makefile, README quickstart). Note ports, env vars, seed data, auth.
- **Drive:** how can an agent interact with it programmatically? Existing harnesses first — Playwright/Cypress specs, expect scripts, PTY helpers, curl-able endpoints, a debug port. Only then pick a generic recipe: browser/CDP for web and Electron, a tmux/PTY harness for CLI/TUI, plain HTTP for services.
- **Observe:** what evidence can be captured? Screenshots, terminal transcripts, response bodies, logs, exit codes, DB state.
- **Isolate:** can two instances run side by side (ports, data dirs, profiles)? If not, say so in the generated skill: refusing to double-drive a shared instance beats corrupting the user's session. Then list the state that escapes isolation even with a scratch data dir: OS-level preferences the app reads by its bundle or package id, keychains, permissions, registrations with other apps, and input devices shared by every process. The generated skill points each at scratch state or saves and restores it. It names what it can do neither for.
- **Test:** what already proves behavior, at each layer: unit and scenario tests, UI-test targets (XCUITest, Playwright, Espresso), contract tests, the CI gate. Read the repo's testing plans and known-issue lists for gaps they name. Note which user-facing behaviors a test already proves, and which paths no test drives end to end. The feature map is built from the second list.

When the primary surface is a macOS app, or the repo has a browser extension, read [`references/macos.md`](references/macos.md) before generating. Each pitfall in it cost a real run a wrong step or a risk to the user's data.

If the checkout doesn't build or start as-is, fix that first (or report it precisely) before generating; a skill written against a broken base teaches wrong steps. When an irrelevant missing asset blocks startup (a static dir the API never serves, a sample config), the generated skill may create it, clearly marked as verification scaffolding, and remove it in cleanup.

## 2. Generate the skill

Write `.claude/skills/verify-<app>/SKILL.md` with YAML frontmatter (`name: verify-<app>` and a `description` that names the app, the surface, and when to reach for it, saying it is not a regression suite — without frontmatter the skill never registers) and these sections, each grounded in what the interview actually found (no placeholders left):

- **When to use it, and when to write a test instead:** the four jobs above, and where the repo's tests live, layer by layer. When an exploration finds behavior that must keep holding, the next step is a test at the lowest layer that proves it, not a recipe.
- **Launch:** the exact command that starts the app for verification, and how to tell it's ready (a log line, a prompt). Launch must reach a usable state from an empty data dir, including any migrations and seed data. Ready means usable, not just that a process answers. A database health check can pass while its init scripts are still running. Include teardown. For a short-lived CLI or TUI there is no server to keep alive: launch means build the binary (or install deps) once, then start each drive in its own isolated PTY or tmux session. Launch refuses a build that isn't of the checkout as it is now. Stamp each build with the commit and a hash of the uncommitted changes under the directories it is built from, one stamp per separately built area, and compare. Driving stale code proves nothing.
- **Doctor:** one read-only check that answers "is this instance worth driving?" — process up, right version/build, port owned by us, auth valid, isolation in effect (the instance reads the scratch data dir, not the real one, checked from the outside), and the same for every side process the skill starts. An agent runs this first whenever anything looks off.
- **Drive:** the harness recipe with real selectors/commands from this repo, not examples. Prefer stable handles (ARIA labels, data attributes, prompt strings, route paths) over coordinates and tab order. Give the handles a section of their own, so an exploring agent finds them without a recipe. Leave out any command that can act on the wrong target when focus isn't where it seems, such as free typing into whatever is focused. Give the safe alternative instead: set a field's value through the accessibility API or the DOM, then check the result before confirming.
- **Evidence:** what to capture for a proof and where it goes. State the proof standards: exercise the real user path, not internal setters or test-only endpoints; capture the action and the resulting state, not just the final screen; verify side effects (files written, rows inserted, messages sent) alongside what's visible; mocks only where a production boundary already isolates the external system. When the safe path is a dry-run or test mode, verify what it actually skips by observing (files, network, git refs) rather than trusting its name: some dry-runs still touch the network or open a browser.
- **Cleanup:** how to tear down instances the run created. Never kill by process name; kill what you started. A recorded pid can belong to another process by the time cleanup runs, so check it still runs what the run started before signalling it. Resolve a scratch path to its real path, and check it is inside the scratch root, before any recursive delete. Put back every piece of escaped state the launch changed, from a process that can reach it (a sandboxed test runner can't), and check it is back after a run. Cleanup removes instances and scratch state, never the evidence: proof artifacts survive the teardown, all logs included, in a location the skill names.
- **Helpers:** any script the skill ships is executable and its invocation is shown in the skill body. A helper the reader has to reverse-engineer is not a helper. Start background processes with exec and redirected stdin and stdout, so the recorded pid is the process itself and no pipe is held open.

## 3. Seed the feature map

Create `.claude/skills/verify-<app>/features/README.md` plus one file per user-facing feature that no automated test drives end to end (from the interview's **Test** list). A feature a test already proves gets no file. A path a UI test could drive on its own gets no file either: name it to the user as a test gap, with the layer that should prove it and any testing plan that already lists it. Don't write tests the user didn't ask for. If every feature is covered, the map is just the README with its baseline and conventions; that is a good outcome. Follow the shape in [`references/feature-map-example/`](references/feature-map-example/), with a README index and one file per feature. Each file answers, from the user's point of view: what the feature is, how to reach it, how to drive it with the harness, and what observable end state proves it works. The four H2s are `Sub-features`, `How to get to it (user POV)`, `Driving it with <harness>`, and `Gotchas`. If the seed data lacks a precondition that a journey needs, the journey reports a failure and the reason goes in that feature's `Gotchas`. Never weaken the journey to make it pass. The map is the repo's maintained verification source; a proof that drives one convenient entry point is incomplete when the map lists others. Write no dated status lines ("driven on <date>", "proven") into the map: they are stale from the next commit. A sub-feature with no working recipe says so.

## 4. Prove the generated skill before handing it over

Run its own instructions end to end once: launch, doctor, drive every step of every recipe you wrote, capture evidence, clean up. Each step left unrun is an unverified claim. In practice they turn out wrong: what a dialog does with a folder, which handle the toolbar exposes, whether a second process lets its stdout go. After cleanup, confirm the evidence still exists at the named location — a cleanup that eats the proof fails this step. Fix what fails, and run the generated cleanup after every failed iteration too, so broken attempts don't strand processes and ports. A generated skill that was never executed is a draft, not a deliverable. Then have a fresh-context subagent review the helpers for safety:
- every kill, and whose pid it can reach;
- every recursive delete, and the path guard before it;
- every write outside the scratch root, and whether it is put back;
- every command that sends input, and what it lands on if focus is elsewhere.

Prove each fix with a failing case: a recorded pid now owned by an unrelated process, or a path that escapes the scratch root. Then re-run the skill. If you proved it in a stand-in for the real target (a container in place of a fresh VM, a local stack in place of a remote one), list every setup step the stand-in did that the target will not. Those steps stay unverified until a run on the real target covers them.

## 5. Offer the maintenance loop

A feature map rots the moment the app changes. Tell the user how to keep it honest: after user-facing changes, drive every mapped feature live with the generated skill, fix doc drift and harness gaps in the skill's own directory, and report app behavior that is actually broken as a product regression instead of papering over it in the map. When a test comes to cover a mapped path, retire its recipe. Suggest a cadence only if they ask.
