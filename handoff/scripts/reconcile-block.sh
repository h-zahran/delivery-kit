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
# command that holds no backslash. That command pipes the block into bash, so
# bash reads its script from stdin, and a command inside the block that read
# stdin would eat the rest of the script. None does: every git, sed, cmp and
# diff in it names its input.
#
# NOTHING FROM GIT IS EVER CODE. A branch name may hold `$(`, a quote, `>` or a
# backtick (git allows all four; PR #68's blocking finding was exactly this).
# The recorded values go into a single-quoted heredoc, so the shell reads them
# as bytes, and each line is prefixed `|`, so no value can equal the heredoc's
# terminator or the closing fence. The terminator holds `~`, which git refuses
# in a ref name, as a second guard. `git status` itself C-quotes a path holding
# a control character, a quote, a backslash or any byte above 0x7f
# (core.quotePath=true, pinned on both sides), so no path breaks a line.
#
# THE DOCUMENT RECORDS ITSELF. It is written before this runs, so its own line
# (`??` when new, ` M` when an older handoff was overwritten) is in the status
# taken here. Adding the block changes the document's content, never its status
# letters, so the record stays true after the write that carries it. Status, not
# content: a further edit to a path that was already modified is not seen. The
# block says so where the reader will see it.
#
# THE SAME COMMANDS ON BOTH SIDES. The block reads the state with the exact
# command lines used here (GIT_OPTIONAL_LOCKS=0 so it never rewrites the index,
# `-c core.quotePath=true`, `--porcelain=v1 --untracked-files=normal`), so a
# config difference on the resuming machine cannot read as a MISMATCH.
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
# Both directories in this shell's own form, so the prefix test below compares
# like with like (git prints D:/x on Windows, the shell spells it /d/x).
docdir=$(cd "$(dirname "$doc")" && pwd -P) || die "cannot enter the document's directory"
docbase=$(basename "$doc")
doc="$docdir/$docbase"
topdir=$(cd "$top" && pwd -P) || die "cannot enter the repository top level"

begin='<!-- handoff-reconcile v1: begin -->'
end='<!-- handoff-reconcile v1: end -->'

# A begin with no end below it is a document someone edited by hand. Cutting
# from the begin to the end of the file would destroy whatever follows, so
# refuse and leave the file as it is.
nb=$(grep -cxF -- "$begin" "$doc")
ne=$(grep -cxF -- "$end" "$doc")
[ "$nb" = "$ne" ] || die "the document has $nb begin and $ne end markers; fix it by hand, nothing was written"

cd "$topdir" || die "cannot enter the repository top level"

# The status is taken FIRST, before the temporary file below exists, so the
# record never lists a file of this script's own.
work=$(mktemp -d) || die "mktemp failed"
trap 'rm -rf "$work"' EXIT
branch=$(git symbolic-ref --short -q HEAD) || branch='(detached)'
head=$(git rev-parse --verify -q HEAD) || head='(no commits)'
GIT_OPTIONAL_LOCKS=0 git -c core.quotePath=true status --porcelain=v1 --untracked-files=normal > "$work/status" ||
  die "git status failed"

case "$docdir/" in
  "$topdir"/*) rel=${docdir#"$topdir"}; rel=${rel#/}; rel=${rel:+$rel/}$docbase ;;
  *) rel=$doc ;;
esac
# For the single-quoted path in the printed command: ' becomes '\''.
q="'\\''"
qrel=${rel//\'/$q}

{
  printf '%s\n' "$begin"
  cat <<'EOF'
## Reconcile

Written by the handoff plugin as the handoff's last step. Step 1 of the Resume
protocol runs it: it reads this file and git, and changes nothing.

EOF
  printf '%s\n' '~~~sh'
  printf '%s\n' "cd \"\$(git rev-parse --show-toplevel)\" && awk 'f && /^\`\`\`\$/ {exit} f; /^\`\`\`bash handoff-reconcile\$/ {f=1}' '$qrel' | bash"
  printf '%s\n' '~~~'
  cat <<'EOF'

It checks the branch, the commit and the `git status` lines against the ones
recorded below, and prints MATCH or MISMATCH for each. It sees which paths
changed, not what changed inside them.

```bash handoff-reconcile
# Compares the state this handoff recorded with the repository now. Read-only.
# The lines between the heredoc markers are data, never code.
top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo 'RECONCILE: cannot run: not inside a git repository'; exit 2; }
cd "$top" || exit 2
t=$(mktemp -d) || exit 2
trap 'rm -rf "$t"' EXIT
cat > "$t/want" <<'DK~END'
EOF
  printf '|%s\n' "$branch" "$head"
  sed 's/^/|/' "$work/status"
  cat <<'EOF'
DK~END
b=$(git symbolic-ref --short -q HEAD) || b='(detached)'
h=$(git rev-parse --verify -q HEAD) || h='(no commits)'
GIT_OPTIONAL_LOCKS=0 git -c core.quotePath=true status --porcelain=v1 --untracked-files=normal > "$t/now" ||
  { echo 'RECONCILE: cannot run: git status failed'; exit 2; }
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
    *) git merge-base --is-ancestor "$wh" HEAD 2>/dev/null && more=' (the recorded commit is behind it: commits were added since the handoff)' ;;
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
# document minus any old block, plus the new one; then swap it in whole.
tmp="$docdir/.$docbase.reconcile-tmp"
cp -p "$doc" "$tmp" 2>/dev/null || die "cannot write beside the document"
trap 'rm -rf "$work" "$tmp"' EXIT
{
  awk -v b="$begin" -v e="$end" '$0 == b {skip = 1} !skip {print} $0 == e {skip = 0}' "$doc" |
    awk 'NF {for (; blank > 0; blank--) print ""; print; next} {blank++}'
  printf '\n'
  cat "$work/block"
} > "$tmp" || die "cannot write beside the document"
mv -f "$tmp" "$doc" || die "cannot replace the document"
printf 'reconcile block written to %s\n' "$rel"
