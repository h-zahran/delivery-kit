#!/usr/bin/env bash
# check-suite.sh — the one verdict a feature quickstart needs on a saved run of
# the house suite: did exactly the expected number of tests run, and did every
# one of them pass?
#
#   bash scripts/check-suite.sh <expected> <tap-file>
#
# <tap-file> is the suite's saved output, stdout and stderr together. Exit 0
# prints one summary line; any other shape exits 1 with one line naming why.
#
# This file exists because every feature quickstart used to write its own copy
# of this check, and the copies drifted: only some of them counted skipped
# tests, so a skip read as a pass in the others. One implementation is the only
# arrangement that cannot drift; CONTRIBUTING.md tells a quickstart to call it.
#
# What a pass needs, and why each part is there:
#   - the plan line, `1..<expected>`, first — a count read without the plan
#     cannot see a test that was counted and never run;
#   - no second plan line — that is how a crashed or concatenated run looks;
#   - exactly <expected> `ok` lines, none of them a skip — bats prints a
#     skipped test as `ok … # skip`, so an ok count alone passes a skip — and
#     numbered 1 to <expected>, in any order;
#   - no `not ok`, and no line that is neither TAP nor a `#` comment.
#
# The rules themselves are NOT here. They live once, in the pipeline plugin's
# `progress.sh tap-check`, which the plugin's own suite-record also judges
# with: this file used to hold a second copy, and the two had already drifted
# (only one checked test numbers). The plugin cannot depend on a script that
# ships only with this repository, so the dependency runs this way: this file
# checks its own arguments (K2, K3) and hands the file to tap-check, passing
# the expected count. The other rows of
# specs/023-gate-reads-whole-changelog/contracts/check-suite.md (K4-K11) are
# tagged on their lines in progress.sh's TAP_AWK. CI's shard step, in
# .github/workflows/ci.yml, reads its own shards' TAP with checks of its own.
#
# Written for bash 3.2 as well as 5: macOS may run the system bash. No message
# prints the file's path, which can carry a user name and reach a public log;
# tap-check prints none either, and discards anything awk prints to stderr.
set -u

die() { printf 'check-suite.sh: %s\n' "$*" >&2; exit 1; }

if [ $# -ne 2 ] || ! [[ $1 =~ ^[1-9][0-9]*$ ]]; then die "usage: check-suite.sh <expected> <tap-file>, where <expected> is a positive integer"; fi  # K2
if [ ! -f "$2" ] || [ ! -r "$2" ]; then die "the TAP file does not exist or cannot be read"; fi  # K3

# progress.sh sits at a fixed place beside this file in the repository. It is
# run by the bash running this file, and tap-check needs no jq, so this file
# still needs only bash and awk.
here="${BASH_SOURCE[0]}"
case "$here" in */*) here="${here%/*}" ;; *) here=. ;; esac
prog="$here/../pipeline/scripts/progress.sh"
[ -f "$prog" ] || die "pipeline/scripts/progress.sh is not where this repository keeps it"

# Only an explicit pass passes: exit 0 AND the summary line. Anything else —
# a refusal, progress.sh failing to start, awk failing to read and tap-check
# saying so — is a refusal, never a silent exit 0. A refusal's own words are
# kept, without progress.sh's prefix.
out="$("${BASH:-bash}" "$prog" tap-check "$2" "$1" 2>&1)" && case "$out" in
  "suite ok: "*) printf '%s\n' "$out"; exit 0 ;;
esac
case "$out" in
  "progress.sh: "*) die "${out#progress.sh: }" ;;
esac
die "the TAP file cannot be read"
