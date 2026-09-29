# Plan: `dev-workflow` Claude Code plugin

Extract the feature development workflow from `filesapp-apple` into this repo as a Claude Code plugin, with a live local development loop and a clean install path for other machines.

## Goals

1. **Live local development.** Edit a skill or agent file, or add a new skill directory, and it is available in every new Claude Code session in every local project. No publish, commit, reinstall, or flag.
2. **Current best practice.** Follow the Claude Code plugin docs as of 2026-09-29 and the patterns from `mattpocock/skills`.
3. **Full subagent fidelity.** Keep the eight subagents as native agent files with `model`, `effort`, `tools`, and `color` intact.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Distribution format | Claude Code plugin, one plugin at the repo root | Subagents are Claude Code native. Plugins register skills and agents together. |
| Repo | `domasgru/skills`, private for now | User's choice. Marketplace install from a private repo works with git credentials. |
| Plugin name | `dev-workflow` | Namespace becomes `/dev-workflow:do`. Rename is free until the first tagged release. |
| Marketplace name | `domasgru` | Install id reads `dev-workflow@domasgru`, same pattern as `mattpocock-skills@mattpocock`. |
| Local dev loop | Symlink `~/.claude/skills/dev-workflow` to this checkout | Verified: Claude Code adopts any folder in `~/.claude/skills/` with a plugin manifest as `<name>@skills-dir`, loads it in place, every session, every project. Symlinks work. |
| Other machines | `claude plugin marketplace add domasgru/skills` then `claude plugin install dev-workflow@domasgru --scope user` | Standard marketplace flow. Never combine with the symlink on the same machine, or every component loads twice. |
| Skill count | 4 skills, 8 agents, unchanged | Same shape as today. Agents move verbatim except for the de-coupling edits below. |
| Git history | Start clean | Seven commits of history in the source repo, not worth a filter-repo. |
| `skills` CLI compatibility | Not a goal | The skills would not work without the agents. Can be added later since the CLI already reads plugin manifests. |

## Repository layout

```
skills/                          repo root = plugin root
├── .claude-plugin/
│   ├── plugin.json              name, version, description, author, repository, license, keywords
│   └── marketplace.json         name: domasgru, one plugin entry with source "./"
├── skills/
│   ├── do/SKILL.md
│   ├── specify/SKILL.md
│   ├── plan/SKILL.md
│   └── implement/SKILL.md
├── agents/
│   ├── prd-reviewer.md
│   ├── planner.md
│   ├── plan-reviewer.md
│   ├── implementation-orchestrator.md
│   ├── implementer.md
│   ├── implementation-reviewer.md
│   ├── implementation-plan-reviewer.md
│   └── implementation-standards-reviewer.md
├── docs/
│   └── development-workflow.md  the workflow document, moved from filesapp-apple
├── .github/workflows/validate.yml
├── CHANGELOG.md
├── README.md
├── PLAN.md                      this file, deleted once the migration is done
└── .gitignore
```

`skills/` and `agents/` are the default scan locations, so `plugin.json` does not need `skills` or `agents` path fields. Every path in a manifest must stay inside the plugin root.

`plugin.json`:

```json
{
  "name": "dev-workflow",
  "version": "0.1.0",
  "description": "Spec, plan, and implement features with reviewed subagents: /do, /specify, /plan, /implement.",
  "author": { "name": "Dominykas Grubys", "url": "https://github.com/domasgru" },
  "repository": "https://github.com/domasgru/skills",
  "license": "MIT",
  "keywords": ["workflow", "planning", "specification", "tdd", "subagents"]
}
```

`marketplace.json`:

```json
{
  "name": "domasgru",
  "owner": { "name": "Dominykas Grubys", "url": "https://github.com/domasgru" },
  "description": "Dominykas Grubys's Claude Code plugins.",
  "plugins": [
    {
      "name": "dev-workflow",
      "source": "./",
      "description": "Spec, plan, and implement features with reviewed subagents.",
      "category": "engineering"
    }
  ]
}
```

## Local development loop

One-time setup on this machine:

```
ln -s ~/code/skills ~/.claude/skills/dev-workflow
claude plugin details dev-workflow      # expect Source: dev-workflow@skills-dir, 4 skills, 8 agents
```

Daily loop:

- Edit any `SKILL.md` or `agents/*.md`, or add a new `skills/<name>/SKILL.md`. Every new session in any project sees it.
- Inside a running session, `/reload-plugins` picks up edits, new skill directories, and new agent files. Use `/reload-plugins --force` if it refuses because of prompt cache cost.
- Validate before committing: `claude plugin validate . --strict`.
- Inspect cost and inventory: `claude plugin details dev-workflow`, `/skill-doctor` in a session.

Alternative with the same behaviour, if the symlink is ever unwanted: add `"env": { "CLAUDE_CODE_PLUGIN_DIRS": "~/code/skills" }` to `~/.claude/settings.json`. The plugin then loads as `dev-workflow@inline`. This is user settings only, not project settings.

## De-coupling edits to the skills and agents

The current files assume `filesapp-apple`. Each edit below makes them work in any project that follows the contract in the next section.

1. **Agent references by name, not path.** Replace every `` `.claude/agents/<name>.md` `` with "the `<name>` subagent from this plugin". Verified: Claude resolves a bare agent name to the namespaced `dev-workflow:<name>` when dispatching.
2. **Skill references by plugin path.** In `do`, replace `` `.claude/skills/specify/SKILL.md` `` with `${CLAUDE_PLUGIN_ROOT}/skills/specify/SKILL.md`, same for `plan` and `implement`. Reading the file keeps the `disable-model-invocation` guard on those skills intact.
3. **Remove project-specific preloads.** Drop `skills: [codebase-design, axiom-data]` from `planner` and `implementation-orchestrator`, and `skills: [axiom-macos, axiom-data, tdd]` from `implementer`. Replace with one body line: "Before starting, invoke every skill the project's `CLAUDE.md` or `AGENTS.md` names for this role." Subagents have the Skill tool.
4. **Generic persona.** In `planner`, replace "senior macOS and iOS engineer" with "senior software engineer and architect". The project's `CLAUDE.md` carries the domain.
5. **Development logs without a shared template.** Each stage appends its own `## Specify`, `## Plan`, or `## Implement` section to `plans/<NNN-slug>/development-logs.md`, creating the file with a `# Development logs: <title>` heading if missing. Remove every reference to the template in `docs/development-workflow.md`.
6. **Standards sources by convention.** In `implementation-reviewer`, replace the `.claude/skills/tdd/tests.md` reference with "the project's documented standards: `docs/architecture.md`, `docs/domain-model.md`, and any files the project's `CLAUDE.md` or `AGENTS.md` names as standards".
7. **Description hygiene.** User-invoked skills keep `disable-model-invocation: true` and a human one-liner description. Agent descriptions keep the "Dispatched by ..." sentence so Claude does not auto-delegate to them.
8. **Delete `planner copy.md`** in the source repo. It is a byte-identical untracked duplicate.

## Contract with a consuming project

Documented in `README.md`. The workflow expects:

- `docs/product-overview.md`, `docs/domain-model.md`, `docs/architecture.md`
- `plans/<NNN-slug>/plan.md` and `plans/<NNN-slug>/development-logs.md`
- Branches named `feature/<NNN-slug>` off `main`
- A `CLAUDE.md` or `AGENTS.md` that states the domain persona and lists skills per role, for example: "Implementers use `axiom-macos`, `axiom-data`, `tdd`. Planners use `codebase-design`, `axiom-data`."

## Installing on other machines and for teammates

```
claude plugin marketplace add domasgru/skills
claude plugin install dev-workflow@domasgru --scope user
```

- A private repo needs git credentials on that machine. SSH or the `gh` credential helper both work.
- Auto-update is off by default for third-party marketplaces. Turn it on in `/plugin`, Marketplaces, Enable auto-update. Claude Code then refreshes within ten minutes of the first message of a session.
- For a team repo, `--scope project` writes `enabledPlugins` to `.claude/settings.json`. Each collaborator still runs the install once.

## Release process

1. Bump `version` in `.claude-plugin/plugin.json` and add a `CHANGELOG.md` entry.
2. `claude plugin validate . --strict`
3. `claude plugin tag .` creates the `dev-workflow--v<version>` tag after checking the manifests agree. Push with tags.

The symlinked dev copy ignores the version string and always loads the working tree. Marketplace installs move only when the version changes.

## CI

`.github/workflows/validate.yml`: on push and pull request, install Claude Code with the native installer and run `claude plugin validate . --strict`. Confirm during implementation that validation runs without an API login in CI. `claude plugin eval` stays optional until a skill is worth an eval case.

## Migration steps

1. In `filesapp-apple`, commit or stash the current uncommitted edits to `planner.md` and the docs. Delete `planner copy.md`.
2. Create the layout above. Copy the four skills into `skills/` and the eight agents into `agents/`. Move `docs/development-workflow.md` into `docs/`.
3. Apply the de-coupling edits.
4. Write `README.md`: what the workflow is, the four commands, the project contract, install, local development, release.
5. Add the manifests, `CHANGELOG.md`, and the CI workflow.
6. `claude plugin validate . --strict` until clean.
7. `ln -s ~/code/skills ~/.claude/skills/dev-workflow` and confirm `claude plugin details dev-workflow` lists 4 skills and 8 agents from `@skills-dir`.
8. In `filesapp-apple`: remove `.claude/skills/{do,specify,plan,implement}` and `.claude/agents/`, keep the third-party skills and `skills-lock.json`, replace `docs/development-workflow.md` with a pointer to this repo, and add the persona and per-role skill list to `AGENTS.md`.
9. Commit both repos. Tag `dev-workflow--v0.1.0`.

## Verification

- `claude plugin validate . --strict` exits 0.
- `claude plugin details dev-workflow` shows Source `dev-workflow@skills-dir`, Skills (4), Agents (8).
- Headless smoke test from any directory: `claude -p "/dev-workflow:plan"` with no plan present reports that it needs a plan pointer instead of erroring on a missing agent.
- End-to-end, per the repo rule to reproduce as the user would: in `filesapp-apple`, run `/dev-workflow:do` on a small real technical change. Confirm the subagent panel shows `dev-workflow:planner` on fable, `dev-workflow:plan-reviewer` on opus, and the implementer on sonnet, and that a PR is opened.
- Add a new throwaway `skills/zz-probe/SKILL.md`, start a new session in another project, confirm `/dev-workflow:zz-probe` exists, then delete it.

## Open decisions

Defaults chosen so work can proceed. Change any of them before the first tag.

- Plugin name `dev-workflow` versus something shorter like `wf`.
- Marketplace name `domasgru`.
- License MIT, added when the repo goes public.
- Whether to parameterise the docs paths through `userConfig` later. Not now.

## Verified facts this plan relies on

- Docs: "Your personal skills directory is `~/.claude/skills/`. Claude Code loads any folder there that contains a `.claude-plugin/plugin.json` as a plugin in every session, with no flag and no install step."
- Docs: "`--plugin-dir` and skills-directory plugins: the directory loads in place and is never copied."
- Tested on Claude Code 2.1.283: a symlink at `~/.claude/skills/<name>` to an external plugin directory is adopted as `<name>@skills-dir` with its skills and agents.
- Tested: `CLAUDE_CODE_PLUGIN_DIRS=<path>` loads the plugin as `<name>@inline`. The binary accepts it from the settings `env` block.
- Tested: in a session, the skill is invokable as `/<plugin>:<skill>`, the agent is listed as `<plugin>:<agent>`, and "dispatch the `<agent>` subagent" resolves to the namespaced agent.
- Docs: `/reload-plugins` re-scans `skills/` and `agents/`, so new directories and files appear without a restart.
- Docs: plugin `agents` and `skills` manifest fields are optional. Default locations are `agents/` and `skills/` under the plugin root.
- Docs: `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` are substituted in skill and agent markdown.
- CLI help: `claude plugin validate <path> --strict`, `claude plugin tag [path]`, `claude plugin details <name>`, `claude plugin install --scope user|project|local`.
- Docs: auto-update is off by default for third-party marketplaces and toggled per marketplace.
