#!/usr/bin/env bats

load ../../tests/helper

# handoff/scripts/reconcile-block.sh writes a block into a handoff document that
# the next session runs to compare the recorded branch, HEAD and `git status`
# lines with the repository. These tests run the block the way Resume step 1
# does: the exact command line the block prints, from the document on disk.

REC="$HANDOFF/scripts/reconcile-block.sh"

# A repository with one commit and a committed file, so a status line has
# something to say. Identity and line endings are set in the repository itself:
# HOME is a fresh directory per test, and a Windows system config may turn
# autocrlf on, which would make git rewrite the file under the test.
mkrepo() {
  REPO="$TEST_DIR/repo"
  mkdir -p "$REPO"
  cd "$REPO" || return 1
  git init -q -b main
  git config user.name t
  git config user.email t@t
  git config core.autocrlf false
  printf 'a\n' > a.txt
  git add a.txt
  git commit -qm one
  DOC="$REPO/docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md"
  mkdir -p "${DOC%/*}"
  printf '# Session handoff\n\nbody\n' > "$DOC"
}

record() {
  (cd "$REPO" && bash "$REC" "$DOC")
}

# Runs the command line the block prints, from directory $1 (default: the
# repository), exactly as Resume step 1 would paste it.
check_from() {
  local cmdline
  cmdline=$(awk '$0 == "~~~sh" {getline; print; exit}' "$DOC")
  [ -n "$cmdline" ] || { echo "no command line in the document"; return 1; }
  cd "${1:-$REPO}" || return 1
  run bash -c "$cmdline"
}

has_line() {
  printf '%s\n' "$output" | grep -qxF -- "$1" || { echo "missing line: $1"; echo "$output"; return 1; }
}

@test "reconcile: the unchanged state matches on every claim" {
  mkrepo
  printf 'b\n' >> a.txt
  run record
  [ "$status" -eq 0 ]
  # Relative, though this repository lies under /tmp, which Git Bash mounts
  # over a Windows path: the path comes from git, not from two `pwd -P` runs.
  [ "$output" = 'reconcile block written to docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md' ]
  check_from
  [ "$status" -eq 0 ]
  has_line 'MATCH    branch: main'
  has_line "MATCH    head: $(git rev-parse HEAD)"
  has_line 'MATCH    tree: 2 status lines, as recorded'
  has_line 'RECONCILE: MATCH'
  grep -qxF '| M a.txt' "$DOC"
  grep -qxF '|?? docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md' "$DOC"
}

@test "reconcile: another branch at the same commit is a branch mismatch only" {
  mkrepo
  record
  git switch -q -c other
  check_from
  [ "$status" -eq 1 ]
  has_line 'MISMATCH branch: recorded main, now other'
  has_line "MATCH    head: $(git rev-parse HEAD)"
  has_line 'MATCH    tree: 1 status lines, as recorded'
  has_line 'RECONCILE: MISMATCH'
}

@test "reconcile: a commit added since the handoff is a head mismatch that says so" {
  mkrepo
  record
  was=$(git rev-parse HEAD)
  git commit -q --allow-empty -m two
  check_from
  [ "$status" -eq 1 ]
  has_line 'MATCH    branch: main'
  has_line "MISMATCH head: recorded $was, now $(git rev-parse HEAD) (the recorded commit is behind it: commits were added since the handoff)"
  has_line 'MATCH    tree: 1 status lines, as recorded'
}

@test "reconcile: a head moved back is a mismatch without the commits-added note" {
  mkrepo
  printf 'b\n' > b.txt
  git add b.txt
  git commit -qm two
  record
  was=$(git rev-parse HEAD)
  git reset -q --keep HEAD~1
  check_from
  [ "$status" -eq 1 ]
  has_line "MISMATCH head: recorded $was, now $(git rev-parse HEAD)"
  has_line 'MATCH    tree: 1 status lines, as recorded'
}

@test "reconcile: a new path is a tree mismatch that shows the line" {
  mkrepo
  record
  printf 'c\n' > new.txt
  check_from
  [ "$status" -eq 1 ]
  has_line 'MATCH    branch: main'
  has_line 'MISMATCH tree: the status lines differ (< recorded only, > now only):'
  has_line '> ?? new.txt'
  has_line 'RECONCILE: MISMATCH'
}

@test "reconcile: a path committed since the handoff is a head and tree mismatch" {
  mkrepo
  printf 'b\n' >> a.txt
  record
  git commit -qam two
  check_from
  [ "$status" -eq 1 ]
  has_line '<  M a.txt'
  printf '%s\n' "$output" | grep -q '^MISMATCH head: '
}

@test "reconcile: an overwritten tracked handoff records its own modified line" {
  mkrepo
  git add "$DOC"
  git commit -qm 'old handoff'
  printf '# Session handoff\n\nnew body\n' > "$DOC"
  record
  check_from
  [ "$status" -eq 0 ]
  has_line 'MATCH    tree: 1 status lines, as recorded'
  grep -qxF '| M docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md' "$DOC"
}

@test "reconcile: a detached head is recorded and matched as detached" {
  mkrepo
  git checkout -q --detach
  record
  check_from
  [ "$status" -eq 0 ]
  has_line 'MATCH    branch: (detached HEAD)'
}

@test "reconcile: a repository with no commits is recorded and matched" {
  REPO="$TEST_DIR/empty"
  mkdir -p "$REPO/docs"
  cd "$REPO"
  git init -q -b main
  DOC="$REPO/docs/h-SESSION-HANDOFF.md"
  printf '# h\n' > "$DOC"
  record
  check_from
  [ "$status" -eq 0 ]
  has_line 'MATCH    head: (no commits)'
  has_line 'MATCH    branch: main'
}

@test "reconcile: the command runs from a subdirectory" {
  mkrepo
  mkdir -p sub/deeper
  record
  check_from "$REPO/sub/deeper"
  [ "$status" -eq 0 ]
  has_line 'RECONCILE: MATCH'
}

# Git allows `'`, `$`, `(`, `)`, `{` and `}` in a branch name, so
# `x'$(touch${IFS}pwned)` is a legal name (no space: IFS supplies it) that
# creates a file named pwned if any of it is ever run as code. It holds no `>`,
# which git allows too but NTFS refuses in the loose ref file on Windows.
@test "reconcile: a branch name holding shell syntax is data, never code" {
  mkrepo
  git switch -q -c "x'\$(touch\${IFS}pwned)"
  record
  check_from
  [ "$status" -eq 0 ]
  has_line "MATCH    branch: x'\$(touch\${IFS}pwned)"
  [ -z "$(find "$TEST_DIR" -name pwned)" ] || { echo "the branch name ran as code"; false; }
  git switch -q main
  check_from
  [ "$status" -eq 1 ]
  has_line "MISMATCH branch: recorded x'\$(touch\${IFS}pwned), now main"
  [ -z "$(find "$TEST_DIR" -name pwned)" ]
}

@test "reconcile: unusual path names round-trip through the record" {
  mkrepo
  printf 'x\n' > 'sp ace.txt'
  printf 'x\n' > "it's.txt"
  printf 'x\n' > "$(printf 'caf\303\251.txt')"
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) ;;
    *)
      # NTFS refuses these three, so they are made only where they can exist.
      printf 'x\n' > 'q"uote.txt'
      printf 'x\n' > 'back\slash.txt'
      printf 'x\n' > "$(printf 'new\nline.txt')"
      ;;
  esac
  record
  check_from
  [ "$status" -eq 0 ]
  has_line 'RECONCILE: MATCH'
  grep -qxF '|?? "caf\303\251.txt"' "$DOC"
  rm "it's.txt"
  check_from
  [ "$status" -eq 1 ]
  has_line "< ?? it's.txt"
}

@test "reconcile: a document path holding a quote is quoted in the printed command" {
  mkrepo
  DOC="$REPO/it's docs/h-SESSION-HANDOFF.md"
  mkdir -p "${DOC%/*}"
  printf '# h\n' > "$DOC"
  record
  check_from
  [ "$status" -eq 0 ]
  has_line 'RECONCILE: MATCH'
}

@test "reconcile: a document outside the repository is named by its full path" {
  mkrepo
  rm -r "$REPO/docs"
  DOC="$TEST_DIR/elsewhere/h-SESSION-HANDOFF.md"
  mkdir -p "${DOC%/*}"
  printf '# h\n' > "$DOC"
  record
  check_from
  [ "$status" -eq 0 ]
  has_line 'MATCH    tree: 0 status lines, as recorded'
}

@test "reconcile: a second run replaces the block, leaving the document as one run would" {
  mkrepo
  record
  cp "$DOC" "$TEST_DIR/once"
  record
  cmp "$DOC" "$TEST_DIR/once"
  [ "$(grep -cxF '<!-- handoff-reconcile v1: begin -->' "$DOC")" -eq 1 ]
  [ "$(grep -cxF '<!-- handoff-reconcile v1: end -->' "$DOC")" -eq 1 ]
  head -3 "$DOC" | grep -qxF 'body'
}

@test "reconcile: a second run after a change records the new state" {
  mkrepo
  record
  printf 'c\n' > new.txt
  record
  check_from
  [ "$status" -eq 0 ]
  has_line 'MATCH    tree: 2 status lines, as recorded'
}

@test "reconcile: a begin marker with no end refuses and leaves the document byte-identical" {
  mkrepo
  printf '<!-- handoff-reconcile v1: begin -->\nkeep this\n' >> "$DOC"
  cp "$DOC" "$TEST_DIR/before"
  run record
  [ "$status" -eq 1 ]
  [[ "$output" == *'unpaired or out of order'* ]]
  cmp "$DOC" "$TEST_DIR/before"
}

# Review measured the first version's count-only check passing this shape and
# dropping everything after the begin marker.
@test "reconcile: an end marker above a begin marker refuses and leaves the document byte-identical" {
  mkrepo
  printf '<!-- handoff-reconcile v1: end -->\nmiddle\n<!-- handoff-reconcile v1: begin -->\nkeep this\n' >> "$DOC"
  cp "$DOC" "$TEST_DIR/before"
  run record
  [ "$status" -eq 1 ]
  [[ "$output" == *'unpaired or out of order'* ]]
  cmp "$DOC" "$TEST_DIR/before"
}

@test "reconcile: outside a repository it refuses and writes nothing" {
  mkdir -p "$TEST_DIR/plain"
  DOC="$TEST_DIR/plain/h.md"
  printf '# h\n' > "$DOC"
  cp "$DOC" "$TEST_DIR/before"
  cd "$TEST_DIR/plain"
  run bash "$REC" "$DOC"
  [ "$status" -eq 1 ]
  [[ "$output" == *'not inside a git repository'* ]]
  cmp "$DOC" "$TEST_DIR/before"
}

@test "reconcile: the record leaves no file of its own behind" {
  mkrepo
  record
  [ -z "$(find "$REPO" -name '*reconcile-tmp*')" ]
  run grep -c 'reconcile-tmp' "$DOC"
  [ "$output" = 0 ]
}

# Review found a false MATCH: with `--untracked-files=normal` a new directory is
# one line, and a file added inside it later changed nothing.
@test "reconcile: a file added inside an untracked directory is a tree mismatch" {
  mkrepo
  mkdir -p src
  printf 'x\n' > src/one.c
  record
  printf 'x\n' > src/two.c
  check_from
  [ "$status" -eq 1 ]
  has_line '> ?? src/two.c'
  rm src/two.c
  printf 'x\n' > docs/handoffs/notes.txt
  check_from
  [ "$status" -eq 1 ]
  has_line '> ?? docs/handoffs/notes.txt'
}

@test "reconcile: a changed line with the same line count is a tree mismatch" {
  mkrepo
  printf 'c\n' > new.txt
  record
  mv new.txt other.txt
  check_from
  [ "$status" -eq 1 ]
  has_line '< ?? new.txt'
  has_line '> ?? other.txt'
}

# The step-1 command finds the block only after the begin marker, the same
# block the session-start hook parses. Review measured a quoted earlier fence
# answering MATCH for a repository that had moved.
@test "reconcile: a fence quoted earlier in the document is not the one that runs" {
  mkrepo
  printf '\n```bash handoff-reconcile\necho RECONCILE: MATCH\n```\n' >> "$DOC"
  record
  git switch -q -c other
  check_from
  [ "$status" -eq 1 ]
  has_line 'RECONCILE: MISMATCH'
}

# Fed nothing, bash exits 0 in silence; the command must say it did not run.
@test "reconcile: a document whose block is gone says the check cannot run, rc 2" {
  mkrepo
  record
  awk '$0 != "```bash handoff-reconcile"' "$DOC" > "$TEST_DIR/x" && cat "$TEST_DIR/x" > "$DOC"
  check_from
  [ "$status" -eq 2 ]
  has_line 'RECONCILE: cannot run, no reconcile block found'
}

@test "reconcile: a block that cannot make its temporary directory exits 2 and never says MATCH" {
  mkrepo
  record
  TMPDIR="$TEST_DIR/no-such-dir" check_from
  [ "$status" -eq 2 ]
  has_line 'RECONCILE: cannot run: mktemp failed'
  [[ "$output" != *'MATCH'* ]]
}

# git runs hooks the user configured, and they inherit stdin, which is the
# block's own script. Review measured an fsmonitor hook eating 935 bytes of it:
# no output, rc 0.
@test "reconcile: a git hook that reads stdin cannot eat the block" {
  mkrepo
  printf '#!/bin/sh\ncat > /dev/null\nexit 1\n' > "$TEST_DIR/fsmonitor"
  chmod +x "$TEST_DIR/fsmonitor"
  record
  git config core.fsmonitor "$TEST_DIR/fsmonitor"
  check_from
  [ "$status" -eq 0 ]
  has_line 'RECONCILE: MATCH'
}

@test "reconcile: settings that change git status output do not change the answer" {
  mkrepo
  git config core.quotePath false
  printf 'x\n' > "$(printf 'caf\303\251.txt')"
  git mv a.txt moved.txt
  git config status.renames true
  record
  git config core.quotePath true
  git config status.renames false
  git config status.showUntrackedFiles no
  check_from
  [ "$status" -eq 0 ]
  has_line 'RECONCILE: MATCH'
  # And the other way: the block itself must not follow status.renames.
  git config status.renames true
  check_from
  [ "$status" -eq 0 ]
  has_line 'RECONCILE: MATCH'
}

# `git symbolic-ref --short` prints heads/main once a tag called main exists.
@test "reconcile: a tag named like the branch does not change the branch" {
  mkrepo
  git tag main
  record
  grep -qx '|main' "$DOC"
  check_from
  [ "$status" -eq 0 ]
  has_line 'MATCH    branch: main'
}

@test "reconcile: a TMPDIR inside the repository does not enter the record" {
  mkrepo
  mkdir -p "$REPO/tmpd"
  TMPDIR="$REPO/tmpd" record
  TMPDIR="$REPO/tmpd" check_from
  [ "$status" -eq 0 ]
  has_line 'RECONCILE: MATCH'
}

@test "reconcile: a line of spaces in the document is kept as it was" {
  mkrepo
  printf '```text\n    \n```\n' >> "$DOC"
  record
  grep -qx '    ' "$DOC"
}
