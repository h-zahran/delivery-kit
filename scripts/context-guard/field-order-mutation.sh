#!/usr/bin/env bash
# Mutation rig for the two positional jq arrays in
# handoff/hooks/context-guard.sh.
#
# The hook extracts every payload field in one jq call and every configuration
# setting in another, joining them with a separator byte and splitting the
# result positionally in shell. jq and the shell therefore agree on field order
# by convention alone. This rig reorders each array, one transposition at a
# time, and reports whether the suite notices.
#
# Run it before believing any claim about that coupling in either direction.
# Phase M review asserted twice that a reorder leaves the suite green; this rig
# showed the existing suite goes red on all twelve transpositions, which is why
# no structural test was ever added.
#
# Usage:
#   scripts/context-guard/field-order-mutation.sh <worktree> [extra-suite ...]
#
#   <worktree>     a git worktree to mutate. It MUST NOT be the main checkout,
#                  and this script refuses if it is. That refusal is not
#                  defensive padding: an earlier version edited the tracked
#                  hook in place, the ten-minute tool timeout killed its
#                  wrapper but not the script, and the orphan went on mutating
#                  a tracked file twice more unnoticed. Make one with
#                  `git worktree add --detach <path> HEAD`.
#
#   [extra-suite]  further .bats files to run beside the hook's own suite,
#                  each reported in its own column. Use this to score a
#                  candidate tripwire against the coverage that already exists.
#
# Reads $BATS_BIN for the bats executable, default "$HOME/bats/bin/bats".
set -u

WT=${1:?usage: field-order-mutation.sh <worktree> [extra-suite ...]}
shift
# The extra suites stay in "$@" rather than being copied into an array. Under
# `set -u`, expanding an EMPTY array is an unbound-variable error on bash 3.2,
# which is what the macOS runner still ships; "$@" is safe empty everywhere.

BATS=${BATS_BIN:-$HOME/bats/bin/bats}
HOOK=handoff/hooks/context-guard.sh
OWN_SUITE=handoff/tests/context-guard.bats

# --- refuse to touch the main checkout -------------------------------------
# `git worktree list` prints the main worktree first, always. Comparing
# resolved paths rather than the strings given, so a relative argument or a
# symlink cannot slip past.
main_wt=$(git worktree list | head -1 | awk '{print $1}')
main_wt=$(cd "$main_wt" && pwd) || exit 9
target=$(cd "$WT" && pwd) || {
  printf 'mutation: no such directory: %s\n' "$WT" >&2
  exit 9
}
if [ "$target" = "$main_wt" ]; then
  printf 'mutation: REFUSING — %s is the main checkout.\n' "$target" >&2
  printf 'mutation: make a scratch one:  git worktree add --detach <path> HEAD\n' >&2
  exit 9
fi

cd "$target" || exit 9
[ -f "$HOOK" ] || {
  printf 'mutation: %s holds no %s\n' "$target" "$HOOK" >&2
  exit 9
}

ORIG="$target/.orig-context-guard"
cp "$HOOK" "$ORIG"
restore() { cp "$ORIG" "$HOOK"; }
trap restore EXIT

# --- locate the two arrays by PATTERN, never by line number ----------------
# Line numbers drift with every edit to the file, and a rig that mutates the
# wrong line still produces a full table of plausible results.
find_one() {
  local pattern=$1 name=$2 hits
  hits=$(grep -c -- "$pattern" "$ORIG")
  if [ "$hits" != "1" ]; then
    printf 'mutation: expected exactly 1 %s line, found %s\n' "$name" "$hits" >&2
    exit 9
  fi
  grep -n -- "$pattern" "$ORIG" | cut -d: -f1
}
# shellcheck disable=SC2016 # a literal search pattern, not an expansion
CFG_LINE=$(find_one 'cfg=$(jq -r' 'configuration array')
# shellcheck disable=SC2016 # a literal search pattern, not an expansion
PAY_LINE=$(find_one 'payload=$(printf' 'payload array')

CFG=('.windowTokens' '.thresholdPct' '.thresholdTokens' '.maxBytes')
PAY=('.agent_id // ""' '.transcript_path // ""' '.session_id // "unknown"' '.cwd // ""')
Q="'"

# Assert the fields this rig believes in are actually on the lines it found.
# Without this the rig happily "mutates" an array whose shape has changed and
# reports on something that no longer exists.
for f in "${CFG[@]}"; do
  if ! sed -n "${CFG_LINE}p" "$ORIG" | grep -qF -- "$f"; then
    printf 'mutation: configuration array has no %s — this rig is out of date\n' "$f" >&2
    exit 9
  fi
done

# The format strings below are the TEXT OF THE HOOK being written out, so every
# `$(...)` and `$US` in them is literal by design — expanding any of them here
# would emit a mutant carrying this rig's values instead of the hook's code.
build_cfg() {
  # shellcheck disable=SC2016 # emitting hook source; expansion would be the bug
  printf '  cfg=$(jq -r --arg US "$US" %s.contextGuard // {} | [%s, %s, %s, %s] | map(. // "" | tostring) | join($US)%s "$1" 2>/dev/null)\n' \
    "$Q" "${CFG[$1]}" "${CFG[$2]}" "${CFG[$3]}" "${CFG[$4]}" "$Q"
}
build_pay() {
  # shellcheck disable=SC2016 # emitting hook source; expansion would be the bug
  printf 'payload=$(printf %s%%s%s "$input" | jq -r --arg US "$US" %s[%s, %s, %s, %s] | map(tostring) | join($US)%s)\n' \
    "$Q" "$Q" "$Q" "${PAY[$1]}" "${PAY[$2]}" "${PAY[$3]}" "${PAY[$4]}" "$Q"
}

# The replacement text arrives NEWLINE-TERMINATED and must stay that way. An
# earlier version dropped it, fusing the new line with the one below; every
# mutant was then a syntactically broken script, every suite failed, and the
# table read as a flawless sweep of catches.
apply() {
  {
    head -n $(( $1 - 1 )) "$ORIG"
    printf '%s' "$2"
    tail -n +$(( $1 + 1 )) "$ORIG"
  } > "$HOOK"
}

runs() {
  if bash "$BATS" "$1" >/dev/null 2>&1; then printf 'GREEN'; else printf 'RED'; fi
}

printf '%-9s %-9s %-8s %-9s' ARRAY SWAP PARSES OWN-SUITE
for s in "$@"; do printf ' %-16s' "$(basename "$s" .bats)"; done
printf '\n'

for which in config payload; do
  if [ "$which" = config ]; then LN=$CFG_LINE; else LN=$PAY_LINE; fi
  for pair in "0 1" "0 2" "0 3" "1 2" "1 3" "2 3"; do
    i=${pair% *}
    j=${pair#* }
    o=(0 1 2 3)
    t=${o[i]}
    o[i]=${o[j]}
    o[j]=$t
    if [ "$which" = config ]; then
      line=$(build_cfg "${o[0]}" "${o[1]}" "${o[2]}" "${o[3]}")
    else
      line=$(build_pay "${o[0]}" "${o[1]}" "${o[2]}" "${o[3]}")
    fi
    apply "$LN" "$line
"
    # A mutant that does not parse proves nothing: every suite fails on a
    # broken script exactly as it would on a caught defect.
    if ! bash -n "$HOOK" 2>/dev/null; then
      printf '%-9s %-9s %-8s %-9s\n' "$which" "$i<->$j" NO -
      restore
      continue
    fi
    # A mutation that changed nothing is a silent false green.
    if cmp -s "$HOOK" "$ORIG"; then
      printf '%-9s %-9s %-8s %-9s\n' "$which" "$i<->$j" NO-OP -
      continue
    fi
    printf '%-9s %-9s %-8s %-9s' "$which" "$i<->$j" yes "$(runs "$OWN_SUITE")"
    for s in "$@"; do printf " %-16s" "$(runs "$s")"; done
    printf '\n'
    restore
  done
done

restore
printf '\ncontrol: unmutated hook -> own-suite=%s' "$(runs "$OWN_SUITE")"
for s in "$@"; do printf "  %s=%s" "$(basename "$s" .bats)" "$(runs "$s")"; done
printf '\n'
printf 'A control that is not GREEN means the rig, not the hook, is broken.\n'
