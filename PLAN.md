# Plan: `domasgru/skills`

A marketplace of Claude Code development-workflow plugins, one per topic, plus standalone skills installable with the `skills` CLI.

## Vision

1. **Install one plugin, think about nothing else.** A topic workflow such as macOS is one `claude plugin install`. Everything it needs arrives with it.
2. **One workflow per topic, only relevant data installed.** macOS today, web and Windows later. Each topic can bundle its own skills. Installing macOS must not install web.
3. **Standalone skills** in the same repo, installable with `npx skills add domasgru/skills`. None exist yet.
4. **Live local development.** Edit or add a skill or agent and every new session in every local project has it. No publish, commit, or reinstall.

## Design

**Core plus overlays.** The workflow itself is topic-agnostic: four skills and eight agents. It lives once, in the `dev-workflow` plugin. A topic plugin such as `macos-dev-workflow` is a thin overlay: a `workflow-profile` skill carrying the persona, the skills each role must use, and topic standards, plus any bundled topic skills. The overlay declares `dependencies: ["dev-workflow@domasgru"]`, so installing the overlay auto-installs the core.

**The profile is the seam.** Every core agent preloads `skills: [workflow-profile]`. Claude Code resolves that name to whichever `workflow-profile` is loaded: the enabled topic plugin's, or a project's own `.claude/skills/workflow-profile/`. With no profile the agents run generic. All three cases were tested on Claude Code 2.1.283.

**One topic per project.** A project enables exactly one topic plugin, at project or user scope. Two enabled topics would both supply `workflow-profile`. A project can also pin its own profile locally, which takes precedence over plugins.

**Standalone skills stay plain.** `skills/<name>/SKILL.md` at the repo root, no plugin wrapper. The `skills` CLI also discovers skills bundled inside topic plugins, so a macOS skill is installable on its own without duplicating it. Workflow skills carry `metadata.internal: true`, which hides them from the CLI because they do not work without the agents. Claude Code ignores the field and strict validation accepts it.

## Repository layout

```
skills/                                    repo domasgru/skills
├── .claude-plugin/
│   └── marketplace.json                   name "domasgru", one entry per plugins/* directory
├── plugins/
│   ├── dev-workflow/                      the core, topic-agnostic
│   │   ├── .claude-plugin/plugin.json
│   │   ├── README.md                      the workflow document, moved from filesapp-apple
│   │   ├── skills/
│   │   │   ├── do/SKILL.md                metadata.internal: true on all four
│   │   │   ├── specify/SKILL.md
│   │   │   ├── plan/SKILL.md
│   │   │   └── implement/SKILL.md
│   │   └── agents/                        eight agents, each with skills: [workflow-profile]
│   │       ├── prd-reviewer.md
│   │       ├── planner.md
│   │       ├── plan-reviewer.md
│   │       ├── implementation-orchestrator.md
│   │       ├── implementer.md
│   │       ├── implementation-reviewer.md
│   │       ├── implementation-plan-reviewer.md
│   │       └── implementation-standards-reviewer.md
│   └── macos-dev-workflow/                the macOS overlay
│       ├── .claude-plugin/plugin.json     dependencies: ["dev-workflow@domasgru"]
│       ├── README.md
│       └── skills/
│           ├── workflow-profile/SKILL.md  user-invocable: false, metadata.internal: true
│           └── <macos skill>/SKILL.md     future bundled macOS skills, CLI-installable individually
├── skills/                                standalone skills, npx skills add domasgru/skills
│   └── <name>/SKILL.md                    categories allowed: skills/<category>/<name>/
├── .github/workflows/validate.yml
├── CHANGELOG.md
├── README.md
├── PLAN.md                                deleted once the migration is done
└── .gitignore
```

Future topics follow the same shape: `plugins/web-dev-workflow/`, `plugins/windows-dev-workflow/`. If a topic's bundled skills become useful without the workflow, split them into `plugins/<topic>-skills/` and add it to the overlay's dependencies. Not needed now.

Namespaces the user types: `/dev-workflow:do`, `/dev-workflow:specify`, `/dev-workflow:plan`, `/dev-workflow:implement`, the same in every topic.

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
      "description": "Topic-agnostic spec, plan, implement loop run by reviewed subagents. Installed automatically by topic workflows.",
      "category": "engineering"
    },
    {
      "name": "macos-dev-workflow",
      "source": "./plugins/macos-dev-workflow",
      "description": "The development workflow for macOS and iOS apps: profile, standards, and bundled macOS skills.",
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
  "description": "Spec, plan, and implement features with reviewed subagents: /do, /specify, /plan, /implement. Topic-agnostic; pair it with a topic workflow plugin.",
  "author": { "name": "Dominykas Grubys", "url": "https://github.com/domasgru" },
  "repository": "https://github.com/domasgru/skills",
  "license": "MIT",
  "keywords": ["workflow", "planning", "specification", "subagents"]
}
```

`plugins/macos-dev-workflow/.claude-plugin/plugin.json`:

```json
{
  "name": "macos-dev-workflow",
  "version": "0.1.0",
  "description": "Development workflow for macOS and iOS apps. Installs the core workflow and adds the macOS profile.",
  "author": { "name": "Dominykas Grubys", "url": "https://github.com/domasgru" },
  "repository": "https://github.com/domasgru/skills",
  "license": "MIT",
  "keywords": ["workflow", "macos", "ios", "swift"],
  "dependencies": ["dev-workflow@domasgru"]
}
```

`skills/` and `agents/` are default scan locations, so no path fields are needed. Every manifest path must stay inside its plugin root, and symlinks that leave the plugin root are rejected, which is why the core cannot be shared by symlink and why `dependencies` is the sharing mechanism.

## The profile contract

`workflow-profile` is a short skill. The core agents preload it, so it must stand on its own and stay small. Sections:

- **Persona.** One or two sentences, for example "The project is a macOS or iOS app written in Swift and SwiftUI."
- **Skills per role.** Which skills each agent invokes before starting, by name, for example planner: `codebase-design`, `axiom-data`; implementer: `axiom-macos`, `axiom-data`, `tdd`, `swift-testing-pro`; reviewers: `tdd` for testing standards.
- **Standards.** Files or skills the standards reviewer treats as documented standards, on top of `docs/architecture.md` and `docs/domain-model.md`.
- **Topic rules.** Anything that binds every project of this topic, such as build and test commands being read from the project's `CLAUDE.md`.

Core agents reference the profile in one uniform way: "Your preloaded `workflow-profile` names the skills for your role. Invoke them before starting. If no profile is loaded, proceed with the project's `CLAUDE.md` alone."

Third-party skill packs the macOS profile names, such as axiom, mattpocock-skills, and swift-testing-pro, are sourced per machine. During implementation, test whether `dependencies` on plugins in other marketplaces auto-install. If they do, declare them in the overlay. If not, the overlay README carries a one-time install block.

## Local development loop

One line in `~/.claude/settings.json`:

```json
{ "env": { "CLAUDE_CODE_PLUGIN_DIRS": "~/code/skills/plugins" } }
```

Every plugin folder under `plugins/` then loads in place, as `<name>@inline`, in every session of every project. New skills, new agents, and new plugin folders appear at the next session start. Inside a running session `/reload-plugins` picks them up, `/reload-plugins --force` if it declines over prompt cache cost. Nothing is copied, so the version string is irrelevant to the dev copy.

Rules:

- Never marketplace-install these plugins on the dev machine. The inline copies would load twice.
- When a second topic plugin exists, switch the env var to an explicit colon-separated list of the core plus the one topic in use, so only one `workflow-profile` is loaded. The value is user settings or shell environment only, not project settings.
- Standalone skills under `skills/` are not plugins, so they are not loaded by this mechanism. Test one with `npx skills add ~/code/skills --skill <name>` in a scratch project, or symlink it into that project's `.claude/skills/`.

Before every commit: `claude plugin validate . --strict` for the marketplace and each plugin. `claude plugin details dev-workflow` and `/skill-doctor` show inventory and context cost.

## De-coupling edits to the skills and agents

1. **Agent references by name.** Replace every `` `.claude/agents/<name>.md` `` with "the `<name>` subagent from this plugin". Tested: a bare name resolves to the namespaced plugin agent.
2. **Skill references by plugin path.** In `do`, replace `` `.claude/skills/specify/SKILL.md` `` with `${CLAUDE_PLUGIN_ROOT}/skills/specify/SKILL.md`, same for `plan` and `implement`. Reading the file keeps `disable-model-invocation: true` on those skills.
3. **Preload the profile only.** Replace `skills: [codebase-design, axiom-data]`, `skills: [codebase-design]`, and `skills: [axiom-macos, axiom-data, tdd]` with `skills: [workflow-profile]` on all eight agents, and add the uniform profile sentence to each body.
4. **Generic persona.** In `planner`, replace "senior macOS and iOS engineer" with "senior software engineer and architect". The persona comes from the profile.
5. **Development logs without a shared template.** Each stage appends its own `## Specify`, `## Plan`, or `## Implement` section to `plans/<NNN-slug>/development-logs.md`, creating the file with a `# Development logs: <title>` heading if missing. Remove the template references to `docs/development-workflow.md`.
6. **Standards sources.** In `implementation-reviewer`, replace the `.claude/skills/tdd/tests.md` reference with "the project's `docs/architecture.md` and `docs/domain-model.md`, plus the standards the profile names".
7. **Hide workflow skills from the `skills` CLI.** Add `metadata: { internal: true }` to the four workflow skills and to `workflow-profile`.
8. **Delete `planner copy.md`** in the source repo. It is a byte-identical untracked duplicate.

## Contract with a consuming project

- `docs/product-overview.md`, `docs/domain-model.md`, `docs/architecture.md`
- `plans/<NNN-slug>/plan.md` and `plans/<NNN-slug>/development-logs.md`
- Branches `feature/<NNN-slug>` off `main`
- Exactly one topic plugin enabled, or a project-local `.claude/skills/workflow-profile/SKILL.md`
- Optional: a `CLAUDE.md` with build and test commands and anything project-specific

## Installing on other machines and for teammates

```
claude plugin marketplace add domasgru/skills
claude plugin install macos-dev-workflow@domasgru --scope user
```

The second command pulls `dev-workflow` as a dependency. Use `--scope project` in a team repo, which writes `enabledPlugins` to `.claude/settings.json`; each collaborator still runs the install once. A private repo needs git credentials on the machine. Auto-update is off by default for third-party marketplaces; turn it on in `/plugin`, Marketplaces, Enable auto-update.

Standalone skills and bundled topic skills:

```
npx skills@latest add domasgru/skills            # interactive pick, or --all
npx skills@latest add domasgru/skills --skill <name>
```

The CLI lists root `skills/*` and the skills inside each plugin declared in `marketplace.json`, minus anything marked internal. Listing on skills.sh starts automatically once the repo is public.

## Release process

Each plugin versions independently.

1. Bump `version` in the plugin's `plugin.json` and add a `CHANGELOG.md` entry under that plugin's heading.
2. `claude plugin validate . --strict`
3. `claude plugin tag plugins/<name>` creates the `<name>--v<version>` tag after checking the manifests agree. Push with tags.

Marketplace installs move when the version changes. The inline dev copy always loads the working tree.

## CI

`.github/workflows/validate.yml` on push and pull request: install Claude Code with the native installer, then run `claude plugin validate . --strict` at the root and in each `plugins/*` directory. Confirm during implementation that validation runs without an API login. `claude plugin eval` stays optional until a skill earns an eval case.

## Migration steps

1. In `filesapp-apple`, commit or stash the current uncommitted edits to `planner.md` and the docs. Delete `planner copy.md`.
2. Create the layout above. Copy the four skills into `plugins/dev-workflow/skills/` and the eight agents into `plugins/dev-workflow/agents/`. Move `docs/development-workflow.md` to `plugins/dev-workflow/README.md`.
3. Apply the de-coupling edits.
4. Write `plugins/macos-dev-workflow/skills/workflow-profile/SKILL.md` from what the agents assumed today: macOS and iOS persona, the per-role skill lists, `tdd` as testing standards.
5. Write the three manifests, the repo `README.md`, both plugin READMEs, `CHANGELOG.md`, and the CI workflow. Create an empty `skills/` with a `.gitkeep`.
6. `claude plugin validate . --strict` until clean.
7. Add the `CLAUDE_CODE_PLUGIN_DIRS` line to `~/.claude/settings.json`. Confirm `claude plugin details dev-workflow` and `claude plugin details macos-dev-workflow` list the expected components from `@inline`.
8. In `filesapp-apple`: remove `.claude/skills/{do,specify,plan,implement}` and `.claude/agents/`, keep the third-party skills and `skills-lock.json`, replace `docs/development-workflow.md` with a pointer to the plugin, and drop the workflow description from `AGENTS.md` in favour of that pointer.
9. Commit both repos. Tag `dev-workflow--v0.1.0` and `macos-dev-workflow--v0.1.0`.

## Verification

- `claude plugin validate . --strict` exits 0 at the root and in both plugins.
- `claude plugin details dev-workflow` shows Skills (4) and Agents (8). `claude plugin details macos-dev-workflow` shows Skills (1).
- Headless: from any directory, `claude -p "Dispatch the implementer subagent with the prompt 'Which skills does your profile tell you to invoke?'"` names the macOS skill list.
- End to end, per the repo rule to reproduce as the user would: in `filesapp-apple`, run `/dev-workflow:do` on a small real technical change. Confirm the subagent panel shows `dev-workflow:planner` on fable, `dev-workflow:plan-reviewer` on opus, and the implementer on sonnet, and that a PR is opened.
- Add a throwaway `plugins/dev-workflow/skills/zz-probe/SKILL.md`, start a new session in another project, confirm `/dev-workflow:zz-probe` exists, then delete it.
- Add a throwaway `skills/zz-standalone/SKILL.md`, run `npx skills@latest add ~/code/skills -l`, confirm it is listed and the four workflow skills are not, then delete it.
- In a scratch clone on a second marketplace, `claude plugin install macos-dev-workflow@domasgru` and confirm `dev-workflow` is auto-installed as a dependency.

## Open decisions

Defaults chosen so work can proceed. Change any before the first tag.

- Plugin names `dev-workflow` and `macos-dev-workflow`. The typed namespace is always `dev-workflow`.
- Marketplace name `domasgru`.
- License MIT, added when the repo goes public.
- Whether third-party packs become `dependencies` or a README install block, decided by the cross-marketplace test.

## Verified facts this plan relies on

Tested on Claude Code 2.1.283 on this machine unless marked docs.

- A core plugin agent with `skills: [workflow-profile]` received the profile content from a second plugin, from the project's `.claude/skills/`, and got nothing without error when no profile existed.
- `CLAUDE_CODE_PLUGIN_DIRS=<folder>` loads every child plugin folder in place as `<name>@inline`, and the binary accepts the variable from the settings `env` block.
- A symlink at `~/.claude/skills/<name>` to an external plugin directory is adopted as `<name>@skills-dir`. Kept as a fallback; the env var is the chosen mechanism.
- In a session, plugin skills run as `/<plugin>:<skill>`, agents list as `<plugin>:<agent>`, and "dispatch the `<agent>` subagent" resolves by bare name.
- `metadata: { internal: true }` passes `claude plugin validate --strict`, and the `skills` CLI v1.7.0 hides such skills while listing root `skills/*` and skills inside plugins declared in `marketplace.json`.
- `claude plugin validate` accepts a marketplace root with `plugins[].source` relative paths.
- Docs: `dependencies` in `plugin.json` accepts `name@marketplace`; enabling a plugin auto-installs its dependencies; `claude plugin prune` removes unneeded ones.
- Docs: "`--plugin-dir` and skills-directory plugins: the directory loads in place and is never copied." `/reload-plugins` re-scans `skills/` and `agents/`.
- Docs: every manifest path must resolve inside the plugin root; symlinks leaving the plugin root are rejected.
- Docs: `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` are substituted in skill and agent markdown.
- CLI help: `claude plugin validate <path> --strict`, `claude plugin tag [path]`, `claude plugin details <name>`, `claude plugin install --scope user|project|local`.
