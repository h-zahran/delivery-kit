# shellcheck shell=bash
# Stated, not inferred. This file has no shebang — it is `load`ed by bats, not
# executed — so an analyser otherwise guesses the dialect from the .bash
# extension. Rename or move the file and that guess is gone: without a
# directive the analyser reports "target shell is unknown", and if it ever
# resolved to sh instead, every `local` and every array below becomes an error.
# The shell-analysis job reads this file, so the dependency is named here
# rather than left resting on a filename.
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
#
# Assigned here and read by nothing in this file, so static analysis reports it
# as unused. It is not: bats reads it out of the environment of the file it
# loads, and an analyser cannot see a reader that lives outside the file. The
# suppression carries that reason rather than standing bare, because a bare
# suppression silences a real defect and reads like a fix.
#
# NOT exported to satisfy the analyser. Exporting would silence the report
# honestly and would also change what every child process inherits — a
# behaviour change to test plumbing, made for a cosmetic reason. The value
# stays a plain assignment.
# shellcheck disable=SC2034 # read by bats from this file's environment, not here
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

# hook_input [--no-cwd] [--cwd <dir>] [--no-session] <transcript_path> [session_id]
#   -> prints the stdin payload
#
# The payload SHAPE is written down once, here. The three flags exist because
# the coverage tests need payloads this function could not previously express
# — one with no working directory, one with a working directory that is not
# $TEST_DIR, and one with no session identifier — and each of them was
# hand-rolled as its own inline jq call instead. Five literal payload
# constructions is the same duplication write_config was added to remove, one
# field over: when Claude Code renames or adds a field, this function is
# updated and hand-rolled copies silently keep sending the old shape while
# their tests still pass.
#
# Keys are DELETED after the object is built rather than assembled
# conditionally, so there is exactly one place the shape is spelled out.
hook_input() {
  local cwd="$TEST_DIR" drop_cwd=0 drop_session=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --no-cwd)     drop_cwd=1; shift ;;
      --cwd)        cwd="$2"; shift 2 ;;
      --no-session) drop_session=1; shift ;;
      *)            break ;;
    esac
  done
  jq -nc --arg t "$1" --arg s "${2:-test-session}" --arg c "$cwd" \
     --argjson dc "$drop_cwd" --argjson ds "$drop_session" \
    '{transcript_path:$t, session_id:$s, cwd:$c}
     | if $dc == 1 then del(.cwd) else . end
     | if $ds == 1 then del(.session_id) else . end'
}

# run_hook [hook_input flags] <transcript_path> [session_id]
run_hook() {
  local payload
  payload="$(hook_input "$@")"
  run bash "$HOOK" <<< "$payload"
}

# run_hook_from <dir> [hook_input flags] <transcript_path> [session_id]
#
# Runs the guard with <dir> as the PROCESS working directory, which is what
# the cwd fallback reads when the payload carries no working directory of its
# own. Almost always used with --no-cwd.
#
# THE CHILD MOVES, NOT THE HARNESS, and that is the whole reason this is a
# function. A plain `cd` in a test leaves bats standing inside a directory
# teardown is about to delete — which on this platform fails rather than
# succeeding quietly, and fails in teardown, where the message points at the
# wrong thing. The rule was written in a comment at one call site and copied
# to a second without it; a third copy would have carried neither.
#
# `exec` so the guard is the same process the cd applied to, and positional
# arguments rather than an interpolated script, so a path can never be read
# as shell.
run_hook_from() {
  local dir="$1" payload
  shift
  payload="$(hook_input "$@")"
  run bash -c 'cd "$1" || exit 99; exec bash "$2"' _ "$dir" "$HOOK" <<< "$payload"
}

# write_config <path> <body> — writes {"contextGuard":<body>} to <path>.
#
# BOTH parameters are required, and both by measurement rather than taste.
#
# The PATH, because the call sites do not all write the same file: most write
# the repository configuration, and a handful write the USER one under $HOME.
# That handful is what proves the precedence order between the two, so a helper
# that hardcoded the repository path could not express them at all — it would
# have to leave them unconverted, or silently write the wrong file and break the
# very test that checks precedence.
#
# NO COUNT IS WRITTEN HERE, and that is a correction rather than vagueness. This
# comment used to say twenty-three repository sites. It was wrong when written —
# running the conversion found a third unconvertible site nobody had named, so
# the number was twenty-two — and it went stale again the moment tests were
# added, which is the whole hazard: a hand-written count drifts in the direction
# that flatters. The counts as MEASURED at the conversion are recorded, dated,
# in this feature's research and contract documents, where they describe an
# event that does not change. What the argument above actually rests on is the
# SHAPE — that two different files are written — and the shape does not drift.
#
# The BODY, because the bodies are not interchangeable. What repeats is the
# wrapper, not the setting. Several bodies are deliberately
# INVALID — a leading-zero number, a zero window, an out-of-range threshold —
# because they exercise the validator, so the body is written verbatim. A helper
# that normalised or rebuilt it would quietly repair exactly the inputs those
# tests exist to reject.
#
# A site that builds its body by substitution interpolates before calling; the
# helper needs no special case for it. Output is byte-identical to the literal
# printf it replaces — checked with cmp, not by eye.
# The guards below are not defensive padding, and each closes a misuse whose
# failure is SILENT — the file is written, the guard reads it, finds nothing it
# recognises, and runs on defaults. The calling test then passes while naming a
# setting it never applied, which is the one outcome a fixture helper must not
# make easier than the literal it replaced. Review found all three; none was
# hypothetical.
#
#   one argument   -> printf with no operand writes {"contextGuard":}, which is
#                     not valid JSON, so every jq read returns empty.
#   swapped        -> a file named for the BODY is created in whatever directory
#                     bats runs from, which is the repository root.
#   double-wrapped -> the natural copy-paste from the literals this replaced;
#                     it nests to .contextGuard.contextGuard and reads as absent.
#
# Measured before adding: no existing call site trips any of the three.
write_config() {
  [ "$#" -eq 2 ] || { printf 'write_config needs <path> <body>, got %s\n' "$#" >&2; return 1; }
  # A FOURTH MISUSE, found only after the first three were closed: an EMPTY
  # body passes all of them — it is two arguments, it does not start with a
  # brace, and it carries no guard key. It writes {"contextGuard":}, which
  # does not parse, so every jq read in the hook returns empty under its
  # 2>/dev/null and the guard runs on its defaults. That is the exact
  # false-green the other three exist to stop, reached by the one route they
  # left open. A body arrives empty whenever an earlier substitution
  # produced nothing, which is a normal way for a fixture to break.
  [ -n "$2" ] || { printf 'write_config: the body is empty; that writes invalid JSON the guard ignores\n' >&2; return 1; }
  case "$1" in
    '{'*) printf 'write_config: the path looks like a body — arguments swapped?\n' >&2; return 1 ;;
  esac
  case "$2" in
    *'"contextGuard"'*) printf 'write_config: pass the INNER object; the wrapper is added here\n' >&2; return 1 ;;
  esac
  printf '{"contextGuard":%s}\n' "$2" > "$1"
}

# bytes_of <file> <lines> — the byte count of the last <lines> lines of <file>.
#
# This exists for naming, and because the trailing-whitespace strip is
# load-bearing on this platform and is the kind of thing that gets dropped when
# an incantation is copied by hand. One definition cannot be copied wrongly.
#
# IT MUST ALSO BE ABLE TO FAIL, and the first version could not. `tail` on a
# missing file writes to stderr and the PIPELINE still exits 0, with `wc -c`
# printing 0 — so a renamed fixture or a typo'd variable yielded a byte cap of
# zero, the guard's validator rejected zero and kept its 8MB default, and the
# uncapped read ran. All three tests that exist to prove the cap cannot starve
# the median went on passing, asserting a percentage the uncapped path produces
# identically. Demonstrated, not supposed: with this function pointed at a
# nonexistent file the three of them stayed green.
#
# Note what that means for the argument above. Centralising an idiom is only
# worth something if the centre can say no; a single definition that fails
# silently propagates one silent failure to every caller instead of four.
bytes_of() {
  [ "$#" -eq 2 ] || { printf 'bytes_of needs <file> <lines>, got %s\n' "$#" >&2; return 1; }
  [ -f "$1" ] || { printf 'bytes_of: no such file: %s\n' "$1" >&2; return 1; }
  local n
  n="$(tail -n "$2" "$1" | wc -c | tr -d ' ')"
  # An `if`, not `A && B || C`. This line predates the shell-analysis job and
  # is unchanged in meaning; the job reports the chained form, so it is fixed
  # here rather than suppressed. A suppression would be silencing a real
  # report on code nobody had looked at, which is the opposite of the point.
  if [ -z "$n" ] || ! [ "$n" -gt 0 ] 2>/dev/null; then
    printf 'bytes_of: %s yielded no bytes\n' "$1" >&2
    return 1
  fi
  printf '%s' "$n"
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
