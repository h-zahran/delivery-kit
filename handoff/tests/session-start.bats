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
  [[ "$ctx" == *": $1. "* ]] || { echo "context does not name $1: $ctx"; return 1; }
  [[ "$msg" == "handoff: $1 matches"* ]] || { echo "message does not name $1: $msg"; return 1; }
  [[ "$ctx" == *'Do not read it or act on it unless the user asks.'* ]]
  case "$ctx" in *[Ff]ollow*) echo "the context directs: $ctx"; return 1 ;; esac
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

@test "session-start: docsDir comes from the environment, then the repository file, then the user file" {
  mkrepo
  printf '{"handoff":{"docsDir":"from-home"}}' > "$HOME/.delivery-kit.json"
  printf '{"handoff":{"docsDir":"from-repo"}}' > .delivery-kit.json
  for d in docs/handoffs from-home from-repo from-env; do
    newdoc "$d/2026-10-10-t-SESSION-HANDOFF.md"
  done
  for d in docs/handoffs from-home from-repo from-env; do
    record "$d/2026-10-10-t-SESSION-HANDOFF.md"
  done
  start_hook
  names from-repo/2026-10-10-t-SESSION-HANDOFF.md
  export DELIVERY_KIT_HANDOFF_DIR=from-env
  start_hook
  names from-env/2026-10-10-t-SESSION-HANDOFF.md
  unset DELIVERY_KIT_HANDOFF_DIR
  printf '{not json' > .delivery-kit.json
  start_hook
  names from-home/2026-10-10-t-SESSION-HANDOFF.md
  rm "$HOME/.delivery-kit.json"
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
  awk '{ if ($0 == "|main") print "main"; else print }' "$f" > "$TEST_DIR/x" && cat "$TEST_DIR/x" > "$f"
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
