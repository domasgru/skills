#!/usr/bin/env python3
"""Make dev-workflow agents use the Apple-platform skills.

`start` (SubagentStart): in a Swift repo, tells the agent which skills to invoke.
`stop` (SubagentStop): blocks an implementer or standards reviewer once when it
changed or reviewed files that require a skill it never invoked.

Reads the hook input on stdin. Any internal error exits 0 with no output, so a
bug here never stalls the workflow.
"""

import json
import os
import re
import subprocess
import sys

ROUTING_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "skill-routing.json")

WRITERS = {"dev-workflow:implementer"}
REVIEWERS = {"dev-workflow:implementation-standards-reviewer"}
PLANNERS = {
    "dev-workflow:architect",
    "dev-workflow:architect-runner-opus",
    "dev-workflow:architect-runner-fable",
    "dev-workflow:architect-test-planner",
    "dev-workflow:planner",
    "dev-workflow:plan-reviewer",
    "dev-workflow:implementation-orchestrator",
}

MAX_FILE_BYTES = 512 * 1024


def load_routing():
    with open(ROUTING_PATH) as f:
        routing = json.load(f)
    for rule in routing["rules"]:
        rule["path_res"] = [re.compile(p) for p in rule["paths"]]
        rule["content_res"] = [re.compile(c, re.MULTILINE) for c in rule["content"]]
    return routing


def git(cwd, *args):
    result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, timeout=20)
    return result.stdout if result.returncode == 0 else ""


def is_swift_repo(cwd):
    return bool(git(cwd, "ls-files", "--", "*.swift", "*Package.swift").strip())


def uncommitted_files(cwd):
    """Files changed in the working tree against HEAD, including untracked ones."""
    changed = git(cwd, "diff", "--name-only", "HEAD").splitlines()
    untracked = git(cwd, "ls-files", "--others", "--exclude-standard").splitlines()
    return [p for p in changed + untracked if p]


def default_branch(cwd):
    head = git(cwd, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD").strip()
    for candidate in ([head] if head else []) + ["main", "origin/main", "master"]:
        if git(cwd, "rev-parse", "--verify", "--quiet", candidate).strip():
            return candidate
    return None


def branch_files(cwd):
    """Files the feature branch changes against the default branch, plus uncommitted ones."""
    base = default_branch(cwd)
    files = []
    if base:
        merge_base = git(cwd, "merge-base", "HEAD", base).strip()
        if merge_base:
            files = git(cwd, "diff", "--name-only", merge_base, "HEAD").splitlines()
    return sorted(set(p for p in files if p) | set(uncommitted_files(cwd)))


def required_skills(cwd, paths, routing):
    """Map each required skill to the changed files that require it."""
    required = {}
    for path in paths:
        full = os.path.join(cwd, path)
        content = ""
        if os.path.isfile(full) and os.path.getsize(full) <= MAX_FILE_BYTES:
            try:
                with open(full, encoding="utf-8", errors="ignore") as f:
                    content = f.read()
            except OSError:
                pass
        for rule in routing["rules"]:
            by_path = any(r.search(path) for r in rule["path_res"])
            by_content = path.endswith(".swift") and any(r.search(content) for r in rule["content_res"])
            if by_path or by_content:
                required.setdefault(rule["skill"], []).append(path)
    return required


def bare(skill_name):
    return skill_name.rsplit(":", 1)[-1]


def invoked_skills(transcript_path):
    """Skills the agent loaded: Skill tool calls, or a direct Read of a skill's SKILL.md."""
    used = set()
    if not transcript_path or not os.path.isfile(transcript_path):
        return used
    with open(transcript_path, encoding="utf-8", errors="ignore") as f:
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
                    used.add(bare(tool_input["skill"]))
                elif block.get("name") == "Read":
                    match = re.search(r"/([^/]+)/SKILL\.md$", tool_input.get("file_path", ""))
                    if match:
                        used.add(match.group(1))
    return used


def skill_table(routing):
    rows = [f"- `{r['skill']}`: {r['covers']}" for r in routing["rules"]]
    rows += [f"- `{r['skill']}` (as needed): {r['covers']}" for r in routing["on_demand"]]
    return "\n".join(rows)


def start_context(agent_type, routing):
    table = skill_table(routing)
    if agent_type in WRITERS:
        return (
            "This is an Apple-platform repo. Before you write code, invoke with the Skill tool each of these "
            "skills that covers code you will touch, then open the reference files its entry file routes you to "
            "for this change. A check at the end of your turn verifies, from the files you changed, that you did.\n"
            f"{table}"
        )
    if agent_type in REVIEWERS:
        return (
            "This is an Apple-platform repo. Before you review, invoke with the Skill tool each of these skills "
            "that covers code in the diff. Their rules are documented standards: cite a breach as the skill and "
            "the reference file that states the rule. A check at the end of your turn verifies, from the files "
            "in the diff, that you did.\n"
            f"{table}"
        )
    return (
        "This is an Apple-platform repo. These skills hold the platform guidance for its code. Invoke the ones "
        "that cover the work you are designing or checking, and wherever you name a slice's skills, choose from "
        "this list by full name.\n"
        f"{table}"
    )


def stop_reason(agent_type, missing):
    lines = []
    for skill, paths in sorted(missing.items()):
        shown = ", ".join(paths[:4]) + (f" and {len(paths) - 4} more" if len(paths) > 4 else "")
        lines.append(f"- `{skill}`, required by {shown}")
    listing = "\n".join(lines)
    if agent_type in WRITERS:
        action = (
            "Invoke each with the Skill tool now, open the reference files it routes you to for this change, "
            "check your changes against them and fix what they flag. Rerun the quick gate if you changed code, "
            "then give your report again, listing the skills you used."
        )
    else:
        action = (
            "Invoke each with the Skill tool now, open the reference files it routes you to for this diff, "
            "review the diff against them, and give your report again with any new findings, each citing the "
            "skill and the reference file."
        )
    return f"Your turn touched code that requires skills you have not invoked:\n{listing}\n{action}"


def handle_start(event):
    agent_type = event.get("agent_type", "")
    if agent_type not in WRITERS | REVIEWERS | PLANNERS:
        return None
    cwd = event.get("cwd") or os.getcwd()
    if not is_swift_repo(cwd):
        return None
    routing = load_routing()
    return {
        "hookSpecificOutput": {
            "hookEventName": "SubagentStart",
            "additionalContext": start_context(agent_type, routing),
        }
    }


def handle_stop(event):
    agent_type = event.get("agent_type", "")
    if agent_type not in WRITERS | REVIEWERS or event.get("stop_hook_active"):
        return None
    cwd = event.get("cwd") or os.getcwd()
    paths = uncommitted_files(cwd) if agent_type in WRITERS else branch_files(cwd)
    required = required_skills(cwd, paths, load_routing())
    if not required:
        return None
    used = invoked_skills(event.get("agent_transcript_path"))
    missing = {skill: files for skill, files in required.items() if skill not in used}
    if not missing:
        return None
    return {"decision": "block", "reason": stop_reason(agent_type, missing)}


def main():
    try:
        mode = sys.argv[1]
        event = json.load(sys.stdin)
        output = handle_start(event) if mode == "start" else handle_stop(event)
    except Exception as error:  # a broken check must never stall the workflow
        print(f"swift_skills: {error!r}", file=sys.stderr)
        return 0
    if output:
        print(json.dumps(output))
    return 0


if __name__ == "__main__":
    sys.exit(main())
