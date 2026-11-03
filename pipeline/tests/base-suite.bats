#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for progress.sh's base suite run (feature 053): `suite-base <feature>
# start` runs the full test command in the background on a detached checkout
# of HEAD's commit and records the result with the same key and writer as
# suite-record, so F.5's `suite-lookup --base` can cite it; `suite-base
# <feature> wait` waits for it in slices. Every test builds its own throwaway
# repository under $BATS_TEST_TMPDIR, and stops only processes whose ids the
# run recorded or the test started itself.
#
# PROGRESS_SH_UNDER_TEST points the suite at another copy of the script, for
# mutation runs: mutate a copy, point the suite at it, watch a test go red.

load ../../tests/helper

setup() {
  PROG="${PROGRESS_SH_UNDER_TEST:-$ROOT/pipeline/scripts/progress.sh}"
  [ -f "$PROG" ] || { echo "no script at $PROG"; return 1; }
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"
  cd "$WORK"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export GIT_CONFIG_NOSYSTEM=1
  export XDG_CONFIG_HOME="$HOME/.config"
  export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
  # The runner's checkout and temporary folders go under this test's own
  # folder, so nothing outlives the test.
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$TMPDIR"
  F=001-demo
  BD=".delivery-kit/runs/$F/base-suite"
  OUT="$BATS_TEST_TMPDIR/out.txt"
  ERR="$BATS_TEST_TMPDIR/err.txt"
  GREEN="printf '1..1\\nok 1 a\\n'"
  RED="printf '1..1\\nnot ok 1 a\\n'; exit 1"
  OWN=()
}

# teardown — stops the runner and its child by the ids the run recorded, and
# every process this test started (OWN), then removes any checkout left.
teardown() {
  local f p
  for f in .delivery-kit/runs/*/base-suite/pid .delivery-kit/runs/*/base-suite/child; do
    [ -f "$f" ] || continue
    p="$(cat "$f")"
    case "$p" in ''|*[!0-9]*) continue ;; esac
    kill "$p" 2>/dev/null || true
  done
  for p in ${OWN[@]+"${OWN[@]}"}; do kill "$p" 2>/dev/null || true; done
  if [ -d .git ]; then
    git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | sed 1d | while IFS= read -r p; do
      git worktree remove --force "$p" 2>/dev/null || true
    done
  fi
}

# repo [<command>] — a committed tree, a state file for $F whose
# config.testCommand is the command ($GREEN when none is given), and the
# run's untracked spec directory recorded as artifacts.spec, as B leaves it.
repo() {
  git init -q .
  git symbolic-ref HEAD refs/heads/main
  git config user.name test
  git config user.email test@example.invalid
  git config commit.gpgsign false
  git config core.autocrlf false
  git config core.hooksPath "$BATS_TEST_TMPDIR/hooks"
  mkdir -p src
  printf 'base\n' > README.md
  printf 'keep\n' > src/keep.sh
  printf '*.log\n' > .gitignore
  git add README.md src/keep.sh .gitignore
  git commit -q -m base
  state "$F" "${1:-$GREEN}" specs/001-demo
}

# state <feature> <command> <spec dir> — the run's state file and its
# untracked spec file.
state() {
  local sf=".delivery-kit/runs/$1/progress.json"
  bash "$PROG" init "$1" "$1" main other > /dev/null
  mkdir -p "$3"
  printf '# spec\n' > "$3/spec.md"
  jq --arg c "$2" --arg s "$3/spec.md" '.config.testCommand = $c | .artifacts.spec = $s' "$sf" > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" "$sf"
}

# reuse <mode> — config.suiteReuse for $F.
reuse() {
  local sf=".delivery-kit/runs/$F/progress.json"
  jq --arg m "$1" '.config.suiteReuse = $m' "$sf" > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" "$sf"
}

# runs <args...> — the script, stdout to $OUT, stderr to $ERR; exit 0.
runs() {
  local rc=0
  bash "$PROG" "$@" > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -eq 0 ] || { echo "exit $rc, expected 0: $(cat "$ERR")"; return 1; }
}

# outcome_wait [<feature>] — polls the runner's outcome file every 0.2 s
# for at most 30 s; a loop with its own counter, never a bare wait, which
# would wait for bats' own timeout watcher too.
outcome_wait() {
  local d=".delivery-kit/runs/${1:-$F}/base-suite" n=0
  while [ ! -f "$d/outcome" ]; do
    n=$((n + 1))
    [ "$n" -le 150 ] || { echo "no outcome after 30 s; runner.log: $(cat "$d/runner.log" 2>/dev/null)"; return 1; }
    sleep 0.2
  done
  OUTCOME="$(cat "$d/outcome")"
}

# others — how many worktrees git lists besides the main one.
others() { git worktree list --porcelain | grep -c '^worktree ' | awk '{ print $1 - 1 }'; }

@test "start records a green result F.5's --base lookup finds" {
  # Mutation: record under the main tree's key (with the spec directory) or
  # skip the record, and the lookup below exits 1.
  repo
  local head; head="$(git rev-parse HEAD)"
  runs suite-base "$F" start
  [[ "$(cat "$OUT")" == "base suite started on commit $head (process "*")" ]] || { echo "start said: $(cat "$OUT")"; false; }
  outcome_wait
  [ "$OUTCOME" = green ] || { echo "outcome '$OUTCOME'; log: $(cat "$BD/runner.log")"; false; }
  runs suite-lookup "$F" --base
  [[ "$(sed -n 2p "$OUT")" == *"on commit $head, command "* ]] || { echo "lookup said: $(cat "$OUT")"; false; }
  [[ "$(sed -n 2p "$OUT")" == *"— for these files without the untracked specs/001-demo/" ]] || { echo "lookup said: $(cat "$OUT")"; false; }
}

@test "a red run is recorded red and never cited" {
  # Mutation: record every run green, and the lookup exits 0.
  repo "$RED"
  runs suite-base "$F" start
  outcome_wait
  [ "$OUTCOME" = red ] || { echo "outcome '$OUTCOME'"; false; }
  run -1 bash "$PROG" suite-lookup "$F" --base
  [[ "$output" == *"is red, and a red result is never reused"* ]] || { echo "$output"; false; }
}

@test "a tracked file changed in the main tree after the record is a miss" {
  repo
  runs suite-base "$F" start
  outcome_wait
  [ "$OUTCOME" = green ]
  printf 'changed\n' >> README.md
  run -1 bash "$PROG" suite-lookup "$F" --base
  [[ "$output" == *"none is recorded"* ]] || { echo "$output"; false; }
}

@test "suiteReuse off starts nothing" {
  # Mutation: drop the suite_config check, and a runner starts.
  repo
  reuse off
  runs suite-base "$F" start
  [[ "$(cat "$OUT")" == "base suite not started: config.suiteReuse is off"* ]] || { echo "start said: $(cat "$OUT")"; false; }
  [ ! -e "$BD" ] || { echo "a bookkeeping folder was made"; false; }
  [ "$(others)" = 0 ]
}

@test "a green result already recorded for the base files starts nothing" {
  repo
  runs suite-base "$F" start
  outcome_wait
  [ "$OUTCOME" = green ]
  # A later run on the same commit, with only its own spec directory new.
  rm -rf specs/001-demo
  state 002-next "$GREEN" specs/002-next
  runs suite-base 002-next start
  [ "$(cat "$OUT")" = "base suite not started: a green result is already recorded for commit $(git rev-parse HEAD)" ] \
    || { echo "start said: $(cat "$OUT")"; false; }
  [ ! -e .delivery-kit/runs/002-next/base-suite ]
}

@test "start twice starts one runner" {
  repo "sleep 3; $GREEN"
  runs suite-base "$F" start
  runs suite-base "$F" start
  [ "$(cat "$OUT")" = "base suite already started on commit $(git rev-parse HEAD)" ] || { echo "second start said: $(cat "$OUT")"; false; }
  [ "$(others)" = 1 ] || { echo "$(others) checkouts besides the main tree"; false; }
  outcome_wait
  [ "$OUTCOME" = green ]
}

@test "the main tree's HEAD, index, refs and files are untouched, and the checkout is removed" {
  # Mutation: run the command in the main tree instead of the checkout, and
  # the status bytes or the worktree count below change.
  repo
  local before after
  before="$(git rev-parse HEAD; git symbolic-ref HEAD; git status --porcelain=v1 -z | od -c; git ls-files -s; git for-each-ref)"
  runs suite-base "$F" start
  outcome_wait
  [ "$OUTCOME" = green ]
  after="$(git rev-parse HEAD; git symbolic-ref HEAD; git status --porcelain=v1 -z | od -c; git ls-files -s; git for-each-ref)"
  [ "$before" = "$after" ] || { diff <(printf '%s\n' "$before") <(printf '%s\n' "$after"); false; }
  [ "$(others)" = 0 ] || { git worktree list; false; }
}

@test "the runner's TMPDIR is its own, and gone afterwards" {
  # The comment comes after the plan line: the green rule wants the plan first.
  repo "printf '1..1\\nok 1 a\\n# tmp=%s\\n' \"\$TMPDIR\""
  runs suite-base "$F" start
  outcome_wait
  [ "$OUTCOME" = green ] || { echo "outcome '$OUTCOME'; tap: $(cat "$BD/suite.tap")"; false; }
  local t; t="$(sed -n 's/^# tmp=//p' "$BD/suite.tap")"
  [ -n "$t" ] && [ "$t" != "$TMPDIR" ] || { echo "the runner's TMPDIR was '$t'"; false; }
  [ ! -e "$t" ] || { echo "$t was left behind"; false; }
}

@test "a run that leaves a file in its checkout records nothing" {
  # Mutation: skip the second key, and the leftover file is recorded green.
  repo ": > left.txt; $GREEN"
  runs suite-base "$F" start
  outcome_wait
  [[ "$OUTCOME" == "nothing recorded — "* ]] || { echo "outcome '$OUTCOME'"; false; }
  run -1 bash "$PROG" suite-lookup "$F" --base
}

@test "one key and one record writer" {
  # Principle IV: the runner reuses the key and the writer; a second copy of
  # either would drift.
  local script="$ROOT/pipeline/scripts/progress.sh" n
  # shellcheck disable=SC2016 # literal jq text
  n="$(grep -cF -- '{mode: $m, head: $h, files: $b, command: $c, platform: $p}' "$script")"
  [ "$n" = 1 ] || { echo "the key's template occurs $n times"; false; }
  n="$(grep -cF -- 'recordedAt: $at' "$script")"
  [ "$n" = 1 ] || { echo "the record's template occurs $n times"; false; }
  local body
  body="$(sed -n '/^base_run() {/,/^}/p' "$script")"
  [[ "$body" == *suite_key_here* ]] || { echo "the runner does not call suite_key_here"; false; }
  [[ "$body" == *suite_write_record* ]] || { echo "the runner does not call suite_write_record"; false; }
}
