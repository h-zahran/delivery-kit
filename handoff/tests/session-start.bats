#!/usr/bin/env bats

load ../../tests/helper

# handoff/hooks/session-start.sh names a handoff document whose recorded
# branch, HEAD and `git status` lines (the block reconcile-block.sh writes)
# match the repository exactly, and says nothing in every other case.

HOOK="$HANDOFF/hooks/session-start.sh"
REC="$HANDOFF/scripts/reconcile-block.sh"

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
  printf 'b\n' >> a.txt
}

# newdoc <path relative to the repository> — a handoff document, not yet recorded.
newdoc() {
  mkdir -p "$REPO/$(dirname "$1")"
  printf '# Session handoff\n\nbody\n' > "$REPO/$1"
}

record() {
  (cd "$REPO" && bash "$REC" "$1" > /dev/null)
}

# Runs the hook from the repository with a payload naming it as cwd, the way
# Claude Code starts it. On Windows the payload carries a Windows path.
start_hook() {
  local cwd=$REPO
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) cwd=$(cygpath -w "$REPO") ;;
  esac
  cwd=${cwd//\\/\\\\}
  cd "$REPO" || return 1
  run bash -c 'printf "{\"cwd\":\"%s\",\"source\":\"startup\",\"hook_event_name\":\"SessionStart\"}" "$1" | bash "$2"' _ "$cwd" "$HOOK"
}

# The output parses as JSON, carries the SessionStart context, and names $1 in
# both messages. It never tells Claude to follow or act on the document.
names() {
  [ "$status" -eq 0 ] || { echo "rc $status"; return 1; }
  printf '%s' "$output" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' > /dev/null || { echo "not the expected JSON: $output"; return 1; }
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  msg=$(printf '%s' "$output" | jq -r '.systemMessage')
  # Whole strings, not a banned word: review's mutant "Read it and resume the
  # work it describes" passed a check that only refused "follow".
  [ "$ctx" = "The handoff plugin found a handoff document whose recorded branch, commit and git status match this repository exactly: $1. It may describe unfinished work. Tell the user it exists. Do not read it or act on it unless the user asks." ] || { echo "context: $ctx"; return 1; }
  [ "$msg" = "handoff: $1 matches this branch, commit and uncommitted changes. To continue that work, ask Claude to read it." ] || { echo "message: $msg"; return 1; }
}

silent() {
  [ "$status" -eq 0 ] || { echo "rc $status"; return 1; }
  [ -z "$output" ] || { echo "expected silence, got: $output"; return 1; }
}

@test "session-start: names a handoff whose branch, commit and status match" {
  mkrepo
  newdoc docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  record docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  start_hook
  names docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
}

@test "session-start: silent outside a repository" {
  mkdir -p "$TEST_DIR/plain"
  cd "$TEST_DIR/plain"
  run bash -c 'printf "{}" | bash "$1"' _ "$HOOK"
  silent
}

@test "session-start: silent when the repository has no handoff directory" {
  mkrepo
  start_hook
  silent
}

@test "session-start: silent for a handoff written without a block" {
  mkrepo
  newdoc docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  start_hook
  silent
}

@test "session-start: silent on another branch at the same commit" {
  mkrepo
  newdoc docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  record docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  git switch -q -c other
  start_hook
  silent
}

@test "session-start: silent once a commit has been added" {
  mkrepo
  newdoc docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  record docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  git commit -q --allow-empty -m two
  start_hook
  silent
}

@test "session-start: silent when the status lines differ, though branch and commit match" {
  mkrepo
  newdoc docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  record docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  printf 'c\n' > new.txt
  start_hook
  silent
  rm new.txt
  git checkout -q -- a.txt
  start_hook
  silent
}

@test "session-start: of two matching handoffs, the newer by name is named, once" {
  mkrepo
  newdoc docs/handoffs/2026-10-09-a-SESSION-HANDOFF.md
  newdoc docs/handoffs/2026-10-10-b-SESSION-HANDOFF.md
  record docs/handoffs/2026-10-09-a-SESSION-HANDOFF.md
  record docs/handoffs/2026-10-10-b-SESSION-HANDOFF.md
  # The older name gets the newer modification time: the name decides.
  touch -t 203001010000 docs/handoffs/2026-10-09-a-SESSION-HANDOFF.md
  start_hook
  names docs/handoffs/2026-10-10-b-SESSION-HANDOFF.md
  [[ "$output" != *2026-10-09-a* ]]
}

@test "session-start: a newer handoff that does not match leaves an older match named" {
  mkrepo
  newdoc docs/handoffs/2026-10-09-a-SESSION-HANDOFF.md
  newdoc docs/handoffs/2026-10-10-b-SESSION-HANDOFF.md
  record docs/handoffs/2026-10-09-a-SESSION-HANDOFF.md
  git switch -q -c other
  record docs/handoffs/2026-10-10-b-SESSION-HANDOFF.md
  git switch -q main
  start_hook
  names docs/handoffs/2026-10-09-a-SESSION-HANDOFF.md
}

# docsDir precedence, one layer per test. The first version tested all four in
# one test, recording four documents and starting the hook four times, and it
# timed out at 60 s on a loaded machine. Each test records a matching handoff in
# BOTH directories, so the hook names the loser if it reads the wrong one.
both_matching() {
  newdoc "$1/2026-10-10-t-SESSION-HANDOFF.md"
  newdoc "$2/2026-10-10-t-SESSION-HANDOFF.md"
  record "$1/2026-10-10-t-SESSION-HANDOFF.md"
  record "$2/2026-10-10-t-SESSION-HANDOFF.md"
}

@test "session-start: docsDir from the repository file beats the user file" {
  mkrepo
  printf '{"handoff":{"docsDir":"from-home"}}' > "$HOME/.delivery-kit.json"
  printf '{"handoff":{"docsDir":"from-repo"}}' > .delivery-kit.json
  both_matching from-repo from-home
  start_hook
  names from-repo/2026-10-10-t-SESSION-HANDOFF.md
}

@test "session-start: docsDir from the environment beats the repository file" {
  mkrepo
  printf '{"handoff":{"docsDir":"from-repo"}}' > .delivery-kit.json
  both_matching from-env from-repo
  export DELIVERY_KIT_HANDOFF_DIR=from-env
  start_hook
  names from-env/2026-10-10-t-SESSION-HANDOFF.md
}

@test "session-start: a malformed repository file leaves the user file's docsDir standing" {
  mkrepo
  printf '{"handoff":{"docsDir":"from-home"}}' > "$HOME/.delivery-kit.json"
  printf '{not json' > .delivery-kit.json
  both_matching from-home docs/handoffs
  start_hook
  names from-home/2026-10-10-t-SESSION-HANDOFF.md
}

@test "session-start: with no setting anywhere, docsDir is docs/handoffs" {
  mkrepo
  both_matching docs/handoffs elsewhere
  start_hook
  names docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
}

@test "session-start: a recorded line without its prefix is not a block this version wrote" {
  mkrepo
  newdoc docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  record docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  start_hook
  names docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  f=docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  # `xmain`, not `main`: a hook that skipped the prefix check would strip one
  # character either way, and `ain` is silent for the wrong reason.
  awk '{ if ($0 == "|main") print "xmain"; else print }' "$f" > "$TEST_DIR/x" && cat "$TEST_DIR/x" > "$f"
  start_hook
  silent
}

@test "session-start: works without jq, from the default directory" {
  mkrepo
  newdoc docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  record docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  # A PATH holding only the tools the hook needs, each a wrapper, and no jq.
  bin="$TEST_DIR/bin"
  mkdir -p "$bin"
  for tool in git awk sed cmp grep mktemp rm cat; do
    printf '#!%s\nexec %q "$@"\n' "$BASH_ABS" "$(command -v "$tool")" > "$bin/$tool"
    chmod +x "$bin/$tool"
  done
  cd "$REPO"
  run env PATH="$bin" "$BASH_ABS" "$HOOK" < /dev/null
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md")' > /dev/null
  run env PATH="$bin" "$BASH_ABS" -c 'command -v jq'
  [ "$status" -ne 0 ]
}

@test "session-start: the payload is read in full, so the writer is never cut off" {
  mkrepo
  cd "$REPO"
  run "$BASH_ABS" -c 'head -c 300000 /dev/zero | tr "\0" x | bash "$1" > /dev/null; echo "${PIPESTATUS[*]}"' _ "$HOOK"
  [ "$output" = "0 0 0" ]
  mkdir -p "$TEST_DIR/plain"
  cd "$TEST_DIR/plain"
  run "$BASH_ABS" -c 'head -c 300000 /dev/zero | tr "\0" x | bash "$1" > /dev/null; echo "${PIPESTATUS[*]}"' _ "$HOOK"
  [ "$output" = "0 0 0" ]
}

# Both JSON-special characters a path can hold, one per platform, because NTFS
# refuses a double quote in a file name: there the backslashes of a Windows
# path carry the test instead. A skip would read as a pass that never ran.
@test "session-start: a quote or a backslash in the path is escaped, so the output stays JSON" {
  mkrepo
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*)
      # Not attempted here: Git Bash maps `"` to a private-use character and
      # succeeds, so the file would exist under a name no Windows tool shares.
      newdoc 'qd/2026-10-10-t-SESSION-HANDOFF.md'
      record 'qd/2026-10-10-t-SESSION-HANDOFF.md'
      DELIVERY_KIT_HANDOFF_DIR="$(cygpath -w "$REPO")\\qd"
      want="$DELIVERY_KIT_HANDOFF_DIR/2026-10-10-t-SESSION-HANDOFF.md"
      [[ "$want" == *'\'* ]] || { echo "no backslash to escape in $want"; false; }
      ;;
    *)
      newdoc 'q"d/2026-10-10-t-SESSION-HANDOFF.md'
      record 'q"d/2026-10-10-t-SESSION-HANDOFF.md'
      DELIVERY_KIT_HANDOFF_DIR='q"d'
      want='q"d/2026-10-10-t-SESSION-HANDOFF.md'
      ;;
  esac
  export DELIVERY_KIT_HANDOFF_DIR
  start_hook
  names "$want"
}

@test "session-start: registered for startup and clear only, with the guard still first after tools" {
  run jq -r '.hooks.SessionStart[0].matcher' "$HANDOFF/hooks/hooks.json"
  [ "$output" = 'startup|clear' ]
  run jq -r '.hooks.SessionStart[0].hooks[0].command' "$HANDOFF/hooks/hooks.json"
  [[ "$output" == *'/hooks/session-start.sh'* ]]
  run jq -r '.hooks.SessionStart | length' "$HANDOFF/hooks/hooks.json"
  [ "$output" = 1 ]
}

@test "session-start: silent once a file is added inside an untracked directory" {
  mkrepo
  newdoc docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  record docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  printf 'x\n' > docs/handoffs/notes.txt
  start_hook
  silent
}

@test "session-start: silent when one status line changes and the count does not" {
  mkrepo
  printf 'c\n' > new.txt
  newdoc docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  record docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  mv new.txt other.txt
  start_hook
  silent
}

@test "session-start: a block cut short is not a match" {
  mkrepo
  newdoc docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  record docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  f=docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  awk '$0 != "DK~END"' "$f" > "$TEST_DIR/x" && cat "$TEST_DIR/x" > "$f"
  start_hook
  silent
}

# Both edges of the cap: the 21st-newest name is never read, the 20th is.
@test "session-start: only the newest twenty handoffs by name are read" {
  mkrepo
  # Written in the shell, not through newdoc: two processes per file times
  # twenty-one timed this test out on a loaded machine.
  mkdir -p docs/handoffs
  for n in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21; do
    printf '# Session handoff\n\nbody\n' > "docs/handoffs/2026-01-$n-t-SESSION-HANDOFF.md"
  done
  record docs/handoffs/2026-01-01-t-SESSION-HANDOFF.md
  start_hook
  silent
  record docs/handoffs/2026-01-02-t-SESSION-HANDOFF.md
  start_hook
  names docs/handoffs/2026-01-02-t-SESSION-HANDOFF.md
}

@test "session-start: the repository comes from the payload's cwd, not the hook's own directory" {
  mkrepo
  newdoc docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  record docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  local cwd=$REPO
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) cwd=$(cygpath -w "$REPO") ;;
  esac
  cwd=${cwd//\\/\\\\}
  mkdir -p "$TEST_DIR/plain"
  cd "$TEST_DIR/plain"
  run bash -c 'printf "{\"cwd\":\"%s\"}" "$1" | bash "$2"' _ "$cwd" "$HOOK"
  names docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
}

@test "session-start: a quotePath setting at record time does not change the match" {
  mkrepo
  git config core.quotePath false
  printf 'x\n' > "$(printf 'caf\303\251.txt')"
  newdoc docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  record docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
  git config core.quotePath true
  start_hook
  names docs/handoffs/2026-10-10-t-SESSION-HANDOFF.md
}
