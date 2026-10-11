#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load helper

@test "ROOT resolves to the directory holding the marketplace manifest" {
  [ -n "$ROOT" ]
  [ -f "$ROOT/.claude-plugin/marketplace.json" ]
}

@test "find_root answers the manifest directory itself, in pwd form" {
  # The inclusive, zero-iteration case, kept as a contract: handed the
  # repository root, find_root returns it rather than a parent — and returns
  # it in the form pwd prints. The right-hand side is computed by pwd
  # directly rather than taken from $ROOT, because $ROOT comes from this
  # same function: compared against itself, the equality held with the
  # normalisation deleted (measured), a pin that pinned nothing.
  run find_root "$ROOT"
  [ "$status" -eq 0 ]
  [ "$output" = "$(cd "$ROOT" && pwd)" ]
}

@test "find_root refuses to escape the checkout it started in" {
  # The bug the rev-parse rewrite fixes. Worktrees sit INSIDE the main
  # working tree, so a walk that left a manifest-less checkout landed on a
  # REAL manifest one level up and the suite silently examined the wrong
  # repository. The fixture is exactly that shape: an outer checkout holding
  # a manifest, an inner checkout without one. The right answer is refusal,
  # not the outer root.
  mkdir -p "$TEST_DIR/outer/.claude-plugin" "$TEST_DIR/outer/inner/deep"
  git init -q "$TEST_DIR/outer"
  printf '{}\n' > "$TEST_DIR/outer/.claude-plugin/marketplace.json"
  git init -q "$TEST_DIR/outer/inner"
  # The fixture must really be two checkouts for the refusal below to mean
  # anything: if both git inits failed, this collapses into test 4's case
  # and passes having exercised no boundary. Prove the outer half resolves
  # before asserting the inner half refuses.
  run find_root "$TEST_DIR/outer"
  [ "$status" -eq 0 ]
  run find_root "$TEST_DIR/outer/inner/deep"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "find_root fails with empty output outside any checkout" {
  # TEST_DIR is a mktemp directory in the system temp, which is not a git
  # checkout. Empty output is asserted so a caller capturing it could never
  # cd somewhere accidental.
  run find_root "$TEST_DIR"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

# helper.bash resolves ROOT once per file and hands it to every test through
# an exported cache, keyed by the bats run and the suite directory. These run
# the helper's load in a child bash with the cache variables set by hand, so
# each edge of the key is fired directly rather than inferred from a green.
load_helper_with() {
  # <run tmpdir> <cached root> <cached key> -> prints "<ROOT>|<key after load>"
  run bash -c '
    export BATS_TEST_DIRNAME="$1" BATS_RUN_TMPDIR="$2" DK_SUITE_ROOT="$3" DK_SUITE_ROOT_KEY="$4"
    . "$1/helper.bash" || exit 97
    printf "%s|%s" "$ROOT" "$DK_SUITE_ROOT_KEY"
  ' _ "$BATS_TEST_DIRNAME" "$@"
}

@test "every test inherits the ROOT its file resolved, under this run's key" {
  [ "$DK_SUITE_ROOT_KEY" = "$BATS_RUN_TMPDIR|$BATS_TEST_DIRNAME" ]
  [ "$ROOT" = "$DK_SUITE_ROOT" ]
  [ "$ROOT" = "$(find_root "$BATS_TEST_DIRNAME")" ]
}

@test "a cached ROOT under a matching key is used without recomputing" {
  # The sentinel is not a checkout: find_root could never return it, so seeing
  # it come back proves the cache was read and find_root was not run.
  load_helper_with /run-a /no/such/sentinel "/run-a|$BATS_TEST_DIRNAME"
  [ "$status" -eq 0 ]
  [ "$output" = "/no/such/sentinel|/run-a|$BATS_TEST_DIRNAME" ]
}

@test "a cached ROOT under any other key is recomputed, never believed" {
  real="$(find_root "$BATS_TEST_DIRNAME")"
  # Another bats run (the developer's shell, or a run before this one).
  load_helper_with /run-b /no/such/sentinel "/run-a|$BATS_TEST_DIRNAME"
  [ "$status" -eq 0 ]
  [ "$output" = "$real|/run-b|$BATS_TEST_DIRNAME" ]
  # The same run, another suite directory.
  load_helper_with /run-a /no/such/sentinel "/run-a|$BATS_TEST_DIRNAME/other"
  [ "$status" -eq 0 ]
  [ "$output" = "$real|/run-a|$BATS_TEST_DIRNAME" ]
  # Outside bats: no run directory, even with a key that matches its empty form.
  load_helper_with "" /no/such/sentinel "|$BATS_TEST_DIRNAME"
  [ "$status" -eq 0 ]
  [ "$output" = "$real||$BATS_TEST_DIRNAME" ]
  # A matching key with an empty cached value.
  load_helper_with /run-a "" "/run-a|$BATS_TEST_DIRNAME"
  [ "$status" -eq 0 ]
  [ "$output" = "$real|/run-a|$BATS_TEST_DIRNAME" ]
}

@test "setup unsets every DELIVERY_KIT_ variable, including names not yet used" {
  # The five the shipped code reads, plus an invented sixth: setup must clear
  # them all, so nothing exported on a runner or a developer machine reaches
  # a test. Run in a child bash, because this test's own environment has
  # already been through setup and would prove nothing.
  run bash -c '
    export DELIVERY_KIT_WINDOW_TOKENS=1 DELIVERY_KIT_THRESHOLD_PCT=2 DELIVERY_KIT_HANDOFF_DIR=3
    export DELIVERY_KIT_THRESHOLD_TOKENS=4 DELIVERY_KIT_MAX_BYTES=5 DELIVERY_KIT_NOT_YET_NAMED=6
    export BATS_TEST_DIRNAME="$1"
    . "$1/helper.bash" || exit 97
    setup || exit 98
    left="${!DELIVERY_KIT_@}"
    teardown
    printf "left:%s" "$left"
  ' _ "$BATS_TEST_DIRNAME"
  [ "$status" -eq 0 ] || { echo "the child failed: $output"; false; }
  [ "$output" = "left:" ] || { echo "setup left these set: $output"; false; }
}
