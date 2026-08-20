#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for pipeline/scripts/preflight.sh — detection and probe. Fixture
# directories sit INSIDE this repository, so git facts read from them
# belong to the enclosing checkout — which is why no fixture test asserts
# baseBranch or remote, and why those assertions get their own scratch
# repositories below. The --base-branch flag on fixture runs is a
# formality: where the checkout publishes origin/HEAD, that wins by
# design.

load ../../tests/helper

setup() {
  PF="$ROOT/pipeline/scripts/preflight.sh"
  FIX="$ROOT/pipeline/tests/fixtures"
}

@test "the web fixture detects web, from the package.json toolchain" {
  run --separate-stderr bash "$PF" --dir "$FIX/web" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.projectType' <<<"$output")" = "web" ]
  [ "$(jq -r '.projectTypeSource' <<<"$output")" = "package.json toolchain" ]
}

@test "the mobile-android fixture detects mobile-android" {
  run --separate-stderr bash "$PF" --dir "$FIX/mobile-android" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.projectType' <<<"$output")" = "mobile-android" ]
}

@test "the other fixture detects other, by default" {
  run --separate-stderr bash "$PF" --dir "$FIX/other" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.projectType' <<<"$output")" = "other" ]
  [ "$(jq -r '.projectTypeSource' <<<"$output")" = "default" ]
}

@test "--project-type overrides detection and says so" {
  run --separate-stderr bash "$PF" --dir "$FIX/web" --base-branch main --project-type other
  [ "$status" -eq 0 ]
  [ "$(jq -r '.projectType' <<<"$output")" = "other" ]
  [ "$(jq -r '.projectTypeSource' <<<"$output")" = "override" ]
}

@test "the no-speckit fixture reports the tool absent, exit 0 -- reporting is not failing" {
  run --separate-stderr bash "$PF" --dir "$FIX/no-speckit" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.present' <<<"$output")" = "false" ]
}

@test "the web fixture reads version and sh flavour, resolving the bash scripts dir" {
  run --separate-stderr bash "$PF" --dir "$FIX/web" --base-branch main
  [ "$(jq -r '.speckit.version' <<<"$output")" = "0.16.5" ]
  [ "$(jq -r '.speckit.script' <<<"$output")" = "sh" ]
  [ "$(jq -r '.speckit.scriptsDir' <<<"$output")" = ".specify/scripts/bash" ]
  [ "$(jq -r '.speckit.versionInRange' <<<"$output")" = "true" ]
}

@test "the mobile-android fixture's ps flavour resolves the powershell scripts dir" {
  run --separate-stderr bash "$PF" --dir "$FIX/mobile-android" --base-branch main
  [ "$(jq -r '.speckit.script' <<<"$output")" = "ps" ]
  [ "$(jq -r '.speckit.scriptsDir' <<<"$output")" = ".specify/scripts/powershell" ]
}

@test "the py flavour is handled loudly: exit 0, empty scriptsDir, stderr names it" {
  run --separate-stderr bash "$PF" --dir "$FIX/other" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.script' <<<"$output")" = "py" ]
  [ "$(jq -r '.speckit.scriptsDir' <<<"$output")" = "" ]
  [[ "$stderr" == *"'py'"* ]]
}

@test "an out-of-range version warns on stderr and continues" {
  run --separate-stderr bash "$PF" --dir "$FIX/other" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.versionInRange' <<<"$output")" = "false" ]
  [[ "$stderr" == *"0.14.0"* ]]
}

@test "an illegal script flavour fails loudly, naming the value" {
  T="$BATS_TEST_TMPDIR/bad"
  mkdir -p "$T/.specify/templates" "$T/.specify/scripts"
  printf '{ "speckit_version": "0.16.5", "script": "bat" }\n' > "$T/.specify/init-options.json"
  run --separate-stderr bash "$PF" --dir "$T" --base-branch main
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'bat'"* ]]
}

@test "a hyphen-skill install is recorded as hyphen-skills" {
  run --separate-stderr bash "$PF" --dir "$FIX/web" --base-branch main
  [ "$(jq -r '.speckit.invocationForm' <<<"$output")" = "hyphen-skills" ]
}

@test "a dot-command install is recorded as dot-commands" {
  run --separate-stderr bash "$PF" --dir "$FIX/mobile-android" --base-branch main
  [ "$(jq -r '.speckit.invocationForm' <<<"$output")" = "dot-commands" ]
}

@test "remote classification: none, github, other" {
  T="$BATS_TEST_TMPDIR/remote"
  mkdir -p "$T"; cd "$T"; git init -q .
  run --separate-stderr bash "$PF" --dir "$T" --base-branch main
  [ "$(jq -r '.remote.kind' <<<"$output")" = "none" ]
  git remote add origin https://github.com/example/thing.git
  run --separate-stderr bash "$PF" --dir "$T" --base-branch main
  [ "$(jq -r '.remote.kind' <<<"$output")" = "github" ]
  git remote set-url origin https://gitlab.example.com/x/y.git
  run --separate-stderr bash "$PF" --dir "$T" --base-branch main
  [ "$(jq -r '.remote.kind' <<<"$output")" = "other" ]
}

@test "base branch: origin/HEAD first, then the override, each with its source" {
  T="$BATS_TEST_TMPDIR/base"
  mkdir -p "$T"; cd "$T"; git init -q -b work .
  run --separate-stderr bash "$PF" --dir "$T" --base-branch trunk
  [ "$(jq -r '.baseBranch' <<<"$output")" = "trunk" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "configured" ]
  git remote add origin https://github.com/example/thing.git
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  run --separate-stderr bash "$PF" --dir "$T" --base-branch trunk
  [ "$(jq -r '.baseBranch' <<<"$output")" = "main" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "origin/HEAD" ]
}

@test "stdout is pure JSON even when stderr is talking" {
  run --separate-stderr bash "$PF" --dir "$FIX/other" --base-branch main
  jq -e . <<<"$output" > /dev/null
  [ -n "$stderr" ]
}

@test "capabilities reports jq true and booleans for gh and adb" {
  run --separate-stderr bash "$PF" --dir "$FIX/web" --base-branch main
  [ "$(jq -r '.capabilities.jq' <<<"$output")" = "true" ]
  [[ "$(jq -r '.capabilities.gh' <<<"$output")" =~ ^(true|false)$ ]]
  [[ "$(jq -r '.capabilities.adb' <<<"$output")" =~ ^(true|false)$ ]]
}

@test "willSkip names phases L and M in a repository with no remote" {
  T="$BATS_TEST_TMPDIR/skips"
  mkdir -p "$T"; cd "$T"; git init -q .
  run --separate-stderr bash "$PF" --dir "$T" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '[.willSkip[].phase] | index("L") != null' <<<"$output")" = "true" ]
  [ "$(jq -r '[.willSkip[].phase] | index("M") != null' <<<"$output")" = "true" ]
}

@test "tree reports dirty and runsLive from the facts on disk" {
  T="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$T"; cd "$T"; git init -q .
  run --separate-stderr bash "$PF" --dir "$T" --base-branch main
  [ "$(jq -r '.tree.dirty' <<<"$output")" = "false" ]
  [ "$(jq -r '.tree.runsLive' <<<"$output")" = "false" ]
  printf 'x' > dirt.txt
  mkdir -p .delivery-kit/runs/001-x
  printf '{"current_phase":"B"}' > .delivery-kit/runs/001-x/progress.json
  run --separate-stderr bash "$PF" --dir "$T" --base-branch main
  [ "$(jq -r '.tree.dirty' <<<"$output")" = "true" ]
  [ "$(jq -r '.tree.runsLive' <<<"$output")" = "true" ]
}
