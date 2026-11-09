#!/usr/bin/env bash
# A run waiting at K, plus one untracked file outside codeRoots ("src"), the
# spec folder and tasks.md. --auto collapses K only when no such path exists,
# so K must stop, name notes/scratch.txt, and commit nothing.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=../lib/build-run.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/build-run.sh"
mkdir -p notes
printf 'my notes, not part of the feature\n' > notes/scratch.txt
