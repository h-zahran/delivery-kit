# Shared fixtures for the delivery-kit suites.

# Every suite loads this file, so a setting that must reach them all belongs
# here — no number is written down, because the suites are enumerated from the
# tree and a hand-counted one goes stale in the direction that hurts. Cheap insurance: a regression that hangs a test — an unbounded walk, a
# read that never returns, a lock never released — gets a NAMED timeout here
# instead of running toward GitHub's 360-minute job cap, which kills the job
# and names nothing.
#
# 60, not 10. Measured 2026-08-27 across five full runs on this machine: the
# slowest single test ranged from about 8.0 s to about 14.9 s. That is not a
# tidy number and it should not be written as one — the spread is real, it lives
# almost entirely in the process-spawn-heavy handoff guard suite, and even a
# ~1.1 s control test varied threefold between runs. 60 is roughly four times
# the WORST reading, and still hundreds of times faster than the job cap it
# replaces.
#
# The first draft of this comment recorded a single reading, 7916 ms, and
# derived a 7.58x margin from it. Review re-measured and got 14.3 s. Both
# readings are real; one number was the mistake. Note what that correction does
# to the case for this change: at the slower readings the value being REMOVED
# here would have killed honest tests outright — three in one measured run, six
# in another — not merely run close to them. The old
# value of 10 lived in tests/layout.bats and was only ever applied there — that
# suite's slowest test is 1149 ms, so 10 gave IT 8.7x margin. Applied to all
# six it would sit 2.7 s above the handoff guard suite's slowest test, on the
# slowest machine measured — which is a developer machine, not a CI runner
# (224.6 s locally against 155 s on the slowest hosted runner). A timeout that
# flakes teaches people to ignore timeouts.
#
# This is the ONLY assignment in the tree, and it has to be: an assignment
# written ABOVE a suite's `load` line loses to this one, silently, while one
# written below it wins. Measured with throwaway suites, not assumed.
# tests/layout.bats used to carry one above its load line; it was removed
# rather than left reading like an owner it was not.
#
# What it actually needs is `ps` OR `pkill`, not an external `timeout` program.
# bats implements the limit itself with a background sleep and a signal, and it
# refuses out loud — `Cannot execute timeout because neither pkill nor ps are
# available`, exit 1 — when it can find neither. Read out of bats-exec-test and
# then measured: a `timeout` shim placed first on PATH was never called and the
# limit still fired. An earlier draft of this comment named the wrong
# dependency and called the failure silent. Both halves were wrong, and a guard
# whose comment misdescribes its own prerequisite sends the next maintainer to
# the wrong place.
BATS_TEST_TIMEOUT=60

# The repository root is the root of the git checkout containing the suite,
# and it must hold the marketplace manifest. The old implementation walked
# parent directories until a manifest appeared, and that walk had no boundary
# within THIS checkout: worktrees live inside the main working tree at
# .claude/worktrees/<name>/, so from a tree that lacked the manifest the walk
# escaped into the parent checkout and every suite examined another
# repository's files while reporting on this one's branch. `git rev-parse
# --show-toplevel` is bounded to the checkout containing $1 by construction —
# for a worktree it names the worktree's own root, never the main checkout's.
#
# The manifest check stays, because a right boundary can still be a wrong
# tree: a checkout of a ref that predates the manifest is not one these
# suites can describe, and refusing beats measuring whatever is there. A
# wrong root is nearly silent downstream — the SHIPPED scans and the version
# gate shout, but the optional git-ignored .leakwords is folded into
# BANNED_WORDS only when present at $ROOT, so a wrong root narrows the leak
# vocabulary without a single test going red. That is why this function is
# tested directly in tests/layout.bats rather than trusted.
#
# The rev-parse output is normalised through cd/pwd: under Git Bash it prints
# the mixed form (D:/...), and every consumer of ROOT was written against the
# POSIX form pwd prints (/d/...). Measured on this machine rather than
# assumed; see the layout suite.
find_root() {
  local top
  top="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" || return 1
  top="$(cd "$top" 2>/dev/null && pwd)" || return 1
  [ -f "$top/.claude-plugin/marketplace.json" ] || return 1
  printf '%s' "$top"
}

ROOT="$(find_root "$BATS_TEST_DIRNAME")" || {
  printf 'the checkout containing %s has no .claude-plugin/marketplace.json at its root\n' "$BATS_TEST_DIRNAME" >&2
  exit 1
}

# The plugin root, one level below the repository root. Named for the suites
# that drive the hook; portability.bats spells its paths out on purpose — its
# lists are registrations, and a variable there would hide what is registered.
# R2 adds PIPELINE beside this for its own suites; the registration lists
# still grow by hand.
HANDOFF="$ROOT/handoff"
HOOK="$HANDOFF/hooks/context-guard.sh"
PIPELINE="$ROOT/pipeline"
PROBE="$PIPELINE/scripts/preflight.sh"

# The absolute path of bash, resolved HERE and not inside a test. The probe
# suite reaches several of its behaviours by handing the probe a search path
# that holds almost nothing — and stripping PATH also removes bash, so a test
# that tried to resolve the interpreter after narrowing its own path could not
# start the probe at all. Resolving at load time is what makes that shape
# possible; it is not a style choice.
BASH_ABS="$(command -v bash)"

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

# probe [--path <dir>] [probe arguments...]
#
# Runs the pre-flight probe once, leaving the exit status in $status, the data
# stream in $output and the diagnostic stream in $stderr — for the CALLING TEST.
# bats does not declare those three local, which is what makes a `run` inside a
# function visible to its caller. Measured, not assumed.
#
# It is a pass-through and supplies no probe flag of its own. That is
# deliberate: one call site must be able to omit --base-branch entirely to reach
# the current-branch fallback, and a helper that supplied it could not express
# that call. It also keeps the fixture visible where the test names it.
#
# --path <dir> gives the probe a search path of exactly <dir>. There is no
# collision: the probe's legal flags are --dir, --project-type and
# --base-branch, and it refuses anything else by name. Two things about this
# shape are load-bearing and were both measured:
#
#   * The environment is changed for the CHILD, via env. A subshell would work
#     for the probe and be useless here — `run` inside a subshell sets its
#     variables in the subshell, and the calling test sees nothing at all.
#   * A bare `PATH=x cmd` prefix is a different trap and does NOT apply: that
#     one is about a builtin's lookup in the CURRENT shell. The probe is a
#     separate process, so its own `command -v` honours the environment it was
#     born with.
#
# The directory handed to --path must be a path with no drive letter. Under Git
# Bash a `C:/...` entry splits on its own colon into two broken entries and then
# EVERY tool reads as absent — including jq, so the probe dies for a reason the
# test did not name and passes for the wrong cause. $BATS_TEST_TMPDIR is
# already in the right form.
probe() {
  local searchpath="$PATH"
  if [ "${1:-}" = "--path" ] && [ "$#" -ge 2 ]; then searchpath="$2"; shift 2; fi
  run --separate-stderr env PATH="$searchpath" "$BASH_ABS" "$PROBE" "$@"
}
