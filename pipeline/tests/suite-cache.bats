#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for progress.sh's suite results: suite-key, suite-record and
# suite-lookup. A full run of testCommand is kept per exact tree, and J, N
# and a later run's F.5 may cite a GREEN result instead of running again —
# so every way a result could stop describing the tree in front of it must
# refuse: a dirty tree, a tree that changed while the suite ran, another
# command, another platform, a red verdict. Every test builds its own
# throwaway repository under $BATS_TEST_TMPDIR.
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
  # The developer's own git configuration must not reach these repositories.
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export GIT_CONFIG_NOSYSTEM=1
  export XDG_CONFIG_HOME="$HOME/.config"
  export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
  F=001-demo
  SF=".delivery-kit/runs/$F/progress.json"
  TAP=".delivery-kit/runs/$F/suite.tap"
  OUT="$BATS_TEST_TMPDIR/out.txt"
  ERR="$BATS_TEST_TMPDIR/err.txt"
}

# repo — a committed tree (README.md, src/keep.sh, a .gitignore that ignores
# *.log and NOT .delivery-kit/, so the state directory shows in git status
# and the key must leave it out by itself), and a state file for $F whose
# config.testCommand is "run-the-suite".
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
  state "$F"
}

# state <feature> [<command>] — a state file whose config.testCommand is the
# command, "run-the-suite" when none is given.
state() {
  local sf=".delivery-kit/runs/$1/progress.json"
  bash "$PROG" init "$1" "$1" main other > /dev/null
  jq --arg c "${2:-run-the-suite}" '.config.testCommand = $c' "$sf" > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" "$sf"
}

# runs <args...> — the script, stdout to $OUT, stderr to $ERR; exit 0.
runs() {
  local rc=0
  bash "$PROG" "$@" > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -eq 0 ] || { echo "exit $rc, expected 0: $(cat "$ERR")"; return 1; }
}

# refuses <fragment> <args...> — exit 1, the fragment on stderr, nothing on
# stdout.
refuses() {
  local frag="$1" rc=0; shift
  bash "$PROG" "$@" > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -eq 1 ] || { echo "exit $rc, expected 1 naming: $frag"; cat "$ERR"; return 1; }
  [[ "$(cat "$ERR")" == *"$frag"* ]] || { echo "stderr lacks '$frag': $(cat "$ERR")"; return 1; }
  [ ! -s "$OUT" ] || { echo "a refusal printed on stdout: $(cat "$OUT")"; return 1; }
}

# key — suite-key's answer, which must be one hex object id.
key() {
  runs suite-key "$F" || return 1
  K="$(cat "$OUT")"
  [[ "$K" =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] || { echo "not a key: '$K'"; return 1; }
}

# tap <lines...> — the TAP file, one argument a line, LF endings.
tap() { printf '%s\n' "$@" > "$TAP"; }

# record <rc> — suite-key, then suite-record of $TAP with that exit code;
# the verdict lands in V.
record() {
  key || return 1
  runs suite-record "$F" "$K" "$TAP" "$1" || return 1
  V="$(cat "$OUT")"
}

# verdict_is <green|red> <rc> <lines...>
verdict_is() {
  local want="$1" rc="$2"; shift 2
  tap "$@"
  record "$rc" || return 1
  [ "$V" = "$want" ] || { echo "verdict '$V', expected '$want' for: $*"; return 1; }
}

records() { find .delivery-kit/suite-results -name '*.json' 2>/dev/null | wc -l | tr -d ' '; }

@test "suite-key prints one key on a clean tree, the same key each time" {
  repo
  key
  local first="$K"
  key
  [ "$K" = "$first" ]
}

@test "suite-key has no key when a tracked file is changed, staged or not" {
  repo
  printf 'changed\n' >> README.md
  refuses "the working tree has a change outside .delivery-kit/ (README.md)" suite-key "$F"
  git add README.md
  refuses "(README.md)" suite-key "$F"
  git reset -q HEAD README.md
  git checkout -q -- README.md
  key
  # Staged only: the file is still in the working tree, deleted in the index.
  git rm -q --cached src/keep.sh
  refuses "(src/keep.sh)" suite-key "$F"
}

@test "suite-key has no key when an untracked file exists, but an ignored one is not seen" {
  repo
  key
  local clean="$K"
  printf 'noise\n' > build.log
  key
  [ "$K" = "$clean" ]
  mkdir -p deep/er
  printf 'new\n' > deep/er/new.txt
  refuses "(deep/er/new.txt)" suite-key "$F"
}

@test "suite-key leaves .delivery-kit/ out of the tree it judges" {
  repo
  # The state file itself is untracked here and not ignored: the key exists
  # only because the state directory is left out.
  [ -n "$(git status --porcelain --untracked-files=all -- .delivery-kit)" ]
  key
  local before="$K"
  printf 'scratch\n' > .delivery-kit/runs/$F/scratch.txt
  key
  [ "$K" = "$before" ]
}

@test "suite-key has no key when an index entry hides a change from git status" {
  repo
  git update-index --assume-unchanged README.md
  printf 'hidden\n' >> README.md
  [ -z "$(git status --porcelain -- README.md)" ]
  refuses "assume-unchanged or skip-worktree" suite-key "$F"
  git update-index --no-assume-unchanged README.md
  git checkout -q -- README.md
  git update-index --skip-worktree README.md
  refuses "assume-unchanged or skip-worktree" suite-key "$F"
}

@test "suite-key has no key when config.testCommand is not recorded" {
  repo
  jq 'del(.config.testCommand)' "$SF" > t.json && mv t.json "$SF"
  refuses "config.testCommand is not recorded as a string" suite-key "$F"
  jq '.config.testCommand = null' "$SF" > t.json && mv t.json "$SF"
  refuses "config.testCommand is not recorded as a string" suite-key "$F"
}

@test "the key changes with any committed change, with the command, and with the platform" {
  repo
  key
  local base="$K"
  printf 'one more line\n' >> src/keep.sh
  git commit -q -am 'a change'
  key
  [ "$K" != "$base" ]
  local changed="$K"
  # The same tree reached by another commit has the same key: the key is the
  # tree, not the commit.
  git revert --no-edit HEAD > /dev/null
  key
  [ "$K" = "$base" ]
  [ "$changed" != "$base" ]
  # Another command: another key.
  jq '.config.testCommand = "run-the-suite --fast"' "$SF" > t.json && mv t.json "$SF"
  key
  [ "$K" != "$base" ]
  jq '.config.testCommand = "run-the-suite"' "$SF" > t.json && mv t.json "$SF"
  key
  [ "$K" = "$base" ]
  # Another platform: another key.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\necho OtherOS\n' > "$BATS_TEST_TMPDIR/bin/uname"
  chmod +x "$BATS_TEST_TMPDIR/bin/uname"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" key
  [ "$K" != "$base" ]
}

@test "suite-record refuses when the tree changed between the key and the record" {
  repo
  key
  tap '1..1' 'ok 1 one'
  # A commit made while the suite ran.
  printf 'later\n' >> README.md
  git commit -q -am later
  refuses "the tree, the command or the platform is not what it was when the key was taken" \
    suite-record "$F" "$K" "$TAP" 0
  [ "$(records)" = 0 ]
  # A file a test left behind.
  key
  printf 'left\n' > leftover.txt
  refuses "no suite key now" suite-record "$F" "$K" "$TAP" 0
  [ "$(records)" = 0 ]
  # A TAP file written inside the tree, outside .delivery-kit/, dirties it.
  rm leftover.txt
  key
  printf '1..1\nok 1 one\n' > suite.tap
  refuses "(suite.tap)" suite-record "$F" "$K" suite.tap 0
  [ "$(records)" = 0 ]
}

@test "suite-record refuses a bad exit code and a missing TAP file" {
  repo
  key
  tap '1..1' 'ok 1 one'
  refuses "is not a number" suite-record "$F" "$K" "$TAP" x
  refuses "is not a number" suite-record "$F" "$K" "$TAP" -1
  refuses "does not exist" suite-record "$F" "$K" .delivery-kit/none.tap 0
  refuses "usage: suite-record" suite-record "$F" "$K" "$TAP"
  [ "$(records)" = 0 ]
}

@test "a green run is recorded with its counts" {
  repo
  verdict_is green 0 '1..3' 'ok 1 one' '# a comment' 'ok 2 two' '' 'ok 3 three'
  local rec=".delivery-kit/suite-results/$K.json"
  [ -f "$rec" ]
  [ "$(jq -c '[.verdict, .plan, .ok, .skipped, .notOk, .nonTap, .rc, .feature, .command, .tree]' "$rec" | tr -d '\r')" \
    = "[\"green\",3,3,0,0,0,0,\"$F\",\"run-the-suite\",\"$(git rev-parse 'HEAD^{tree}')\"]" ]
  [ "$(jq -r '.rc | type' "$rec" | tr -d '\r')" = number ]
}

@test "a skip counts as an ok and is reported" {
  repo
  verdict_is green 0 '1..2' 'ok 1 one' 'ok 2 two # skip not here'
  [ "$(jq -c '[.ok, .skipped]' ".delivery-kit/suite-results/$K.json" | tr -d '\r')" = '[2,1]' ]
}

@test "a TAP file with CRLF endings reads as it does with LF" {
  repo
  printf '1..2\r\nok 1 one\r\nok 2 two\r\n' > "$TAP"
  record 0
  [ "$V" = green ]
}

@test "a plan that does not match the ok count is red" {
  repo
  verdict_is red 0 '1..3' 'ok 1 one' 'ok 2 two'
  verdict_is red 0 '1..1' 'ok 1 one' 'ok 2 two'
}

@test "a not ok is red even when the ok count matches the plan" {
  repo
  verdict_is red 0 '1..2' 'ok 1 one' 'ok 2 two' 'not ok 3 three'
  [ "$(jq -r .notOk ".delivery-kit/suite-results/$K.json" | tr -d '\r')" = 1 ]
}

@test "a line that is neither TAP nor a comment is red" {
  repo
  verdict_is red 0 '1..2' 'ok 1 one' 'warning: something' 'ok 2 two'
}

@test "a non-zero exit code is red even when every test is ok" {
  repo
  verdict_is red 1 '1..2' 'ok 1 one' 'ok 2 two'
}

@test "no plan, a late plan, two plans, an empty plan and an empty file are red" {
  repo
  verdict_is red 0 'ok 1 one'
  verdict_is red 0 'ok 1 one' '1..1'
  verdict_is red 0 '1..1' 'ok 1 one' '1..1'
  verdict_is red 0 '1..0'
  : > "$TAP"
  record 0
  [ "$V" = red ]
}

@test "suite-lookup finds a green record for this tree, from any run" {
  repo
  verdict_is green 0 '1..2' 'ok 1 one' 'ok 2 two'
  runs suite-lookup "$F"
  [ "$(sed -n 1p "$OUT")" = ".delivery-kit/suite-results/$K.json" ]
  [[ "$(sed -n 2p "$OUT")" == "1..2, 2 ok (0 skipped), 0 not ok, exit 0 — recorded "*" by run $F" ]]
  # A later run on the same tree, with the same command, reuses it.
  state 002-later
  runs suite-lookup 002-later
  [ "$(sed -n 1p "$OUT")" = ".delivery-kit/suite-results/$K.json" ]
}

@test "suite-lookup finds nothing before a record, after a commit, or on a dirty tree" {
  repo
  refuses "none is recorded for this tree, command and platform" suite-lookup "$F"
  verdict_is green 0 '1..1' 'ok 1 one'
  printf 'dirty\n' >> README.md
  refuses "no suite key" suite-lookup "$F"
  git commit -q -am 'a change'
  refuses "none is recorded for this tree, command and platform" suite-lookup "$F"
}

@test "a red result is never reused, and a later red replaces a green" {
  repo
  verdict_is red 0 '1..2' 'ok 1 one' 'not ok 2 two'
  refuses "is red, and a red result is never reused" suite-lookup "$F"
  verdict_is green 0 '1..2' 'ok 1 one' 'ok 2 two'
  runs suite-lookup "$F"
  verdict_is red 1 '1..2' 'ok 1 one' 'ok 2 two'
  refuses "is red, and a red result is never reused" suite-lookup "$F"
  # Red only by the verdict: the counts a record keeps all look green.
  verdict_is red 0 '1..1' 'ok 1 one' '1..1'
  refuses "is red, and a red result is never reused" suite-lookup "$F"
}

@test "suite-lookup misses for another command or another platform" {
  repo
  verdict_is green 0 '1..1' 'ok 1 one'
  state 002-other "run-the-suite --other"
  refuses "none is recorded for this tree, command and platform" suite-lookup 002-other
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\necho OtherOS\n' > "$BATS_TEST_TMPDIR/bin/uname"
  chmod +x "$BATS_TEST_TMPDIR/bin/uname"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" refuses "none is recorded for this tree, command and platform" suite-lookup "$F"
  runs suite-lookup "$F"
}

@test "suite-lookup judges the record's counts and identity again" {
  repo
  verdict_is red 0 '1..3' 'ok 1 one' 'ok 2 two'
  local rec=".delivery-kit/suite-results/$K.json"
  # Edited by hand to read green without the counts of a green run.
  jq '.verdict = "green"' "$rec" > t.json && mv t.json "$rec"
  refuses "is red" suite-lookup "$F"
  jq '.ok = 3 | .rc = "0"' "$rec" > t.json && mv t.json "$rec"
  refuses "is red" suite-lookup "$F"
  jq '.rc = 0 | .command = "something else"' "$rec" > t.json && mv t.json "$rec"
  refuses "records another tree, command or platform" suite-lookup "$F"
  printf 'not json' > "$rec"
  refuses "is not one readable record" suite-lookup "$F"
}
