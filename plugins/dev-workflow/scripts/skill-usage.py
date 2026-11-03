#!/usr/bin/env python3
"""Report which skills each agent loaded in Claude Code sessions.

Usage: skill-usage.py <project-dir-or-session.jsonl>...

A project dir is one under ~/.claude/projects/; every session in it is reported.
A skill counts as loaded when the agent called the Skill tool for it or read its SKILL.md.
"""

import glob
import json
import os
import re
import sys


def skills_in(transcript):
    used = []
    with open(transcript, encoding="utf-8", errors="ignore") as f:
        for line in f:
            try:
                content = json.loads(line).get("message", {}).get("content")
            except (ValueError, AttributeError):
                continue
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict) or block.get("type") != "tool_use":
                    continue
                tool_input = block.get("input") or {}
                if block.get("name") == "Skill" and tool_input.get("skill"):
                    used.append(tool_input["skill"].rsplit(":", 1)[-1])
                elif block.get("name") == "Read":
                    match = re.search(r"/([^/]+)/SKILL\.md$", tool_input.get("file_path", ""))
                    if match:
                        used.append(match.group(1))
    return sorted(set(used))


def agent_type(transcript):
    meta = transcript[: -len(".jsonl")] + ".meta.json"
    try:
        with open(meta) as f:
            return json.load(f).get("agentType", "?")
    except (OSError, ValueError):
        return "?"


def report(session):
    print(f"== {session}")
    print(f"   {'main session':45} {', '.join(skills_in(session)) or '-'}")
    subagents = glob.glob(os.path.join(session[: -len(".jsonl")], "subagents", "*.jsonl"))
    for transcript in sorted(subagents, key=os.path.getmtime):
        print(f"   {agent_type(transcript):45} {', '.join(skills_in(transcript)) or '-'}")


def main(args):
    if not args:
        print(__doc__.strip())
        return 2
    for arg in args:
        sessions = [arg] if arg.endswith(".jsonl") else glob.glob(os.path.join(arg, "*.jsonl"))
        for session in sorted(sessions, key=os.path.getmtime):
            report(session)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
