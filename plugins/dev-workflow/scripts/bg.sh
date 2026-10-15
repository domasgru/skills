#!/usr/bin/env bash
# Run a long command in the background and wait for it in bounded foreground calls, for a command that
# outlasts one foreground Bash call (10 minutes) and cannot be split into steps.
#
#   bash bg.sh run  <dir> -- <command...>   start this with Bash run_in_background: true
#   bash bg.sh wait <dir> [seconds]         in the foreground, as often as needed; at most 570 s per call
#
# `run` records the command's pid, output and exit code in <dir>. `wait` returns as soon as the command
# has ended (printing its exit code and the tail of its output), when it died without an exit code, or
# after the time given, saying it is still running. Each call ends, so it never outlives the work, and the
# agent stays in its turn until the command is done.
set -uo pipefail

cmd=${1:-}; dir=${2:-}
[ -n "$cmd" ] && [ -n "$dir" ] || { echo "usage: bg.sh run <dir> -- <command...> | bg.sh wait <dir> [seconds]"; exit 2; }

case "$cmd" in
run)
  shift 2; [ "${1:-}" = "--" ] && shift
  mkdir -p "$dir"; rm -f "$dir/exit"
  echo $$ >"$dir/pid"
  "$@" >"$dir/out" 2>&1
  echo $? >"$dir/exit"
  ;;
wait)
  limit=${3:-570}; [ "$limit" -gt 570 ] && limit=570
  waited=0
  while :; do
    if [ -f "$dir/exit" ]; then
      echo "ended with exit code $(cat "$dir/exit") after waiting ${waited}s; last lines of $dir/out:"
      tail -n 30 "$dir/out"
      exit 0
    fi
    if [ -f "$dir/pid" ] && ! kill -0 "$(cat "$dir/pid")" 2>/dev/null; then
      echo "died without an exit code; last lines of $dir/out:"
      tail -n 30 "$dir/out" 2>/dev/null
      exit 1
    fi
    if [ "$waited" -ge "$limit" ]; then
      echo "still running after ${waited}s; call wait again"
      exit 0
    fi
    sleep 5; waited=$((waited + 5))
  done
  ;;
*) echo "unknown command: $cmd"; exit 2 ;;
esac
