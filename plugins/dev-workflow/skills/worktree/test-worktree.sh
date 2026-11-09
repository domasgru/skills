#!/usr/bin/env bash
# Tests worktree.sh end to end against a real repository and a local bare origin. HOME and git's config are redirected
# and gh is a stub that records any call, so nothing outside the scratch directory is touched.
# usage: bash test-worktree.sh
set -u

here=$(cd "$(dirname "$0")" && pwd -P)
script="$here/worktree.sh"
scratch=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$scratch"' EXIT
failures=0

export HOME="$scratch/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
mkdir -p "$HOME" "$scratch/bin"
printf '#!/bin/sh\ntouch "%s/gh-called"\nexit 1\n' "$scratch" >"$scratch/bin/gh"
chmod +x "$scratch/bin/gh"
export PATH="$scratch/bin:$PATH"

wt() { bash "$script" "$@"; }

same() { # <name> <actual> <expected>
    if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$3', got '$2'"; failures=$((failures + 1)); fi
}

exits() { # <name> <expected status> <command...>
    local name=$1 expected=$2 actual=0
    shift 2
    "$@" >/dev/null 2>&1 || actual=$?
    same "$name" "$actual" "$expected"
}

says() { # <name> <expected status> <text in its output> <command...>
    local name=$1 expected=$2 text=$3 actual=0 output
    shift 3
    output=$("$@" 2>&1) || actual=$?
    same "$name" "$actual" "$expected"
    case "$output" in
        *"$text"*) echo "ok   $name: says why" ;;
        *) echo "FAIL $name: expected '$text' in '$output'"; failures=$((failures + 1)) ;;
    esac
}

exists() { if [ -e "$1" ]; then echo yes; else echo no; fi; }
has_branch() { if git -C "$root" rev-parse -q --verify "refs/heads/$1" >/dev/null; then echo yes; else echo no; fi; }
on_origin() { git -C "$root" ls-remote origin "refs/heads/$1" | cut -f1; }
excluded() { grep -cxF 'plans/**/.temp/' "$root/.git/info/exclude"; }
start() { wt start "$1" 2>/dev/null; }
take_main() { git fetch -q origin main && git merge -q --no-edit origin/main; }
message_path() { echo "$(git rev-parse --show-toplevel)/plans/$(git branch --show-current | sed 's|^feature/||')/.temp/land-message.md"; }
land_here() { take_main; write_message; wt land "$(git rev-parse HEAD)" >/dev/null 2>&1; }

write_message() { # where land reads it, for the worktree we are in
    mkdir -p "$(dirname "$(message_path)")"
    cp "$message" "$(message_path)"
}

commit_file() { # <path> <line> <subject>
    mkdir -p "$(dirname "$1")"
    printf '%s\n' "$2" >>"$1"
    git add -A
    git commit -qm "$3"
}

move_main() { # <file>, committed by another session
    (cd "$other" && git pull -q --no-edit origin main && commit_file "$1" moved "main moved: $1" && git push -q origin main)
}

root="$scratch/repo"
other="$scratch/other"
message="$scratch/message"
git init -q --bare -b main "$scratch/origin.git"
git clone -q "$scratch/origin.git" "$root" 2>/dev/null
cd "$root" || exit 1
git symbolic-ref HEAD refs/heads/main
commit_file notes.txt first "first"
git push -q -u origin main
git clone -q "$scratch/origin.git" "$other"
cat >"$message" <<'EOF'
Add the feature

What it does.

---

## Merge Danger

**Door:** two-way

**Blast Radius:** small

Co-Authored-By: Claude <noreply@anthropic.com>
EOF

# Landing squashes the approved commit onto main.
alpha=$(start alpha)
same "start writes the scratch exclude" "$(excluded)" 1
cd "$alpha" || exit 1
commit_file plans/001-alpha/plan.md plan "plans"
commit_file alpha.txt one "slice one"
commit_file alpha.txt two "slice two"
write_message
before=$(git rev-parse origin/main)
tip=$(git rev-parse HEAD)
tree=$(git rev-parse 'HEAD^{tree}')
exits "land succeeds" 0 wt land "$tip"
landed=$(on_origin main)
same "main's tree is the gated tree" "$(git rev-parse "$landed^{tree}")" "$tree"
same "the feature is one commit on main" "$(git rev-list --count "$before..$landed")" 1
same "its one parent is the old main" "$(git log -1 --format=%P "$landed")" "$before"
same "its subject is the message's" "$(git log -1 --format=%s "$landed")" "Add the feature"
same "its body keeps Markdown headings" "$(git log -1 --format=%B "$landed" | grep -c '^## Merge Danger$')" 1
same "its trailer names the branch and tip" "$(git log -1 --format='%(trailers:key=Squash-of,valueonly)' "$landed")" "feature/001-alpha $tip"
same "the message's own trailer survives" "$(git log -1 --format='%(trailers:key=Co-Authored-By,valueonly)' "$landed")" "Claude <noreply@anthropic.com>"
same "the trailer closes the message, past a --- line" "$(git log -1 --format=%B "$landed" | sed '/^$/d' | tail -1 | cut -d: -f1)" "Squash-of"
same "origin keeps the slice commits" "$(on_origin feature/001-alpha)" "$tip"
same "local main follows" "$(git -C "$root" rev-parse main)" "$landed"
same "the trailer's tip recovers the slice commits" "$(git log --format=%s "$landed^..$tip" | tr '\n' ,)" "slice two,slice one,plans,"

# Landing refuses anything but the approved, clean, current commit.
cd "$root" || exit 1
bravo=$(start bravo)
same "start prunes a landed worktree" "$(exists "$alpha")" no
cd "$bravo" || exit 1
write_message
says "a branch with nothing to land is refused" 1 "changes nothing" wt land "$(git rev-parse HEAD)"
commit_file bravo.txt one "one"
commit_file bravo.txt two "two"
tip=$(git rev-parse HEAD)
main_before=$(on_origin main)
says "an older commit is refused" 1 "not the approved commit" wt land "$(git rev-parse HEAD~1)"
says "an unknown commit is refused" 1 "full commit" wt land 0000000000000000000000000000000000000000
says "the name HEAD is refused, whatever it points at now" 1 "full commit" wt land HEAD
says "a short commit is refused" 1 "full commit" wt land "$(git rev-parse --short HEAD)"
rm "$(message_path)"
says "a missing message is refused" 1 "no commit message" wt land "$tip"
: >"$(message_path)"
says "an empty message is refused" 1 "no commit message" wt land "$tip"
write_message
exits "the wrong arguments are a usage error" 2 wt land
printf 'dirty\n' >dirty.txt
says "uncommitted work is refused" 1 "uncommitted changes" wt land "$tip"
rm dirty.txt
cd "$root" || exit 1
says "land refuses to run on main" 1 "feature branch" wt land "$(git rev-parse HEAD)"
cd "$bravo" || exit 1
same "a refused landing leaves main alone" "$(on_origin main)" "$main_before"
same "a refused landing pushes no branch" "$(on_origin feature/002-bravo)" ""

# Approval survives a clean merge of a moved main.
move_main moved.txt
exits "land says main moved" 4 wt land "$tip"
same "and pushes nothing" "$(on_origin feature/002-bravo)" ""
take_main
merged=$(git rev-parse HEAD)
tree=$(git rev-parse 'HEAD^{tree}')
exits "the approved commit lands over a clean merge of main" 0 wt land "$tip"
same "with the merged tree" "$(git rev-parse "$(on_origin main)^{tree}")" "$tree"
same "on top of the moved main" "$(git log -1 --format=%P "$(on_origin main)")" "$(git -C "$other" rev-parse HEAD)"
same "its diff is only the feature" "$(git show --format= --name-only "$(on_origin main)")" "bravo.txt"
same "its trailer names the merged tip" "$(git log -1 --format='%(trailers:key=Squash-of,valueonly)' "$(on_origin main)")" "feature/002-bravo $merged"
same "origin keeps the merged tip" "$(on_origin feature/002-bravo)" "$merged"
same "its slice commits exclude what came from main" "$(git log --format=%s "$(on_origin main)^..$merged" | grep -c 'main moved')" 0

# Approval covers nothing else that reached the branch.
cd "$root" || exit 1
extra=$(start extra)
cd "$extra" || exit 1
commit_file extra.txt one "approved"
write_message
approved=$(git rev-parse HEAD)
commit_file extra.txt two "added after approval"
says "a commit added after approval is refused" 1 "not the approved commit" wt land "$approved"
move_main extra-main.txt
take_main
says "and merging main does not hide it" 1 "not the approved commit" wt land "$approved"
exits "a new approval of the new commit lands" 0 wt land "$(git rev-parse HEAD)"

cd "$root" || exit 1
evil=$(start evil)
cd "$evil" || exit 1
commit_file evil.txt one "approved"
write_message
approved=$(git rev-parse HEAD)
move_main evil-main.txt
take_main
printf 'slipped in\n' >>evil.txt
git add -A
git commit -q --amend --no-edit
says "a merge that changes anything else is refused" 1 "not the approved commit" wt land "$approved"

cd "$root" || exit 1
resolved=$(start resolved)
cd "$resolved" || exit 1
commit_file both.txt branch "branch side"
write_message
approved=$(git rev-parse HEAD)
move_main both.txt
git fetch -q origin main
git merge -q --no-edit origin/main >/dev/null 2>&1
printf 'both sides\n' >both.txt
git add -A
git commit -qm "resolved"
says "a merge that needed resolving is refused" 1 "not the approved commit" wt land "$approved"
exits "a new approval of the resolution lands" 0 wt land "$(git rev-parse HEAD)"

# A push that loses a race changes nothing on origin, and takes the same route as main moving.
cd "$root" || exit 1
race=$(start race)
cd "$race" || exit 1
commit_file race.txt one "race"
write_message
hook="$root/.git/hooks/pre-push"
mkdir -p "$root/.git/hooks"
cat >"$hook" <<EOF
#!/bin/sh
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
cd "$other" && git pull -q --no-edit origin main && echo raced >>raced.txt && git add -A && git commit -qm raced && git push -q origin main
EOF
chmod +x "$hook"
exits "a push that loses the race says main moved" 4 wt land "$(git rev-parse HEAD)"
rm "$hook"
same "main is the other session's commit" "$(on_origin main)" "$(git -C "$other" rev-parse HEAD)"
same "and the branch push rolled back with it" "$(on_origin "feature/$(basename "$race")")" ""
exits "taking main in and landing again works" 0 land_here

# A push that fails for another reason lands nothing, and says so.
cd "$root" || exit 1
wt sync-main
diverged=$(start diverged)
slug=$(basename "$diverged")
(cd "$other" && git pull -q --no-edit origin main && git switch -q -c elsewhere && commit_file elsewhere.txt one "elsewhere" \
    && git push -q origin "elsewhere:refs/heads/feature/$slug" && git switch -q main)
cd "$diverged" || exit 1
commit_file diverged.txt one "diverged"
write_message
main_before=$(on_origin main)
says "a branch that moved on origin fails the push" 5 "nothing landed" wt land "$(git rev-parse HEAD)"
same "and main stays" "$(on_origin main)" "$main_before"

# Land works from anywhere in the worktree: a gate may leave the shell in a subdirectory.
cd "$root" || exit 1
sub=$(start sub)
cd "$sub" || exit 1
commit_file apple/sub.txt one "in a subdirectory"
write_message
cd apple || exit 1
exits "land runs from a subdirectory" 0 wt land "$(git rev-parse HEAD)"

# The human's main checkout is theirs.
cd "$root" || exit 1
wt sync-main
printf 'human\n' >>notes.txt
kept=$(start kept)
cd "$kept" || exit 1
commit_file kept.txt one "kept"
land_here
same "local main passes a human's unrelated edit" "$(git -C "$root" rev-parse main)" "$(on_origin main)"
same "and the edit survives" "$(grep -c human "$root/notes.txt")" 1
cd "$root" || exit 1
clash=$(start clash)
cd "$clash" || exit 1
commit_file notes.txt feature "clash"
write_message
held=$(git -C "$root" rev-parse main)
output=$(wt land "$(git rev-parse HEAD)" 2>&1)
same "landing goes on over a conflicting edit" "$?" 0
same "local main stays put" "$(git -C "$root" rev-parse main)" "$held"
same "the conflicting edit survives" "$(grep -c human "$root/notes.txt")" 1
same "land says local main stayed" "$(printf '%s\n' "$output" | grep -c 'local main')" 1
cd "$root" || exit 1
exits "discard judges by origin, past a stale local main" 0 wt discard "$(basename "$clash")"
git checkout -q -- notes.txt
wt sync-main
same "local main catches up once the edit is gone" "$(git rev-parse main)" "$(on_origin main)"

# Prune tells landed work from everything else.
done_tree=$(start done-tree)
fresh=$(start fresh-tree)
progress=$(start progress-tree)
later=$(start later-tree)
dirty=$(start dirty-tree)
cd "$progress" || exit 1
commit_file progress.txt one "unfinished"
cd "$done_tree" || exit 1
commit_file done.txt one "done"
land_here
cd "$later" || exit 1
commit_file later.txt one "landed"
land_here
commit_file later.txt two "added after landing"
cd "$dirty" || exit 1
commit_file dirty.txt one "landed"
land_here
printf 'scratch\n' >untracked.txt
cd "$done_tree" || exit 1
wt prune 2>/dev/null
same "prune spares the worktree it runs from" "$(exists "$done_tree")" yes
cd "$root" || exit 1
output=$(wt prune 2>&1)
same "prune removes a landed worktree" "$(exists "$done_tree")" no
same "and its branch" "$(has_branch "feature/$(basename "$done_tree")")" no
same "origin keeps that branch's commits" "$([ -n "$(on_origin "feature/$(basename "$done_tree")")" ] && echo yes)" yes
same "prune spares a fresh worktree, whose tip is on main" "$(exists "$fresh")" yes
same "prune spares unfinished work" "$(exists "$progress")" yes
same "prune spares commits added after landing" "$(exists "$later")" yes
same "prune spares a landed worktree with uncommitted changes" "$(exists "$dirty")" yes
same "and says why" "$(printf '%s\n' "$output" | grep -c 'uncommitted change')" 1
same "prune never asks gh" "$(exists "$scratch/gh-called")" no

# Discard takes landed work and work that produced nothing, and nothing else.
says "discard refuses uncommitted changes" 1 "uncommitted changes" wt discard "$(basename "$dirty")"
rm "$dirty/untracked.txt"
cd "$dirty" || exit 1
says "discard refuses the worktree it runs from" 1 "outside" wt discard "$(basename "$dirty")"
cd "$root" || exit 1
exits "discard removes a landed worktree" 0 wt discard "$(basename "$dirty")"
same "and its branch" "$(has_branch "feature/$(basename "$dirty")")" no
says "discard refuses unlanded commits" 1 "not on main" wt discard "$(basename "$progress")"
same "and the worktree stays" "$(exists "$progress")" yes
exits "discard removes a worktree that produced nothing" 0 wt discard "$(basename "$fresh")"

# Abandon drops the worktree of work that will not land, and keeps its commits.
printf 'scratch\n' >"$progress/untracked.txt"
says "abandon refuses uncommitted changes" 1 "uncommitted changes" wt abandon "$(basename "$progress")"
rm "$progress/untracked.txt"
cd "$progress" || exit 1
says "abandon refuses the worktree it runs from" 1 "outside" wt abandon "$(basename "$progress")"
cd "$root" || exit 1
exits "abandon removes the worktree" 0 wt abandon "$(basename "$progress")"
same "the worktree is gone" "$(exists "$progress")" no
same "the branch stays" "$(has_branch "feature/$(basename "$progress")")" yes

# A detached worktree's commits are on no branch, so neither removal may take it.
detached=$(start detached-tree)
cd "$detached" || exit 1
git switch -q --detach
commit_file detached.txt one "on no branch"
cd "$root" || exit 1
says "discard refuses a detached worktree" 1 "is not on" wt discard "$(basename "$detached")"
says "abandon refuses a detached worktree" 1 "is not on" wt abandon "$(basename "$detached")"
same "and its commit stays reachable" "$(exists "$detached")" yes

# A landed branch keeps its number taken, plan or no plan.
last=$(start last-tree)
cd "$last" || exit 1
commit_file last.txt one "no plan"
land_here
cd "$root" || exit 1
wt discard "$(basename "$last")" 2>/dev/null
next=$(start next-tree)
number=$(basename "$last" | cut -c1-3)
same "the next worktree takes the next number" "$(basename "$next")" "$(printf '%03d' $((10#$number + 1)))-next-tree"

# Workflow scratch stays out of every commit, whatever the repository's .gitignore says.
cd "$next" || exit 1
mkdir -p plans/x/.temp
printf 'notes\n' >plans/x/.temp/notes.md
printf 'plan\n' >plans/x/plan.md
same "scratch is invisible to commit everything" "$(git status --porcelain -uall | grep -c '\.temp')" 0
same "the plan beside it is not" "$(git status --porcelain -uall | grep -c 'plan\.md')" 1
git add -A
git commit -qm "plan"
same "scratch stays out of the commit" "$(git ls-files | grep -c '\.temp')" 0
land_here
cd "$root" || exit 1
exits "scratch does not block discard" 0 wt discard "$(basename "$next")"
another=$(start another-tree)
same "the exclude is written once" "$(excluded)" 1
grep -vxF 'plans/**/.temp/' .git/info/exclude >"$scratch/exclude"
cp "$scratch/exclude" .git/info/exclude
wt resume "$(basename "$later")" >/dev/null
same "resume writes it for an older worktree" "$(excluded)" 1
older=$(start older-tree)
cd "$older" || exit 1
commit_file older.txt one "older"
write_message
cp "$scratch/exclude" "$root/.git/info/exclude"
exits "land takes its message from scratch, in a worktree older than the exclude" 0 wt land "$(git rev-parse HEAD)"
same "and the message is not in the commit" "$(git show --format= --name-only "$(on_origin main)" | grep -c '\.temp')" 0
cd "$root" || exit 1

# Removing a worktree removes its Xcode DerivedData, and only its own. plutil exists only on macOS.
derived_data() { # <folder> <workspace path>
    mkdir -p "$HOME/Library/Developer/Xcode/DerivedData/$1"
    printf '<?xml version="1.0"?><plist version="1.0"><dict><key>WorkspacePath</key><string>%s</string></dict></plist>\n' \
        "$2" >"$HOME/Library/Developer/Xcode/DerivedData/$1/info.plist"
}
if command -v plutil >/dev/null; then
    gone=$(start gone-tree)
    derived_data discarded "$another/App.xcodeproj"
    derived_data abandoned "$gone/App.xcodeproj"
    derived_data unrelated "$scratch/elsewhere/App.xcodeproj"
    exits "discard goes through" 0 wt discard "$(basename "$another")"
    same "discard removes the worktree's DerivedData" "$(exists "$HOME/Library/Developer/Xcode/DerivedData/discarded")" no
    exits "abandon goes through" 0 wt abandon "$(basename "$gone")"
    same "abandon removes the worktree's DerivedData" "$(exists "$HOME/Library/Developer/Xcode/DerivedData/abandoned")" no
    same "another project's DerivedData stays" "$(exists "$HOME/Library/Developer/Xcode/DerivedData/unrelated")" yes
fi

if [ "$failures" -ne 0 ]; then echo "test-worktree: $failures failed"; exit 1; fi
echo "test-worktree: all passed"
