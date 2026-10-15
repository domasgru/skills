#!/usr/bin/env python3
"""Read and check a feature plan under plans/<NNN-slug>/ without loading it whole.

Layouts:
  split  - plan.md (requirements, then a ## Plan files index), design.md, testing.md, slices/S<N>.md
  inline - the older single plan.md holding ## Design (or ## Implementation Decisions),
           ## Testing Decisions and ## Slices. Read the same way, so plans in flight keep working.

Commands:
  plan.py check  <dir>                  coverage, each slice's Skills list and design sections, and the
                                        round ledgers; exit 1 on an error
  plan.py slices <dir>                  one line per slice, for the orchestrator
  plan.py slice  <dir> S<N> --out FILE  writes the slice's read set (the slice, its test rows, its checks,
                                        the design sections it names) to FILE and prints the path and its size
  plan.py skills <dir>                  installed skills named per slice: skill -> invoke/covered -> slices
  plan.py size   <file>...              estimated tokens per file
  plan.py cat    <dir>                  the whole plan in reading order, for a human who wants one document
  plan.py split  <dir>                  converts an inline plan to the split layout (only to revise an older plan)

Python 3 standard library only. Token counts are estimates at CHARS_PER_TOKEN, measured on a 287 KB plan
that the API counted at about 114k tokens.
"""
import os, re, sys

CHARS_PER_TOKEN = 2.5
NOTES = "\n## Implementation notes"


def tok(text):
    return int(len(text) / CHARS_PER_TOKEN)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def norm(heading):
    """Compare headings without markup: backticks, emphasis, trailing colons, case."""
    return re.sub(r"[`*_]", "", heading).strip().rstrip(":").strip().lower()


def r_refs(text):
    """Every R<N> a text cites, ranges included: 'R28 to R38', 'R28-R38', 'R28–R38'."""
    out = set(re.findall(r"\bR(\d+)\b", text))
    for a, b in re.findall(r"\bR(\d+)\s*(?:to|–|—|-|\.\.)\s*R(\d+)\b", text):
        if int(a) <= int(b) <= int(a) + 200:
            out |= {str(i) for i in range(int(a), int(b) + 1)}
    return {"R" + n for n in out}


def sections(text, level):
    """Split text on headings of exactly `level` #'s: [(heading, body_with_heading)]."""
    pat = re.compile(r"^(#{%d}) (.+)$" % level, re.M)
    out = []
    for m in pat.finditer(text):
        nxt = re.compile(r"^#{1,%d} " % level, re.M).search(text, m.end())
        out.append((m.group(2).strip(), text[m.start():nxt.start() if nxt else len(text)]))
    return out


def section(text, level, name_prefix):
    for h, body in sections(text, level):
        if norm(h).startswith(name_prefix.lower()):
            return body
    return ""


class Plan:
    def __init__(self, d):
        self.dir = d.rstrip("/")
        self.plan = read(os.path.join(self.dir, "plan.md"))
        self.split = os.path.exists(os.path.join(self.dir, "design.md"))
        if self.split:
            self.design = read(os.path.join(self.dir, "design.md"))
            tp = os.path.join(self.dir, "testing.md")
            self.testing = read(tp) if os.path.exists(tp) else ""
            sd = os.path.join(self.dir, "slices")
            names = sorted((n for n in os.listdir(sd) if re.fullmatch(r"S\d+\.md", n)),
                           key=lambda n: int(n[1:-3])) if os.path.isdir(sd) else []
            self.slices = {n[:-3]: read(os.path.join(sd, n)) for n in names}
            cut = self.plan.find("\n## Plan files")
            self.requirements = self.plan if cut < 0 else self.plan[:cut]
        else:
            self.design = section(self.plan, 2, "design") or section(self.plan, 2, "implementation decisions")
            self.testing = section(self.plan, 2, "testing decisions")
            self.slices = {}
            for h, body in sections(section(self.plan, 2, "slices"), 3):
                m = re.match(r"(S\d+)\b", h)
                if m:
                    self.slices[m.group(1)] = body
            cuts = [i for i in (self.plan.find("\n## Design"), self.plan.find("\n## Implementation Decisions")) if i >= 0]
            self.requirements = self.plan[:min(cuts)] if cuts else self.plan

    # --- parsed facts -------------------------------------------------------------------------
    def r_ids(self):
        return re.findall(r"^### (R\d+)\.", self.requirements, re.M)

    def rows(self):
        """T id -> (requirement ids, the row's line)."""
        out = {}
        for line in self.testing.splitlines():
            m = re.match(r"^\|\s*(T\d+)\s*\|([^|]*)\|", line)
            if m:
                out[m.group(1)] = (r_refs(m.group(2)), line)
        return out

    def verified(self):
        v = section(self.testing, 3, "verified without a test")
        return r_refs(v), v

    @staticmethod
    def plan_part(slice_text):
        i = slice_text.find(NOTES)
        return slice_text if i < 0 else slice_text[:i]

    @staticmethod
    def field(body, name):
        m = re.search(r"\*\*%s:\*\*(.*?)(?=\n\*\*[A-Z][^*]*:\*\*|\n- \[|\n#|\Z)" % re.escape(name), body, re.S)
        return m.group(1).strip() if m else None

    def slice_facts(self, sid):
        b = self.plan_part(self.slices[sid])
        names = self.field(b, "Design sections")
        blocked = self.field(b, "Blocked by")
        return dict(
            reqs=r_refs(self.field(b, "Requirements") or ""),
            rows=re.findall(r"\bT\d+\b", self.field(b, "Test scenarios") or ""),
            design_sections=[s.strip(" -") for s in re.split(r"[;\n]", names) if s.strip(" -")] if names else None,
            skills=self.field(b, "Skills"),
            blocked=blocked.splitlines()[0] if blocked else "",
            title=b.splitlines()[0].lstrip("# ").strip(),
        )

    def design_section(self, heading):
        for lvl in (2, 3, 4, 5):
            for h, body in sections(self.design, lvl):
                if norm(h) == norm(heading):
                    return body
        return None

    def outline(self):
        return "\n".join(l for l in self.design.splitlines() if re.match(r"^#{2,5} ", l))

    def read_set(self, sid):
        f = self.slice_facts(sid)
        rows = self.rows()
        _, vtext = self.verified()
        parts = [self.slices[sid].rstrip() + "\n"]
        header = [l for l in self.testing.splitlines() if l.startswith("| ID ") or re.match(r"^\|-", l)][:2]
        parts.append("\n## Test rows of this slice\n\n" + "\n".join(header + [rows[t][1] for t in f["rows"] if t in rows]) + "\n")
        vlines = [l for l in vtext.splitlines() if r_refs(l) & f["reqs"]]
        if vlines:
            parts.append("\n## Checks without a test for this slice's requirements\n\n" + "\n".join(vlines) + "\n")
        missing = []
        if f["design_sections"] is None:
            where = "design.md" if self.split else "the ## Design section of plan.md"
            parts.append(f"\n## Design outline\n\nThis slice names no design sections. Read the sections of {where} "
                         "that hold the types and signatures it builds:\n\n" + self.outline() + "\n")
        else:
            parts.append("\n## Design sections this slice builds\n")
            for h in f["design_sections"]:
                body = self.design_section(h)
                if body is None:
                    missing.append(h)
                else:
                    parts.append("\n" + body.rstrip() + "\n")
        return "".join(parts), missing

    # --- checks -------------------------------------------------------------------------------
    def check(self):
        errors, warnings = [], []
        rs, rows = self.r_ids(), self.rows()
        vset, _ = self.verified()
        in_rows = set().union(*[r for r, _ in rows.values()]) if rows else set()
        for r in rs:
            if r not in in_rows and r not in vset:
                errors.append(f"{r}: no test row and no check without a test")
        in_slices, t_in_slices = set(), {}
        for sid in self.slices:
            f = self.slice_facts(sid)
            in_slices |= f["reqs"]
            for t in f["rows"]:
                t_in_slices.setdefault(t, []).append(sid)
                if t not in rows:
                    errors.append(f"{sid}: names {t}, which is not in the test table")
            if f["skills"] is None:
                (errors if self.split else warnings).append(f"{sid}: no **Skills:** list")
            for h in f["design_sections"] or []:
                if self.design_section(h) is None:
                    errors.append(f"{sid}: names design section '{h}', which the design does not have")
        for r in rs:
            if r not in in_slices:
                errors.append(f"{r}: no slice delivers it")
        for t in rows:
            if t not in t_in_slices:
                errors.append(f"{t}: belongs to no slice")
        errors += self.check_rounds()
        return errors, warnings

    def check_rounds(self):
        """Every finding a verifier or test-planner pass raised has a fate in some ledger in rounds/."""
        rd = os.path.join(self.dir, ".temp", "architect", "rounds")
        if not os.path.isdir(rd):
            return []
        raised, fated = set(), set()
        for n in sorted(os.listdir(rd)):
            t = read(os.path.join(rd, n))
            if n.startswith(("findings-", "verify")):
                raised |= set(re.findall(r"^### ((?:V\d+\.|P\d+\.)\d+|V\d+)\b", t, re.M))
            else:
                fated |= set(re.findall(r"^- ((?:V\d+\.|P\d+\.)\d+|V\d+): (?:accepted|rejected|escalated)", t, re.M))
        return [f"finding {f}: raised but has no accepted/rejected/escalated line in a ledger"
                for f in sorted(raised - fated)]

    # --- conversion ---------------------------------------------------------------------------
    def to_split(self):
        if self.split:
            return "already split"
        design = self.design.strip() + "\n"
        testing = self.testing.strip() + "\n"
        sd = os.path.join(self.dir, "slices")
        os.makedirs(sd, exist_ok=True)
        for sid, body in self.slices.items():
            with open(os.path.join(sd, sid + ".md"), "w", encoding="utf-8") as f:
                f.write(re.sub(r"^### ", "# ", body.strip(), count=1) + "\n")
        for name, text in (("design.md", design), ("testing.md", testing)):
            with open(os.path.join(self.dir, name), "w", encoding="utf-8") as f:
                f.write(text)
        rest = self.plan
        for sec in (self.design, self.testing, section(self.plan, 2, "slices")):
            if sec:
                rest = rest.replace(sec, "")
        index = ("\n## Plan files\n\n- `design.md`: the design\n- `testing.md`: the testing decisions\n"
                 + "".join(f"- `slices/{s}.md`\n" for s in self.slices))
        with open(os.path.join(self.dir, "plan.md"), "w", encoding="utf-8") as f:
            f.write(rest.rstrip() + "\n" + index)
        return f"split into design.md, testing.md and {len(self.slices)} slice files"


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    cmd, target = argv[1], argv[2]
    if cmd == "size":
        for p in argv[2:]:
            print(f"{tok(read(p)):>7}  {p}")
        return 0
    p = Plan(target)
    if cmd == "check":
        errors, warnings = p.check()
        print(f"layout: {'split' if p.split else 'inline (older plan)'}; requirements ~{tok(p.requirements)}, "
              f"design ~{tok(p.design)}, testing ~{tok(p.testing)} tokens; {len(p.slices)} slices")
        for e in errors:
            print("ERROR  " + e)
        for w in warnings:
            print("warn   " + w)
        print("ok" if not errors else f"{len(errors)} errors")
        return 1 if errors else 0
    if cmd == "slices":
        for sid in p.slices:
            f = p.slice_facts(sid)
            rs_text, _ = p.read_set(sid)
            inv = re.findall(r"invoke\s+`([^`]+)`", f["skills"] or "")
            print(f"{sid} | {f['title']} | blocked by: {f['blocked'] or '?'} | rows {len(f['rows'])} | "
                  f"read set ~{tok(rs_text)} | invoke: {', '.join(inv) or ('none' if f['skills'] else 'NOT LISTED')}")
        return 0
    if cmd == "slice":
        sid = argv[3]
        out = argv[argv.index("--out") + 1] if "--out" in argv else None
        text, missing = p.read_set(sid)
        if out:
            os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
            with open(out, "w", encoding="utf-8") as f:
                f.write(text)
            print(f"{out}  ~{tok(text)} tokens")
        else:
            sys.stdout.write(text)
        for m in missing:
            print(f"missing design section: {m}", file=sys.stderr)
        return 0
    if cmd == "skills":
        by = {}
        for sid in p.slices:
            for kind, name, rest in re.findall(r"^-\s*(invoke|covered)\s+`([^`]+)`(.*)$", p.slice_facts(sid)["skills"] or "", re.M):
                by.setdefault((name, kind), []).append(f"{sid}{rest}")
        for (name, kind), uses in sorted(by.items()):
            print(f"{name} [{kind}]")
            for u in uses:
                print(f"  {u}")
        return 0
    if cmd == "cat":
        parts = [p.plan] + ([p.design, p.testing] + list(p.slices.values()) if p.split else [])
        sys.stdout.write("\n\n".join(parts))
        return 0
    if cmd == "split":
        print(p.to_split())
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
