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
#     skipped test as `ok … # skip`, so an ok count alone passes a skip;
#   - no `not ok`, and no line that is neither TAP nor a `#` comment.
#
# Each rule is ONE line ending `# K<n>` (the rows of
# specs/023-gate-reads-whole-changelog/contracts/check-suite.md). A tagged line
# holds only its refusal, so the quickstart can delete one rule at a time and
# require the suite's test of this file to go red naming that rule. Reading,
# classifying and counting sit on untagged lines for the same reason.
#
# Written for bash 3.2 as well as 5: macOS may run the system bash. No message
# prints the file's path, which can carry a user name and reach a public log.
set -u

die() { printf 'check-suite.sh: %s\n' "$*" >&2; exit 1; }

if [ $# -ne 2 ] || ! [[ $1 =~ ^[1-9][0-9]*$ ]]; then die "usage: check-suite.sh <expected> <tap-file>, where <expected> is a positive integer"; fi  # K2
if [ ! -f "$2" ]; then die "the TAP file does not exist"; fi  # K3

# One pass. The rules in END run in a fixed order and the first one broken is
# the one reported: a `not ok`, a skip or a stray line is named before the ok
# count it also shortens or leaves unchanged.
#
# BINMODE=3 makes GNU Awk on Windows read and write bytes as they are. Left
# in text mode it strips every CR itself, so the K11 line below did nothing
# there and could never be shown to matter — measured on Windows: deleting
# it left the suite's test of this file green. On Linux and macOS awk keeps
# the CR, so there the line was always needed. Other awks treat BINMODE as an
# unused variable. With it set, the CR strip is this script's own rule on
# every system.
verdict="$(awk -v BINMODE=3 -v e="$1" '
  { sub(/\r$/, "") }  # K11
  /^[[:space:]]*$/ { next }
  { n++ }
  n == 1 { first = $0 }
  /^1[.][.][0-9]+$/ { plans++; next }
  /^ok / { oks++; if (tolower($0) ~ /# skip/) skips++; next }
  /^not ok / { nots++; next }
  /^#/ { next }
  { stray++ }
  END {
    if (msg == "" && n == 0) msg = "the TAP file is empty"  # K4
    if (msg == "" && first != "1.." e) msg = "the first line is not the plan line 1.." e  # K5
    if (msg == "" && plans > 1) msg = "a second plan line: the run crashed or was concatenated"  # K6
    if (msg == "" && nots > 0) msg = nots " not ok"  # K9
    if (msg == "" && skips > 0) msg = skips " skipped, and a skip is not a pass"  # K8
    if (msg == "" && stray > 0) msg = stray " non-TAP line(s)"  # K10
    if (msg == "" && oks + 0 != e + 0) msg = "ok count " (oks + 0) ", expected " e  # K7
    if (msg == "") print "OK suite ok: 1.." e ", " (oks + 0) " ok, 0 skipped, 0 not ok, 0 non-TAP"
    else print "FAIL " msg
  }' "$2")"

case "$verdict" in
  "OK "*) printf '%s\n' "${verdict#OK }" ;;
  "FAIL "*) die "${verdict#FAIL }" ;;
  *) die "the TAP file could not be read" ;;
esac
