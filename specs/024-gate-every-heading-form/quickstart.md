# Quickstart: validate that the release form reads every level-2 heading form

Run from the repository root on the feature branch, in Git Bash or any bash
5. The `bash` blocks below are ONE script: extract every `bash` block in
order into a file and run that file with `bash`. Never paste it into an
interactive shell, because a failure exits the shell. Each check prints its
ID and `ok`, or stops with `FAIL`. Block 4 and block 5 use scratch
worktrees, and block 7 runs the house suite: run the file in the
background or with a long timeout.

Clause IDs: H1–H9 in [contracts/release-form.md](contracts/release-form.md).
`$BASE` is the branch's base, `33c972b`; its `scripts/` and `tests/` are
byte-identical to `8bc9b5a`, the gate the seed names.

## 1. Setup

```bash
set -u
BASE=33c972bd9eddbf0ff0c1c522058f095449cde7c7
fail() { echo "FAIL $*"; exit 1; }
CLEANUP=()
wt=""
trap '[ -n "$wt" ] && { git worktree remove --force "$wt" 2>/dev/null || { rm -rf -- "$wt"; git worktree prune; }; }; for p in "${CLEANUP[@]+"${CLEANUP[@]}"}"; do [ -n "$p" ] && rm -rf -- "$p"; done' EXIT
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || fail "base $BASE not found"
[ -f .claude-plugin/marketplace.json ] || fail "not at the repository root"
BATS="$HOME/bats/bin/bats"
[ -f "$BATS" ] || fail "bats not found at the path CONTRIBUTING.md gives"
# The six new tests, one per contract clause group (FR-013). bats reads
# -f as an extended regular expression over the test name.
NEW='bare level-2 heading form|inside a quote or a list item|deep line while a list item|code fence that never closes|code fence whose end is unclear|judges no non-heading'
```

## 2. The real tree (H8)

The default form's output on this tree must equal the base script's output
on the base tree. Both plugins are released today, so the release form
passes for each.

```bash
tmp=$(mktemp -d) && [ -d "$tmp" ] || fail "mktemp -d"
CLEANUP+=("$tmp")
git worktree add -q --detach "$tmp/base" "$BASE" || fail "H8 worktree"
wt=$tmp/base
base_out=$(cd "$wt" && bash scripts/check-versions.sh 2>&1); base_rc=$?
git worktree remove --force "$wt" || fail "H8 worktree not removed"
wt=""
now_out=$(bash scripts/check-versions.sh 2>&1); now_rc=$?
[ "$now_rc" = "$base_rc" ] && [ "$now_out" = "$base_out" ] \
  || fail "H8 default run changed: rc $base_rc -> $now_rc; output: $now_out"
for p in handoff pipeline; do
  out=$(bash scripts/check-versions.sh --released "$p" 2>&1) || fail "H8 --released $p refused the real tree: $out"
done
echo "H8 ok"
```

## 3. The new tests (H1–H7, H9)

The six new tests are run on their own and their result is read with the
suite check: plan line, ok count, and no skip, `not ok` or stray line.

```bash
t=$(mktemp); CLEANUP+=("$t")
"$BATS" --print-output-on-failure -f "$NEW" tests/portability.bats > "$t" 2>&1
bash scripts/check-suite.sh 6 "$t" || { cat "$t"; fail "H1-H7 H9 the new tests"; }
echo "H1-H7 H9 ok (the six new tests)"
```

## 4. The test can go red (mutant)

In a scratch worktree holding this branch's tree, committed or not, the gate
is put back to its `$BASE` copy, which judges only lines beginning `## `.
The new tests must report `not ok` and name a clause. A red counts only
when a selected test reports `not ok` AND names the clause: a bats crash,
an unresolved root or a failed fixture also exit non-zero.

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
(cd "$wt" && "$BATS" -f "$NEW" tests/portability.bats > "$mo" 2>&1)
grep -q '^not ok ' "$mo" && grep -qE '(^|[^A-Z])H[1-6]:' "$mo" \
  || { cat "$mo"; fail "the new tests did not report an H clause against the base gate"; }
echo "gate mutant red: $(grep -oE '(^|[^A-Z])H[1-6]:' "$mo" | head -1 | tr -d ' #')"
git worktree remove --force "$wt" || fail "mutant worktree not removed"
wt=""
```

## 5. The fixtures keep their own baseline (FR-012)

In a scratch worktree, a refused shape of each kind is appended to EVERY
live changelog the marketplace names (not committed). Every `--released`
test must still pass, because each builds its fixture from the live tree and
removes these shapes itself.

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
for p in $plugins; do
  printf '\nPlain text.\n\n##\tTab\n\n ## Indent\n\n##\n\n> ## Quoted\n\n>## Tight\n\n- ## Listed\n\n- item\n\n\t## Deep\n\nUnder\n---\n\nSingle\n-\n\n- ```\n  listed fence\n\n```\nopen fence\n' >> "$wt/$p/CHANGELOG.md"
  (cd "$wt" && bash scripts/check-versions.sh --released "$p" >/dev/null 2>&1) \
    && fail "control: the planted live $p changelog still passes --released, so this block proves nothing"
done
fo=$ft/out.txt
(cd "$wt" && "$BATS" --print-output-on-failure -f '^--released (refuses|judges)' tests/portability.bats > "$fo" 2>&1)
# The expected count comes from the test FILE, not from the run's own plan
# line: that pins the filter to every test it should select.
n=$(grep -cE '^@test "--released (refuses|judges)' tests/portability.bats)
[ "$n" -ge 9 ] || fail "control: expected at least nine '--released' tests in the file, found $n"
bash scripts/check-suite.sh "$n" "$fo" || { cat "$fo"; fail "FR-012 a --released test reddened on a correct tree, or the filter selected a different set"; }
git worktree remove --force "$wt" || fail "fixture worktree not removed"
wt=""
echo "FR-012 ok ($n --released tests pass on a live changelog holding every refused kind)"
```

## 6. Scope (FR-013)

```bash
B='\b(flutter|dart|pubspec|supabase|gradle|graphify|speckit|superpowers)\b'
[ "$(printf '+uses speckit\n' | grep -ciE -- "$B")" = "1" ] || fail "FR-013 control: the vocabulary pattern matches nothing"
v=$(git diff "$BASE" -- scripts | grep '^+' | grep -v '^+++' | grep -ciE -- "$B")
[ "$v" = "0" ] || fail "FR-013 $v banned-word lines on a STRICT surface"
git diff --quiet "$BASE" -- handoff pipeline || fail "FR-013 a plugin file changed"
[ -z "$(git ls-files --others --exclude-standard -- handoff pipeline)" ] || fail "FR-013 an untracked file in a plugin"
# No interval expression in a line added under scripts/: a repetition count
# in braces straight after a character, a class or a group. `${1}` is not
# one. (Bash 3.2 is shown by CI's macOS job running the suite, not here.)
I='[]a-zA-Z0-9.)][{][0-9]+(,[0-9]*)?[}]'
[ "$(printf '+  /^ [ ]{0,3}##/\n+ x="${1}"\n' | grep -cE -- "$I")" = "1" ] || fail "FR-013 control: the interval pattern does not match exactly the planted interval"
iv=$(git diff "$BASE" -- scripts | grep '^+' | grep -v '^+++' | grep -cE -- "$I")
[ "$iv" = "0" ] || fail "FR-013 $iv added lines hold an interval expression"
echo "FR-013 ok (no count in prose is a review check, not a script check)"
```

## 7. The house suite (SC-005)

```bash
tap=$(mktemp)
"$BATS" -r --print-output-on-failure tests handoff/tests pipeline/tests > "$tap" 2>&1
rc=$?
bash scripts/check-suite.sh 248 "$tap" || fail "SC-005 suite (rc $rc, TAP kept at $tap)"
[ "$rc" = "0" ] || fail "SC-005 bats exited $rc although every line passed"
rm -f "$tap"
echo "SC-005 ok"
echo "ALL OK"
```
