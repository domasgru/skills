#!/usr/bin/env python3
"""Builds a small split-layout plan and an older inline one, and checks plan.py's commands against them."""
import os, shutil, subprocess, sys, tempfile

H = os.path.dirname(os.path.abspath(__file__))
ROOT = tempfile.mkdtemp(prefix="plantest-")
D = os.path.join(ROOT, "plans", "007-demo")
os.makedirs(D + "/slices")
os.makedirs(D + "/.temp/architect/rounds")
w = lambda p, s: open(os.path.join(D, p), "w").write(s)
r = lambda p: open(os.path.join(D, p)).read()

w("plan.md", "# Plan: Demo\n\n## Requirements\n\n### R1. Lists items\nMUST list.\n\n### R2. Sorts items\nMUST sort.\n\n"
  "### R3. Survives restart\nMUST survive.\n\n## Non-goals\nNone.\n\n## Plan files\n- design.md\n")
w("design.md", "## Design\n\n### Problem\nP.\n\n### Shape\nS.\n\n#### Type sketch: Lister\n```\nstruct Lister {}\n```\n\n"
  "#### Type sketch: Sorter\n```\nstruct Sorter {}\n```\n\n### Open questions and risks\nNone.\n")
w("testing.md", "## Testing Decisions\n\n### Strategy\nOne seam.\n\n### Test scenarios\n\n"
  "| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |\n"
  "|----|--------------|------|---------------------|----------------------------------------|\n"
  "| T1 | R1 | E | Given two items, when listed, then both show | R1 |\n"
  "| T2 | R2 | E | Given b and a, when listed, then a before b | R2 |\n\n"
  "### Verified without a test\n- R3: a manual relaunch, steps 1 to 3.\n")
w("slices/S1.md", "# S1: Lists and sorts\n\n**What to build:** the list.\n\n**Blocked by:** None (can start immediately).\n\n"
  "**Requirements:** R1, R2, R3\n\n**Test scenarios:** T1, T2\n\n**Design sections:** Type sketch: Lister; Type sketch: Sorter\n\n"
  "**Skills:**\n- invoke `swift-testing-pro`: the suites for T1 and T2; references: core-rules.md\n"
  "- covered `swift-concurrency`: by design.md#Shape, the Lister is main-actor only\n\n- [ ] T1 and T2 green\n")
w(".temp/architect/rounds/findings-1.md", "### P1.1 R2 has no seam\n### P1.2 wording\n")
w(".temp/architect/rounds/verify-0.md", "### V0.1 usage disagrees with sketch\n")
w(".temp/architect/rounds/round-1.md", "- P1.1: accepted — Shape\n- V0.1: rejected — the usage is right\n")


def run(*args):
    p = subprocess.run([sys.executable, "-I", os.path.join(H, "plan.py"), *args], capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


fails = []


def expect(name, cond, out=""):
    print(("ok   " if cond else "FAIL ") + name)
    if not cond:
        print(out)
        fails.append(name)


rc, out = run("check", D)
expect("check: finds the one unfated finding", rc == 1 and "finding P1.2" in out and out.count("ERROR") == 1, out)
w(".temp/architect/rounds/round-1.md", "- P1.1: accepted — Shape\n- P1.2: escalated — Q1\n- V0.1: rejected — the usage is right\n")
rc, out = run("check", D)
expect("check: passes once every finding has a fate", rc == 0 and "layout: split" in out, out)
rc, out = run("slice", D, "S1", "--out", D + "/.temp/slices/S1-read.md")
rs = r(".temp/slices/S1-read.md")
expect("slice: read set holds the slice, its rows, its check and both design sections",
       "| T2 |" in rs and "R3: a manual relaunch" in rs and "struct Lister" in rs and "struct Sorter" in rs and "Open questions" not in rs, rs)
rc, out = run("skills", D)
expect("skills: invoke and covered per slice", "swift-testing-pro [invoke]" in out and "swift-concurrency [covered]" in out, out)
rc, out = run("slices", D)
expect("slices: one line with the invoke list", "invoke: swift-testing-pro" in out, out)
w("slices/S1.md", r("slices/S1.md").replace("**Requirements:** R1, R2, R3", "**Requirements:** R1, R2"))
rc, out = run("check", D)
expect("check: a requirement no slice delivers is an error", rc == 1 and "R3: no slice delivers it" in out, out)
w("slices/S1.md", r("slices/S1.md").replace("**Requirements:** R1, R2", "**Requirements:** R1 to R3"))
rc, out = run("check", D)
expect("check: a range 'R1 to R3' covers R2 and R3", rc == 0, out)

w(".temp/architect/rounds/findings-3.md", "### P3.1 still open\n")
w(".temp/architect/rounds/final.md", "- P3.1: escalated — Q1\n")
rc, out = run("check", D)
expect("check: a fate in final.md counts", rc == 0, out)

w("design.md", r("design.md").replace("#### Type sketch: Lister", "#### Type sketch: `Lister`"))
rc, out = run("check", D)
expect("check: a heading with backticks matches the plain name", rc == 0, out)

w("slices/S1.md", r("slices/S1.md").replace("Type sketch: Sorter", "Type sketch: Sorter2"))
rc, out = run("check", D)
expect("check: a design section the design lacks is an error", rc == 1 and "Sorter2" in out, out)
w("slices/S1.md", r("slices/S1.md").replace("Type sketch: Sorter2", "Type sketch: Sorter"))

big = r("design.md") + "x " * 60000
w("design.md", big)
rc, out = run("check", D)
expect("check: a large design is not an error", rc == 0, out)
rc, out = run("size", D + "/design.md")
expect("size: estimates tokens", rc == 0 and int(out.split()[0]) > 40000, out)

# an older, inline plan
I = os.path.join(ROOT, "plans", "001-old")
os.makedirs(I)
open(I + "/plan.md", "w").write(
    "# Plan: Old\n\n## Requirements\n\n### R1. Lists\nMUST.\n\n### R2. Sorts\nMUST.\n\n"
    "## Design\n\n### Shape\n\n#### Lister\n" + "type sketch line\n" * 400 + "\n"
    "## Testing Decisions\n\n### Test scenarios\n\n| ID | Requirements | Seam | Given / When / Then | Source |\n|---|---|---|---|---|\n"
    "| T1 | R1-R2 | E | lists and sorts | R1 |\n\n### Verified without a test\nNone.\n\n"
    "## Slices\n\n### S1: Everything\n\n**What to build:** all.\n\n**Blocked by:** None.\n\n**Requirements:** R1, R2\n\n"
    "**Test scenarios:** T1\n\n- [ ] green\n")
rc, out = run("check", I)
expect("inline: a missing Skills list is a warning, not an error", rc == 0 and "warn   S1: no **Skills:**" in out, out)
rc, out = run("slice", I, "S1", "--out", I + "/.temp/S1.md")
rs = open(I + "/.temp/S1.md").read()
expect("inline: the read set carries the design outline", "## Design outline" in rs and "#### Lister" in rs, rs[:400])
rc, out = run("split", I)
rc2, out2 = run("check", I)
expect("split: converts an inline plan; coverage still holds",
       os.path.exists(I + "/design.md") and os.path.exists(I + "/slices/S1.md") and "## Design" not in open(I + "/plan.md").read()
       and "layout: split" in out2 and "no test row" not in out2, out + out2)

shutil.rmtree(ROOT, ignore_errors=True)
print("all passed" if not fails else f"{len(fails)} failed")
sys.exit(1 if fails else 0)
