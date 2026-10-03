# Quickstart: validate that the release gate closes the gaps Phase 25 left

Run from the repository root on the feature branch, in Git Bash or any bash
5. The `bash` blocks below are ONE script: extract every `bash` block in
order into a file and run that file with `bash`. Never paste it into an
interactive shell, because a failure exits the shell. Each check prints its
ID and `ok`, or stops with `FAIL`. Blocks 4 and 5 use scratch worktrees,
block 7 runs the proof (it needs Python and markdown-it-py; set
`QS_SKIP_PROOF=1` to skip it on purpose), and block 8 runs the house
suite: run the file in the background or with a
long timeout.

Clause IDs: K1-K7, H8 and U1-U6 in
[contracts/release-form.md](contracts/release-form.md). `$BASE` is the
branch's base, `88cb603`.

## 1. Setup

```bash
set -u
BASE=88cb603dc755ee3e69fc26f6a3219f0b86c14bf5
fail() { echo "FAIL $*"; exit 1; }
CLEANUP=()
wt=""
trap '[ -n "$wt" ] && { git worktree remove --force "$wt" 2>/dev/null || { rm -rf -- "$wt"; git worktree prune; }; }; for p in "${CLEANUP[@]+"${CLEANUP[@]}"}"; do [ -n "$p" ] && rm -rf -- "$p"; done' EXIT
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || fail "base $BASE not found"
[ -f .claude-plugin/marketplace.json ] || fail "not at the repository root"
BATS="$HOME/bats/bin/bats"
[ -f "$BATS" ] || fail "bats not found at the path CONTRIBUTING.md gives"
# Every release-form test, and the one-script test (FR-007).
REL='^--released (refuses|judges)|^one version-agreement script, and both gates call it'
NREL=$(( $(grep -cE '^@test "--released (refuses|judges)' tests/portability.bats) + 1 ))
[ "$NREL" -ge 11 ] || fail "control: expected at least ten --released tests in the file, found $((NREL - 1))"
```

## 2. The real tree (K7)

Both forms' output on this tree must equal the base script's output on
the base tree.

```bash
tmp=$(mktemp -d) && [ -d "$tmp" ] || fail "mktemp -d"
CLEANUP+=("$tmp")
git worktree add -q --detach "$tmp/base" "$BASE" || fail "K7 worktree"
wt=$tmp/base
for form in "" "--released handoff" "--released pipeline"; do
  base_out=$(cd "$wt" && bash scripts/check-versions.sh $form 2>&1); base_rc=$?
  now_out=$(bash scripts/check-versions.sh $form 2>&1); now_rc=$?
  [ "$now_rc" = "$base_rc" ] && [ "$now_out" = "$base_out" ] \
    || fail "K7 '${form:-default}' changed: rc $base_rc -> $now_rc; output: $now_out"
  [ "$now_rc" = "0" ] || fail "K7 '${form:-default}' refused the real tree: $now_out"
done
git worktree remove --force "$wt" || fail "K7 worktree not removed"
wt=""
echo "K7 ok"
```

## 3. The release-form tests (K1-K6, H8, U1-U6), and SC-002's time

```bash
t=$(mktemp); CLEANUP+=("$t")
"$BATS" --print-output-on-failure -f "$REL" tests/portability.bats > "$t" 2>&1
bash scripts/check-suite.sh "$NREL" "$t" || { cat "$t"; fail "K1-K6 H8 U1-U6 the release-form tests"; }
echo "K1-K6 H8 U1-U6 ok ($NREL tests)"
# SC-002: a 400,000-marker line is refused in under 2 s on this machine.
sd=$(mktemp -d); CLEANUP+=("$sd")
mkdir -p "$sd/.claude-plugin" "$sd/handoff/.claude-plugin"
cp handoff/.claude-plugin/plugin.json "$sd/handoff/.claude-plugin/"
jq '.plugins |= .[:1]' .claude-plugin/marketplace.json > "$sd/.claude-plugin/marketplace.json"
{ grep -m1 -E '^## \[[0-9]' handoff/CHANGELOG.md; printf '\nPlain text.\n\n'
  awk 'BEGIN { s = ""; for (i = 0; i < 400000; i++) s = s "> "; print s "x" }'; } > "$sd/handoff/CHANGELOG.md"
s0=$(date +%s)
out=$(cd "$sd" && bash "$OLDPWD/scripts/check-versions.sh" --released handoff 2>&1) && fail "SC-002 the long line passed: $out"
s1=$(date +%s)
case "$out" in *"bytes long"*) ;; *) fail "SC-002 refused, but not for its length: ${out:0:300}" ;; esac
# Whole seconds: a difference under 2 means the run took under 2 s.
[ $((s1 - s0)) -lt 2 ] || fail "SC-002 took $((s1 - s0)) s"
echo "SC-002 ok ($((s1 - s0)) s)"
```

## 4. The tests can go red (base-gate mutant)

In a scratch worktree holding this branch's tree, committed or not, the
gate is put back to its `$BASE` copy, which has none of this phase's rules.
The release-form tests must report `not ok`, and a red must name a K
clause: a bats crash or a failed fixture also exits non-zero.

```bash
mt=$(mktemp -d) && [ -d "$mt" ] || fail "mktemp -d"
CLEANUP+=("$mt")
git worktree add -q --detach "$mt/wt" HEAD || fail "mutant worktree"
wt=$mt/wt
for f in $(git diff --name-only HEAD -- scripts tests; git ls-files --others --exclude-standard -- scripts tests); do
  cp -- "$f" "$wt/$f" || fail "mutant worktree: copy $f"
done
mo=$mt/out.txt
git show "$BASE:scripts/check-versions.sh" > "$wt/scripts/check-versions.sh"
cmp -s scripts/check-versions.sh "$wt/scripts/check-versions.sh" && fail "gate mutant did not land"
(cd "$wt" && "$BATS" -f "$REL" tests/portability.bats > "$mo" 2>&1)
grep -q '^not ok ' "$mo" && grep -qE '(^|[^A-Z])K[1-5]:' "$mo" \
  || { cat "$mo"; fail "the release-form tests did not report a K clause against the base gate"; }
echo "gate mutant red: $(grep -oE '(^|[^A-Z])K[1-5]:' "$mo" | tr -d ' #' | sort -u | tr '\n' ' ')"
git worktree remove --force "$wt" || fail "mutant worktree not removed"
wt=""
```

## 5. The fixtures keep their own baseline (FR-017)

In a scratch worktree, a refused shape of each kind, a lone-CR line and an
over-long line are appended to EVERY live changelog the marketplace names
(not committed). Every release-form test must still pass, because each
builds its fixture from the live tree and removes these shapes itself.

```bash
ft=$(mktemp -d) && [ -d "$ft" ] || fail "mktemp -d"
CLEANUP+=("$ft")
git worktree add -q --detach "$ft/wt" HEAD || fail "fixture worktree"
wt=$ft/wt
for f in $(git diff --name-only HEAD -- scripts tests; git ls-files --others --exclude-standard -- scripts tests); do
  cp -- "$f" "$wt/$f" || fail "fixture worktree: copy $f"
done
plugins=$(jq -r '.plugins[].source' .claude-plugin/marketplace.json | tr -d '\r' | sed 's#^\./##; s#/$##')
[ -n "$plugins" ] || fail "control: the marketplace names no plugin"
long=$(awk 'BEGIN { s = ""; for (i = 0; i < 1001; i++) s = s "x"; print s }')
for p in $plugins; do
  printf '\nPlain text.\n\n##\tTab\n\n> ## Quoted\n\n- ## Listed\n\nUnder\n---\n\n- ```\n  listed fence\n\nNotes\r## x\n\n%s\n\n```\nopen fence\n' "$long" >> "$wt/$p/CHANGELOG.md"
  (cd "$wt" && bash scripts/check-versions.sh --released "$p" >/dev/null 2>&1) \
    && fail "control: the planted live $p changelog still passes --released, so this block proves nothing"
done
fo=$ft/out.txt
(cd "$wt" && "$BATS" --print-output-on-failure -f "$REL" tests/portability.bats > "$fo" 2>&1)
bash scripts/check-suite.sh "$NREL" "$fo" || { cat "$fo"; fail "FR-017 a release-form test reddened on a correct tree"; }
git worktree remove --force "$wt" || fail "fixture worktree not removed"
wt=""
echo "FR-017 ok ($NREL tests pass on a live changelog holding every refused kind)"
```

## 6. Scope (FR-018)

```bash
B='\b(flutter|dart|pubspec|supabase|gradle|graphify|speckit|superpowers)\b'
[ "$(printf '+uses speckit\n' | grep -ciE -- "$B")" = "1" ] || fail "FR-018 control: the vocabulary pattern matches nothing"
v=$(git diff "$BASE" -- scripts | grep '^+' | grep -v '^+++' | grep -ciE -- "$B")
[ "$v" = "0" ] || fail "FR-018 $v banned-word lines on a STRICT surface"
git diff --quiet "$BASE" -- handoff pipeline || fail "FR-018 a plugin file changed"
[ -z "$(git ls-files --others --exclude-standard -- handoff pipeline)" ] || fail "FR-018 an untracked file in a plugin"
I='[]a-zA-Z0-9.)][{][0-9]+(,[0-9]*)?[}]'
[ "$(printf '+  /^ [ ]{0,3}##/\n+ x="${1}"\n' | grep -cE -- "$I")" = "1" ] || fail "FR-018 control: the interval pattern does not match exactly the planted interval"
iv=$(git diff "$BASE" -- scripts | grep '^+' | grep -v '^+++' | grep -cE -- "$I")
[ "$iv" = "0" ] || fail "FR-018 $iv added lines hold an interval expression"
echo "FR-018 ok (no count in prose is a review check, not a script check)"
```

## 7. The narrowing proof (FR-009, SC-003)

The enumeration is rerun. Each narrowing the walk keeps must report 0
wrong passes and a positive control of at least 1. Without Python and
markdown-it-py this block FAILS, unless `QS_SKIP_PROOF=1` was set on
purpose, and then it says that it proved nothing.

```bash
PY=""
for c in python3 python; do
  c=$(command -v "$c" || true)
  [ -n "$c" ] && "$c" -c 'import markdown_it' 2>/dev/null && { PY=$c; break; }
done
if [ -n "$PY" ]; then
  po=$(mktemp); CLEANUP+=("$po")
  "$PY" specs/025-gate-closes-phase25-gaps/proof/enumerate.py scripts/check-versions.sh > "$po" 2>&1 \
    || { cat "$po"; fail "FR-009 the enumeration proof failed"; }
  grep -E '^(KEPT|REVERTED) ' "$po"
  echo "FR-009 ok"
elif [ "${QS_SKIP_PROOF:-}" = "1" ]; then
  echo "FR-009 SKIPPED ON PURPOSE (QS_SKIP_PROOF=1): the proof was not rerun"
else
  fail "FR-009 Python with markdown-it-py not found; install it, or set QS_SKIP_PROOF=1 to skip the proof on purpose"
fi
```

## 8. The house suite (SC-006)

```bash
tap=$(mktemp)
"$BATS" -r --print-output-on-failure tests handoff/tests pipeline/tests > "$tap" 2>&1
rc=$?
bash scripts/check-suite.sh 249 "$tap" || fail "SC-006 suite (rc $rc, TAP kept at $tap)"
[ "$rc" = "0" ] || fail "SC-006 bats exited $rc although every line passed"
rm -f "$tap"
echo "SC-006 ok"
echo "ALL OK"
```
