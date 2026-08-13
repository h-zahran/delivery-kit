# Shared fixtures for the delivery-kit suites.

HOOK="${BATS_TEST_DIRNAME}/../hooks/context-guard.sh"
REPO="${BATS_TEST_DIRNAME}/.."

setup() {
  # Every test gets its own TMPDIR. The hook keeps per-session bucket state
  # there, and a shared TMPDIR would leak state between tests — and collide
  # with any real Claude Code session running on the same machine.
  TEST_DIR="$(mktemp -d)"
  export TMPDIR="$TEST_DIR/tmp"
  mkdir -p "$TMPDIR"
  unset DELIVERY_KIT_WINDOW_TOKENS DELIVERY_KIT_THRESHOLD_PCT DELIVERY_KIT_HANDOFF_DIR
  unset DELIVERY_KIT_MAX_BYTES
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
