#!/usr/bin/env bash
# A run waiting at K whose state file is committed to the branch: a state
# file that travels with the repository may carry answers nobody at this
# keyboard gave. The resume must stop, name the tracked state file and show
# the recorded answers, and use none of them, --auto or not.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=../lib/build-run.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/build-run.sh"
git add -f .delivery-kit/runs/001-greeting/progress.json
git commit -qm "chore: keep the run state"
