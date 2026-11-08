#!/usr/bin/env bash
# Tests block-unlocked-ui-tests.sh by feeding it what Claude Code feeds a PreToolUse hook. Nothing here runs xcodebuild.
# usage: bash test-block-unlocked-ui-tests.sh
set -u

here=$(cd "$(dirname "$0")" && pwd -P)
hook="$here/block-unlocked-ui-tests.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
failures=0

# A repository with XCUITests, and one without.
ui="$scratch/with ui"
plain="$scratch/plain"
git init -q "$ui"
git init -q "$plain"
mkdir -p "$ui/apple/Tests"
printf 'import XCTest\nlet app = XCUIApplication()\n' >"$ui/apple/Tests/Fixture.swift"
printf 'import XCTest\n' >"$plain/Tests.swift"
printf 'XCUIApplication is mentioned in this note\n' >"$plain/notes.md"
git -C "$ui" add -A
git -C "$plain" add -A

decision() { # <cwd> <command>
    jq -n --arg cwd "$1" --arg command "$2" '{cwd: $cwd, tool_name: "Bash", tool_input: {command: $command}}' \
        | bash "$hook" | jq -r '.hookSpecificOutput.permissionDecision // empty'
}

denies() { # <name> <cwd> <command>
    if [ "$(decision "$2" "$3")" = deny ]; then echo "ok   $1"; else echo "FAIL $1: allowed: $3"; failures=$((failures + 1)); fi
}

allows() { # <name> <cwd> <command>
    if [ -z "$(decision "$2" "$3")" ]; then echo "ok   $1"; else echo "FAIL $1: denied: $3"; failures=$((failures + 1)); fi
}

mac="-scheme App -destination 'platform=macOS,arch=arm64'"

denies "a direct test run" "$ui" "xcodebuild test $mac"
denies "a run that does not build" "$ui" "xcodebuild test-without-building $mac"
denies "the action after the flags" "$ui" "xcodebuild $mac test"
denies "a full path to the tool" "$ui" "/usr/bin/xcodebuild test $mac"
denies "behind cd" "$ui" "cd apple && xcodebuild test $mac"
denies "in a subshell" "$ui" "(cd apple && xcodebuild test $mac)"
denies "behind an environment variable" "$ui" "DEVELOPER_DIR=/x xcodebuild test $mac"
denies "behind env, xcrun and time" "$ui" "time env A=1 xcrun xcodebuild test $mac"
denies "across a line continuation" "$ui" "xcodebuild \\
    test $mac"
denies "piped" "$ui" "xcodebuild test $mac | tail -5"
denies "one UI test" "$ui" "xcodebuild test $mac -only-testing:AppUITests/Foo/testBar"
denies "a UI test among hosted ones" "$ui" "xcodebuild test $mac -only-testing:AppHostedTests/Foo -only-testing:AppUITests/Bar"
denies "from another directory, through cd" "$plain" "cd '$ui' && xcodebuild test $mac"
denies "from another directory, through -project" "$plain" "xcodebuild test -project '$ui/apple/App.xcodeproj' $mac"

allows "a build for testing" "$ui" "xcodebuild build-for-testing $mac"
allows "a plain build" "$ui" "xcodebuild build $mac"
allows "a Simulator" "$ui" "xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 18'"
allows "hosted tests only" "$ui" "xcodebuild test $mac -only-testing:AppHostedTests/Foo"
allows "UI tests skipped" "$ui" "xcodebuild test $mac -skip-testing:AppUITests"
allows "the words in a commit message" "$ui" "git commit -m 'run xcodebuild test here'"
allows "the words in a heredoc" "$ui" "cat <<EOF
xcodebuild test
EOF"
allows "a search for the tool" "$ui" "grep xcodebuild test"
allows "the repository's own script" "$ui" "Scripts/ui-test.py -only-testing:AppUITests/Foo/testBar"
allows "a repository with no XCUITests" "$plain" "xcodebuild test $mac"
allows "outside any repository" "$scratch" "xcodebuild test $mac"
allows "nothing to do with it" "$ui" "ls -la"

if [ "$failures" -ne 0 ]; then echo "test-block-unlocked-ui-tests: $failures failed"; exit 1; fi
echo "test-block-unlocked-ui-tests: all passed"
