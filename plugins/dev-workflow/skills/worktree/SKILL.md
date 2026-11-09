---
name: worktree
description: "Start, resume, finish, discard, abandon or prune a feature worktree. Run by hand like this: /worktree prune"
disable-model-invocation: true
metadata:
  internal: true
---

Every write a workflow skill makes lands in a worktree: `.claude/worktrees/<NNN-slug>` on branch `feature/<NNN-slug>`, cut from the latest `main`. Read-only work may run on `main`. `worktree.sh`, beside this file, decides numbering, base commit and paths in one place; run it as `bash <path> ...`, where `<path>` is its absolute path, from any checkout of the repo.

## Start `<slug>`

Skip when the session is already in the worktree for this request (for example `/do` started it before following `/specify`). Otherwise:

1. Run `worktree.sh`, beside this file, as `bash <path> start <slug>`. `<slug>` is two to four lowercase words joined by dashes, derived from the request. The script fast-forwards local `main` to `origin/main` when it can, prunes landed worktrees, then prints the new worktree's path.
2. Call `EnterWorktree` with that path. The path's basename is the `<NNN-slug>`: it names `plans/<NNN-slug>/` and `feature/<NNN-slug>`.

Done when `git branch --show-current` prints `feature/<NNN-slug>`. From here on everything, including every subagent you dispatch, runs in the worktree.

## Resume `<NNN-slug>`

`<NNN-slug>` is the directory in the `plans/<NNN-slug>/plan.md` pointer you were given. Skip when `git branch --show-current` already prints `feature/<NNN-slug>`. Otherwise run `worktree.sh`, beside this file, as `bash <path> resume <NNN-slug>` and call `EnterWorktree` with the path it prints. Done when `git branch --show-current` prints `feature/<NNN-slug>`.

## Finish

Takes the worktree's work to `main` as one squashed commit, after a green gate and the human's approval. Resume first when the session is elsewhere.

1. **Commit** everything in the worktree.

2. **Take in main.** Run `git fetch origin main`, then `git merge origin/main`, resolving any conflict so both sides keep their intent. Done when `git merge-base --is-ancestor origin/main HEAD` exits 0 and the tree is clean.

3. **Gate.** Run the repo's full gate on this commit, as its `AGENTS.md` names it: in a repo split into areas, the gate of every area the diff touches, by the repo's own rule where it has one, and of every area when the diff touches none. Where it names none, run the full test suite. A gate that outlasts the Bash timeout runs with `run_in_background`, and you end your turn until its notification resumes you.

   Run no gate in two cases, and say which in the commit message:
   - **Prose only:** every changed file is documentation or other text no gate builds or tests. A comment in a source file is code here, since the gate builds and lints that file.
   - **Nothing to run:** the repo has neither a gate nor tests.

   A red gate is a bug in the branch: write the failure to `plans/<NNN-slug>/.temp/slices/fixes.md`, dispatch one `implementer` subagent from this plugin with that path, commit its work, log it under Implement in `plans/<NNN-slug>/development-logs.md` when that file exists, and return to step 2. The second red gate in a row ends Finish: report it and stop, with the worktree as it is.

   A gate that passes but says something went unproved holds no bug to fix: put what went unproved under **Open**, so the human decides at step 6.

   Done when the gate has passed on `HEAD`, or one of the two cases applies.

4. **Push.** Run `git push -u origin HEAD`, so the human can read the diff on GitHub. On failure, report it and stop.

5. **Share the context.** Run `git rev-parse HEAD`: that full commit is what the human approves. Write the commit message to `plans/<NNN-slug>/.temp/land-message.md`, following the template below. Print it in the session, then print the context below it, leaving out a line the change has no data for. For a planned change, the orchestrator's `plans/<NNN-slug>/.temp/implement-report.md` supplies most of it. The human decides from this alone, so the unflattering parts go in.

   <finish-context-template>
   **Branch:** `feature/<NNN-slug>` at `<full sha>`
   **Requirements:** <how each `R<N>` holds>
   **Main:** <up to date, or the commits taken in and the conflicts resolved>
   **Review:** <findings fixed, and findings declined with why>
   **Verification:** <the outcome, with its evidence path>
   **Open:** <known gaps and anything unproved, or "None">
   **Compare:** <repo URL>/compare/main...feature/<NNN-slug>
   **Worktree:** <path>. `/open` opens it.
   </finish-context-template>

6. **Ask.** Call `AskUserQuestion` with "Merge `feature/<NNN-slug>` at `<short sha>` to `main`?", naming the gate's result, and the options **Merge**, **Request changes** and **Not now**. The answer covers this commit, and its clean merge with a later `main`.
   - **Request changes:** make them in the worktree, then Finish from step 1.
   - **Not now:** report the worktree path and stop. Finishing later starts from step 1.

7. **Land**, on **Merge**. Run `worktree.sh`, beside this file, as `bash <path> land <sha>`, where `<sha>` is the full commit from step 5, the one the human approved. It takes the message from step 5's file, squashes `HEAD` onto `main`, pushes it with the branch, and fast-forwards local `main`. It accepts only the approved commit, or that commit cleanly merged with `main`. On a failure other than exit 4, report it and stop.

   Exit 4 means `main` moved first. Run step 2's merge again:
   - **Conflicts:** their resolution is new work. Return to step 3, with a new commit and a new approval.
   - **Clean:** the approval stands. `git diff --name-only <sha> HEAD` lists what came in. Run step 3's gate only for an area that both this branch's changes and those files touch, by step 3's rule. A repo without areas is one area, and prose touches none. Add what came in without a gate to the message's Gate line. When the gate passes or none is needed, run `land <sha>` again with the same `<sha>`. A red gate goes to step 3's fix, and that new commit needs a new approval.

8. **Clean up**, following Discard below. When `ExitWorktree` reports no active worktree session, skip the script and say so: the next Start prunes the worktree, and new work starts in a new one, since a squashed branch shares no history with `main`. Report the commit on `main`, and `land`'s note when local `main` stayed behind.

<commit-message-template>
<one-line imperative title naming the change>

A very concise and simple description of what was implemented.

Gate: `<command>`: <its final line, verbatim>, or why none ran.

## Merge Danger

**Door:** <one-way or two-way>

<optional: description>

**Blast Radius:** <one-word description>

<optional: potential ramifications of merge>

<the attribution lines your instructions give for commits>
</commit-message-template>

### Merge Danger

Describe whether it's a one-way or two-way door. You can walk back through two-way doors, but not one-way doors. A change that is cheap to roll back is lower risk. Changes that involve destructive actions or hard-to-reverse decisions are one-way doors.

The blast radius is the potential impact or scope of the changes introduced. Consider all possibilities. Examples are layout shift, breakages for consumers, mobile responsiveness, etc.

## Discard `<NNN-slug>`

For a worktree whose work has landed, or ended with nothing to ship, such as a maintenance pass that found nothing to change. Call `ExitWorktree` with `action: "keep"`, then run `worktree.sh`, beside this file, as `bash <path> discard <NNN-slug>`. It removes the worktree, its branch and its Xcode DerivedData only when the tree is clean and the branch has landed or holds no commit that `main` lacks; otherwise it refuses and says why, and the worktree stays for the human. Copy out anything the report must keep, such as evidence under the worktree's build directories, before discarding.

## Abandon `<NNN-slug>`

For a worktree whose work will not land, on the human's word. Call `ExitWorktree` with `action: "keep"`, then run `worktree.sh`, beside this file, as `bash <path> abandon <NNN-slug>`. It removes a clean worktree and its Xcode DerivedData, and keeps the branch with its commits.

## Prune

Run `worktree.sh`, beside this file, as `bash <path> prune`. It removes every worktree whose branch has landed, with its branch, and deletes the worktree's Xcode DerivedData with it. A worktree with uncommitted changes stays, reported with those changes listed. Start runs it too, so a worktree Finish could not leave disappears without a separate step.

## Rules

- `main` moves only through Finish's Land, on the human's approval.
- The branch changes only through Start and Resume. When `git branch --show-current` is not the branch you expect, stop and report; `git checkout` and `git switch` stay unused in every checkout.
- Dispatch subagents plainly; they inherit the worktree. The Agent tool's `isolation: "worktree"` would give each one its own copy of the repo, away from this one.
- Every file you write lives in the worktree. The main checkout is the human's.
