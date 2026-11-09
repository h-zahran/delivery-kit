#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for the eval cases in pipeline/evals/. The cases themselves need a
# model and are billed, so they run only by hand; this suite runs what needs
# no model: each case's fixture.sh, which builds its repository with the
# plugin's own progress.sh. A change to progress.sh that breaks a case goes
# red here, for free, before anyone pays for a run that scores 0.

load ../../tests/helper

setup() {
  EVALS="$ROOT/pipeline/evals"
  F=001-greeting
}

# cases — every folder under pipeline/evals that holds a prompt.md or a
# case.yaml, which is what makes it a case. Derived, never listed.
cases() {
  local d
  for d in "$EVALS"/*/; do
    d="${d%/}"
    { [ -f "$d/prompt.md" ] || [ -f "$d/case.yaml" ]; } && printf '%s\n' "${d##*/}"
  done
  return 0
}

# build <case> — runs the case's fixture.sh in a new empty folder, as the
# eval's scaffold step does, checks the run it built waits at K, is valid
# and holds no lock, and leaves the shell in that folder.
#
# One build per test: a fixture makes some forty progress.sh calls, which
# take 22 to 34 s on the Windows runner, so two builds in one test passed
# 60 s there.
build() {
  WS="$BATS_TEST_TMPDIR/ws-$1"
  mkdir -p "$WS"
  cd "$WS"
  run bash "$EVALS/$1/fixture.sh"
  [ "$status" -eq 0 ] || { echo "$1: fixture.sh exited $status: $output"; return 1; }
  [ "$(bash "$ROOT/pipeline/scripts/progress.sh" get "$F" current_phase)" = K ] \
    || { echo "$1: the run does not wait at K"; return 1; }
  bash "$ROOT/pipeline/scripts/progress.sh" validate "$F" > /dev/null || { echo "$1: the state file does not validate"; return 1; }
  [ ! -e ".delivery-kit/lock" ] \
    || { echo "$1: a lock was left, so a resume would stop on it, not on the stop the case checks"; return 1; }
}

@test "there are eval cases, and each has a grader, names fixture.sh, and is built by a test of its own" {
  local list c n=0
  list="$(cases)"
  [ -n "$list" ] || { echo "pipeline/evals holds no case"; false; }
  while IFS= read -r c; do
    compgen -G "$EVALS/$c/graders/*.md" > /dev/null || { echo "$c has no grader"; false; }
    grep -qxF '  scaffold_script: fixture.sh' "$EVALS/$c/case.yaml" || { echo "$c does not name fixture.sh as its scaffold"; false; }
    grep -qxF "  build $c || return 1" "$BATS_TEST_FILENAME" \
      || { echo "$c has no test that builds it: add one that calls build $c"; false; }
    n=$((n + 1))
  done <<<"$list"
  [ "$n" -ge 2 ] || { echo "only $n case(s) found"; false; }
}

@test "the outside-path case leaves one untracked path outside the feature, and K would list it" {
  build k-auto-stops-on-outside-path || return 1
  [ "$(git status --porcelain)" = '?? notes/' ] || { echo "unexpected tree: $(git status --porcelain)"; false; }
  run bash "$ROOT/pipeline/scripts/progress.sh" commit-list "$F"
  [ "$status" -eq 0 ] || { echo "commit-list failed: $output"; false; }
  [[ $output == *'! notes/scratch.txt'* ]] || { echo "commit-list does not mark notes/scratch.txt outside the feature: $output"; false; }
}

@test "the tracked-state case commits the state file and leaves a clean tree" {
  build tracked-state-stops-a-resume || return 1
  [ -z "$(git status --porcelain)" ] || { echo "the tree is not clean: $(git status --porcelain)"; false; }
  [ "$(git ls-files .delivery-kit)" = ".delivery-kit/runs/$F/progress.json" ] \
    || { echo "the state file is not the one tracked path under .delivery-kit: $(git ls-files .delivery-kit)"; false; }
}
