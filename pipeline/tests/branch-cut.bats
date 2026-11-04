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

# tracked — a committed file for dirty to change. Run before the branch exists,
# so the branch holds it too.
tracked() {
  printf 'one\n' > tracked.txt
  git add tracked.txt
  git commit -q -m tracked
}

# dirty — uncommitted work of all three kinds: a modified tracked file, a staged
# new file and an untracked file. kept — all three are still as dirty left them.
# Mutation: `git reset --hard` or `git checkout --force` loses the first two.
dirty() {
  printf 'edit\n' >> tracked.txt
  printf 'staged\n' > staged.txt
  git add staged.txt
  printf 'draft\n' > spec.md
}
kept() {
  [ "$(git status --porcelain)" = $'A  staged.txt\n M tracked.txt\n?? spec.md' ] || { git status --porcelain; return 1; }
  [ "$(cat tracked.txt)" = $'one\nedit' ] || { echo "tracked.txt changed"; return 1; }
  [ "$(cat staged.txt)" = staged ] || { echo "staged.txt changed"; return 1; }
  [ "$(cat spec.md)" = draft ] || { echo "spec.md changed"; return 1; }
}

# no_esc <text> — the text holds no raw ESC byte, read from its bytes.
no_esc() {
  printf '%s' "$1" > "$BATS_TEST_TMPDIR/bytes"
  [ -z "$(od -An -c "$BATS_TEST_TMPDIR/bytes" | grep -F -- 033)" ] || { echo "a raw ESC reached stderr"; return 1; }
}

# failing_hook — a real post-checkout hook, which runs after git has moved HEAD,
# and whose non-zero exit becomes git checkout's. Call it after the test's own
# checkouts: it fails those too.
failing_hook() {
  mkdir -p "$BATS_TEST_TMPDIR/hooks"
  printf '#!/bin/sh\necho "the hook says no" >&2\nexit 7\n' > "$BATS_TEST_TMPDIR/hooks/post-checkout"
  chmod +x "$BATS_TEST_TMPDIR/hooks/post-checkout"
  git config core.hooksPath "$BATS_TEST_TMPDIR/hooks"
}

# checked_out_anyway — a failed checkout that moved HEAD: exit 1, the true line,
# HEAD on the branch, and the next run answers that it is on the branch.
checked_out_anyway() {
  [ "$status" -eq 1 ] || { echo "status $status: $stderr"; return 1; }
  [ -z "$output" ] || { echo "stdout: $output"; return 1; }
  [ "$stderr" = "progress.sh: branch '$F' is checked out, but a later step failed, such as a git hook: the hook says no" ] || { echo "stderr: $stderr"; return 1; }
  [ "$(git symbolic-ref HEAD)" = "refs/heads/$F" ] || { echo "HEAD is elsewhere"; return 1; }
  run --separate-stderr bash "$PROG" branch-cut "$F"
  [ "$status" -eq 0 ] || { echo "second run, status $status: $stderr"; return 1; }
  [ "$output" = "already on branch $F" ] || { echo "second run, stdout: $output"; return 1; }
}

@test "branch-cut cuts an absent branch from the recorded base, and uncommitted work stays" {
  tracked
  local base; base="$(git rev-parse main)"
  dirty
  run --separate-stderr bash "$PROG" branch-cut "$F"
  [ "$status" -eq 0 ] || { echo "status $status: $stderr"; false; }
  [ "$output" = "branch $F cut from main" ] || { echo "stdout: $output"; false; }
  [ "$(git symbolic-ref HEAD)" = "refs/heads/$F" ]
  [ "$(git rev-parse "refs/heads/$F")" = "$base" ]
  kept
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
  tracked
  bash "$PROG" branch-cut "$F" > /dev/null
  git commit -q --allow-empty -m 'work on the branch'
  tip="$(git rev-parse HEAD)"
  git checkout -q main
  dirty
  run --separate-stderr bash "$PROG" branch-cut "$F"
  [ "$status" -eq 0 ] || { echo "status $status: $stderr"; false; }
  [ "$output" = "switched to branch $F" ] || { echo "stdout: $output"; false; }
  [ "$(git symbolic-ref HEAD)" = "refs/heads/$F" ]
  [ "$(git rev-parse HEAD)" = "$tip" ]
  kept
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
  # The line claims only what the check shows.
  [ "$stderr" = "progress.sh: branch '$F' exists, and the base 'main' is not its ancestor. Nothing changed. To use it anyway, run: git checkout $F" ] || { echo "stderr: $stderr"; false; }
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

@test "branch-cut refuses a name outside the allowlist, or a full ref, and no shell reads it" {
  # git takes every one of these as a branch name, and the refusal of a
  # not-an-ancestor branch prints the name in a command to run. Mutation: drop
  # the allowlist, and git cuts the branch.
  local n names
  names=('x$(touch${IFS}pwned)' 'a;b' 'a|b' "a'b" 'a`touch pwned`b' 'refs/heads/main' 'refs/x' $'caf\303\251')
  BEFORE="$(refs)"
  for n in "${names[@]}"; do
    field branch "$n"
    run --separate-stderr bash "$PROG" branch-cut "$F"
    refused 'not a branch name'
    [ ! -e pwned ]
  done
  field branch "$F"
  for n in "${names[@]}"; do
    field baseBranch "$n"
    run --separate-stderr bash "$PROG" branch-cut "$F"
    refused 'not a branch name'
    [ ! -e pwned ]
  done
}

@test "branch-cut prints a refused name masked: no raw byte, and cut to 200 bytes" {
  # Mutation: print the name as it is, and the ESC reaches the terminal.
  local long
  BEFORE="$(refs)"
  field branch $'a\033[31mb'
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused 'not a branch name'
  no_esc "$stderr"
  [ "$stderr" = "progress.sh: 'a?[31mb' in $SF is not a branch name" ] || { echo "stderr: $stderr"; false; }
  # One ? a byte, whatever the locale.
  field branch $'caf\303\251'
  # A system without this locale adds its own warning line, so the end is read.
  LC_ALL=C.UTF-8 run --separate-stderr bash "$PROG" branch-cut "$F"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"progress.sh: 'caf??' in $SF is not a branch name" ]] || { echo "stderr: $stderr"; false; }
  long="$(printf '%0300d' 0)"
  field branch "$long;"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  [ "$stderr" = "progress.sh: '${long:0:200} [cut]' in $SF is not a branch name" ] || { echo "stderr: $stderr"; false; }
  field branch "$F"
  field baseBranch $'a\033[31mb'
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused 'not a branch name'
  no_esc "$stderr"
  [ "$stderr" = "progress.sh: 'a?[31mb' in $SF is not a branch name" ] || { echo "stderr: $stderr"; false; }
}

@test "branch-cut refuses a branch equal to the base, on it or elsewhere" {
  # Mutation: drop the check, and on the base it answers "already on branch".
  field branch main
  BEFORE="$(refs)"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused "'main'"
  [ "$stderr" = "progress.sh: the branch in $SF is the base branch 'main': a run cuts a branch of its own" ] || { echo "stderr: $stderr"; false; }
  git checkout -q -b elsewhere
  BEFORE="$(refs)"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused "'main'"
  [ "$stderr" = "progress.sh: the branch in $SF is the base branch 'main': a run cuts a branch of its own" ] || { echo "stderr: $stderr"; false; }
}

@test "branch-cut checks the names before it answers that it is on the branch" {
  # Mutation: move the on-branch answer above the name checks.
  git checkout -q -b "$F"
  field baseBranch 'a;b'
  BEFORE="$(refs)"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused "'a;b' in $SF is not a branch name"
}

@test "branch-cut refuses a subdirectory, where the state directory is not" {
  # Mutation: drop need_git_top, and the refusal is another one's.
  mkdir -p sub/dir
  cd sub/dir
  BEFORE="$(refs)"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused "run this from the repository's top level"
}

@test "branch-cut reads a branch that is not a string as no branch" {
  # Mutation: read .branch without `strings`, and 42 is a name git takes.
  jq '.branch = 42' "$SF" > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  BEFORE="$(refs)"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused 'records no branch'
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

@test "branch-cut tests the ancestor on the branch, never a tag of the same name" {
  # refs/heads/main is the branch's ancestor; the tag main, which git reads first
  # for a bare name, is not. Mutation: a bare base in merge-base, and it refuses.
  local side
  bash "$PROG" branch-cut "$F" > /dev/null
  git commit -q --allow-empty -m 'work on the branch'
  git checkout -q main
  git checkout -q -b side
  git commit -q --allow-empty -m 'not on the branch'
  side="$(git rev-parse HEAD)"
  git tag main "$side"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  [ "$status" -eq 0 ] || { echo "status $status: $stderr"; false; }
  [ "$output" = "switched to branch $F" ] || { echo "stdout: $output"; false; }
  [ "$(git symbolic-ref HEAD)" = "refs/heads/$F" ]
}

@test "branch-cut says what happened when a hook fails after the cut moved HEAD" {
  # Mutation: drop the second read of HEAD, and it says it could not cut.
  failing_hook
  run --separate-stderr bash "$PROG" branch-cut "$F"
  checked_out_anyway
}

@test "branch-cut says what happened when a hook fails after the switch moved HEAD" {
  # Mutation: drop the second read of HEAD, and it says nothing changed.
  bash "$PROG" branch-cut "$F" > /dev/null
  git checkout -q main
  failing_hook
  run --separate-stderr bash "$PROG" branch-cut "$F"
  checked_out_anyway
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

@test "branch-cut refuses a branch that is the base in another letter case" {
  # A file system that ignores case reads refs/heads/MAIN as main's ref. Mutation:
  # compare the names exactly.
  field branch MAIN
  BEFORE="$(refs)"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  refused "is the base branch 'main'"
}

@test "branch-cut masks what git prints when a checkout fails" {
  # A tracked hook can print a terminal escape. Mutation: print $err raw.
  local hooks="$BATS_TEST_TMPDIR/hooks"
  mkdir -p "$hooks"
  printf '#!/bin/sh\nprintf "\\033]0;PWN\\007" >&2\nexit 1\n' > "$hooks/post-checkout"
  chmod +x "$hooks/post-checkout"
  git config core.hooksPath "$hooks"
  run --separate-stderr bash "$PROG" branch-cut "$F"
  [ "$status" -eq 1 ] || { echo "status $status"; false; }
  [ "$(printf '%s' "$stderr" | LC_ALL=C tr -d '[:print:]\n' | wc -c | tr -d ' ')" = 0 ] || { echo "a raw byte reached stderr"; false; }
  [[ "$stderr" == *'PWN'* ]] || { echo "stderr: $stderr"; false; }
}
