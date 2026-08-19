#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# A deadline, because the third test's failure mode is a spin rather than a
# wrong answer. bats 1.11 applies no default timeout and ci.yml sets no
# timeout-minutes, so a reintroduced non-terminating walk would run until
# GitHub's own 360-minute job cap on each of the three matrix runners and
# report as CI timing out rather than as a broken search — which is the one
# reading the test below is written to prevent. Ten seconds is orders of
# magnitude more than the walk needs; it turns the hang into a named failure.
BATS_TEST_TIMEOUT=10

load helper

# `find_root` replaces a fixed "${BATS_TEST_DIRNAME}/.." because two suites sit
# at different depths. A wrong root is not reliably caught downstream, and is
# caught in fewer places than it was before Task 2: portability.bats's SKILL.md
# search now walks `$ROOT` itself rather than `$ROOT/skills`, so any ancestor
# of the true root still finds the same files beneath it and that test's
# non-empty pin passes without noticing. The version gate's `checked` guard
# and the SHIPPED scans still shout, but the optional git-ignored `.leakwords`
# is folded into BANNED_WORDS only `if [ -f "$ROOT/.leakwords" ]` — now very
# nearly the only silent path — so a wrong root drops every private term and
# leaves the leak scan green on a narrower list. The search having lost its
# one downstream detector is exactly why it is tested here rather than
# trusted, in all three directions.

@test "ROOT resolves to the directory holding the marketplace manifest" {
  [ -n "$ROOT" ]
  [ -f "$ROOT/.claude-plugin/marketplace.json" ]
}

@test "find_root stops at the NEAREST manifest, not the outermost" {
  # Two manifests on one walk. TEST_DIR is a mktemp directory in the system
  # temp rather than inside this repository, so nothing above `outer` holds a
  # manifest and an overshoot would just walk to / and return 1. The outer
  # fixture is what makes the assertion discriminating: a search that keeps
  # going past the first hit answers `outer`, and the equality below names
  # `inner`, so this is the only test that can tell "found the nearest" from
  # "found any".
  mkdir -p "$TEST_DIR/outer/.claude-plugin" "$TEST_DIR/outer/inner/.claude-plugin/deep"
  printf '{}\n' > "$TEST_DIR/outer/.claude-plugin/marketplace.json"
  printf '{}\n' > "$TEST_DIR/outer/inner/.claude-plugin/marketplace.json"

  run find_root "$TEST_DIR/outer/inner/.claude-plugin/deep"
  [ "$status" -eq 0 ]
  [ "$output" = "$(cd "$TEST_DIR/outer/inner" && pwd)" ]
}

@test "find_root terminates instead of walking to / forever" {
  # The positive control for the loop guard. Without the parent-equals-self
  # check this hangs until bats times out, which reads as an unrelated failure.
  run find_root "$TEST_DIR"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}
