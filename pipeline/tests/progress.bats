#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for pipeline/scripts/progress.sh — state and lock mechanics.
# Every test runs in its own scratch repository under $BATS_TEST_TMPDIR so
# no test can see another's state, and nothing touches this repository's
# own working tree.

load ../../tests/helper

setup() {
  PROG="$ROOT/pipeline/scripts/progress.sh"
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"
  cd "$WORK"
}

@test "init creates a state file that validates and prints its path" {
  run bash "$PROG" init 001-demo feature-branch main web
  [ "$status" -eq 0 ]
  [ "$output" = ".delivery-kit/runs/001-demo/progress.json" ]
  run bash "$PROG" validate 001-demo
  [ "$status" -eq 0 ]
  [ "$(jq -r '.feature' .delivery-kit/runs/001-demo/progress.json)" = "001-demo" ]
  [ "$(jq -r '.current_phase' .delivery-kit/runs/001-demo/progress.json)" = "preflight" ]
}

@test "init is idempotent: an existing state file is never clobbered" {
  bash "$PROG" init 001-demo b main web
  bash "$PROG" phase-start 001-demo B
  run bash "$PROG" init 001-demo b main web
  [ "$status" -eq 0 ]
  # The phase recorded between the two inits survives the second one.
  [ "$(jq -r '.current_phase' .delivery-kit/runs/001-demo/progress.json)" = "B" ]
}

@test "validate reds loudly on malformed JSON, naming the file" {
  mkdir -p .delivery-kit/runs/001-demo
  printf 'not json' > .delivery-kit/runs/001-demo/progress.json
  run bash "$PROG" validate 001-demo
  [ "$status" -ne 0 ]
  [[ "$output" == *"progress.json"* ]]
  [[ "$output" == *"not valid JSON"* ]]
}

@test "validate reds on a missing required key, naming the key" {
  bash "$PROG" init 001-demo b main web
  jq 'del(.current_phase)' .delivery-kit/runs/001-demo/progress.json > t.json
  mv t.json .delivery-kit/runs/001-demo/progress.json
  run bash "$PROG" validate 001-demo
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing required key 'current_phase'"* ]]
}

@test "phase-start records the phase and a start timestamp at phase START" {
  bash "$PROG" init 001-demo b main web
  bash "$PROG" phase-start 001-demo B
  [ "$(jq -r '.current_phase' .delivery-kit/runs/001-demo/progress.json)" = "B" ]
  [ -n "$(jq -r '.timestamps.B.started // empty' .delivery-kit/runs/001-demo/progress.json)" ]
}

@test "phase-start rejects an unknown phase by name" {
  bash "$PROG" init 001-demo b main web
  run bash "$PROG" phase-start 001-demo X
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown phase 'X'"* ]]
}

@test "phase-done is idempotent: one completion, however many calls" {
  bash "$PROG" init 001-demo b main web
  bash "$PROG" phase-done 001-demo B
  bash "$PROG" phase-done 001-demo B
  [ "$(jq -r '[.completed_phases[] | select(. == "B")] | length' .delivery-kit/runs/001-demo/progress.json)" = "1" ]
}

@test "from-validate accepts the current phase and a completed one" {
  bash "$PROG" init 001-demo b main web
  bash "$PROG" phase-done 001-demo A
  bash "$PROG" phase-start 001-demo B
  run bash "$PROG" from-validate 001-demo B
  [ "$status" -eq 0 ]
  run bash "$PROG" from-validate 001-demo A
  [ "$status" -eq 0 ]
}

@test "from-validate refuses a phase whose artefact does not exist, naming it" {
  bash "$PROG" init 001-demo b main web
  run bash "$PROG" from-validate 001-demo D
  [ "$status" -ne 0 ]
  [[ "$output" == *"'spec' artefact"* ]]
  # Record an artefact that exists and the same phase becomes legal.
  printf 'spec' > spec.md
  jq '.artifacts.spec = "spec.md"' .delivery-kit/runs/001-demo/progress.json > t.json
  mv t.json .delivery-kit/runs/001-demo/progress.json
  run bash "$PROG" from-validate 001-demo D
  [ "$status" -eq 0 ]
}

@test "lock-take refuses a live lock, naming the holder and the removal command" {
  bash "$PROG" init 001-demo b main web
  bash "$PROG" lock-take 001-demo session-one
  bash "$PROG" init 002-other b main web
  run bash "$PROG" lock-take 002-other session-two
  [ "$status" -ne 0 ]
  [[ "$output" == *"001-demo"* ]]
  [[ "$output" == *"rm '"* ]]
}

@test "lock-take takes over a stale lock whose holder has no state file" {
  mkdir -p .delivery-kit
  jq -n '{feature: "ghost", session: "dead", taken_at: "2026-01-01T00:00:00Z"}' > .delivery-kit/lock
  bash "$PROG" init 001-demo b main web
  run bash "$PROG" lock-take 001-demo session-one
  [ "$status" -eq 0 ]
  [[ "$output" == *"stale"* ]]
  [ "$(jq -r '.feature' .delivery-kit/lock)" = "001-demo" ]
}

@test "a DONE state file makes its lock stale; release is idempotent and refuses strangers" {
  bash "$PROG" init 001-demo b main web
  bash "$PROG" lock-take 001-demo session-one
  bash "$PROG" phase-start 001-demo DONE
  bash "$PROG" init 002-other b main web
  run bash "$PROG" lock-take 002-other session-two
  [ "$status" -eq 0 ]
  run bash "$PROG" lock-release 001-demo
  [ "$status" -ne 0 ]
  [[ "$output" == *"held by '002-other'"* ]]
  bash "$PROG" lock-release 002-other
  run bash "$PROG" lock-release 002-other
  [ "$status" -eq 0 ]
}

@test "a feature name that could escape the runs directory is refused by name" {
  run bash "$PROG" init '../escape' b main web
  [ "$status" -ne 0 ]
  [[ "$output" == *"letters, digits, dot, dash, underscore"* ]]
}

@test "stdout carries nothing even when stderr is talking" {
  bash "$PROG" init 001-demo b main web
  jq -n '{feature: "ghost", session: "dead", taken_at: "2026-01-01T00:00:00Z"}' > .delivery-kit/lock
  run --separate-stderr bash "$PROG" lock-take 001-demo session-one
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [[ "$stderr" == *"stale"* ]]
}

# ---------------------------------------------------------------------------
# The `read` subcommand. Shipped skill documents instruct their readers to get a
# run's state through it rather than by reading the file, and one of them warns
# about a platform-specific hazard in its output — the warning this second test
# pins. Nothing tested either claim before these. A change that put a validation
# message on the data stream would have shipped green.
#
# No count of those documents appears here or in a test name. One did, briefly,
# and it was wrong: both skills rest on `read`, but only one carries the CRLF
# warning.
# ---------------------------------------------------------------------------

@test "read puts pure JSON on stdout, and puts NOTHING there when the state is broken" {
  bash "$PROG" init 001-demo b main web
  sf=.delivery-kit/runs/001-demo/progress.json

  # BYTE-IDENTICAL to the file, not merely parseable. A parser accepts leading
  # whitespace, so "jq accepts it" alone would still pass if read printed a
  # blank line first — measured in review, with exactly that mutation. The
  # contract says read PRINTS THE STATE FILE, and only a byte comparison says
  # that.
  bash "$PROG" read 001-demo > got.txt
  # Not `cmp -s`: the silent form tells you only that the assertion failed,
  # while plain cmp names the byte that differed — and it keeps "file missing"
  # (exit 2) distinguishable from "files differ" (exit 1).
  cmp got.txt "$sf"
  jq -e . < got.txt > /dev/null

  # Now break it. The fault belongs on stderr; a caller parsing stdout must see
  # ZERO BYTES — not "nothing bats can see". bats strips trailing newlines from
  # $output, so [ -z "$output" ] passes on a one-byte newline. Measure the file.
  jq '.completed_phases = "not-a-list"' "$sf" > t.json
  mv t.json "$sf"
  if bash "$PROG" read 001-demo > got2.txt 2> err.txt; then st=0; else st=$?; fi
  [ "$st" -ne 0 ]
  [ ! -s got2.txt ]
  grep -q "completed_phases must be an array" err.txt
}

@test "read honours the documented CRLF contract" {
  bash "$PROG" init 001-demo b main web
  sf=.delivery-kit/runs/001-demo/progress.json
  # The condition is CONSTRUCTED, never waited for. It does not arise on every
  # machine, so a test that read whatever the file happened to hold would pass
  # everywhere and prove nothing on most of them.
  #
  # ON WINDOWS THIS LINE IS A NO-OP, and that is not a reason to delete it. The
  # jq build there writes CRLF, so `init` already produced a CRLF state file and
  # this conversion changes nothing — measured. On Linux and macOS, where jq
  # writes LF, this line is the only thing that creates the condition, so those
  # two CI jobs are where the constructed half is actually exercised.
  awk '{printf "%s\r\n", $0}' "$sf" > t.json
  mv t.json "$sf"

  # 1. A strict parser still accepts it — this is why the skills say "parse it
  #    with jq".
  run --separate-stderr bash "$PROG" read 001-demo
  [ "$status" -eq 0 ]
  jq -e . <<<"$output" > /dev/null

  # 2. Command substitution still captures cleanly — the skills' other blessed
  #    route. An exact comparison, so a retained carriage return fails it.
  v="$(bash "$PROG" read 001-demo | jq -r .current_phase)"
  [ "$v" = "preflight" ]

  # 3. And the idiom the skills FORBID does retain the stray character. This is
  #    the warning half: if this ever stopped being true, the shipped warning
  #    would be a lie with no test to notice.
  cr="$(printf '\r')"
  bash "$PROG" read 001-demo > out.txt
  kept=no
  while IFS= read -r l; do
    case "$l" in
      *'"feature"'*) case "$l" in *"$cr") kept=yes ;; esac ;;
    esac
  done < out.txt
  [ "$kept" = yes ]
}

# ---------------------------------------------------------------------------
# Refusal paths. A refusal is a PAIR: a non-zero exit and a message naming what
# was wrong. Each test below asserts the naming, because a test that asserts
# only the status passes with the message emptied — and the person meeting one
# of these is already in trouble and needs the name, not the number.
#
# Only the D branch of from-validate was covered before this block (see the
# test above named for it). It is deliberately not duplicated here.
# ---------------------------------------------------------------------------

@test "phase-done refuses an unknown phase, naming it" {
  bash "$PROG" init 001-demo b main web
  run bash "$PROG" phase-done 001-demo ZZZ
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown phase 'ZZZ'"* ]]
}

@test "from-validate refuses E by naming the plan artefact" {
  bash "$PROG" init 001-demo b main web
  run bash "$PROG" from-validate 001-demo E
  [ "$status" -ne 0 ]
  [[ "$output" == *"'plan' artefact"* ]]
  [[ "$output" == *"records none that exists"* ]]
}

@test "from-validate refuses the tasks group by naming the tasks artefact" {
  bash "$PROG" init 001-demo b main web
  # Every phase in that group shares this one branch. Driving one proves the
  # branch; driving the rest would prove the case statement, which is not what
  # is at risk — and a count written here would go stale the moment the group
  # gains a phase, with nothing to redden it.
  run bash "$PROG" from-validate 001-demo F
  [ "$status" -ne 0 ]
  [[ "$output" == *"'tasks' artefact"* ]]
}

@test "from-validate's final refusal names the phase and all three reasons" {
  bash "$PROG" init 001-demo b main web
  run bash "$PROG" from-validate 001-demo O
  [ "$status" -ne 0 ]
  # The enumeration IS the useful part: it tells the reader which of three
  # things to change. Assert all three, so none can be dropped quietly.
  [[ "$output" == *"--from O"* ]]
  [[ "$output" == *"not the current phase"* ]]
  [[ "$output" == *"not completed"* ]]
  [[ "$output" == *"no artefact rule admits it"* ]]
}

@test "lock-take with no session id names the missing argument" {
  bash "$PROG" init 001-demo b main web
  run bash "$PROG" lock-take 001-demo
  [ "$status" -ne 0 ]
  [[ "$output" == *"needs a session id"* ]]
}

@test "a lock that cannot be created names the race and the remedy" {
  bash "$PROG" init 001-demo b main web
  # This test does NOT run a race, and must not be "fixed" into one: a race is
  # unreliable to lose on purpose, and a test that passes only sometimes is
  # worse than no test. The guard above the protected write tests for a regular
  # FILE, so a directory at that path passes the guard untouched and then makes
  # the write fail. Same branch, different door, deterministic.
  mkdir -p .delivery-kit/lock
  run bash "$PROG" lock-take 001-demo session-one
  [ "$status" -ne 0 ]
  [[ "$output" == *"lost the lock race"* ]]
  [[ "$output" == *"run lock-take again"* ]]
}

@test "too few arguments prints usage, enumerating every subcommand" {
  # Both shapes reach it: no arguments at all, and a subcommand with no feature.
  run bash "$PROG"
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage:"* ]]
  run bash "$PROG" read
  [ "$status" -ne 0 ]
  # Assert the WHOLE enumeration in one comparison. Asserting a few names is not
  # enough: one of the eight is a substring of another, so `validate` still
  # matches after `validate|` is deleted — and a review measured five of the
  # eight silently droppable under an earlier three-name assertion. Any drop,
  # and any reorder, reddens this line. (An earlier draft of this comment said
  # three names were substrings; measured, it is exactly one.) The list grew
  # from eight to ten with commit-add and piece-next, to twenty with the
  # commit mechanics (snapshot to drop-stale), and to twenty-one with
  # remainder-commit, edited here rather than
  # pinned by a second, weaker test beside this one.
  [[ "$output" == *"<init|read|validate|phase-start|phase-done|from-validate|lock-take|lock-release|commit-add|piece-next|snapshot|spec-commit|piece-commit|late-commit|remainder-commit|record-branch|guide|commit-list|metrics|state-set|drop-stale>"* ]]
}

@test "validate names the file and the key when completed_phases is not a list" {
  bash "$PROG" init 001-demo b main web
  jq '.completed_phases = "not-a-list"' .delivery-kit/runs/001-demo/progress.json > t.json
  mv t.json .delivery-kit/runs/001-demo/progress.json
  run bash "$PROG" validate 001-demo
  [ "$status" -ne 0 ]
  # The path matters as much as the key: a repository can hold several state
  # files, and naming only the key sends the reader to the wrong one.
  [[ "$output" == *"runs/001-demo/progress.json"* ]]
  [[ "$output" == *"completed_phases must be an array"* ]]
}

@test "validate names the file and the value when current_phase is unknown" {
  bash "$PROG" init 001-demo b main web
  jq '.current_phase = "ZZZ"' .delivery-kit/runs/001-demo/progress.json > t.json
  mv t.json .delivery-kit/runs/001-demo/progress.json
  run bash "$PROG" validate 001-demo
  [ "$status" -ne 0 ]
  [[ "$output" == *"runs/001-demo/progress.json"* ]]
  [[ "$output" == *"current_phase 'ZZZ'"* ]]
  [[ "$output" == *"is not a phase this pipeline knows"* ]]
}

# --- commit-add ---------------------------------------------------------------
#
# Full 40-character ids, written out. A helper that repeats one character cannot
# build an id that starts with a given prefix, so every prefix rule below would
# pass whatever the code did. Each one was measured at 40 characters.
SHA_A=abc1234000000000000000000000000000000001
SHA_B=7be8232ef0000000000000000000000000000002
SHA_C=fdb79bb000000000000000000000000000000003
SHA_D=d000000000000000000000000000000000000004
SHA_E=eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee

ca_init() {
  bash "$PROG" init 001-demo b main web > /dev/null
  SF=.delivery-kit/runs/001-demo/progress.json
}

# The four shapes measured in real state files written before commit-add
# existed: a 7-character id, a full id, a 9-character id, and an id followed by
# the commit subject.
seed_legacy() {
  jq --arg e "$SHA_E" '.commits = ["abc1234", $e, "7be8232ef", "fdb79bb feat(pipeline): pre-flight names git"]' \
    "$SF" > t.json
  mv t.json "$SF"
}

# refuses_via <subcommand> <fragment> <arguments...>
# A refusal is only proven when all four hold. The exit code alone proves
# nothing: before commit-add and piece-next existed, the helper already exited
# 1 on either, with a usage line — so every check here names the fragment the
# contract promises, and the state file must come through byte-identical.
#
# stdout goes to a FILE and must be zero bytes: bats strips trailing newlines
# from $output, so [ -z "$output" ] passes on a one-byte newline (the comment
# on the read test above says so, and a reviewer measured a refusal that also
# printed "\n" passing every refusal test that way). Plain cmp, not cmp -s,
# for the reason given on the read test.
refuses_via() {
  local sub="$1" frag="$2" rc=0; shift 2
  cp "$SF" before.json
  bash "$PROG" "$sub" "$@" > out.txt 2> err.txt || rc=$?
  [ "$rc" -ne 0 ] || { echo "exit 0, expected a refusal naming: $frag"; return 1; }
  stderr="$(cat err.txt)"
  [[ "$stderr" == *"$frag"* ]] || { echo "stderr lacks '$frag': $stderr"; return 1; }
  [ ! -s out.txt ] || { echo "a refusal printed on stdout: $(od -c out.txt)"; return 1; }
  cmp before.json "$SF" || { echo "a refusal changed the state file"; return 1; }
}

# no_stdout <subcommand> <arguments...> — succeeds, and prints zero bytes.
no_stdout() {
  bash "$PROG" "$@" > out.txt
  [ ! -s out.txt ] || { echo "stdout was not empty: $(od -c out.txt)"; return 1; }
}
refuses() { refuses_via commit-add "$@"; }

hex() { printf '%s' "$1" | od -An -tx1 | tr -d ' \n'; }

# The eight kinds, written out here on purpose from
# contracts/progress-commands.md: a second view of the set, pinned equal to the
# script's. Walking the script's own list would be circular — dropping a kind
# would drop it from both.
CONTRACT_KINDS=(spec piece converge simplify review tests constitution other)

@test "commit-add records one piece entry with its fields in order and arrays typed" {
  ca_init
  # Unsorted on purpose: sorted input would pass a write that sorted it.
  # commit-add prints nothing on stdout — zero bytes, measured from a file: the
  # orchestrator reads stdout, and a stray line there would be taken for an answer.
  no_stdout commit-add 001-demo piece "$SHA_A" "Phase 1: Setup" T002,T001 z.sh "b c.md"
  [ "$(jq -c '.commits[0] | keys_unsorted' "$SF")" = '["sha","kind","piece","tasks","files"]' ]
  jq -e '.commits[0].tasks | type == "array"' "$SF" > /dev/null
  jq -e '.commits[0].files | type == "array"' "$SF" > /dev/null
  [ "$(jq -r '.commits[0].sha' "$SF")" = "$SHA_A" ]
  [ "$(jq -r '.commits[0].kind' "$SF")" = "piece" ]
  [ "$(jq -r '.commits[0].piece' "$SF")" = "Phase 1: Setup" ]
  [ "$(jq -c '.commits[0].tasks' "$SF")" = '["T002","T001"]' ]
  [ "$(jq -c '.commits[0].files' "$SF")" = '["z.sh","b c.md"]' ]
  bash "$PROG" validate 001-demo
  # Written through a temporary file and moved into place, so none is left.
  [ ! -e "$SF.tmp" ]
}

@test "commit-add appends a second entry and leaves the first untouched" {
  ca_init
  bash "$PROG" commit-add 001-demo spec "$SHA_A" "" "" specs/x/spec.md
  first="$(jq -c '.commits[0]' "$SF")"
  bash "$PROG" commit-add 001-demo piece "$SHA_B" "Phase 1: Setup" T001 a.sh
  [ "$(jq '.commits | length' "$SF")" -eq 2 ]
  [ "$(jq -c '.commits[0]' "$SF")" = "$first" ]
  [ "$(jq -r '.commits[1].sha' "$SF")" = "$SHA_B" ]
}

@test "commit-add keeps old-style bare-string entries in place and appends after them" {
  ca_init
  seed_legacy
  before="$(jq -c '.commits' "$SF")"
  bash "$PROG" commit-add 001-demo other "$SHA_D" "" "" notes.txt
  [ "$(jq '.commits | length' "$SF")" -eq 5 ]
  [ "$(jq -c '.commits[:4]' "$SF")" = "$before" ]
  jq -e '.commits[4] | type == "object"' "$SF" > /dev/null
  # Both shapes in one list still validate.
  bash "$PROG" validate 001-demo
}

@test "commit-add treats an identical re-record as done and writes nothing" {
  ca_init
  bash "$PROG" commit-add 001-demo piece "$SHA_A" "Phase 1: Setup" T001,T002 a.sh
  cp "$SF" before.json
  # A re-run after a crash between recording and the next step repeats the call
  # exactly. It must succeed, or re-entering the phase would fail on work that
  # is already done.
  no_stdout commit-add 001-demo piece "$SHA_A" "Phase 1: Setup" T001,T002 a.sh
  cmp before.json "$SF"
}

@test "commit-add accepts kind tests with no files and records an empty array" {
  ca_init
  bash "$PROG" commit-add 001-demo tests "$SHA_A" "" ""
  jq -e '.commits[0].files | type == "array" and length == 0' "$SF" > /dev/null
  jq -e '.commits[0].tasks | type == "array" and length == 0' "$SF" > /dev/null
}

@test "commit-add stores a path with a space and non-ASCII bytes exactly" {
  ca_init
  bash "$PROG" commit-add 001-demo other "$SHA_A" "" "" 'dir/a b ü—🎯.md'
  # Compared as bytes against a literal, never against another jq round-trip:
  # on Windows the shell rewrites some arguments before a native jq sees them,
  # and a round-trip through the same rewrite would compare equal regardless.
  got="$(jq -r '.commits[0].files[0]' "$SF")"
  [ "$(hex "$got")" = "6469722f61206220c3bce28094f09f8eaf2e6d64" ]
}

@test "commit-add stores a path that starts with a dash as data, not an option" {
  ca_init
  bash "$PROG" commit-add 001-demo other "$SHA_A" "" "" -dash.txt
  [ "$(jq -c '.commits[0].files' "$SF")" = '["-dash.txt"]' ]
}

@test "commit-add accepts each of the eight kinds the contract names" {
  ca_init
  [ "${#CONTRACT_KINDS[@]}" -eq 8 ]
  i=0
  for k in "${CONTRACT_KINDS[@]}"; do
    i=$((i + 1))
    bash "$PROG" commit-add 001-demo "$k" "$(printf '%039d%d' 0 "$i")" "P$i" "T00$i" "f$i.txt"
  done
  [ "$(jq -r '[.commits[].kind] | join(" ")' "$SF")" = "${CONTRACT_KINDS[*]}" ]
}

@test "commit-add refuses too few arguments by name" {
  ca_init
  refuses "commit-add needs" 001-demo piece "$SHA_A" "Phase 1: Setup"
}

@test "commit-add refuses an unknown kind and lists all eight legal ones" {
  ca_init
  refuses "unknown kind" 001-demo bogus "$SHA_A" "" "" a.txt
  for k in "${CONTRACT_KINDS[@]}"; do
    [[ "$stderr" == *"$k"* ]] || { echo "the message does not list '$k'"; false; }
  done
  # And lists nothing else: the whole set, in order, bounded by its brackets,
  # so a ninth kind added to the script alone goes red here.
  [[ "$stderr" == *"(legal: ${CONTRACT_KINDS[*]})"* ]] || { echo "the legal list is not exactly the contract's eight: $stderr"; false; }
}

@test "commit-add refuses a multi-word kind that is a substring of the list" {
  ca_init
  # " spec piece " with its spaces IS a substring of the legal list, so the
  # bare membership idiom would accept it. Measured before this was written.
  refuses "unknown kind" 001-demo "spec piece" "$SHA_A" "" "" a.txt
}

@test "commit-add refuses an empty commit id" {
  ca_init
  refuses "needs a commit id" 001-demo other "" "" "" a.txt
}

@test "commit-add refuses a 39-character commit id" {
  ca_init
  refuses "not a full commit id" 001-demo other "${SHA_A:0:39}" "" "" a.txt
}

@test "commit-add refuses a 41-character commit id" {
  ca_init
  refuses "not a full commit id" 001-demo other "${SHA_A}0" "" "" a.txt
}

@test "commit-add refuses an uppercase commit id" {
  ca_init
  refuses "not a full commit id" 001-demo other ABC1234000000000000000000000000000000001 "" "" a.txt
}

@test "commit-add refuses a recorded id with a different kind" {
  ca_init
  bash "$PROG" commit-add 001-demo piece "$SHA_A" "Phase 1: Setup" T001,T002 a.sh b.sh
  refuses "already recorded with different details" 001-demo other "$SHA_A" "Phase 1: Setup" T001,T002 a.sh b.sh
}

@test "commit-add refuses a recorded id with a different piece" {
  ca_init
  bash "$PROG" commit-add 001-demo piece "$SHA_A" "Phase 1: Setup" T001,T002 a.sh b.sh
  refuses "already recorded with different details" 001-demo piece "$SHA_A" "Phase 2: Other" T001,T002 a.sh b.sh
}

@test "commit-add refuses a recorded id with different tasks" {
  ca_init
  bash "$PROG" commit-add 001-demo piece "$SHA_A" "Phase 1: Setup" T001,T002 a.sh b.sh
  refuses "already recorded with different details" 001-demo piece "$SHA_A" "Phase 1: Setup" T001 a.sh b.sh
}

@test "commit-add refuses a recorded id with different files" {
  ca_init
  bash "$PROG" commit-add 001-demo piece "$SHA_A" "Phase 1: Setup" T001,T002 a.sh b.sh
  refuses "already recorded with different details" 001-demo piece "$SHA_A" "Phase 1: Setup" T001,T002 a.sh
}

@test "commit-add refuses an id claimed by a 7-character old-style entry" {
  ca_init
  seed_legacy
  refuses "already recorded by an old-style entry" 001-demo other "$SHA_A" "" "" a.txt
}

@test "commit-add refuses an id claimed by a 9-character old-style entry" {
  ca_init
  seed_legacy
  refuses "already recorded by an old-style entry" 001-demo other "$SHA_B" "" "" a.txt
}

@test "commit-add refuses an id claimed by an old-style entry's first word" {
  ca_init
  seed_legacy
  # "fdb79bb feat(pipeline): ..." — only the first word is an id. Comparing the
  # whole string would never match, and the duplicate would slip through.
  refuses "already recorded by an old-style entry" 001-demo other "$SHA_C" "" "" a.txt
}

@test "commit-add refuses an id equal to a full old-style entry" {
  ca_init
  seed_legacy
  refuses "already recorded by an old-style entry" 001-demo other "$SHA_E" "" "" a.txt
}

@test "commit-add does not let a 6-character old-style word claim an id" {
  ca_init
  jq '.commits = ["abc123"]' "$SF" > t.json
  mv t.json "$SF"
  # Six characters is below the shortest id git prints. A word that short must
  # match nothing, or one odd old entry could claim every id that shares it.
  bash "$PROG" commit-add 001-demo other "$SHA_A" "" "" a.txt
  [ "$(jq '.commits | length' "$SF")" -eq 2 ]
}

@test "commit-add refuses an unknown feature" {
  ca_init
  refuses "no state file" 002-nope other "$SHA_A" "" "" a.txt
}

@test "commit-add refuses a piece with no piece name" {
  ca_init
  refuses "needs a piece name" 001-demo piece "$SHA_A" "" T001 a.txt
}

@test "commit-add refuses a piece with no task ids" {
  ca_init
  refuses "needs its task ids" 001-demo piece "$SHA_A" "Phase 1: Setup" "" a.txt
}

@test "commit-add refuses a task id that is not a T and digits" {
  # The review guide prints the ids in a table cell: an id is data of one
  # known shape, never markup.
  ca_init
  refuses "task id '<b>x</b>'" 001-demo piece "$SHA_A" "Phase 1: Setup" 'T001,<b>x</b>' a.txt
  refuses "task id 'T1|x'" 001-demo piece "$SHA_A" "Phase 1: Setup" 'T1|x' a.txt
  refuses "task id 't001'" 001-demo piece "$SHA_A" "Phase 1: Setup" 't001' a.txt
  refuses "task id 'T'" 001-demo review "$SHA_A" "" 'T' a.txt
  refuses "task id 'T1 '" 001-demo piece "$SHA_A" "Phase 1: Setup" 'T1 ' a.txt
}

@test "commit-add refuses a piece name holding a carriage return" {
  ca_init
  refuses "piece name holds a control character" 001-demo piece "$SHA_A" $'Phase 1: Setup\r' T001 a.txt
}

@test "commit-add refuses a piece name holding a line feed" {
  ca_init
  refuses "piece name holds a control character" 001-demo piece "$SHA_A" $'Phase 1:\nSetup' T001 a.txt
}

@test "commit-add refuses a piece name holding the unit separator" {
  ca_init
  refuses "piece name holds a control character" 001-demo piece "$SHA_A" $'Phase 1:\x1fSetup' T001 a.txt
}

@test "commit-add refuses a review entry with no files" {
  ca_init
  refuses "needs the files it changed" 001-demo review "$SHA_A" "" ""
}

# --- piece-next ---------------------------------------------------------------
#
# The fixture copies two real headings byte for byte (an em dash, an emoji,
# parentheses), keeps a phase with no task, nests tasks under `### `
# subheadings, marks one task with a lowercase x, carries a lettered phase,
# and plants decoy task lines under headings that are not pieces.
FIXTURE="$ROOT/pipeline/tests/fixtures/tasks-pieces/tasks.md"

pn_init() {
  ca_init
  mkdir -p specs
  cp "$FIXTURE" specs/tasks.md
  jq '.artifacts.tasks = "specs/tasks.md"' "$SF" > t.json
  mv t.json "$SF"
}

# The fixture's own heading text after "## ", found by a fixed prefix.
fixture_heading() {
  local line
  line="$(grep -F -- "## $1" "$FIXTURE")"
  printf '%s' "${line#\#\# }"
}

# record <heading> <ids> — records a piece under a fresh full id.
PN_N=0
record() {
  PN_N=$((PN_N + 1))
  bash "$PROG" commit-add 001-demo piece "$(printf 'f%039d' "$PN_N")" "$1" "$2" specs/tasks.md
}

# pn_refuses <fragment> [feature] — refuses_via for piece-next, which now also
# proves a refusal left the state file untouched.
pn_refuses() { refuses_via piece-next "$1" "${2:-001-demo}"; }

@test "piece-next prints the first piece as two lines: heading, then task ids" {
  pn_init
  # --keep-empty-lines, or a stray blank line after the ids would be hidden:
  # measured, bats drops it from `lines` without the flag and counts it with.
  run --keep-empty-lines --separate-stderr bash "$PROG" piece-next 001-demo
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "Phase 1: Setup" ]
  [ "${lines[1]}" = "T001,T002" ]
}

@test "piece-next skips a recorded piece and a heading with no task" {
  pn_init
  record "Phase 1: Setup" T001,T002
  run --separate-stderr bash "$PROG" piece-next 001-demo
  [ "$status" -eq 0 ]
  # Phase 2 has no task, so it is not a piece. Phase 3's three tasks all sit
  # under `### ` subheadings, which do not end the piece.
  [ "${lines[0]}" = "$(fixture_heading 'Phase 3: ')" ]
  [ "${lines[1]}" = "T003,T004,T005" ]
}

@test "piece-next skips a phase recorded under kind converge" {
  pn_init
  bash "$PROG" commit-add 001-demo converge "$(printf 'c%039d' 1)" "Phase 1: Setup" T001,T002 specs/tasks.md
  run --separate-stderr bash "$PROG" piece-next 001-demo
  [ "${lines[0]}" = "$(fixture_heading 'Phase 3: ')" ]
}

@test "piece-next does not skip a heading named by a review entry" {
  pn_init
  bash "$PROG" commit-add 001-demo review "$(printf 'c%039d' 1)" "Phase 1: Setup" "" a.sh
  run --separate-stderr bash "$PROG" piece-next 001-demo
  [ "${lines[0]}" = "Phase 1: Setup" ]
}

@test "piece-next walks every piece once, in order, then prints nothing" {
  pn_init
  expected="Phase 1: Setup|T001,T002
$(fixture_heading 'Phase 3: ')|T003,T004,T005
$(fixture_heading 'Phase 4: ')|T006
$(fixture_heading 'Phase 9b: ')|T007"
  # Bounded: a piece that repeats is the failure this test exists to catch, and
  # an unbounded loop would turn it into a hang instead of a named red.
  bound=$(( $(grep -c '^## Phase ' specs/tasks.md) + 1 ))
  seen=""; all=""; n=0
  while :; do
    n=$((n + 1))
    [ "$n" -le "$bound" ] || { echo "no end after $bound calls; last heading: $heading"; false; }
    out="$(bash "$PROG" piece-next 001-demo)"
    all="$all$out"
    [ -n "$out" ] || break
    heading="${out%%$'\n'*}"; ids="${out#*$'\n'}"
    seen="$seen${seen:+$'\n'}$heading|$ids"
    record "$heading" "$ids"
  done
  [ "$seen" = "$expected" ]
  # T006 is marked with a lowercase x, and Phase 9b carries a letter: both
  # arrived above. The decoys under non-piece headings never do.
  # Every id from T900 up is a decoy: a non-piece heading, a Phase heading
  # with no number, with no colon, with an uppercase suffix, an indented task.
  for d in T900 T901 T902 T903 T904 T905; do
    [[ "$all" != *"$d"* ]] || { echo "decoy $d was printed"; false; }
  done
  # "Nothing left" is zero bytes, not a blank line: a caller reading one line
  # would take a blank for a piece with an empty name.
  no_stdout piece-next 001-demo
}

@test "piece-next prints both real headings byte for byte" {
  pn_init
  record "Phase 1: Setup" T001,T002
  run --separate-stderr bash "$PROG" piece-next 001-demo
  # The emoji, the em dash and the parentheses, compared as bytes.
  [ "$(hex "${lines[0]}")" = "$(hex "$(fixture_heading 'Phase 3: ')")" ]
  record "${lines[0]}" "${lines[1]}"
  run --separate-stderr bash "$PROG" piece-next 001-demo
  [ "$(hex "${lines[0]}")" = "$(hex "$(fixture_heading 'Phase 4: ')")" ]
}

@test "piece-next reads a CRLF tasks file exactly like an LF one" {
  pn_init
  # awk, not sed: BSD sed on macOS writes a literal r for \r.
  #
  # ON WINDOWS THIS CASE DOES NOT EXERCISE THE SCRIPT'S OWN CR STRIPPING. The
  # native jq there removes the CR itself when it reads a file — measured — so
  # only the Linux and macOS runs prove the script strips it.
  awk '{printf "%s\r\n", $0}' "$FIXTURE" > specs/tasks.md
  # --keep-empty-lines, or a stray blank line after the ids would be hidden:
  # measured, bats drops it from `lines` without the flag and counts it with.
  run --keep-empty-lines --separate-stderr bash "$PROG" piece-next 001-demo
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "Phase 1: Setup" ]
  [ "${lines[1]}" = "T001,T002" ]
  [[ "$output" != *$'\r'* ]]
}

@test "piece-next writes neither the state file nor the tasks file" {
  pn_init
  cp "$SF" state.before
  cp specs/tasks.md tasks.before
  # Compared after a call that PRINTED a piece: a check made after a refusal
  # passes on a command that does nothing at all.
  run --separate-stderr bash "$PROG" piece-next 001-demo
  [ "${lines[0]}" = "Phase 1: Setup" ]
  cmp state.before "$SF"
  cmp tasks.before specs/tasks.md
}

@test "piece-next refuses an unknown feature" {
  pn_init
  pn_refuses "no state file" 002-nope
}

@test "piece-next refuses a run that records no tasks file" {
  ca_init
  pn_refuses "records no tasks file"
}

@test "piece-next refuses a recorded tasks file that does not exist" {
  ca_init
  jq '.artifacts.tasks = "specs/missing.md"' "$SF" > t.json
  mv t.json "$SF"
  pn_refuses "tasks file not found"
}

@test "piece-next refuses a tasks file with no Phase heading" {
  pn_init
  printf '# Tasks\n\n## Dependencies\n\n- [ ] T001 not a piece\n' > specs/tasks.md
  pn_refuses "no piece"
}

@test "piece-next refuses a tasks file whose only Phase heading has no task" {
  pn_init
  printf '# Tasks\n\n## Phase 1: Setup\n\nProse only.\n' > specs/tasks.md
  pn_refuses "no piece"
}

@test "piece-next refuses a heading holding the unit separator" {
  pn_init
  printf '## Phase 1: Set\037up\n\n- [ ] T001 a task\n' > specs/tasks.md
  pn_refuses "heading holds a control character"
}

@test "piece-next refuses a heading holding a carriage return mid-line" {
  pn_init
  # Mid-line, so it is kept on every OS: Windows jq strips only the CR before a
  # line feed. commit-add would refuse this name, so offering it would stall.
  printf '## Phase 1: Set\rup\n\n- [ ] T001 a task\n' > specs/tasks.md
  pn_refuses "heading holds a control character"
}

# --- added at the deep review ---------------------------------------------------

@test "commit-add is not blocked by an empty old-style entry" {
  ca_init
  jq '.commits = [""]' "$SF" > t.json
  mv t.json "$SF"
  # An empty string has no first word. Before this was fixed, the duplicate
  # check failed on it for EVERY id, with jq's own error and exit 5 — an old
  # entry that must match nothing blocked every record the run would make.
  bash "$PROG" commit-add 001-demo other "$SHA_A" "" "" a.txt
  [ "$(jq '.commits | length' "$SF")" -eq 2 ]
}

@test "commit-add refuses an empty path in its file list" {
  ca_init
  # An unset variable expands to an empty argument: the shape a broken caller
  # produces, and one a check for a merely non-empty list would let through.
  refuses "empty path" 001-demo other "$SHA_A" "" "" a.txt ""
}

@test "commit-add refuses an empty task id anywhere in its task list" {
  ca_init
  refuses "empty task id" 001-demo piece "$SHA_A" "Phase 1: Setup" "T001,,T002" a.txt
  refuses "empty task id" 001-demo piece "$SHA_A" "Phase 1: Setup" ",T001" a.txt
  refuses "empty task id" 001-demo piece "$SHA_A" "Phase 1: Setup" "T001," a.txt
}

@test "piece-next ignores old-style entries, even one equal to a heading" {
  pn_init
  # Most state files written before commit-add existed hold bare strings (the
  # dated count is in the feature's spec). One equal to a heading names no
  # kind, so it is not a recorded piece — and reading a bare string as an
  # entry with a kind would crash the walk on every one of those files.
  jq '.commits = ["abc1234", "Phase 1: Setup"]' "$SF" > t.json
  mv t.json "$SF"
  run --separate-stderr bash "$PROG" piece-next 001-demo
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Phase 1: Setup" ]
  [ "${lines[1]}" = "T001,T002" ]
}

@test "piece-next refuses a heading holding a NUL" {
  pn_init
  # Command substitution drops a NUL with only a warning, so the name printed
  # would never equal the heading in the file, and the piece would come back
  # after it was recorded. Measured before this was fixed.
  printf '## Phase 1: Set\000up\n\n- [ ] T001 a task\n' > specs/tasks.md
  pn_refuses "heading holds a control character"
}

@test "commit-add refuses a converge entry whose piece name holds a carriage return" {
  ca_init
  # piece-next counts converge entries as recorded too, so a converge name
  # carrying a CR stalls a run exactly as a piece name would.
  refuses "piece name holds a control character" 001-demo converge "$SHA_A" $'Phase 7: Gaps\r' T001 a.txt
}

@test "commit-add refuses a lowercase id holding a letter that is not hex" {
  ca_init
  refuses "not a full commit id" 001-demo other abc123g000000000000000000000000000000001 "" "" a.txt
}

@test "piece-next matches a recorded name exactly, never as a prefix" {
  pn_init
  # "Phase 1" is a prefix of the heading "Phase 1: Setup", not the heading.
  record "Phase 1" T001,T002
  run --separate-stderr bash "$PROG" piece-next 001-demo
  [ "${lines[0]}" = "Phase 1: Setup" ]
}

# --- added at the pull-request review ------------------------------------------

@test "commit-add refuses a state file whose commits is not a list" {
  ca_init
  jq '.commits = "abc"' "$SF" > t.json
  mv t.json "$SF"
  refuses "commits must be a list" 001-demo other "$SHA_A" "" "" a.txt
}

@test "piece-next refuses a state file whose commits is not a list" {
  pn_init
  jq '.commits = "abc"' "$SF" > t.json
  mv t.json "$SF"
  # Read as "nothing recorded", it would offer every piece again.
  pn_refuses "commits must be a list"
}

# --- validate as one jq program -------------------------------------------------
# validate answers from ONE jq program over the slurped file, and falls back to
# the old one-process-per-check form only for a file that is not exactly one
# JSON document. These pin the translations that program makes, where the old
# form got its answer from a jq ERROR or exit status rather than a value.

@test "validate names the first required key when the document is not an object" {
  mkdir -p .delivery-kit/runs/001-demo
  for doc in '[1]' 'true' '5' '"str"'; do
    printf '%s' "$doc" > .delivery-kit/runs/001-demo/progress.json
    run bash "$PROG" validate 001-demo
    [ "$status" -eq 1 ]
    [ "$output" = "progress.sh: .delivery-kit/runs/001-demo/progress.json is missing required key 'feature'" ]
  done
}

@test "validate calls a null or false document, or an empty file, not valid JSON" {
  mkdir -p .delivery-kit/runs/001-demo
  for doc in 'null' 'false' ''; do
    printf '%s' "$doc" > .delivery-kit/runs/001-demo/progress.json
    run bash "$PROG" validate 001-demo
    [ "$status" -eq 1 ]
    [ "$output" = "progress.sh: .delivery-kit/runs/001-demo/progress.json is not valid JSON" ]
  done
}

@test "validate names the first fault when two rules are broken at once" {
  bash "$PROG" init 001-demo b main web
  sf=.delivery-kit/runs/001-demo/progress.json
  cp "$sf" good.json
  jq 'del(.artifacts) | del(.gates)' good.json > "$sf"
  run bash "$PROG" validate 001-demo
  [ "$output" = "progress.sh: $sf is missing required key 'gates'" ]
  jq '.completed_phases = "x" | .current_phase = "ZZZ"' good.json > "$sf"
  run bash "$PROG" validate 001-demo
  [ "$output" = "progress.sh: $sf: completed_phases must be an array" ]
}

@test "validate prints a current_phase that is not a string as jq prints it" {
  bash "$PROG" init 001-demo b main web
  sf=.delivery-kit/runs/001-demo/progress.json
  jq '.current_phase = 5' "$sf" > t.json
  mv t.json "$sf"
  run bash "$PROG" validate 001-demo
  [ "$status" -eq 1 ]
  [ "$output" = "progress.sh: $sf: current_phase '5' is not a phase this pipeline knows" ]
  jq '.current_phase = null' "$sf" > t.json
  mv t.json "$sf"
  run bash "$PROG" validate 001-demo
  [ "$output" = "progress.sh: $sf: current_phase '' is not a phase this pipeline knows" ]
}

@test "validate spawns ONE jq process on a valid state file" {
  # The point of the one program: a jq that cannot run it would fall back to
  # the per-check form and stay green everywhere else, only slower. A shim on
  # PATH counts the processes, and the count is the assertion.
  bash "$PROG" init 001-demo b main web
  real="$(command -v jq)"
  mkdir -p shim
  printf '#!/usr/bin/env bash\nprintf x >> "%s/jq.log"\nexec "%s" "$@"\n' "$PWD" "$real" > shim/jq
  chmod +x shim/jq
  : > jq.log
  PATH="$PWD/shim:$PATH" run bash "$PROG" validate 001-demo
  [ "$status" -eq 0 ]
  [ "$(cat jq.log)" = "x" ]
  # And the shim is live: the fallback a two-document file takes counts more.
  sf=.delivery-kit/runs/001-demo/progress.json
  jq -c . "$sf" > two.json; jq -c . "$sf" >> two.json; mv two.json "$sf"
  : > jq.log
  PATH="$PWD/shim:$PATH" run bash "$PROG" validate 001-demo
  [ "$(wc -c < jq.log)" -gt 1 ]
}
