#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for `progress.sh branch-cut <feature>` (feature 058): phase B's branch
# cut, safe to run again, as init is. It reads the branch and the base from the
# state file. Every test builds its own throwaway repository under
# $BATS_TEST_TMPDIR, and asserts the exact status and line.
#
# PROGRESS_SH_UNDER_TEST points the suite at another copy of the script, for
# mutation runs.

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
  F=001-demo
  git init -q .
  git symbolic-ref HEAD refs/heads/main
  git config core.autocrlf false
  git config commit.gpgsign false
  printf '.delivery-kit/\n' > .gitignore
  git add .gitignore
  git commit -q -m base
  bash "$PROG" init "$F" "$F" main other > /dev/null
  SF=".delivery-kit/runs/$F/progress.json"
}

# field <key> <value> — one string field of the state file.
field() {
  jq --arg k "$1" --arg v "$2" '.[$k] = $v' "$SF" > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" "$SF"
}

# refs — every ref and the commit it names, and HEAD: the proof a refusal
# changed nothing.
refs() { git for-each-ref; git symbolic-ref -q HEAD || git rev-parse HEAD; }

# refused <word in stderr> — exit 1, nothing on stdout, the word on stderr, and
# no ref moved since BEFORE.
refused() {
  [ "$status" -eq 1 ] || { echo "status $status: $output"; return 1; }
  [ -z "$output" ] || { echo "stdout was: $output"; return 1; }
  [[ "$stderr" == *"$1"* ]] || { echo "stderr was: $stderr"; return 1; }
  [ "$(refs)" = "$BEFORE" ] || { echo "a ref moved"; return 1; }
}

@test "branch-cut cuts an absent branch from the recorded base, and uncommitted work stays" {
  local base; base="$(git rev-parse main)"
  printf 'draft\n' > spec.md
  run --separate-stderr bash "$PROG" branch-cut "$F"
  [ "$status" -eq 0 ] || { echo "status $status: $stderr"; false; }
  [ "$output" = "branch $F cut from main" ] || { echo "stdout: $output"; false; }
  [ "$(git symbolic-ref HEAD)" = "refs/heads/$F" ]
  [ "$(git rev-parse "refs/heads/$F")" = "$base" ]
  [ "$(cat spec.md)" = draft ]
}

@test "branch-cut cuts from the recorded base, whatever HEAD is on" {
  # The mutation this catches: cut from HEAD, or from a name the caller typed.
  local base; base="$(git rev-parse main)"
  git checkout -q -b other
  git commit -q --allow-empty -m other
  run --separate-stderr bash "$PROG" branch-cut "$F"
  [ "$status" -eq 0 ] || { echo "status $status: $stderr"; false; }
  [ "$(git rev-parse "refs/heads/$F")" = "$base" ]
}

@test "branch-cut run three times changes nothing after the first" {
  local tip
  printf 'draft\n' > spec.md
  bash "$PROG" branch-cut "$F" > /dev/null
  tip="$(git rev-parse HEAD)"
  git commit -q --allow-empty -m 'work on the branch'
  tip="$(git rev-parse HEAD)"
  local n
  for n in 1 2; do
    run --separate-stderr bash "$PROG" branch-cut "$F"
    [ "$status" -eq 0 ] || { echo "status $status: $stderr"; false; }
    [ "$output" = "already on branch $F" ] || { echo "stdout: $output"; false; }
    [ "$(git rev-parse HEAD)" = "$tip" ]
    [ "$(git symbolic-ref HEAD)" = "refs/heads/$F" ]
    [ "$(cat spec.md)" = draft ]
  done
}

@test "branch-cut switches to the branch from elsewhere when the base is its ancestor" {
  local tip
  bash "$PROG" branch-cut "$F" > /dev/null
  git commit -q --allow-empty -m 'work on the branch'
  tip="$(git rev-parse HEAD)"
  git checkout -q main
  printf 'draft\n' > spec.md
  run --separate-stderr bash "$PROG" branch-cut "$F"
  [ "$status" -eq 0 ] || { echo "status $status: $stderr"; false; }
  [ "$output" = "switched to branch $F" ] || { echo "stdout: $output"; false; }
  [ "$(git symbolic-ref HEAD)" = "refs/heads/$F" ]
  [ "$(git rev-parse HEAD)" = "$tip" ]
  [ "$(cat spec.md)" = draft ]
}

@test "branch-cut treats a detached HEAD as elsewhere" {
  bash "$PROG" branch-cut "$F" > /dev/null
  git checkout -q --detach
  run --separate-stderr bash "$PROG" branch-cut "$F"
  [ "$status" -eq 0 ] || { echo "status $status: $stderr"; false; }
  [ "$output" = "switched to branch $F" ] || { echo "stdout: $output"; false; }
  [ "$(git symbolic-ref HEAD)" = "refs/heads/$F" ]
}

@test "branch-cut refuses a branch the base is not an ancestor of, and names both and the command" {
  bash "$PROG" branch-cut "$F" > /dev/null
  git checkout -q main
  git commit -q --allow-empty -m 'the base moved'
  BEFORE="$(refs)"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused "git checkout $F"
  [[ "$stderr" == *"'$F'"* && "$stderr" == *"'main'"* ]] || { echo "stderr: $stderr"; false; }
}

@test "branch-cut refuses an empty branch or base in the state file, and guesses no name" {
  BEFORE="$(refs)"
  field branch ''
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused 'records no branch'
  field branch "$F"
  field baseBranch ''
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused 'records no base branch'
}

@test "branch-cut refuses a name git would read as a flag or expand" {
  local n
  git checkout -q -b previous
  git checkout -q main
  BEFORE="$(refs)"
  for n in -x '@{-1}' '@' 'a b' 'a..b'; do
    field branch "$n"
    run --separate-stderr bash "$PROG" branch-cut "$F"
    refused 'not a branch name'
  done
  field branch "$F"
  for n in -x '@{-1}'; do
    field baseBranch "$n"
    run --separate-stderr bash "$PROG" branch-cut "$F"
    refused 'not a branch name'
  done
}

@test "branch-cut refuses a base with no commit here, when it needs the base" {
  field baseBranch gone
  BEFORE="$(refs)"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused "'gone'"
  # On the branch already, the base is not needed.
  git checkout -q -b "$F"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  [ "$status" -eq 0 ] || { echo "status $status: $stderr"; false; }
  [ "$output" = "already on branch $F" ]
  # With the branch present and HEAD elsewhere, it is needed again.
  git checkout -q main
  BEFORE="$(refs)"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused "'gone'"
}

@test "branch-cut reads the branch, never a tag of the same name" {
  # A tag named as the base, on an older commit: the mutation is a start point
  # without refs/heads/, which git reads as the tag, with a warning.
  local old base
  old="$(git rev-parse HEAD)"
  git commit -q --allow-empty -m second
  base="$(git rev-parse HEAD)"
  git tag main "$old"
  git tag "$F" "$old"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  [ "$status" -eq 0 ] || { echo "status $status: $stderr"; false; }
  [ "$(git rev-parse "refs/heads/$F")" = "$base" ]
  [ "$(git symbolic-ref HEAD)" = "refs/heads/$F" ]
  git checkout -q main 2> /dev/null
  run --separate-stderr bash "$PROG" branch-cut "$F"
  [ "$status" -eq 0 ] || { echo "status $status: $stderr"; false; }
  [ "$output" = "switched to branch $F" ]
  [ "$(git symbolic-ref HEAD)" = "refs/heads/$F" ]
}

@test "branch-cut keeps uncommitted work when git refuses the switch" {
  bash "$PROG" branch-cut "$F" > /dev/null
  printf 'theirs\n' > spec.md
  git add spec.md
  git commit -q -m 'the branch holds spec.md'
  git checkout -q main
  printf 'mine\n' > spec.md
  BEFORE="$(refs)"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused 'git could not switch'
  [ "$(cat spec.md)" = mine ]
}

@test "branch-cut refuses a branch checked out in another worktree" {
  bash "$PROG" branch-cut "$F" > /dev/null
  git checkout -q main
  git worktree add -q "$BATS_TEST_TMPDIR/other" "$F"
  BEFORE="$(refs)"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused 'git could not switch'
  git worktree remove --force "$BATS_TEST_TMPDIR/other"
}

@test "branch-cut takes no other argument" {
  BEFORE="$(refs)"
  run --separate-stderr bash "$PROG" branch-cut "$F" another
  refused 'usage: branch-cut <feature>'
}

@test "branch-cut is refused on an abandoned run" {
  bash "$PROG" abandon "$F" 2> /dev/null
  BEFORE="$(refs)"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused 'was abandoned'
}
