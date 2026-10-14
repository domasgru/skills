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

prune() {
  git -C "$root" worktree prune
  for wt in "$dir"/*/; do
    [ -d "$wt" ] || continue
    case "$(pwd -P)/" in "$wt"*) continue;; esac    # never remove the worktree we run from
    branch=$(git -C "$wt" branch --show-current)
    [ -n "$branch" ] || continue
    [ "$(gh pr view "$branch" --json state --jq .state 2>/dev/null)" = MERGED ] || continue
    git -C "$root" worktree remove "$wt" && git -C "$root" branch -D "$branch" >/dev/null \
      && echo "pruned $branch" >&2 || echo "skipped $branch (dirty or in use)" >&2
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
