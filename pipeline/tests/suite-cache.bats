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

# reuse <commit|files|off> [<feature>] — config.suiteReuse for the run.
reuse() {
  local sf=".delivery-kit/runs/${2:-$F}/progress.json"
  jq --arg m "$1" '.config.suiteReuse = $m' "$sf" > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" "$sf"
}

@test "suite-key prints one key on a clean tree, the same key each time" {
  repo
  key
  local first="$K"
  key
  [ "$K" = "$first" ]
}

@test "under files, a changed tracked file changes the key, staged or not, and committing it does not" {
  repo
  reuse files
  key
  local clean="$K"
  printf 'changed\n' >> README.md
  key
  local dirty="$K"
  [ "$dirty" != "$clean" ] || { echo "a changed tracked file left the key as it was"; false; }
  # Staging changes nothing the suite reads, and neither does the commit: N
  # can cite the run J made before J committed.
  git add README.md
  key
  [ "$K" = "$dirty" ] || { echo "staging a change moved the key"; false; }
  git commit -q -m changed
  key
  [ "$K" = "$dirty" ] || { echo "committing a change moved the key"; false; }
  git revert --no-edit HEAD > /dev/null
  key
  [ "$K" = "$clean" ]
}

@test "under commit, the default, staging a change and committing it each change the key" {
  repo
  key
  local clean="$K"
  printf 'changed\n' >> README.md
  key
  local dirty="$K"
  [ "$dirty" != "$clean" ]
  git add README.md
  key
  local staged="$K"
  [ "$staged" != "$dirty" ] || { echo "under commit, staging a change left the key as it was"; false; }
  git commit -q -m changed
  key
  [ "$K" != "$staged" ] || { echo "under commit, a commit left the key as it was"; false; }
  # Staged only: the file is still on disk, but now untracked.
  git revert --no-edit HEAD > /dev/null
  key
  local back="$K"
  git rm -q --cached src/keep.sh
  key
  [ "$K" != "$back" ] || { echo "under commit, a file that left the index left the key as it was"; false; }
}

@test "an untracked file changes the key, by its name and its bytes, but an ignored one is not seen" {
  repo
  key
  local clean="$K"
  printf 'noise\n' > build.log
  key
  [ "$K" = "$clean" ] || { echo "an ignored file moved the key"; false; }
  mkdir -p deep/er
  printf 'new\n' > deep/er/new.txt
  key
  local one="$K"
  [ "$one" != "$clean" ] || { echo "a new untracked file left the key as it was"; false; }
  printf 'other\n' > deep/er/new.txt
  key
  [ "$K" != "$one" ] || { echo "an untracked file's bytes are not in the key"; false; }
  printf 'new\n' > deep/er/new.txt
  key
  [ "$K" = "$one" ]
  # The same bytes under another name: a test can read a file by its name.
  mv deep/er/new.txt deep/er/renamed.txt
  key
  [ "$K" != "$one" ] || { echo "renaming an untracked file left the key as it was"; false; }
  rm -r deep
  key
  [ "$K" = "$clean" ]
}

@test "a deleted tracked file changes the key, and is not the same as an empty one" {
  repo
  key
  local clean="$K"
  rm src/keep.sh
  key
  local gone="$K"
  [ "$gone" != "$clean" ] || { echo "a deleted tracked file left the key as it was"; false; }
  : > src/keep.sh
  key
  [ "$K" != "$gone" ] && [ "$K" != "$clean" ] || { echo "an emptied file keyed as a deleted or an unchanged one"; false; }
  # Deleted from the index too: the path is in neither list.
  git rm -q -f src/keep.sh
  key
  [ "$K" != "$gone" ] && [ "$K" != "$clean" ] || { echo "a file removed from the index keyed as one only deleted from disk"; false; }
}

@test "which of two files with the same bytes was deleted is in the key" {
  repo
  printf 'same\n' > a1.txt
  printf 'same\n' > a2.txt
  git add a1.txt a2.txt
  git commit -q -m twins
  rm a1.txt
  key
  local first="$K"
  git checkout -q -- a1.txt
  rm a2.txt
  key
  [ "$K" != "$first" ] || { echo "deleting one twin keyed as deleting the other"; false; }
}

@test "a change of line endings alone changes the key" {
  repo
  key
  local clean="$K"
  printf 'base\r\n' > README.md
  key
  [ "$K" != "$clean" ] || { echo "CRLF in place of LF left the key as it was"; false; }
  printf 'side\n' > side.txt
  key
  local lf="$K"
  printf 'side\r\n' > side.txt
  key
  [ "$K" != "$lf" ] || { echo "CRLF in an untracked file left the key as it was"; false; }
}

@test "a mode change git sees changes the key" {
  repo
  key
  local clean="$K"
  # The index mode, which every system can change.
  git update-index --chmod=+x src/keep.sh
  key
  [ "$K" != "$clean" ] || { echo "an index mode change left the key as it was"; false; }
  git update-index --chmod=-x src/keep.sh
  key
  [ "$K" = "$clean" ]
}

@test "the mode on disk moves the key where git sees it, on every system" {
  repo
  reuse files
  # 100755 in the index, a plain file on disk: with core.fileMode false git
  # reads no mode on disk, with true it reports the pair 100755 100644.
  git update-index --chmod=+x src/keep.sh
  git commit -q -m 'keep.sh executable in the index'
  chmod -x src/keep.sh
  git config core.fileMode false
  key
  local off="$K"
  git config core.fileMode true
  git diff-files --raw -- src/keep.sh > "$BATS_TEST_TMPDIR/df.txt"
  grep -q -- '^:100755 100644 ' "$BATS_TEST_TMPDIR/df.txt" || { echo "git sees no mode pair: $(cat "$BATS_TEST_TMPDIR/df.txt")"; false; }
  key
  [ "$K" != "$off" ] || { echo "a mode git sees on disk left the key as it was"; false; }
}

@test "a sibling of the state directory with the same prefix is in the key" {
  repo
  key
  local clean="$K"
  mkdir -p .delivery-kitX
  printf 'x\n' > .delivery-kitX/f.txt
  key
  [ "$K" != "$clean" ] || { echo ".delivery-kitX/ was left out with .delivery-kit/"; false; }
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
  # The same files reached by another commit: under commit, another key;
  # under files, the same key.
  git revert --no-edit HEAD > /dev/null
  key
  [ "$K" != "$base" ] || { echo "under commit, another commit kept the key"; false; }
  [ "$changed" != "$base" ]
  reuse files
  key
  local fbase="$K"
  git revert --no-edit HEAD > /dev/null
  git revert --no-edit HEAD > /dev/null
  key
  [ "$K" = "$fbase" ] || { echo "under files, the same files under another commit moved the key"; false; }
  reuse commit
  key
  base="$K"
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
  refuses "nothing recorded — what the key covers (the files, the git state its mode reads, the command, the platform) is not what it was when the key was taken" \
    suite-record "$F" "$K" "$TAP" 0
  [ "$(records)" = 0 ]
  # A file a test left behind.
  key
  printf 'left\n' > leftover.txt
  refuses "is not what it was when the key was taken" suite-record "$F" "$K" "$TAP" 0
  [ "$(records)" = 0 ]
  # A TAP file written inside the tree, outside .delivery-kit/, is such a file.
  rm leftover.txt
  key
  printf '1..1\nok 1 one\n' > suite.tap
  refuses "is not what it was when the key was taken" suite-record "$F" "$K" suite.tap 0
  [ "$(records)" = 0 ]
  # A tree that has no key now records nothing either.
  rm suite.tap
  key
  git update-index --assume-unchanged README.md
  refuses "nothing recorded — no suite key now" suite-record "$F" "$K" "$TAP" 0
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

@test "a skip is red, and is counted" {
  repo
  verdict_is red 0 '1..2' 'ok 1 one' 'ok 2 two # skip not here'
  [ "$(jq -c '[.ok, .skipped]' ".delivery-kit/suite-results/$K.json" | tr -d '\r')" = '[2,1]' ]
  refuses "is red, and a red result is never reused" suite-lookup "$F"
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
  [[ "$(sed -n 2p "$OUT")" == "1..2, 2 ok (0 skipped), 0 not ok, exit 0 — recorded "*" by run $F" ]] || false
  # A later run on the same tree, with the same command, reuses it.
  state 002-later
  runs suite-lookup 002-later
  [ "$(sed -n 1p "$OUT")" = ".delivery-kit/suite-results/$K.json" ]
}

@test "suite-lookup finds nothing before a record, or after a change, committed or not" {
  repo
  refuses "none is recorded for these files, command and platform" suite-lookup "$F"
  verdict_is green 0 '1..1' 'ok 1 one'
  printf 'dirty\n' >> README.md
  refuses "none is recorded for these files, command and platform" suite-lookup "$F"
  git commit -q -am 'a change'
  refuses "none is recorded for these files, command and platform" suite-lookup "$F"
  git update-index --assume-unchanged README.md
  refuses "no reusable result — no suite key" suite-lookup "$F"
}

@test "under files, a green result on uncommitted work is reused after the work is committed" {
  repo
  reuse files
  printf 'fixed\n' >> src/keep.sh
  verdict_is green 0 '1..1' 'ok 1 one'
  local rec=".delivery-kit/suite-results/$K.json"
  runs suite-lookup "$F"
  [ "$(sed -n 1p "$OUT")" = "$rec" ]
  # J commits the files it ran on; N cites that run.
  git commit -q -am 'J late commit'
  runs suite-lookup "$F"
  [ "$(sed -n 1p "$OUT")" = "$rec" ]
  # One byte more, and it is another set of files.
  printf 'x' >> src/keep.sh
  refuses "none is recorded for these files, command and platform" suite-lookup "$F"
}

@test "under files, a new untracked file and an unstaged deletion read the same once committed" {
  repo
  reuse files
  printf 'new test\n' > src/a-new.sh
  rm README.md
  verdict_is green 0 '1..1' 'ok 1 one'
  local rec=".delivery-kit/suite-results/$K.json"
  git add src/a-new.sh README.md
  git commit -q -m 'J adds a test file and deletes another'
  runs suite-lookup "$F"
  [ "$(sed -n 1p "$OUT")" = "$rec" ] || { echo "J's run on the same files was not reused after the commit"; false; }
}

@test "under commit, a green result on uncommitted work is not reused after the work is committed" {
  repo
  printf 'fixed\n' >> src/keep.sh
  verdict_is green 0 '1..1' 'ok 1 one'
  runs suite-lookup "$F"
  git commit -q -am 'J late commit'
  refuses "none is recorded for these files, command and platform under suiteReuse commit" suite-lookup "$F"
}

# The git state a suite can read, changed with the files left alone: a
# commit message (a trailer the suite checks in `git log -1`), staged bytes
# (a suite comparing `git show :path` with the file), and HEAD moved past
# the base (a branch-range check over main...HEAD).
@test "under commit a changed commit message, staged bytes or a moved HEAD each misses" {
  repo
  verdict_is green 0 '1..1' 'ok 1 one'
  git commit -q --amend -m 'base, with a trailer the suite refuses'
  refuses "none is recorded" suite-lookup "$F"
  verdict_is green 0 '1..1' 'ok 1 one'
  git update-index --cacheinfo "100644,$(printf 'staged\n' | git hash-object -w --stdin),README.md"
  [ "$(cat README.md)" = base ]
  refuses "none is recorded" suite-lookup "$F"
  git reset -q
  runs suite-lookup "$F"
  git commit -q --allow-empty -m 'HEAD past main'
  refuses "none is recorded" suite-lookup "$F"
}

@test "under files the same three git changes reuse the result" {
  repo
  reuse files
  verdict_is green 0 '1..1' 'ok 1 one'
  git commit -q --amend -m 'base, with a trailer the suite refuses'
  runs suite-lookup "$F"
  git update-index --cacheinfo "100644,$(printf 'staged\n' | git hash-object -w --stdin),README.md"
  runs suite-lookup "$F"
  git reset -q
  git commit -q --allow-empty -m 'HEAD past main'
  runs suite-lookup "$F"
}

@test "with suiteReuse off nothing is kept or reused, and a bad value has no key" {
  repo
  verdict_is green 0 '1..1' 'ok 1 one'
  local k="$K"
  reuse off
  refuses "config.suiteReuse is off" suite-lookup "$F"
  refuses "config.suiteReuse is off" suite-key "$F"
  refuses "nothing recorded — no suite key now: config.suiteReuse is off" suite-record "$F" "$k" "$TAP" 0
  reuse sometimes
  refuses "is none of commit, files or off" suite-key "$F"
  jq '.config.suiteReuse = true' "$SF" > "$BATS_TEST_TMPDIR/t.json" && mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  refuses "is none of commit, files or off" suite-key "$F"
  jq '.config.suiteReuse = null' "$SF" > "$BATS_TEST_TMPDIR/t.json" && mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  runs suite-lookup "$F"
}

@test "under commit, a record under the right file name whose head is another commit is refused" {
  repo
  verdict_is green 0 '1..1' 'ok 1 one'
  local rec=".delivery-kit/suite-results/$K.json" first other
  first="$(git rev-parse HEAD)"
  git commit -q --allow-empty -m other
  other="$(git rev-parse HEAD)"
  git reset -q --hard "$first"
  runs suite-lookup "$F"
  # Forged: the key, mode and digests are this tree's; only head differs.
  jq --arg h "$other" '.head = $h' "$rec" > "$BATS_TEST_TMPDIR/forged.json"
  mv "$BATS_TEST_TMPDIR/forged.json" "$rec"
  refuses "records other files, another command, platform or mode" suite-lookup "$F"
}

@test "a record made under one mode is never reused under another" {
  repo
  reuse files
  verdict_is green 0 '1..1' 'ok 1 one'
  local rec=".delivery-kit/suite-results/$K.json"
  reuse commit
  refuses "none is recorded" suite-lookup "$F"
  key
  # Copied under the other mode's key, its mode and head still say files.
  cp "$rec" ".delivery-kit/suite-results/$K.json"
  jq --arg k "$K" '.key = $k' "$rec" > ".delivery-kit/suite-results/$K.json"
  refuses "records other files, another command, platform or mode" suite-lookup "$F"
  jq --arg k "$K" --arg h "$(git rev-parse HEAD)" '.key = $k | .head = $h' "$rec" > ".delivery-kit/suite-results/$K.json"
  refuses "records other files, another command, platform or mode" suite-lookup "$F"
}

@test "a fresh run reuses a green result an earlier run recorded on the same uncommitted files" {
  repo
  mkdir -p work
  printf 'wip\n' > work/new.sh
  printf 'more\n' >> README.md
  verdict_is green 0 '1..1' 'ok 1 one'
  state 002-fresh
  runs suite-lookup 002-fresh
  [ "$(sed -n 1p "$OUT")" = ".delivery-kit/suite-results/$K.json" ]
  [[ "$(sed -n 2p "$OUT")" == *"by run $F" ]] || { echo "the summary does not name the run that recorded it: $(cat "$OUT")"; false; }
}

# spec <feature> <dir> — an untracked spec file for the run, recorded as
# its artifacts.spec, as B leaves it.
spec() {
  local sf=".delivery-kit/runs/$1/progress.json"
  mkdir -p "$2"
  printf '# spec\n' > "$2/spec.md"
  jq --arg s "$2/spec.md" '.artifacts.spec = $s' "$sf" > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" "$sf"
}

@test "F.5 with --base reuses an earlier run's green result on the tree before its own untracked spec" {
  repo
  verdict_is green 0 '1..2' 'ok 1 one' 'ok 2 two'
  local rec=".delivery-kit/suite-results/$K.json"
  state 002-next
  spec 002-next specs/002-next
  # The spec files are bytes the suite could read: these files have no record.
  refuses "none is recorded for these files, command and platform" suite-lookup 002-next
  runs suite-lookup 002-next --base
  [ "$(sed -n 1p "$OUT")" = "$rec" ]
  [[ "$(sed -n 2p "$OUT")" == "1..2, 2 ok (0 skipped), 0 not ok, exit 0 — recorded "*" by run $F — for these files without the untracked specs/002-next/" ]] \
    || { echo "the summary does not say the spec directory was left out: $(cat "$OUT")"; false; }
}

@test "--base leaves out only the run's untracked spec directory" {
  repo
  verdict_is green 0 '1..1' 'ok 1 one'
  state 002-next
  spec 002-next specs/002-next
  # Any other change misses: an untracked file elsewhere, a tracked change.
  printf 'other\n' > notes.txt
  refuses "and without the untracked specs/002-next/, none is recorded for these files, command and platform" suite-lookup 002-next --base
  rm notes.txt
  printf 'x\n' >> README.md
  refuses "none is recorded" suite-lookup 002-next --base
  git checkout -q -- README.md
}

@test "--base does not leave out a sibling spec directory with the same prefix" {
  repo
  verdict_is green 0 '1..1' 'ok 1 one'
  state 002-next
  spec 002-next specs/002-next
  mkdir -p specs/002-nextX
  printf 'x\n' > specs/002-nextX/x.txt
  refuses "and without the untracked specs/002-next/, none is recorded" suite-lookup 002-next --base
}

@test "--base refuses a spec under .delivery-kit/ or outside the repository, naming no path" {
  repo
  state 002-next
  spec 002-next .delivery-kit/specs
  refuses "sits under .delivery-kit/, which is left out already" suite-lookup 002-next --base
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  printf '# spec\n' > "$BATS_TEST_TMPDIR/elsewhere/spec.md"
  jq --arg s "$BATS_TEST_TMPDIR/elsewhere/spec.md" '.artifacts.spec = $s' .delivery-kit/runs/002-next/progress.json > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" .delivery-kit/runs/002-next/progress.json
  refuses "names a spec file outside this repository" suite-lookup 002-next --base
  [[ "$(cat "$ERR")" != *"$BATS_TEST_TMPDIR"* ]] || { echo "the refusal printed a path: $(cat "$ERR")"; false; }
  jq '.artifacts.spec = "/no/such/spec.md"' .delivery-kit/runs/002-next/progress.json > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" .delivery-kit/runs/002-next/progress.json
  refuses "names no spec file that exists" suite-lookup 002-next --base
  [[ "$(cat "$ERR")" != *"/no/such"* ]] || { echo "the refusal printed a path: $(cat "$ERR")"; false; }
}

@test "--base does not leave out a spec directory already tracked" {
  repo
  verdict_is green 0 '1..1' 'ok 1 one'
  state 002-next
  spec 002-next specs/002-next
  git add specs/002-next/spec.md
  git commit -q -m spec
  refuses "none is recorded" suite-lookup 002-next --base
}

@test "--base needs a spec file in a directory of its own, and is lookup's alone" {
  repo
  verdict_is green 0 '1..1' 'ok 1 one'
  state 002-next
  printf 'x\n' > stray.txt
  refuses "and none without the spec directory: " suite-lookup 002-next --base
  printf '# spec\n' > spec.md
  jq '.artifacts.spec = "spec.md"' .delivery-kit/runs/002-next/progress.json > t.json && mv t.json .delivery-kit/runs/002-next/progress.json
  refuses "no spec directory to leave out" suite-lookup 002-next --base
  refuses "usage: suite-lookup <feature> [--base]" suite-lookup 002-next --other
  refuses "usage: suite-lookup <feature> [--base]" suite-lookup 002-next --base extra
  refuses "usage: suite-key <feature>" suite-key 002-next --base
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
  refuses "none is recorded for these files, command and platform" suite-lookup 002-other
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\necho OtherOS\n' > "$BATS_TEST_TMPDIR/bin/uname"
  chmod +x "$BATS_TEST_TMPDIR/bin/uname"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" refuses "none is recorded for these files, command and platform" suite-lookup "$F"
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
  refuses "records other files, another command, platform or mode" suite-lookup "$F"
  printf 'not json' > "$rec"
  refuses "is not one readable record" suite-lookup "$F"
}

@test "suite-key refuses, never issues a key, when the index-tag check itself fails" {
  repo
  git update-index --assume-unchanged README.md
  printf 'hidden\n' >> README.md
  # A grep that errors (exit 2) — the shape a scratch file removed under it
  # gives. Read as "no match", it would issue a key over the hidden change.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\nexit 2\n' > "$BATS_TEST_TMPDIR/bin/grep"
  chmod +x "$BATS_TEST_TMPDIR/bin/grep"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" refuses "could not read the index tags" suite-key "$F"
}

@test "suite-key has no key in a repository with a submodule" {
  repo
  git update-index --add --cacheinfo "160000,$(git rev-parse HEAD),sub"
  git commit -q -m 'a submodule'
  mkdir -p sub
  # An uninitialised submodule: git status shows nothing.
  [ -z "$(git status --porcelain --ignore-submodules=none -- sub)" ]
  refuses "the tree holds a submodule (sub)" suite-key "$F"
}

@test "a changed tracked file under .delivery-kit/ changes the key" {
  repo
  mkdir -p .delivery-kit/fixtures
  printf 'good\n' > .delivery-kit/fixtures/in.txt
  git add .delivery-kit/fixtures/in.txt
  git commit -q -m 'a tracked fixture'
  key
  local before="$K"
  printf 'bad\n' > .delivery-kit/fixtures/in.txt
  key
  [ "$K" != "$before" ] || { echo "a tracked file under .delivery-kit/ is not in the key"; false; }
}

@test "the key sees a file's bytes when a line-ending conversion hides them from git status" {
  repo
  git config core.autocrlf true
  verdict_is green 0 '1..1' 'ok 1 one'
  printf 'base\r\n' > README.md
  git add README.md
  [ -z "$(git status --porcelain -- README.md)" ]
  refuses "none is recorded for these files, command and platform" suite-lookup "$F"
}

@test "the key sees a file's bytes when a clean filter hides them from git status" {
  repo
  git config filter.strip.clean "sed 's/^v=.*/v=1/'"
  git config filter.strip.smudge cat
  printf 'README.md filter=strip\n' > .git/info/attributes
  printf 'v=1\n' > README.md
  git add README.md
  git commit -q -m 'v=1'
  verdict_is green 0 '1..1' 'ok 1 one'
  printf 'v=999\n' > README.md
  git add README.md
  [ -z "$(git status --porcelain -- README.md)" ]
  refuses "none is recorded for these files, command and platform" suite-lookup "$F"
}

@test "the key sees a file's bytes when its size and time are what the index holds" {
  repo
  git config core.trustctime false
  git config core.checkStat minimal
  touch -d '2020-01-02 03:04:05' README.md
  git update-index --refresh > /dev/null
  verdict_is green 0 '1..1' 'ok 1 one'
  # Same size, same time: the stat cache calls it unchanged.
  printf 'case\n' > README.md
  touch -d '2020-01-02 03:04:05' README.md
  [ -z "$(git status --porcelain -- README.md)" ]
  [ "$(cat README.md)" = case ]
  refuses "none is recorded for these files, command and platform" suite-lookup "$F"
}

@test "a test number repeated, missing or out of range is red; the order is not judged" {
  repo
  verdict_is red 0 '1..3' 'ok 1 one' 'ok 1 one' 'ok 1 one'
  verdict_is red 0 '1..2' 'ok 1 one' 'ok 3 three'
  verdict_is red 0 '1..1' 'ok - unnumbered'
  verdict_is red 0 '1..2' 'ok 1 one' 'ok 2x two'
  verdict_is red 0 '1..2' 'ok 1 one' 'ok 0 zero'
  # A parallel runner prints in the order tests finish.
  verdict_is green 0 '1..3' 'ok 2 two' 'ok 3 three' 'ok 1 one'
}

@test "suite-lookup refuses counts that are not whole numbers, and another byte digest" {
  repo
  verdict_is green 0 '1..1' 'ok 1 one'
  local rec=".delivery-kit/suite-results/$K.json"
  cp "$rec" "$BATS_TEST_TMPDIR/green.json"
  jq '.plan = 1.5 | .ok = 1.5' "$rec" > t.json && mv t.json "$rec"
  refuses "is red" suite-lookup "$F"
  jq '.skipped = -1' "$BATS_TEST_TMPDIR/green.json" > "$rec"
  refuses "is red" suite-lookup "$F"
  jq '.ok = "1"' "$BATS_TEST_TMPDIR/green.json" > "$rec"
  refuses "is red" suite-lookup "$F"
  jq '.bytes = "0000"' "$BATS_TEST_TMPDIR/green.json" > "$rec"
  refuses "records other files, another command, platform or mode" suite-lookup "$F"
  # The commit's tree is kept to be read, never compared; the mode and,
  # under commit, HEAD's commit id are.
  jq '.tree = "0000"' "$BATS_TEST_TMPDIR/green.json" > "$rec"
  runs suite-lookup "$F"
  jq '.mode = "files"' "$BATS_TEST_TMPDIR/green.json" > "$rec"
  refuses "records other files, another command, platform or mode" suite-lookup "$F"
  jq '.head = "0000"' "$BATS_TEST_TMPDIR/green.json" > "$rec"
  refuses "records other files, another command, platform or mode" suite-lookup "$F"
  # A green that counts a skip is not a green run's.
  jq '.skipped = 1' "$BATS_TEST_TMPDIR/green.json" > "$rec"
  refuses "is red" suite-lookup "$F"
  cp "$BATS_TEST_TMPDIR/green.json" "$rec"
  runs suite-lookup "$F"
}

# fake_uname <dir> <s> <m> — a uname that answers -s and -m apart.
fake_uname() {
  mkdir -p "$1"
  printf '#!/bin/sh\ncase "$1" in -s) echo %s ;; -m) echo %s ;; *) echo x ;; esac\n' "$2" "$3" > "$1/uname"
  chmod +x "$1/uname"
}

@test "the key changes with the machine alone" {
  repo
  fake_uname "$BATS_TEST_TMPDIR/b1" SameOS arch1
  fake_uname "$BATS_TEST_TMPDIR/b2" SameOS arch2
  PATH="$BATS_TEST_TMPDIR/b1:$PATH" key
  local a="$K"
  PATH="$BATS_TEST_TMPDIR/b2:$PATH" key
  [ "$K" != "$a" ]
}

@test "suite-key has no key on an unborn HEAD" {
  git init -q .
  git symbolic-ref HEAD refs/heads/main
  git config core.autocrlf false
  state "$F"
  refuses "HEAD names no commit yet" suite-key "$F"
}

@test "a tracked file name with a space is not read as a hidden index entry" {
  repo
  printf 'x\n' > 'my file.txt'
  git add 'my file.txt'
  git commit -q -m spaced
  key
}

@test "suite-key has no key with an unmerged path, or an untracked repository inside the tree" {
  repo
  git checkout -q -b side
  printf 'side\n' > README.md
  git commit -q -am side
  git checkout -q main
  printf 'main\n' > README.md
  git commit -q -am main
  git merge -q side > /dev/null 2>&1 || true
  refuses "the index holds an unmerged path (README.md)" suite-key "$F"
  git merge --abort
  key
  mkdir -p nested
  git -C nested init -q
  printf 'q\n' > nested/q.txt
  refuses "an untracked directory holds a repository of its own (nested/)" suite-key "$F"
}

@test "an odd untracked file name survives the trip through quoting" {
  repo
  key
  local clean="$K"
  printf 'a\n' > "$(printf 'caf\303\251.txt')"
  key
  local one="$K"
  [ "$one" != "$clean" ]
  printf 'b\n' > "$(printf 'caf\303\251.txt')"
  key
  [ "$K" != "$one" ] || { echo "a quoted file name's bytes are not in the key"; false; }
}

@test "suite-lookup refuses a record whose key or platform was edited" {
  repo
  verdict_is green 0 '1..1' 'ok 1 one'
  local rec=".delivery-kit/suite-results/$K.json" o="$BATS_TEST_TMPDIR/orig.json"
  cp "$rec" "$o"
  jq '.platform = "OtherOS x"' "$o" > "$rec"
  refuses "records other files, another command, platform or mode" suite-lookup "$F"
  jq '.key = "0000000000000000000000000000000000000000"' "$o" > "$rec"
  refuses "records other files, another command, platform or mode" suite-lookup "$F"
}

@test "suite-lookup refuses a hand-edited green whose counts are not a green run's" {
  repo
  verdict_is green 0 '1..2' 'ok 1 one' 'ok 2 two'
  local rec=".delivery-kit/suite-results/$K.json" o="$BATS_TEST_TMPDIR/orig.json"
  cp "$rec" "$o"
  jq '.notOk = 1' "$o" > "$rec";              refuses "is red" suite-lookup "$F"
  jq '.nonTap = 1' "$o" > "$rec";             refuses "is red" suite-lookup "$F"
  jq '.plan = 0 | .ok = 0' "$o" > "$rec";     refuses "is red" suite-lookup "$F"
  jq '.plan = "2" | .ok = "2"' "$o" > "$rec"; refuses "is red" suite-lookup "$F"
  jq '.ok = 3' "$o" > "$rec";                 refuses "is red" suite-lookup "$F"
  cat "$o" "$o" > "$rec";                     refuses "is not one readable record" suite-lookup "$F"
  cp "$o" "$rec"
  runs suite-lookup "$F"
}

@test "an exit code with a leading zero is read in base ten" {
  repo
  verdict_is red 08 '1..1' 'ok 1 one'
  [ "$(jq -r .rc ".delivery-kit/suite-results/$K.json" | tr -d '\r')" = 8 ]
}

@test "a record holds no CR byte" {
  repo
  verdict_is green 0 '1..1' 'ok 1 one'
  [ "$(tr -cd '\r' < ".delivery-kit/suite-results/$K.json" | wc -c | tr -d ' ')" = 0 ]
}

@test "a line that starts ok without a space is not an ok" {
  repo
  verdict_is red 0 '1..2' 'ok 1 one' 'okay'
  # A tab is not the space TAP puts after ok, even before a good number.
  verdict_is red 0 '1..2' 'ok 1 one' $'ok\t2 two'
}

@test "blank and whitespace-only lines before the plan are skipped" {
  repo
  verdict_is green 0 '' '1..1' 'ok 1 one'
  verdict_is green 0 '1..1' '   ' 'ok 1 one'
}

@test "an upper-case SKIP is counted, and is red" {
  repo
  verdict_is red 0 '1..1' 'ok 1 one # SKIP not here'
  [ "$(jq -r .skipped ".delivery-kit/suite-results/$K.json" | tr -d '\r')" = 1 ]
}

# --- tap-check ----------------------------------------------------------------
# tap-check judges any TAP file, keyed or not, by the rules suite-record keeps
# its verdict by. It needs no feature and no repository.

# tap_ok <want summary> <args...> / tap_no <fragment> <args...>
tap_ok() {
  local want="$1" rc=0; shift
  bash "$PROG" tap-check "$@" > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -eq 0 ] || { echo "exit $rc, expected 0: $(cat "$ERR")"; return 1; }
  [ "$(cat "$OUT")" = "$want" ] || { echo "printed '$(cat "$OUT")', expected '$want'"; return 1; }
}
tap_no() {
  local frag="$1" rc=0; shift
  bash "$PROG" tap-check "$@" > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -eq 1 ] || { echo "exit $rc, expected 1 naming: $frag; out: $(cat "$OUT")"; return 1; }
  [[ "$(cat "$ERR")" == *"$frag"* ]] || { echo "stderr lacks '$frag': $(cat "$ERR")"; return 1; }
  [ ! -s "$OUT" ] || { echo "a refusal printed on stdout: $(cat "$OUT")"; return 1; }
  [[ "$(cat "$ERR")" != *"$BATS_TEST_TMPDIR"* ]] || { echo "a refusal printed the file's path: $(cat "$ERR")"; return 1; }
}

@test "tap-check passes a clean run, with or without the expected count, outside any repository" {
  t="$BATS_TEST_TMPDIR/run.tap"
  printf '1..3\nok 2 b\n# note\n\nok 1 a\nok 3 c\n' > "$t"
  tap_ok 'suite ok: 1..3, 3 ok, 0 skipped, 0 not ok, 0 non-TAP' "$t"
  tap_ok 'suite ok: 1..3, 3 ok, 0 skipped, 0 not ok, 0 non-TAP' "$t" 3
  printf '1..1\r\nok 1 a\r\n' > "$t"
  tap_ok 'suite ok: 1..1, 1 ok, 0 skipped, 0 not ok, 0 non-TAP' "$t"
}

@test "tap-check refuses a skip, a not ok, a stray line and a short count, each by name" {
  t="$BATS_TEST_TMPDIR/run.tap"
  printf '1..2\nok 1 a\nok 2 b # skip later\n' > "$t";  tap_no "1 skipped, and a skip is not a pass" "$t"
  printf '1..2\nok 1 a\nok 2 b # SKIP later\n' > "$t";  tap_no "1 skipped" "$t" 2
  printf '1..2\nok 1 a\nnot ok 2 b\n' > "$t";           tap_no "1 not ok" "$t"
  printf '1..2\nok 1 a\nwarning: x\nok 2 b\n' > "$t";   tap_no "1 non-TAP line(s)" "$t"
  printf '1..2\nok 1 a\n' > "$t";                       tap_no "ok count 1, expected 2" "$t"
  printf '1..1\nok 1 a\nok 2 b\n' > "$t";               tap_no "ok count 2, expected 1" "$t"
  printf '1..2\nok 1 a\nok 1 a\n' > "$t";               tap_no "1 test number(s) missing, repeated or outside the plan" "$t"
  printf '1..2\nok 1 a\nok 2 b\n1..2\n' > "$t";         tap_no "a second plan line" "$t"
  printf '1..2\nok 1 a\nnot ok 2 b # TODO later\n' > "$t"; tap_no "1 not ok" "$t"
  printf '\n\n' > "$t";                                 tap_no "the TAP file is empty" "$t"
}

@test "tap-check reads the plan line first, and against the expected count when one is given" {
  t="$BATS_TEST_TMPDIR/run.tap"
  printf 'ok 1 a\n1..1\n' > "$t";   tap_no "the first non-blank line is not a plan line 1..N with N at least 1" "$t"
  printf '1..0\n' > "$t";           tap_no "the first non-blank line is not a plan line 1..N with N at least 1" "$t"
  printf '1..01\nok 1 a\n' > "$t";  tap_no "not a plan line 1..N" "$t"
  printf '1..2\nok 1 a\nok 2 b\n' > "$t"
  tap_no "the first non-blank line is not the plan line 1..3" "$t" 3
  tap_no "the first non-blank line is not the plan line 1..1" "$t" 1
  # The plan is compared as text: 1..02 is not the plan line 1..2.
  printf '1..02\nok 1 a\nok 2 b\n' > "$t"
  tap_no "the first non-blank line is not the plan line 1..2" "$t" 2
}

@test "tap-check, and check-suite.sh through it, need only bash and awk" {
  t="$BATS_TEST_TMPDIR/run.tap"
  printf '1..1\nok 1 a\n' > "$t"
  local bin="$BATS_TEST_TMPDIR/onlyawk"
  mkdir -p "$bin"
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$(command -v awk)" > "$bin/awk"
  chmod +x "$bin/awk"
  run env PATH="$bin" "$BASH" "$PROG" tap-check "$t"
  [ "$status" -eq 0 ] || { echo "tap-check needed more than bash and awk: $output"; false; }
  [ "$output" = 'suite ok: 1..1, 1 ok, 0 skipped, 0 not ok, 0 non-TAP' ] || { echo "printed: $output"; false; }
  local cs="$ROOT/scripts/check-suite.sh"
  if [ -f "$cs" ] && [ -z "${PROGRESS_SH_UNDER_TEST:-}" ]; then
    run env PATH="$bin" "$BASH" "$cs" 1 "$t"
    [ "$status" -eq 0 ] || { echo "check-suite.sh needed more than bash and awk: $output"; false; }
  fi
}

@test "tap-check refuses bad arguments and a file it cannot read, never naming the file" {
  t="$BATS_TEST_TMPDIR/run.tap"
  printf '1..1\nok 1 a\n' > "$t"
  tap_no "usage: progress.sh tap-check <tap-file> [<expected-count>]"
  tap_no "where <expected-count> is a positive integer" "$t" 0
  tap_no "where <expected-count> is a positive integer" "$t" 01
  tap_no "where <expected-count> is a positive integer" "$t" x
  tap_no "usage: progress.sh tap-check" "$t" 1 extra
  tap_no "the TAP file does not exist or cannot be read" "$BATS_TEST_TMPDIR/none.tap"
  tap_no "the TAP file does not exist or cannot be read" "$BATS_TEST_TMPDIR"
  # An awk that cannot read is a refusal, and its own words never print.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\necho "awk: cannot open %s" >&2\nexit 2\n' "$t" > "$BATS_TEST_TMPDIR/bin/awk"
  chmod +x "$BATS_TEST_TMPDIR/bin/awk"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" tap_no "the TAP file cannot be read" "$t"
}

@test "suite-record keeps tap-check's verdict, and check-suite.sh holds no copy of the rules" {
  repo
  # One judge: every shape tap-check refuses, suite-record keeps as red.
  local shape
  for shape in '1..1\nok 1 a # skip x\n' '1..2\nok 1 a\nok 1 a\n' '1..1\nok 1 a\nstray\n' '1..0\n'; do
    printf "$shape" > "$TAP"
    tap_no "" "$TAP"
    record 0
    [ "$V" = red ] || { echo "suite-record called '$shape' $V, tap-check refused it"; false; }
  done
  printf '1..1\nok 1 a\n' > "$TAP"
  tap_ok 'suite ok: 1..1, 1 ok, 0 skipped, 0 not ok, 0 non-TAP' "$TAP"
  record 0
  [ "$V" = green ]
  # The repository's quickstart check hands the file to tap-check and judges
  # nothing itself: a second copy of the rules is how the two drifted.
  local cs="$ROOT/scripts/check-suite.sh"
  if [ -f "$cs" ]; then
    # Code only: a comment can name tap-check, or awk, without running it.
    grep -v -E -- '^[[:space:]]*#' "$cs" | sed -e 's/[[:space:]]#.*$//' > "$BATS_TEST_TMPDIR/code.txt"
    grep -q -- 'tap-check' "$BATS_TEST_TMPDIR/code.txt" || { echo "check-suite.sh no longer calls tap-check"; false; }
    if grep -n -E -- '(^|[^[:alnum:]_])(g|m|n)?awk([^[:alnum:]_]|$)' "$BATS_TEST_TMPDIR/code.txt" > "$BATS_TEST_TMPDIR/awk.txt"; then
      echo "check-suite.sh runs an awk itself: $(cat "$BATS_TEST_TMPDIR/awk.txt")"; false
    fi
  fi
}
