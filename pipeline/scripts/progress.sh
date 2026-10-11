#!/usr/bin/env bash
# progress.sh — state and lock mechanics for the pipeline plugin.
#
# Contract, shared with preflight.sh and inherited from the spec tool's own
# scripts: PURE JSON (or a bare path, or nothing) on stdout, every
# diagnostic on stderr. A warning printed into a JSON stream is a parse
# failure that reads like a missing feature. The exceptions, by design, are
# plain text that is the answer and nothing else: piece-next prints two
# lines, a heading and its task ids; the commit commands print the commit
# id they recorded; --list prints paths, one per line; guide prints the
# review guide and commit-list prints K's list; suite-key prints a key,
# suite-record a verdict, suite-lookup a record's path and a summary,
# tap-check one summary line, and get the value it was asked for.
#
# Everything this file writes lives under .delivery-kit/, and the commit
# commands write git commits, never a path under it. The state directory is
# the user's to ignore; the skill (never this script) offers the one
# gitignore line.
#
# jq here may be a native Windows binary with text-mode stdout: command
# substitution strips the trailing CR it emits, `read` does not (measured
# repeatedly in this repository's suite) — so this script reads jq only
# through command substitution and jq's exit codes, never `while read`, and
# the commit commands also pass $JQB (jq -b where this jq takes it: binary
# output, no CR) and strip any CR left. git's path lists are read
# NUL-separated from a file instead. Every file this script writes with jq —
# the state file, the lock, the metrics file — is written with $JQB too, so
# it holds LF line endings on every system: a Windows jq without -b wrote
# the state file in CRLF (measured, jq 1.8.1). jq 1.6 is the oldest jq
# this script supports.
set -euo pipefail

STATE_ROOT=".delivery-kit"
# The folder that holds this script, absolute: trailer-check.sh sits beside
# it, and the run may change directory before a commit.
SCRIPT_DIR="${BASH_SOURCE[0]}"
case "$SCRIPT_DIR" in */*) SCRIPT_DIR="${SCRIPT_DIR%/*}" ;; *) SCRIPT_DIR=. ;; esac
SCRIPT_DIR="$(CDPATH='' cd -P -- "$SCRIPT_DIR" && pwd -P)" || { printf 'progress.sh: cannot find the folder that holds progress.sh\n' >&2; exit 1; }

warn() { printf 'progress.sh: %s\n' "$*" >&2; }
die()  { printf 'progress.sh: %s\n' "$*" >&2; exit 1; }

# HIDDEN_CHARS: the characters that can disguise text, one list for this
# script and trailer-check.sh. A copy of this script made without it stops
# here, saying so: bash's own error would name the copy's full path.
[ -r "$SCRIPT_DIR/hidden-chars.sh" ] || die "hidden-chars.sh is missing beside progress.sh"
# shellcheck source-path=SCRIPTDIR source=hidden-chars.sh
. "$SCRIPT_DIR/hidden-chars.sh"

# Every invocation removes what it made, on any exit: suite-key's scratch
# file, a text file's checked copy, with_trailers' message copy and its
# check's error file, show-message's record message, and the state lock
# this process holds. Each name starts empty: one inherited from the
# caller's environment names a file this process did not make, and an
# inherited STATE_LOCK would also read as a lock already held.
SK_SCRATCH='' TEXT_COPY='' TR_MSG='' TR_ERR='' SHOW_MSG='' STATE_LOCK=''
on_exit() {
  rm -f "${SK_SCRATCH:-}" "${TEXT_COPY:-}" "${TR_MSG:-}" "${TR_ERR:-}" "${SHOW_MSG:-}"
  if [ -n "${STATE_LOCK:-}" ]; then rmdir "$STATE_LOCK" 2>/dev/null || true; fi
}
trap on_exit EXIT
usage() { die "usage: progress.sh <init|read|validate|phase-start|phase-done|from-validate|lock-take|lock-release|commit-add|piece-next|snapshot|spec-commit|piece-commit|late-commit|remainder-commit|show-message|record-branch|guide|commit-list|metrics|state-set|drop-stale|suite-key|suite-record|suite-lookup|ask-later|pending|answer|pending-check|abandon|get> <feature> [args]"; }

# tap-check alone needs no jq: it reads a TAP file with awk, and the
# repository's scripts/check-suite.sh calls it, which needs only bash and awk.
if [ "${1:-}" != tap-check ]; then
  command -v jq >/dev/null 2>&1 || die "jq is required and was not found on PATH"
fi

# JQB is -b when this jq takes it, and empty when it does not. -b (binary
# output) keeps a native Windows jq from ending every line with CR, and
# every jq 1.7 or later takes it on every system; jq 1.6 takes it only on
# Windows, and refuses it elsewhere as an unknown option, where jq writes LF
# without it. So it is probed, once per process, by the dispatch below —
# never assumed. validate and read do not use it and spawn no probe.
JQB=''
jq_b_probe() { if jq -b -n 1 >/dev/null 2>&1; then JQB=-b; else JQB=''; fi; }

# Feature names come from the spec tool (NNN-slug). Anything else could
# escape the runs directory, so the shape is enforced, loudly, everywhere.
# A name made only of dots passes that shape and still escapes: "." and ".."
# are directories already, so `init ..` wrote .delivery-kit/progress.json
# and `init .` wrote runs/progress.json (measured). It is refused by name.
# So is a name ending in a dot: Win32 drops a trailing dot, so a native
# Windows jq cannot open .delivery-kit/runs/a./progress.json, and
# preflight.sh refuses such a spec folder segment for the same reason. One
# rule covers both, since a name made only of dots ends in one.
feature_ok() {
  case "$1" in ''|*[!A-Za-z0-9._-]*|*.) return 1 ;; esac
  return 0
}
need_feature() {
  feature_ok "$1" && return 0
  case "$1" in
    ''|*[!A-Za-z0-9._-]*) die "feature name '$1' — letters, digits, dot, dash, underscore only" ;;
    *[!.]*) die "feature name '$1' ends with a dot, which Windows drops from a folder name" ;;
  esac
  die "feature name '$1' is only dots, which names a directory that already exists, not a run"
}

state_file() { printf '%s/runs/%s/progress.json' "$STATE_ROOT" "$1"; }
lock_file()  { printf '%s/lock' "$STATE_ROOT"; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# The full phase alphabet. DONE is the terminal marker, not a phase a run
# works in — but phase-start accepts it so a finishing run can record it.
PHASES=" preflight A B C C.5 D E F F.5 G H H.5 H.7 I J K L M N N.5 O DONE "
# Word by word, never a substring match: `case "$PHASES" in *" $1 "*)`
# accepted a run of adjacent names, because "A B" and "C C.5" with their
# surrounding spaces ARE substrings of the list (measured). An exact
# comparison against each word refuses them, and anything else that is not
# one whole name. The list is split on spaces only, never globbed: no name
# holds a pattern character.
phase_known() {
  local p
  for p in $PHASES; do [ "$p" = "$1" ] && return 0; done
  return 1
}

# What a recorded commit holds. One list, read by the check and by its message.
KINDS=" spec piece converge simplify review tests constitution other "
# Word by word, as phase_known is: a substring match accepts "spec piece",
# for the same reason (measured).
kind_known() {
  local k
  for k in $KINDS; do [ "$k" = "$1" ] && return 0; done
  return 1
}

# The keys every state file must hold, in the order validate names a missing
# one. One list, read by both checks below.
REQUIRED_KEYS="feature current_phase completed_phases gates timestamps artifacts"

# validate's checks as ONE jq program, because every subcommand validates and
# a jq process costs far more than the checks do on Windows: on a 19 KB state
# file, ten alternating runs each, the nine-process form averaged 1.9 s a call
# and this one 0.47 s, bash start-up included (2026-10-06). It reads the
# file slurped, judges only a file that is exactly ONE JSON document, and
# answers one line naming the FIRST fault, in the order the per-check form
# finds them:
#   nojson        the document is null or false (`jq -e .` fails on those)
#   missing<US>K  key K is absent; any non-object fails on the first key,
#                 because `has` errors on it
#   notarray      completed_phases is not an array
#   phase<US>P    current_phase is the string P, for bash to judge
#   other         current_phase is not a string; bash reads it as before
#   each          not one document; judged document by document below
# The string comes last so the line ending jq adds lands where the per-check
# form's did, and command substitution strips it the same way.
# shellcheck disable=SC2016 # a jq program: $d, $k and $ARGS are jq's
VALIDATE_JQ='
  if length != 1 then "each"
  else .[0]
  | if . == null or . == false then "nojson"
    elif type != "object" then "missing\u001f" + $ARGS.positional[0]
    else . as $d
    | [$ARGS.positional[] | select(. as $k | $d | has($k) | not)] as $gone
    | if ($gone | length) > 0 then "missing\u001f" + $gone[0]
      elif (.completed_phases | type) != "array" then "notarray"
      elif (.current_phase | type) == "string" then "phase\u001f" + .current_phase
      else "other" end
    end
  end'

# The per-check form, kept for what the one program does not judge: a file
# that is not exactly one JSON document — unparseable, empty, or several
# documents, where jq judges each document in turn and its exit status
# across them is not the same in every jq version. Sets cp.
validate_each() {
  local key
  # A file with no byte but whitespace is not JSON, whatever jq says: jq 1.6
  # -e exits 0 on an empty file, which read as "current_phase ''".
  [ -n "$(LC_ALL=C tr -d ' \t\r\n' < "$1" | head -c 1)" ] || die "$1 is not valid JSON"
  jq -e . "$1" >/dev/null 2>&1 || die "$1 is not valid JSON"
  for key in $REQUIRED_KEYS; do
    if ! jq -e --arg k "$key" 'has($k)' "$1" >/dev/null 2>&1; then
      die "$1 is missing required key '$key'"
    fi
  done
  if ! jq -e '.completed_phases | type == "array"' "$1" >/dev/null 2>&1; then
    die "$1: completed_phases must be an array"
  fi
  cp="$(jq -r '.current_phase // empty' "$1")"
}

cmd_validate() {
  need_feature "$1"
  sf="$(state_file "$1")"
  [ -f "$sf" ] || die "no state file at $sf"
  validate_file "$sf"
}

# validate_file <path> — validate's checks on any file, so a whole-file write
# can be judged in its temp file before it replaces the state file. Prints
# the path, as validate always has.
validate_file() {
  sf="$1"
  # A jq that fails here (a parse error, or a program it cannot run) answers
  # nothing, and nothing falls through to the per-check form.
  # shellcheck disable=SC2086 # REQUIRED_KEYS is split into words on purpose
  v="$(jq -r -s "$VALIDATE_JQ" "$sf" --args $REQUIRED_KEYS 2>/dev/null)" || v=""
  case "${v%%$'\x1f'*}" in
    nojson)   die "$sf is not valid JSON" ;;
    missing)  die "$sf is missing required key '${v#*$'\x1f'}'" ;;
    notarray) die "$sf: completed_phases must be an array" ;;
    phase)    cp="${v#*$'\x1f'}" ;;
    other)    cp="$(jq -r '.current_phase // empty' "$sf")" ;;
    *)        validate_each "$sf" ;;
  esac
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
    init_metrics "$feature" "$sf"
    printf '%s\n' "$sf"
    return 0
  fi
  mkdir -p "${sf%/*}"
  jq ${JQB:+"$JQB"} -n --arg f "$feature" --arg b "$branch" --arg bb "$base" --arg pt "$ptype" '{
    feature: $f, branch: $b, baseBranch: $bb, projectType: $pt,
    current_phase: "preflight", completed_phases: [],
    timestamps: {}, artifacts: {}, pr_url: "", commits: [],
    implementer: "", test_baseline: "", last_task: "",
    deferred_ambiguities: [], analyze_changelog: [],
    config: {}, speckit: {}, capabilities: {}, gates: {}
  }' > "$sf"
  init_metrics "$feature" "$sf"
  printf '%s\n' "$sf"
}

# init_metrics <feature> <state file> — the run file, made by init when it
# is absent, on a fresh run and on a resume alike; one that exists is left
# for metrics to refresh. A failure here is said and does not stop init:
# the state file is the run's memory, and metrics at the next phase
# boundary tries again. Nothing reaches stdout, which carries init's path.
init_metrics() {
  local mf
  mf="$(run_dir "$1")/pipeline-run.json"
  [ ! -e "$mf" ] || return 0
  ( metrics_write "$1" "$2" ) > /dev/null || warn "could not make $mf now; progress.sh metrics makes it"
}

cmd_phase_start() {
  feature="$1"; phase="${2:-}"
  [ -n "$phase" ] || die "phase-start needs a phase"
  phase_known "$phase" || die "unknown phase '$phase' (legal:${PHASES% })"
  sf="$(cmd_validate "$feature")"
  # Written at the START of the phase, so a crash still records which phase
  # to re-enter. Re-entering a completed phase is safe by design; this
  # write is an in-place update either way.
  state_lock "$sf"
  tmp="$(mktemp "$sf.XXXXXX")" || die "could not make a temporary file beside $sf — the state file is unchanged"
  if ! jq ${JQB:+"$JQB"} --arg p "$phase" --arg t "$(now)" \
     '.current_phase = $p
      | .timestamps[$p] = ((.timestamps[$p] // {}) + {started: $t})' \
     "$sf" > "$tmp"; then rm -f "$tmp"; die "the write to $sf failed — the state file is unchanged"; fi
  mv "$tmp" "$sf"
  state_unlock
}

cmd_phase_done() {
  feature="$1"; phase="${2:-}"
  [ -n "$phase" ] || die "phase-done needs a phase"
  phase_known "$phase" || die "unknown phase '$phase'"
  sf="$(cmd_validate "$feature")"
  state_lock "$sf"
  tmp="$(mktemp "$sf.XXXXXX")" || die "could not make a temporary file beside $sf — the state file is unchanged"
  if ! jq ${JQB:+"$JQB"} --arg p "$phase" --arg t "$(now)" \
     '.completed_phases = (if (.completed_phases | index($p)) then .completed_phases else .completed_phases + [$p] end)
      | .timestamps[$p] = ((.timestamps[$p] // {}) + {done: $t})' \
     "$sf" > "$tmp"; then rm -f "$tmp"; die "the write to $sf failed — the state file is unchanged"; fi
  mv "$tmp" "$sf"
  state_unlock
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
# and that agreement is what makes a re-run after a crash safe. The files are
# read from a NUL-separated file ($f), never from jq's arguments: a native
# Windows jq cannot start with more than 32,767 characters of command line,
# about 650 paths, so a big commit landed and could never be recorded
# (measured). NUL, not a line feed: a path from a commit on the branch is
# not checked for one. The one NUL that ends the list is dropped; any other
# empty item is an empty path, which the duplicate check refuses.
# shellcheck disable=SC2016 # a jq program: $sha, $k, $p, $t and $f are jq's
ENTRY_JQ='def files: $f | split("\u0000")
  | if length > 0 and .[length-1] == "" then .[0:length-1] else . end;
def entry: {sha: $sha, kind: $k, piece: $p,
  tasks: ($t | if . == "" then [] else split(",") end),
  files: files};'

# commit-add records one commit the run made: what it holds, which piece and
# tasks it covers, and which files it changed. The orchestrator calls it after
# every commit; piece-next reads what it wrote to know which pieces are done.
# The files come as arguments, or with --files-from as a NUL-separated file —
# the form every commit command here uses, so no list is too long.
#
# Cheap checks come first, so a bad call never spawns jq. Nothing is printed
# on stdout, in success or refusal: the orchestrator reads stdout, and a stray
# line there would be taken for an answer.
cmd_commit_add() {
  local ff='' id rest
  feature="${1:-}"; shift || true
  if [ "${1:-}" = --files-from ]; then
    [ $# -ge 2 ] || die "commit-add --files-from needs a file"
    ff="$2"; shift 2
  fi
  [ $# -ge 4 ] || die "commit-add needs <feature> [--files-from <file>] <kind> <sha> <piece> <tasks> [<file>...]"
  kind="$1"; sha="$2"; piece="$3"; tasks="$4"; shift 4
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
  if [ -n "$ff" ]; then
    [ $# -eq 0 ] || die "commit-add --files-from takes no paths after <tasks>: the list is the file's"
    [ -f "$ff" ] || die "commit-add --files-from: no file at $ff"
  else
    [ $# -gt 0 ] || [ "$kind" = tests ] \
      || die "a $kind entry needs the files it changed; only a tests entry may have none"
  fi
  # An empty item is what an unset variable expands to, so it is the shape a
  # broken caller produces; a list that is merely non-empty would hide it.
  case ",$tasks," in *,,*) [ -z "$tasks" ] || die "the task list holds an empty task id: '$tasks'" ;; esac
  # A task id is T and digits, as piece-next reads it from the tasks file: the
  # review guide prints the ids in a table cell, so an id is never markup. The
  # digits are spelled out, as sha_ok's are, for the same locale reason.
  rest="$tasks,"
  while [ -n "$tasks" ] && [ -n "$rest" ]; do
    id="${rest%%,*}"; rest="${rest#*,}"
    case "$id" in T|[!T]*|T*[!0123456789]*)
      die "the task list holds task id '$id', which is not T and digits (T001)" ;;
    esac
  done
  for f in "$@"; do [ -n "$f" ] || die "the file list holds an empty path"; done
  sf="$(cmd_validate "$feature")"
  if [ -z "$ff" ]; then
    ff="${sf%/*}/commit-add-files.nul"
    nul_file "$ff" "$@"
  fi
  jqargs=(--arg sha "$sha" --arg k "$kind" --arg p "$piece" --arg t "$tasks" --rawfile f "$ff")

  # One word back: new, same, conflict or legacy — or a refusal of the file
  # list itself, which only a --files-from list can reach here.
  # Old-style entries are bare strings written before this command existed —
  # an id, or an id and the commit subject — so only their first word is
  # compared, and only when it is long enough to be an id git prints. This
  # branch can go once no state file anywhere still holds a bare string.
  # shellcheck disable=SC2016 # a jq program: $sha, $mine and $w are jq's
  # A commits value that is not a list is refused, never read as empty: `[]?`
  # would otherwise swallow the type error and answer "new".
  verdict="$(jq -r "${jqargs[@]}" "$ENTRY_JQ"'
    if (files | any(. == "")) then "emptypath"
    elif (files | length) == 0 and $k != "tests" then "nofiles"
    elif ((.commits // []) | type) != "array" then "notlist"
    else
    [.commits[]? | objects | select(.sha == $sha)] as $mine
    | if ($mine | length) > 0 then
        (if any($mine[]; {kind, piece, tasks, files} == (entry | {kind, piece, tasks, files}))
         then "same" else "conflict" end)
      elif any(.commits[]? | strings;
               (split(" ")[0] // "") as $w
               | ($w | test("^[0-9a-f]{7,40}$")) and ($sha | startswith($w)))
      then "legacy"
      else "new" end
    end' "$sf")"
  case "$verdict" in
    new) ;;
    emptypath) die "the file list holds an empty path" ;;
    nofiles) die "a $kind entry needs the files it changed; only a tests entry may have none" ;;
    notlist) die "$sf: commits must be a list — not recording into it" ;;
    # A re-run after a crash repeats the call exactly; the work is done.
    same) return 0 ;;
    conflict) die "commit $sha is already recorded with different details in $sf — not recording it twice" ;;
    legacy) die "commit $sha is already recorded by an old-style entry in $sf" ;;
    *) die "commit-add: the duplicate check answered '$verdict', which is none of new, same, conflict, legacy, notlist, emptypath or nofiles — nothing written" ;;
  esac

  state_lock "$sf"
  tmp="$(mktemp "$sf.XXXXXX")" || die "could not make a temporary file beside $sf — nothing recorded"
  if ! jq ${JQB:+"$JQB"} "${jqargs[@]}" "$ENTRY_JQ"' .commits += [entry]' "$sf" > "$tmp"; then rm -f "$tmp"; die "the write to $sf failed — nothing recorded"; fi
  mv "$tmp" "$sf"
  state_unlock
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
  # A commits value that is not a list is refused, never read as "nothing
  # recorded": that reading would offer every piece again.
  r="$(jq -r --rawfile t "$tf" '
    if ((.commits // []) | type) != "array" then "notlist" else
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
      end
    end' "$sf")"
  case "${r%%$'\x1f'*}" in
    done) return 0 ;;
    notlist) die "$sf: commits must be a list — cannot tell which pieces are recorded" ;;
    none) die "no piece in $tf: no '## Phase <N>:' heading with a task line under it" ;;
    bad)  die "the next piece's heading holds a control character (a CR, NUL or U+001F) that its output cannot carry, in $tf" ;;
    next)
      rest="${r#*$'\x1f'}"
      printf '%s\n%s\n' "${rest%%$'\x1f'*}" "${rest#*$'\x1f'}" ;;
    *) die "piece-next: the walk answered '$r', which is none of next, done, none, bad or notlist" ;;
  esac
}

# RUN_END_JQ — how a run stands, in one word: "abandoned" when `abandon`
# marked it (any abandoned value but null or false), "done" when its phase
# is DONE, else "live". Read by lock-take's staleness check and by abandon;
# preflight.sh judges runsLive by the same rule, in its own copy, since it
# cannot source this file.
RUN_END_JQ='if (.abandoned // false) != false then "abandoned" elif .current_phase == "DONE" then "done" else "live" end'

# not_abandoned <feature> — abandon is terminal: a run it ended is never
# worked on again. Without this, a resumed abandoned run took the lock and
# started phases while pre-flight reported no live run and another run's
# lock-take read its lock as stale, so two runs held the repository at once;
# and a session still running wrote on after its run was abandoned. The
# dispatch runs it before every command but the ones in ABANDONED_OK, so a
# command added later is refused on an abandoned run unless it is listed
# there. A state file it cannot read is left to the command's own validate,
# which names the fault.
ABANDONED_OK=" read validate get metrics abandon lock-release piece-next show-message guide commit-list pending pending-check suite-key suite-record suite-lookup "
not_abandoned() {
  local sf c
  for c in $ABANDONED_OK; do [ "$c" = "$cmd" ] && return 0; done
  sf="$(state_file "$1")"
  [ -f "$sf" ] || return 0
  [ "$(jqs "$RUN_END_JQ" "$sf" 2>/dev/null || true)" != abandoned ] \
    || die "run '$1' was abandoned: an abandoned run is ended, and $cmd is refused on it — start a new run under another name"
}

# The repository lock is a file naming its holder, and every look at it and
# every change to it — lock-take's staleness check, its removal of a stale
# lock and its claim, lock-release's check and removal — happens while this
# process holds <lock>.lock, the same mkdir lock every state write takes.
# Without it two takers could both find one stale lock: the first removed it
# and claimed the repository, then the second's removal deleted the FIRST
# one's new lock, and both believed they held it. A guard left by a taker
# that died is broken after a minute, as state_lock breaks any; a stale
# repository lock is still taken over below, by the same rules as before.
cmd_lock_take() {
  feature="$1"; session="${2:-}"
  [ -n "$session" ] || die "lock-take needs a session id"
  lf="$(lock_file)"; mkdir -p "$STATE_ROOT"
  state_lock "$lf"
  if [ -f "$lf" ]; then
    holder="$(jq -r '.feature // empty' "$lf" 2>/dev/null || true)"
    hs="$(state_file "${holder:-missing}")"
    stale=false
    if [ -z "$holder" ] || [ ! -f "$hs" ]; then stale=true
    else
      case "$(jqs "$RUN_END_JQ" "$hs" 2>/dev/null || true)" in done|abandoned) stale=true ;; esac
    fi
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
  # noclobber still guards the claim itself: anything at the path by now —
  # a directory, or a lock written by an older copy of this script, which
  # takes no guard — makes the claim fail rather than overwrite it.
  ( set -C; jq ${JQB:+"$JQB"} -n --arg f "$feature" --arg s "$session" --arg t "$(now)" \
      '{feature: $f, session: $s, taken_at: $t}' > "$lf" ) 2>/dev/null \
    || die "lost the lock race; run lock-take again"
  state_unlock
}

cmd_lock_release() {
  feature="$1"
  lf="$(lock_file)"
  [ -f "$lf" ] || return 0   # a clean stop releases; releasing twice is a no-op
  state_lock "$lf"
  [ -f "$lf" ] || { state_unlock; return 0; }
  holder="$(jq -r '.feature // empty' "$lf" 2>/dev/null || true)"
  [ "$holder" = "$feature" ] || die "lock is held by '$holder', not '$feature' — not releasing it"
  rm -f "$lf"
  state_unlock
}

# abandon <feature> — ends a run for good without finishing it. It records
# `abandoned: {at, phase}` in the state file, the phase being where the run
# stopped, and current_phase is left as it was: the state file is kept as
# the run's record, and is still valid for every release that reads it,
# since no required key changes. Pre-flight no longer counts the run as
# live, and a lock it holds is stale to lock-take. Then the repository lock
# is released if this run holds it, and left alone if another run does. A
# DONE run is refused: it has nothing to abandon. A run already abandoned
# keeps its first record, and its lock is still released, so a re-run after
# a crash between the two steps finishes the job. Prints nothing.
cmd_abandon() {
  local st holder
  feature="$1"
  [ $# -eq 1 ] || die "usage: abandon <feature>"
  sf="$(cmd_validate "$feature")"
  state_lock "$sf"
  st="$(jqs "$RUN_END_JQ" "$sf")" || die "$sf could not be read"
  # shellcheck disable=SC2016 # a jq program: $at is jq's
  case "$st" in
    live)      state_write "$sf" '.abandoned = {at: $at, phase: .current_phase}' --arg at "$(now)" ;;
    abandoned) warn "$feature is already abandoned: its first record stands" ;;
    done)      die "$feature is DONE: a finished run is not abandoned" ;;
    *)         die "$sf: could not tell how the run stands ('$st') — nothing written" ;;
  esac
  state_unlock
  lf="$(lock_file)"
  [ -f "$lf" ] || return 0
  state_lock "$lf"
  holder="$(jq -r '.feature // empty' "$lf" 2>/dev/null || true)"
  if [ -f "$lf" ] && [ "$holder" = "$feature" ]; then
    rm -f "$lf"
    warn "released the repository lock, which $feature held"
  fi
  state_unlock
}

# get <feature> <key|filter> — one value from the state file, read-only, for
# the orchestrator: a bare key name (letters, digits, underscore) prints that
# top-level key, anything else is a jq filter. Strings print raw, everything
# else as JSON, and always through $JQB, so a native Windows jq ends no line
# with a CR — a value read line by line compares as written.
cmd_get() {
  local q="${2:-}"
  feature="$1"
  { [ $# -eq 2 ] && [ -n "$q" ]; } || die "usage: get <feature> <key-or-jq-filter>"
  # A filter is never an option: one starting with a dash would reach jq as one.
  case "$q" in -*) die "get: '$q' starts with a dash, which jq would read as an option" ;; esac
  sf="$(cmd_validate "$feature")"
  case "$q" in
    [A-Za-z_]*) case "$q" in *[!A-Za-z0-9_]*) ;; *) jq ${JQB:+"$JQB"} -r --arg k "$q" '.[$k]' "$sf"; return ;; esac ;;
  esac
  jq ${JQB:+"$JQB"} -r "$q" "$sf"
}

# =============================================================================
# The commit mechanics. The orchestrator used to carry these as prose and
# re-type them by hand on every run; each is one subcommand here, tested.
# They run git from the repository's top level, where the state directory
# lives. git's path lists are read NUL-separated from a file — never through
# `$( )`, which drops the NUL bytes and runs the paths together — and a path
# holding a CR or LF is refused, because no list here can carry it. Every
# commit names every path it stages, through a NUL path file and
# `git --literal-pathspecs`, so git reads no path as a pattern and nothing
# already staged rides along.
# =============================================================================

# jqs <jq arguments...> — jq's raw answer through command substitution, with
# $JQB so a native Windows jq writes no CR, and any CR left stripped anyway.
# The SHORT -b only: jq 1.7 parses it on every platform (a no-op off
# Windows), while the long --binary is an unknown option there; jq 1.6
# parses neither off Windows, which is why JQB is probed.
jqs() {
  local v
  v="$(jq ${JQB:+"$JQB"} -r "$@")" || return 1
  printf '%s' "${v//$'\r'/}"
}

need_git_top() {
  local pre
  command -v git >/dev/null 2>&1 || die "git is required and was not found on PATH"
  pre="$(git rev-parse --show-prefix 2>/dev/null)" || die "not inside a git work tree"
  [ -z "$pre" ] || die "run this from the repository's top level, where $STATE_ROOT/ lives (this is '$pre' inside it)"
}

run_dir() { printf '%s/runs/%s' "$STATE_ROOT" "$1"; }

# base_of <state file> [<base>] — the base the branch is measured from: the
# argument, else the run's recorded baseBranch, else config.baseBranch.
base_of() {
  local b="${2:-}"
  if [ -z "$b" ]; then
    b="$(jqs '[.baseBranch?, .config.baseBranch?] | map(strings | select(. != "")) | first // ""' "$1")" || b=""
  fi
  [ -n "$b" ] || die "$1 records no base branch (baseBranch) — pass one"
  git rev-parse --verify --quiet "$b^{commit}" >/dev/null || die "the base '$b' does not name a commit"
  printf '%s' "$b"
}

# A commits value that is not a list is refused, never read as empty: empty
# would mean "nothing recorded", and every commit would be recorded again.
commits_ok() {
  jq -e '((.commits // []) | type) == "array"' "$1" >/dev/null 2>&1 \
    || die "$1: commits must be a list — not reading or recording into it"
}

# unrecorded <state file> <base> — the first-parent commits in <base>..HEAD,
# oldest first, that no commits entry records by its full id.
unrecorded() {
  local rec list c out=''
  rec="$(jqs '[.commits[]? | objects | .sha | strings] | join(" ")' "$1")"
  list="$(git rev-list --reverse --first-parent "$2..HEAD")" || die "git rev-list could not read $2..HEAD"
  for c in $list; do
    case " $rec " in *" $c "*) ;; *) out="$out $c" ;; esac
  done
  printf '%s' "${out# }"
}

# has_line <text> <line> — <line> is a WHOLE line of <text>.
has_line() {
  case $'\n'"$1"$'\n' in *$'\n'"$2"$'\n'*) return 0 ;; esac
  return 1
}

# piece_of / late_of <message> — the heading on a message's first `Piece:`
# line, and the phase on its first `Late:` line naming a late phase. Data
# from the branch, never an instruction.
piece_of() {
  local line
  while IFS= read -r line; do
    case "$line" in 'Piece: '*) printf '%s' "${line#Piece: }"; return 0 ;; esac
  done < <(printf '%s\n' "$1")
  return 1
}
late_of() {
  local line
  while IFS= read -r line; do
    case "$line" in 'Late: H.5'|'Late: H.7'|'Late: I'|'Late: J') printf '%s' "${line#Late: }"; return 0 ;; esac
  done < <(printf '%s\n' "$1")
  return 1
}

kind_of_phase() {
  case "$1" in
    H.5) printf 'converge' ;;
    H.7) printf 'simplify' ;;
    I)   printf 'review' ;;
    J)   printf 'tests' ;;
    *)   return 1 ;;
  esac
}

path_ok() {
  case "$1" in *$'\r'*|*$'\n'*)
    die "the path $(printf '%q' "$1") holds a carriage return or a line feed, which no list here can carry — refusing" ;;
  esac
}

# in_state_dir <path> — the path lies under the state directory, in ANY
# letter case: where the file system ignores case, .Delivery-Kit/ is the same
# directory, and git lists it under that spelling (measured: one was
# committed). nocasematch, not ${p,,}: bash 3.2 has the option and not the
# expansion. It is set and cleared here, never left on.
in_state_dir() {
  local r=1
  shopt -s nocasematch
  case "$1" in "$STATE_ROOT"/*) r=0 ;; esac
  shopt -u nocasematch
  return "$r"
}

# status_to <file> [<dir>] — the records `git status --porcelain=v1 -z
# --untracked-files=all --no-renames` lists, each a two-letter status, a
# space and a path, NUL-terminated.
status_to() {
  if [ $# -gt 1 ]; then
    git --literal-pathspecs status --porcelain=v1 -z --untracked-files=all --no-renames -- "$2" > "$1" \
      || die "git status failed"
  else
    git status --porcelain=v1 -z --untracked-files=all --no-renames > "$1" || die "git status failed"
  fi
}

# commit_files <sha> — CF: the files <sha> touched, read as K reads them.
commit_files() {
  local f tmp="$RD/diff-tree.nul"
  git diff-tree --no-commit-id --name-only -r -z --diff-merges=first-parent --root "$1" > "$tmp" \
    || die "git diff-tree could not read commit $1"
  CF=()
  while IFS= read -r -d '' f; do CF+=("$f"); done < "$tmp"
}

# dir_rel <dir> / repo_rel <file> — a path relative to the repository's top
# level, as git's lists spell it. artifacts may record a path absolute or
# relative; a directory comes back with its trailing slash, the top as ''.
dir_rel() {
  local top here
  top="$(git rev-parse --show-toplevel)"
  here="$(cd -- "$1" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || here=""
  [ "$here" = "$top" ] || die "'$1' is not inside this repository"
  (cd -- "$1" && git rev-parse --show-prefix)
}
repo_rel() {
  local d b
  case "$1" in */*) d="${1%/*}"; b="${1##*/}" ;; *) d=.; b="$1" ;; esac
  [ -n "$d" ] || d=/
  printf '%s%s' "$(dir_rel "$d")" "$b"
}

# feature_bounds <state file> — what counts as inside the feature: ROOTS
# (config.codeRoots, one "r:<root>" line each, so an empty root survives) and
# ROOT_LIST (each root stripped of a leading `./` and a trailing `/`, parsed
# once here, never once a path), SPEC_DIR (the directory artifacts.spec sits
# in) and TASKS_REL.
feature_bounds() {
  local spec tf r
  ROOTS="$(jqs '.config.codeRoots? | if type == "array" then (.[] | strings | "r:" + .) elif type == "string" then "r:" + . else empty end' "$1")"
  ROOT_LIST=()
  while IFS= read -r r; do
    case "$r" in r:*) r="${r#r:}"; r="${r#./}"; ROOT_LIST+=("${r%/}") ;; esac
  done < <(printf '%s\n' "$ROOTS")
  spec="$(jqs '(.artifacts.spec? // .artifacts.tasks? // "") | strings' "$1")"
  SPEC_DIR=''
  if [ -n "$spec" ] && [ -e "$spec" ]; then
    case "$spec" in */*) SPEC_DIR="$(dir_rel "${spec%/*}")" ;; *) SPEC_DIR="$(dir_rel .)" ;; esac
  fi
  TASKS_REL=''
  tf="$(jqs '.artifacts.tasks? // "" | strings' "$1")"
  if [ -n "$tf" ] && [ -f "$tf" ]; then TASKS_REL="$(repo_rel "$tf")"; fi
}

# inside_feature <path> — K's rule: a path is inside a root when it equals the
# root or begins with the root and `/`, the root first stripped of a leading
# `./` and a trailing `/`; a root that is then `.` or empty holds every path.
# The spec directory and tasks.md are inside too.
inside_feature() {
  local p="$1" r
  if [ -n "$TASKS_REL" ] && [ "$p" = "$TASKS_REL" ]; then return 0; fi
  if [ -n "$SPEC_DIR" ]; then
    case "$p" in "$SPEC_DIR"*) return 0 ;; esac
  fi
  for r in ${ROOT_LIST[@]+"${ROOT_LIST[@]}"}; do
    if [ -z "$r" ] || [ "$r" = . ] || [ "$p" = "$r" ]; then return 0; fi
    case "$p" in "$r"/*) return 0 ;; esac
  done
  return 1
}

# The two files a pre-flight offer may write. An accepted offer is recorded as
# gates.<name> = {accepted: true, hash: <git hash-object of the file it
# wrote>}; anything else — a declined offer, a string, "true" written as a
# string — is no accepted offer.
CONSTITUTION=".specify/memory/constitution.md"
offer_gate() {
  case "$1" in
    "$CONSTITUTION") printf 'constitution' ;;
    .gitignore) printf 'gitignore' ;;
    *) return 1 ;;
  esac
}
offer_hash() {
  # shellcheck disable=SC2016 # a jq program: $g is jq's
  jqs --arg g "$1" '.gates[$g]? | if type == "object" and .accepted == true and (.hash | type) == "string" then .hash else "" end' "$sf"
}
offer_accepted() { [ -n "$(offer_hash "$1")" ]; }

# offer_matches <path> [<commit>] — the change to <path> is exactly what its
# accepted offer wrote: the file, as <commit> holds it or as it stands now,
# hashes to the recorded hash. A file that is gone matches nothing.
offer_matches() {
  local g want h
  g="$(offer_gate "$1")" || return 1
  want="$(offer_hash "$g")"
  [ -n "$want" ] || return 1
  if [ -n "${2:-}" ]; then
    h="$(git rev-parse --verify --quiet "$2:$1" 2>/dev/null)" || return 1
  else
    [ -f "$1" ] || return 1
    h="$(git hash-object -- "$1" 2>/dev/null)" || return 1
  fi
  [ "$h" = "$want" ]
}

# mark_of <path> [<commit>] — MARK: `-` inside the feature or `!` outside it,
# as K reads it. A path under the state directory is outside. A change to the
# constitution or .gitignore is inside only when it is exactly what an
# accepted pre-flight offer wrote, wherever codeRoots reach. Sets a variable
# rather than printing through `$( )`, which cost a process a path.
mark_of() {
  if in_state_dir "$1"; then MARK='!'; return 0; fi
  if offer_gate "$1" > /dev/null; then
    if offer_matches "$1" "${2:-}"; then MARK='-'; else MARK='!'; fi
    return 0
  fi
  if inside_feature "$1"; then MARK='-'; else MARK='!'; fi
}

# A piece's task ids, and the ones not yet marked [X], walked exactly as
# piece-next walks the tasks file. One line: ok<US>ids<US>open, or none.
# shellcheck disable=SC2016 # a jq program: $t, $h, $l and $c are jq's
SECTION_JQ='
  (reduce ($t | split("\n")[] | rtrimstr("\r")) as $l ([];
    if ($l | startswith("## ")) then
      . + [if ($l | test("^## Phase [0-9]+[a-z]*:"))
           then {h: ($l | ltrimstr("## ")), ids: [], open: []} else null end]
    elif length > 0 and .[length-1] != null then
      [$l | capture("^- \\[(?<m>[ xX])\\] (?<id>T[0-9]+)")] as $c
      | .[length-1].ids += [$c[].id]
      | .[length-1].open += [$c[] | select(.m == " ") | .id]
    else . end))
  | [.[] | select(. != null and .h == $h)] | first
  | if . == null then "none"
    else "ok\u001f" + (.ids | join(",")) + "\u001f" + (.open | join(",")) end'

# section_of <state file> <heading> — SEC_IDS and SEC_OPEN for that piece.
section_of() {
  local tf r rest
  tf="$(jqs '.artifacts.tasks // empty' "$1")"
  if [ -z "$tf" ] || [ ! -f "$tf" ]; then
    die "the run's tasks file (artifacts.tasks) is not recorded, or not found: '$tf'"
  fi
  r="$(jqs -n --rawfile t "$tf" --arg h "$2" "$SECTION_JQ")"
  case "${r%%$'\x1f'*}" in
    ok) rest="${r#*$'\x1f'}"; SEC_IDS="${rest%%$'\x1f'*}"; SEC_OPEN="${rest#*$'\x1f'}" ;;
    *)  return 1 ;;
  esac
}

# msg_body <file> — the message the orchestrator wrote, checked: it exists,
# is not blank, holds no CR, and has no Piece:, Late: or Tasks: line of its
# own — this script writes those lines, from data, and a second one would
# be matched by the crash scans.
msg_body() {
  local m line
  [ -f "$1" ] || die "message file not found: $1"
  # Counted from the file's bytes: Git Bash's `$( )` strips a CR, so a check
  # on the captured text would pass on Windows and refuse elsewhere.
  if [ "$(tr -cd '\r' < "$1" | wc -c)" -ne 0 ]; then
    die "the message file $1 holds a carriage return: write it with LF line endings"
  fi
  m="$(cat -- "$1")"
  [[ $m == *[![:space:]]* ]] || die "the message file $1 is empty"
  while IFS= read -r line; do
    case "$line" in 'Piece: '*|'Late: '*|'Tasks: '*)
      die "the message file $1 carries a '${line%%:*}:' line of its own; this command writes that line itself" ;;
    esac
  done < <(printf '%s\n' "$m")
  MSG="$m"
}

# nul_file <file> <paths...> — the paths NUL-separated, or an EMPTY file for
# none: `printf '%s\0'` with no argument would write one empty path instead.
nul_file() {
  local f="$1"; shift
  if [ $# -gt 0 ]; then printf '%s\0' "$@" > "$f"; else : > "$f"; fi
}

# with_trailers <message file> — the run's commit trailers, added to a copy
# of the message. The list is the state file's config.commitTrailers: an
# array of `<token>: <value>` strings the orchestrator recorded from
# pre-flight's report. It is read as data, never typed into a command, and
# every entry passes trailer-check.sh. Sets MF to the file to commit: the message
# file itself when the run records no trailer, else the copy under the run
# directory, so a caller's own file is never rewritten. Every caller sets sf
# and RD first. The lines are appended here, not by git interpret-trailers:
# git's trailer.* configuration can rename a token (trailer.<x>.key) or run
# a command (trailer.<x>.cmd), so no git setting may touch them. A message
# whose last paragraph, after the subject, is all `<token>: <value>` lines
# gets the trailers joined to it; any other message gets a blank line first.
# A trailer is not added when the same line is already in that block or
# earlier in the list. show-message prints the result K shows.
with_trailers() {
  local n i j t r l m block=0 LC_ALL=C TR=() HAVE=() last=() seen
  MF="$1"
  n="$(jqs '.config.commitTrailers? // [] | if type == "array" and all(.[]; type == "string" and length > 0) then length else "bad" end' "$sf")" \
    || die "$sf could not be read for config.commitTrailers — no commit is made"
  [ "$n" != bad ] || die "$sf: config.commitTrailers must be an array of non-empty strings — no commit is made"
  [ "$n" -gt 0 ] || return 0
  # Each entry goes to trailer-check.sh as JSON, so a CR or NUL inside it
  # is seen there rather than stripped by jqs on the way. Its error file and
  # the message copy are this call's own (mktemp): a show-message during a
  # commit of the same run must not swap the message git commits.
  TR_ERR="$(mktemp "$RD/trailer-check.XXXXXX")" || die "could not make a temporary file in $RD — no commit is made"
  i=0
  while [ "$i" -lt "$n" ]; do
    j="$(jq ${JQB:+"$JQB"} -c --argjson i "$i" '.config.commitTrailers[$i]' "$sf")" \
      || die "$sf could not be read for config.commitTrailers — no commit is made"
    j="${j%$'\r'}"
    t="$("$BASH" "$SCRIPT_DIR/trailer-check.sh" "$j" 2>"$TR_ERR")" \
      || { r="$(cat -- "$TR_ERR")"; die "the recorded trailer $r — no commit is made"; }
    TR+=("$t"); i=$((i + 1))
  done
  # The message without its trailing blank lines; the last paragraph, when
  # it is not the subject's, is a trailer block if every line is shaped so.
  m="$(cat -- "$1")" || die "could not read the message $1 — no commit is made"
  while IFS= read -r l || [ -n "$l" ]; do
    case "$l" in *[![:space:]]*) last+=("$l") ;; *) last=(); seen=1 ;; esac
  done < <(printf '%s\n' "$m")
  if [ "${seen:-0}" = 1 ] && [ "${#last[@]}" -gt 0 ]; then
    block=1
    for l in "${last[@]}"; do
      case "${l%%: *}" in
        "$l"|""|*[!A-Za-z0-9-]*|[!A-Za-z]*) block=0; break ;;
      esac
    done
  fi
  if [ "$block" = 1 ]; then HAVE=("${last[@]}"); fi
  TR_MSG="$(mktemp "$RD/trailers-msg.XXXXXX")" || die "could not make a temporary file in $RD — no commit is made"
  MF="$TR_MSG"
  {
    printf '%s\n' "$m"
    i=0
    for t in "${TR[@]}"; do
      for l in ${HAVE[@]+"${HAVE[@]}"}; do [ "$l" != "$t" ] || continue 2; done
      if [ "$i" = 0 ] && [ "$block" = 0 ]; then printf '\n'; fi
      printf '%s\n' "$t"; HAVE+=("$t"); i=1
    done
  } > "$MF" || die "could not write the message copy $MF — no commit is made"
}

# commit_named <path file> <message file> — stage and commit exactly the
# named paths, the message carrying the run's trailers (with_trailers). A commit is never run from an empty path file: with no
# pathspec, git commits whatever is already staged (measured). A hook that
# rejects the commit stops here; --no-verify is never passed.
commit_named() {
  [ -s "$1" ] || die "the path list is empty — a commit from an empty path file takes whatever is already staged, so no commit is made"
  with_trailers "$2"
  git --literal-pathspecs add --pathspec-from-file="$1" --pathspec-file-nul >&2 \
    || die "git add refused the paths in $1 — nothing committed"
  git --literal-pathspecs commit -q --cleanup=verbatim -F "$MF" --pathspec-from-file="$1" --pathspec-file-nul >&2 \
    || die "the commit was rejected (a commit hook?) — nothing is committed or recorded, and the paths in $1 stay uncommitted"
  SHA="$(git rev-parse HEAD)"
}

# state_write <state file> <jq program> [jq options...] — a whole-file write:
# into a temp file, validated there, then moved over the state file. On any
# failure the old file stands as it was.
# state_lock <state file> — one writer at a time. Every write to a state file
# happens while this process holds <file>.lock, a directory, because mkdir
# either makes it or fails, on every system. A second call while this
# process holds it does nothing, so a command can hold it across its own
# read and write. A lock older than a minute belongs to a writer that died —
# no write takes that long — so it is broken, and that is said.
# PROGRESS_LOCK_TRIES bounds the wait, in tenths of a second (default 100).
state_lock() {
  local l="$1.lock" n=0 max="${PROGRESS_LOCK_TRIES:-100}"
  [ "${STATE_LOCK:-}" != "$l" ] || return 0
  case "$max" in ''|*[!0-9]*) max=100 ;; esac
  until mkdir "$l" 2>/dev/null; do
    if [ -n "$(find "$l" -maxdepth 0 -mmin +1 2>/dev/null)" ] && rmdir "$l" 2>/dev/null; then
      warn "broke a stale lock on $1: its writer has not run for over a minute"
      continue
    fi
    n=$((n + 1))
    [ "$n" -le "$max" ] || die "$1 is locked by another write ($l): if no other progress.sh is running, remove that directory"
    sleep 0.1
  done
  STATE_LOCK="$l"
  # A subshell does not run its parent's EXIT trap, and the commit commands
  # record from one: arm it here too, so a die inside lets go of the lock.
  trap on_exit EXIT
}
state_unlock() {
  if [ -n "${STATE_LOCK:-}" ]; then rmdir "$STATE_LOCK" 2>/dev/null || true; STATE_LOCK=''; fi
}

# state_write <state file> <jq program> [jq args] — the program's output
# replaces the state file, read and written under the lock, through a
# temporary file of this write's own, and only when it validates.
state_write() {
  local f="$1" prog="$2" tmp held=0
  shift 2
  if [ "${STATE_LOCK:-}" = "$f.lock" ]; then held=1; fi
  state_lock "$f"
  tmp="$(mktemp "$f.XXXXXX")" || die "could not make a temporary file beside $f — the state file is unchanged"
  if ! jq ${JQB:+"$JQB"} "$@" "$prog" "$f" > "$tmp"; then rm -f "$tmp"; die "the write to $f failed — the state file is unchanged"; fi
  if ! ( validate_file "$tmp" ) > /dev/null; then rm -f "$tmp"; die "the write would leave $f invalid — the state file is unchanged"; fi
  mv "$tmp" "$f"
  if [ "$held" -eq 0 ]; then state_unlock; fi
}

piece_saved() {
  # shellcheck disable=SC2016 # a jq program: its $ names are jq's
  [ "$(jqs --arg h "$2" '.measurements.pieceBefore.piece? == $h' "$1" 2>/dev/null)" = true ]
}

# The current piece, from piece-next: HEADING and IDS, as data. Empty HEADING
# when every piece is recorded.
next_piece() {
  local pn
  pn="$(cmd_piece_next "$1")" || exit 1
  HEADING="${pn%%$'\n'*}"; IDS="${pn#*$'\n'}"
  [ -n "$pn" ] || { HEADING=''; IDS=''; }
}

# built_or_die <commit> <heading> — a `Piece:` line read from a commit on the
# branch is recorded only for a section of the tasks file whose every task is
# marked [X]: the rule piece-commit holds its own commits to. A message is
# data; without this a hand commit naming a piece marked it done, with its
# tasks still open (measured). Sets SEC_IDS.
built_or_die() {
  section_of "$sf" "$2" \
    || die "commit $1 carries 'Piece: $2', which is not a section of the tasks file: not recorded, and this stops the run"
  [ -z "$SEC_OPEN" ] \
    || die "commit $1 carries 'Piece: $2', but task(s) $SEC_OPEN not marked [X] in the tasks file: not recorded, and this stops the run"
}

# h5_piece_or_die <commit> <heading> — a `Late: H.5` commit's `Piece:` line
# must also be the piece piece-next names, as converge's own commit is.
h5_piece_or_die() {
  built_or_die "$1" "$2"
  local ids="$SEC_IDS"
  next_piece "$feature"
  [ "$2" = "$HEADING" ] \
    || die "commit $1 carries 'Piece: $2', which is not the piece piece-next names ('$HEADING'): not recorded, and this stops the run"
  SEC_IDS="$ids"
}

# recover_piece — a commit in <base>..HEAD that no entry records and that
# carries `Piece: <HEADING>` as a whole line was made before a crash: record
# it from that commit (kind converge when it also carries `Late: H.5`) and
# print its id. It is never built or committed again.
recover_piece() {
  local list c msg kind
  list="$(unrecorded "$sf" "$base")"
  for c in $list; do
    msg="$(git log -1 --format=%B "$c")"
    has_line "$msg" "Piece: $HEADING" || continue
    built_or_die "$c" "$HEADING"
    kind=piece
    if has_line "$msg" 'Late: H.5'; then kind=converge; fi
    commit_files "$c"
    ( cmd_commit_add "$feature" --files-from "$RD/diff-tree.nul" "$kind" "$c" "$HEADING" "$IDS" )
    warn "the piece '$HEADING' is already committed in $c, which no entry recorded: recorded it from that commit as kind $kind — it is not built or committed again"
    printf '%s\n' "$c"
    return 0
  done
  return 1
}

# recover_late — the same for a late phase: an unrecorded commit carrying
# `Late: <phase>` is recorded from that commit, never made again.
recover_late() {
  local list c msg h i
  list="$(unrecorded "$sf" "$base")"
  for c in $list; do
    msg="$(git log -1 --format=%B "$c")"
    has_line "$msg" "Late: $phase" || continue
    h=''; i=''
    if [ "$phase" = H.5 ] && h="$(piece_of "$msg")"; then
      h5_piece_or_die "$c" "$h"; i="$SEC_IDS"
    else
      h=''
    fi
    commit_files "$c"
    ( cmd_commit_add "$feature" --files-from "$RD/diff-tree.nul" "$kind" "$c" "$h" "$i" )
    warn "phase $phase already committed $c, which no entry recorded: recorded it from that commit as kind $kind — it is not made again"
    printf '%s\n' "$c"
    return 0
  done
  return 1
}

# piece_paths <state file> — PP: the paths git status lists now that are
# absent from measurements.pieceBefore, never one under the state directory,
# plus the tasks file.
piece_paths() {
  local before tf rec p have=0
  before="$(jqs '.measurements.pieceBefore.paths[]? | strings' "$1")"
  tf="$(repo_rel "$(jqs '.artifacts.tasks' "$1")")"
  status_to "$RD/piece-after.nul"
  PP=()
  while IFS= read -r -d '' rec; do
    p="${rec:3}"
    path_ok "$p"
    if in_state_dir "$p"; then continue; fi
    if has_line "$before" "$p"; then continue; fi
    if [ "$p" = "$tf" ]; then have=1; fi
    PP+=("$p")
  done < "$RD/piece-after.nul"
  if in_state_dir "$tf"; then have=1; fi
  if [ "$have" -eq 0 ]; then PP+=("$tf"); fi
}

# hash_of <path> — `git hash-object`, or `deleted` for a path that is gone.
hash_of() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    git hash-object -- "$1" 2>/dev/null || printf 'unhashable'
  else
    printf 'deleted'
  fi
}

# hash_paths — HH: a hash for each path in HP, in order, as hash_of gives it:
# `git hash-object`, `deleted` for a path that is gone, or `unhashable` (a
# directory, a dangling link). ONE git process hashes them all: a process a
# path cost about 0.1 s a path on Windows, 104 s for 1,000 (measured). The
# list is one path a line, safe because path_ok has refused CR and LF; a path
# starting with a double quote is hashed alone, because --stdin-paths would
# unquote it. Should the one process fail, each path is hashed alone, as
# before.
hash_paths() {
  local i=0 n="${#HP[@]}" p h
  local -a want
  HH=(); want=()
  while [ "$i" -lt "$n" ]; do
    p="${HP[$i]}"
    if [ -d "$p" ] || { [ -L "$p" ] && [ ! -e "$p" ]; }; then HH[i]=unhashable
    elif [ ! -e "$p" ]; then HH[i]=deleted
    else
      case "$p" in '"'*) HH[i]="$(hash_of "$p")" ;; *) HH[i]=''; want+=("$i") ;; esac
    fi
    i=$((i + 1))
  done
  [ "${#want[@]}" -gt 0 ] || return 0
  for i in "${want[@]}"; do printf '%s\n' "${HP[$i]}"; done > "$RD/hash-in.txt"
  local -a got
  got=()
  if git hash-object --stdin-paths < "$RD/hash-in.txt" > "$RD/hash-out.txt" 2>/dev/null; then
    while IFS= read -r h; do got+=("${h%$'\r'}"); done < "$RD/hash-out.txt"
  fi
  if [ "${#got[@]}" -eq "${#want[@]}" ]; then
    n=0
    for i in "${want[@]}"; do HH[i]="${got[$n]}"; n=$((n + 1)); done
  else
    for i in "${want[@]}"; do HH[i]="$(hash_of "${HP[$i]}")"; done
  fi
}

# late_paths <state file> — LP: the paths git status lists now that are absent
# from measurements.lateBefore or whose content changed since it was saved,
# less any untracked path outside the feature, which stays for K, and never
# one under the state directory.
late_paths() {
  local map rec p i=0 n
  local -a st
  map="$(jqs '.measurements.lateBefore.paths[]? | objects | "\(.hash) \(.path)"' "$1")"
  feature_bounds "$1"
  status_to "$RD/late-after.nul"
  HP=(); st=()
  while IFS= read -r -d '' rec; do
    p="${rec:3}"
    path_ok "$p"
    if in_state_dir "$p"; then continue; fi
    HP+=("$p"); st+=("${rec:0:2}")
  done < "$RD/late-after.nul"
  LP=()
  n="${#HP[@]}"
  [ "$n" -gt 0 ] || return 0
  hash_paths
  while [ "$i" -lt "$n" ]; do
    p="${HP[$i]}"
    if has_line "$map" "${HH[$i]} $p"; then
      :
    elif [ "${st[$i]}" = '??' ] && ! inside_feature "$p"; then
      warn "left uncommitted for K (untracked, outside codeRoots, the spec directory and tasks.md): $p"
    else
      LP+=("$p")
    fi
    i=$((i + 1))
  done
}

# --- snapshot -----------------------------------------------------------------
# snapshot <feature> piece — saves measurements.pieceBefore for the piece
# piece-next names: every path git status lists, with the piece's heading.
# snapshot <feature> late <phase> [--fresh] — saves measurements.lateBefore:
# every path with its hash. A list already saved for that piece or phase
# stands (a resume compares against it); --fresh saves a late list afresh,
# for a --from, less the paths gates.<phase>.failure.paths names. A piece
# found already committed is recorded instead, and its id printed: it must
# not be built again.
cmd_snapshot() {
  feature="$1"; what="${2:-}"
  sf="$(cmd_validate "$feature")"
  need_git_top
  RD="$(run_dir "$feature")"
  local rec p n=0 phase fresh
  case "$what" in
    piece)
      [ $# -eq 2 ] || die "usage: snapshot <feature> piece — the heading comes from piece-next, never typed"
      commits_ok "$sf"
      next_piece "$feature"
      [ -n "$HEADING" ] || die "piece-next names no piece: every piece is recorded, so there is nothing to build"
      base="$(base_of "$sf")"
      if recover_piece; then return 0; fi
      if piece_saved "$sf" "$HEADING"; then
        warn "measurements.pieceBefore already names '$HEADING': the saved list stands"
        return 0
      fi
      status_to "$RD/piece-before.nul"
      while IFS= read -r -d '' rec; do
        p="${rec:3}"; path_ok "$p"
        printf '%s\n' "$p"; n=$((n + 1))
      done < "$RD/piece-before.nul" > "$RD/piece-before.txt"
      # shellcheck disable=SC2016 # a jq program: its $ names are jq's
      state_write "$sf" '.measurements.pieceBefore = {piece: $h, paths: ($p | split("\n") | map(select(length > 0)))}' \
        --arg h "$HEADING" --rawfile p "$RD/piece-before.txt"
      warn "saved measurements.pieceBefore for '$HEADING': $n paths"
      ;;
    late)
      phase="${3:-}"; fresh="${4:-}"
      kind="$(kind_of_phase "$phase")" || die "snapshot late needs a late phase: H.5, H.7, I or J (got '$phase')"
      case "$fresh" in ''|--fresh) ;; *) die "unknown option '$fresh' (only --fresh)" ;; esac
      [ $# -le 4 ] || die "usage: snapshot <feature> late <phase> [--fresh]"
      commits_ok "$sf"
      base="$(base_of "$sf")"
      # A re-entered late phase finds its own commit first: one made before a
      # crash is recorded from that commit, its id printed, never made again.
      if recover_late; then return 0; fi
      if [ -z "$fresh" ] && [ "$(jqs '.measurements.lateBefore.phase? // ""' "$sf")" = "$phase" ]; then
        warn "measurements.lateBefore already names $phase: the saved list stands"
        return 0
      fi
      local skip=''
      if [ -n "$fresh" ]; then
        # shellcheck disable=SC2016 # a jq program: its $ names are jq's
        skip="$(jqs --arg p "$phase" '.gates[$p].failure.paths? // [] | .[]? | strings' "$sf")"
      fi
      status_to "$RD/late-before.nul"
      HP=()
      while IFS= read -r -d '' rec; do
        p="${rec:3}"; path_ok "$p"
        if has_line "$skip" "$p"; then continue; fi
        HP+=("$p")
      done < "$RD/late-before.nul"
      n="${#HP[@]}"
      : > "$RD/late-before.txt"
      if [ "$n" -gt 0 ]; then
        hash_paths
        local i=0
        while [ "$i" -lt "$n" ]; do
          printf '%s %s\n' "${HH[$i]}" "${HP[$i]}"; i=$((i + 1))
        done > "$RD/late-before.txt"
      fi
      # shellcheck disable=SC2016 # a jq program: its $ names are jq's
      state_write "$sf" '.measurements.lateBefore = {phase: $ph, paths: [$p | split("\n")[] | select(length > 0) | capture("^(?<hash>[^ ]+) (?<path>.*)$")]}' \
        --arg ph "$phase" --rawfile p "$RD/late-before.txt"
      warn "saved measurements.lateBefore for $phase: $n paths"
      ;;
    *) die "snapshot needs 'piece', or 'late <phase>'" ;;
  esac
}

# --- spec-commit --------------------------------------------------------------
# The feature's spec directory, alone, as `docs(spec): <feature>`, recorded as
# kind spec. Never made twice: a recorded spec commit stands, and one already
# on the branch under that subject is recorded from that commit. A spec
# directory the owner committed already makes no commit. A recorded artefact
# git ignores is a hard failure; any other ignored file is left alone.
cmd_spec_commit() {
  feature="$1"
  [ $# -eq 1 ] || die "usage: spec-commit <feature>"
  sf="$(cmd_validate "$feature")"
  need_git_top
  RD="$(run_dir "$feature")"
  commits_ok "$sf"
  base="$(base_of "$sf")"
  local spec sd list c msg arts a ign rec p r
  if jq -e 'any(.commits[]?; type == "object" and .kind == "spec")' "$sf" >/dev/null; then
    warn "a spec commit is already recorded: it is not made again"
    return 0
  fi
  list="$(unrecorded "$sf" "$base")"
  for c in $list; do
    msg="$(git log -1 --format=%B "$c")"
    [ "${msg%%$'\n'*}" = "docs(spec): $feature" ] || continue
    commit_files "$c"
    ( cmd_commit_add "$feature" --files-from "$RD/diff-tree.nul" spec "$c" "" "" )
    warn "the spec commit $c is on the branch but was not recorded: recorded it from that commit — it is not made again"
    printf '%s\n' "$c"
    return 0
  done
  spec="$(jqs '.artifacts.spec? // "" | strings' "$sf")"
  if [ -z "$spec" ] || [ ! -e "$spec" ]; then die "$sf records no spec that exists (artifacts.spec: '$spec')"; fi
  case "$spec" in */*) sd="$(dir_rel "${spec%/*}")" ;; *) sd="$(dir_rel .)" ;; esac
  [ -n "$sd" ] || die "the spec sits at the repository's top level: there is no spec directory to commit alone"
  # A recorded artefact that git ignores could never be committed: name it.
  arts=''
  while IFS= read -r a; do
    if [ -n "$a" ] && [ -f "$a" ] && r="$(repo_rel "$a" 2>/dev/null)"; then arts="$arts$r"$'\n'; fi
  done < <(jqs '.artifacts? // {} | .[]? | strings' "$sf"; printf '\n')
  git --literal-pathspecs ls-files -o -i --exclude-standard -z -- "$sd" > "$RD/spec-ignored.nul" \
    || die "git ls-files failed on $sd"
  while IFS= read -r -d '' ign; do
    if has_line "$arts" "$ign"; then
      die "the recorded artefact $ign is ignored by git, so the spec commit cannot hold it — a hard failure"
    fi
  done < "$RD/spec-ignored.nul"
  status_to "$RD/spec-status.nul" "$sd"
  SP=()
  while IFS= read -r -d '' rec; do
    p="${rec:3}"; path_ok "$p"
    if in_state_dir "$p"; then continue; fi
    SP+=("$p")
  done < "$RD/spec-status.nul"
  if [ "${#SP[@]}" -eq 0 ]; then
    if [ -n "$(git --literal-pathspecs ls-files -- "$sd")" ]; then
      warn "the spec directory $sd is committed already and nothing in it is uncommitted: no spec commit is made"
      return 0
    fi
    die "the spec directory $sd holds no file to commit"
  fi
  nul_file "$RD/spec-paths.nul" "${SP[@]}"
  printf 'docs(spec): %s\n' "$feature" > "$RD/spec-msg.txt"
  commit_named "$RD/spec-paths.nul" "$RD/spec-msg.txt"
  ( cmd_commit_add "$feature" --files-from "$RD/spec-paths.nul" spec "$SHA" "" "" ) \
    || die "commit $SHA is made but not recorded — run record-branch $feature"
  warn "committed the spec directory as $SHA: ${#SP[@]} paths"
  printf '%s\n' "$SHA"
}

# --- piece-commit -------------------------------------------------------------
# piece-commit <feature> <message-file> — commits the piece piece-next names:
# the paths git status lists that are absent from measurements.pieceBefore,
# plus tasks.md, never a path under the state directory. Every task of the
# piece must be marked [X]. The message is the file's text, then a
# `Tasks: <ids>` and a `Piece: <heading>` line written from piece-next's own
# output. Records the commit as kind piece and prints its id.
# piece-commit <feature> --list — prints those paths and commits nothing.
cmd_piece_commit() {
  feature="$1"; local mf="${2:-}"
  if [ $# -ne 2 ] || [ -z "$mf" ]; then die "usage: piece-commit <feature> <message-file|--list>"; fi
  sf="$(cmd_validate "$feature")"
  need_git_top
  RD="$(run_dir "$feature")"
  commits_ok "$sf"
  next_piece "$feature"
  [ -n "$HEADING" ] || die "piece-next names no piece: every piece is recorded, so there is nothing to commit"
  if [ "$mf" != --list ]; then msg_body "$mf"; fi
  base="$(base_of "$sf")"
  if recover_piece; then return 0; fi
  piece_saved "$sf" "$HEADING" \
    || die "measurements.pieceBefore does not name '$HEADING': run snapshot $feature piece when the piece starts, before it is built"
  section_of "$sf" "$HEADING" || die "the piece '$HEADING' is not in the tasks file"
  [ -z "$SEC_OPEN" ] || die "the piece '$HEADING' is not built: task(s) $SEC_OPEN not marked [X] in the tasks file"
  piece_paths "$sf"
  if [ "$mf" = --list ]; then
    if [ "${#PP[@]}" -gt 0 ]; then printf '%s\n' "${PP[@]}"; fi
    return 0
  fi
  nul_file "$RD/piece-paths.nul" ${PP[@]+"${PP[@]}"}
  printf '%s\n\nTasks: %s\nPiece: %s\n' "$MSG" "$IDS" "$HEADING" > "$RD/piece-msg.txt"
  commit_named "$RD/piece-paths.nul" "$RD/piece-msg.txt"
  ( cmd_commit_add "$feature" --files-from "$RD/piece-paths.nul" piece "$SHA" "$HEADING" "$IDS" ) \
    || die "commit $SHA is made but not recorded — run record-branch $feature"
  warn "committed the piece '$HEADING' as $SHA: ${#PP[@]} paths"
  printf '%s\n' "$SHA"
}

# --- late-commit --------------------------------------------------------------
# late-commit <feature> <phase> <message-file> — one late commit for H.5, H.7,
# I or J, kind converge, simplify, review or tests: the paths changed since
# measurements.lateBefore (see late_paths). The message is the file's text,
# then `Late: <phase>`; H.5 adds `Tasks:` and `Piece:` lines for the phase
# converge appended, as piece-next names it. A phase that changed no file
# makes no commit and says so.
# late-commit <feature> J <message-file> --record — J's empty record commit
# of a waved-through red: no path, kind tests, never twice on the branch.
# late-commit <feature> <phase> --list — prints the paths, commits nothing.
cmd_late_commit() {
  feature="$1"; phase="${2:-}"; local mf="${3:-}" flag="${4:-}" saved c list
  kind="$(kind_of_phase "$phase")" || die "late-commit needs a late phase: H.5, H.7, I or J (got '$phase')"
  if [ $# -gt 4 ] || [ -z "$mf" ]; then die "usage: late-commit <feature> <phase> <message-file|--list> [--record]"; fi
  case "$flag" in ''|--record) ;; *) die "unknown option '$flag' (only --record)" ;; esac
  if [ -n "$flag" ] && [ "$phase" != J ]; then die "--record makes J's empty record commit: it is for phase J only"; fi
  if [ -n "$flag" ] && [ "$mf" = --list ]; then die "--record makes a commit; it does not go with --list"; fi
  sf="$(cmd_validate "$feature")"
  need_git_top
  RD="$(run_dir "$feature")"
  commits_ok "$sf"
  base="$(base_of "$sf")"
  if [ "$mf" != --list ]; then msg_body "$mf"; fi
  if recover_late; then return 0; fi
  saved="$(jqs '.measurements.lateBefore.phase? // "" | strings' "$sf")"
  HEADING=''; IDS=''
  if [ "$flag" = --record ]; then
    list="$(git rev-list --first-parent "$base..HEAD")" || die "git rev-list could not read $base..HEAD"
    for c in $list; do
      if has_line "$(git log -1 --format=%B "$c")" 'Late: J'; then
        # recover_late has recorded any such commit by now: a re-entered J
        # finds its record made, and answers with its id, as spec-commit does.
        # shellcheck disable=SC2016 # a jq program: $s is jq's
        if jq -e --arg s "$c" 'any(.commits[]?; type == "object" and .sha == $s)' "$sf" >/dev/null; then
          warn "J's record is already made and recorded as $c: it is not made again"
          printf '%s\n' "$c"
          return 0
        fi
        die "commit $c already carries 'Late: J': the record reaches a commit exactly once"
      fi
    done
    if [ "$saved" = J ]; then
      late_paths "$sf"
      [ "${#LP[@]}" -eq 0 ] || die "J changed files: the record rides in J's own late commit — run without --record"
    fi
    j_record_msg "$RD/late-msg.txt"
    with_trailers "$RD/late-msg.txt"
    git commit -q --allow-empty --only --cleanup=verbatim -F "$MF" >&2 \
      || die "the record commit was rejected (a commit hook?) — nothing is committed or recorded"
    SHA="$(git rev-parse HEAD)"
    ( cmd_commit_add "$feature" tests "$SHA" "" "" ) \
      || die "commit $SHA is made but not recorded — run record-branch $feature"
    warn "made J's empty record commit $SHA"
    printf '%s\n' "$SHA"
    return 0
  fi
  [ "$saved" = "$phase" ] \
    || die "measurements.lateBefore does not name $phase: run snapshot $feature late $phase when the phase starts"
  if [ "$phase" = H.5 ]; then
    next_piece "$feature"
    if [ -n "$HEADING" ]; then
      section_of "$sf" "$HEADING" || die "the piece '$HEADING' is not in the tasks file"
      [ -z "$SEC_OPEN" ] || die "converge's phase '$HEADING' is not built: task(s) $SEC_OPEN not marked [X] in the tasks file"
    fi
  fi
  late_paths "$sf"
  if [ "$mf" = --list ]; then
    if [ "${#LP[@]}" -gt 0 ]; then printf '%s\n' "${LP[@]}"; fi
    return 0
  fi
  if [ "${#LP[@]}" -eq 0 ]; then
    warn "$phase changed no file: no late commit is made"
    return 0
  fi
  nul_file "$RD/late-paths.nul" "${LP[@]}"
  {
    printf '%s\n\n' "$MSG"
    if [ -n "$HEADING" ]; then printf 'Tasks: %s\nPiece: %s\n' "$IDS" "$HEADING"; fi
    printf 'Late: %s\n' "$phase"
  } > "$RD/late-msg.txt"
  commit_named "$RD/late-paths.nul" "$RD/late-msg.txt"
  ( cmd_commit_add "$feature" --files-from "$RD/late-paths.nul" "$kind" "$SHA" "$HEADING" "$IDS" ) \
    || die "commit $SHA is made but not recorded — run record-branch $feature"
  warn "committed $phase as $SHA (kind $kind): ${#LP[@]} paths"
  printf '%s\n' "$SHA"
}

# --- record-branch ------------------------------------------------------------
# Records, oldest first and each before the next, every first-parent commit
# in <base>..HEAD that commits does not record, with its files read as K
# reads them: `Late: H.5` as converge (the heading of its Piece: line and
# that phase's task ids); a whole-line `Piece: <heading>` for the heading
# piece-next then names as piece; `Late: <phase>` under that phase's kind;
# the subject `docs(spec): <feature>` as spec; any other as other. Stops on a
# Piece: line for any other heading, and on a commit with no file and no
# `Late: J` line. Prints the ids it recorded.
cmd_record_branch() {
  feature="$1"
  [ $# -le 2 ] || die "usage: record-branch <feature> [<base>]"
  sf="$(cmd_validate "$feature")"
  need_git_top
  RD="$(run_dir "$feature")"
  commits_ok "$sf"
  base="$(base_of "$sf" "${2:-}")"
  local list c msg late h ids k hasp out='' n=0
  list="$(unrecorded "$sf" "$base")"
  for c in $list; do
    msg="$(git log -1 --format=%B "$c")"
    commit_files "$c"
    late="$(late_of "$msg")" || late=''
    hasp=0; h=''
    if h="$(piece_of "$msg")"; then hasp=1; else h=''; fi
    if [ "${#CF[@]}" -eq 0 ] && [ "$late" != J ]; then
      die "commit $c has no file and no 'Late: J' line: it cannot be shown, so it is not recorded and this stops the run ($n recorded before it)"
    fi
    ids=''
    if [ "$late" = H.5 ]; then
      k=converge
      if [ "$hasp" -eq 1 ]; then h5_piece_or_die "$c" "$h"; ids="$SEC_IDS"; fi
    elif [ "$hasp" -eq 1 ]; then
      next_piece "$feature"
      if [ "$HEADING" != "$h" ]; then
        die "commit $c carries 'Piece: $h', which is not the piece piece-next names ('$HEADING'): not recorded, and this stops the run ($n recorded before it)"
      fi
      built_or_die "$c" "$h"
      k=piece; ids="$IDS"
    elif [ -n "$late" ]; then
      k="$(kind_of_phase "$late")"; h=''
    elif [ "${msg%%$'\n'*}" = "docs(spec): $feature" ]; then
      k=spec; h=''
    else
      k=other; h=''
    fi
    ( cmd_commit_add "$feature" --files-from "$RD/diff-tree.nul" "$k" "$c" "$h" "$ids" )
    out="$out$c"$'\n'; n=$((n + 1))
    warn "recorded $c as kind $k"
  done
  printf '%s' "$out"
}

# --- guide --------------------------------------------------------------------
# The review guide: one row per first-parent commit in <base>..HEAD, oldest
# first, joined by its id to its commits entry. A piece name or path is a code
# span fenced by one more backtick than its longest run of backticks, with a
# space inside the fence when the value begins or ends with one; `|` is `\|`.
# The branch's ids arrive as a file ($b, one a line), never as arguments: past
# about 780 commits they would pass a native Windows jq's command-line limit.
# The first line is "ok", then each row's size in bytes, newline included,
# so --parts splits without a process a row.
# shellcheck disable=SC2016 # a jq program: $mode, $b, $e, $v and $lines are jq's
GUIDE_JQ='
  def span: . as $v
    | ("`" * (([$v | scan("`+") | length] | max // 0) + 1)) as $f
    | (if ($v | startswith("`")) or ($v | endswith("`")) then " " else "" end) as $pad
    | $f + $pad + ($v | gsub("\\|"; "\\|")) + $pad + $f;
  def cr: tostring | test("[\r\n]");
  [.commits[]? | objects] as $all
  | [$b | split("\n")[] | rtrimstr("\r") | select(length > 0) as $s
     | {s: $s, e: ([$all[] | select(.sha == $s)] | first)}] as $rows
  | ([$rows[] | select(.e == null)] | first) as $miss
  | ([$rows[] | select(.e != null and ([.e.piece?, .e.tasks[]?, .e.files[]?] | map(select(. != null)) | any(cr)))] | first) as $bad
  | if $miss != null then "missing\u001f" + $miss.s
    elif $bad != null then "crlf\u001f" + $bad.s
    else
      [$rows[] | .e as $e
       | "| " + .s[0:7] + " | " + ($e.kind | tostring) + " | "
         + (if (($e.piece // "") | tostring) == "" then "" else ($e.piece | tostring | span) end) + " | "
         + (($e.tasks // []) | map(tostring) | join(", ") | gsub("\\|"; "\\|")) + " | "
         + (if $mode == "counts"
            then (($e.files // []) | length) as $n | "\($n) file" + (if $n == 1 then "" else "s" end)
            else (($e.files // []) | map(tostring | span) | join("<br>")) end)
         + " |"] as $lines
      | ("ok\u001f" + ([$lines[] | utf8bytelength + 1 | tostring] | join(" "))), $lines[]
    end'
GUIDE_HEAD='Read this branch commit by commit, top to bottom: each row is one commit, oldest first.'
GUIDE_COLS='| Commit | Kind | Piece | Task IDs | Files |
|---|---|---|---|---|'
# A pull-request body or comment holds at most 65,536 characters; a part is
# kept to this many BYTES, which can only be fewer characters.
GUIDE_PART_MAX=65000

# guide_rows <mode> — ROWS: the table's rows, one per line; SIZES: each row's
# size in bytes, newline included, space-separated.
guide_rows() {
  local r first
  r="$(jqs --arg mode "$1" --rawfile b "$RD/guide-ids.txt" "$GUIDE_JQ" "$sf")"
  first="${r%%$'\n'*}"
  case "$first" in
    ok$'\x1f'*) SIZES="${first#*$'\x1f'}" ;;
    missing$'\x1f'*) die "commit ${first#*$'\x1f'} in $base..HEAD is not recorded: run record-branch first" ;;
    crlf$'\x1f'*) die "the entry for commit ${first#*$'\x1f'} holds a carriage return or a line feed in its piece name, task ids or a path: it would break the table — this stops L" ;;
    *) die "guide: the table answered '$first', which is none of ok, missing or crlf" ;;
  esac
  case "$r" in *$'\n'*) ROWS="${r#*$'\n'}" ;; *) ROWS='' ;; esac
}

# guide <feature> [<base>] — prints the guide.
# guide <feature> [<base>] --parts — prints the guide with each commit's file
# count instead of its files, and writes the full guide, split at row
# boundaries into parts of at most GUIDE_PART_MAX bytes each, to
# guide-parts/guide-<n>.md in the run directory: one pull-request comment
# each, in order. No row and no file is dropped.
cmd_guide() {
  feature="$1"; shift
  local base_arg='' parts=0 stale u part size b row pdir block
  while [ $# -gt 0 ]; do
    case "$1" in
      --parts) parts=1 ;;
      -*) die "unknown option '$1' (only --parts)" ;;
      *) [ -z "$base_arg" ] || die "usage: guide <feature> [<base>] [--parts]"; base_arg="$1" ;;
    esac
    shift
  done
  sf="$(cmd_validate "$feature")"
  need_git_top
  RD="$(run_dir "$feature")"
  commits_ok "$sf"
  # Before the base is read: a run that started on an older pipeline may
  # record none, and it builds no guide, says so, and carries on.
  if jq -e 'any(.commits[]?; type == "string")' "$sf" >/dev/null; then
    warn "commits holds an old-style string entry: this run started on an older pipeline, and no guide is built"
    return 0
  fi
  base="$(base_of "$sf" "$base_arg")"
  git rev-list --reverse --first-parent "$base..HEAD" > "$RD/guide-ids.txt" || die "git rev-list could not read $base..HEAD"
  # shellcheck disable=SC2016 # a jq program: $b is jq's
  stale="$(jqs --rawfile b "$RD/guide-ids.txt" '[.commits[] | objects | .sha | strings] - ($b | split("\n") | map(rtrimstr("\r"))) | join(" ")' "$sf")"
  [ -z "$stale" ] || die "commits records $stale, which is not in $base..HEAD: the guide never shows a row for a commit that is not on the branch — this stops the run"
  u="$(unrecorded "$sf" "$base")"
  [ -z "$u" ] || die "commit(s) $u in $base..HEAD are not recorded: run record-branch first"
  if [ "$parts" -eq 0 ]; then
    guide_rows full
    printf '%s\n\n%s\n' "$GUIDE_HEAD" "$GUIDE_COLS"
    if [ -n "$ROWS" ]; then printf '%s\n' "$ROWS"; fi
    return 0
  fi
  pdir="$RD/guide-parts"
  mkdir -p "$pdir"
  rm -f "$pdir"/guide-*.md
  guide_rows full
  # The block is ASCII, so its length in characters is its size in bytes;
  # each row's size in bytes came from jq.
  block="$(printf '%s\n\n%s\n' "$GUIDE_HEAD" "$GUIDE_COLS")"$'\n'
  part=1; size="${#block}"
  printf '%s' "$block" > "$pdir/guide-$part.md"
  if [ -n "$ROWS" ]; then
    while IFS= read -r row; do
      b="${SIZES%% *}"; SIZES="${SIZES#* }"
      if [ $((size + b)) -gt "$GUIDE_PART_MAX" ]; then
        [ "$size" -gt "${#block}" ] || die "one row of the guide alone passes $GUIDE_PART_MAX bytes; it cannot be split without dropping files: ${row%% | *} |"
        part=$((part + 1)); size="${#block}"
        printf '%s' "$block" > "$pdir/guide-$part.md"
      fi
      printf '%s\n' "$row" >> "$pdir/guide-$part.md"; size=$((size + b))
    done < <(printf '%s\n' "$ROWS")
  fi
  warn "the full guide is in $part part(s): $pdir/guide-1.md to guide-$part.md, each at most $GUIDE_PART_MAX bytes"
  guide_rows counts
  printf '%s\n\n%s\n' "$GUIDE_HEAD" "$GUIDE_COLS"
  if [ -n "$ROWS" ]; then printf '%s\n' "$ROWS"; fi
}

# --- drop-stale ---------------------------------------------------------------
# On the owner's answer to L's stop: removes every commits entry whose id is
# not in <base>..HEAD — the one write to commits outside commit-add — and
# prints the ids removed. The branch's ids travel as data, never as program
# text. Old-style string entries are left as they are.
cmd_drop_stale() {
  feature="$1"
  [ $# -le 2 ] || die "usage: drop-stale <feature> [<base>]"
  sf="$(cmd_validate "$feature")"
  need_git_top
  RD="$(run_dir "$feature")"
  commits_ok "$sf"
  base="$(base_of "$sf" "${2:-}")"
  local gone
  git rev-list --first-parent "$base..HEAD" > "$RD/branch-ids.txt" || die "git rev-list could not read $base..HEAD"
  # shellcheck disable=SC2016 # a jq program: $b and $s are jq's
  gone="$(jqs --rawfile b "$RD/branch-ids.txt" '($b | split("\n")) as $on
    | [.commits[]? | objects | .sha | strings | select(. as $s | any($on[]; . == $s) | not)] | join(" ")' "$sf")"
  if [ -z "$gone" ]; then
    warn "every recorded commit is on the branch: nothing removed"
    return 0
  fi
  # shellcheck disable=SC2016 # a jq program: $b and $s are jq's
  state_write "$sf" '($b | split("\n")) as $on
    | .commits |= map(select(type != "object" or (.sha as $s | any($on[]; . == $s))))' \
    --rawfile b "$RD/branch-ids.txt"
  warn "removed the entries for commits not on the branch: $gone"
  # shellcheck disable=SC2086 # one id per line: split on purpose
  printf '%s\n' $gone
}

# --- commit-list --------------------------------------------------------------
# K's list: every first-parent commit in <base>..HEAD, oldest first, with its
# full message (indented, so it reads as data) and every file it touched; then
# every path still uncommitted. Each path is marked `-` inside the feature or
# `!` outside it; a path under the state directory is always outside, and is
# never listed as uncommitted. A commit with no file and no `Late: J` line
# stops K: refused, naming it.
cmd_commit_list() {
  feature="$1"
  [ $# -le 2 ] || die "usage: commit-list <feature> [<base>]"
  sf="$(cmd_validate "$feature")"
  need_git_top
  RD="$(run_dir "$feature")"
  base="$(base_of "$sf" "${2:-}")"
  feature_bounds "$sf"
  local list c msg line f rec p out roots='' r n=0
  while IFS= read -r r; do
    case "$r" in r:*) roots="$roots${roots:+, }'${r#r:}'" ;; esac
  done < <(printf '%s\n' "$ROOTS")
  [ -n "$roots" ] || roots="(none: every path outside the spec directory and tasks.md counts as outside)"
  out="codeRoots: $roots"$'\n'"Paths are marked '-' inside the feature (codeRoots, the spec directory, tasks.md) or '!' outside it; .gitignore and the constitution are inside only as an accepted pre-flight offer wrote them."$'\n'
  list="$(git rev-list --reverse --first-parent "$base..HEAD")" || die "git rev-list could not read $base..HEAD"
  for c in $list; do
    n=$((n + 1))
    msg="$(git log -1 --format=%B "$c")"
    commit_files "$c"
    if [ "${#CF[@]}" -eq 0 ] && ! has_line "$msg" 'Late: J'; then
      die "commit $c has no file and no 'Late: J' line: K cannot show it — this stops the run"
    fi
    out="$out"$'\n'"commit $n: $c"$'\n'"  message:"$'\n'
    while IFS= read -r line; do out="$out    $line"$'\n'; done < <(printf '%s\n' "$msg")
    out="$out  files:"$'\n'
    if [ "${#CF[@]}" -eq 0 ]; then out="$out    (none: J's record of a waved-through red)"$'\n'; fi
    for f in ${CF[@]+"${CF[@]}"}; do
      path_ok "$f"
      mark_of "$f" "$c"
      out="$out    $MARK $f"$'\n'
    done
  done
  out="$out"$'\n'"uncommitted:"$'\n'
  status_to "$RD/k-status.nul"
  local m=0
  while IFS= read -r -d '' rec; do
    p="${rec:3}"; path_ok "$p"
    if in_state_dir "$p"; then continue; fi
    mark_of "$p"
    out="$out  $MARK $p"$'\n'; m=$((m + 1))
  done < "$RD/k-status.nul"
  if [ "$m" -eq 0 ]; then out="$out  (none)"$'\n'; fi
  printf '%s' "$out"
}

# --- remainder-commit -----------------------------------------------------------
# remainder-commit <feature> <message-file> [--kind other|constitution] — K's
# commits. Kind other, the default: every path git status lists, never one
# under the state directory, less the constitution when gates records its
# pre-flight offer accepted, for that takes its own commit. Kind
# constitution: that file alone, and only when the offer is recorded
# accepted. The message is the file's text, checked as the other commands
# check theirs. Every path is named, through the same NUL path file, and a
# remainder left empty makes no commit and says so: a commit from an empty
# path file would take whatever is already staged. Records the commit under
# its kind and prints its id.
# remainder-commit <feature> --list [--kind ...] — prints the paths, commits
# nothing.
cmd_remainder_commit() {
  feature="$1"; local mf="${2:-}" k=other rec p accepted=0
  case $# in
    2) ;;
    4) [ "$3" = --kind ] || die "unknown option '$3' (only --kind)"; k="$4" ;;
    *) die "usage: remainder-commit <feature> <message-file|--list> [--kind other|constitution]" ;;
  esac
  [ -n "$mf" ] || die "usage: remainder-commit <feature> <message-file|--list> [--kind other|constitution]"
  case "$k" in other|constitution) ;; *) die "unknown kind '$k': remainder-commit makes kind other or constitution" ;; esac
  sf="$(cmd_validate "$feature")"
  need_git_top
  RD="$(run_dir "$feature")"
  commits_ok "$sf"
  if [ "$mf" != --list ]; then msg_body "$mf"; fi
  if offer_accepted constitution; then accepted=1; fi
  if [ "$k" = constitution ] && [ "$accepted" -eq 0 ]; then
    die "gates.constitution records no accepted pre-flight offer ({accepted: true, hash: ...}): there is no constitution commit to make"
  fi
  status_to "$RD/rest-status.nul"
  RP=()
  while IFS= read -r -d '' rec; do
    p="${rec:3}"; path_ok "$p"
    if in_state_dir "$p"; then continue; fi
    if [ "$p" = "$CONSTITUTION" ]; then
      if [ "$k" = constitution ] || [ "$accepted" -eq 0 ]; then RP+=("$p"); fi
    elif [ "$k" = other ]; then
      RP+=("$p")
    fi
  done < "$RD/rest-status.nul"
  if [ "$mf" = --list ]; then
    if [ "${#RP[@]}" -gt 0 ]; then printf '%s\n' "${RP[@]}"; fi
    return 0
  fi
  if [ "${#RP[@]}" -eq 0 ]; then
    warn "nothing is left uncommitted for a kind $k commit: no commit is made"
    return 0
  fi
  nul_file "$RD/rest-paths.nul" "${RP[@]}"
  commit_named "$RD/rest-paths.nul" "$mf"
  ( cmd_commit_add "$feature" --files-from "$RD/rest-paths.nul" "$k" "$SHA" "" "" ) \
    || die "commit $SHA is made but not recorded — record it with commit-add $feature --files-from $RD/rest-paths.nul $k $SHA '' ''"
  warn "committed the kind $k remainder as $SHA: ${#RP[@]} paths"
  printf '%s\n' "$SHA"
}

# j_record_msg <file> — J's empty record commit's message: the message read
# by msg_body, then its `Late: J` line. late-commit J --record commits it;
# show-message --record prints it. One writer, so the two cannot differ.
j_record_msg() { printf '%s\n\nLate: J\n' "$MSG" > "$1"; }

# show-message <feature> <message file> [--record] — prints the message
# exactly as a commit subcommand would commit it: the run's recorded
# trailers added by the same with_trailers path, the caller's file left
# alone. With --record, J's empty record commit as late-commit J --record
# makes it. K shows a message this way, so the owner's answer covers every
# line that leaves at L.
cmd_show_message() {
  feature="$1"
  case $# in
    2) ;;
    3) [ "$3" = --record ] || die "unknown option '$3' (only --record)" ;;
    *) die "usage: show-message <feature> <message-file> [--record]" ;;
  esac
  [ -n "$2" ] || die "usage: show-message <feature> <message-file> [--record]"
  sf="$(cmd_validate "$feature")"
  need_git_top
  RD="$(run_dir "$feature")"
  msg_body "$2"
  if [ "${3:-}" = --record ]; then
    SHOW_MSG="$(mktemp "$RD/show-record-msg.XXXXXX")" || die "could not make a temporary file in $RD"
    j_record_msg "$SHOW_MSG"
    with_trailers "$SHOW_MSG"
  else
    with_trailers "$2"
  fi
  cat -- "$MF"
}

# --- metrics ------------------------------------------------------------------
# .delivery-kit/runs/<feature>/pipeline-run.json, derived from the state file:
# phases with their timestamps and seconds, gates, the commits by kind, and
# the analyze iterations. Keys the orchestrator wrote itself (findings fixed,
# agents dispatched, loop iterations) are kept; derived keys are rewritten.
# Running it twice writes the same file.
# shellcheck disable=SC2016 # a jq program: $m, $d and $s are jq's
METRICS_JQ='
  def secs: try fromdateiso8601 catch null;
  ($m | if length > 0 then .[0] else {} end) + {
    feature,
    current_phase,
    completed_phases,
    phases: ((.timestamps // {}) | with_entries(.value |= (
      if type == "object" and (.started | type) == "string" and (.done | type) == "string"
      then (.done | secs) as $d | (.started | secs) as $s
           | . + {seconds: (if $d != null and $s != null then $d - $s else null end)}
      else . end))),
    gates: (.gates // {}),
    commits: {
      total: ((.commits // []) | length),
      by_kind: ((.commits // []) | map(if type == "object" then (.kind // "unknown" | tostring) else "old-style" end)
                | group_by(.) | map({key: .[0], value: length}) | from_entries)
    },
    analyze_iterations: ((.analyze_changelog // []) | length)
  }'

cmd_metrics() {
  feature="$1"
  [ $# -eq 1 ] || die "usage: metrics <feature>"
  sf="$(cmd_validate "$feature")"
  metrics_write "$feature" "$sf"
  printf '%s\n' "$MF_PATH"
}

# metrics_write <feature> <state file> — writes the run file, through a
# temporary file of this write's own, and sets MF_PATH to it. init runs it
# too, so the file exists from the run's first moment and never depends on
# the orchestrator remembering to make it.
metrics_write() {
  local mf tmp
  commits_ok "$2"
  mf="$(run_dir "$1")/pipeline-run.json"
  MF_PATH="$mf"
  if [ -f "$mf" ]; then
    [ "$(jqs -s 'length == 1 and (.[0] | type) == "object"' "$mf" 2>/dev/null)" = true ] \
      || die "$mf is not one JSON object — not overwriting it"
    tmp="$(mktemp "$mf.XXXXXX")" || die "could not make a temporary file beside $mf — it is unchanged"
    jq ${JQB:+"$JQB"} --slurpfile m "$mf" "$METRICS_JQ" "$2" > "$tmp" || { rm -f "$tmp"; die "metrics: the write failed — $mf is unchanged"; }
  else
    tmp="$(mktemp "$mf.XXXXXX")" || die "could not make a temporary file beside $mf"
    jq ${JQB:+"$JQB"} --argjson m '[]' "$METRICS_JQ" "$2" > "$tmp" || { rm -f "$tmp"; die "metrics: the write failed"; }
  fi
  mv "$tmp" "$mf"
}

# --- state-set ----------------------------------------------------------------
# state-set <feature> <key> [<sub-key>] <json> — the whole-key write for the
# keys no other subcommand writes: gates, artifacts, measurements and config
# (objects), analyze_changelog (a list), test_baseline and last_task
# (strings). With a sub-key, only that member of the object is replaced. The
# value travels as data (--argjson); the write goes to a temp file, is
# validated there, and only then replaces the state file. Every other key —
# commits, the phase alphabet, the feature's identity — has its own command
# or is never written, and is refused.
STATE_SET_KEYS=" gates artifacts measurements config analyze_changelog test_baseline last_task "
cmd_state_set() {
  feature="$1"; local key="${2:-}" sub='' json want k ok=1
  case $# in
    3) json="$3" ;;
    4) sub="$3"; json="$4"; [ -n "$sub" ] || die "the sub-key is empty" ;;
    *) die "usage: state-set <feature> <key> [<sub-key>] <json>" ;;
  esac
  ok=0
  for k in $STATE_SET_KEYS; do if [ "$k" = "$key" ]; then ok=1; fi; done
  [ "$ok" -eq 1 ] || die "state-set does not write '$key' (it writes:${STATE_SET_KEYS% })"
  case "$key" in
    analyze_changelog) want=array ;;
    test_baseline|last_task) want=string ;;
    *) want=object ;;
  esac
  if [ -n "$sub" ] && [ "$want" != object ]; then die "'$key' holds a $want, which has no sub-keys"; fi
  jq -n --argjson v "$json" '$v' >/dev/null 2>&1 || die "the value is not one valid JSON document: $json"
  if [ -z "$sub" ]; then
    # shellcheck disable=SC2016 # a jq program: its $ names are jq's
    [ "$(jqs -n --argjson v "$json" '$v | type')" = "$want" ] || die "'$key' must be a JSON $want"
  fi
  sf="$(cmd_validate "$feature")"
  # gates.pending belongs to ask-later and answer: a sub-key write could
  # forge or drop a question, and a whole-gates write could wipe the queue.
  # The comparison and the write are made under one hold of the lock.
  state_lock "$sf"
  if [ "$key" = gates ]; then
    [ "$sub" != pending ] || die "gates.pending is written only by ask-later and answer"
    if [ -z "$sub" ]; then
      # shellcheck disable=SC2016 # a jq program: its $ names are jq's
      jq -e --argjson v "$json" '((.gates | has("pending")) == ($v | has("pending"))) and (.gates.pending == $v.pending)' "$sf" > /dev/null \
        || die "a whole-gates write must keep gates.pending as it is: it is written only by ask-later and answer"
    fi
  fi
  if [ -n "$sub" ]; then
    # shellcheck disable=SC2016 # a jq program: its $ names are jq's
    state_write "$sf" '.[$k] = ((.[$k] // {}) | if type == "object" then .[$s] = $v else error("not an object") end)' \
      --arg k "$key" --arg s "$sub" --argjson v "$json"
  else
    # shellcheck disable=SC2016 # a jq program: its $ names are jq's
    state_write "$sf" '.[$k] = $v' --arg k "$key" --argjson v "$json"
  fi
}

# --- questions that wait ------------------------------------------------------
# ask-later, pending, answer and pending-check keep the run's waiting
# questions in gates.pending. A question whose answer changes nothing the
# run does before its next stop waits there, and every open one is asked at
# the next stop — at the latest before L pushes, where pending-check stops
# the run while one is open, under --auto too. An entry is open exactly when
# it has no "answer" key. An answered entry stays as the record: it is never
# asked again, and its answer is never replaced. Only these commands write
# gates.pending; state-set refuses to.

# text_file <file> <what> — the file's text, in TEXT. It must exist, be
# readable, hold no control character but tab and line feed (counted from
# the bytes, so a CR is refused on every system, and an ESC sequence cannot
# reach the owner's terminal through pending), and not be blank.
#
# The file is read ONCE, into a copy every check reads, so nothing can swap
# it between the checks and the read. At most 16384 bytes: the text travels
# as one argument to jq, and Windows refuses an argument list past 32 KB.
# Characters a terminal can act on, or that can make a question read as
# something else, are refused too: the list is HIDDEN_CHARS, in
# hidden-chars.sh, which trailer-check.sh reads as well.
text_file() {
  local size
  if [ ! -f "$1" ] || [ ! -r "$1" ]; then die "the $2 file does not exist or cannot be read: $1"; fi
  TEXT_COPY="$(mktemp)" || die "could not make a temporary file to read the $2 file"
  cat -- "$1" > "$TEXT_COPY" || die "the $2 file could not be read: $1"
  size="$(wc -c < "$TEXT_COPY")"; size=$((size + 0))
  [ "$size" -le 16384 ] || die "the $2 file $1 is longer than 16384 bytes ($size)"
  if [ "$(LC_ALL=C tr -cd '\000-\010\013-\037\177' < "$TEXT_COPY" | wc -c)" -ne 0 ]; then
    die "the $2 file $1 holds a control character: only tab and line feed are allowed"
  fi
  TEXT="$(cat -- "$TEXT_COPY")"
  rm -f "$TEXT_COPY"; TEXT_COPY=''
  [[ $TEXT == *[![:space:]]* ]] || die "the $2 file $1 is empty"
  # shellcheck disable=SC2016 # a jq program: its $ names are jq's
  [ "$(jqs -n --arg t "$TEXT" '$t | test("'"$HIDDEN_CHARS"'")')" = false ] \
    || die "the $2 file $1 holds a character that can disguise text in a terminal (a C1 control, a bidi, invisible or zero-width character, a variation selector, a tag character, or a byte-order mark)"
}

# pending_ok <state file> — dies unless gates is an object and gates.pending
# is absent or a list of entries, each an object with a string id, phase and
# question, and a non-blank string answer when it has one; every id is P<n>
# and appears once. Presence is tested, never
# defaulted: a pending of false or null is a queue that cannot be read, and
# such a queue is never read as empty.
PENDING_OK_JQ='if (.gates | type) != "object" then "bad" elif (.gates | has("pending") | not) then "ok" elif (.gates.pending | type) == "array" and all(.gates.pending[]; type == "object" and (.id | type) == "string" and (.id | test("^P[1-9][0-9]*$")) and (.phase | type) == "string" and (.question | type) == "string" and ((has("answer") | not) or ((.answer | type) == "string" and (.answer | test("[^[:space:]]"))))) and ([.gates.pending[].id] | length) == ([.gates.pending[].id] | unique | length) then "ok" else "bad" end'
pending_ok() {
  local v
  v="$(jqs "$PENDING_OK_JQ" "$1")" || die "$1 could not be read for gates.pending"
  [ "$v" = ok ] || die "$1: gates.pending is not a list of questions (each an object with a string id, phase and question)"
}

# ask-later <feature> <phase> <question file> — queues the question and
# prints its id. The same text from the same phase is queued once: a
# re-entered phase gets the existing id back, answered or not.
cmd_ask_later() {
  feature="$1"; local phase="${2:-}" qf="${3:-}" qtext id n
  [ $# -eq 3 ] || die "usage: ask-later <feature> <phase> <question-file>"
  case "$phase" in *[[:space:]]*|'') die "unknown phase '$phase'" ;; esac
  if ! phase_known "$phase" || [ "$phase" = DONE ]; then die "unknown phase '$phase'"; fi
  # pending-check runs before L pushes, and nothing after L checks again: a
  # question raised at M, N, N.5 or O would never meet it.
  case "$phase" in M|N|N.5|O) die "after L, a question cannot wait: phase $phase stops the run to ask it now" ;; esac
  sf="$(cmd_validate "$feature")"
  text_file "$qf" question; qtext="$TEXT"
  # Held from the first read to the write: two calls at once never mint one
  # id twice, nor lose a question.
  state_lock "$sf"
  pending_ok "$sf"
  # shellcheck disable=SC2016 # a jq program: its $ names are jq's
  id="$(jqs --arg p "$phase" --arg q "$qtext" '[(.gates.pending? // [])[] | select(.phase == $p and .question == $q) | .id][0] // ""' "$sf")" \
    || die "$sf could not be read for gates.pending"
  if [ -n "$id" ]; then
    warn "that question is already queued as $id: it is not queued again"
    printf '%s\n' "$id"; return 0
  fi
  # One past the highest id, never the count: an entry removed by hand
  # would otherwise make the next id one that is already taken.
  n="$(jqs '[(.gates.pending? // [])[].id | ltrimstr("P") | tonumber] | max // 0' "$sf")" || die "$sf could not be read for gates.pending"
  id="P$((n + 1))"
  # shellcheck disable=SC2016 # a jq program: its $ names are jq's
  state_write "$sf" '.gates.pending = ((.gates.pending // []) + [{id: $id, phase: $p, question: $q, askedAt: $at}])' \
    --arg id "$id" --arg p "$phase" --arg q "$qtext" --arg at "$(now)"
  printf '%s\n' "$id"
}

# pending <feature> — every open question, ready to show at a stop: a line
# "<id> (raised at <phase>, <time>):", the question, then a blank line.
# Prints nothing when none is open.
cmd_pending() {
  feature="$1"; local out
  [ $# -eq 1 ] || die "usage: pending <feature>"
  sf="$(cmd_validate "$feature")"
  pending_ok "$sf"
  out="$(jqs '[(.gates.pending? // [])[] | select(has("answer") | not) | "\(.id) (raised at \(.phase), \(.askedAt // "time not recorded")):\n\(.question)\n"] | join("\n")' "$sf")" \
    || die "$sf could not be read for gates.pending"
  if [ -n "$out" ]; then printf '%s\n' "$out"; fi
}

# answer <feature> <id> <answer file> — records the owner's answer to an
# open question and prints its id. An answer stands: a second one is refused.
cmd_answer() {
  feature="$1"; local id="${2:-}" af="${3:-}" atext st
  [ $# -eq 3 ] || die "usage: answer <feature> <id> <answer-file>"
  case "$id" in P[1-9]|P[1-9]*[0-9]) ;; *) die "'$id' is not a question id (P1, P2, ...)" ;; esac
  case "${id#P}" in *[!0-9]*) die "'$id' is not a question id (P1, P2, ...)" ;; esac
  sf="$(cmd_validate "$feature")"
  state_lock "$sf"
  pending_ok "$sf"
  # shellcheck disable=SC2016 # a jq program: its $ names are jq's
  st="$(jqs --arg id "$id" '[(.gates.pending? // [])[] | select(.id == $id)] | if length == 0 then "none" elif length > 1 then "many" elif (.[0] | has("answer")) then "answered" else "open" end' "$sf")" \
    || die "$sf could not be read for gates.pending"
  case "$st" in
    open) ;;
    none) die "no question $id is queued" ;;
    answered) die "$id is already answered: an answer stands and is never replaced" ;;
    many) die "$sf: gates.pending holds $id more than once — no answer is recorded" ;;
    *) die "$sf could not be read for $id" ;;
  esac
  text_file "$af" answer; atext="$TEXT"
  # shellcheck disable=SC2016 # a jq program: its $ names are jq's
  state_write "$sf" '.gates.pending |= map(if .id == $id then . + {answer: $a, answeredAt: $at} else . end)' \
    --arg id "$id" --arg a "$atext" --arg at "$(now)"
  printf '%s\n' "$id"
}

# pending-check <feature> — exit 0, printing nothing, when no question is
# open; exit 1 naming the open ids when one is, and on a queue it cannot
# read. Run before L pushes: an open question stops the run there, and
# --auto does not collapse that stop.
cmd_pending_check() {
  feature="$1"; local open n
  [ $# -eq 1 ] || die "usage: pending-check <feature>"
  sf="$(cmd_validate "$feature")"
  pending_ok "$sf"
  n="$(jqs '[(.gates.pending? // [])[] | select(has("answer") | not)] | length' "$sf")" \
    || die "$sf could not be read for gates.pending"
  case "$n" in ''|*[!0-9]*) die "$sf could not be read for gates.pending" ;; esac
  [ "$n" -eq 0 ] && return 0
  open="$(jqs '[(.gates.pending? // [])[] | select(has("answer") | not) | .id] | join(" ")' "$sf")" || open='(unreadable ids)'
  die "waiting questions are still open: $open — ask them, and record each answer, before anything leaves the machine"
}

# --- suite results ------------------------------------------------------------
# suite-key, suite-record and suite-lookup keep a full run of testCommand
# per exact set of files, so J, N and a later run's F.5 can cite a GREEN
# result on files that command already passed on instead of spending the run
# again. config.suiteReuse says what else the key covers:
#   commit    (the default) the files, AND git's state around them: HEAD's
#             commit id, and each tracked path's index mode and object id,
#             so a staged change, a commit, an amended message or HEAD
#             moved is a change. A suite that reads HEAD's commit or the
#             index — a trailer in `git log -1`, staged bytes through
#             `git show :path` — is never told a result that does not hold.
#             Other refs are not keyed: a fetch would move every key. The
#             price: N cannot cite J's run once K commits.
#   files     the files alone: a change committed, staged or only in the
#             working tree counts the same, so N can cite J's run on the
#             files J then committed. For a suite that reads no git state.
#   off       nothing is kept and nothing is reused.
# The files, in either mode: every tracked path still on disk and every
# untracked path git does not ignore, except an untracked path under
# .delivery-kit/; every such file's bytes as they are on disk, unfiltered;
# and its mode — a tracked file's mode on disk where git sees modes, else
# its index mode, and 100644 for an untracked file. Under commit, a tracked
# path missing from disk is named too. An index entry marked
# assume-unchanged or skip-worktree hides its changes from git, a
# submodule's files and a nested repository's are not git's to list, and an
# unmerged path has no one entry, so any of these means no key. The key also
# covers the mode, config.testCommand exactly as recorded, and the platform
# (uname -s and uname -m): the same files can pass on one system and fail on
# another. It is git's hash of these as one JSON object; the record repeats
# them, and suite-lookup compares them too, never the file name alone, so a
# record made under one mode is never reused under another. Records live
# repository-wide, in .delivery-kit/suite-results/, so a later run finds
# them. The verdict comes from the TAP, never from the exit code alone; see
# TAP_AWK. What the key cannot see, a reuse assumes unchanged: git's refs
# other than HEAD's commit — the branch's name, tags, and other branches,
# the base among them, so a range check against a base that moved can be
# reused — files git ignores, an empty directory, the environment and the tools' versions, an
# untracked file's own mode, a tracked file's mode where git ignores it
# (core.fileMode false), and a rename that changes only letter case where
# the file system ignores case; under files, all of git's own records too.
# The TAP file and the exit code are the caller's: suite-record judges what
# it is handed.
SUITE_DIR="$STATE_ROOT/suite-results"

# suite_key <feature> [base] — sets SK_MODE, SK_TREE, SK_HEAD, SK_BYTES,
# SK_CMD, SK_PLAT and SK_KEY; returns 1 with the reason in SK_WHY when there
# is no key. With base, the untracked files under the run's spec directory
# are left out: the key of the files as they were before this feature,
# which F.5's baseline may look up and nothing ever records.
suite_key() {
  local sf spec d top here
  SK_WHY='' SK_KEY='' SK_LEAVE='' SK_HEAD=''
  sf="$(cmd_validate "$1")" || exit 1
  SK_CMD="$(jqs '.config.testCommand? | strings' "$sf")" || SK_CMD=''
  if [ -z "$SK_CMD" ]; then SK_WHY="config.testCommand is not recorded as a string in $sf"; return 1; fi
  SK_MODE="$(jqs '.config.suiteReuse? | if . == null then "commit" elif type == "string" then . else "?" end' "$sf")" || SK_MODE='?'
  case "$SK_MODE" in
    commit|files) ;;
    off) SK_WHY="config.suiteReuse is off: no suite result is kept or reused"; return 1 ;;
    *) SK_WHY="config.suiteReuse in $sf is none of commit, files or off"; return 1 ;;
  esac
  if [ "${2:-}" = base ]; then
    spec="$(jqs '.artifacts.spec? // "" | strings' "$sf")" || spec=''
    # No message names the spec's path: artifacts may record it absolute,
    # and a full path can carry a user name into a public log.
    if [ -z "$spec" ] || [ ! -f "$spec" ]; then SK_WHY="artifacts.spec in $sf names no spec file that exists"; return 1; fi
    # The top level as the spec directory would leave out every untracked
    # file, the feature's code with the rest.
    case "$spec" in */*) d="${spec%/*}" ;; *) d=. ;; esac
    [ -n "$d" ] || d=/
    top="$(git rev-parse --show-toplevel)" || die "git rev-parse failed"
    here="$(cd -- "$d" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || here=''
    if [ "$here" != "$top" ]; then SK_WHY="artifacts.spec in $sf names a spec file outside this repository"; return 1; fi
    SK_LEAVE="$(cd -- "$d" && git rev-parse --show-prefix)" || die "could not place the spec directory"
    if [ -z "$SK_LEAVE" ]; then SK_WHY="the spec file sits at the repository's top level, so there is no spec directory to leave out"; return 1; fi
    case "$SK_LEAVE" in "$STATE_ROOT"/*)
      SK_WHY="the spec file sits under $STATE_ROOT/, which is left out already, so there is no spec directory to leave out"; return 1 ;;
    esac
  fi
  # This call's own scratch file: two calls at once must never truncate or
  # remove each other's, which would read as a clean answer.
  SK_SCRATCH="$(mktemp "$(run_dir "$1")/suite-scratch.XXXXXX")" || die "could not make a scratch file"
  if ! suite_key_check "$SK_SCRATCH"; then rm -f "$SK_SCRATCH"; return 1; fi
  rm -f "$SK_SCRATCH"
  SK_PLAT="$(uname -s) $(uname -m)"
  # shellcheck disable=SC2016 # a jq program: its $ names are jq's
  SK_KEY="$(jqs -n -c --arg m "$SK_MODE" --arg h "$SK_HEAD" --arg b "$SK_BYTES" --arg c "$SK_CMD" --arg p "$SK_PLAT" \
    '{mode: $m, head: $h, files: $b, command: $c, platform: $p}' | git hash-object --stdin)" || die "could not hash the suite key"
}

# SUITE_KEY_AWK reads five lists, each but the last ended by a line holding
# only the byte 001, which no list can hold — git quotes a control character
# in a path: the tracked paths missing from disk (ls-files -d), the index
# (ls-files -s: mode, object, stage, a tab, the path), the untracked paths,
# diff-files' raw lines (old mode, new mode, objects, status, a tab, the
# path), and the hashes of the files on disk. want=paths prints the paths
# on disk, for hash-object, which answers in the same order; it stops at the
# first entry that means no key, printing the byte 001 and the reason.
# want=list pairs each path with its hash and prints one line a file, the
# path, its mode and its hash, tab-separated — a tab in a path is quoted —
# and m=commit adds the index mode and object id (or u for an untracked
# file) and a line for each tracked path missing from disk. The mode is the
# one on disk where diff-files reports one other than the index's — a file
# listed only because its time changed holds the same pair — else the index
# mode, and 100644 for an untracked file, so a file reads the same tracked
# or untracked — unless git records it as 100755 once added. The caller
# sorts the lines, so where a path sits in git's
# lists does not move the key. Every path stays as git quoted it.
# shellcheck disable=SC2016 # an awk program: its $ names are awk's
SUITE_KEY_AWK='
  $0 == "\001" { part++; next }
  part == 0 { gone[$0] = 1; next }
  part == 1 {
    mode = $1; obj = $2; stage = $3; p = $0; sub(/^[^\t]*\t/, "", p)
    if (mode == "160000") { print "\001the tree holds a submodule (" p ")"; bad = 1; exit }
    if (stage != "0") { print "\001the index holds an unmerged path (" p ")"; bad = 1; exit }
    if (p in gone) { if (m == "commit") G[++ng] = p "\tgone\ti " mode " " obj; next }
    if (want == "paths") print p
    else { P[++np] = p; M[np] = mode; I[np] = "i " mode " " obj }
    next
  }
  part == 2 {
    if ($0 ~ /\/"?$/) { print "\001an untracked directory holds a repository of its own (" $0 ")"; bad = 1; exit }
    if (want == "paths") print
    else { P[++np] = $0; M[np] = "100644"; I[np] = "u" }
    next
  }
  part == 3 { t = index($0, "\t"); split(substr($0, 1, t - 1), f, " "); if (f[1] != ":" f[2]) dm[substr($0, t + 1)] = f[2]; next }
  { H[++nh] = $0 }
  END {
    if (bad || want != "list") exit
    if (nh != np) { print "\001the files and their hashes do not pair up"; exit }
    for (i = 1; i <= np; i++) {
      line = P[i] "\t" ((P[i] in dm) ? dm[P[i]] : M[i]) "\t" H[i]
      if (m == "commit") line = line "\t" I[i]
      print line
    }
    for (i = 1; i <= ng; i++) print G[i]
  }'

# suite_key_check <scratch file> — sets SK_TREE, SK_HEAD and SK_BYTES;
# returns 1 with the reason in SK_WHY when the files have no key. Dies,
# never answers, when a check cannot be made.
suite_key_check() {
  local scratch="$1" rc paths hashes entries
  local leave=()
  # The tag letters, spelled out rather than as a range a locale can widen:
  # lower case is assume-unchanged, S is skip-worktree. Read from a file, never
  # through a pipe: grep -q leaving early would hand git a SIGPIPE, and
  # pipefail would turn a match into a failure. Any exit but 0 or 1 is a
  # check not made, never a clean answer. --no-optional-locks on every git
  # call: a check made while a suite runs must not rewrite the index under it.
  git --no-optional-locks ls-files -v > "$scratch" || die "git ls-files failed"
  rc=0; LC_ALL=C grep -q '^[abcdefghijklmnopqrstuvwxyzS] ' "$scratch" || rc=$?
  case "$rc" in
    0) SK_WHY="an index entry is marked assume-unchanged or skip-worktree, which hides its changes from git status"; return 1 ;;
    1) ;;
    *) die "could not read the index tags (grep exited $rc)" ;;
  esac
  # The untracked list leaves out the state directory, and with base the
  # spec directory, by pathspec: literal, so no character in either is read
  # as a pattern, and before quoting, so an odd name cannot slip past. The
  # trailing slash keeps a sibling such as .delivery-kitX/ in.
  if [ -n "$SK_LEAVE" ]; then leave=(":(exclude,literal)$SK_LEAVE"); fi
  { git --no-optional-locks -c core.quotePath=true ls-files -d \
    && printf '\001\n' \
    && git --no-optional-locks -c core.quotePath=true ls-files -s \
    && printf '\001\n' \
    && git --no-optional-locks -c core.quotePath=true ls-files -o --exclude-standard -- . \
         ":(exclude,literal)$STATE_ROOT/" ${leave[@]+"${leave[@]}"} \
    && printf '\001\n' \
    && git --no-optional-locks -c core.quotePath=true diff-files --raw \
    && printf '\001\n'; } > "$scratch" || die "git ls-files failed"
  paths="$(awk -v BINMODE=3 -v want=paths "$SUITE_KEY_AWK" < "$scratch")" || die "could not read the index entries"
  case "$paths" in *$'\001'*) SK_WHY="${paths##*$'\001'}"; return 1 ;; esac
  SK_TREE="$(git rev-parse --verify --quiet 'HEAD^{tree}')" || { SK_WHY="HEAD names no commit yet"; return 1; }
  if [ "$SK_MODE" = commit ]; then SK_HEAD="$(git rev-parse --verify --quiet HEAD)" || die "git rev-parse failed"; fi
  # The bytes each file holds on disk, read with no filter and no line-ending
  # conversion. git status compares what a file CLEANS to, and trusts a
  # file's size and time, so a file can hold other bytes than its blob and
  # still look unchanged; the tests read the bytes. ls-files quotes an odd
  # path and hash-object unquotes it, so every name survives the trip.
  hashes=''
  if [ -n "$paths" ]; then
    hashes="$(printf '%s\n' "$paths" | git hash-object --no-filters --stdin-paths)" || die "could not read the files' bytes"
  fi
  [ -z "$hashes" ] || printf '%s\n' "$hashes" >> "$scratch" || die "could not write the scratch file"
  entries="$(awk -v BINMODE=3 -v want=list -v m="$SK_MODE" "$SUITE_KEY_AWK" < "$scratch" | LC_ALL=C sort)" \
    || die "could not read the index entries"
  case "$entries" in *$'\001'*) die "${entries##*$'\001'}" ;; esac
  SK_BYTES="$(printf '%s\n' "$entries" | git hash-object --stdin)" || die "could not hash the files' bytes"
}

# TAP_AWK judges a TAP file, one copy of these rules for this plugin and the
# delivery-kit repository's quickstarts: tap-check prints its verdict,
# suite-record keeps it, and the repository's scripts/check-suite.sh, which
# does not ship with this plugin, calls tap-check. (The repository's CI reads
# its own shards' TAP with checks of its own.) It prints one line: seven counts — non-blank lines, plan
# lines, the plan's count when the FIRST non-blank line is a plan (else 0),
# ok lines, skips among them, not ok lines, and non-TAP lines — then OK, or
# the first rule the file breaks. A non-TAP line is one that is neither TAP
# nor a `#` comment, or a test line whose number is missing, repeated or
# outside the plan; tests may finish in any order, as a parallel runner
# prints them. e is the expected count, or empty to take the plan's. The
# rules run in a fixed order, so a not ok, a skip or a stray line is named
# before the ok count it also shortens. A run's stdout and stderr belong in
# the one file: anything that is not TAP makes the result red, which only
# means it is run again. The K tags are the rows of
# specs/023-gate-reads-whole-changelog/contracts/check-suite.md. BINMODE=3
# keeps GNU Awk on Windows from stripping the CR itself, so the strip below
# is this script's own rule everywhere; the file reaches awk on stdin, never
# as an argument awk could read as an assignment.
# shellcheck disable=SC2016 # an awk program: its $ names are awk's
TAP_AWK='
  { sub(/\r$/, "") }  # K11
  /^[[:space:]]*$/ { next }
  { n++ }
  n == 1 { first = $0 }
  /^1[.][.][0-9]+$/ { plans++; if (n == 1) plan = substr($0, 4) + 0; next }
  function num(v) { if (v !~ /^[0-9]+$/ || (v + 0) in seen) badnum++; else seen[v + 0] = 1 }
  /^ok / { oks++; num($2); if (tolower($0) ~ /# skip/) skips++; next }
  /^not ok / { nots++; num($3); next }
  /^#/ { next }
  { stray++ }
  END {
    for (v in seen) if (v + 0 < 1 || v + 0 > plan) badnum++
    if (msg == "" && n == 0) msg = "the TAP file is empty"  # K4
    if (msg == "" && e != "" && first != "1.." e) msg = "the first non-blank line is not the plan line 1.." e  # K5
    if (msg == "" && e == "" && first !~ /^1[.][.][1-9][0-9]*$/) msg = "the first non-blank line is not a plan line 1..N with N at least 1"  # K5
    if (msg == "" && plans > 1) msg = "a second plan line: the run crashed or was concatenated"  # K6
    if (msg == "" && nots > 0) msg = nots " not ok"  # K9
    if (msg == "" && skips > 0) msg = skips " skipped, and a skip is not a pass"  # K8
    if (msg == "" && stray > 0) msg = stray " non-TAP line(s)"  # K10
    if (msg == "" && oks + 0 != plan + 0) msg = "ok count " (oks + 0) ", expected " plan  # K7
    if (msg == "" && badnum > 0) msg = badnum " test number(s) missing, repeated or outside the plan"
    printf "%d %d %d %d %d %d %d %s\n", n, plans, plan, oks, skips, nots, stray + badnum, (msg == "" ? "OK" : msg)
  }'

# tap_judge <tap file> [<expected count>] — sets TJ_PLAN, TJ_OK, TJ_SKIP,
# TJ_NOT and TJ_STRAY, and TJ_MSG: empty when the run passes, else the first
# rule it breaks. Only an explicit OK passes: awk failing to start or to
# read, and printing nothing, dies, never a silent pass. stderr is discarded
# BEFORE the file is opened, so the shell's own error for a file it cannot
# open, which names the file as given, never prints.
tap_judge() {
  local counts n plans v
  counts="$(awk -v BINMODE=3 -v e="${2:-}" "$TAP_AWK" 2>/dev/null < "$1")" || counts=''
  read -r n plans TJ_PLAN TJ_OK TJ_SKIP TJ_NOT TJ_STRAY TJ_MSG <<EOF
$counts
EOF
  for v in "$n" "$plans" "$TJ_PLAN" "$TJ_OK" "$TJ_SKIP" "$TJ_NOT" "$TJ_STRAY"; do
    case "$v" in ''|*[!0-9]*) die "the TAP file cannot be read" ;; esac
  done
  [ -n "$TJ_MSG" ] || die "the TAP file cannot be read"
  if [ "$TJ_MSG" = OK ]; then TJ_MSG=''; fi
}

# tap-check <tap file> [<expected count>] — judges any TAP file, keyed or
# not: the plan line first (1..<expected> when a count is given), one plan
# line, as many ok lines as the plan names, numbered 1 to N in any order,
# no skip, no not ok, and no line that is neither TAP nor a `#` comment.
# Exit 0 prints one summary line; anything else exits 1 naming the first
# rule broken. It takes no feature and needs no git. No message prints the
# file's path, which can carry a user name and reach a public log.
cmd_tap_check() {
  local tap="${1:-}" want="${2:-}"
  { [ $# -eq 1 ] || [ $# -eq 2 ]; } || die "usage: progress.sh tap-check <tap-file> [<expected-count>]"
  if [ $# -eq 2 ]; then
    case "$want" in ''|0*|*[!0-9]*) die "usage: progress.sh tap-check <tap-file> [<expected-count>], where <expected-count> is a positive integer" ;; esac
  fi
  if [ ! -f "$tap" ] || [ ! -r "$tap" ]; then die "the TAP file does not exist or cannot be read"; fi
  tap_judge "$tap" "$want"
  [ -z "$TJ_MSG" ] || die "$TJ_MSG"
  printf 'suite ok: 1..%s, %s ok, 0 skipped, 0 not ok, 0 non-TAP\n' "$TJ_PLAN" "$TJ_OK"
}

cmd_suite_key() {
  [ $# -eq 1 ] || die "usage: suite-key <feature>"
  need_git_top
  if ! suite_key "$1"; then die "no suite key: $SK_WHY"; fi
  printf '%s\n' "$SK_KEY"
}

# suite-record <feature> <key> <tap file> <rc> — the key is suite-key's,
# taken BEFORE the command ran. Files that no longer have that key when the
# result is recorded — a test left a file behind, a file changed meanwhile
# — record nothing: a result is kept only for the files it ran on. A change
# the key cannot see is not refused: a file a test changed and restored, or
# wrote where git ignores it. The verdict is green only for exit code 0 and
# a TAP file tap-check passes. A red result is recorded too, so the latest
# result on a set of files is the one that stands, and lookup never reuses
# a red one.
cmd_suite_record() {
  local key="${2:-}" tap="${3:-}" rc="${4:-}" verdict out tmp
  [ $# -eq 4 ] || die "usage: suite-record <feature> <key> <tap-file> <rc>"
  case "$rc" in [0-9]|[0-9][0-9]|[0-9][0-9][0-9]) ;; *) die "the exit code '$rc' is not a number from 0 to 999" ;; esac
  if [ ! -f "$tap" ] || [ ! -r "$tap" ]; then die "the TAP file does not exist or cannot be read"; fi
  need_git_top
  if ! suite_key "$1"; then die "nothing recorded — no suite key now: $SK_WHY"; fi
  [ "$key" = "$SK_KEY" ] || die "nothing recorded — what the key covers (the files, the git state its mode reads, the command, the platform) is not what it was when the key was taken"
  tap_judge "$tap"
  verdict=red
  if [ "$rc" -eq 0 ] && [ -z "$TJ_MSG" ]; then verdict=green; fi
  mkdir -p "$SUITE_DIR"
  out="$SUITE_DIR/$SK_KEY.json"
  # A temporary name of this call's own: two records on one key never write
  # one file.
  tmp="$(mktemp "$SUITE_DIR/.record.XXXXXX")" || die "could not make a temporary record"
  # -b: a native Windows jq writes no CR, so a record is the same bytes on
  # every system. Literal -b until the dispatch probes jq and sets JQB
  # (jq 1.6 has no -b); then this becomes jq ${JQB:+"$JQB"}. An inherited
  # JQB is never trusted here. tree is HEAD's tree when the result was
  # recorded, kept to be read, never compared.
  # shellcheck disable=SC2016 # a jq program: its $ names are jq's
  if ! jq -b -n --arg key "$SK_KEY" --arg mode "$SK_MODE" --arg head "$SK_HEAD" --arg tree "$SK_TREE" --arg bytes "$SK_BYTES" --arg command "$SK_CMD" --arg platform "$SK_PLAT" \
       --arg verdict "$verdict" --arg feature "$1" --arg tap "$tap" --arg at "$(now)" \
       --argjson plan "$TJ_PLAN" --argjson ok "$TJ_OK" --argjson skipped "$TJ_SKIP" --argjson notOk "$TJ_NOT" \
       --argjson nonTap "$TJ_STRAY" --argjson rc "$((10#$rc))" \
       '{key: $key, mode: $mode, head: $head, tree: $tree, bytes: $bytes, command: $command, platform: $platform, verdict: $verdict,
         plan: $plan, ok: $ok, skipped: $skipped, notOk: $notOk, nonTap: $nonTap, rc: $rc,
         recordedAt: $at, feature: $feature, tap: $tap}' > "$tmp"; then
    rm -f "$tmp"; die "the suite record could not be written"
  fi
  mv "$tmp" "$out"
  printf '%s\n' "$verdict"
}

# suite-lookup <feature> [--base] — exit 0 only for a GREEN record whose
# files, command and platform are these, printing the record's path and a
# summary line; exit 1, the reason on stderr, for anything else. The record
# may come from any run: a later run's F.5 reuses an earlier run's result on
# the same files. Its counts are judged again here — whole numbers, none
# below zero, no skip — so a record edited by hand to read green without the
# counts of one is not reused. With --base, for F.5 alone: when these files
# have no green record, the files without the run's untracked spec directory
# are looked up too — the baseline is the tree before this feature, and the
# spec directory is the feature's own.
# shellcheck disable=SC2016 # a jq program: its $ names are jq's
SUITE_LOOKUP_JQ='
  if length != 1 or (.[0] | type) != "object" then "unreadable"
  else .[0]
  | if .key != $k or .mode != $mo or .head != $h or .bytes != $b or .command != $c or .platform != $p then "another"
    elif .verdict == "green"
         and ([.plan, .ok, .skipped, .notOk, .nonTap, .rc] | all(type == "number" and . == floor and . >= 0))
         and .rc == 0 and .notOk == 0 and .nonTap == 0 and .skipped == 0 and .plan >= 1 and .ok == .plan
      then "green\u001f1..\(.plan), \(.ok) ok (\(.skipped) skipped), 0 not ok, exit 0 — recorded \(.recordedAt) by run \(.feature)"
    else "red" end
  end'

# suite_lookup_one — prints and returns 0 for a green record on SK_KEY;
# returns 1 with the reason in LK_WHY for anything else.
suite_lookup_one() {
  local rec v
  rec="$SUITE_DIR/$SK_KEY.json"
  if [ ! -f "$rec" ]; then LK_WHY="none is recorded for these files, command and platform under suiteReuse $SK_MODE"; return 1; fi
  v="$(jqs -s --arg k "$SK_KEY" --arg mo "$SK_MODE" --arg h "$SK_HEAD" --arg b "$SK_BYTES" --arg c "$SK_CMD" --arg p "$SK_PLAT" "$SUITE_LOOKUP_JQ" "$rec" 2>/dev/null)" || v=unreadable
  case "${v%%$'\x1f'*}" in
    green)   printf '%s\n%s' "$rec" "${v#*$'\x1f'}"
             if [ -n "$SK_LEAVE" ]; then printf ' — for these files without the untracked %s' "$SK_LEAVE"; fi
             printf '\n'; return 0 ;;
    red)     LK_WHY="the result recorded for these files is red, and a red result is never reused: run the suite" ;;
    another) LK_WHY="$rec records other files, another command, platform or mode" ;;
    *)       LK_WHY="$rec is not one readable record" ;;
  esac
  return 1
}

cmd_suite_lookup() {
  local first
  case "$#:${2:-}" in 1:|2:--base) ;; *) die "usage: suite-lookup <feature> [--base]" ;; esac
  need_git_top
  if ! suite_key "$1"; then die "no reusable result — no suite key: $SK_WHY"; fi
  if suite_lookup_one; then return 0; fi
  [ $# -eq 2 ] || die "no reusable result — $LK_WHY"
  first="$LK_WHY"
  if ! suite_key "$1" base; then die "no reusable result — $first; and none without the spec directory: $SK_WHY"; fi
  if suite_lookup_one; then return 0; fi
  die "no reusable result — $first; and without the untracked $SK_LEAVE, $LK_WHY"
}

# tap-check takes a TAP file, not a feature, so it is dispatched before the
# feature name is checked. It makes no file, so the exit trap, whose rm is
# one more tool than bash and awk, is dropped first.
if [ "${1:-}" = tap-check ]; then trap - EXIT; shift; cmd_tap_check "$@"; exit 0; fi
cmd="${1:-}"; [ $# -ge 2 ] || usage
feature_arg="$2"
need_feature "$feature_arg"
case "$cmd" in validate|read) ;; *) jq_b_probe ;; esac
not_abandoned "$feature_arg"
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
  snapshot)      shift 2; cmd_snapshot "$feature_arg" "$@" ;;
  spec-commit)   shift 2; cmd_spec_commit "$feature_arg" "$@" ;;
  piece-commit)  shift 2; cmd_piece_commit "$feature_arg" "$@" ;;
  late-commit)   shift 2; cmd_late_commit "$feature_arg" "$@" ;;
  remainder-commit) shift 2; cmd_remainder_commit "$feature_arg" "$@" ;;
  show-message)  shift 2; cmd_show_message "$feature_arg" "$@" ;;
  record-branch) shift 2; cmd_record_branch "$feature_arg" "$@" ;;
  guide)         shift 2; cmd_guide "$feature_arg" "$@" ;;
  commit-list)   shift 2; cmd_commit_list "$feature_arg" "$@" ;;
  metrics)       shift 2; cmd_metrics "$feature_arg" "$@" ;;
  state-set)     shift 2; cmd_state_set "$feature_arg" "$@" ;;
  drop-stale)    shift 2; cmd_drop_stale "$feature_arg" "$@" ;;
  suite-key)     shift 2; cmd_suite_key "$feature_arg" "$@" ;;
  suite-record)  shift 2; cmd_suite_record "$feature_arg" "$@" ;;
  suite-lookup)  shift 2; cmd_suite_lookup "$feature_arg" "$@" ;;
  ask-later)     shift 2; cmd_ask_later "$feature_arg" "$@" ;;
  pending)       shift 2; cmd_pending "$feature_arg" "$@" ;;
  answer)        shift 2; cmd_answer "$feature_arg" "$@" ;;
  pending-check) shift 2; cmd_pending_check "$feature_arg" "$@" ;;
  abandon)       shift 2; cmd_abandon "$feature_arg" "$@" ;;
  get)           shift 2; cmd_get "$feature_arg" "$@" ;;
  *) usage ;;
esac
