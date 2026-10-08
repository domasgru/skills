# Plan: `domasgru/skills`

A marketplace of Claude Code development-workflow plugins, one per topic, plus standalone skills installable with the `skills` CLI.

## Vision

1. **Install one plugin, think about nothing else.** A topic workflow such as macOS is one `claude plugin install`. Everything it needs arrives with it.
2. **The core works on its own.** `dev-workflow` is the full development workflow with no platform or stack information in it, bundling only generic skills. A user can run it bare, or install any skills they find relevant themselves.
3. **One plugin per topic, only relevant data installed.** `macos-dev-workflow` today, `nextjs-dev-workflow` or `windows-dev-workflow` later. A topic plugin bundles the skills for its platform or stack. Installing macOS must not install web.
4. **Agents discover skills, nobody routes them.** No workflow skill or agent names a platform skill. Every bundled skill allows model invocation, agents hold the Skill tool, and they pick skills by description, from our plugins, the project, and the user's own installs alike.
5. **Standalone skills** in the same repo, installable with `npx skills add domasgru/skills`. None exist yet.
6. **Live local development.** Edit or add a skill or agent and every new session in every local project has it. No publish, commit, or reinstall.

## Design

**Core plus topic plugins.** The workflow itself is topic-agnostic: eight workflow skills, seventeen agents, three shared reference files and three vendored generic skills. It lives once, in the `dev-workflow` plugin. A topic plugin such as `macos-dev-workflow` is a bundle of that topic's skills with `dependencies: ["dev-workflow@domasgru"]`, so installing it auto-installs the core. Both live in the same marketplace, so the cross-marketplace dependency rules below do not apply to this edge.

**Skills are discovered, not routed.** The twelve agents that design, implement or review code carry `Skill` in their `tools` list. Tested on 2.1.294: a plugin subagent with the Skill tool is offered every model-invocable skill from every loaded plugin, and a skill with `disable-model-invocation: true` is withheld from it. So an implementer running where `macos-dev-workflow` is enabled sees `macos-dev-workflow:axiom-macos` beside the core's `dev-workflow:tdd`, and the same implementer in a Next.js project sees whatever that project installed. The workflow files never name a platform skill. Any number of topic plugins can be enabled at once.

**Generic in the core, platform in the topic plugin.** The core vendors `codebase-design`, `tdd` and `research`, which name no platform. Their examples are TypeScript-flavoured, which is acceptable for a methodology skill. The design agents still preload `codebase-design` and the implementer still preloads `tdd`, since those are always relevant and travel in the same plugin. The macOS plugin vendors `axiom-apple-docs`, `axiom-data`, `axiom-graphics`, `axiom-macos`, `axiom-swiftui`, `swift-concurrency` and `swift-testing-pro`, and preloads nothing anywhere. `writing-for-agents` is for authoring skills, not for running the workflow, so it is not bundled.

**Third-party skills are vendored with the `skills` CLI.** All four upstream packs are MIT. Inside a plugin directory, `npx skills add <repo> --skill <name> -a claude-code --copy -y` copies the skill to `<plugin>/.claude/skills/<name>/` and records it in `<plugin>/skills-lock.json`; `npx skills update -p -y` refreshes them. Tested on 2.1.294: a `plugin.json` with `"skills": ["./skills", "./.claude/skills"]` loads both directories, and the ten real skill copies pass `--strict`. The copies are taken fresh from upstream, so edits made to the project's local copies are dropped by design: the `disable-model-invocation: true` on three axiom skills in `filesapp-apple` was added locally in `e4eeaa9`, and upstream carries no such line. Attribution lives in `THIRD-PARTY.md` with each pack's upstream and license text.

**Worktrees travel with the core.** Every write a workflow skill makes lands in `.claude/worktrees/<NNN-slug>` of the consuming project, on `feature/<NNN-slug>`. The `worktree` skill and its `worktree.sh` own the lifecycle. The script is run through `bash`, so the executable bit never matters after an install.

**`how` and `why` ship in the core.** They are the read-only stages of the workflow, `why` reads the `plans/<NNN-slug>/` and `development-logs.md` conventions the core defines, and the architect runs both in its grounding phase. Each needs two agents, so neither can be a standalone skill.

**Flat `agents/`, references beside it.** Tested on 2.1.294: a markdown file in `agents/` without frontmatter is registered as an agent under its filename and fails `claude plugin validate --strict`, and `claude plugin details` did not list agents placed in a subdirectory of `agents/`. So the two reference files move to `references/`, the five architect agents move up to `agents/`, and agents reach the references through `${CLAUDE_PLUGIN_ROOT}/references/<file>`. The names were already unique, so nothing else changes.

**Standalone skills stay plain.** `skills/<name>/SKILL.md` at the repo root, no plugin wrapper. The `skills` CLI also discovers skills bundled inside plugins, so a skill we write for a topic plugin is installable on its own without duplicating it. Workflow skills carry `metadata.internal: true`, which hides them from the CLI because they do not work without the agents. Claude Code ignores the field and strict validation accepts it.

## Repository layout

```
skills/                                    repo domasgru/skills
├── .claude-plugin/
│   └── marketplace.json                   name "domasgru", one entry per plugins/* directory
├── plugins/
│   ├── dev-workflow/                      the core, topic-agnostic
│   │   ├── .claude-plugin/plugin.json     skills: ["./skills", "./.claude/skills"]
│   │   ├── README.md                      the workflow document, moved from filesapp-apple
│   │   ├── skills/                        ours; metadata.internal: true on all eight
│   │   │   ├── do/SKILL.md
│   │   │   ├── specify/SKILL.md
│   │   │   ├── plan/SKILL.md
│   │   │   ├── architect/SKILL.md
│   │   │   ├── implement/SKILL.md
│   │   │   ├── worktree/SKILL.md
│   │   │   ├── worktree/worktree.sh
│   │   │   ├── how/SKILL.md
│   │   │   └── why/SKILL.md
│   │   ├── .claude/skills/                vendored by the skills CLI, never edited by hand
│   │   │   ├── codebase-design/
│   │   │   ├── tdd/
│   │   │   └── research/
│   │   ├── skills-lock.json               written by the skills CLI
│   │   ├── agents/                        flat; twelve carry the Skill tool
│   │   │   ├── prd-reviewer.md
│   │   │   ├── planner.md
│   │   │   ├── plan-reviewer.md
│   │   │   ├── architect.md
│   │   │   ├── architect-runner-fable.md
│   │   │   ├── architect-runner-opus.md
│   │   │   ├── architect-judge.md
│   │   │   ├── architect-test-planner.md
│   │   │   ├── implementation-orchestrator.md
│   │   │   ├── implementer.md
│   │   │   ├── implementation-reviewer.md
│   │   │   ├── implementation-plan-reviewer.md
│   │   │   ├── implementation-standards-reviewer.md
│   │   │   ├── how-explorer.md
│   │   │   ├── how-explainer.md
│   │   │   ├── why-investigator.md
│   │   │   └── why-synthesizer.md
│   │   └── references/                    not a component directory, so never scanned
│   │       ├── plan-slices.md
│   │       ├── design-reference.md
│   │       └── development-logs-template.md
│   └── macos-dev-workflow/                the macOS topic plugin
│       ├── .claude-plugin/plugin.json     dependencies: ["dev-workflow@domasgru"], same skills paths
│       ├── README.md
│       ├── skills/.gitkeep                our own macOS skills, when we write them
│       ├── .claude/skills/                vendored: axiom-apple-docs, axiom-data, axiom-graphics,
│       │                                  axiom-macos, axiom-swiftui, swift-concurrency, swift-testing-pro
│       └── skills-lock.json
├── skills/                                standalone skills, npx skills add domasgru/skills
│   └── <name>/SKILL.md                    categories allowed: skills/<category>/<name>/
├── THIRD-PARTY.md                         upstream, commit and MIT text for each vendored pack
├── .github/workflows/validate.yml
├── CHANGELOG.md
├── README.md
├── PLAN.md                                deleted once the migration is done
└── .gitignore
```

Future topics follow the same shape: `plugins/nextjs-dev-workflow/`, `plugins/windows-dev-workflow/`, each a `.claude/skills/` of vendored packs, a `skills/` of our own, and the dependency on the core.

What the user types: `/do`, `/specify`, `/plan`, `/architect`, `/implement`, `/worktree prune`, `/how`, `/why`, `/research`. Tested on 2.1.294: a plugin skill answers to its bare name when no other skill uses that name. `/dev-workflow:do` is the unambiguous form and the one documentation uses. Agents appear as `dev-workflow:<name>` and resolve by bare name when dispatched. Skills appear to agents as `dev-workflow:tdd` and `macos-dev-workflow:axiom-macos`.

## Manifests

`.claude-plugin/marketplace.json`:

```json
{
  "name": "domasgru",
  "owner": { "name": "Dominykas Grubys", "url": "https://github.com/domasgru" },
  "description": "Development workflow plugins and skills by Dominykas Grubys.",
  "plugins": [
    {
      "name": "dev-workflow",
      "source": "./plugins/dev-workflow",
      "description": "Topic-agnostic specify, plan, architect, implement loop run by reviewed subagents in feature worktrees, plus how and why for reading a codebase. Works on its own; topic plugins add their skills.",
      "category": "engineering"
    },
    {
      "name": "macos-dev-workflow",
      "source": "./plugins/macos-dev-workflow",
      "description": "The development workflow for macOS and iOS apps: the core plus the Apple platform skills the agents draw on.",
      "category": "engineering"
    }
  ]
}
```

`plugins/dev-workflow/.claude-plugin/plugin.json`:

```json
{
  "name": "dev-workflow",
  "version": "0.1.0",
  "description": "Specify, plan or architect, and implement features with reviewed subagents in feature worktrees: /do, /specify, /plan, /architect, /implement, /worktree, plus /how, /why and /research. Topic-agnostic; add a topic plugin or your own skills.",
  "author": { "name": "Dominykas Grubys", "url": "https://github.com/domasgru" },
  "repository": "https://github.com/domasgru/skills",
  "license": "MIT",
  "keywords": ["workflow", "planning", "specification", "architecture", "subagents", "worktrees"],
  "skills": ["./skills", "./.claude/skills"]
}
```

`plugins/macos-dev-workflow/.claude-plugin/plugin.json`:

```json
{
  "name": "macos-dev-workflow",
  "version": "0.1.0",
  "description": "Development workflow for macOS and iOS apps. Installs the core workflow and adds the Apple platform skills: axiom, swift-concurrency, swift-testing-pro.",
  "author": { "name": "Dominykas Grubys", "url": "https://github.com/domasgru" },
  "repository": "https://github.com/domasgru/skills",
  "license": "MIT",
  "keywords": ["workflow", "macos", "ios", "swift", "swiftui"],
  "dependencies": ["dev-workflow@domasgru"],
  "skills": ["./skills", "./.claude/skills"]
}
```

`agents/` is a default scan location, so it needs no path field. `skills` is declared because the vendored copies live outside the default directory; every declared path must exist, hence `skills/.gitkeep` in the macOS plugin. `references/` is not a scan location, which is the point. Every manifest path must stay inside its plugin root, and symlinks that leave the plugin root are rejected except between plugins of one marketplace, which is why the core is shared through `dependencies` rather than a symlink and why the CLI runs with `--copy`. `claude plugin validate` at the marketplace root checks only `marketplace.json`; each plugin is validated separately.

## How files refer to each other inside the plugin

The source repo refers to everything by `.claude/...` path. The plugin has three forms instead:

- **Agents by name.** "Dispatch the `<name>` subagent from this plugin." Tested: a bare name resolves to the namespaced plugin agent.
- **Files by `${CLAUDE_PLUGIN_ROOT}`.** Claude Code substitutes the placeholder when a skill is invoked and when an agent is loaded, both tested on 2.1.294. It does not substitute inside a file another skill Reads. The workflow skills carry `disable-model-invocation: true`, so `do` reaches `specify`, `plan`, `architect` and `implement` by Reading their files, and those four reach the `worktree` skill the same way. `do` is therefore the only skill that reads a file which itself names a plugin path, and it carries one sentence that resolves it: "The skill files below name their plugin root with a placeholder; it resolves to `${CLAUDE_PLUGIN_ROOT}`." After substitution that sentence states the real path.
- **Files beside the one being read, in words.** The `worktree` skill says "`worktree.sh`, beside this file", and is run as `bash <that path> start <slug>`. No placeholder, so it reads the same whether invoked or Read.

The architect agent reads the `how` and `why` skill files through `${CLAUDE_PLUGIN_ROOT}`, which is substituted because it is an agent, and those two files name only agents. The implementation reviewer names the `tdd` standards files as `${CLAUDE_PLUGIN_ROOT}/.claude/skills/tdd/tests.md` and `mocking.md`.

## Skills: which agents hold the Skill tool, and what is preloaded

| Agent | `tools` gains `Skill` | `skills` preload |
|---|---|---|
| planner, architect, architect-runner-fable, architect-runner-opus, architect-test-planner, implementation-orchestrator | yes | `[codebase-design]` |
| implementer | yes | `[tdd]` |
| plan-reviewer, architect-judge, implementation-reviewer, implementation-plan-reviewer, implementation-standards-reviewer | yes | none |
| prd-reviewer | no, it reads product documents only | none |
| how-explorer, how-explainer, why-investigator, why-synthesizer | no, they read code and history | none |

A preload names a skill bundled in the same plugin, so it is always present. Everything platform-specific reaches an agent through the Skill tool's own list, by description. The agents are told once, uniformly: "The Skill tool lists the skills installed for this project. Invoke the ones relevant to your task before starting." Nothing else in the core mentions a skill name other than the three it bundles.

The macOS plugin has no agents and no profile. It is the Apple skill set plus the dependency on the core. A persona is unnecessary: the agents read `docs/architecture.md` and the codebase, which say what the project is.

## Vendoring third-party skills

The `skills` CLI is the only tool; no script of ours.

- **Add:** `cd plugins/<name>` and `npx skills@latest add <source> --skill <skill> -a claude-code --copy -y`. The CLI copies into `.claude/skills/<skill>/` and records the upstream hash in the lockfile. Tested with the CLI current on 2026-10-08: run inside `plugins/dev-workflow/` of a git repo, the copy and the lockfile landed in that directory, not at the repo root.
- **Update:** `cd plugins/<name>` and `npx skills@latest update -p -y`.
- **Check:** after either, `grep -rl 'disable-model-invocation: true' plugins/*/.claude/skills` prints nothing. Upstream copies of all ten skills carry no such line, so any hit means a pack started shipping one. Only then decide how to handle it, by hand or with a script.
- **Attribute:** keep `THIRD-PARTY.md` current: pack, upstream URL, the skills taken, the license. All four are MIT, each with a `LICENSE` file upstream; the MIT text is reproduced once per pack.

Vendored copies are never edited by hand, since an update would overwrite the edit. The core's three and the macOS plugin's seven are the initial set. The consuming project drops its own copies, so a skill is never loaded twice.

## Local development loop

One line in `~/.claude/settings.json`:

```json
{ "env": { "CLAUDE_CODE_PLUGIN_DIRS": "~/code/skills/plugins" } }
```

Every plugin folder under `plugins/` then loads in place, as `<name>@inline`, in every session of every project. New skills, new agents, and new plugin folders appear at the next session start. Inside a running session `/reload-plugins` picks them up, `/reload-plugins --force` if it declines over prompt cache cost. Nothing is copied, so the version string is irrelevant to the dev copy. Tested on 2.1.294 with the variable in the shell environment: `claude plugin details` and `claude -p` both saw the probe plugins as `@inline`.

Rules:

- Never marketplace-install these plugins on the dev machine. The inline copies would load twice.
- On the dev machine every topic plugin loads at once. That is harmless: a topic plugin is only skills, and an irrelevant skill costs its description. Narrow the env var to a colon-separated list when the always-on cost matters.
- The value is user settings or shell environment only; project and local settings cannot set it.
- Standalone skills under `skills/` are not plugins, so they are not loaded by this mechanism. Test one with `npx skills add ~/code/skills --skill <name>` in a scratch project, or symlink it into that project's `.claude/skills/`.

Alternative not taken: `claude plugin init <name>` scaffolds a plugin at `~/.claude/skills/<name>/` that loads as `<name>@skills-dir` with no install step. The repo lives in `~/code/skills`, so the env var is the fit.

Before every commit: `claude plugin validate . --strict` for the marketplace and each plugin. `claude plugin details dev-workflow` and `/skill-doctor` show inventory and context cost.

## De-coupling edits to the skills and agents

1. **Agent references by name.** Replace every `` `.claude/agents/<name>.md` `` with "the `<name>` subagent from this plugin". Skills: `specify` (prd-reviewer), `plan` (planner), `architect` (architect), `implement` (implementation-orchestrator), `how` (how-explorer, how-explainer), `why` (why-investigator, why-synthesizer). Agents: `planner` (plan-reviewer), `implementation-orchestrator` (implementer, implementation-reviewer), `implementation-reviewer` (implementation-standards-reviewer twice, implementation-plan-reviewer), `architect`, whose "defined beside it in `.claude/agents/architect/`" becomes the four subagent names.
2. **Skill references by plugin path.** In `do`, replace every `` `.claude/skills/<name>/SKILL.md` `` reference (five skills, six occurrences) with `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md` and add the placeholder sentence above. In `specify`, `plan`, `architect` and `implement`, replace the `worktree` skill reference the same way. In the `architect` agent, replace the `how` and `why` skill references the same way.
3. **Reference files.** `planner` step 4 and `architect-test-planner` step 2 point at `${CLAUDE_PLUGIN_ROOT}/references/plan-slices.md`. `architect` and both runners point at `${CLAUDE_PLUGIN_ROOT}/references/design-reference.md`. Move both files out of `agents/`.
4. **Worktree script beside its skill.** In `worktree/SKILL.md`, replace the four `.claude/skills/worktree/worktree.sh` paths with "`worktree.sh`, beside this file, run as `bash <path> ...`". `.claude/worktrees/<NNN-slug>` stays: that is the consuming project's path, not the plugin's. The script itself needs no change; it derives the repo root from git.
5. **Skill tool and generic preloads.** Add `Skill` to `tools` on the twelve agents in the table. Replace `skills: [codebase-design, axiom-data]` (planner, architect, both runners) with `skills: [codebase-design]`; keep `skills: [codebase-design]` on architect-test-planner and implementation-orchestrator; replace `skills: [axiom-macos, axiom-data, tdd]` on implementer with `skills: [tdd]`. Add the uniform Skill-tool sentence to the twelve bodies. `implementer` keeps "Use the `tdd` skill where relevant, at the seams the plan names."
6. **Generic persona.** In `planner`, `architect`, both runners and `architect-test-planner`, replace "senior macOS and iOS engineer and software architect" with "senior software engineer and architect". In `design-reference.md`, "The type sketch sits here as Swift code blocks" becomes "as code blocks in the project's language".
7. **Development logs template in one place.** Move the template from the Development logs section of `docs/development-workflow.md` to `references/development-logs-template.md`. `specify` step 6, `planner` step 6 and `architect` Phase D step 3 create the file from `${CLAUDE_PLUGIN_ROOT}/references/development-logs-template.md`. The README keeps the prose and points at the template file.
8. **Standards sources.** In `implementation-reviewer` step 3, the `.claude/skills/tdd/tests.md` and `mocking.md` references become `${CLAUDE_PLUGIN_ROOT}/.claude/skills/tdd/tests.md` and `mocking.md`, after "anything in the repo that documents how code should be written". The smell-baseline sentence refers to the `implementation-standards-reviewer` subagent by name.
9. **Hide workflow skills from the `skills` CLI.** Add `metadata: { internal: true }` to the eight workflow skills.
10. **README edits.** In the moved workflow document, "`.claude/skills/worktree/SKILL.md` owns the lifecycle" becomes "the `worktree` skill owns the lifecycle", and the self-reference under Development logs points at the template file.

Nothing to delete in the source repo: `planner copy.md` is gone, and the `no-comments` skill and `comment-sicko` agent were removed in `70fe691`.

## Contract with a consuming project

- `docs/product-overview.md`, `docs/domain-model.md`, `docs/architecture.md`
- `plans/<NNN-slug>/plan.md` and `plans/<NNN-slug>/development-logs.md`
- Branches `feature/<NNN-slug>` off `main`, worktrees under `.claude/worktrees/<NNN-slug>`, ignored by `.gitignore` (Claude Code also writes the pattern to `.git/info/exclude`)
- `origin` on GitHub and an authenticated `gh` CLI: the worktree script asks `gh` whether a PR is merged, and Finish opens the PR with `gh pr create`
- `dev-workflow` enabled, alone or through one or more topic plugins
- No project copy of a skill a plugin already bundles. Skills the plugins do not bundle are installed per project with the `skills` CLI and pinned by the project's `skills-lock.json`, and the agents see them the same way
- Optional: `AGENTS.md` or `CLAUDE.md` with build and test commands and anything project-specific; a `research/` directory for the `research` skill's notes, which the architect reads and `why` never does

## Installing on other machines and for teammates

One command per setup. `--marketplace` adds the marketplace in user settings first when it is missing (CLI help, 2.1.294):

```
claude plugin install macos-dev-workflow --marketplace domasgru/skills   # core + Apple skills
claude plugin install dev-workflow --marketplace domasgru/skills         # core only
```

The macOS command pulls `dev-workflow` as a dependency. On a stack without a topic plugin, install the core and add skills with `npx skills add` if wanted. Use `--scope project` in a team repo, which writes `enabledPlugins` to `.claude/settings.json`; each collaborator still runs the install once. A private repo needs git credentials on the machine. Auto-update is off by default for third-party marketplaces; turn it on in `/plugin`, Marketplaces, Enable auto-update.

Standalone skills and the skills we write for topic plugins:

```
npx skills@latest add domasgru/skills            # interactive pick, or --all
npx skills@latest add domasgru/skills --skill <name>
```

The CLI lists root `skills/*` and the skills inside each plugin declared in `marketplace.json`, minus anything marked internal. Listing on skills.sh starts automatically once the repo is public.

## Release process

Each plugin versions independently.

1. Bump `version` in the plugin's `plugin.json` and add a `CHANGELOG.md` entry under that plugin's heading. A vendored pack moving upstream is a changelog line too.
2. `claude plugin validate . --strict` at the root and in each plugin.
3. `claude plugin tag plugins/<name> --dry-run`, then without `--dry-run --push`. It creates the `<name>--v<version>` tag after checking the manifests agree and the tree is clean.

Marketplace installs move when the version changes. The inline dev copy always loads the working tree. Dependencies may later pin a range resolved from these tags; not needed at 0.1.0.

## CI

`.github/workflows/validate.yml` on push and pull request: install Claude Code with the native installer, then run `claude plugin validate . --strict` at the root and in each `plugins/*` directory. Confirm during implementation that validation runs without an API login. `claude plugin eval` stays optional until a skill earns an eval case.

## Migration steps

The source of truth is `main` of `filesapp-apple` at `6f09d04`, checked out clean at `~/code/files-apple-2`. The `feature/001-walking-skeleton` checkout at `~/code/filesapp-apple` carries an older copy of the workflow files and picks up the change when it takes `main`; nothing there to stash.

1. Create the layout above. Copy the eight skills into `plugins/dev-workflow/skills/`, the seventeen agents flat into `plugins/dev-workflow/agents/`, `plan-slices.md` and `design-reference.md` into `references/`, and the development-logs template into `references/development-logs-template.md`. Move `docs/development-workflow.md` to `plugins/dev-workflow/README.md`.
2. Apply the de-coupling edits.
3. Vendor: inside `plugins/dev-workflow/`, `npx skills add mattpocock/skills --skill codebase-design,tdd,research -a claude-code --copy -y`. Inside `plugins/macos-dev-workflow/`, the same for `CharlesWiltgen/axiom` (the five axiom skills), `twostraws/Swift-Testing-Agent-Skill` and `avdlee/swift-concurrency-agent-skill`. Confirm with `grep -rl 'disable-model-invocation: true' plugins/*/.claude/skills` that no copy carries the flag, and write `THIRD-PARTY.md`.
4. Write the three manifests, the repo `README.md`, both plugin READMEs, `CHANGELOG.md`, and the CI workflow. Create an empty root `skills/` and `plugins/macos-dev-workflow/skills/` with a `.gitkeep` each.
5. `claude plugin validate . --strict` at the root and in both plugins until clean.
6. Add the `CLAUDE_CODE_PLUGIN_DIRS` line to `~/.claude/settings.json`. Confirm `claude plugin details dev-workflow` shows Skills (11) and Agents (17) from `@inline`, and `claude plugin details macos-dev-workflow` shows Skills (7).
7. In `filesapp-apple`, on a branch off `main`: remove `.claude/skills/*` except `writing-for-agents`, remove all of `.claude/agents/`, trim `skills-lock.json` to `writing-for-agents`, replace `docs/development-workflow.md` with a pointer to the plugin README. `AGENTS.md` is empty and stays. Open the PR.
8. Commit both repos. Tag `dev-workflow--v0.1.0` and `macos-dev-workflow--v0.1.0`.

## Verification

- `claude plugin validate . --strict` exits 0 at the root and in both plugins.
- `claude plugin details dev-workflow` shows Skills (11) and Agents (17), none of them `plan-slices` or `design-reference`. `claude plugin details macos-dev-workflow` shows Skills (7).
- Headless, from an empty directory with both plugins loaded: `claude -p "Dispatch the implementer subagent with the prompt 'List the exact names of every skill your Skill tool offers, one per line.'"` lists `dev-workflow:tdd`, `dev-workflow:codebase-design`, `dev-workflow:research` and the seven `macos-dev-workflow:*` skills, and none of the eight workflow skills. With `CLAUDE_CODE_PLUGIN_DIRS` narrowed to the core alone, the same prompt lists only the three.
- Headless, from an empty directory: `claude -p "/do"` and `claude -p "/dev-workflow:do"` both load the skill and ask what to do.
- End to end, per the repo rule to reproduce as the user would: in `filesapp-apple`, run `/do` on a small real technical change that touches persistence. Confirm the worktree appears under `.claude/worktrees/`, the subagent panel shows `dev-workflow:planner` on fable, `dev-workflow:plan-reviewer` on opus, and `dev-workflow:implementer` on sonnet, that the implementer invokes `macos-dev-workflow:axiom-data` unprompted, and that a PR is opened from the worktree. Then run `/how` on a subsystem and confirm `dev-workflow:how-explainer` runs.
- Add a throwaway `plugins/dev-workflow/skills/zz-probe/SKILL.md`, start a new session in another project, confirm `/dev-workflow:zz-probe` exists, then delete it.
- Add a throwaway `skills/zz-standalone/SKILL.md`, run `npx skills@latest add ~/code/skills -l`, confirm it is listed, that the eight workflow skills are not, and note whether the vendored skills are. If they are, decide then whether to mark the copies internal, knowing `npx skills update` would undo a hand edit.
- On a second machine or user with no marketplace added, run only `claude plugin install macos-dev-workflow --marketplace domasgru/skills`, and confirm the marketplace is added, `dev-workflow` is auto-installed as a dependency, both plugins' `.claude/skills` copies load, and `bash .../skills/worktree/worktree.sh` runs from the installed copy.

## Open decisions

Defaults chosen so work can proceed. Change any before the first tag.

- Plugin names `dev-workflow` and `macos-dev-workflow`. The typed namespace is always `dev-workflow`.
- Marketplace name `domasgru`.
- License MIT, added when the repo goes public.
- The twelve agents that hold the Skill tool, per the table. The five that do not can gain it later at the cost of the skill list in their context.
- `codebase-design` and `tdd` stay preloaded on the agents that always need them. Dropping the preloads would make the core rely on discovery alone.
- Vendored skills live in `<plugin>/.claude/skills/` because that is where the `skills` CLI writes and where `npx skills update` looks. Copying them into `skills/` would break updates.
- `how` and `why` live in `dev-workflow`. Splitting them into their own plugin later is a move of two skills and four agents plus a dependency line.
- The worktree script lives beside its skill and is run through `bash`. A plugin's top-level `bin/` is put on the Bash tool's PATH and would allow a bare `worktree start <slug>`, but plugins with a `bin/` are not installable in claude.ai or Cowork, so not now.

Decided since the first draft: no `workflow-profile` and no per-role skill lists. Third-party packs are vendored into the plugins rather than declared as plugin dependencies, because cross-marketplace dependencies are off by default and three of the four packs are not plugin marketplaces.

## Verified facts this plan relies on

Tested on Claude Code 2.1.294 on this machine, 2026-10-08, with probe plugins built from the real skills and agents:

- A plugin subagent with `tools: Skill, Read` was offered `dev-workflow:<skill>` and `macos-dev-workflow:<skill>` from two inline plugins, plus the built-in skills, and was not offered a skill carrying `disable-model-invocation: true`.
- `plugin.json` with `"skills": ["./skills", "./.claude/skills"]` passed `--strict` and `claude plugin details` listed skills from both directories.
- The ten real third-party skill copies (`codebase-design`, `tdd`, `research`, five `axiom-*`, `swift-concurrency`, `swift-testing-pro`) passed `--strict` inside a plugin and all appeared in the inventory. The project's copies of `axiom-apple-docs`, `axiom-graphics` and `axiom-swiftui` carry `disable-model-invocation: true`; upstream `main` of all five axiom skills does not (GitHub API, 2026-10-08), and the line entered `filesapp-apple` in commit `e4eeaa9`, the initial import.
- `npx skills@latest add mattpocock/skills --skill research -a claude-code --copy -y`, run inside `plugins/dev-workflow/` of a git repo, wrote `plugins/dev-workflow/.claude/skills/research/` as a real directory and `plugins/dev-workflow/skills-lock.json`, nothing at the repo root. The CLI has `add`, `update`, `remove`, `list`, `experimental_install` (restore from lockfile), `--copy`, `-a <agents>`, `-s <skills>`, `-l`, and no option for a custom target directory.
- `mattpocock/skills`, `CharlesWiltgen/axiom`, `twostraws/Swift-Testing-Agent-Skill` and `avdlee/swift-concurrency-agent-skill` are MIT, each with a `LICENSE` file (GitHub API).
- `claude plugin validate --strict` fails on a markdown file in `agents/` that has no frontmatter, and `claude plugin details` lists such a file as an agent under its filename (`plan-slices` appeared in the inventory).
- `claude plugin details` listed 13 agents with the five architect agents under `agents/architect/`, and all 17 once `agents/` was flat. A headless session then listed all 17 as `dev-workflow:<name>`.
- `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` were substituted in an invoked skill body; `${CLAUDE_PLUGIN_ROOT}` was substituted in a dispatched agent's body.
- `/dev-workflow:zz-probe` and bare `/zz-probe` both invoked the probe skill.
- `metadata: { internal: true }` on a skill, `worktree.sh` beside a `SKILL.md`, and a `references/` directory all pass `--strict`; `references/` is not scanned.
- `CLAUDE_CODE_PLUGIN_DIRS=<folder>` loaded the folder's child plugins as `<name>@inline` for `claude plugin details` and for `claude -p`.
- `claude plugin validate <marketplace root>` passed while a plugin inside it failed, so plugins are validated one by one.
- The `EnterWorktree` tool takes `path` for an existing worktree listed in `git worktree list`, which is how the `worktree` skill enters the worktree its script created.
- `claude plugin tag` has `--dry-run`, `--push`, `--remote` and `-m`. `claude plugin init <name>` scaffolds `~/.claude/skills/<name>/`, loaded as `<name>@skills-dir`.

Tested on Claude Code 2.1.283 on this machine:

- An agent's `skills:` preload resolved a skill from another plugin and from the project's `.claude/skills/` by bare name, and a missing name produced no error.
- The binary accepts `CLAUDE_CODE_PLUGIN_DIRS` from the settings `env` block. Re-confirmed by migration step 6.
- A symlink at `~/.claude/skills/<name>` to an external plugin directory is adopted as `<name>@skills-dir`. Kept as a fallback; the env var is the chosen mechanism.
- `claude plugin validate` accepts a marketplace root with `plugins[].source` relative paths.
- The `skills` CLI v1.7.0 hides `metadata.internal` skills while listing root `skills/*` and skills inside plugins declared in `marketplace.json`.

From the current docs:

- Subagents invoke project, user and plugin skills through the Skill tool; an agent's `skills:` preload skips a missing or disabled skill with a debug-log warning and cannot preload a skill with `disable-model-invocation: true`.
- Plugin `agents/` is documented as scanned recursively, with `agents/review/security.md` registering as `my-plugin:review:security`. `claude plugin details` on 2.1.294 did not show that; a flat `agents/` avoids the question and the nested name form.
- Plugin agents support `model` (`sonnet`, `opus`, `haiku`, `fable`, a full ID, or `inherit`), `effort`, `color`, `background`, `tools` and `skills`. They ignore `permissionMode`, `hooks`, `mcpServers` and `initialPrompt`.
- `dependencies` in `plugin.json` accepts `name@marketplace`, and a bare name resolves against the plugin's own marketplace. Enabling a plugin auto-installs its dependencies from the same marketplace. A dependency from another marketplace is not installed unless the user already has it enabled at the same scope or the root marketplace lists the target in `allowCrossMarketplaceDependenciesOn`. Ranges resolve from `<name>--v<version>` tags.
- `CLAUDE_CODE_PLUGIN_DIRS` exists since 2.1.280, takes `:`-separated absolute or `~` paths, loads each the way `--plugin-dir` does, and cannot be set from project or local settings.
- Every component path must resolve inside the plugin root and must exist; a symlink leading outside the plugin is rejected, other than links between plugins within one marketplace.
- Skill frontmatter `metadata` is a free-form map Claude Code does not act on; `disable-model-invocation` and `user-invocable` are documented keys.
- `${CLAUDE_PLUGIN_ROOT}` is substituted anywhere in skill, command and agent markdown bodies; `${CLAUDE_SKILL_DIR}` only in skills.
- The docs do not say whether a marketplace install preserves a script's executable bit, which is why the script is run through `bash`.
- `${CLAUDE_PLUGIN_ROOT}/bin` is added to the Bash tool's PATH, and plugins with a top-level `bin/` are not installable in claude.ai or Cowork.
