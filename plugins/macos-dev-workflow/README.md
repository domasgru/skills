# macos-dev-workflow

The development workflow for macOS and iOS apps. It is the Apple platform skill set plus a dependency on [`dev-workflow`](../dev-workflow/README.md), so installing it installs the core workflow too.

```
claude plugin install macos-dev-workflow --marketplace domasgru/skills
```

## Skills

Vendored with the `skills` CLI into `.claude/skills/`, never edited by hand:

- `axiom-apple-docs`, `axiom-data`, `axiom-graphics`, `axiom-macos`, `axiom-swiftui` from [CharlesWiltgen/axiom](https://github.com/CharlesWiltgen/axiom)
- `swift-concurrency` from [avdlee/swift-concurrency-agent-skill](https://github.com/avdlee/swift-concurrency-agent-skill)
- `swift-testing-pro` from [twostraws/Swift-Testing-Agent-Skill](https://github.com/twostraws/Swift-Testing-Agent-Skill)

`skills/` holds our own macOS skills, when we write them.

No workflow file names these skills. The core's agents hold the Skill tool and invoke whichever skills are relevant, by description. Nothing is preloaded.

## Updating the vendored skills

```
cd plugins/macos-dev-workflow
npx skills@latest update -p -y
grep -rl 'disable-model-invocation: true' .claude/skills
```

The `grep` must print nothing: a skill with that flag is hidden from the agents. Record the update in `CHANGELOG.md` and keep `THIRD-PARTY.md` current.

The upstream `swift-testing-pro` directory carries its own `.claude-plugin/plugin.json` and a second copy under `skills/swift-testing-pro/`. Claude Code does not scan inside a skill directory, so neither loads; they stay so that updates apply cleanly.
