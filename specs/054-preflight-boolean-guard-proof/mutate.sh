#!/usr/bin/env bash
# Mutation rig for feature 054: does each boolean in the pre-flight report
# have a test that goes red when that boolean is emitted as a string?
#
# Usage: mutate.sh [--final] <commit>
#
# For one commit it makes one throwaway worktree, derives the mutants by
# measuring them (research R5), and for each one flips `--argjson <var> "` to
# `--arg <var> "` in a SCRATCH COPY of the worktree's pipeline/scripts/. The
# worktree's own pipeline/tests/preflight.bats then runs against that copy
# through the suite's PREFLIGHT_UNDER_TEST hook. Nothing tracked is ever
# edited: not in this checkout, not in the worktree (research R6).
#
# It RUNS the commit's own preflight.sh and preflight.bats, with your
# environment. Point it only at commits you trust.
#
# This is a measurement, not a suite. It runs on Linux; its output goes into
# measurements.md. Only pipeline/tests/preflight.bats runs under each mutant,
# so HOLE means "no test in preflight.bats went red", not "the whole suite
# stayed green".
#
# Verdicts (data-model.md): CAUGHT, ELSEWHERE, HOLE, WALK-ONLY, NO-WALK,
# NO-OP, BAD, INCOMPLETE, MISSING. Exit 1 on NO-OP, BAD, INCOMPLETE or
# MISSING, on a red or incomplete control, on a failed derivation or a failed
# final byte check; with --final, also on any verdict but CAUGHT.

set -u

final=0
if [ "${1:-}" = "--final" ]; then final=1; shift; fi
commit="${1:-}"
[ -n "$commit" ] || { echo "usage: mutate.sh [--final] <commit>" >&2; exit 2; }

top="$(git rev-parse --show-toplevel)" || { echo "not inside a git repository" >&2; exit 2; }
sha="$(git -C "$top" rev-parse --verify -q "$commit^{commit}")" || { echo "no such commit: $commit" >&2; exit 2; }

BATS="${BATS:-$HOME/bats/bin/bats}"
[ -f "$BATS" ] || { echo "bats not found (set BATS)" >&2; exit 2; }

# The walk test FR-012 adds. Named here, once, because the verdicts read it.
WALK='no report field is the string "true" or "false"'
# The seven the spec names. The derivation must find each of them, or the rig
# refuses: a derivation that silently found fewer would measure less than the
# spec claims (Principle I).
REQUIRED="gh adb sk_present sk_in_range sk_const git_usable dirty"
PARALLEL=3

# Absolute, so a relative TMPDIR cannot put the worktree somewhere cleanup
# does not look (git resolves the worktree path against the top, the shell
# against the current directory).
tmp="$(mktemp -d "${TMPDIR:-/tmp}/dk-mutate.XXXXXX")" || exit 2
tmp="$(cd "$tmp" && pwd -P)" || exit 2
wt="$tmp/wt"
batch=""

# Remove only what this run made. Each suite runs under `timeout`, which puts
# itself in a process group of its own, so killing the subshell above it
# would leave bats running against a deleted worktree: the group is killed
# instead, by the leader's PID, recorded in a pg-* file while it is alive and
# removed once it is reaped. The PID is written by the process itself before
# it execs timeout, so no signal can land while the file is missing; the PID
# is signalled too, in case timeout has not made its group yet. Only the
# current batch's subshells are signalled: a PID already reaped is no longer
# this run's to signal.
# shellcheck disable=SC2329 # invoked by the EXIT trap below
cleanup() {
  local f p
  for f in "$tmp"/pg-*; do
    [ -f "$f" ] || continue
    p="$(cat "$f")"
    [ -n "$p" ] || continue
    kill -TERM -- "-$p" 2>/dev/null
    kill -TERM "$p" 2>/dev/null
  done
  for p in $batch; do kill "$p" 2>/dev/null; done
  if [ -d "$wt" ] && ! git -C "$top" worktree remove --force "$wt" 2>/dev/null; then
    echo "cleanup: could not remove the worktree at $wt; run: git worktree prune" >&2
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

git -C "$top" worktree add --quiet --detach "$wt" "$sha" || { echo "worktree add failed" >&2; exit 1; }
script="$wt/pipeline/scripts/preflight.sh"
suite="$wt/pipeline/tests/preflight.bats"

# A commit whose suite ignores PREFLIGHT_UNDER_TEST would run every mutant
# against the unmutated script: all green, every row a false HOLE.
grep -q 'PREFLIGHT_UNDER_TEST' "$suite" || { echo "this commit's preflight.bats has no PREFLIGHT_UNDER_TEST hook" >&2; exit 1; }

# The report template: the one `jq -n` call that builds the report. Mutations
# and the derivation are confined to it, so a `--argjson` elsewhere in the
# script is never touched.
TEMPLATE_START='^jq -n \\$'
TEMPLATE_END="^}'\$"
# template_of <file> — the template's lines. The patterns reach awk through
# the environment: `awk -v` would turn their `\\` into `\`.
template_of() {
  TS="$TEMPLATE_START" TE="$TEMPLATE_END" \
    awk '$0 ~ ENVIRON["TS"] {f=1} f {print} f && $0 ~ ENVIRON["TE"] {exit}' "$1"
}
if [ "$(template_of "$script" | grep -c '')" -lt 2 ] || ! template_of "$script" | tail -1 | grep -qE "$TEMPLATE_END"; then
  echo "derivation: no report template (jq -n ... }') in preflight.sh" >&2; exit 1
fi

echo "commit   $sha"
echo "date     $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "mode     $([ "$final" = 1 ] && echo final || echo base)"

# run_suite <name> [script under test] — the whole preflight.bats, in the
# worktree, under a hard time limit, TAP to $tmp/<name>.tap. Returns bats'
# exit status (124 when the limit was hit).
run_suite() {
  local pid rc
  # shellcheck disable=SC2016 # $$ and $@ belong to the inner bash
  ( cd "$wt" && PREFLIGHT_UNDER_TEST="${2:-$script}" \
      exec bash -c 'echo "$$" > "$1"; shift; exec timeout 600 bash "$@"' _ \
        "$tmp/pg-$1" "$BATS" --tap pipeline/tests/preflight.bats ) > "$tmp/$1.tap" 2>&1 &
  pid=$!
  wait "$pid"; rc=$?
  rm -f "$tmp/pg-$1"
  return "$rc"
}

# plan_of <tap file> — the plan line, wherever stderr has pushed it.
plan_of() { grep -m1 -E '^1\.\.[0-9]+$' "$1"; }

# complete <tap file> <rc> — the run finished: bats exited 0 or 1, and the
# plan line's count equals the ok plus not-ok lines. A cut or crashed run
# gets no verdict.
complete() {
  local n seen
  case "$2" in 0|1) ;; *) return 1 ;; esac
  n="$(plan_of "$1" | sed 's/^1\.\.//')"
  seen="$(grep -cE '^(ok|not ok) ' "$1")"
  [ -n "$n" ] && [ "$n" = "$seen" ]
}

# The control: the unmutated script must be green and complete, or a red
# under a mutant proves nothing about the mutant (FR-004).
run_suite control; crc=$?
plan="$(plan_of "$tmp/control.tap")"
if ! complete "$tmp/control.tap" "$crc"; then
  echo "CONTROL incomplete (exit $crc, plan '$plan', $(grep -cE '^(ok|not ok) ' "$tmp/control.tap") results)"; exit 1
fi
if [ "$crc" -ne 0 ] || grep -q '^not ok' "$tmp/control.tap"; then
  echo "CONTROL red (exit $crc)"; grep '^not ok' "$tmp/control.tap"; exit 1
fi
echo "CONTROL green $plan, $(grep -c '^ok ' "$tmp/control.tap") ok"

# flip <var> <in> <out> — the one mutation, confined to the FIRST report
# template, as template_of reads it (a sed range would restart at a later
# `jq -n \` block).
flip() {
  TS="$TEMPLATE_START" TE="$TEMPLATE_END" V="$1" awk '
    !done && $0 ~ ENVIRON["TS"] {f = 1}
    f {gsub("--argjson " ENVIRON["V"] " \"", "--arg " ENVIRON["V"] " \"")}
    f && $0 ~ ENVIRON["TE"] {f = 0; done = 1}
    {print}' "$2" > "$3"
}

# Derivation (R5), by measurement, not by parsing: every `--argjson <var> "`
# in the template is flipped in a copy and the report probed once; the var's
# fields are the paths that were booleans and became strings. A var whose
# flip turns no boolean into a string (an array, say) is named and is not a
# mutant. A flip that changes nothing, or that leaves no JSON report, fails
# the rig: a var is never dropped in silence. A boolean no var fills (a
# literal such as `jq: true`) is named too.
probe() { bash "$1" --dir "$wt" --base-branch main 2>/dev/null; }
report="$(probe "$script")"
printf '%s\n' "$report" | jq -e 'type == "object"' >/dev/null 2>&1 \
  || { echo "derivation: the probe printed no JSON object" >&2; exit 1; }
bools="$(printf '%s\n' "$report" | jq -c '[paths(type == "boolean")]')"
cp -R "$wt/pipeline/scripts" "$tmp/derive"
argvars="$(template_of "$script" \
  | grep -oE -- '--argjson [a-z_]+ "' | sed 's/^--argjson //; s/ "$//' | sort -u)"
vars=""
dfail=0
: > "$tmp/fields"
for v in $argvars; do
  flip "$v" "$script" "$tmp/derive/preflight.sh"
  if cmp -s "$tmp/derive/preflight.sh" "$script"; then
    echo "derivation: flipping $v changed nothing (NO-OP)"; dfail=1; continue
  fi
  out="$(probe "$tmp/derive/preflight.sh")"
  if ! printf '%s\n' "$out" | jq -e 'type == "object"' >/dev/null 2>&1; then
    echo "derivation: flipping $v leaves no JSON report (BAD)"; dfail=1; continue
  fi
  f="$(printf '%s\n' "$out" | jq -r --argjson b "$bools" \
        '. as $r | [$b[] as $p | select(($r | getpath($p)) | type == "string") | $p | map(tostring) | join(".")] | join(",")')"
  if [ -z "$f" ]; then echo "not boolean $v (its flip turns no boolean into a string)"; continue; fi
  vars="$vars $v"
  printf '%s %s\n' "$v" "$f" >> "$tmp/fields"
done
vars="${vars# }"
[ "$dfail" = 0 ] || exit 1
echo "derived  $vars"
claimed="$(cut -d' ' -f2 "$tmp/fields" | tr ',' '\n')"
for p in $(printf '%s\n' "$bools" | jq -r '.[] | map(tostring) | join(".")'); do
  printf '%s\n' "$claimed" | grep -qxF -- "$p" || echo "unmutable $p (no --argjson variable fills it)"
done
for r in $REQUIRED; do
  case " $vars " in *" $r "*) ;; *) echo "derivation: '$r' not found" >&2; exit 1 ;; esac
done

fields_of() { awk -v v="$1" '$1 == v {print $2; exit}' "$tmp/fields"; }

# command_at <line> — the whole command holding <line> of the suite, less
# its diagnostics. bats names a failing command by its first line, or, for
# `cmd || { echo ...; false; }`, by the line of that `false`, so neither end
# can be assumed. This reads forward from the start of the enclosing test or
# function, tracking single and double quotes and skipping comments, and
# splits commands at a line end outside quotes with no backslash before it.
# If no command end is found within 40 lines, the command is <line> alone.
# Text from `|| {` to the end of a line is dropped: a diagnostic that prints
# a field is not a check of it.
command_at() {
  awk -v n="$1" '{L[NR] = $0} END {
    s = n
    while (s > 1 && L[s] !~ /^@test |^[A-Za-z_][A-Za-z0-9_]*\(\) *\{/) s--
    sq = 0; dq = 0; start = s; stop = 0
    for (k = s; k <= NR && k <= n + 40; k++) {
      line = L[k]
      if (!sq && !dq && line ~ /^[ \t]*#/) { if (k == start) start = k + 1; continue }
      for (c = 1; c <= length(line); c++) {
        ch = substr(line, c, 1)
        if (sq) { if (ch == "\047") sq = 0 }
        else if (dq) { if (ch == "\\") c++; else if (ch == "\"") dq = 0 }
        else if (ch == "\\") c++
        else if (ch == "\047") sq = 1
        else if (ch == "\"") dq = 1
        else if (ch == "#" && (c == 1 || substr(line, c - 1, 1) ~ /[ \t]/)) break
      }
      if (!sq && !dq && line !~ /\\$/) {
        if (k >= n) { stop = k; break }
        start = k + 1
      }
    }
    if (!stop || start > n) { start = n; stop = n }
    for (k = start; k <= stop; k++) { t = L[k]; sub(/\|\| *\{.*/, "", t); print t }
  }' "$suite"
}

# guard_seen <tap file> <fields> — some failing command reads one of the
# fields by its full path (`.capabilities.git`, never a bare `.git`, which
# file paths and URLs also hold), with no word character after it. That is
# the field's own guard, which FR-011 requires; any other red does not count.
guard_seen() {
  local alts re n lines
  alts="$(printf '%s\n' "$2" | tr ',' '\n' | sed 's/\./\\./g' | paste -sd'|' -)"
  re="\\.($alts)([^A-Za-z0-9_]|\$)"
  lines="$(grep -oE 'preflight\.bats, line [0-9]+' "$1" | sed 's/.* //' | sort -un)"
  for n in $lines; do
    command_at "$n" | grep -qE -- "$re" && return 0
  done
  return 1
}

# mutant <var> — writes $tmp/r-<var> as
# "kind<TAB>mutated line<TAB>red count<TAB>walk red<TAB>guard red<TAB>red names".
# The counts come from the TAP file, never from the joined names: a test name
# may itself hold the separator.
mutant() {
  local v="$1" d="$tmp/m-$1" n line red nred nwalk guard rc
  cp -R "$wt/pipeline/scripts" "$d"
  n="$(template_of "$d/preflight.sh" | grep -cF -- "--argjson $v \"")"
  if [ "$n" != 1 ]; then printf 'BAD\t%s occurrences of --argjson %s in the template\t0\t0\t0\t\n' "$n" "$v" > "$tmp/r-$v"; return; fi
  flip "$v" "$script" "$d/preflight.sh"
  # A mutation that changed nothing is a silent false green: refuse it.
  if cmp -s "$d/preflight.sh" "$script"; then printf 'NO-OP\t-\t0\t0\t0\t\n' > "$tmp/r-$v"; return; fi
  if ! bash -n "$d/preflight.sh" 2>/dev/null; then printf 'BAD\tbash -n failed\t0\t0\t0\t\n' > "$tmp/r-$v"; return; fi
  line="$(TS="$TEMPLATE_START" TE="$TEMPLATE_END" V="--arg $v \"" awk '
    $0 ~ ENVIRON["TS"] {f = 1}
    f && index($0, ENVIRON["V"]) {print NR ":" $0; exit}
    f && $0 ~ ENVIRON["TE"] {exit}' "$d/preflight.sh")"
  run_suite "t-$v" "$d/preflight.sh"; rc=$?
  if ! complete "$tmp/t-$v.tap" "$rc"; then
    printf 'INCOMPLETE\t%s (bats exit %s)\t0\t0\t0\t\n' "$line" "$rc" > "$tmp/r-$v"; return
  fi
  nred="$(grep -c '^not ok' "$tmp/t-$v.tap")"
  nwalk="$(sed -n 's/^not ok [0-9]* //p' "$tmp/t-$v.tap" | grep -cxF -- "$WALK")"
  guard=0; guard_seen "$tmp/t-$v.tap" "$(fields_of "$v")" && guard=1
  red="$(sed -n 's/^not ok [0-9]* //p' "$tmp/t-$v.tap" | awk 'NR > 1 {printf " | "} {printf "%s", $0}')"
  printf 'RAN\t%s\t%s\t%s\t%s\t%s\n' "$line" "$nred" "$nwalk" "$guard" "$red" > "$tmp/r-$v"
}

# Split on purpose: $vars is a space-separated list of [a-z_] names.
# shellcheck disable=SC2086
set -- $vars
while [ $# -gt 0 ]; do
  batch=""
  i=0
  while [ $# -gt 0 ] && [ $i -lt $PARALLEL ]; do
    mutant "$1" & batch="$batch $!"
    shift; i=$((i + 1))
  done
  # Wait for these PIDs only; a bare wait would also wait on anything else.
  for p in $batch; do wait "$p"; done
  batch=""
done

fail=0
echo
echo "var ; fields ; verdict ; mutated line ; red count ; red tests (joined by ' | ')"
for v in $vars; do
  kind=MISSING; line=""; nred=0; nwalk=0; guard=0; red=""
  if [ -f "$tmp/r-$v" ]; then
    IFS="$(printf '\t')" read -r kind line nred nwalk guard red < "$tmp/r-$v"
  fi
  if [ "$kind" = RAN ]; then
    if [ "$nred" = 0 ]; then verdict=HOLE
    elif [ "$final" = 0 ]; then
      if [ "$guard" = 1 ]; then verdict=CAUGHT; else verdict=ELSEWHERE; fi
    elif [ "$guard" = 1 ] && [ "$nwalk" -gt 0 ]; then verdict=CAUGHT
    elif [ "$nwalk" -gt 0 ]; then verdict="WALK-ONLY"
    elif [ "$guard" = 1 ]; then verdict="NO-WALK"
    else verdict=ELSEWHERE
    fi
  else
    verdict="$kind"
  fi
  case "$verdict" in
    NO-OP|BAD|INCOMPLETE|MISSING) fail=1 ;;
    CAUGHT) ;;
    *) [ "$final" = 1 ] && fail=1 ;;
  esac
  echo "$v ; $(fields_of "$v") ; $verdict ; ${line:-} ; ${nred:-0} ; ${red:-}"
done

# The worktree's script must still be the commit's, byte for byte: proof that
# every mutant ran on a copy.
git -C "$wt" show "$sha:pipeline/scripts/preflight.sh" > "$tmp/orig.sh"
if cmp -s "$tmp/orig.sh" "$script"; then
  echo; echo "BYTES    worktree preflight.sh identical to $sha"
else
  echo; echo "BYTES    worktree preflight.sh CHANGED"; fail=1
fi
exit "$fail"
