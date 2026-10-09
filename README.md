# skills

Claude Code plugins that run a full spec, plan, implement and review workflow with subagents, one plugin per platform.

## Install

```
claude plugin install macos-dev-workflow --marketplace domasgru/skills   # macOS and iOS
claude plugin install dev-workflow --marketplace domasgru/skills         # any stack
```

## Use

```
/do <request>        # whole workflow, you review once
/specify <feature>   # or step by step: /specify, then /plan or /architect, then /implement
/how <question>      # how does X work
/why <question>      # why is X this way
/main                # leave the worktree, back to the main checkout on main
/open                # open this checkout in Xcode or VS Code, at the file under discussion
```

See the [workflow](plugins/dev-workflow/README.md) for details.
