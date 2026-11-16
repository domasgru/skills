#!/usr/bin/env bash
# Tests block-polling.sh with the waits agents have used, and with commands it must let through.
# usage: bash hooks/test-block-polling.sh
set -uo pipefail
hook="$(dirname "$0")/block-polling.sh"
failed=0

decide() {   # <agent_id> <command>: prints deny or allow
  local out
  out=$(jq -n --arg agent "$1" --arg command "$2" '{agent_id: $agent, tool_input: {command: $command}} | if .agent_id == "" then del(.agent_id) else . end' | bash "$hook")
  if grep -q '"deny"' <<<"$out"; then echo deny; else echo allow; fi
}

expect() {   # <deny|allow> <agent_id> <command>
  local got
  got=$(decide "$2" "$3")
  if [ "$got" = "$1" ]; then echo "ok   $1: $3"; else echo "FAIL expected $1, got $got: $3"; failed=1; fi
}

sub=a0124da9ffdab06b4
expect deny  "$sub" 'until grep -q done /tmp/run.log || ! pgrep -f ui-test.py >/dev/null; do sleep 10; done'
expect deny  "$sub" 'tail -f /tmp/run.log'
expect deny  "$sub" 'sleep 540; tail -c 600 /tmp/vm-ui-all.log'
expect deny  "$sub" 'python3 -c "import select; select.select([],[],[],170)"; tail -c 300 /tmp/a6.log'
expect deny  "$sub" "python3 -I -c \"import time; time.sleep(540); print('waited')\""
expect deny  "$sub" 'lsof +r 30 -p 4242 >/dev/null; tail -c 400 /tmp/a.log'
expect deny  "$sub" 'read -t 170 -u 0 x < /dev/zero'
expect deny  "$sub" 'cat /private/tmp/claude-501/x/tasks/a7cdd791fcc6c84e1.output'
expect allow "$sub" 'Scripts/ui-test.py -only-testing:FilesMacUITests/NewNoteUITests'
expect allow "$sub" 'ax.sh "$RUN" menu "Quit Files App DEV"; sleep 3; launch.sh --again "$RUN"'
expect allow "$sub" 'python3 -c "import time; time.sleep(0.5)"'
expect allow "$sub" 'git commit -m "sleep 600 in a message is data"'
expect allow ""     'sleep 540'
[ "$failed" = 0 ] && echo "block-polling: all green" || { echo "block-polling: FAILED"; exit 1; }
