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
  check_from
  [ "$status" -eq 0 ]
  has_line 'MATCH    branch: main'
  has_line "MATCH    head: $(git rev-parse HEAD)"
  has_line 'MATCH    tree: 2 status lines, as recorded'
  has_line 'RECONCILE: MATCH'
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
  has_line 'MATCH    branch: (detached)'
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
  rm "it's.txt"
  check_from
  [ "$status" -eq 1 ]
  has_line "< ?? \"it's.txt\"" || has_line "< ?? it's.txt"
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
  [[ "$output" == *'1 begin and 0 end markers'* ]]
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
