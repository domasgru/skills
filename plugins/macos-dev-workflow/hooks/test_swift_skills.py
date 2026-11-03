import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "swift_skills.py")

SWIFTUI_VIEW = "import SwiftUI\n\nstruct Card: View {\n    var body: some View { Text(\"hi\") }\n}\n"
ASYNC_MODEL = "import Foundation\n\nactor Store {\n    func load() async {}\n}\n"
SWIFT_TEST = "import Testing\n\n@Test func adds() { #expect(1 + 1 == 2) }\n"
PLAIN = "struct Point { var x = 0 }\n"


def run(*args, cwd):
    subprocess.run(args, cwd=cwd, check=True, capture_output=True)


class Repo:
    def __init__(self):
        self.dir = tempfile.TemporaryDirectory()
        self.path = os.path.realpath(self.dir.name)
        run("git", "init", "-q", "-b", "main", cwd=self.path)
        run("git", "config", "user.email", "t@t", cwd=self.path)
        run("git", "config", "user.name", "t", cwd=self.path)
        self.write("Sources/Point.swift", PLAIN)
        self.commit("base")

    def write(self, rel, text):
        full = os.path.join(self.path, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w") as f:
            f.write(text)

    def commit(self, message):
        run("git", "add", "-A", cwd=self.path)
        run("git", "commit", "-q", "-m", message, cwd=self.path)

    def transcript(self, skills=(), reads=()):
        path = os.path.join(self.path, ".transcript.jsonl")
        with open(path, "w") as f:
            for skill in skills:
                block = {"type": "tool_use", "name": "Skill", "input": {"skill": skill}}
                f.write(json.dumps({"message": {"content": [block]}}) + "\n")
            for read in reads:
                block = {"type": "tool_use", "name": "Read", "input": {"file_path": read}}
                f.write(json.dumps({"message": {"content": [block]}}) + "\n")
        return path


def hook(mode, event):
    result = subprocess.run(
        [sys.executable, HOOK, mode], input=json.dumps(event), capture_output=True, text=True, check=True
    )
    return json.loads(result.stdout) if result.stdout.strip() else None


def stop(repo, agent, transcript, active=False):
    return hook("stop", {
        "agent_type": agent, "cwd": repo.path,
        "agent_transcript_path": transcript, "stop_hook_active": active,
    })


class StopTest(unittest.TestCase):
    def setUp(self):
        self.repo = Repo()
        self.addCleanup(self.repo.dir.cleanup)

    def test_implementer_blocked_for_each_skill_its_changes_require(self):
        self.repo.write("Sources/Card.swift", SWIFTUI_VIEW)
        self.repo.write("Sources/Store.swift", ASYNC_MODEL)
        out = stop(self.repo, "dev-workflow:implementer", self.repo.transcript())
        self.assertEqual(out["decision"], "block")
        self.assertIn("`axiom-swiftui`, required by Sources/Card.swift", out["reason"])
        self.assertIn("`swift-concurrency`, required by Sources/Store.swift", out["reason"])
        self.assertIn("quick gate", out["reason"])

    def test_implementer_passes_once_skills_invoked_under_any_namespace(self):
        self.repo.write("Sources/Card.swift", SWIFTUI_VIEW)
        transcript = self.repo.transcript(skills=["macos-dev-workflow:axiom-swiftui"])
        self.assertIsNone(stop(self.repo, "dev-workflow:implementer", transcript))

    def test_reading_the_skill_file_counts_as_invoking_it(self):
        self.repo.write("Tests/AddTests.swift", SWIFT_TEST)
        transcript = self.repo.transcript(reads=["/x/.claude/skills/swift-testing-pro/SKILL.md"])
        self.assertIsNone(stop(self.repo, "dev-workflow:implementer", transcript))

    def test_only_missing_skills_are_named(self):
        self.repo.write("Sources/Card.swift", SWIFTUI_VIEW)
        self.repo.write("Tests/AddTests.swift", SWIFT_TEST)
        out = stop(self.repo, "dev-workflow:implementer", self.repo.transcript(skills=["axiom-swiftui"]))
        self.assertNotIn("axiom-swiftui", out["reason"])
        self.assertIn("swift-testing-pro", out["reason"])

    def test_blocks_only_once(self):
        self.repo.write("Sources/Card.swift", SWIFTUI_VIEW)
        self.assertIsNone(stop(self.repo, "dev-workflow:implementer", self.repo.transcript(), active=True))

    def test_changes_needing_no_skill_pass(self):
        self.repo.write("Sources/Other.swift", PLAIN)
        self.repo.write("README.md", "import SwiftUI\n")
        self.assertIsNone(stop(self.repo, "dev-workflow:implementer", self.repo.transcript()))

    def test_implementer_ignores_files_committed_by_earlier_slices(self):
        run("git", "switch", "-q", "-c", "feature/x", cwd=self.repo.path)
        self.repo.write("Sources/Card.swift", SWIFTUI_VIEW)
        self.repo.commit("slice 1")
        self.assertIsNone(stop(self.repo, "dev-workflow:implementer", self.repo.transcript()))

    def test_reviewer_checked_against_whole_branch_diff(self):
        run("git", "switch", "-q", "-c", "feature/x", cwd=self.repo.path)
        self.repo.write("Sources/Card.swift", SWIFTUI_VIEW)
        self.repo.commit("slice 1")
        out = stop(self.repo, "dev-workflow:implementation-standards-reviewer", self.repo.transcript())
        self.assertEqual(out["decision"], "block")
        self.assertIn("axiom-swiftui", out["reason"])
        self.assertIn("new findings", out["reason"])

    def test_path_rules_apply_to_non_swift_files(self):
        self.repo.write("App/App.entitlements", "<plist/>")
        out = stop(self.repo, "dev-workflow:implementer", self.repo.transcript())
        self.assertIn("axiom-macos", out["reason"])

    def test_other_agents_never_blocked(self):
        self.repo.write("Sources/Card.swift", SWIFTUI_VIEW)
        self.assertIsNone(stop(self.repo, "dev-workflow:planner", self.repo.transcript()))

    def test_broken_input_never_blocks(self):
        result = subprocess.run([sys.executable, HOOK, "stop"], input="not json", capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")


class StartTest(unittest.TestCase):
    def test_swift_repo_gets_role_specific_context(self):
        repo = Repo()
        self.addCleanup(repo.dir.cleanup)
        writer = hook("start", {"agent_type": "dev-workflow:implementer", "cwd": repo.path})
        reviewer = hook("start", {"agent_type": "dev-workflow:implementation-standards-reviewer", "cwd": repo.path})
        planner = hook("start", {"agent_type": "dev-workflow:planner", "cwd": repo.path})
        self.assertIn("Before you write code", writer["hookSpecificOutput"]["additionalContext"])
        self.assertIn("Before you review", reviewer["hookSpecificOutput"]["additionalContext"])
        self.assertIn("name a slice's skills", planner["hookSpecificOutput"]["additionalContext"])
        self.assertIn("`axiom-swiftui`", writer["hookSpecificOutput"]["additionalContext"])

    def test_non_swift_repo_and_unrelated_agents_get_nothing(self):
        repo = Repo()
        self.addCleanup(repo.dir.cleanup)
        self.assertIsNone(hook("start", {"agent_type": "dev-workflow:how-explorer", "cwd": repo.path}))
        with tempfile.TemporaryDirectory() as plain:
            run("git", "init", "-q", cwd=plain)
            self.assertIsNone(hook("start", {"agent_type": "dev-workflow:implementer", "cwd": plain}))


if __name__ == "__main__":
    unittest.main()
