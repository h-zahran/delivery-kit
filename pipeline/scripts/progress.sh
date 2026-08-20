#!/usr/bin/env bash
# progress.sh — state and lock mechanics for the pipeline plugin.
#
# Contract, shared with preflight.sh and inherited from the spec tool's own
# scripts: PURE JSON (or a bare path, or nothing) on stdout, every
# diagnostic on stderr. A warning printed into a JSON stream is a parse
# failure that reads like a missing feature.
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
usage() { die "usage: progress.sh <init|read|validate|phase-start|phase-done|from-validate|lock-take|lock-release> <feature> [args]"; }

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
phase_known() { case "$PHASES" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

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
  *) usage ;;
esac
