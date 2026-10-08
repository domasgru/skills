# skills

Claude Code development-workflow plugins, one per topic, and standalone skills, by Dominykas Grubys.

| Plugin | What it is |
|---|---|
| [`dev-workflow`](plugins/dev-workflow/README.md) | The topic-agnostic specify, plan or architect, implement loop run by reviewed subagents in feature worktrees, plus `how` and `why` for reading a codebase. Bundles the generic `codebase-design`, `tdd` and `research` skills. Works on its own; its agents pick up whatever skills are installed. |
| [`macos-dev-workflow`](plugins/macos-dev-workflow/README.md) | The workflow for macOS and iOS apps. Installs the core as a dependency and adds the Apple platform skills. |

`skills/` holds standalone skills, installable with the `skills` CLI. None exist yet.

## Install

```
claude plugin install macos-dev-workflow --marketplace domasgru/skills   # core + Apple skills
claude plugin install dev-workflow --marketplace domasgru/skills         # core only
```

`--marketplace` adds the `domasgru` marketplace when it is missing. Add `--scope project` in a team repo. On a stack without a topic plugin, install the core and add skills with `npx skills add` if wanted.

Then type `/do`, `/specify`, `/plan`, `/architect`, `/implement`, `/worktree prune`, `/how`, `/why` or `/research`. `/dev-workflow:do` is the unambiguous form. The [`dev-workflow` README](plugins/dev-workflow/README.md) describes the workflow.

The workflow expects of a project:

- `docs/product-overview.md`, `docs/domain-model.md`, `docs/architecture.md`.
- `plans/<NNN-slug>/plan.md` and `development-logs.md`, written by the workflow.
- Branches `feature/<NNN-slug>` off `main`, in worktrees under `.claude/worktrees/<NNN-slug>`, ignored by `.gitignore`.
- `origin` on GitHub and an authenticated `gh` CLI.
- No project copy of a skill a plugin already bundles.
- Optional: `AGENTS.md` or `CLAUDE.md` with build and test commands, and a `research/` directory for the `research` skill's notes.

Standalone skills and the skills inside the plugins:

```
npx skills@latest add domasgru/skills
npx skills@latest add domasgru/skills --skill <name>
```

The workflow skills are marked `metadata.internal` and are not offered, since they need the plugin's agents.

## Layout

```
.claude-plugin/marketplace.json     marketplace "domasgru", one entry per plugin
plugins/<name>/
  .claude-plugin/plugin.json
  skills/                           our skills
  .claude/skills/                   vendored by the skills CLI, never edited by hand
  skills-lock.json                  written by the skills CLI
  agents/                           flat, one file per agent
  references/                       files agents read through ${CLAUDE_PLUGIN_ROOT}
skills/<name>/SKILL.md              standalone skills
THIRD-PARTY.md                      upstream, commit and license of each vendored pack
CHANGELOG.md                        per plugin
```

## Local development

Set `CLAUDE_CODE_PLUGIN_DIRS` to this repo's `plugins/` directory, in the `env` block of `~/.claude/settings.json` or in the shell:

```json
{ "env": { "CLAUDE_CODE_PLUGIN_DIRS": "~/code/skills/plugins" } }
```

Every plugin under `plugins/` then loads in place as `<name>@inline` in every session. Edits appear at the next session start, or after `/reload-plugins`. Never marketplace-install these plugins on the same machine; they would load twice.

Standalone skills are not plugins. Test one with `npx skills add ~/code/skills --skill <name>` in a scratch project.

## Vendoring third-party skills

```
cd plugins/<name>
npx skills@latest add <owner/repo> --skill <skill> -a claude-code --copy -y   # add
npx skills@latest update -p -y                                                # update
grep -rl 'disable-model-invocation: true' .claude/skills                      # must print nothing
```

Keep `THIRD-PARTY.md` and `CHANGELOG.md` current.

## Before every commit

```
claude plugin validate . --strict
for d in plugins/*/; do (cd "$d" && claude plugin validate . --strict); done
```

CI runs the same on every push and pull request. `claude plugin details <name>` shows the inventory and its context cost.

## Release

Bump `version` in the plugin's `plugin.json`, add a `CHANGELOG.md` entry, validate, then `claude plugin tag plugins/<name> --dry-run` and `claude plugin tag plugins/<name> --push`.
