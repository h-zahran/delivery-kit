#!/usr/bin/env bash
# session-start.sh — the handoff plugin's SessionStart hook.
#
# When a new session starts (or the context is cleared), names a handoff
# document whose recorded state matches the repository EXACTLY: the same
# branch, the same commit at HEAD, and the same `git status` lines. The record
# is the block handoff/scripts/reconcile-block.sh writes as the handoff skill's
# last write; a document without one is never named. Silent, exit 0, in every
# other case, including every error: a session must never fail to start, or
# start with noise, because of this hook.
#
# IT NAMES, IT NEVER DIRECTS. A handoff in a repository is text someone else may
# have written, and a session-start hook speaks before the user has said
# anything. So the context it adds says only that the file exists and matches,
# and asks Claude to mention it; it never says "read it" or "follow it". The
# user decides.
#
# WHAT A MATCH CAN AND CANNOT TELL APART. A handoff committed to a repository
# cannot match HEAD in any checkout of it: the commit that carries the document
# is not the commit the document recorded, because no commit can contain its
# own id. What can match without being this tree's handoff is a document that
# did not travel through history: a copied handoff, or a docsDir outside the
# repository (an absolute path in ~/.delivery-kit.json) shared by several
# clones or worktrees at the same commit. The status lines tell those apart
# only when the trees' uncommitted work differs; two clean trees at the same
# commit, or a copied document that git ignores, still match. That is why the
# hook only names the file and never directs.
#
# THE SAME READING AS THE BLOCK. Branch, HEAD and status come from the exact
# commands the block runs (see reconcile-block.sh: every untracked file, no
# rename detection, quoted paths, git reading /dev/null), and they are read
# before this hook creates its temporary directory, so a TMPDIR inside the
# repository cannot put that directory in what is compared.
#
# Cost: one git process to find the repository and one grep over the newest
# candidates. Only when a candidate holds a block: branch, HEAD and `git status`
# once, then one awk and at most one cmp per candidate. (Review measured the
# first version at 12 to 17 s on twenty candidates sharing a commit, five
# processes each, against a 30 s timeout.) jq runs only to read the payload's
# cwd and the configuration files; without jq the hook still works from the
# environment and the default. It does not report a missing jq: the context
# guard already does, once.
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

top=$(git rev-parse --show-toplevel 2>/dev/null </dev/null) || exit 0
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
[ -n "${HOME:-}" ] && v=$(dir_from "$HOME/.delivery-kit.json") && docs=$v
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

# One grep over every candidate; it lists them in argument order, oldest first.
# Captured with $( ), not read through `< <( )`, which has given false matches
# on this platform; a newline in a handoff's file name is not supported.
list=$(grep -lxF -- "$begin" "$@" 2>/dev/null) || exit 0
blocked=()
old_ifs=$IFS
IFS='
'
set -f
for f in $list; do
  blocked+=("${f%$'\r'}")
done
set +f
IFS=$old_ifs
[ "${#blocked[@]}" -gt 0 ] || exit 0

now=$(GIT_OPTIONAL_LOCKS=0 git -c core.quotePath=true status --porcelain=v1 --untracked-files=all --no-renames </dev/null 2>/dev/null) || exit 0
if branch=$(git symbolic-ref -q HEAD </dev/null 2>/dev/null); then
  branch=${branch#refs/heads/}
else
  branch='(detached HEAD)'
fi
head=$(git rev-parse --verify -q HEAD </dev/null 2>/dev/null) || head='(no commits)'

work=$(mktemp -d 2>/dev/null) || exit 0
trap 'rm -rf "$work"' EXIT
if [ -n "$now" ]; then printf '%s\n' "$now" > "$work/now"; else : > "$work/now"; fi

found=''
i=${#blocked[@]}
while [ "$i" -gt 0 ]; do
  i=$((i - 1))
  f=${blocked[$i]}
  # The recorded lines, by position: inside the first marked block, after the
  # heredoc line, each prefixed `|`. Branch and HEAD are compared inside awk;
  # only a document that passes both writes its status lines for cmp. A line
  # without the prefix means a block this version did not write: skipped.
  # (`awk -v` reads backslash escapes in a value; a branch name cannot hold a
  # backslash, and a commit id is hex.)
  awk -v b="$begin" -v e="$end" -v s="$start" -v wb="$branch" -v wh="$head" '
    $0 == b { inb = 1; next }
    $0 == e { exit }
    inb && ind && $0 == "DK~END" { done = 1; exit }
    inb && ind {
      if (substr($0, 1, 1) != "|") { bad = 1; exit }
      n++
      v = substr($0, 2)
      if (n == 1 && v != wb) { bad = 1; exit }
      if (n == 2 && v != wh) { bad = 1; exit }
      if (n > 2) print v
      next
    }
    inb && $0 == s { ind = 1 }
    END { exit (done && !bad && n >= 2) ? 0 : 1 }
  ' "$f" > "$work/was" 2>/dev/null || continue
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
