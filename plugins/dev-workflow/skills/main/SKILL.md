---
name: main
description: "Move this session out of any worktree, back to the main checkout on the main branch."
disable-model-invocation: true
metadata:
  internal: true
---

The **main checkout** is the repo's original directory, the one every worktree hangs off. It prints with `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`. This skill moves the session there, on branch `main`. Worktrees stay on disk, untouched.

1. **Leave the worktree.** When `git rev-parse --show-toplevel` already prints the main checkout, go to step 2. Otherwise call `ExitWorktree` with `action: "keep"`. When it reports no active worktree session, the session was launched inside the worktree and has no way out: tell the human to restart Claude Code from the main checkout path, and stop.
2. **Be on `main`.** When `git branch --show-current` prints another branch and `git status --porcelain` is empty, run `git switch main`. When the tree has changes, report the branch and the changes, and stop.

Done when `git rev-parse --show-toplevel` prints the main checkout and `git branch --show-current` prints `main`. Report both.
