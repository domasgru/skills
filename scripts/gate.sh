#!/usr/bin/env bash
# The repo's full gate: validates the marketplace and every plugin, then runs the script and hook tests. The final line says "all green" only when every step passed.
# usage: bash scripts/gate.sh
set -euo pipefail
cd "$(dirname "$0")/.."

claude plugin validate . --strict
for plugin in plugins/*/; do
    (cd "$plugin" && claude plugin validate . --strict)
done
bash plugins/dev-workflow/skills/worktree/test-worktree.sh
bash plugins/macos-dev-workflow/hooks/test-block-unlocked-ui-tests.sh
python3 plugins/macos-dev-workflow/hooks/test_swift_skills.py

echo "gate: all green"
