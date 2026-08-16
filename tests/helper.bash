# Shared fixtures for the delivery-kit suites.

HOOK="${BATS_TEST_DIRNAME}/../hooks/context-guard.sh"
REPO="${BATS_TEST_DIRNAME}/.."

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
