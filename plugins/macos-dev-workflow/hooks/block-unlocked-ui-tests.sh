#!/usr/bin/env bash
# PreToolUse hook for Bash: denies a direct `xcodebuild test` that could run a Mac app's UI tests. They drive the real pointer
# and keyboard, so a run that holds no lock collides with any other session's run, and fails at random. The repository's own
# script holds the lock; its xcodebuild is out of this hook's sight, and needs to be. Simulator runs have a pointer of their own.
set -euo pipefail

input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
case "$command" in *xcodebuild*) ;; *) exit 0 ;; esac

# A line continuation joins its lines. A heredoc's body is data, and so is a quoted string: the words in a commit message are
# not a command. Flags and paths are read with the quotes left in, since a destination is usually quoted.
joined=$(perl -0777 -pe 's/\\\n/ /g; s/(<<-?[ \t]*([\x27"]?)(\w+)\2[^\n]*)\n.*?\n[ \t]*\3(?=\n|$)/$1/gs' <<<"$command")
shell=$(perl -0777 -pe 's/\x27[^\x27]*\x27//g; s/"(?:\\.|[^"\\])*"//gs; s/[;&|()]/\n/g' <<<"$joined")

prefix='([[:alnum:]_]+=[^[:space:]]*[[:space:]]+|(env|time|nohup|exec|command|xcrun)[[:space:]]+|timeout[[:space:]]+[^[:space:]]+[[:space:]]+)*'
action='(.*[[:space:]])?(test|test-without-building)([[:space:]]|$)'
grep -Eq "^[[:space:]]*${prefix}([^[:space:]]*/)?xcodebuild[[:space:]]${action}" <<<"$shell" || exit 0

grep -Eq -- '-destination[[:space:]=].*Simulator' <<<"$joined" && exit 0

only=$(grep -Eo -- '-only-testing:[^[:space:]"\x27]+' <<<"$joined" || true)
if [ -n "$only" ]; then
  grep -q 'UITests' <<<"$only" || exit 0
else
  grep -Eq -- '-skip-testing:[^[:space:]]*UITests' <<<"$joined" && exit 0
fi

# Whether a directory the command runs in, or names its project in, belongs to a repository with XCUITests.
has_ui_tests() {
  [ -d "$1" ] && git -C "$1" grep -q XCUIApplication -- '*.swift' 2>/dev/null
}

found=no
has_ui_tests "$cwd" && found=yes
while IFS= read -r target; do
  [ -n "$target" ] || continue
  case "$target" in /*) ;; *) target="$cwd/$target" ;; esac
  has_ui_tests "$target" && found=yes
done < <(perl -ne '
  while (/(?:^|[;&|(\s])cd\s+(\x27[^\x27]*\x27|"[^"]*"|[^\s;&|)]+)/g) { my $path = $1; $path =~ s/^[\x27"]|[\x27"]$//g; print "$path\n"; }
  while (/-(?:project|workspace)\s+(\x27[^\x27]*\x27|"[^"]*"|\S+)/g) { my $path = $1; $path =~ s/^[\x27"]|[\x27"]$//g; $path =~ s{/?[^/]*$}{}; print(($path eq "" ? "." : $path) . "\n"); }
' <<<"$joined")
[ "$found" = yes ] || exit 0

jq -n --arg reason 'Blocked: this repository has XCUITests, which drive the real pointer and keyboard, so a direct run collides with any other session on this Mac and fails at random. Run them through the repository'"'"'s script, which waits for the machine-wide lock, tests a build with its own bundle id and gives a verdict on each failure: `Scripts/ui-test.py -only-testing:<target>/<class>/<test>` in `apple/` of filesapp-apple, run in the background since the wait can be long. A repository with no such script needs one first (see "One driver" in create-verification-skill/references/macos.md). These need no lock: a Simulator destination, `-skip-testing:<...UITests>`, and `-only-testing:` of targets that are not UI tests.' '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
