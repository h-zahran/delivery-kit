# Shared fixtures for the delivery-kit suites.

# The repository root is found by walking up from the suite's own directory
# until the marketplace manifest appears, rather than by counting ".."
# segments. Two suites live at different depths — tests/ at the root and
# handoff/tests/ one level down — so any fixed count is correct for one and
# silently wrong for the other.
#
# A wrong root is caught downstream in FEWER places than it used to be, and
# that is a consequence of Task 2 worth stating rather than discovering. Most
# readers in portability.bats still shout: the SHIPPED scans grep paths that
# would be absent and exit 2, and the version gate cds into "$ROOT" and finds
# no directory holding a .claude-plugin/plugin.json, so its `checked` guard
# fires and names the root it was handed. The SKILL.md search no longer does.
# It now walks "$ROOT" itself rather than "$ROOT/skills", so ANY ancestor of
# the true root still finds the same SKILL.md files somewhere beneath it and
# the non-empty pin passes without noticing — widening that search to cover a
# second plugin also retired it as a check on this function, which is a guard
# removed, not a guard relocated.
#
# What is left genuinely silent is the optional git-ignored .leakwords, folded
# into BANNED_WORDS only `if [ -f "$ROOT/.leakwords" ]`: a wrong root drops
# every private term and leaves the leak scan green on a narrower list than
# the one whoever wrote that file configured. It is now very nearly the only
# silent path, which is why this function is tested directly in
# tests/layout.bats rather than trusted to be caught by a reader downstream.
find_root() {
  local d parent
  d="$(cd "$1" 2>/dev/null && pwd)" || return 1
  while [ ! -f "$d/.claude-plugin/marketplace.json" ]; do
    # Two steps rather than `cd "$d/.."`: under MSYS/Git Bash that literal
    # path becomes "//.." at the root, and "/" and "//" then alternate
    # forever, so the fixed point the guard below waits for never arrives.
    # Entering the directory first and then `cd ..` gives the POSIX
    # behaviour -- dot-dot at the root is the root -- on every platform.
    parent="$(cd "$d" && cd .. && pwd)"
    # At the filesystem root, `cd ..` is a fixed point. Without this the loop
    # never ends and bats reports a timeout, which looks like a slow test.
    [ "$parent" != "$d" ] || return 1
    d="$parent"
  done
  printf '%s' "$d"
}

ROOT="$(find_root "$BATS_TEST_DIRNAME")" || {
  printf 'no .claude-plugin/marketplace.json above %s\n' "$BATS_TEST_DIRNAME" >&2
  exit 1
}

# The plugin root, one level below the repository root. Named rather than
# spelled out at each use so R2 can add PIPELINE beside it without a sweep.
HANDOFF="$ROOT/handoff"
HOOK="$HANDOFF/hooks/context-guard.sh"

setup() {
  # Every test gets its own TMPDIR and its own HOME. The hook keeps per-session
  # bucket state under TMPDIR and reads configuration from $HOME, so a shared
  # value of either leaks state between tests — and collides with whatever is
  # already on the machine running the suite: a real Claude Code session in the
  # first case, a real user-level configuration in the second.
  #
  # HOME became as load-bearing as TMPDIR the moment the hook started reading
  # ~/.delivery-kit.json. Without this, every test in the suite inherits the
  # developer's own window and threshold, so assertions like "200000-token" pass
  # or fail on the contents of a file the repository does not contain. The
  # failure aims itself squarely at the people this release most needs: the
  # setup skill shipped alongside the hook exists precisely to create that file,
  # so the suite goes red for whoever adopts the feature and stays green in CI,
  # which has no home configuration to read. Tests write into both directories
  # freely; this isolation is what makes that safe.
  TEST_DIR="$(mktemp -d)"
  export TMPDIR="$TEST_DIR/tmp"
  export HOME="$TEST_DIR/home"
  mkdir -p "$TMPDIR" "$HOME"
  unset DELIVERY_KIT_WINDOW_TOKENS DELIVERY_KIT_THRESHOLD_PCT DELIVERY_KIT_HANDOFF_DIR
  unset DELIVERY_KIT_MAX_BYTES
  # The absolute tripwire reads this one, and "unset" is the state the guard's
  # default behaviour depends on — so a developer who has it exported would
  # otherwise run a suite that silently disagrees with CI, starting with the
  # test that asserts the unset case behaves as 1.0.x.
  unset DELIVERY_KIT_THRESHOLD_TOKENS
}

teardown() {
  if [ -n "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
}

# append_entry <file> <input_tokens> [isSidechain]
append_entry() {
  printf '{"isSidechain":%s,"message":{"usage":{"input_tokens":%s,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}\n' \
    "${3:-false}" "$2" >> "$1"
}

# transcript_with <tokens...> -> prints the transcript path
transcript_with() {
  local f="$TEST_DIR/transcript.jsonl" t
  : > "$f"
  for t in "$@"; do append_entry "$f" "$t"; done
  printf '%s' "$f"
}

# hook_input <transcript_path> [session_id] -> prints the stdin payload
hook_input() {
  jq -nc --arg t "$1" --arg s "${2:-test-session}" --arg c "$TEST_DIR" \
    '{transcript_path:$t, session_id:$s, cwd:$c}'
}

# run_hook <transcript_path> [session_id]
run_hook() {
  local payload
  payload="$(hook_input "$@")"
  run bash "$HOOK" <<< "$payload"
}
