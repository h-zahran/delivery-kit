#!/usr/bin/env bash
# Behaviour differential for handoff/hooks/context-guard.sh.
#
# Runs a BASELINE copy of the hook and the WORKING copy over the same payload
# and configuration shapes, comparing stdout and exit code on each. It exists
# because the hook's own suite cannot see every way a refactor can change
# behaviour: phase 14 shipped a change that passed all 163 tests and 3-OS CI
# while silently truncating a configuration value and, on another path, exiting
# without a word. Both were found here, not by the suite.
#
# Usage:
#   scripts/context-guard/differential.sh [<baseline-ref>]
#
#   <baseline-ref>  any git revision holding the hook to compare against.
#                   Default origin/main. PIN IT TO A COMMIT ID when the branch
#                   under test has already merged: this repository rebase-
#                   merges, so after a merge `origin/main` IS the change and
#                   the differential compares the hook with itself, reporting a
#                   flawless zero having tested nothing.
#
#   NEWHOOK=<path>  compare that file instead of the working copy. Used to
#                   point the differential at a deliberately broken hook and
#                   confirm it can still report a difference. RUN THAT CONTROL:
#                   a harness that has only ever printed zero differences has
#                   not been shown to be capable of printing anything else.
#
# Exit status is 0 only when every shape matched.
set -u

BASE=${1:-origin/main}
HOOK_PATH=handoff/hooks/context-guard.sh

cd "$(git rev-parse --show-toplevel)" || exit 9

root=${TMPDIR:-/tmp}/ctxdiff
rm -rf "$root"
mkdir -p "$root"
OLD="$root/old.sh"
NEW="$root/new.sh"

git show "$BASE:$HOOK_PATH" > "$OLD" || {
  printf 'differential: cannot read %s from %s\n' "$HOOK_PATH" "$BASE" >&2
  exit 9
}
cp "${NEWHOOK:-$HOOK_PATH}" "$NEW" || exit 9

# A baseline identical to the candidate is almost always a mistake — a stale
# ref, or a branch already merged — and it produces the most reassuring output
# this script can print. Say so rather than reporting a perfect score.
if cmp -s "$OLD" "$NEW"; then
  printf 'differential: %s and the candidate are IDENTICAL — nothing to compare.\n' "$BASE" >&2
  printf 'differential: pin <baseline-ref> to the commit BEFORE the change.\n' >&2
  exit 9
fi

n=0
same=0
diffn=0

# run_shape <label> <payload-json> <config-json-or-empty>
#
# Each side gets its own HOME, TMPDIR, TEMP and TMP, and that is load bearing
# rather than tidy. The guard writes a once-per-5%-bucket flag to
# $TMPDIR/ctx-warned-<session>, NOT under HOME. Isolate only HOME and the
# baseline fires first, leaves the flag, and silences the candidate — which
# reports as "old speaks, new is silent" on every shape that fires. Measured:
# that mistake reported 7 of 30 shapes different on a hook that was correct.
run_shape() {
  label=$1
  payload=$2
  cfg=$3
  n=$((n + 1))
  for which in old new; do
    d="$root/s$n/$which"
    mkdir -p "$d/home" "$d/work" "$d/tmp"
    : > "$d/t.jsonl"
    i=0
    while [ "$i" -lt 6 ]; do
      printf '{"message":{"usage":{"input_tokens":90000,"cache_read_input_tokens":90000,"output_tokens":10}}}\n' >> "$d/t.jsonl"
      i=$((i + 1))
    done
    if [ -n "$cfg" ]; then
      printf '%s' "$cfg" > "$d/home/.delivery-kit.json"
    fi
    hook=$OLD
    if [ "$which" = new ]; then hook=$NEW; fi
    # The placeholders are substituted per side so each reads its own copy of
    # the transcript and its own working directory.
    p=$(printf '%s' "$payload" | sed "s|%TRANSCRIPT%|$d/t.jsonl|; s|%CWD%|$d/work|")
    printf '%s' "$p" | env HOME="$d/home" TMPDIR="$d/tmp" TEMP="$d/tmp" TMP="$d/tmp" \
      bash "$hook" > "$d/out" 2>"$d/err"
    printf '%s' "$?" > "$d/rc"
  done
  o="$root/s$n/old"
  w="$root/s$n/new"
  if cmp -s "$o/out" "$w/out" && cmp -s "$o/rc" "$w/rc"; then
    same=$((same + 1))
    printf '  ok   %-44s rc=%s\n' "$label" "$(cat "$o/rc")"
  else
    diffn=$((diffn + 1))
    printf '  DIFF %-44s old_rc=%s new_rc=%s\n' "$label" "$(cat "$o/rc")" "$(cat "$w/rc")"
    printf '       --- baseline stdout ---\n'
    sed 's/^/       /' "$o/out" | head -6
    printf '       --- candidate stdout ---\n'
    sed 's/^/       /' "$w/out" | head -6
  fi
}

P_MAIN='{"transcript_path":"%TRANSCRIPT%","session_id":"s1","cwd":"%CWD%"}'
C_OK='{"contextGuard":{"windowTokens":1000000,"thresholdPct":50,"maxBytes":9000000}}'

printf '== payload shapes ==\n'
run_shape "ordinary main session" "$P_MAIN" ""
run_shape "subagent (agent_id present)" '{"agent_id":"a1","transcript_path":"%TRANSCRIPT%","session_id":"s1","cwd":"%CWD%"}' ""
run_shape "agent_id empty string" '{"agent_id":"","transcript_path":"%TRANSCRIPT%","session_id":"s1","cwd":"%CWD%"}' ""
run_shape "agent_id null" '{"agent_id":null,"transcript_path":"%TRANSCRIPT%","session_id":"s1","cwd":"%CWD%"}' ""
run_shape "session_id absent" '{"transcript_path":"%TRANSCRIPT%","cwd":"%CWD%"}' ""
run_shape "session_id null" '{"transcript_path":"%TRANSCRIPT%","session_id":null,"cwd":"%CWD%"}' ""
run_shape "cwd absent" '{"transcript_path":"%TRANSCRIPT%","session_id":"s1"}' ""
# An object where a string is expected: this is the shape that made an earlier
# payload program exit 5, leaving the guard silent. Keep it.
run_shape "cwd is an object" '{"transcript_path":"%TRANSCRIPT%","session_id":"s1","cwd":{"a":1}}' ""
run_shape "cwd is a number" '{"transcript_path":"%TRANSCRIPT%","session_id":"s1","cwd":42}' ""
run_shape "session_id is a boolean" '{"transcript_path":"%TRANSCRIPT%","session_id":true,"cwd":"%CWD%"}' ""
run_shape "transcript missing on disk" '{"transcript_path":"/no/such/file.jsonl","session_id":"s1","cwd":"%CWD%"}' ""
run_shape "transcript_path empty" '{"transcript_path":"","session_id":"s1","cwd":"%CWD%"}' ""
run_shape "empty JSON object" '{}' ""
run_shape "empty payload" '' ""
run_shape "malformed JSON" '{not json' ""
# A JSON string value may legally contain a newline. This is the shape that a
# splitter built on `read` truncates, dropping every field after it.
run_shape "session_id containing a newline" '{"transcript_path":"%TRANSCRIPT%","session_id":"a\nb","cwd":"%CWD%"}' ""

printf '== configuration shapes ==\n'
run_shape "config: ordinary" "$P_MAIN" "$C_OK"
run_shape "config: windowTokens with a newline" "$P_MAIN" '{"contextGuard":{"windowTokens":"5\n999999","thresholdPct":50,"maxBytes":9000000}}'
run_shape "config: leading zero" "$P_MAIN" '{"contextGuard":{"windowTokens":"0123456","thresholdPct":50}}'
run_shape "config: string numbers" "$P_MAIN" '{"contextGuard":{"windowTokens":"1000000","thresholdPct":"50"}}'
run_shape "config: thresholdPct out of range" "$P_MAIN" '{"contextGuard":{"windowTokens":1000000,"thresholdPct":150}}'
run_shape "config: thresholdPct zero" "$P_MAIN" '{"contextGuard":{"windowTokens":1000000,"thresholdPct":0}}'
run_shape "config: nulls throughout" "$P_MAIN" '{"contextGuard":{"windowTokens":null,"thresholdPct":null,"thresholdTokens":null,"maxBytes":null}}'
run_shape "config: booleans" "$P_MAIN" '{"contextGuard":{"windowTokens":true,"thresholdPct":false}}'
run_shape "config: empty contextGuard" "$P_MAIN" '{"contextGuard":{}}'
run_shape "config: no contextGuard key" "$P_MAIN" '{"other":1}'
run_shape "config: malformed JSON" "$P_MAIN" '{nope'
run_shape "config: thresholdTokens only" "$P_MAIN" '{"contextGuard":{"thresholdTokens":650000}}'
run_shape "config: maxBytes tiny" "$P_MAIN" '{"contextGuard":{"windowTokens":1000000,"maxBytes":1}}'
run_shape "config: negative window" "$P_MAIN" '{"contextGuard":{"windowTokens":-5}}'

printf '\nbaseline: %s\n' "$BASE"
printf 'SHAPES: %s   IDENTICAL: %s   DIFFERENT: %s\n' "$n" "$same" "$diffn"
[ "$diffn" -eq 0 ]
