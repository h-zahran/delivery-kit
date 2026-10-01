# Quickstart: validate the 1.3.0 stamp

Run from the repository root on the feature branch, in Git Bash or any bash 5.
The blocks below are ONE script: extract every `bash` block in order into a
file and run that file with `bash` (do not paste into an interactive shell —
a failure exits the shell). Each check prints its contract clause
([contracts/release-stamp.md](contracts/release-stamp.md)) and `ok`, or stops
with `FAIL`. The whole script runs the house suite (block 6), which takes
about eight to ten minutes: run it in the background or with a long timeout.

## 1. Setup

```bash
set -u
BASE=d9a085e33a52c9333131a6e37b1b778a5104e967
SPEC_DIR=specs/022-release-pipeline-1-3-0
fail() { echo "FAIL $*"; exit 1; }
CLEANUP=()
wt=""
trap '[ -n "$wt" ] && { git worktree remove --force "$wt" 2>/dev/null || { rm -rf -- "$wt"; git worktree prune; }; }; for p in "${CLEANUP[@]}"; do [ -n "$p" ] && rm -rf -- "$p"; done' EXIT
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || fail "base $BASE not found"
[ -f .claude-plugin/marketplace.json ] || fail "not at the repository root"
```

## 2. The three version sites (S1–S4, S10)

```bash
jq empty .claude-plugin/marketplace.json || fail "S10 marketplace.json does not parse"
jq empty pipeline/.claude-plugin/plugin.json || fail "S10 plugin.json does not parse"
echo "S10 ok"

got=$(jq -r '.plugins[] | "\(.name) \(.version)"' .claude-plugin/marketplace.json | tr -d '\r')
want=$(printf 'handoff 2.2.0\npipeline 1.3.0')
[ "$got" = "$want" ] || fail "S1 marketplace lists: $got"
echo "S1 ok"

v=$(jq -r .version pipeline/.claude-plugin/plugin.json | tr -d '\r')
[ "$v" = "1.3.0" ] || fail "S2 plugin.json version is $v"
echo "S2 ok"

h=$(grep -m1 '^## ' pipeline/CHANGELOG.md | tr -d '\r')
[ "$h" = "## [1.3.0] - 2026-10-01" ] || fail "S3 first heading is: $h"
echo "S3 ok"

n=$(grep -c -- '^## \[Unreleased\]' pipeline/CHANGELOG.md)
[ "$n" = "0" ] || fail "S4 Unreleased headings: $n"
echo "S4 ok"
```

## 3. The changelog text did not move (S5)

The whole file is compared, not a region: the `d9a085e` file with its one
heading rewritten must equal the branch file byte for byte. The control
proves the comparison can fail.

```bash
want_file=$(mktemp); CLEANUP+=("$want_file")
git show "$BASE:pipeline/CHANGELOG.md" \
  | sed 's/^## \[Unreleased\]$/## [1.3.0] - 2026-10-01/' > "$want_file"
[ "$(grep -c -F -x '## [1.3.0] - 2026-10-01' "$want_file")" = "1" ] \
  || fail "S5 rewrite of the base heading did not land exactly once"
cmp -s "$want_file" pipeline/CHANGELOG.md || fail "S5 changelog differs beyond the heading"
ctl=$(mktemp) && [ -n "$ctl" ] || fail "S5 control: mktemp"
CLEANUP+=("$ctl"); sed '20s/$/ x/' "$want_file" > "$ctl"
cmp -s "$ctl" pipeline/CHANGELOG.md; rc_ctl=$?
[ "$rc_ctl" = "1" ] || fail "S5 control: cmp returned $rc_ctl, not 1 (differ)"
rm -f "$want_file" "$ctl"
echo "S5 ok (control red)"
```

## 4. The change set (S6, S7)

Only this feature's own spec directory is exempt — another feature's spec is
a change like any other. `git diff` sees tracked files only, so untracked
files outside the spec directory are checked separately. Files git
ignores — through `.gitignore` or this clone's own `.git/info/exclude`,
the run directory under `.delivery-kit/` among them — are left out on
purpose: `git add` by name never stages them.

```bash
numstat=$(git diff --numstat "$BASE" -- . ":(exclude)$SPEC_DIR/" | tr -d '\r' | sort)
want_ns=$(printf '1\t1\t.claude-plugin/marketplace.json\n1\t1\tpipeline/.claude-plugin/plugin.json\n1\t1\tpipeline/CHANGELOG.md' | sort)
[ "$numstat" = "$want_ns" ] || fail "S6 change set is: $numstat"
untracked=$(git ls-files --others --exclude-standard -- . ":(exclude)$SPEC_DIR/") \
  || fail "S6 git ls-files --others failed"
[ -z "$untracked" ] || fail "S6 untracked files outside $SPEC_DIR: $untracked"
echo "S6 ok"

git diff --quiet "$BASE" -- handoff/ || fail "S7 handoff/ changed"
[ -n "$(git ls-files handoff/ | head -1)" ] || fail "S7 control: handoff/ has no tracked files"
echo "S7 ok"
```

## 5. The agreement gate (S8, S9)

`--released pipeline` is the tag run's form. It must FAIL at `d9a085e`, where
the open heading sits above 1.2.1, before its pass on the branch is believed.
The base is checked out in a temporary worktree, so the main checkout is not
touched.

```bash
out=$(bash scripts/check-versions.sh 2>&1); rc=$?
out=$(printf '%s\n' "$out" | tr -d '\r')
printf '%s\n' "$out"
[ "$rc" = "0" ] || fail "S8 rc=$rc"
[ "$(printf '%s\n' "$out" | grep -c 'state=released$')" = "2" ] || fail "S8 not both released"
echo "S8 ok"

# S9. The control demands the gate's own refusal text, not just a non-zero
# rc: a failed `cd` or a missing tool would also exit non-zero and prove
# nothing. It runs the BRANCH's copy of the gate against the base tree, so
# a release that also edits the gate proves its new copy can go red.
bash scripts/check-versions.sh --released pipeline >/dev/null 2>&1; rc=$?
[ "$rc" = "0" ] || fail "S9 --released pipeline on the branch: rc=$rc"
wt_parent=$(mktemp -d) && [ -d "$wt_parent" ] || fail "S9 control: mktemp -d"
CLEANUP+=("$wt_parent")
git worktree add -q --detach "$wt_parent/base" "$BASE" || fail "S9 control: worktree"
wt=$wt_parent/base
gate=$(pwd)/scripts/check-versions.sh
base_out=$(cd "$wt" && bash "$gate" --released pipeline 2>&1); rc_base=$?
git worktree remove --force "$wt" || fail "S9 control: worktree not removed: $wt"
wt=""
[ "$rc_base" != "0" ] || fail "S9 control: --released pipeline PASSED at $BASE"
printf '%s\n' "$base_out" | grep -q 'this tree is NOT released' \
  || fail "S9 control: base rc $rc_base without the gate's refusal: $base_out"
echo "S9 ok (branch rc 0, base rc $rc_base with the gate's refusal)"
```

## 6. The house suite (S11)

The plan line and the ok count are compared to each other and to 240; an ok
count alone can hide a test that was counted and never run. A skipped test
prints `ok … # skip`, so skips are counted on their own and must be 0.

```bash
tap=$(mktemp)
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests > "$tap" 2>&1
rc=$?
plan=$(head -1 "$tap" | tr -d '\r')
oks=$(grep -c '^ok ' "$tap")
skips=$(grep -c -i '^ok .* # skip' "$tap")
nots=$(grep -c '^not ok ' "$tap")
other=$(grep -v -E '^(ok |not ok |1\.\.|#)' "$tap" | grep -c .)
echo "S11 rc=$rc plan=$plan ok=$oks skipped=$skips not_ok=$nots non_tap=$other"
[ "$rc" = "0" ] && [ "$plan" = "1..240" ] && [ "$oks" = "240" ] && [ "$skips" = "0" ] \
  && [ "$nots" = "0" ] && [ "$other" = "0" ] \
  || fail "S11 suite (TAP kept at $tap)"
rm -f "$tap"
echo "S11 ok"
```

## 7. The commit the tag goes on (S12)

The tag recipe in the pull request runs this same check. It finds the
release commit by an exact match of its subject, refuses unless exactly one
commit matches, and refuses unless that commit's own tree says 1.3.0 in the
manifest and the changelog heading. Before the merge `TAG_REF` defaults to
`HEAD`; after it, run with `TAG_REF=origin/main` after a `git fetch`.

```bash
TAG_REF=${TAG_REF:-HEAD}
rel=$(git log --format='%H%x09%s' "$TAG_REF" \
  | awk -F'\t' '$2=="chore(release): pipeline 1.3.0" {print $1}')
n=$(printf '%s\n' "$rel" | grep -c .)
[ "$n" = "1" ] || fail "S12 $n commits on $TAG_REF match the release subject: $rel"
v=$(git show "$rel:pipeline/.claude-plugin/plugin.json" | jq -r .version | tr -d '\r')
[ "$v" = "1.3.0" ] || fail "S12 release commit $rel has plugin.json version $v"
h=$(git show "$rel:pipeline/CHANGELOG.md" | grep -m1 '^## ' | tr -d '\r')
[ "$h" = "## [1.3.0] - 2026-10-01" ] || fail "S12 release commit $rel has heading: $h"
echo "S12 ok (the tag goes on $rel)"
echo "ALL OK"
```
