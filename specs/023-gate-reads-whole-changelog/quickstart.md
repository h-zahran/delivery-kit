# Quickstart: validate the release rule and the suite check

Run from the repository root on the feature branch, in Git Bash or any bash
5. The `bash` blocks below are ONE script: extract every `bash` block in
order into a file and run that file with `bash` — never paste it into an
interactive shell, because a failure exits the shell. One block per
section. Each check prints its ID and `ok`, or stops with `FAIL`. Block 6
runs the house suite (eight to ten minutes) and block 4 runs mutants in a
scratch worktree: run the file in the background or with a long timeout.

Clause IDs: G1–G7 in [contracts/release-form.md](contracts/release-form.md),
K1–K11 in [contracts/check-suite.md](contracts/check-suite.md).

## 1. Setup

```bash
set -u
BASE=58318226b5f9f957a161addc28729ba224d414ba
fail() { echo "FAIL $*"; exit 1; }
CLEANUP=()
wt=""
trap '[ -n "$wt" ] && { git worktree remove --force "$wt" 2>/dev/null || { rm -rf -- "$wt"; git worktree prune; }; }; for p in "${CLEANUP[@]+"${CLEANUP[@]}"}"; do [ -n "$p" ] && rm -rf -- "$p"; done' EXIT
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || fail "base $BASE not found"
[ -f .claude-plugin/marketplace.json ] || fail "not at the repository root"
BATS="$HOME/bats/bin/bats"
[ -f "$BATS" ] || fail "bats not found at the path CONTRIBUTING.md gives"
```

## 2. The real tree (G4, G5)

The default form's output on this tree must equal the base script's output
on the base tree: nothing a default run prints may change (G5). Both plugins
are released today, so the release form passes for each (G4).

```bash
tmp=$(mktemp -d) && [ -d "$tmp" ] || fail "mktemp -d"
CLEANUP+=("$tmp")
git worktree add -q --detach "$tmp/base" "$BASE" || fail "G5 worktree"
wt=$tmp/base
base_out=$(cd "$wt" && bash scripts/check-versions.sh 2>&1); base_rc=$?
git worktree remove --force "$wt" || fail "G5 worktree not removed"
wt=""
now_out=$(bash scripts/check-versions.sh 2>&1); now_rc=$?
[ "$now_rc" = "$base_rc" ] && [ "$now_out" = "$base_out" ] \
  || fail "G5 default run changed: rc $base_rc -> $now_rc; output: $now_out"
echo "G5 ok"
for p in handoff pipeline; do
  bash scripts/check-versions.sh --released "$p" >/dev/null 2>&1 || fail "G4 --released $p refused the real tree"
done
echo "G4 ok"
```

## 3. The two new tests (G1–G3, G6, K1–K11)

Each test file is run on its own and its result is read with the suite
check itself: plan line, ok count and no skip, not ok or stray line.

```bash
t=$(mktemp); CLEANUP+=("$t")
"$BATS" --print-output-on-failure -f 'below|undated' tests/portability.bats > "$t" 2>&1
bash scripts/check-suite.sh 1 "$t" || { cat "$t"; fail "G1-G3 release-rule test"; }
echo "G1-G3 G6 ok (the release-rule test)"
"$BATS" --print-output-on-failure tests/check-suite.bats > "$t" 2>&1
bash scripts/check-suite.sh 1 "$t" || { cat "$t"; fail "K1-K11 suite-check test"; }
echo "K1-K11 ok (the suite-check test)"
```

## 4. The tests can go red (mutants)

In a scratch worktree holding this branch's tree, committed or not: the
gate is put back to its `$BASE` copy — the first-heading-only comparison
the seed names — and the release-rule test must report `not ok`. Then
each suite-check rule is removed in turn (its line ends `# K<n>`; the IDs
are read from the script and their number pinned to the contract), and
the suite-check test must report `not ok` every time. A mutant counts only
if it changed exactly one line, still parses, and still passes a clean
run.

```bash
mt=$(mktemp -d) && [ -d "$mt" ] || fail "mktemp -d"
CLEANUP+=("$mt")
git worktree add -q --detach "$mt/wt" HEAD || fail "mutant worktree"
wt=$mt/wt
for f in $(git diff --name-only HEAD -- scripts tests; git ls-files --others --exclude-standard -- scripts tests); do
  cp -- "$f" "$wt/$f" || fail "mutant worktree: copy $f"
done
mo=$mt/out.txt
# A red counts only when the one test in the file reports `not ok 1` AND its
# output names the expected clause: a bats crash, an unresolved root, an
# unparseable mutant or a failed fixture also exit non-zero, and would
# otherwise be scored as a catch. red <tag> <bats args...>
red() { tag=$1; shift; (cd "$wt" && "$BATS" "$@" > "$mo" 2>&1); grep -q '^not ok 1 ' "$mo" && grep -qF "$tag:" "$mo"; }

# The gate: put back the $BASE copy, the first-heading-only comparison.
git show "$BASE:scripts/check-versions.sh" > "$wt/scripts/check-versions.sh"
cmp -s scripts/check-versions.sh "$wt/scripts/check-versions.sh" && fail "gate mutant did not land"
red G1 -f 'below|undated' tests/portability.bats || fail "the release-rule test did not report G1 against the first-heading-only gate"
cp -- scripts/check-versions.sh "$wt/scripts/check-versions.sh"
echo "gate mutant red"

# The suite check: remove each rule in turn. The IDs are read from the
# script, and their count is pinned to the contract's K2-K11 rows.
ids=$(grep -oE '# K[0-9]+$' scripts/check-suite.sh | sed 's/^# //' | sort)
want=$(grep -oE '^\| K[0-9]+ \|' specs/023-gate-reads-whole-changelog/contracts/check-suite.md | grep -oE 'K[0-9]+' | grep -vx 'K1' | sort)
[ -n "$want" ] || fail "control: the contract lists no rule"
[ "$ids" = "$want" ] || fail "the script's rule tags differ from the contract's K2-K11 rows: script [$(printf '%s
' "$ids" | tr '
' ' ')] contract [$(printf '%s
' "$want" | tr '
' ' ')]"
clean=$mt/clean.tap; printf '1..1\nok 1 x\n' > "$clean"
for k in $ids; do
  n=$(grep -c -E "# $k\$" scripts/check-suite.sh)
  [ "$n" = "1" ] || fail "mutant $k: expected one line ending '# $k', found $n"
  grep -v -E "# $k\$" scripts/check-suite.sh > "$wt/scripts/check-suite.sh"
  [ "$(diff scripts/check-suite.sh "$wt/scripts/check-suite.sh" | grep -c '^<')" = "1" ] || fail "mutant $k did not land as one line"
  bash -n "$wt/scripts/check-suite.sh" || fail "mutant $k does not parse"
  bash "$wt/scripts/check-suite.sh" 1 "$clean" >/dev/null 2>&1 || fail "mutant $k no longer passes a clean run, so its red would prove nothing"
  red "$k" tests/check-suite.bats || fail "the suite-check test did not report $k with rule $k removed"
  cp -- scripts/check-suite.sh "$wt/scripts/check-suite.sh"
done
git worktree remove --force "$wt" || fail "mutant worktree not removed"
wt=""
echo "suite-check mutants red: $(printf '%s
' "$ids" | tr '
' ' ')"
```

## 5. The records (FR-007, FR-008, FR-010)

```bash
d=$(git diff "$BASE" -- specs/016-release-two-plugins/contracts/version-agreement.md | grep -E '^[-+]' | grep -v -E '^(\+\+\+|---) ')
[ -n "$d" ] || fail "FR-008 the 016 contract has no note"
printf '%s\n' "$d" | grep -q '^-' && fail "FR-008 an existing line of the 016 contract changed"
printf '%s\n' "$d" | grep -q 'Later note, 2026-10-01' || fail "FR-008 the note is not the dated one"
echo "FR-008 ok"
grep -q 'scripts/check-suite.sh' CONTRIBUTING.md || fail "FR-007 CONTRIBUTING.md does not name the suite check"
echo "FR-007 ok"
B='\b(flutter|dart|pubspec|supabase|gradle|graphify|speckit|superpowers)\b'
[ "$(printf '+uses speckit\n' | grep -ciE -- "$B")" = "1" ] || fail "FR-010 control: the vocabulary pattern matches nothing"
v=$( { git diff "$BASE" -- scripts CONTRIBUTING.md; for f in $(git ls-files --others --exclude-standard -- scripts); do sed 's/^/+/' "$f"; done; } | grep '^+' | grep -v '^+++' | grep -ciE -- "$B")
[ "$v" = "0" ] || fail "FR-010 $v banned-word lines on a STRICT surface"
git diff --quiet "$BASE" -- handoff pipeline || fail "FR-010 a plugin file changed"
[ -z "$(git ls-files --others --exclude-standard -- handoff pipeline)" ] || fail "FR-010 an untracked file in a plugin"
old=$(git ls-files -- 'specs/*/quickstart.md' | grep -v '^specs/023-')
[ -n "$old" ] || fail "control: no earlier quickstart found"
printf '%s
' "$old" | xargs git diff --quiet "$BASE" -- || fail "an earlier feature's quickstart changed"
echo "FR-010 ok (no count in prose is a review check, not a script check)"
```

## 6. The house suite (SC-004)

The suite check judges the house suite itself: plan `1..242`.

```bash
tap=$(mktemp)
"$BATS" -r --print-output-on-failure tests handoff/tests pipeline/tests > "$tap" 2>&1
rc=$?
bash scripts/check-suite.sh 242 "$tap" || fail "SC-004 suite (rc $rc, TAP kept at $tap)"
[ "$rc" = "0" ] || fail "SC-004 bats exited $rc although every line passed"
rm -f "$tap"
echo "SC-004 ok"
echo "ALL OK"
```
