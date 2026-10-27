#!/usr/bin/env bash
# Usage: worktree.sh start <slug> | resume <NNN-slug> | discard <NNN-slug> | prune | sync-main
# Feature worktrees live under .claude/worktrees/<NNN-slug> on feature/<NNN-slug>.
# start and resume print the worktree path on stdout; everything else goes to stderr.
set -euo pipefail
root=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
dir="$root/.claude/worktrees"
usage="usage: worktree.sh start <slug> | resume <NNN-slug> | discard <NNN-slug> | prune | sync-main"

# Fetch origin/main and fast-forward local main to it. Leaves local main as it was when
# that is not possible (diverged, or conflicting changes in the checkout holding main).
# Returns 1 only when the fetch fails.
sync_main() {
  git -C "$root" fetch -q origin main 2>/dev/null || return 1
  if [ "$(git -C "$root" branch --show-current)" = main ]; then git -C "$root" merge -q --ff-only origin/main
  else git -C "$root" fetch -q . origin/main:main; fi >/dev/null 2>&1 || true
}

base() {
  if sync_main; then echo origin/main
  else echo "warning: fetch failed, branching from local main" >&2; echo main; fi
}

# Removes every worktree whose PR is finished: merged, with its branch, or closed unmerged, keeping
# the branch since its commits are on no other branch. A worktree with uncommitted or untracked
# changes stays. Never fails, so start always goes on.
prune() {
  git -C "$root" worktree prune || true
  for wt in "$dir"/*/; do
    [ -d "$wt" ] || continue
    case "$(pwd -P)/" in "$wt"*) continue;; esac    # never remove the worktree we run from
    wt=${wt%/}
    branch=$(git -C "$wt" branch --show-current 2>/dev/null || true)
    [ -n "$branch" ] || continue
    state=$(gh pr view "$branch" --json state --jq .state 2>/dev/null || true)
    case "$state" in MERGED|CLOSED) ;; *) continue;; esac
    physical=$(cd "$wt" && pwd -P) || continue
    if ! error=$(git -C "$root" worktree remove "$wt" 2>&1); then skipped "$wt" "$branch" "$error"; continue; fi
    if [ "$state" = MERGED ]; then
      git -C "$root" branch -D "$branch" >/dev/null 2>&1 || echo "warning: could not delete $branch" >&2
      echo "pruned $branch (merged)" >&2
    else echo "pruned $branch (closed; branch kept)" >&2; fi
    remove_derived_data "$physical"
  done
}

# Says why a finished worktree stayed: its uncommitted changes, else git's error.
skipped() {
  local changes
  changes=$(git -C "$1" status --porcelain 2>/dev/null || true)
  if [ -n "$changes" ]; then
    echo "skipped $2: $(printf '%s\n' "$changes" | wc -l | tr -d ' ') uncommitted change(s)" >&2
    printf '%s\n' "$changes" | head -5 | sed 's/^/    /' >&2
  else echo "skipped $2: $3" >&2; fi
}

# Deletes the Xcode DerivedData folders of projects and packages inside the removed worktree $1,
# 1-2 GB each. Folders without a WorkspacePath belong to Xcode itself and stay.
remove_derived_data() {
  local data="$HOME/Library/Developer/Xcode/DerivedData" folder workspace
  [ -d "$data" ] || return 0
  for folder in "$data"/*/; do
    workspace=$(plutil -extract WorkspacePath raw -o - "$folder/info.plist" 2>/dev/null) || continue
    case "$workspace" in
      "$1"|"$1"/*) rm -rf "$folder" && echo "  removed DerivedData $(basename "$folder")" >&2 \
                     || echo "warning: could not remove $folder" >&2 ;;
    esac
  done
}

start() {
  b=$(base); prune
  n=$( { git -C "$root" branch -a --format='%(refname:short)'; git -C "$root" ls-tree --name-only origin/main plans/; } \
       | grep -oE '(feature|plans)/[0-9]+' | grep -oE '[0-9]+$' | sort -n | tail -1 || true )
  slug=$(printf '%03d' $(( 10#${n:-0} + 1 )))-$1
  git -C "$root" worktree add -q --no-track -b "feature/$slug" "$dir/$slug" "$b" >&2
  echo "$dir/$slug"
}

resume() {
  if [ ! -d "$dir/$1" ]; then
    git -C "$root" fetch -q origin "feature/$1" 2>/dev/null || true
    git -C "$root" worktree add -q "$dir/$1" "feature/$1" >&2
  fi
  echo "$dir/$1"
}

# Removes a worktree that produced nothing, with its branch: only when its tree is clean and its
# branch holds no commit that main or origin/main lacks. Refuses anything else, and the worktree
# it runs from.
discard() {
  wt="$dir/$1"; branch="feature/$1"
  [ -d "$wt" ] || { echo "no worktree $1" >&2; exit 1; }
  case "$(pwd -P)/" in "$wt"/*) echo "refusing: run discard from outside $1" >&2; exit 1;; esac
  [ -z "$(git -C "$wt" status --porcelain)" ] || { echo "refusing: $1 has uncommitted changes" >&2; exit 1; }
  ahead=$(git -C "$root" rev-list --count "$branch" --not main $(git -C "$root" rev-parse -q --verify origin/main || true))
  [ "$ahead" = 0 ] || { echo "refusing: $branch has $ahead commit(s) not on main" >&2; exit 1; }
  git -C "$root" worktree remove "$wt" && git -C "$root" branch -D "$branch" >/dev/null
  echo "discarded $branch" >&2
}

case "${1:-}" in
  start|resume|discard) [ $# -eq 2 ] || { echo "$usage" >&2; exit 2; }; "$@" ;;
  prune) prune ;;
  sync-main) sync_main || true ;;
  *) echo "$usage" >&2; exit 2 ;;
esac
