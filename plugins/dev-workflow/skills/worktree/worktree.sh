#!/usr/bin/env bash
# Usage: worktree.sh start <slug> | resume <NNN-slug> | land <sha> | discard <NNN-slug> | abandon <NNN-slug> | prune | sync-main
# Feature worktrees live under .claude/worktrees/<NNN-slug> on feature/<NNN-slug>.
# start and resume print the worktree path on stdout; everything else goes to stderr.
# land reads its commit message from plans/<NNN-slug>/.temp/land-message.md. It exits 4 when main moved and 5 when
# the push failed for another reason; nothing landed in either case.
set -euo pipefail
root=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
dir="$root/.claude/worktrees"
trailer=Squash-of
usage="usage: worktree.sh start <slug> | resume <NNN-slug> | land <sha> | discard <NNN-slug> | abandon <NNN-slug> | prune | sync-main"

refuse() { echo "refusing: $1" >&2; exit 1; }

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

# Keeps the workflow's scratch out of every commit in this clone, whatever the repository's .gitignore says.
exclude_scratch() {
  local exclude
  exclude="$(git rev-parse --path-format=absolute --git-common-dir)/info/exclude"
  grep -qxF 'plans/**/.temp/' "$exclude" 2>/dev/null && return 0
  mkdir -p "$(dirname "$exclude")"
  printf '\nplans/**/.temp/\n' >>"$exclude"
}

# True when main holds the squash of this branch's current tip, read from the trailer land writes.
# A fresh branch, unfinished work and commits added after landing all read false.
landed() {
  local tip found
  tip=$(git -C "$root" rev-parse "$1")
  found=$(git -C "$root" log -1 --format=%H --fixed-strings --grep="$trailer: $1 $tip" origin/main 2>/dev/null || true)
  [ -n "$found" ]
}

# Removes every worktree whose branch has landed, with its branch. A worktree with uncommitted or
# untracked changes stays. Never fails, so start always goes on.
prune() {
  git -C "$root" worktree prune || true
  for wt in "$dir"/*/; do
    [ -d "$wt" ] || continue
    case "$(pwd -P)/" in "$wt"*) continue;; esac    # never remove the worktree we run from
    wt=${wt%/}
    branch=$(git -C "$wt" branch --show-current 2>/dev/null || true)
    [ -n "$branch" ] || continue
    landed "$branch" || continue
    physical=$(cd "$wt" && pwd -P) || continue
    if ! error=$(git -C "$root" worktree remove "$wt" 2>&1); then skipped "$wt" "$branch" "$error"; continue; fi
    git -C "$root" branch -D "$branch" >/dev/null 2>&1 || echo "warning: could not delete $branch" >&2
    echo "pruned $branch (landed)" >&2
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
  b=$(base); prune; exclude_scratch
  n=$( { git -C "$root" branch -a --format='%(refname:short)'; git -C "$root" ls-tree --name-only origin/main plans/; } \
       | grep -oE '(feature|plans)/[0-9]+' | grep -oE '[0-9]+$' | sort -n | tail -1 || true )
  slug=$(printf '%03d' $(( 10#${n:-0} + 1 )))-$1
  git -C "$root" worktree add -q --no-track -b "feature/$slug" "$dir/$slug" "$b" >&2
  echo "$dir/$slug"
}

resume() {
  exclude_scratch
  if [ ! -d "$dir/$1" ]; then
    git -C "$root" fetch -q origin "feature/$1" 2>/dev/null || true
    git -C "$root" worktree add -q "$dir/$1" "feature/$1" >&2
  fi
  echo "$dir/$1"
}

main_moved() { echo "main moved: merge origin/main, then land again as worktree Finish says" >&2; exit 4; }

# True when HEAD is the approved commit, or that commit cleanly merged with origin/main and nothing
# more. A commit added since, a conflict's resolution or an edit inside the merge all read false.
is_approved() {
  local merged
  [ "$(git rev-parse HEAD)" = "$1" ] && return 0
  merged=$(git merge-tree --write-tree "$1" origin/main 2>/dev/null) || return 1
  [ "$merged" = "$(git rev-parse 'HEAD^{tree}')" ]
}

# Squashes HEAD onto origin/main as one commit and pushes it with the branch, all or nothing, so origin
# keeps the slice commits. Refuses unless the checkout is clean, HEAD contains origin/main and HEAD is
# what the human approved. Only a full commit id is accepted: a name like HEAD would approve whatever
# it points at by now.
land() {
  local branch approved tip message squash
  exclude_scratch    # the message lives in scratch, and this worktree may predate the exclude
  branch=$(git branch --show-current)
  case "$branch" in feature/*) ;; *) refuse "land runs on a feature branch, not ${branch:-a detached HEAD}";; esac
  approved=$(git rev-parse -q --verify "$1^{commit}") && [ "$approved" = "$1" ] || refuse "land takes the full commit the human approved, not $1"
  message="$(git rev-parse --show-toplevel)/plans/${branch#feature/}/.temp/land-message.md"
  [ -s "$message" ] || refuse "no commit message in $message"
  [ -z "$(git status --porcelain)" ] || refuse "uncommitted changes"
  tip=$(git rev-parse HEAD)
  git fetch -q origin main
  git merge-base --is-ancestor origin/main "$tip" || main_moved
  is_approved "$approved" || refuse "HEAD is not the approved commit $1, or that commit cleanly merged with main"
  [ "$(git rev-parse 'origin/main^{tree}')" != "$(git rev-parse "$tip^{tree}")" ] || refuse "$branch changes nothing on main"
  squash=$(git interpret-trailers --no-divider --trailer "$trailer: $branch $tip" "$message" | git commit-tree "$tip^{tree}" -p origin/main)
  if ! git push -q --atomic origin "$tip:refs/heads/$branch" "$squash:refs/heads/main"; then
    git fetch -q origin main 2>/dev/null || true
    git merge-base --is-ancestor origin/main "$tip" || main_moved
    echo "push failed, nothing landed" >&2; exit 5
  fi
  sync_main || true
  [ "$(git -C "$root" rev-parse main)" = "$squash" ] \
    || echo "note: local main stayed where it was: its checkout holds conflicting changes or other commits" >&2
  echo "landed $squash" >&2
}

# What discard and abandon both need: the worktree exists, is clean, holds its own branch, and is not
# the one we run from. Any other HEAD could hold commits on no branch at all.
removable() {
  [ -d "$dir/$1" ] || { echo "no worktree $1" >&2; exit 1; }
  case "$(pwd -P)/" in "$dir/$1"/*) refuse "run this from outside $1";; esac
  [ -z "$(git -C "$dir/$1" status --porcelain)" ] || refuse "$1 has uncommitted changes"
  [ "$(git -C "$dir/$1" branch --show-current)" = "feature/$1" ] || refuse "$1 is not on feature/$1"
}

# Removes a worktree whose work is done, with its branch: only when its branch has landed or holds
# no commit that main or origin/main lacks.
discard() {
  local wt="$dir/$1" branch="feature/$1" ahead physical
  removable "$1"
  if ! landed "$branch"; then
    ahead=$(git -C "$root" rev-list --count "$branch" --not main $(git -C "$root" rev-parse -q --verify origin/main || true))
    [ "$ahead" = 0 ] || refuse "$branch has $ahead commit(s) not on main"
  fi
  physical=$(cd "$wt" && pwd -P)
  git -C "$root" worktree remove "$wt"
  git -C "$root" branch -D "$branch" >/dev/null
  remove_derived_data "$physical"
  echo "discarded $branch" >&2
}

# Removes the worktree of work that will not land, and keeps its branch, whose commits may be on no other.
abandon() {
  local wt="$dir/$1" physical
  removable "$1"
  physical=$(cd "$wt" && pwd -P)
  git -C "$root" worktree remove "$wt"
  remove_derived_data "$physical"
  echo "abandoned $1, kept feature/$1" >&2
}

case "${1:-}" in
  start|resume|land|discard|abandon) [ $# -eq 2 ] || { echo "$usage" >&2; exit 2; }; "$@" ;;
  prune) prune ;;
  sync-main) sync_main || true ;;
  *) echo "$usage" >&2; exit 2 ;;
esac
