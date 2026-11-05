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

# edit_state <jq filter> [<jq args>...] — one edit of $F's state file.
edit_state() {
  local sf=".delivery-kit/runs/$F/progress.json" filter="$1"
  shift
  jq "$@" "$filter" "$sf" > "$BATS_TEST_TMPDIR/t.json" || return 1
  mv "$BATS_TEST_TMPDIR/t.json" "$sf"
}

# reuse <mode> — config.suiteReuse for $F.
reuse() { edit_state '.config.suiteReuse = $m' --arg m "$1"; }

# runs <args...> — the script, stdout to $OUT, stderr to $ERR; exit 0.
runs() {
  local rc=0
  bash "$PROG" "$@" > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -eq 0 ] || { echo "exit $rc, expected 0: $(cat "$ERR")"; return 1; }
}

# runs3 <args...> — the same, for the exit 3 of a record that cannot serve.
runs3() {
  local rc=0
  bash "$PROG" "$@" > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -eq 3 ] || { echo "exit $rc, expected 3: $(cat "$ERR")"; return 1; }
}

# legal <exact line> — start exits 0 with the line, nothing on stderr, and no
# bookkeeping folder: a legal "not started", which FR-003 keeps at exit 0.
legal() {
  runs suite-base "$F" start
  [ "$(cat "$OUT")" = "$1" ] || { echo "start said: $(cat "$OUT")"; return 1; }
  [ ! -s "$ERR" ] || { echo "stderr: $(cat "$ERR")"; return 1; }
  [ ! -e "$BD" ] || { echo "a bookkeeping folder was made"; return 1; }
  [ "$(others)" = 0 ] || { echo "a checkout was made"; return 1; }
}

# stub <name> <first line of sh that decides to fail> — a command on $BIN that
# fails when the line says so and hands every other call to the real one.
stub() {
  local real
  real="$(command -v "$1")"
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"
  printf '#!/bin/sh\n%s\nexec "%s" "$@"\n' "$2" "$real" > "$BIN/$1"
  chmod +x "$BIN/$1"
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
  local edit
  repo
  for edit in 'del(.config.testCommand)' '.config.testCommand = null' '.config.testCommand = ""' '.config.testCommand = 42'; do
    edit_state "$edit"
    runs3 suite-base "$F" start
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
  local edit
  repo
  for edit in 'del(.artifacts.spec)' '.artifacts.spec = "specs/001-demo/gone.md"'; do
    edit_state "$edit"
    runs3 suite-base "$F" start
    [[ "$(cat "$OUT")" == "base suite not started: artifacts.spec in "*" names no spec file that exists" ]] \
      || { echo "start said, after $edit: $(cat "$OUT")"; false; }
    [ ! -e "$BD" ] || { echo "a bookkeeping folder was made, after $edit"; false; }
  done
}

@test "a folder at artifacts.spec exits 3" {
  # Mutation: test the path with -e, and a folder reads as the spec file.
  repo
  edit_state '.artifacts.spec = "specs/001-demo"'
  runs3 suite-base "$F" start
  [ "$(cat "$OUT")" = "base suite not started: artifacts.spec in .delivery-kit/runs/$F/progress.json names no spec file that exists" ] || { echo "start said: $(cat "$OUT")"; false; }
  [ ! -e "$BD" ] || { echo "a bookkeeping folder was made"; false; }
}

@test "a start after exit 3 starts, once the record is fixed" {
  # Mutation: leave a marker behind at exit 3, and the second start refuses.
  repo
  edit_state 'del(.config.testCommand)'
  runs3 suite-base "$F" start
  edit_state '.config.testCommand = $c' --arg c "$GREEN"
  runs suite-base "$F" start
  [[ "$(cat "$OUT")" == "base suite started on commit "* ]] || { echo "start said: $(cat "$OUT")"; false; }
  outcome_wait
  [ "$OUTCOME" = green ]
}

# Precedence: a line that needs no record comes before the record's own checks.
@test "an abandoned run with no test command exits 0 with the abandoned line" {
  # Mutation: read the record before the abandoned check, and this exits 3.
  repo
  bash "$PROG" abandon "$F" > /dev/null
  edit_state 'del(.config.testCommand)'
  legal "base suite not started: the run was abandoned"
}

@test "suiteReuse off with no spec file exits 0 with the off line" {
  # Mutation: read the spec before suiteReuse, and this exits 3.
  repo
  reuse off
  edit_state 'del(.artifacts.spec)'
  legal "base suite not started: config.suiteReuse is off: no suite result is kept or reused"
}

@test "already started, with the record broken afterwards, exits 0 with its line" {
  # Mutation: read the record before the started check, and this exits 3.
  repo
  runs suite-base "$F" start
  outcome_wait
  [ "$OUTCOME" = green ]
  edit_state 'del(.config.testCommand)'
  runs suite-base "$F" start
  [ "$(cat "$OUT")" = "base suite already started on commit $(git rev-parse HEAD)" ] || { echo "start said: $(cat "$OUT")"; false; }
}

# FR-003: each legal line that has no test above, its fixture as in
# suite-cache.bats.
@test "a spec file at the top level exits 0 with its line" {
  repo
  printf '# spec\n' > spec.md
  edit_state '.artifacts.spec = "spec.md"'
  legal "base suite not started: the spec file sits at the repository's top level, so there is no spec directory to leave out"
}

@test "a spec file under the state directory exits 0 with its line" {
  repo
  mkdir -p .delivery-kit/specs
  printf '# spec\n' > .delivery-kit/specs/spec.md
  edit_state '.artifacts.spec = ".delivery-kit/specs/spec.md"'
  legal "base suite not started: the spec file sits under .delivery-kit/, which is left out already, so there is no spec directory to leave out"
}

@test "a spec file outside the repository exits 0 with its line, and names no path" {
  repo
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  printf '# spec\n' > "$BATS_TEST_TMPDIR/elsewhere/spec.md"
  edit_state '.artifacts.spec = $s' --arg s "$BATS_TEST_TMPDIR/elsewhere/spec.md"
  legal "base suite not started: artifacts.spec in .delivery-kit/runs/$F/progress.json names a spec file outside this repository"
}

@test "an index entry hidden from git status exits 0 with its line" {
  local want="base suite not started: an index entry is marked assume-unchanged or skip-worktree, which hides its changes from git status"
  repo
  git update-index --assume-unchanged README.md
  legal "$want"
  git update-index --no-assume-unchanged README.md
  git update-index --skip-worktree README.md
  legal "$want"
}

@test "an unmerged path exits 0 with its line" {
  repo
  git checkout -q -b side
  printf 'side\n' > README.md
  git commit -q -am side
  git checkout -q main
  printf 'main\n' > README.md
  git commit -q -am main
  git merge -q side > /dev/null 2>&1 || true
  legal "base suite not started: the index holds an unmerged path (README.md)"
}

@test "a submodule exits 0 with its line" {
  repo
  git update-index --add --cacheinfo "160000,$(git rev-parse HEAD),sub"
  git commit -q -m 'a submodule'
  mkdir -p sub
  legal "base suite not started: the tree holds a submodule (sub)"
}

@test "a repository nested in the tree exits 0 with its line" {
  repo
  mkdir -p nested
  git -C nested init -q
  printf 'q\n' > nested/q.txt
  legal "base suite not started: an untracked directory holds a repository of its own (nested/)"
}

@test "HEAD with no commit exits 0 with its line" {
  git init -q .
  git symbolic-ref HEAD refs/heads/main
  git config core.autocrlf false
  state "$F" "$GREEN" specs/001-demo
  legal "base suite not started: HEAD names no commit yet"
}

# FR-004: exit 1 is a check that could not be made. Each stub fails one call and
# passes the rest on, so the exact line shows the fault is the one planted.
@test "a git worktree add that fails exits 1, says so and starts nothing" {
  # Mutation: read the failure as a legal line, and this exits 0.
  repo
  stub git 'if [ "$1 $2" = "worktree add" ]; then exit 1; fi'
  local rc=0
  PATH="$BIN:$PATH" bash "$PROG" suite-base "$F" start > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -eq 1 ] || { echo "exit $rc: $(cat "$ERR")"; false; }
  [ ! -s "$OUT" ] || { echo "stdout: $(cat "$OUT")"; false; }
  [ "$(cat "$ERR")" = "progress.sh: base suite not started: git worktree add failed (see $BD/runner.log)" ] || { echo "stderr: $(cat "$ERR")"; false; }
  [ ! -e "$BD/pid" ] || { echo "a runner was recorded"; false; }
  [ "$(others)" = 0 ]
  [ -z "$(ls -A "$TMPDIR")" ] || { echo "the temporary folder was left: $(ls -A "$TMPDIR")"; false; }
}

@test "a temporary folder that cannot be made exits 1, says so and starts nothing" {
  # A stub, not a missing TMPDIR: BSD mktemp falls back to /tmp when TMPDIR is
  # missing, and the key's scratch file needs mktemp to work.
  repo
  stub mktemp 'case "$*" in *dk-base-suite*) exit 1 ;; esac'
  local rc=0
  PATH="$BIN:$PATH" bash "$PROG" suite-base "$F" start > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -eq 1 ] || { echo "exit $rc: $(cat "$ERR")"; false; }
  [ ! -s "$OUT" ] || { echo "stdout: $(cat "$OUT")"; false; }
  [ "$(cat "$ERR")" = "progress.sh: could not make a temporary folder for the base checkout" ] || { echo "stderr: $(cat "$ERR")"; false; }
  [ ! -e "$BD" ] || { echo "a bookkeeping folder was made"; false; }
  [ "$(others)" = 0 ]
}

# The classification is read from the script, so a new reason cannot arrive
# unclassified. Each legal reason's exit 0 is asserted in its own test above,
# through `runs`. Mutation: add a line, or mark a third reason as a fault.
@test "every reason the start can give is classified: two fault, the rest legal" {
  local lines line reasons=0
  # Occurrences, not lines: a second mark on a marked line still counts.
  [ "$(grep -o 'SK_FAULT=1' "$PROG" | wc -l)" -eq 2 ] || { echo "SK_FAULT=1 is set other than twice"; false; }
  # Every assignment, in any quoting, but the line that sets them all empty.
  lines="$(grep -n 'SK_WHY=' "$PROG")"
  while IFS= read -r line; do
    case "$line" in *"SK_WHY='' SK_FAULT=''"*) continue ;; esac
    reasons=$((reasons + 1))
    case "$line" in
      *'config.testCommand is not recorded as a string'*|*'names no spec file that exists'*)
        [[ "$line" == *'SK_FAULT=1'* ]] || { echo "not marked a fault: $line"; false; } ;;
      *'config.suiteReuse is off'*|*'none of commit, files or off'*|*'outside this repository'*|*'top level'*|*'left out already'*|*'assume-unchanged'*|*'names no commit yet'*|*'${paths##*'*)
        [[ "$line" != *'SK_FAULT=1'* ]] || { echo "a legal reason is marked a fault: $line"; false; } ;;
      *) echo "a reason this test does not classify: $line"; false ;;
    esac
  done <<<"$lines"
  [ "$reasons" -ge 8 ] || { echo "only $reasons reasons read"; false; }
  # base_start's own lines: every printf and die that says "not started".
  lines="$(grep -n 'base suite not started' "$PROG")"
  while IFS= read -r line; do
    case "$line" in
      *'the run was abandoned'*|*'$SK_WHY'*|*'a green result is already recorded'*|*'TMPDIR lies inside'*|*'are not these files'*) ;;
      *'die "base suite not started: git worktree add failed'*|*'die "base suite not started: the runner could not be started'*) ;;
      *) echo "a line this test does not classify: $line"; false ;;
    esac
  done <<<"$lines"
}

# Feature 058: the started line shows the layer that set the command, read from
# the state file, JSON-quoted as the command is. Mutation: drop the read, or
# print it raw.
@test "the started line names the command's layer when the state file records it" {
  local want
  repo
  edit_state '.config.testCommandFrom = "the repository'"'"'s .delivery-kit.json"'
  runs suite-base "$F" start
  # The whole line: the command as JSON has each backslash of $GREEN doubled.
  want="base suite started on commit $(git rev-parse HEAD) (process $(cat "$BD/pid")), command \"printf '1..1\\\\nok 1 a\\\\n'\", from \"the repository's .delivery-kit.json\""
  [ "$(cat "$OUT")" = "$want" ] || { echo "start said: $(cat "$OUT")"; false; }
  outcome_wait
}

@test "the started line escapes the characters a terminal can act on" {
  # U+009B is a one-byte-long CSI, and U+202E reverses the text after it. Plain
  # JSON quoting passes both through as they are. Mutation: drop -a on either.
  local csi=$'\302\233' bidi=$'\342\200\256' want
  repo "$GREEN # $csi$bidi"
  edit_state '.config.testCommandFrom = $f' --arg f "layer $csi$bidi"
  runs suite-base "$F" start
  [ "$(LC_ALL=C tr -d '\000-\177' < "$OUT" | wc -c)" -eq 0 ] || { od -c "$OUT" | head -20; false; }
  want="base suite started on commit $(git rev-parse HEAD) (process $(cat "$BD/pid")), command \"printf '1..1\\\\nok 1 a\\\\n' # \\u009b\\u202e\", from \"layer \\u009b\\u202e\""
  [ "$(cat "$OUT")" = "$want" ] || { echo "start said: $(cat "$OUT")"; false; }
  outcome_wait
}

@test "the started line says no layer when none is recorded" {
  repo
  runs suite-base "$F" start
  [[ "$(cat "$OUT")" != *', from '* ]] || { echo "start said: $(cat "$OUT")"; false; }
  outcome_wait
}

@test "the started line says no layer when the record is not a string" {
  repo
  edit_state '.config.testCommandFrom = 42'
  runs suite-base "$F" start
  [[ "$(cat "$OUT")" != *', from '* ]] || { echo "start said: $(cat "$OUT")"; false; }
  outcome_wait
}

@test "the base suite's command gets INT as its caller has it" {
  # A job that a shell with no job control starts in the background has INT
  # ignored, and no bash under it can catch or reset it. Runs 058 and 059 lost
  # their base suite to that: a test that sends INT held until its limit. The
  # probe is a behaviour, since bash versions print trap -p differently.
  local probe="$BATS_TEST_TMPDIR/probe.sh" rec="$BATS_TEST_TMPDIR/rec" here="$BATS_TEST_TMPDIR/here"
  printf '%s\n' 'r=ignored; trap "r=caught" INT; kill -INT $$; sleep 0.1; printf "%s\n" "$r" > "$1"' > "$probe"
  bash "$probe" "$here"
  repo "bash '$probe' '$rec'; $GREEN"
  runs suite-base "$F" start
  outcome_wait
  [ -s "$rec" ] || { echo "the command never ran: $(cat "$BD/outcome")"; false; }
  [ "$(cat "$rec")" = "$(cat "$here")" ] || { echo "here: $(cat "$here"), in the command: $(cat "$rec")"; false; }
}

# holder_repo <file> — a run whose command starts a process, writes its id to the
# file, and waits, so a test can look past the command to what it started.
holder_repo() {
  repo "sleep 60 3>&- & printf '%s\\n' \"\$!\" > '$1'; wait"
}

# held <file> — waits for the holder's id and the runner's record of the command.
held() {
  local n=0
  while [ ! -s "$1" ] || [ ! -s "$BD/child" ]; do n=$((n + 1)); [ "$n" -le 50 ] || { echo "the command never started"; return 1; }; sleep 0.2; done
}

# stop_at_limit — calls the wait until the limit has stopped the run.
stop_at_limit() {
  local i=0
  waits --slice 1 --limit 2
  while [ "$WRC" = 2 ] && [ "$i" -lt 20 ]; do i=$((i + 1)); waits --slice 1 --limit 2; done
  [ "$WRC" = 0 ] || { echo "exit $WRC: $(cat "$OUT") $(cat "$ERR")"; return 1; }
  [ "$(cat "$OUT")" = "base suite stopped at the 2 s limit" ] || { echo "wait said: $(cat "$OUT")"; return 1; }
}

@test "a stop ends what the base suite's command started" {
  # The command leads a process group of its own, so the runner's group no longer
  # holds it. Mutation: signal the command's id alone, and the holder lives on.
  local holder="$BATS_TEST_TMPDIR/holder"
  holder_repo "$holder"
  runs suite-base "$F" start
  held "$holder"
  stop_at_limit
  gone "$(cat "$holder")" || { echo "the process the command started is still alive"; false; }
  [ "$(others)" = 0 ] || { git worktree list; false; }
}

@test "the stop's KILL reaches what the base suite's command started" {
  # A stopped runner runs no trap, so only the 10 s fallback can end the command.
  # Mutation: KILL the command's id alone, and the holder lives on.
  local holder="$BATS_TEST_TMPDIR/holder" runner
  holder_repo "$holder"
  runs suite-base "$F" start
  held "$holder"
  runner="$(cat "$BD/pid")"
  kill -STOP "$runner"
  stop_at_limit
  gone "$runner" || { echo "the runner is still alive"; false; }
  gone "$(cat "$holder")" || { echo "the process the command started is still alive"; false; }
  [ "$(others)" = 0 ] || { git worktree list; false; }
}
