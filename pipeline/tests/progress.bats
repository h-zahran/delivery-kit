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
  # three names were substrings; measured, it is exactly one.)
  [[ "$output" == *"<init|read|validate|phase-start|phase-done|from-validate|lock-take|lock-release>"* ]]
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
