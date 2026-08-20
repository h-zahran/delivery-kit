#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Cheap insurance: find_root no longer walks, but a regression that
# reintroduces one gets a named timeout instead of GitHub's 360-minute job cap.
BATS_TEST_TIMEOUT=10

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
