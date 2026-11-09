# skills

Claude Code plugins under `plugins/`. `plugins/dev-workflow/README.md` is the workflow they run.

- **Gate**: `scripts/gate.sh`. There is no hosted CI. It validates the plugins, whose skills and agents are what this repo ships, so a change to them runs it. It is both the quick gate and the full gate.
