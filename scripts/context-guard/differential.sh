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
asserted=0
settled_n=0

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
    # The mirror of string-all-three: three string fields whose concatenation IS
    # parseable as a number. The old hook re-parsed it into a genuine reading and
    # inflated the median; the new one drops it. Where string-all-three turns a
    # silence into speech, this turns speech into silence — and both are
    # corrections. Two readings of 80000 make the true median 80000, at 40% of
    # the default window; the junk pushed it to 180000, at 90%.
    string-numeric)
      printf '%s\n' \
        '{"message":{"usage":{"input_tokens":80000}}}' \
        '{"message":{"usage":{"input_tokens":80000}}}' \
        '{"message":{"usage":{"input_tokens":"180000","cache_read_input_tokens":"","cache_creation_input_tokens":""}}}' \
        '{"message":{"usage":{"input_tokens":"180000","cache_read_input_tokens":"","cache_creation_input_tokens":""}}}' \
        '{"message":{"usage":{"input_tokens":"180000","cache_read_input_tokens":"","cache_creation_input_tokens":""}}}'
      return 0 ;;
    # Twenty real readings of 30000, then fifteen junk records whose three string
    # fields concatenate to "180000". Paired with a byte cap of 1650 — fifteen
    # junk lines at 110 bytes each — the capped read is junk and nothing else.
    #
    # This pins the COUNT, which the median shapes cannot. The old code counted
    # fifteen string readings, cleared the floor, skipped the fallback and
    # answered 180000; this counts none of them, falls back, and answers the true
    # 30000. If that record's byte length ever changes, the cap must change with
    # it or the shape silently stops starving the read.
    string-numeric-capped)
      i=0
      while [ "$i" -lt 20 ]; do
        printf '{"message":{"usage":{"input_tokens":30000}}}\n'
        i=$((i + 1))
      done
      i=0
      while [ "$i" -lt 15 ]; do
        printf '{"message":{"usage":{"input_tokens":"180000","cache_read_input_tokens":"","cache_creation_input_tokens":""}}}\n'
        i=$((i + 1))
      done
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
    # IDENTICAL 556 bytes. Mutating the count leaves every shape here as expected.
    # (The `junk alone under the byte cap` shape below is the one place the count
    # DOES reach the answer, and it reaches it through the fallback decision.)
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

# run_shape <label> <payload-json> <config-json-or-empty> [<transcript-shape>] [same|diff|diff@<commit>]
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
  expect=${5-same}
  # AN ASSERTED DIFFERENCE IS RELATIVE TO A BASELINE, and until now the
  # expectation could not say which. `diff` means "these two disagree", but the
  # two are the baseline and the working copy — so the moment the divergence
  # MERGES, the baseline acquires it, both sides agree, and a correct assertion
  # reports UNEXPECTED on a correct tree.
  #
  # Measured 2026-09-04: three shapes asserted `diff` for the one-pass reading
  # change reported "expected a DIFFERENCE and found none" against a baseline
  # that already contained that change. Nothing was wrong with the hook or with
  # the shapes; the assertions had simply outlived their baseline, and the
  # harness had no way to know. Left alone that is permanent red, which is the
  # failure the `diff` expectation was invented to avoid, arrived at from the
  # other side.
  #
  # So an assertion may name the commit that INTRODUCED its divergence:
  # `diff@<commit>`. If the baseline already contains that commit the divergence
  # is settled history and the two sides SHOULD agree, so the expectation
  # becomes `same`; if it does not, the divergence is still ahead of the
  # baseline and `diff` stands. One assertion, correct on both sides of its own
  # merge, with no edit required when it lands.
  settled=""
  case "$expect" in
    same|diff) ;;
    diff@?*)
      since=${expect#diff@}
      # AN ANCHOR MUST BE A COMMIT ID, NOT A REF. Lowercase hex is not merely
      # the stricter choice — it is exactly what the documented count command in
      # this file's header, and its twin in handoff/hooks/context-guard.sh,
      # already match. Accepting more than the counter can see is how a shape
      # goes missing from a total without anyone being told.
      #
      # A ref passes every check below: it resolves, it is reachable, and it is
      # an ancestor of any baseline at or after it — so it relaxes its own
      # assertion permanently, and the shape stops testing anything. Measured
      # 2026-09-04: HEAD, main, origin/main, HEAD~1 and a bare at-sign all
      # resolve, are all reachable, and all relax. The bare at-sign is one
      # keystroke from the empty anchor and git reads it as HEAD.
      case "$since" in
        *[!0-9a-f]*)
          printf 'differential: anchor %s is not a commit id; a ref moves and would relax this assertion for ever\n' "$since" >&2
          exit 9 ;;
      esac
      # Seven is git's own minimum abbreviation, and an id shorter than that can
      # match more than one object as the repository grows.
      [ "${#since}" -ge 7 ] || {
        printf 'differential: anchor %s is too short to be an unambiguous commit id\n' "$since" >&2
        exit 9
      }
      # AN ANCHOR MUST RESOLVE, AND IT MUST BE REACHABLE, and neither failure
      # may be silent. `--is-ancestor` answers 1 for "no" and 128 for "I could
      # not tell"; folding 128 into the `else` turns a typo into a plain `diff`
      # that reads as anchored and is not. Measured 2026-09-04: a bogus id and
      # an empty id both return 128.
      git rev-parse --verify --quiet "$since^{commit}" >/dev/null 2>&1 || {
        printf 'differential: the anchor in expectation %s does not resolve to a commit\n' "$expect" >&2
        exit 9
      }
      # RESOLVING IS NOT ENOUGH, and this is the trap that matters here. This
      # repository REBASE-merges, so the id a branch carries is not the id that
      # lands. Measured 2026-09-04: `9148066` and `f495823` have identical
      # trees, and only the second is an ancestor of `main` — yet the first
      # still RESOLVES, because it survives in the reflog until gc. rev-parse
      # alone would therefore admit a pre-rebase orphan, and the ancestry test
      # below would answer "no" for ever while a comment beside the call
      # claimed the shape was anchored. Reachability from some ref is what
      # distinguishes them: measured, `branch -a --contains` prints nothing for
      # the orphan and `main` for the id that landed.
      #
      # THE LIMIT OF THAT CHECK, stated so it is not oversold: --contains prints
      # the CURRENT branch too, so a pre-rebase id is still reachable while the
      # branch carrying it exists. This fails loud only after that branch is
      # deleted and its ref pruned — later than the moment the anchor is
      # written, which is when a reader most needs to be caught.
      #
      # SO: WRITE THE ANCHOR AFTER THE BRANCH LANDS, reading the id off
      # `origin/main`. An anchor written on the branch it describes is the
      # wrong id by construction.
      [ -n "$(git branch -a --contains "$since" 2>/dev/null)" ] || {
        printf 'differential: anchor %s is reachable from no branch, so it looks like a PRE-REBASE id;\n' "$since" >&2
        printf 'differential: take the anchor from origin/main AFTER the branch lands\n' >&2
        exit 9
      }
      if git merge-base --is-ancestor "$since" "$BASE"; then
        expect="same"
        settled=$since
        settled_n=$((settled_n + 1))
      else
        rc=$?
        # The two checks above make 0 or 1 the expected answers — but $BASE is never
        # validated as a commit anywhere in this script (git show accepts a tree-ish),
        # so 128 is genuinely reachable. Measured 2026-09-04: --is-ancestor against a
        # TREE returns 128. Say so out loud
        # rather than assuming it: an rc that is neither is a question the
        # harness cannot answer, and answering it anyway is the silence this
        # file exists to refuse.
        [ "$rc" -eq 1 ] || {
          printf 'differential: the ancestry test for %s returned %s, which is neither yes nor no\n' "$since" "$rc" >&2
          exit 9
        }
        expect="diff"
      fi
      ;;
    *)
      # A hard stop, matching the unknown-transcript-shape arm below. An
      # expectation this function does not understand must never fall through
      # to a default, because the default is `same` and a shape silently
      # expecting agreement is a shape that has stopped testing anything.
      printf 'differential: unknown expectation %s (want same, diff, or diff@<commit>)\n' "$expect" >&2
      exit 9
      ;;
  esac
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
      asserted=$((asserted + 1))
      printf '  ok   %-44s DIFFERS, as asserted (old %s bytes, new %s bytes)\n' \
        "$label" "$(wc -c < "$o/out" | tr -d ' ')" "$(wc -c < "$w/out" | tr -d ' ')"
    elif [ -n "$settled" ]; then
      printf '  ok   %-44s agrees; its asserted divergence (%s) is already in the baseline\n' "$label" "$settled"
    else
      printf '  ok   %-44s rc=%s\n' "$label" "$(cat "$o/rc")"
    fi
  else
    diffn=$((diffn + 1))
    if [ "$expect" = diff ]; then
      printf '  SAME %-44s expected a DIFFERENCE and found none\n' "$label"
    elif [ -n "$settled" ]; then
      printf '  DIFF %-44s its divergence (%s) is already in the baseline, so the two sides should AGREE and do not\n' "$label" "$settled"
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
# shapes below, found when a floor-to-zero control passed every shape.
run_shape "config: maxBytes tiny" "$P_MAIN" '{"contextGuard":{"maxBytes":1}}'
run_shape "config: negative window" "$P_MAIN" '{"contextGuard":{"windowTokens":-5}}'

# THE THRESHOLD BOUNDARY, and the only shapes in this file asserted to differ
# for a reason other than an accident of refactoring. Feature 017 changed
# is_valid_threshold from `-le 100` to `-lt 100`, so a threshold of exactly 100
# is now refused and falls back to the previously resolved value.
#
# windowTokens is 360000 on all three so they are directly comparable: the
# default six readings are 180000 each, which is 50% of that window. 50 sits
# ABOVE the 45 fallback and BELOW 99, which is what makes exactly one of these
# three move:
#
#   thresholdPct 100 -> old: accepted, 50 < 100, SILENT
#                       new: refused, falls back to 45, 50 >= 45, FIRES     DIFF
#   thresholdPct  99 -> accepted by both, 50 < 99, silent both sides        same
#   thresholdPct 101 -> refused by both, falls back to 45, fires both sides same
#
# The two `same` assertions are not padding. They are how the change is shown to
# be BOUNDED rather than merely present: one value moved and its neighbours did
# not. Do not delete them to tidy the table.
#
# Picking 1000000 here instead would put the readings at 18%, below every
# threshold, and all three shapes would compare two silences — the exact defect
# recorded in the comment above `config: maxBytes tiny`.
# NOTE: plain `diff`, not `diff@`, and it cannot be otherwise yet — the commit
# introducing this divergence does not exist; it is the one being written.
#
# CONVERT IT AFTER THE BRANCH LANDS, TAKING THE ID FROM `origin/main`. Not from
# this branch. This repository rebase-merges, so the id here is not the id that
# lands: measured 2026-09-04, `9148066` and `f495823` have identical trees, and
# only the second is an ancestor of `main`. An anchor written on the branch it
# describes therefore never matches, and the guard in `run_shape` now refuses it
# by name rather than letting it degrade quietly.
#
# Until that follow-up, this assertion carries the exact staleness the `diff@`
# form was added to cure: the next feature to pin a baseline containing it will
# see one false red on a correct tree.
run_shape "config: thresholdPct exactly 100" "$P_MAIN" '{"contextGuard":{"windowTokens":360000,"thresholdPct":100}}' "" diff
run_shape "config: thresholdPct 99"          "$P_MAIN" '{"contextGuard":{"windowTokens":360000,"thresholdPct":99}}'
run_shape "config: thresholdPct 101"         "$P_MAIN" '{"contextGuard":{"windowTokens":360000,"thresholdPct":101}}'

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
run_shape "transcript: all three fields strings" "$P_MAIN" "" string-all-three diff@f495823
# The mirror case, also asserted. Old fires at 90% on an inflated median, new
# stays silent at the true 40%.
run_shape "transcript: strings that parse as a number" "$P_MAIN" "" string-numeric diff@f495823
# The same junk, starved to it by the byte cap, which moves the FALLBACK
# DECISION rather than the median.
run_shape "transcript: junk alone under the byte cap" "$P_MAIN" '{"contextGuard":{"maxBytes":1650}}' string-numeric-capped diff@f495823
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
# passed every shape until this line changed. A shape that cannot make the guard
# SPEAK cannot tell you it has stopped speaking.
run_shape "transcript: sixteen, byte cap of 1"  "$P_MAIN" '{"contextGuard":{"maxBytes":1}}' sixteen
run_shape "transcript: fourteen, byte cap of 1" "$P_MAIN" '{"contextGuard":{"maxBytes":1}}' fourteen

printf '\nbaseline: %s\n' "$BASE"
# AS EXPECTED, not IDENTICAL. The counter includes shapes asserted to DIFFER, so
# labelling it `IDENTICAL` reported a run in which one shape differed by design
# as a run in which nothing did — which is the single line a reader takes away.
# The asserted differences are counted out separately for the same reason, and
# the phrase reads `of the expected` rather than `of those`: the figure is a
# subset of AS EXPECTED, but printing straight after UNEXPECTED made it read as
# a subset of that instead.
# The RELAXED count is printed, and it is not decoration. An expectation
# auto-relaxed by `diff@` is an assertion that did not run, and a baseline
# pinned too new relaxes EVERY assertion and then prints a flawless zero. The
# refusal at the top of this file cannot catch that: the candidate's own change
# still differs, so the two sides are not identical. A reader who sees
# "0 unexpected" beside "3 auto-relaxed to same" can tell the difference between
# a harness that agreed and a harness that stopped asking.
printf 'SHAPES: %s   AS EXPECTED: %s   UNEXPECTED: %s   (of the expected, %s asserted to differ, %s auto-relaxed to same)\n' \
  "$n" "$same" "$diffn" "$asserted" "$settled_n"
[ "$diffn" -eq 0 ]
