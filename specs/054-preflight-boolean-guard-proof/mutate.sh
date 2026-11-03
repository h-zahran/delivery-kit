#!/usr/bin/env bash
# Mutation rig for feature 054: does each boolean in the pre-flight report
# have a test that goes red when that boolean is emitted as a string?
#
# Usage: mutate.sh [--final] <commit>
#
# For one commit it makes one throwaway worktree, derives the mutants from the
# code (research R5), and for each one flips `--argjson <var> "` to
# `--arg <var> "` in a SCRATCH COPY of the worktree's pipeline/scripts/. The
# worktree's own pipeline/tests/preflight.bats then runs against that copy
# through the suite's PREFLIGHT_UNDER_TEST hook. Nothing tracked is ever
# edited: not in this checkout, not in the worktree (research R6).
#
# This is a measurement, not a suite. It runs here, on Linux, from the
# repository root; its output goes into measurements.md.
#
# Verdicts (data-model.md): CAUGHT, HOLE, WALK-ONLY, NO-WALK, NO-OP, BAD.
# Exit 1 on any NO-OP or BAD, on a red control, on a failed derivation or a
# failed final byte check; with --final, also on any verdict but CAUGHT.

set -u

final=0
if [ "${1:-}" = "--final" ]; then final=1; shift; fi
commit="${1:-}"
[ -n "$commit" ] || { echo "usage: mutate.sh [--final] <commit>" >&2; exit 2; }

top="$(git rev-parse --show-toplevel)" || { echo "not inside a git repository" >&2; exit 2; }
sha="$(git -C "$top" rev-parse --verify -q "$commit^{commit}")" || { echo "no such commit: $commit" >&2; exit 2; }

BATS="${BATS:-$HOME/bats/bin/bats}"
[ -f "$BATS" ] || { echo "bats not found at $BATS" >&2; exit 2; }

# The walk test FR-012 adds. Named here, once, because the verdicts read it.
WALK='no report field is the string "true" or "false"'
# The seven the spec names. The derivation must find each of them, or the rig
# refuses: a derivation that silently found fewer would measure less than the
# spec claims (Principle I).
REQUIRED="gh adb sk_present sk_in_range sk_const git_usable dirty"
PARALLEL=3

tmp="$(mktemp -d "${TMPDIR:-/tmp}/dk-mutate.XXXXXX")" || exit 2
wt="$tmp/wt"
pids=""

# Remove only what this run made: its own background PIDs, its one worktree,
# its own folder. Never a process or worktree it did not record.
# shellcheck disable=SC2329 # invoked by the EXIT trap below
cleanup() {
  local p
  for p in $pids; do kill "$p" 2>/dev/null; done
  [ -d "$wt" ] && git -C "$top" worktree remove --force "$wt" 2>/dev/null
  rm -rf "$tmp"
}
trap cleanup EXIT

git -C "$top" worktree add --quiet --detach "$wt" "$sha" || { echo "worktree add failed" >&2; exit 1; }
script="$wt/pipeline/scripts/preflight.sh"

echo "commit   $sha"
echo "date     $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "mode     $([ "$final" = 1 ] && echo final || echo base)"

# run_suite <tap file> [script under test] — the whole preflight.bats, in the
# worktree, with a hard time limit so a hang cannot outlive the rig.
run_suite() {
  ( cd "$wt" && PREFLIGHT_UNDER_TEST="${2:-$script}" \
      timeout 600 bash "$BATS" --tap pipeline/tests/preflight.bats ) > "$1" 2>&1
}

# The control: the unmutated script must be green, or a red under a mutant
# proves nothing about the mutant (FR-004).
run_suite "$tmp/control.tap"; crc=$?
plan="$(grep -m1 '^1\.\.' "$tmp/control.tap")"
if [ "$crc" -ne 0 ] || grep -q '^not ok' "$tmp/control.tap"; then
  echo "CONTROL red (exit $crc)"; grep '^not ok' "$tmp/control.tap"; exit 1
fi
echo "CONTROL green $plan"

# Derivation (R5): the boolean paths of a real report, mapped through the
# template's `key: $var` lines, kept where the var is an `--argjson` argument.
report="$(bash "$script" --dir "$wt" --base-branch main 2>/dev/null)"
jq -e . >/dev/null 2>&1 <<EOF || { echo "derivation: the probe printed no JSON" >&2; exit 1; }
$report
EOF
paths="$(printf '%s\n' "$report" | jq -r 'paths(type == "boolean") | map(tostring) | join(".")')"
pairs="$(grep -oE '[A-Za-z]+: \$[a-z_]+' "$script" | sed 's/: \$/ /' | sort -u)"
vars=""
for p in $paths; do
  key="${p##*.}"
  v="$(printf '%s\n' "$pairs" | awk -v k="$key" '$1 == k {print $2; exit}')"
  [ -n "$v" ] || continue
  grep -qF -- "--argjson $v \"" "$script" || continue
  case " $vars " in *" $v "*) ;; *) vars="$vars $v" ;; esac
done
vars="${vars# }"
echo "derived  $vars"
for r in $REQUIRED; do
  case " $vars " in *" $r "*) ;; *) echo "derivation: '$r' not found" >&2; exit 1 ;; esac
done

# fields_of <var> — every report path that var fills (gh fills two).
fields_of() {
  local p key out=""
  for p in $paths; do
    key="${p##*.}"
    [ "$(printf '%s\n' "$pairs" | awk -v k="$key" '$1 == k {print $2; exit}')" = "$1" ] && out="$out,$p"
  done
  printf '%s' "${out#,}"
}

# mutant <var> — writes $tmp/r-<var> as "verdict<TAB>mutated line<TAB>red names".
mutant() {
  local v="$1" d="$tmp/m-$1" n line red
  cp -R "$wt/pipeline/scripts" "$d"
  n="$(grep -cF -- "--argjson $v \"" "$d/preflight.sh")"
  if [ "$n" != 1 ]; then printf 'BAD\t%s occurrences of --argjson %s\t\n' "$n" "$v" > "$tmp/r-$v"; return; fi
  sed "s/--argjson $v \"/--arg $v \"/" "$d/preflight.sh" > "$d/preflight.sh.new" && mv "$d/preflight.sh.new" "$d/preflight.sh"
  # A mutation that changed nothing is a silent false green: refuse it.
  if cmp -s "$d/preflight.sh" "$script"; then printf 'NO-OP\t\t\n' > "$tmp/r-$v"; return; fi
  if ! bash -n "$d/preflight.sh" 2>/dev/null; then printf 'BAD\tbash -n failed\t\n' > "$tmp/r-$v"; return; fi
  line="$(grep -n -- "--arg $v \"" "$d/preflight.sh" | head -1)"
  run_suite "$tmp/t-$v.tap" "$d/preflight.sh"
  red="$(sed -n 's/^not ok [0-9]* //p' "$tmp/t-$v.tap" | tr '\n' ';' | sed 's/;$//; s/;/; /g')"
  printf 'RAN\t%s\t%s\n' "$line" "$red" > "$tmp/r-$v"
}

# Split on purpose: $vars is a space-separated list of [a-z_] names.
# shellcheck disable=SC2086
set -- $vars
while [ $# -gt 0 ]; do
  batch=""
  i=0
  while [ $# -gt 0 ] && [ $i -lt $PARALLEL ]; do
    mutant "$1" & batch="$batch $!"; pids="$pids $!"
    shift; i=$((i + 1))
  done
  # Wait for these PIDs only; a bare wait would also wait on anything else.
  for p in $batch; do wait "$p"; done
done
pids=""

fail=0
echo
echo "var | fields | verdict | mutated line | red tests"
for v in $vars; do
  IFS="$(printf '\t')" read -r kind line red < "$tmp/r-$v"
  if [ "$kind" = RAN ]; then
    walk=0; other=0
    old_ifs="$IFS"; IFS=';'
    for t in $red; do
      t="${t# }"
      [ -n "$t" ] || continue
      if [ "$t" = "$WALK" ]; then walk=1; else other=$((other + 1)); fi
    done
    IFS="$old_ifs"
    if [ "$walk" = 0 ] && [ "$other" = 0 ]; then verdict=HOLE
    elif [ "$final" = 0 ]; then verdict=CAUGHT
    elif [ "$walk" = 1 ] && [ "$other" -gt 0 ]; then verdict=CAUGHT
    elif [ "$walk" = 1 ]; then verdict="WALK-ONLY"
    else verdict="NO-WALK"
    fi
  else
    verdict="$kind"
  fi
  case "$verdict" in
    NO-OP|BAD) fail=1 ;;
    CAUGHT) ;;
    *) [ "$final" = 1 ] && fail=1 ;;
  esac
  echo "$v | $(fields_of "$v") | $verdict | ${line:-} | ${red:-}"
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
