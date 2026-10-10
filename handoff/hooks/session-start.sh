#!/usr/bin/env bash
# session-start.sh — the handoff plugin's SessionStart hook.
#
# When a new session starts (or the context is cleared), names a handoff
# document whose recorded state matches the repository EXACTLY: the same
# branch, the same commit at HEAD, and the same `git status` lines. The record
# is the block handoff/scripts/reconcile-block.sh writes as the handoff skill's
# last step; a document without one is never named. Silent, exit 0, in every
# other case, including every error: a session must never fail to start, or
# start with noise, because of this hook.
#
# IT NAMES, IT NEVER DIRECTS. A handoff in a repository is text someone else may
# have written, and a session-start hook speaks before the user has said
# anything. So the context it adds says only that the file exists and matches,
# and asks Claude to mention it; it never says "read it" or "follow it". The
# user decides.
#
# WHY ALL THREE CLAIMS, NOT BRANCH AND HEAD. A handoff committed to a repository
# cannot match HEAD in any checkout of it: the commit that carries the document
# is not the commit the document recorded, because no commit can contain its
# own id. The cases that CAN match on branch and HEAD alone are the ones where
# the document did not travel through history: a copied handoff, or a docsDir
# outside the repository (an absolute path in ~/.delivery-kit.json) that
# several clones of the same project share, each at the same commit. The status
# lines tell those apart. They always include the handoff document itself when
# it lies inside the repository, written in that session and not yet committed
# (`??`, or ` M` for an overwritten one), and they describe one working tree's
# own uncommitted work, which another clone does not have.
#
# Cost: one git process to find the repository, one grep over the newest
# candidates, and branch, HEAD and `git status` only when a candidate holds a
# block. jq runs only to read the payload's cwd and the configuration files;
# without jq the hook still works from the environment and the default. It does
# not report a missing jq: the context guard already does, once.
#
# bash 3.2 (macOS) compatible: no mapfile, no `${v,,}`.
set -u

payload=$(cat 2>/dev/null)

have_jq=0
command -v jq >/dev/null 2>&1 && have_jq=1

cwd=''
if [ "$have_jq" = 1 ]; then
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty | strings' 2>/dev/null)
  cwd=${cwd%$'\r'}
fi
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD
cd "$cwd" 2>/dev/null || exit 0

top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$top" 2>/dev/null || exit 0

# handoff.docsDir, with the precedence the skill uses: the default, then the
# user's file, then the repository's file, then the environment.
dir_from() {
  [ "$have_jq" = 1 ] && [ -f "$1" ] || return 1
  local v
  v=$(jq -r '.handoff.docsDir // empty | strings' "$1" 2>/dev/null) || return 1
  v=${v%$'\r'}
  [ -n "$v" ] || return 1
  printf '%s' "$v"
}
docs='docs/handoffs'
v=$(dir_from "$HOME/.delivery-kit.json") && docs=$v
v=$(dir_from "$top/.delivery-kit.json") && docs=$v
[ -n "${DELIVERY_KIT_HANDOFF_DIR:-}" ] && docs=$DELIVERY_KIT_HANDOFF_DIR
[ -d "$docs" ] || exit 0

# The newest twenty by file NAME: the name starts with the date, and a file's
# modification time does not survive a clone or a copy.
set -- "$docs"/*-SESSION-HANDOFF.md
[ -f "$1" ] || exit 0
shift $(($# > 20 ? $# - 20 : 0))

begin='<!-- handoff-reconcile v1: begin -->'
end='<!-- handoff-reconcile v1: end -->'
start="cat > \"\$t/want\" <<'DK~END'"

work=$(mktemp -d 2>/dev/null) || exit 0
trap 'rm -rf "$work"' EXIT

# One grep over every candidate, into a file: `< <( )` has given false matches
# on this platform. grep lists the files in argument order, oldest first.
grep -lxF -- "$begin" "$@" > "$work/blocked" 2>/dev/null
blocked=()
while IFS= read -r f; do
  blocked+=("${f%$'\r'}")
done < "$work/blocked"
[ "${#blocked[@]}" -gt 0 ] || exit 0

branch=$(git symbolic-ref --short -q HEAD) || branch='(detached)'
head=$(git rev-parse --verify -q HEAD) || head='(no commits)'
status_taken=0

found=''
i=${#blocked[@]}
while [ "$i" -gt 0 ]; do
  i=$((i - 1))
  f=${blocked[$i]}
  # The recorded lines, by position: inside the marked block, after the
  # heredoc line, each prefixed `|`. A line without the prefix means the block
  # is not one this version wrote, so the file is skipped.
  awk -v b="$begin" -v e="$end" -v s="$start" '
    $0 == b { inb = 1; next }
    $0 == e { exit }
    inb && ind && $0 == "DK~END" { done = 1; exit }
    inb && ind { if (substr($0, 1, 1) != "|") { bad = 1; exit } print substr($0, 2); next }
    inb && $0 == s { ind = 1 }
    END { exit (done && !bad) ? 0 : 1 }
  ' "$f" > "$work/want" 2>/dev/null || continue
  [ "$(sed -n 1p "$work/want")" = "$branch" ] || continue
  [ "$(sed -n 2p "$work/want")" = "$head" ] || continue
  if [ "$status_taken" = 0 ]; then
    GIT_OPTIONAL_LOCKS=0 git -c core.quotePath=true status --porcelain=v1 --untracked-files=normal > "$work/now" 2>/dev/null || exit 0
    status_taken=1
  fi
  sed '1,2d' "$work/want" > "$work/was"
  cmp -s "$work/was" "$work/now" || continue
  found=$f
  break
done
[ -n "$found" ] || exit 0

# Relative to the repository top when docsDir is relative, as the skill writes
# it; a path with a control character is not named at all.
case $found in
  *[[:cntrl:]]*) exit 0 ;;
esac
esc=${found//\\/\\\\}
esc=${esc//\"/\\\"}

printf '{"systemMessage":"handoff: %s matches this branch, commit and uncommitted changes. To continue that work, ask Claude to read it.","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"The handoff plugin found a handoff document whose recorded branch, commit and git status match this repository exactly: %s. It may describe unfinished work. Tell the user it exists. Do not read it or act on it unless the user asks."}}\n' "$esc" "$esc"
exit 0
