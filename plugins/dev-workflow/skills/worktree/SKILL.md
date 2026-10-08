---
name: worktree
description: "Start, resume, finish or prune a feature worktree. Run by hand like this: /worktree prune"
disable-model-invocation: true
metadata:
  internal: true
---

Every write a workflow skill makes lands in a worktree: `.claude/worktrees/<NNN-slug>` on branch `feature/<NNN-slug>`, cut from the latest `main`. Read-only work may run on `main`. `worktree.sh`, beside this file, decides numbering, base commit and paths in one place; run it as `bash <path> ...`, where `<path>` is its absolute path, from any checkout of the repo.

## Start `<slug>`

Skip when the session is already in the worktree for this request (for example `/do` started it before following `/specify`). Otherwise:

1. Run `worktree.sh`, beside this file, as `bash <path> start <slug>`. `<slug>` is two to four lowercase words joined by dashes, derived from the request. The script prunes merged worktrees, then prints the new worktree's path.
2. Call `EnterWorktree` with that path. The path's basename is the `<NNN-slug>`: it names `plans/<NNN-slug>/` and `feature/<NNN-slug>`.

Done when `git branch --show-current` prints `feature/<NNN-slug>`. From here on everything, including every subagent you dispatch, runs in the worktree.

## Resume `<NNN-slug>`

`<NNN-slug>` is the directory in the `plans/<NNN-slug>/plan.md` pointer you were given. Skip when `git branch --show-current` already prints `feature/<NNN-slug>`. Otherwise run `worktree.sh`, beside this file, as `bash <path> resume <NNN-slug>` and call `EnterWorktree` with the path it prints. Done when `git branch --show-current` prints `feature/<NNN-slug>`.

## Finish

1. Commit everything in the worktree.
2. Run `git push -u origin HEAD`.
3. Open the PR with `gh pr create`, its description following the template below.
4. Report the PR link and the worktree path. Stay in the worktree so review fixes land in the same place.

<pr-description-template>
A very concise and simple description of what was implemented.
</pr-description-template>

## Prune

Run `worktree.sh`, beside this file, as `bash <path> prune`. It removes every worktree whose PR is merged, together with its branch, and reports what it pruned and what it skipped. Start runs it too, so merged work disappears without a separate step.

## Rules

- The branch changes only through Start and Resume. When `git branch --show-current` is not the branch you expect, stop and report; `git checkout` and `git switch` stay unused in every checkout.
- Dispatch subagents plainly; they inherit the worktree. The Agent tool's `isolation: "worktree"` would give each one its own copy of the repo, away from this one.
- Every file you write lives in the worktree. The main checkout is the human's.
