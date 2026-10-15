#!/usr/bin/env bash
# PreToolUse hook for Bash and Monitor: denies the polling a subagent uses to wait on background work.
# Such a wait never ends when the work fails or the watched process is gone, so the agent and the
# process outlive the work. The main session is left alone: Claude Code itself recommends Monitor there.
set -euo pipefail

input=$(cat)
[ -n "$(jq -r '.agent_id // empty' <<<"$input")" ] || exit 0
command=$(jq -r '.tool_input.command // empty' <<<"$input")
# Heredoc bodies and quoted strings are data, not shell: a "for" or "sleep" inside them is not a loop.
shell=$(perl -0777 -pe 's/(<<-?[ \t]*([\x27"]?)(\w+)\2[^\n]*)\n.*?\n[ \t]*\3(?=\n|$)/$1/gs; s/\x27[^\x27]*\x27//g; s/"(?:\\.|[^"\\])*"//gs' <<<"$command")

boundary='(^|[[:space:];&|(])'
reason=
if grep -Eq "${boundary}tail[[:space:]]([^;&|]*[[:space:]])?(-[[:alnum:]]*[fF]|--follow)" <<<"$shell"; then
  reason='`tail -f` never exits, so you stay open after the work you watch has ended.'
elif grep -Eq "${boundary}(for|while|until)[[:space:]]" <<<"$shell" && grep -Eq "${boundary}sleep([[:space:]]|$)" <<<"$shell"; then
  reason='A sleep loop waits on a condition that may never come true: a subagent that failed or a process that died never satisfies it.'
elif grep -Eq '/subagents/agent-|/tasks/a[0-9a-f]{16}\.output' <<<"$command"; then
  reason='Subagent transcripts are internal and do not say reliably whether a subagent has finished.'
fi
[ -n "$reason" ] || exit 0

jq -n --arg reason "Blocked: $reason To wait for a subagent you dispatched, end your turn; its report resumes you. Never end your turn while a command you started is still running: with no child running, your end of turn is read as your final report. Run a long command such as a test gate as a foreground Bash call with timeout 600000, its steps as separate foreground calls, or one step through scripts/bg.sh in this plugin, as references/handoff.md says." '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
