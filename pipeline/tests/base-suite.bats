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
  local d f p n
  # Only a runner that has not written its outcome is still ours to stop: an
  # id recorded by a runner that ended may belong to another process now.
  for d in .delivery-kit/runs/*/base-suite; do
    [ -d "$d" ] && [ ! -f "$d/outcome" ] || continue
    for f in "$d/pid" "$d/child"; do
      p="$(cat "$f" 2>/dev/null || true)"
      case "$p" in ''|*[!0-9]*) continue ;; esac
      kill "$p" 2>/dev/null || true
      n=0; while kill -0 "$p" 2>/dev/null && [ "$n" -lt 25 ]; do n=$((n + 1)); sleep 0.2; done
    done
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
  [[ "$(cat "$OUT")" == "base suite started on commit $head (process "*"), command \"printf "* ]] || { echo "start said: $(cat "$OUT")"; false; }
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
  bash "$PROG" suite-base "$F" wait > "$OUT"
  [ "$(cat "$OUT")" = "base suite ended: red" ] || { echo "wait said: $(cat "$OUT")"; false; }
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

@test "a state file with no usable test command starts nothing, says so and exits 3" {
  # Feature 058: exit 0 here read as a legal "not started", and run 056's
  # ordering fault hid behind it. Mutation: make this path exit 0 or 1, and the
  # status check goes red; start a runner anyway, and the folder or the process
  # check goes red.
  local sf edit rc
  repo
  sf=".delivery-kit/runs/$F/progress.json"
  for edit in 'del(.config.testCommand)' '.config.testCommand = null' '.config.testCommand = ""' '.config.testCommand = 42'; do
    jq "$edit" "$sf" > "$BATS_TEST_TMPDIR/t.json"
    mv "$BATS_TEST_TMPDIR/t.json" "$sf"
    rc=0; bash "$PROG" suite-base "$F" start > "$OUT" 2> "$ERR" || rc=$?
    [ "$rc" -eq 3 ] || { echo "status $rc, after $edit: $(cat "$ERR")"; false; }
    [[ "$(cat "$OUT")" == "base suite not started: config.testCommand is not recorded as a string in "* ]] \
      || { echo "start said, after $edit: $(cat "$OUT")"; false; }
    [ ! -e "$BD" ] || { echo "a bookkeeping folder was made, after $edit"; false; }
    [ "$(others)" = 0 ]
  done
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

@test "the main tree's HEAD, index, refs, files and state file are untouched, and the checkout is removed" {
  # Mutation: have the runner write the state file, or leave its checkout
  # behind, and the snapshot or the worktree count below changes. (Running
  # the command in the main tree is caught by the moved-file tests.)
  repo
  local before after
  before="$(git rev-parse HEAD; git symbolic-ref HEAD; git status --porcelain=v1 -z | od -c; git ls-files -s; git for-each-ref; cksum < ".delivery-kit/runs/$F/progress.json")"
  runs suite-base "$F" start
  outcome_wait
  [ "$OUTCOME" = green ]
  after="$(git rev-parse HEAD; git symbolic-ref HEAD; git status --porcelain=v1 -z | od -c; git ls-files -s; git for-each-ref; cksum < ".delivery-kit/runs/$F/progress.json")"
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
  local script="$PROG" n
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

# gone <pid> — true once the process has ended, polled for at most 5 s: a
# stopped process can take a moment to be reaped.
gone() {
  local n=0
  while kill -0 "$1" 2>/dev/null; do
    n=$((n + 1)); [ "$n" -le 25 ] || return 1
    sleep 0.2
  done
}

# waits <args...> — suite-base wait, its exit status in WRC, stdout in $OUT.
waits() {
  WRC=0
  bash "$PROG" suite-base "$F" wait "$@" > "$OUT" 2> "$ERR" || WRC=$?
}

@test "wait says when none was started" {
  repo
  waits
  [ "$WRC" = 0 ] || { echo "exit $WRC: $(cat "$ERR")"; false; }
  [ "$(cat "$OUT")" = "no base suite was started for this run" ]
}

@test "wait returns when the runner ends" {
  repo
  runs suite-base "$F" start
  waits --slice 30
  [ "$WRC" = 0 ] || { echo "exit $WRC: $(cat "$OUT") $(cat "$ERR")"; false; }
  [ "$(cat "$OUT")" = "base suite ended: green" ] || { echo "wait said: $(cat "$OUT")"; false; }
}

@test "wait gives back control while the runner works" {
  # Mutation: ignore the slice, and this call blocks until the limit.
  repo "exec sleep 20"
  runs suite-base "$F" start
  waits --slice 1 --limit 60
  [ "$WRC" = 2 ] || { echo "exit $WRC: $(cat "$OUT") $(cat "$ERR")"; false; }
  [[ "$(cat "$OUT")" == "base suite still running after "* ]] || { echo "wait said: $(cat "$OUT")"; false; }
}

@test "wait stops only its own runner at the limit" {
  # Mutation: drop the stop, and the runner and its child live on.
  repo "exec sleep 60"
  sleep 60 3>&- &
  OWN+=("$!")
  runs suite-base "$F" start
  local n=0
  while [ ! -s "$BD/child" ]; do n=$((n + 1)); [ "$n" -le 50 ] || { echo "the command never started"; false; }; sleep 0.2; done
  local i=0 t0
  waits --slice 1 --limit 2
  t0="$(date +%s)"
  while [ "$WRC" = 2 ] && [ "$i" -lt 10 ]; do i=$((i + 1)); t0="$(date +%s)"; waits --slice 1 --limit 2; done
  # The TERM reaches the runner's group, so the stop takes well under the
  # 10 s fallback. Mutation: drop the TERM, and only the fallback stops it.
  [ $(( $(date +%s) - t0 )) -lt 8 ] || { echo "the stopping call took the fallback's 10 s"; false; }
  [ "$WRC" = 0 ] || { echo "exit $WRC: $(cat "$OUT") $(cat "$ERR")"; false; }
  [ "$(cat "$OUT")" = "base suite stopped at the 2 s limit" ] || { echo "wait said: $(cat "$OUT")"; false; }
  gone "$(cat "$BD/pid")" || { echo "the runner is still alive"; false; }
  gone "$(cat "$BD/child")" || { echo "the runner's command is still alive"; false; }
  kill -0 "${OWN[0]}" || { echo "a process the run did not start was stopped"; false; }
  [ "$(others)" = 0 ] || { git worktree list; false; }
}

@test "a runner that stopped reporting is never signalled" {
  # Mutation: drop the heartbeat check before the stop, and this sleep dies.
  repo
  sleep 60 3>&- &
  OWN+=("$!")
  mkdir -p "$BD"
  printf '%s\n' "${OWN[0]}" > "$BD/pid"
  git rev-parse HEAD > "$BD/commit"
  printf '%s\n' "$TMPDIR/dk-base-suite.none/tree" > "$BD/tree"
  printf '%s\n' "$(( $(date +%s) - 120 ))" > "$BD/started"
  printf '%s\n' "$(( $(date +%s) - 120 ))" > "$BD/heartbeat"
  # A live id with a stale heartbeat gets 15 s to beat again, then is said
  # to have stopped; the limit, long passed, never signals it.
  waits --slice 30 --limit 1
  [ "$WRC" = 0 ] || { echo "exit $WRC: $(cat "$OUT") $(cat "$ERR")"; false; }
  [ "$(cat "$OUT")" = "base suite stopped reporting" ] || { echo "wait said: $(cat "$OUT")"; false; }
  kill -0 "${OWN[0]}" || { echo "a process whose heartbeat was stale was signalled"; false; }
}

@test "a dead runner's checkout is removed" {
  repo "exec sleep 60"
  runs suite-base "$F" start
  # Wait for the command to start, then stop the runner and its command by
  # the ids the run recorded, without any chance to clean up.
  local n=0
  while [ ! -f "$BD/child" ]; do n=$((n + 1)); [ "$n" -le 50 ] || false; sleep 0.2; done
  kill -KILL "$(cat "$BD/pid")" "$(cat "$BD/child")"
  gone "$(cat "$BD/pid")"
  [ "$(others)" = 1 ]
  waits --slice 2
  [ "$WRC" = 0 ] || { echo "exit $WRC: $(cat "$OUT") $(cat "$ERR")"; false; }
  [ "$(cat "$OUT")" = "base suite stopped reporting" ] || { echo "wait said: $(cat "$OUT")"; false; }
  [ "$(others)" = 0 ] || { git worktree list; false; }
  # The heartbeat loop ends with its runner: a runner stopped by KILL runs
  # no trap, and a loop that outlived it once wrote on for ever (found while
  # building this test). Mutation: loop on `:` again, and the beat moves.
  local beat; beat="$(cat "$BD/heartbeat" 2>/dev/null || true)"
  sleep 6
  [ "$(cat "$BD/heartbeat" 2>/dev/null || true)" = "$beat" ] || { echo "the heartbeat moved after its runner was gone"; false; }
}

@test "the limit counts from the first wait" {
  # Mutation: count the limit from each call, and the second call runs out
  # its slice (exit 2) instead of stopping the runner.
  repo "exec sleep 60"
  runs suite-base "$F" start
  waits --slice 1 --limit 50
  [ "$WRC" = 2 ] || { echo "exit $WRC: $(cat "$OUT") $(cat "$ERR")"; false; }
  # The first wait was 100 s ago, as far as the limit knows.
  printf '%s\n' "$(( $(date +%s) - 100 ))" > "$BD/wait-started"
  waits --slice 3 --limit 50
  [ "$WRC" = 0 ] || { echo "exit $WRC: $(cat "$OUT") $(cat "$ERR")"; false; }
  [ "$(cat "$OUT")" = "base suite stopped at the 50 s limit" ] || { echo "wait said: $(cat "$OUT")"; false; }
}

@test "with no flags the limit is 900 seconds" {
  # Mutation: change the default limit, and the runner is not stopped here.
  repo "exec sleep 60"
  runs suite-base "$F" start
  printf '%s\n' "$(( $(date +%s) - 899 ))" > "$BD/wait-started"
  local t0; t0="$(date +%s)"
  waits
  [ "$WRC" = 0 ] || { echo "exit $WRC: $(cat "$OUT") $(cat "$ERR")"; false; }
  [ "$(cat "$OUT")" = "base suite stopped at the 900 s limit" ] || { echo "wait said: $(cat "$OUT")"; false; }
  [ $(( $(date +%s) - t0 )) -lt 15 ]
}

@test "the heartbeat keeps a long run alive past its first minute" {
  # Mutation: drop the heartbeat writer, and a run older than 60 s reads as
  # stopped, so F.5 would run the suite itself.
  repo "exec sleep 30"
  runs suite-base "$F" start
  local n=0
  while [ ! -f "$BD/heartbeat" ]; do n=$((n + 1)); [ "$n" -le 50 ] || { echo "no heartbeat"; false; }; sleep 0.2; done
  printf '%s\n' "$(( $(date +%s) - 120 ))" > "$BD/started"
  local beat; beat="$(cat "$BD/heartbeat")"
  sleep 6
  [ "$(cat "$BD/heartbeat")" != "$beat" ] || { echo "the heartbeat did not move"; false; }
  waits --slice 1
  [ "$WRC" = 2 ] || { echo "exit $WRC: $(cat "$OUT") $(cat "$ERR")"; false; }
}

@test "green TAP with a failing exit code is red" {
  # Mutation: drop the command's exit code, and this records green.
  repo "$GREEN; exit 3"
  runs suite-base "$F" start
  outcome_wait
  [ "$OUTCOME" = red ] || { echo "outcome '$OUTCOME'"; false; }
}

@test "the runner reads only its checkout while the main tree changes" {
  # Mutation: run the command in the main tree, and the TAP shows the
  # changed bytes.
  repo "sleep 2; printf '1..1\\nok 1 a\\n# readme=%s\\n' \"\$(cat README.md)\""
  runs suite-base "$F" start
  printf 'changed\n' > README.md
  outcome_wait
  [ "$OUTCOME" = green ] || { echo "outcome '$OUTCOME'; tap: $(cat "$BD/suite.tap")"; false; }
  grep -qx '# readme=base' "$BD/suite.tap" || { echo "the runner read the main tree: $(cat "$BD/suite.tap")"; false; }
}

@test "a run holding the lock does not stop the base suite run" {
  repo
  bash "$PROG" lock-take "$F" another-session > /dev/null
  runs suite-base "$F" start
  outcome_wait
  [ "$OUTCOME" = green ] || { echo "outcome '$OUTCOME'; log: $(cat "$BD/runner.log")"; false; }
}

@test "start refuses what it cannot cite, and starts nothing" {
  # An unknown suiteReuse value.
  repo
  reuse sometimes
  runs suite-base "$F" start
  [[ "$(cat "$OUT")" == "base suite not started: config.suiteReuse in "*" is none of commit, files or off" ]] || { echo "start said: $(cat "$OUT")"; false; }
  reuse commit
  # A TMPDIR inside the work tree. Mutation: drop the check, and a checkout
  # lands inside the tree.
  mkdir -p inner
  printf 'inner/\n' >> .git/info/exclude
  TMPDIR="$WORK/inner" runs suite-base "$F" start
  [ "$(cat "$OUT")" = "base suite not started: TMPDIR lies inside the work tree, and the checkout must lie outside it" ] || { echo "start said: $(cat "$OUT")"; false; }
  # A main tree that differs from the base commit outside the spec
  # directory. Mutation: drop the key comparison, and a runner starts whose
  # record could never be cited.
  printf 'more\n' >> README.md
  runs suite-base "$F" start
  [[ "$(cat "$OUT")" == "base suite not started: the base commit's files are not these files without the spec directory"* ]] || { echo "start said: $(cat "$OUT")"; false; }
  [ ! -f "$BD/pid" ]
  [ "$(others)" = 0 ] || { git worktree list; false; }
}

@test "the clean-up removes only its own checkout's record" {
  # Mutation: prune every worktree record, and the record of the owner's
  # worktree, whose folder is away, is gone.
  repo
  git worktree add -q --detach "$BATS_TEST_TMPDIR/mine" HEAD
  mv "$BATS_TEST_TMPDIR/mine" "$BATS_TEST_TMPDIR/away"
  local admin; admin="$(git rev-parse --git-common-dir)/worktrees/mine"
  [ -d "$admin" ]
  runs suite-base "$F" start
  outcome_wait
  [ "$OUTCOME" = green ]
  # Again through the fallback: git refuses to remove the runner's checkout
  # (its .git file is broken), so its own record is removed by path. A
  # missing folder would not reach the fallback: given the full path, git
  # removes the record of a worktree whose folder is gone (git 2.53).
  state 002-next "exec sleep 60" specs/002-next
  rm -rf specs/001-demo
  runs suite-base 002-next start
  local b=".delivery-kit/runs/002-next/base-suite" n=0
  while [ ! -s "$b/child" ]; do n=$((n + 1)); [ "$n" -le 50 ] || false; sleep 0.2; done
  kill -KILL "$(cat "$b/pid")" "$(cat "$b/child")"
  printf 'gitdir: /nowhere\n' > "$(cat "$b/tree")/.git"
  bash "$PROG" suite-base 002-next wait > "$OUT"
  [ "$(cat "$OUT")" = "base suite stopped reporting" ] || { echo "wait said: $(cat "$OUT")"; false; }
  # The record's path must be known, or the check below passes on nothing.
  [ -s "$b/admin" ] || { echo "no admin path was recorded"; false; }
  [ ! -d "$(cat "$b/admin")" ] || { echo "the dead runner's own record was left"; false; }
  [ -d "$admin" ] || { echo "the owner's worktree record was pruned"; false; }
  mv "$BATS_TEST_TMPDIR/away" "$BATS_TEST_TMPDIR/mine"
}

@test "start on an abandoned run starts nothing" {
  # Mutation: drop the abandoned check, and a runner starts for a run that
  # has ended.
  repo
  bash "$PROG" abandon "$F" > /dev/null
  runs suite-base "$F" start
  [ "$(cat "$OUT")" = "base suite not started: the run was abandoned" ] || { echo "start said: $(cat "$OUT")"; false; }
  [ ! -f "$BD/pid" ]
  [ "$(others)" = 0 ]
}

@test "a dead runner's ids are never signalled again" {
  # Once the wait finds the runner gone, the outcome says so, and a later
  # wait reads it instead of looking at the recorded ids.
  repo "exec sleep 60"
  runs suite-base "$F" start
  local n=0
  while [ ! -s "$BD/child" ]; do n=$((n + 1)); [ "$n" -le 50 ] || false; sleep 0.2; done
  kill -KILL "$(cat "$BD/pid")" "$(cat "$BD/child")"
  gone "$(cat "$BD/pid")"
  waits --slice 2
  [ "$(cat "$OUT")" = "base suite stopped reporting" ]
  [ "$(cat "$BD/outcome")" = "stopped reporting" ] || { echo "no outcome was written"; false; }
  waits --slice 2
  [ "$WRC" = 0 ] && [ "$(cat "$OUT")" = "base suite stopped reporting" ] || { echo "second wait: $WRC $(cat "$OUT")"; false; }
}

@test "wait and start refuse a bad argument" {
  repo
  local a
  for a in "--slice 0" "--slice abc" "--limit" "--other 1"; do
    # shellcheck disable=SC2086 # the words are the arguments
    run -1 bash "$PROG" suite-base "$F" wait $a
  done
  run -1 bash "$PROG" suite-base "$F"
  [[ "$output" == *"usage: suite-base <feature> start | wait"* ]] || { echo "$output"; false; }
  run -1 bash "$PROG" suite-base "$F" start extra
}

# Feature 058: exit 3 is the run's own record failing the start.
@test "an artifacts.spec that names no spec file exits 3, absent or stale" {
  local sf rc edit
  repo
  sf=".delivery-kit/runs/$F/progress.json"
  for edit in 'del(.artifacts.spec)' '.artifacts.spec = "specs/001-demo/gone.md"'; do
    jq "$edit" "$sf" > "$BATS_TEST_TMPDIR/t.json"
    mv "$BATS_TEST_TMPDIR/t.json" "$sf"
    rc=0; bash "$PROG" suite-base "$F" start > "$OUT" 2> "$ERR" || rc=$?
    [ "$rc" -eq 3 ] || { echo "status $rc, after $edit: $(cat "$ERR")"; false; }
    [[ "$(cat "$OUT")" == "base suite not started: artifacts.spec in "*" names no spec file that exists" ]] \
      || { echo "start said, after $edit: $(cat "$OUT")"; false; }
    [ ! -e "$BD" ] || { echo "a bookkeeping folder was made, after $edit"; false; }
  done
}

@test "a start after exit 3 starts, once the record is fixed" {
  # Mutation: leave a marker behind at exit 3, and the second start refuses.
  local sf rc
  repo
  sf=".delivery-kit/runs/$F/progress.json"
  jq 'del(.config.testCommand)' "$sf" > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" "$sf"
  rc=0; bash "$PROG" suite-base "$F" start > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -eq 3 ]
  jq --arg c "$GREEN" '.config.testCommand = $c' "$sf" > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" "$sf"
  runs suite-base "$F" start
  [[ "$(cat "$OUT")" == "base suite started on commit "* ]] || { echo "start said: $(cat "$OUT")"; false; }
  outcome_wait
  [ "$OUTCOME" = green ]
}

# The classification is read from the script, so a new reason cannot arrive
# unclassified. The legal paths' exit 0 is asserted where each is tested,
# through `runs`. Mutation: add a line, or mark a third reason as a fault.
@test "every reason the start can give is classified: two fault, the rest legal" {
  local lines line faults=0 reasons=0
  lines="$(grep -n 'SK_WHY="' "$PROG" | grep -v "SK_WHY='" )"
  [ -n "$lines" ]
  while IFS= read -r line; do
    reasons=$((reasons + 1))
    case "$line" in
      *'config.testCommand is not recorded as a string'*|*'names no spec file that exists'*)
        [[ "$line" == *'SK_FAULT=1'* ]] || { echo "not marked a fault: $line"; false; }
        faults=$((faults + 1)) ;;
      *'config.suiteReuse is off'*|*'none of commit, files or off'*|*'outside this repository'*|*'top level'*|*'left out already'*|*'assume-unchanged'*|*'names no commit yet'*|*'${paths##*'*)
        [[ "$line" != *'SK_FAULT=1'* ]] || { echo "a legal reason is marked a fault: $line"; false; }
        ;;
      *) echo "a reason this test does not classify: $line"; false ;;
    esac
  done <<<"$lines"
  [ "$faults" -eq 2 ] || { echo "$faults fault reasons"; false; }
  [ "$reasons" -ge 8 ] || { echo "only $reasons reasons read"; false; }
  # base_start's own lines: every printf and die that says "not started".
  lines="$(grep -n 'base suite not started' "$PROG" | grep -v '^[0-9]*:#')"
  while IFS= read -r line; do
    case "$line" in
      *'the run was abandoned'*|*'$SK_WHY'*|*'a green result is already recorded'*|*'TMPDIR lies inside'*|*'are not these files'*) ;;
      *'die "base suite not started: git worktree add failed'*|*'die "base suite not started: the runner could not be started'*) ;;
      *) echo "a line this test does not classify: $line"; false ;;
    esac
  done <<<"$lines"
}
