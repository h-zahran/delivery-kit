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
# suite-record a verdict, and suite-lookup a record's path and a summary.
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
# the commit commands also pass jq -b (binary output, no CR) and strip any
# CR left. git's path lists are read NUL-separated from a file instead.
set -euo pipefail

STATE_ROOT=".delivery-kit"

warn() { printf 'progress.sh: %s\n' "$*" >&2; }
die()  { printf 'progress.sh: %s\n' "$*" >&2; exit 1; }
usage() { die "usage: progress.sh <init|read|validate|phase-start|phase-done|from-validate|lock-take|lock-release|commit-add|piece-next|snapshot|spec-commit|piece-commit|late-commit|remainder-commit|record-branch|guide|commit-list|metrics|state-set|drop-stale|suite-key|suite-record|suite-lookup> <feature> [args]"; }

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

  tmp="$sf.tmp"
  jq "${jqargs[@]}" "$ENTRY_JQ"' .commits += [entry]' "$sf" > "$tmp" && mv "$tmp" "$sf"
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
# -b so a native Windows jq writes no CR, and any CR left stripped anyway.
# The SHORT -b only: jq 1.7 parses it on every platform (a no-op off
# Windows), while the long --binary is an unknown option there.
jqs() {
  local v
  v="$(jq -b -r "$@")" || return 1
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

# commit_named <path file> <message file> — stage and commit exactly the
# named paths. A commit is never run from an empty path file: with no
# pathspec, git commits whatever is already staged (measured). A hook that
# rejects the commit stops here; --no-verify is never passed.
commit_named() {
  [ -s "$1" ] || die "the path list is empty — a commit from an empty path file takes whatever is already staged, so no commit is made"
  git --literal-pathspecs add --pathspec-from-file="$1" --pathspec-file-nul >&2 \
    || die "git add refused the paths in $1 — nothing committed"
  git --literal-pathspecs commit -q --cleanup=verbatim -F "$2" --pathspec-from-file="$1" --pathspec-file-nul >&2 \
    || die "the commit was rejected (a commit hook?) — nothing is committed or recorded, and the paths in $1 stay uncommitted"
  SHA="$(git rev-parse HEAD)"
}

# state_write <state file> <jq program> [jq options...] — a whole-file write:
# into a temp file, validated there, then moved over the state file. On any
# failure the old file stands as it was.
state_write() {
  local f="$1" prog="$2" tmp
  shift 2
  tmp="$f.tmp"
  if ! jq "$@" "$prog" "$f" > "$tmp"; then rm -f "$tmp"; die "the write to $f failed — the state file is unchanged"; fi
  if ! ( validate_file "$tmp" ) > /dev/null; then rm -f "$tmp"; die "the write would leave $f invalid — the state file is unchanged"; fi
  mv "$tmp" "$f"
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
    printf '%s\n\nLate: J\n' "$MSG" > "$RD/late-msg.txt"
    git commit -q --allow-empty --only --cleanup=verbatim -F "$RD/late-msg.txt" >&2 \
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
  commits_ok "$sf"
  local mf tmp
  mf="$(run_dir "$feature")/pipeline-run.json"
  tmp="$mf.tmp"
  if [ -f "$mf" ]; then
    [ "$(jqs -s 'length == 1 and (.[0] | type) == "object"' "$mf" 2>/dev/null)" = true ] \
      || die "$mf is not one JSON object — not overwriting it"
    jq --slurpfile m "$mf" "$METRICS_JQ" "$sf" > "$tmp" || { rm -f "$tmp"; die "metrics: the write failed — $mf is unchanged"; }
  else
    jq --argjson m '[]' "$METRICS_JQ" "$sf" > "$tmp" || { rm -f "$tmp"; die "metrics: the write failed"; }
  fi
  mv "$tmp" "$mf"
  printf '%s\n' "$mf"
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
  if [ -n "$sub" ]; then
    # shellcheck disable=SC2016 # a jq program: its $ names are jq's
    state_write "$sf" '.[$k] = ((.[$k] // {}) | if type == "object" then .[$s] = $v else error("not an object") end)' \
      --arg k "$key" --arg s "$sub" --argjson v "$json"
  else
    # shellcheck disable=SC2016 # a jq program: its $ names are jq's
    state_write "$sf" '.[$k] = $v' --arg k "$key" --argjson v "$json"
  fi
}

# --- suite results ------------------------------------------------------------
# suite-key, suite-record and suite-lookup keep a full run of testCommand
# per exact tree, so J, N and a later run's F.5 can cite a GREEN result on a
# tree that command already passed on instead of spending the run again. A
# result is reused only when all four of these are what they were:
#   tree      HEAD^{tree} — and only when the working tree holds NO change
#             but an untracked path under .delivery-kit/, tracked, staged or
#             untracked (files git ignores are not seen, as git does not see
#             them). A dirty tree has no key: nothing is looked up and
#             nothing is recorded. An index entry marked assume-unchanged or
#             skip-worktree hides its changes from git status, and a
#             submodule's files are not in the tree, so either means no key.
#   bytes     every tracked file's bytes as they are on disk, unfiltered
#   command   config.testCommand, exactly as the state file records it
#   platform  uname -s and uname -m: the same tree can pass on one system
#             and fail on another
# The key is git's hash of the four as one JSON object; the record repeats
# them, and suite-lookup compares them too, never the file name alone.
# Records live repository-wide, in .delivery-kit/suite-results/, so a later
# run finds them. The verdict comes from the TAP, never from the exit code
# alone; see SUITE_AWK. What the key cannot see, a reuse assumes unchanged:
# files git ignores, the environment and the tools' versions, a file's mode
# where git ignores it (core.fileMode false), and the history around the
# tree — its refs and commit messages. The TAP file and the exit code are the
# caller's: suite-record judges what it is handed.
SUITE_DIR="$STATE_ROOT/suite-results"

# suite_key <feature> — sets SK_TREE, SK_BYTES, SK_CMD, SK_PLAT and SK_KEY;
# returns 1 with the reason in SK_WHY when there is no key.
suite_key() {
  local sf
  SK_WHY='' SK_KEY=''
  sf="$(cmd_validate "$1")" || exit 1
  SK_CMD="$(jqs '.config.testCommand? | strings' "$sf")" || SK_CMD=''
  if [ -z "$SK_CMD" ]; then SK_WHY="config.testCommand is not recorded as a string in $sf"; return 1; fi
  # This call's own scratch file: two calls at once must never truncate or
  # remove each other's, which would read as a clean answer.
  SK_SCRATCH="$(mktemp "$(run_dir "$1")/suite-scratch.XXXXXX")" || die "could not make a scratch file"
  trap 'rm -f "${SK_SCRATCH:-}"' EXIT
  if ! suite_key_check "$SK_SCRATCH"; then rm -f "$SK_SCRATCH"; return 1; fi
  rm -f "$SK_SCRATCH"
  SK_PLAT="$(uname -s) $(uname -m)"
  # shellcheck disable=SC2016 # a jq program: its $ names are jq's
  SK_KEY="$(jqs -n -c --arg t "$SK_TREE" --arg b "$SK_BYTES" --arg c "$SK_CMD" --arg p "$SK_PLAT" \
    '{tree: $t, bytes: $b, command: $c, platform: $p}' | git hash-object --stdin)" || die "could not hash the suite key"
}

# suite_key_check <scratch file> — sets SK_TREE and SK_BYTES; returns 1 with
# the reason in SK_WHY when the tree has no key. Dies, never answers, when a
# check cannot be made.
suite_key_check() {
  local scratch="$1" rec dirty rc sub hashes
  # --no-optional-locks: a check made while a suite runs must not rewrite the
  # index under it. --ignore-submodules=none: a submodule's own changes count.
  git --no-optional-locks status --porcelain=v1 -z --untracked-files=all --no-renames --ignore-submodules=none > "$scratch" \
    || die "git status failed"
  dirty=''
  while IFS= read -r -d '' rec; do
    # Only an UNTRACKED path in the state directory is the run's own; a
    # tracked file there that changed is a change like any other.
    case "$rec" in "?? $STATE_ROOT"/*) ;; *) dirty="${rec:3}"; break ;; esac
  done < "$scratch"
  if [ -n "$dirty" ]; then SK_WHY="the working tree has a change outside $STATE_ROOT/ ($dirty)"; return 1; fi
  # The tag letters, spelled out rather than as a range a locale can widen:
  # lower case is assume-unchanged, S is skip-worktree. Read from a file, never
  # through a pipe: grep -q leaving early would hand git a SIGPIPE, and
  # pipefail would turn a match into a failure. Any exit but 0 or 1 is a
  # check not made, never a clean answer.
  git --no-optional-locks ls-files -v > "$scratch" || die "git ls-files failed"
  rc=0; LC_ALL=C grep -q '^[abcdefghijklmnopqrstuvwxyzS] ' "$scratch" || rc=$?
  case "$rc" in
    0) SK_WHY="an index entry is marked assume-unchanged or skip-worktree, which hides its changes from git status"; return 1 ;;
    1) ;;
    *) die "could not read the index tags (grep exited $rc)" ;;
  esac
  # A submodule's files are not in this tree's bytes, and git status does not
  # see one that is not checked out, so a tree that holds one has no key.
  git --no-optional-locks ls-files -s > "$scratch" || die "git ls-files failed"
  sub="$(awk -v BINMODE=3 '$1 == "160000" { sub(/^[^\t]*\t/, ""); print; exit }' < "$scratch")" \
    || die "could not read the index entries"
  if [ -n "$sub" ]; then SK_WHY="the tree holds a submodule ($sub)"; return 1; fi
  SK_TREE="$(git rev-parse --verify --quiet 'HEAD^{tree}')" || { SK_WHY="HEAD names no commit yet"; return 1; }
  # The bytes each tracked file holds, read with no filter and no line-ending
  # conversion. git status compares what a file CLEANS to, and trusts a
  # file's size and time, so a file can hold other bytes than its blob and
  # still look unchanged; the tests read the bytes. ls-files quotes an odd
  # path and hash-object unquotes it, so every name survives the trip.
  git --no-optional-locks -c core.quotePath=true ls-files > "$scratch" || die "git ls-files failed"
  hashes="$(git hash-object --no-filters --stdin-paths < "$scratch")" || die "could not read the tracked files' bytes"
  SK_BYTES="$(printf '%s\n' "$hashes" | git hash-object --stdin)" || die "could not hash the tracked files' bytes"
}

# SUITE_AWK reads a TAP file and prints one line, seven counts: non-blank
# lines, plan lines, the plan's count when the FIRST non-blank line is the
# plan (else 0), ok lines, skips among them, not ok lines, and stray lines:
# lines that are neither TAP nor a `#` comment, and test lines whose number
# is missing, repeated or outside the plan — in any order, as a parallel
# runner prints them. The rules are those of the delivery-kit
# repository's scripts/check-suite.sh, which does not ship with this plugin,
# except that a skip counts as an ok here and is reported, not refused. A
# run's stdout and stderr belong in the one file: anything that is not TAP
# makes the result red, which only means it is run again. BINMODE=3 keeps
# GNU Awk on Windows from stripping the CR itself, so the strip below is this
# script's own rule everywhere; the file reaches awk on stdin, never as an
# argument awk could read as an assignment.
# shellcheck disable=SC2016 # an awk program: its $ names are awk's
SUITE_AWK='
  { sub(/\r$/, "") }
  /^[[:space:]]*$/ { next }
  { n++ }
  /^1[.][.][0-9]+$/ { plans++; if (n == 1) plan = substr($0, 4) + 0; next }
  function num(v) { if (v !~ /^[0-9]+$/ || (v + 0) in seen) stray++; else seen[v + 0] = 1 }
  /^ok / { oks++; num($2); if (tolower($0) ~ /# skip/) skips++; next }
  /^not ok / { nots++; num($3); next }
  /^#/ { next }
  { stray++ }
  END {
    for (v in seen) if (v + 0 < 1 || v + 0 > plan) stray++
    printf "%d %d %d %d %d %d %d\n", n, plans, plan, oks, skips, nots, stray
  }'

cmd_suite_key() {
  [ $# -eq 1 ] || die "usage: suite-key <feature>"
  need_git_top
  if ! suite_key "$1"; then die "no suite key: $SK_WHY"; fi
  printf '%s\n' "$SK_KEY"
}

# suite-record <feature> <key> <tap file> <rc> — the key is suite-key's,
# taken BEFORE the command ran. A tree that no longer has that key when the
# result is recorded — a test left a file behind, a commit was made meanwhile
# — records nothing: a result is kept only for the tree it ran on. A change
# the key cannot see is not refused: a file a test changed and restored, or
# wrote where git ignores it. A red
# result is recorded too, so the latest result on a tree is the one that
# stands, and lookup never reuses a red one.
cmd_suite_record() {
  local key="${2:-}" tap="${3:-}" rc="${4:-}" counts n plans plan oks skips nots stray v verdict out tmp
  [ $# -eq 4 ] || die "usage: suite-record <feature> <key> <tap-file> <rc>"
  case "$rc" in [0-9]|[0-9][0-9]|[0-9][0-9][0-9]) ;; *) die "the exit code '$rc' is not a number from 0 to 999" ;; esac
  if [ ! -f "$tap" ] || [ ! -r "$tap" ]; then die "the TAP file does not exist or cannot be read"; fi
  need_git_top
  if ! suite_key "$1"; then die "nothing recorded — no suite key now: $SK_WHY"; fi
  [ "$key" = "$SK_KEY" ] || die "nothing recorded — the tree, the command or the platform is not what it was when the key was taken"
  counts="$(awk -v BINMODE=3 "$SUITE_AWK" 2>/dev/null < "$tap")" || counts=''
  read -r n plans plan oks skips nots stray <<EOF
$counts
EOF
  for v in "$n" "$plans" "$plan" "$oks" "$skips" "$nots" "$stray"; do
    case "$v" in ''|*[!0-9]*) die "the TAP file cannot be read" ;; esac
  done
  verdict=red
  if [ "$rc" -eq 0 ] && [ "$plans" -eq 1 ] && [ "$plan" -ge 1 ] && [ "$oks" -eq "$plan" ] \
     && [ "$nots" -eq 0 ] && [ "$stray" -eq 0 ]; then
    verdict=green
  fi
  mkdir -p "$SUITE_DIR"
  out="$SUITE_DIR/$SK_KEY.json"
  # A temporary name of this call's own: two records on one key never write
  # one file.
  tmp="$(mktemp "$SUITE_DIR/.record.XXXXXX")" || die "could not make a temporary record"
  # -b: a native Windows jq writes no CR, so a record is the same bytes on
  # every system.
  # shellcheck disable=SC2016 # a jq program: its $ names are jq's
  if ! jq -b -n --arg key "$SK_KEY" --arg tree "$SK_TREE" --arg bytes "$SK_BYTES" --arg command "$SK_CMD" --arg platform "$SK_PLAT" \
       --arg verdict "$verdict" --arg feature "$1" --arg tap "$tap" --arg at "$(now)" \
       --argjson plan "$plan" --argjson ok "$oks" --argjson skipped "$skips" --argjson notOk "$nots" \
       --argjson nonTap "$stray" --argjson rc "$((10#$rc))" \
       '{key: $key, tree: $tree, bytes: $bytes, command: $command, platform: $platform, verdict: $verdict,
         plan: $plan, ok: $ok, skipped: $skipped, notOk: $notOk, nonTap: $nonTap, rc: $rc,
         recordedAt: $at, feature: $feature, tap: $tap}' > "$tmp"; then
    rm -f "$tmp"; die "the suite record could not be written"
  fi
  mv "$tmp" "$out"
  printf '%s\n' "$verdict"
}

# suite-lookup <feature> — exit 0 only for a GREEN record whose tree, command
# and platform are this tree's, printing the record's path and a summary
# line; exit 1, the reason on stderr, for anything else. The record may come
# from any run: a later run's F.5 reuses an earlier run's result on the same
# tree. Its counts are judged again here — whole numbers, none below zero —
# so a record edited by hand to read green without the counts of one is not
# reused.
# shellcheck disable=SC2016 # a jq program: its $ names are jq's
SUITE_LOOKUP_JQ='
  if length != 1 or (.[0] | type) != "object" then "unreadable"
  else .[0]
  | if .key != $k or .tree != $t or .bytes != $b or .command != $c or .platform != $p then "another"
    elif .verdict == "green"
         and ([.plan, .ok, .skipped, .notOk, .nonTap, .rc] | all(type == "number" and . == floor and . >= 0))
         and .rc == 0 and .notOk == 0 and .nonTap == 0 and .plan >= 1 and .ok == .plan
      then "green\u001f1..\(.plan), \(.ok) ok (\(.skipped) skipped), 0 not ok, exit 0 — recorded \(.recordedAt) by run \(.feature)"
    else "red" end
  end'
cmd_suite_lookup() {
  local rec v
  [ $# -eq 1 ] || die "usage: suite-lookup <feature>"
  need_git_top
  if ! suite_key "$1"; then die "no reusable result — no suite key: $SK_WHY"; fi
  rec="$SUITE_DIR/$SK_KEY.json"
  [ -f "$rec" ] || die "no reusable result — none is recorded for this tree, command and platform"
  v="$(jqs -s --arg k "$SK_KEY" --arg t "$SK_TREE" --arg b "$SK_BYTES" --arg c "$SK_CMD" --arg p "$SK_PLAT" "$SUITE_LOOKUP_JQ" "$rec" 2>/dev/null)" || v=unreadable
  case "${v%%$'\x1f'*}" in
    green)   printf '%s\n%s\n' "$rec" "${v#*$'\x1f'}" ;;
    red)     die "no reusable result — the result recorded for this tree is red, and a red result is never reused: run the suite" ;;
    another) die "no reusable result — $rec records another tree, command or platform" ;;
    *)       die "no reusable result — $rec is not one readable record" ;;
  esac
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
  snapshot)      shift 2; cmd_snapshot "$feature_arg" "$@" ;;
  spec-commit)   shift 2; cmd_spec_commit "$feature_arg" "$@" ;;
  piece-commit)  shift 2; cmd_piece_commit "$feature_arg" "$@" ;;
  late-commit)   shift 2; cmd_late_commit "$feature_arg" "$@" ;;
  remainder-commit) shift 2; cmd_remainder_commit "$feature_arg" "$@" ;;
  record-branch) shift 2; cmd_record_branch "$feature_arg" "$@" ;;
  guide)         shift 2; cmd_guide "$feature_arg" "$@" ;;
  commit-list)   shift 2; cmd_commit_list "$feature_arg" "$@" ;;
  metrics)       shift 2; cmd_metrics "$feature_arg" "$@" ;;
  state-set)     shift 2; cmd_state_set "$feature_arg" "$@" ;;
  drop-stale)    shift 2; cmd_drop_stale "$feature_arg" "$@" ;;
  suite-key)     shift 2; cmd_suite_key "$feature_arg" "$@" ;;
  suite-record)  shift 2; cmd_suite_record "$feature_arg" "$@" ;;
  suite-lookup)  shift 2; cmd_suite_lookup "$feature_arg" "$@" ;;
  *) usage ;;
esac
