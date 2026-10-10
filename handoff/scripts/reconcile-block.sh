#!/usr/bin/env bash
# reconcile-block.sh <handoff-document>
#
# Records what the repository looks like right now into a handoff document, as
# a block the next session runs to check it. Three claims: the branch, the
# commit at HEAD, and the `git status` lines. Run by the handoff skill as its
# LAST write, so nothing the skill does afterwards can make its own record
# wrong. Prints one line naming the document; changes nothing but that file.
#
# WHY A SCRIPT IN THE DOCUMENT, and not a subcommand of this file. The session
# that resumes cannot reach this plugin by path: `${CLAUDE_PLUGIN_ROOT}` is
# substituted in a plugin skill's text, not in a handoff document, and the
# absolute path it expands to names a plugin VERSION directory that the next
# update removes. And it cannot be handed the values to paste: the Bash tool
# drops backslashes from pasted text, and `git status` C-quotes an unusual
# path with exactly those. So the check travels inside the document, and
# step 1 of the Resume protocol runs it straight from the file with a short
# command. That command holds no backslash unless the document's own path
# holds a single quote (written `'\''`).
#
# THE COMMAND PIPES THE BLOCK INTO BASH, so bash reads its script from stdin,
# and anything inside the block that read stdin would eat the rest of the
# script. sed, cmp and diff name their files. git is the trap: it runs hooks the
# user configured, and review measured a `core.fsmonitor` hook reading 935
# bytes of the script, after which the block printed nothing and exited 0. So
# every git call in the block reads /dev/null. The command also finds the block
# only AFTER the begin marker, the same block the session-start hook parses, so
# a fence quoted earlier in the document is never the one that runs; and when it
# finds no block it says so and exits 2, rather than feeding bash nothing, which
# exits 0 in silence.
#
# NOTHING FROM GIT IS EVER CODE. A branch name may hold `$(`, a quote, `>` or a
# backtick (git allows all four; PR #68's blocking finding was exactly this).
# The recorded values go into a single-quoted heredoc, so the shell reads them
# as bytes, and each line is prefixed `|`, so no value can equal the heredoc's
# terminator or the closing fence. The terminator holds `~`, which git refuses
# in a ref name, as a second guard. `git status` itself C-quotes a path holding
# a control character, a quote, a backslash or any byte above 0x7f
# (core.quotePath=true, pinned on both sides), so no path breaks a line. A
# detached HEAD is recorded as `(detached HEAD)`, which holds a space, and git
# refuses a space in a ref name, so no branch can be called that.
#
# EVERY UNTRACKED FILE, NOT EVERY UNTRACKED DIRECTORY. With git's default,
# `--untracked-files=normal`, a new directory is one line (`?? docs/`), and any
# file added inside it later changes nothing: review measured a MATCH, and the
# hook naming the document, after two files were added under such directories.
# On a repository's first handoff the handoff directory is itself one of them.
# So both sides list every file (`--untracked-files=all`), at the cost of a
# longer record when a large untracked tree is not ignored.
#
# THE DOCUMENT RECORDS ITSELF, when git lists it. It is written before this
# runs, so its line is in the status taken here: `??` when it is untracked,
# ` M` when an older tracked handoff was overwritten, and none at all when git
# ignores it. Adding the block changes the document's content, never its status
# letters, so the record stays true after the write that carries it. Status, not
# content: a further edit to a path that was already modified is not seen. The
# block says so where the reader will see it.
#
# THE SAME COMMANDS ON BOTH SIDES. The block reads the state with the exact
# command lines used here: GIT_OPTIONAL_LOCKS=0 so it never rewrites the index,
# `-c core.quotePath=true`, `--porcelain=v1 --untracked-files=all
# --no-renames`. `--no-renames` because `status.renames` is configurable, and
# review measured a rename read as MISMATCH once the setting differed. The
# branch comes from `git symbolic-ref -q HEAD` with `refs/heads/` cut off, not
# from `--short`, which prints `heads/main` once a tag called `main` exists.
#
# THE STATE IS READ FIRST, before this script or the block creates any
# temporary file, so a TMPDIR inside the repository cannot put one in the
# record.
#
# bash 3.2 (macOS) compatible: no mapfile, no `${v,,}`, no `sed -i`.
set -u

die() {
  printf 'reconcile-block: %s\n' "$1" >&2
  exit "${2:-1}"
}

[ $# -eq 1 ] || die "usage: reconcile-block.sh <handoff-document>" 2
doc=$1
[ -f "$doc" ] || die "not a file: $doc"

top=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository"
docdir=$(CDPATH='' cd -- "$(dirname -- "$doc")" && pwd -P) || die "cannot enter the document's directory"
docbase=$(basename -- "$doc")
doc="$docdir/$docbase"

begin='<!-- handoff-reconcile v1: begin -->'
end='<!-- handoff-reconcile v1: end -->'

# The markers must come in begin/end pairs, in that order. Anything else is a
# document someone edited by hand, and cutting from a begin to wherever the
# next end is, or to the end of the file, would destroy what follows. Refuse
# and leave the file as it is. (Review measured the old count-only check
# passing `end … begin …` and losing the text after the begin.)
awk -v b="$begin" -v e="$end" '
  $0 == b { if (open) bad = 1; open = 1 }
  $0 == e { if (!open) bad = 1; open = 0 }
  END { exit (bad || open) ? 1 : 0 }
' "$doc" || die "the document's reconcile markers are unpaired or out of order; fix it by hand, nothing was written"

cd "$top" || die "cannot enter the repository top level"

st=$(GIT_OPTIONAL_LOCKS=0 git -c core.quotePath=true status --porcelain=v1 --untracked-files=all --no-renames </dev/null) ||
  die "git status failed"
if branch=$(git symbolic-ref -q HEAD </dev/null); then
  branch=${branch#refs/heads/}
else
  branch='(detached HEAD)'
fi
head=$(git rev-parse --verify -q HEAD </dev/null) || head='(no commits)'

# The printed path: relative to the top when the document lies in this
# repository, as git itself says (two `pwd -P` results disagree across a mount
# alias such as /tmp, or in letter case on Windows); absolute otherwise.
if [ "$(git -C "$docdir" rev-parse --show-toplevel 2>/dev/null)" = "$top" ]; then
  rel=$(git -C "$docdir" rev-parse --show-prefix)$docbase
else
  rel=$doc
fi
q="'\\''"
qrel=${rel//\'/$q}

work=$(mktemp -d) || die "mktemp failed"
trap 'rm -rf "$work"' EXIT

{
  printf '%s\n' "$begin"
  cat <<'EOF'
## Reconcile

Written by the handoff plugin as the handoff's last write. Step 1 of the Resume
protocol runs the one-line command below: it reads this file and git, and
changes nothing.

EOF
  printf '%s\n' '~~~sh'
  printf '%s\n' "cd \"\$(git rev-parse --show-toplevel)\" && awk 'm && f && /^\`\`\`\$/ {exit} m && f; m && /^\`\`\`bash handoff-reconcile\$/ {f=1} \$0 == \"$begin\" {m=1} END {if (!f) print \"echo RECONCILE: cannot run, no reconcile block found; exit 2\"}' '$qrel' | bash"
  printf '%s\n' '~~~'
  cat <<'EOF'

It checks the branch, the commit and the `git status` lines against the ones
recorded below, and prints MATCH or MISMATCH for each. It sees which paths
changed, not what changed inside them. Its last line starts `RECONCILE:`; if
it does not, the check did not run.

```bash handoff-reconcile
# Compares the state this handoff recorded with the repository now. Read-only.
# The lines between the heredoc markers are data, never code. Every git call
# reads /dev/null: this script arrives on stdin, and a git hook would eat it.
top=$(git rev-parse --show-toplevel 2>/dev/null </dev/null) || { echo 'RECONCILE: cannot run: not inside a git repository'; exit 2; }
cd "$top" || exit 2
now=$(GIT_OPTIONAL_LOCKS=0 git -c core.quotePath=true status --porcelain=v1 --untracked-files=all --no-renames </dev/null) ||
  { echo 'RECONCILE: cannot run: git status failed'; exit 2; }
if b=$(git symbolic-ref -q HEAD </dev/null); then b=${b#refs/heads/}; else b='(detached HEAD)'; fi
h=$(git rev-parse --verify -q HEAD </dev/null) || h='(no commits)'
t=$(mktemp -d) || { echo 'RECONCILE: cannot run: mktemp failed'; exit 2; }
trap 'rm -rf "$t"' EXIT
cat > "$t/want" <<'DK~END'
EOF
  printf '|%s\n' "$branch" "$head"
  [ -z "$st" ] || printf '%s\n' "$st" | sed 's/^/|/'
  cat <<'EOF'
DK~END
if [ -n "$now" ]; then printf '%s\n' "$now" > "$t/now"; else : > "$t/now"; fi
wb=$(sed -n '1s/^|//p' "$t/want")
wh=$(sed -n '2s/^|//p' "$t/want")
sed '1,2d; s/^|//' "$t/want" > "$t/was"
ok=1
if [ "$wb" = "$b" ]; then
  printf 'MATCH    branch: %s\n' "$b"
else
  ok=0; printf 'MISMATCH branch: recorded %s, now %s\n' "$wb" "$b"
fi
if [ "$wh" = "$h" ]; then
  printf 'MATCH    head: %s\n' "$h"
else
  ok=0; more=''
  case $wh in
    *[!0-9a-f]* | '') ;;
    *) git merge-base --is-ancestor "$wh" HEAD </dev/null 2>/dev/null && more=' (the recorded commit is behind it: commits were added since the handoff)' ;;
  esac
  printf 'MISMATCH head: recorded %s, now %s%s\n' "$wh" "$h" "$more"
fi
n=$(grep -c '' "$t/was")
if cmp -s "$t/was" "$t/now"; then
  printf 'MATCH    tree: %s status lines, as recorded\n' "$n"
else
  ok=0; printf 'MISMATCH tree: the status lines differ (< recorded only, > now only):\n'
  diff "$t/was" "$t/now"
fi
if [ "$ok" = 1 ]; then echo 'RECONCILE: MATCH'; exit 0; fi
echo 'RECONCILE: MISMATCH'
exit 1
```
EOF
  printf '%s\n' "$end"
} > "$work/block"

# Copy first, so the new file keeps the document's mode; then fill it with the
# document minus any old block, plus the new one; then swap it in whole. Only
# EMPTY lines at the end are dropped (so reruns do not pile them up); a line of
# spaces anywhere, inside a code fence included, is kept as it was. On Windows
# the awk here reads in text mode, so a CRLF document comes back LF.
tmp="$docdir/.$docbase.reconcile-tmp"
cp -p "$doc" "$tmp" 2>/dev/null || die "cannot write beside the document"
trap 'rm -rf "$work" "$tmp"' EXIT
{
  awk -v b="$begin" -v e="$end" '$0 == b {skip = 1} !skip {print} $0 == e {skip = 0}' "$doc" |
    awk 'length($0) {for (; blank > 0; blank--) print ""; print; next} {blank++}'
  printf '\n'
  cat "$work/block"
} > "$tmp" || die "cannot write beside the document"
mv -f "$tmp" "$doc" || die "cannot replace the document"
printf 'reconcile block written to %s\n' "$rel"
