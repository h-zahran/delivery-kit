#!/usr/bin/env bash
# progress.sh — state and lock mechanics for the pipeline plugin.
#
# Contract, shared with preflight.sh and inherited from the spec tool's own
# scripts: PURE JSON (or a bare path, or nothing) on stdout, every
# diagnostic on stderr. A warning printed into a JSON stream is a parse
# failure that reads like a missing feature. One exception, by design:
# piece-next prints two plain lines, a heading and its task ids.
#
# Everything this file writes lives under .delivery-kit/. The state
# directory is the user's to ignore; the skill (never this script) offers
# the one gitignore line.
#
# jq here may be a native Windows binary with text-mode stdout: command
# substitution strips the trailing CR it emits, `read` does not (measured
# repeatedly in this repository's suite) — so this script reads jq only
# through command substitution and jq's exit codes, never `while read`.
set -euo pipefail

STATE_ROOT=".delivery-kit"

warn() { printf 'progress.sh: %s\n' "$*" >&2; }
die()  { printf 'progress.sh: %s\n' "$*" >&2; exit 1; }
usage() { die "usage: progress.sh <init|read|validate|phase-start|phase-done|from-validate|lock-take|lock-release|commit-add|piece-next> <feature> [args]"; }

command -v jq >/dev/null 2>&1 || die "jq is required and was not found on PATH"

# Feature names come from the spec tool (NNN-slug). Anything else could
# escape the runs directory, so the shape is enforced, loudly, everywhere.
feature_ok() { case "$1" in ''|*[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac; }
need_feature() { feature_ok "$1" || die "feature name '$1' — letters, digits, dot, dash, underscore only"; }

state_file() { printf '%s/runs/%s/progress.json' "$STATE_ROOT" "$1"; }
lock_file()  { printf '%s/lock' "$STATE_ROOT"; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# The full phase alphabet. DONE is the terminal marker, not a phase a run
# works in — but phase-start accepts it so a finishing run can record it.
PHASES=" preflight A B C C.5 D E F F.5 G H H.5 H.7 I J K L M N N.5 O DONE "
# KNOWN HOLE, recorded rather than fixed here: this substring match accepts a
# run of adjacent names — "A B" and "C C.5" were measured to pass. The fix is
# the word-by-word loop kind_known uses below; it changes what phase-start and
# validate accept, so it belongs to its own change.
phase_known() { case "$PHASES" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# What a recorded commit holds. One list, read by the check and by its message.
KINDS=" spec piece converge simplify review tests constitution other "
# Word by word, never a substring match: the substring idiom above accepts
# "spec piece", because that string with its surrounding spaces IS a
# substring of the list — measured. An exact comparison against each word
# refuses it, and anything else that is not one whole name.
kind_known() {
  local k
  for k in $KINDS; do [ "$k" = "$1" ] && return 0; done
  return 1
}

cmd_validate() {
  need_feature "$1"
  sf="$(state_file "$1")"
  [ -f "$sf" ] || die "no state file at $sf"
  jq -e . "$sf" >/dev/null 2>&1 || die "$sf is not valid JSON"
  for key in feature current_phase completed_phases gates timestamps artifacts; do
    jq -e --arg k "$key" 'has($k)' "$sf" >/dev/null 2>&1 \
      || die "$sf is missing required key '$key'"
  done
  jq -e '.completed_phases | type == "array"' "$sf" >/dev/null 2>&1 \
    || die "$sf: completed_phases must be an array"
  cp="$(jq -r '.current_phase // empty' "$sf")"
  phase_known "$cp" || die "$sf: current_phase '$cp' is not a phase this pipeline knows"
  printf '%s\n' "$sf"
}

cmd_init() {
  need_feature "$1"
  feature="$1"; branch="${2:-}"; base="${3:-}"; ptype="${4:-}"
  sf="$(state_file "$feature")"
  if [ -f "$sf" ]; then
    # Idempotent: an existing, valid state file is the run's memory and is
    # never clobbered — re-running init is how a resumed session finds it.
    cmd_validate "$feature" >/dev/null
    printf '%s\n' "$sf"
    return 0
  fi
  mkdir -p "${sf%/*}"
  jq -n --arg f "$feature" --arg b "$branch" --arg bb "$base" --arg pt "$ptype" '{
    feature: $f, branch: $b, baseBranch: $bb, projectType: $pt,
    current_phase: "preflight", completed_phases: [],
    timestamps: {}, artifacts: {}, pr_url: "", commits: [],
    implementer: "", test_baseline: "", last_task: "",
    deferred_ambiguities: [], analyze_changelog: [],
    config: {}, speckit: {}, capabilities: {}, gates: {}
  }' > "$sf"
  printf '%s\n' "$sf"
}

cmd_phase_start() {
  feature="$1"; phase="${2:-}"
  [ -n "$phase" ] || die "phase-start needs a phase"
  phase_known "$phase" || die "unknown phase '$phase' (legal:${PHASES% })"
  sf="$(cmd_validate "$feature")"
  # Written at the START of the phase, so a crash still records which phase
  # to re-enter. Re-entering a completed phase is safe by design; this
  # write is an in-place update either way.
  tmp="$sf.tmp"
  jq --arg p "$phase" --arg t "$(now)" \
     '.current_phase = $p
      | .timestamps[$p] = ((.timestamps[$p] // {}) + {started: $t})' \
     "$sf" > "$tmp" && mv "$tmp" "$sf"
}

cmd_phase_done() {
  feature="$1"; phase="${2:-}"
  [ -n "$phase" ] || die "phase-done needs a phase"
  phase_known "$phase" || die "unknown phase '$phase'"
  sf="$(cmd_validate "$feature")"
  tmp="$sf.tmp"
  jq --arg p "$phase" --arg t "$(now)" \
     '.completed_phases = (if (.completed_phases | index($p)) then .completed_phases else .completed_phases + [$p] end)
      | .timestamps[$p] = ((.timestamps[$p] // {}) + {done: $t})' \
     "$sf" > "$tmp" && mv "$tmp" "$sf"
}

# --from <phase> is offered by the resume prompt and validated against
# which artefacts exist, not against hope: re-entering a phase without the
# artefact it consumes re-runs work that has nothing to work on.
cmd_from_validate() {
  feature="$1"; phase="${2:-}"
  [ -n "$phase" ] || die "from-validate needs a phase"
  phase_known "$phase" || die "unknown phase '$phase'"
  sf="$(cmd_validate "$feature")"
  need=""
  case "$phase" in
    D)         need="spec" ;;
    E)         need="plan" ;;
    F|F.5|G|H) need="tasks" ;;
  esac
  if [ -n "$need" ]; then
    a="$(jq -r --arg k "$need" '.artifacts[$k] // empty' "$sf")"
    { [ -n "$a" ] && [ -e "$a" ]; } \
      || die "--from $phase needs the '$need' artefact, and the state file records none that exists"
    return 0
  fi
  cur="$(jq -r '.current_phase' "$sf")"
  [ "$phase" = "$cur" ] && return 0
  jq -e --arg p "$phase" '.completed_phases | index($p)' "$sf" >/dev/null 2>&1 \
    || die "--from $phase: not the current phase, not completed, and no artefact rule admits it"
}

# A full id only: 40 lowercase hex characters. One commit spelled two ways,
# short and full, would be recorded twice and read twice. The digits are
# spelled out rather than written as a range, because a range in a bracket
# pattern follows the locale on an older bash.
sha_ok() {
  [ "${#1}" -eq 40 ] || return 1
  case "$1" in *[!0123456789abcdef]*) return 1 ;; esac
}

# The entry commit-add writes, defined ONCE and used by both of its jq
# programs. The duplicate check compares against exactly what the write would
# append, so the two can never disagree about what "the same entry" means —
# and that agreement is what makes a re-run after a crash safe.
# shellcheck disable=SC2016 # a jq program: $sha, $k, $p, $t and $ARGS are jq's
ENTRY_JQ='def entry: {sha: $sha, kind: $k, piece: $p,
  tasks: ($t | if . == "" then [] else split(",") end),
  files: $ARGS.positional};'

# commit-add records one commit the run made: what it holds, which piece and
# tasks it covers, and which files it changed. The orchestrator calls it after
# every commit; piece-next reads what it wrote to know which pieces are done.
#
# Cheap checks come first, so a bad call never spawns jq. Nothing is printed
# on stdout, in success or refusal: the orchestrator reads stdout, and a stray
# line there would be taken for an answer.
cmd_commit_add() {
  [ $# -ge 5 ] || die "commit-add needs <feature> <kind> <sha> <piece> <tasks> [<file>...]"
  feature="$1"; kind="$2"; sha="$3"; piece="$4"; tasks="$5"; shift 5
  kind_known "$kind" || die "unknown kind '$kind' (legal:${KINDS% })"
  [ -n "$sha" ] || die "the entry needs a commit id"
  sha_ok "$sha" \
    || die "'$sha' is not a full commit id: 40 lowercase hex characters, as git rev-parse prints them"
  if [ "$kind" = piece ]; then
    [ -n "$piece" ] || die "a piece entry needs a piece name"
    [ -n "$tasks" ] || die "a piece entry needs its task ids"
  fi
  # A name holding one of these can never equal a heading piece-next prints,
  # so the piece would be offered for ever.
  case "$piece" in *$'\r'*|*$'\n'*|*$'\x1f'*)
    die "the piece name holds a control character (CR, LF or U+001F)" ;;
  esac
  [ $# -gt 0 ] || [ "$kind" = tests ] \
    || die "a $kind entry needs the files it changed; only a tests entry may have none"
  # An empty item is what an unset variable expands to, so it is the shape a
  # broken caller produces; a list that is merely non-empty would hide it.
  case ",$tasks," in *,,*) [ -z "$tasks" ] || die "the task list holds an empty task id: '$tasks'" ;; esac
  for f in "$@"; do [ -n "$f" ] || die "the file list holds an empty path"; done
  sf="$(cmd_validate "$feature")"
  jqargs=(--arg sha "$sha" --arg k "$kind" --arg p "$piece" --arg t "$tasks")

  # One word back: new, same, conflict or legacy. The files travel after
  # `--args --`, so a path starting with a dash is data and not an option.
  # Old-style entries are bare strings written before this command existed —
  # an id, or an id and the commit subject — so only their first word is
  # compared, and only when it is long enough to be an id git prints. This
  # branch can go once no state file anywhere still holds a bare string.
  # shellcheck disable=SC2016 # a jq program: $sha, $mine and $w are jq's
  verdict="$(jq -r "${jqargs[@]}" "$ENTRY_JQ"'
    [.commits[]? | objects | select(.sha == $sha)] as $mine
    | if ($mine | length) > 0 then
        (if any($mine[]; {kind, piece, tasks, files} == (entry | {kind, piece, tasks, files}))
         then "same" else "conflict" end)
      elif any(.commits[]? | strings;
               (split(" ")[0] // "") as $w
               | ($w | test("^[0-9a-f]{7,40}$")) and ($sha | startswith($w)))
      then "legacy"
      else "new" end' "$sf" --args -- "$@")"
  case "$verdict" in
    new) ;;
    # A re-run after a crash repeats the call exactly; the work is done.
    same) return 0 ;;
    conflict) die "commit $sha is already recorded with different details in $sf — not recording it twice" ;;
    legacy) die "commit $sha is already recorded by an old-style entry in $sf" ;;
    *) die "commit-add: the duplicate check answered '$verdict', which is none of new, same, conflict or legacy — nothing written" ;;
  esac

  tmp="$sf.tmp"
  jq "${jqargs[@]}" "$ENTRY_JQ"' .commits += [entry]' "$sf" --args -- "$@" > "$tmp" && mv "$tmp" "$sf"
}

# piece-next names the next piece to build: the first `## Phase <N>:` section
# of the run's tasks file that has a task line and is not yet recorded by a
# piece or converge entry. It prints two lines — the heading after "## ", then
# the task ids — or nothing when every piece is recorded. "Nothing left" and
# "nothing to read" never look the same: the second is a refusal, by name.
#
# The whole walk is ONE jq program over one line of output. On Windows jq
# ends every line with CRLF, and command substitution removes only the last
# line ending — the CR on every earlier line survives (measured). So jq's
# multi-line output is never printed here: jq returns one line, split on the
# U+001F unit separator, and bash prints the two fields itself. A heading
# printed with a stray CR would be recorded with it, never match again, and be
# offered for ever. For the same reason a heading that still holds a CR after
# its line ending is removed, or holds U+001F, is refused rather than printed
# — and so is one holding a NUL, which command substitution drops silently,
# so the name printed would never equal the heading in the file (measured).
cmd_piece_next() {
  feature="$1"
  sf="$(cmd_validate "$feature")"
  tf="$(jq -r '.artifacts.tasks // empty' "$sf")"
  [ -n "$tf" ] || die "$sf records no tasks file (artifacts.tasks) — the tasks phase has not run"
  [ -f "$tf" ] || die "tasks file not found: $tf (recorded in $sf)"
  # Every "## " heading opens a slot in the array: a piece for a Phase
  # heading, null for any other, so a task line under a non-piece heading has
  # nowhere to go. A "### " line does not start with "## " and opens nothing.
  # A line that is not a task captures nothing, and appending nothing is a
  # no-op. The last slot is written as .[length-1], not .[-1]: assigning
  # through a negative index is not dependable across the jq versions CI runs.
  r="$(jq -r --rawfile t "$tf" '
    [.commits[]? | objects | select(.kind == "piece" or .kind == "converge") | .piece] as $done
    | (reduce ($t | split("\n")[] | rtrimstr("\r")) as $l ([];
        if ($l | startswith("## ")) then
          . + [if ($l | test("^## Phase [0-9]+[a-z]*:"))
               then {h: ($l | ltrimstr("## ")), ids: []} else null end]
        elif length > 0 and .[length-1] != null then
          .[length-1].ids += [$l | capture("^- \\[[ xX]\\] (?<id>T[0-9]+)").id]
        else . end))
    | [.[] | select(. != null and (.ids | length > 0))] as $pieces
    | if ($pieces | length) == 0 then "none"
      else
        ([$pieces[] | select(.h as $h | any($done[]; . == $h) | not)] | first) as $next
        | if $next == null then "done"
          elif ($next.h | explode | any(. == 0 or . == 13 or . == 31)) then "bad"
          else "next\u001f" + $next.h + "\u001f" + ($next.ids | join(",")) end
      end' "$sf")"
  case "${r%%$'\x1f'*}" in
    done) return 0 ;;
    none) die "no piece in $tf: no '## Phase <N>:' heading with a task line under it" ;;
    bad)  die "the next piece's heading holds a control character (a CR, NUL or U+001F) that its output cannot carry, in $tf" ;;
    next)
      rest="${r#*$'\x1f'}"
      printf '%s\n%s\n' "${rest%%$'\x1f'*}" "${rest#*$'\x1f'}" ;;
    *) die "piece-next: the walk answered '$r', which is none of next, done, none or bad" ;;
  esac
}

cmd_lock_take() {
  feature="$1"; session="${2:-}"
  [ -n "$session" ] || die "lock-take needs a session id"
  lf="$(lock_file)"; mkdir -p "$STATE_ROOT"
  if [ -f "$lf" ]; then
    holder="$(jq -r '.feature // empty' "$lf" 2>/dev/null || true)"
    hs="$(state_file "${holder:-missing}")"
    stale=false
    if [ -z "$holder" ] || [ ! -f "$hs" ]; then stale=true
    elif [ "$(jq -r '.current_phase // empty' "$hs" 2>/dev/null)" = "DONE" ]; then stale=true; fi
    if [ "$stale" = true ]; then
      # A crashed session must never lock the repository permanently — that
      # failure mode turns a safety feature into an outage.
      warn "taking over a stale lock (holder '${holder:-unknown}' has no live run)"
      rm -f "$lf"
    else
      warn "the repository is locked by a live run:"
      warn "  feature: $holder"
      warn "  session: $(jq -r '.session // "unknown"' "$lf")"
      warn "  taken:   $(jq -r '.taken_at // "unknown"' "$lf")"
      warn "if that run is truly gone, remove the lock yourself: rm '$lf'"
      exit 1
    fi
  fi
  # noclobber makes creation atomic: two takers race, one wins, the loser
  # lands in the live-lock branch above on its retry.
  ( set -C; jq -n --arg f "$feature" --arg s "$session" --arg t "$(now)" \
      '{feature: $f, session: $s, taken_at: $t}' > "$lf" ) 2>/dev/null \
    || die "lost the lock race; run lock-take again"
}

cmd_lock_release() {
  feature="$1"
  lf="$(lock_file)"
  [ -f "$lf" ] || return 0   # a clean stop releases; releasing twice is a no-op
  holder="$(jq -r '.feature // empty' "$lf" 2>/dev/null || true)"
  [ "$holder" = "$feature" ] || die "lock is held by '$holder', not '$feature' — not releasing it"
  rm -f "$lf"
}

cmd="${1:-}"; [ $# -ge 2 ] || usage
feature_arg="$2"
need_feature "$feature_arg"
case "$cmd" in
  init)          shift 2; cmd_init "$feature_arg" "$@" ;;
  read)          cmd_validate "$feature_arg" >/dev/null; cat "$(state_file "$feature_arg")" ;;
  validate)      cmd_validate "$feature_arg" >/dev/null ;;
  phase-start)   cmd_phase_start "$feature_arg" "${3:-}" ;;
  phase-done)    cmd_phase_done "$feature_arg" "${3:-}" ;;
  from-validate) cmd_from_validate "$feature_arg" "${3:-}" ;;
  lock-take)     cmd_lock_take "$feature_arg" "${3:-}" ;;
  lock-release)  cmd_lock_release "$feature_arg" ;;
  commit-add)    shift 2; cmd_commit_add "$feature_arg" "$@" ;;
  piece-next)    cmd_piece_next "$feature_arg" ;;
  *) usage ;;
esac
