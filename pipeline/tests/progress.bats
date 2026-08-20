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
