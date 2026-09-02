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

# mktemp, not a fixed name under a shared temporary directory. The old form was
# `rm -rf ${TMPDIR:-/tmp}/ctxdiff` followed by `mkdir -p`: `rm -rf` removes a
# top-level symbolic link rather than following it, so it was not a direct hit,
# but anything recreating that path as a link BETWEEN the two commands captures
# every write this script then makes.
root=$(mktemp -d) || exit 9
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
READING='{"message":{"usage":{"input_tokens":90000,"cache_read_input_tokens":90000,"output_tokens":10}}}'

# write_transcript <shape>
#
# Writes one transcript to STDOUT; the single caller redirects it into place.
# It used to take the path and carry a truncation step plus fifteen appends,
# which made every shape cost more to add than the one line that makes it
# different from its neighbours.
#
# The transcript used to be six identical readings, hardcoded inside run_shape,
# because every shape then varied the payload or the configuration and none
# varied the file being read. That stopped being true when the reading count,
# the median and the under-fifteen fallback moved into one program: the shapes
# that can now break are shapes OF THE TRANSCRIPT, and a harness that cannot
# vary it cannot see them.
#
# The fourteen and sixteen shapes sit either side of the floor of fifteen. Be
# exact about what that buys, because the obvious reading is wrong: WITHOUT A
# BYTE CAP THE FALLBACK IS A NO-OP. The capped read already holds the whole
# file, so the re-read returns the same readings and the same median whichever
# side of the floor the count lands. Measured: a mutant with the floor set to
# zero differs on the two BYTE-CAP shapes and on neither plain one.
#
# So the plain counts guard against a crash or a shape-table slip, and the
# byte-cap variants are what actually exercise the fallback. Both are kept;
# only the claim about them is corrected.
#
# Shapes are NAMED, never numbered, and that is a deliberate refusal of a
# shorter spelling. A numeric arm would make any future count free, and would
# also make `166` for `16` a silent 166-reading transcript instead of the hard
# stop the catch-all gives a misspelt word. This harness exists because silence
# is the failure mode that matters; it may not introduce one of its own to save
# four lines.
#
# An empty <shape> keeps the original six readings, so every payload and
# configuration shape below compares exactly what it compared before.
write_transcript() {
  shape=$1
  case "$shape" in
    '')       nread=6 ;;
    empty)    return 0 ;;
    one)      nread=1 ;;
    fourteen) nread=14 ;;
    fifteen)  nread=15 ;;
    sixteen)  nread=16 ;;
    malformed)
      printf '%s\n' "$READING" 'this line is not JSON at all' "$READING"
      return 0 ;;
    # A line that parses, but whose token count is not a number. jq reports an
    # error for that ONE input and carries on. Collect the same pipeline into an
    # array without the error-tolerant form and the error escapes the array,
    # killing the whole program: no readings at all, and a guard that says
    # nothing. This shape is the one that catches that.
    string-tokens)
      printf '%s\n' "$READING" '{"message":{"usage":{"input_tokens":"not-a-number"}}}' "$READING"
      return 0 ;;
    string-cache)
      printf '%s\n' "$READING" '{"message":{"usage":{"input_tokens":90000,"cache_read_input_tokens":"nope"}}}' "$READING"
      return 0 ;;
    # Every one of the three token fields a STRING. jq's `+` concatenates
    # strings, so this record does not error the way a single string field
    # does — it produces a string reading, and that is what makes it the one
    # shape where the old hook and the new one genuinely disagree.
    string-all-three)
      printf '%s\n' "$READING" '{"message":{"usage":{"input_tokens":"a","cache_read_input_tokens":"b","cache_creation_input_tokens":"c"}}}' "$READING"
      return 0 ;;
    sidechain)
      printf '%s\n' '{"isSidechain":true,"message":{"usage":{"input_tokens":999999}}}' "$READING" '{"isSidechain":true,"message":{"usage":{"input_tokens":999999}}}'
      return 0 ;;
    # A negative reading is skipped by a count that looks for a leading digit and
    # INCLUDED by the median, which sorts whatever it is handed. This shape shows
    # the median tolerates such a reading, and that is ALL it shows.
    #
    # THIS FILE CANNOT SEE THE COUNT RULE, and the comment here used to claim it
    # could. The reason is structural, not a gap to be filled with a cleverer
    # shape: the capped read is a byte SUFFIX of the transcript, so if it holds
    # fifteen or more readings its last fifteen IS the file's last fifteen and
    # the uncapped re-read returns the same median; and if it holds fewer under
    # either counting rule, both rules fall back. The count therefore decides
    # only whether a second jq is SPAWNED — never what the guard answers.
    #
    # Measured on a straddle of fourteen positive readings and one negative,
    # which is fifteen by `length` and fourteen by the digit rule: the shipped
    # hook spends 5 jq processes and a `length` mutant spends 4, and both emit an
    # IDENTICAL 556 bytes. Mutating the count reports 43 of 43 identical here.
    # The rule is pinned by the spawn-counting rig in
    # specs/015-guard-jq-spawn-two/quickstart.md, not by this harness.
    negative)
      printf '%s\n' "$READING" '{"message":{"usage":{"input_tokens":-5}}}' "$READING"
      return 0 ;;
    # Twenty readings, chosen so that three different medians come out of them:
    # the last fifteen give 114000, the FIRST fifteen give 104000, and all twenty
    # give 110000. Every one of the three is above the threshold, so all three
    # FIRE and the percentage is printed — which means a window that slipped is a
    # visible difference in stdout, not a silence that looks like agreement.
    #
    # An earlier version of this shape used five tiny readings and fifteen equal
    # ones. Every window over it yields the same median, so it could not tell a
    # correct window from a broken one. A shape that cannot fail is decoration.
    window)
      i=0
      while [ "$i" -lt 5 ]; do
        printf '{"message":{"usage":{"input_tokens":95000}}}\n'
        i=$((i + 1))
      done
      i=0
      while [ "$i" -lt 15 ]; do
        printf '{"message":{"usage":{"input_tokens":%d}}}\n' "$((100000 + i * 2000))"
        i=$((i + 1))
      done
      return 0 ;;
    *) printf 'differential: unknown transcript shape %s\n' "$shape" >&2; exit 9 ;;
  esac
  i=0
  while [ "$i" -lt "$nread" ]; do
    printf '%s\n' "$READING"
    i=$((i + 1))
  done
}

# run_shape <label> <payload-json> <config-json-or-empty> [<transcript-shape>] [same|diff]
#
# The fifth argument is an EXPECTATION, and it defaults to `same` so every
# shape written before it existed keeps its meaning. `diff` asserts the two
# sides DISAGREE, and fails when they agree.
#
# A harness with no way to say `diff` has only two options for a divergence it
# has decided to keep: leave the shape out, and lie by omission; or leave it
# in and stay permanently red, which trains a reader to skim past the one line
# that matters. An asserted difference is neither — it goes red if the
# divergence is ever quietly repaired, which is the direction nobody watches.
run_shape() {
  label=$1
  payload=$2
  cfg=$3
  # Unset, not empty, on every call site written before the transcript shapes
  # existed, so `set -u` needs the default here.
  tshape=${4:-}
  expect=${5:-same}
  n=$((n + 1))
  for which in old new; do
    d="$root/s$n/$which"
    mkdir -p "$d/home" "$d/work" "$d/tmp"
    write_transcript "$tshape" > "$d/t.jsonl"
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
  # Quoted so the analyser does not read it as an assignment from the diff
  # command, which is a real command and is on the path here.
  actual="diff"
  if cmp -s "$o/out" "$w/out" && cmp -s "$o/rc" "$w/rc"; then actual="same"; fi
  if [ "$actual" = "$expect" ]; then
    same=$((same + 1))
    if [ "$expect" = diff ]; then
      printf '  ok   %-44s DIFFERS, as asserted (old %s bytes, new %s bytes)\n' \
        "$label" "$(wc -c < "$o/out" | tr -d ' ')" "$(wc -c < "$w/out" | tr -d ' ')"
    else
      printf '  ok   %-44s rc=%s\n' "$label" "$(cat "$o/rc")"
    fi
  else
    diffn=$((diffn + 1))
    if [ "$expect" = diff ]; then
      printf '  SAME %-44s expected a DIFFERENCE and found none\n' "$label"
    else
      printf '  DIFF %-44s old_rc=%s new_rc=%s\n' "$label" "$(cat "$o/rc")" "$(cat "$w/rc")"
    fi
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
# Left at the DEFAULT window on purpose. This shape carried a windowTokens of
# 1000000 for as long as it existed, which puts the readings at 18% and below
# the threshold — so both sides said nothing, and two silences compare equal.
# It was the only shape here touching the fallback, and it could not have seen
# a fallback that stopped working. Same defect as the two transcript byte-cap
# shapes below, found when a floor-to-zero control passed 43 of 43.
run_shape "config: maxBytes tiny" "$P_MAIN" '{"contextGuard":{"maxBytes":1}}'
run_shape "config: negative window" "$P_MAIN" '{"contextGuard":{"windowTokens":-5}}'

printf '== transcript shapes ==\n'
run_shape "transcript: empty file"             "$P_MAIN" "" empty
run_shape "transcript: one reading"            "$P_MAIN" "" one
run_shape "transcript: fourteen readings"      "$P_MAIN" "" fourteen
run_shape "transcript: fifteen readings"       "$P_MAIN" "" fifteen
run_shape "transcript: sixteen readings"       "$P_MAIN" "" sixteen
run_shape "transcript: unparseable line"       "$P_MAIN" "" malformed
run_shape "transcript: non-numeric tokens"     "$P_MAIN" "" string-tokens
run_shape "transcript: non-numeric cache"      "$P_MAIN" "" string-cache
run_shape "transcript: sidechain entries"      "$P_MAIN" "" sidechain
# ASSERTED TO DIFFER, and the assertion is the record. On a usage record whose
# three token fields are all strings the old hook emitted the concatenation as
# a reading, its separate median call then failed to parse it, and the whole
# read collapsed to SILENCE. The new one drops the junk and answers from the
# readings around it. Measured: 0 bytes against 556. Not repaired, because the
# only way back to byte-identical here is back to a silent guard.
run_shape "transcript: all three fields strings" "$P_MAIN" "" string-all-three diff
run_shape "transcript: negative reading"       "$P_MAIN" "" negative
run_shape "transcript: median window matters"  "$P_MAIN" "" window
# The byte cap starves the capped read, so the uncapped re-read decides. This is
# the fallback path, reached the way a real session reaches it rather than by a
# transcript large enough to be impractical in a harness.
#
# THE WINDOW IS LEFT AT ITS DEFAULT ON PURPOSE, and that is load bearing. These
# two shapes first carried a windowTokens of 1000000, which puts the readings at
# 18% and the guard below its threshold. Both sides then said NOTHING, and two
# silences compare equal — so the shapes reported ok against a hook whose
# fallback had been disabled outright. Measured: the floor-to-zero control
# passed 43 of 43 until this line changed. A shape that cannot make the guard
# SPEAK cannot tell you it has stopped speaking.
run_shape "transcript: sixteen, byte cap of 1"  "$P_MAIN" '{"contextGuard":{"maxBytes":1}}' sixteen
run_shape "transcript: fourteen, byte cap of 1" "$P_MAIN" '{"contextGuard":{"maxBytes":1}}' fourteen

printf '\nbaseline: %s\n' "$BASE"
printf 'SHAPES: %s   IDENTICAL: %s   DIFFERENT: %s\n' "$n" "$same" "$diffn"
[ "$diffn" -eq 0 ]
