#!/usr/bin/env bash
# Usage: worktree.sh start <slug> | resume <NNN-slug> | prune
# Feature worktrees live under .claude/worktrees/<NNN-slug> on feature/<NNN-slug>.
# start and resume print the worktree path on stdout; everything else goes to stderr.
set -euo pipefail
root=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
dir="$root/.claude/worktrees"
usage="usage: worktree.sh start <slug> | resume <NNN-slug> | prune"

base() {
  if git -C "$root" fetch -q origin main 2>/dev/null; then echo origin/main
  else echo "warning: fetch failed, branching from local main" >&2; echo main; fi
}

prune() {
  git -C "$root" worktree prune
  for wt in "$dir"/*/; do
    [ -d "$wt" ] || continue
    case "$PWD/" in "$wt"*) continue;; esac          # never remove the worktree we run from
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

case "${1:-}" in
  start|resume) [ $# -eq 2 ] || { echo "$usage" >&2; exit 2; }; "$@" ;;
  prune) prune ;;
  *) echo "$usage" >&2; exit 2 ;;
esac
