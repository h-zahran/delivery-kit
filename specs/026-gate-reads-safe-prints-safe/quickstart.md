# Quickstart: validate that the gate reads only what it can judge, and prints only what is safe

Run from the repository root on the feature branch, in Git Bash or any
bash 5. The `bash` blocks below are ONE script: extract every `bash` block
in order into a file and run that file with `bash`. Never paste it into an
interactive shell, because a failure exits the shell. Each check prints
its ID and `ok`, or stops with `FAIL`. Block 2 and block 5 use scratch
worktrees; block 6 needs a system that can make a symbolic link (set
`QS_SKIP_LINK=1` to skip that one check on purpose); block 8 runs the
house suite: run the file in the background or with a long timeout.

Clause IDs: L1-L4, P1-P6, R1-R2 in
[contracts/release-gate.md](contracts/release-gate.md). `$BASE` is the
branch's base, `4016666`.

## 1. Setup

```bash
set -u
BASE=40166663e0475c88ff8d4546799e11b0f46c1879
fail() { echo "FAIL $*"; exit 1; }
CLEANUP=()
wt=""
trap '[ -n "$wt" ] && { git worktree remove --force "$wt" 2>/dev/null || { rm -rf -- "$wt"; git worktree prune; }; }; for p in "${CLEANUP[@]+"${CLEANUP[@]}"}"; do [ -n "$p" ] && rm -rf -- "$p"; done' EXIT
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || fail "base $BASE not found"
[ -f .claude-plugin/marketplace.json ] || fail "not at the repository root"
BATS="$HOME/bats/bin/bats"
[ -f "$BATS" ] || fail "bats not found at the path CONTRIBUTING.md gives"
GATE=$PWD/scripts/check-versions.sh
# The two tests this phase adds (block 4 checks that both exist, so
# blocks 1-3 also run before the second is written).
NEW='^the gate reads only a regular changelog|^the gate prints every value masked'
fx() { # fx <dir>: a one-plugin fixture built from handoff/
  mkdir -p "$1/.claude-plugin" "$1/handoff/.claude-plugin"
  cp handoff/.claude-plugin/plugin.json "$1/handoff/.claude-plugin/"
  jq '.plugins |= .[:1]' .claude-plugin/marketplace.json > "$1/.claude-plugin/marketplace.json"
  cp handoff/CHANGELOG.md "$1/handoff/CHANGELOG.md"
}
```

## 2. The real tree (R1)

```bash
tmp=$(mktemp -d) && [ -d "$tmp" ] || fail "mktemp -d"
CLEANUP+=("$tmp")
git worktree add -q --detach "$tmp/base" "$BASE" || fail "R1 worktree"
wt=$tmp/base
for form in "" "--released handoff" "--released pipeline"; do
  base_out=$(cd "$wt" && bash scripts/check-versions.sh $form 2>&1); base_rc=$?
  now_out=$(bash scripts/check-versions.sh $form 2>&1); now_rc=$?
  [ "$now_rc" = "$base_rc" ] && [ "$now_out" = "$base_out" ] \
    || fail "R1 '${form:-default}' changed: rc $base_rc -> $now_rc; output: $now_out"
  [ "$now_rc" = "0" ] || fail "R1 '${form:-default}' refused the real tree: $now_out"
done
git worktree remove --force "$wt" || fail "R1 worktree not removed"
wt=""
echo "R1 ok"
```

## 3. The walk is the one the proof judged (R2)

```bash
want=24c123b1b203af88fdcd745f3c4cba58ba6289e1612cf13f7bf1708d46314896
walk=$(awk '/LC_ALL=C awk .$/ { f = 1; next } f && /^    . "\.\/\$p\/CHANGELOG\.md"\)"$/ { exit } f' "$GATE")
[ -n "$walk" ] || fail "R2 control: the walk was not found in the gate"
if command -v sha256sum >/dev/null 2>&1; then got=$(printf '%s' "$walk" | sha256sum); else got=$(printf '%s' "$walk" | shasum -a 256); fi
got=${got%% *}
[ "$got" = "$want" ] || fail "R2 the walk changed (sha256 $got): rerun the Phase 26 proof (FR-008)"
echo "R2 ok"
```

## 4. The new tests (L1-L4, P1-P6)

```bash
[ "$(grep -cE '^@test "(the gate reads only a regular changelog|the gate prints every value masked)' tests/portability.bats)" = "2" ] \
  || fail "control: expected the two new tests in the file"
t=$(mktemp); CLEANUP+=("$t")
"$BATS" --print-output-on-failure -f "$NEW" tests/portability.bats > "$t" 2>&1
bash scripts/check-suite.sh 2 "$t" || { cat "$t"; fail "L1-L4 P1-P6 the new tests"; }
# L1 says which way it took, on a pass too, through file descriptor 3.
links=$(grep -c '^# links: ' "$t")
[ "$links" = "1" ] || { cat "$t"; fail "L1 expected exactly one '# links:' line, found $links"; }
grep '^# links: ' "$t"
echo "L1-L4 P1-P6 ok"
```

## 5. The tests can go red (base-gate mutant)

In a scratch worktree holding this branch's tests, the gate is put back to
its `$BASE` copy, which has none of this phase's rules. The new tests must
both report `not ok`, one naming an L clause and one a P clause, and
neither on a `fixture:` error.

```bash
mt=$(mktemp -d) && [ -d "$mt" ] || fail "mktemp -d"
CLEANUP+=("$mt")
git worktree add -q --detach "$mt/wt" HEAD || fail "mutant worktree"
wt=$mt/wt
for f in $(git diff --name-only HEAD -- scripts tests; git ls-files --others --exclude-standard -- scripts tests); do
  cp -- "$f" "$wt/$f" || fail "mutant worktree: copy $f"
done
git show "$BASE:scripts/check-versions.sh" > "$wt/scripts/check-versions.sh"
cmp -s scripts/check-versions.sh "$wt/scripts/check-versions.sh" && fail "gate mutant did not land"
mo=$mt/out.txt
(cd "$wt" && "$BATS" -f "$NEW" tests/portability.bats > "$mo" 2>&1)
# Both tests red, each on a clause of its own, and neither on its fixture.
[ "$(grep -c '^not ok ' "$mo")" = "2" ] && grep -qE '(^|[^A-Z])L[1-4]:' "$mo" \
  && grep -qE '(^|[^A-Z])P[1-6]:' "$mo" && ! grep -q 'fixture:' "$mo" \
  || { cat "$mo"; fail "the new tests did not each report an L or P clause against the base gate"; }
echo "gate mutant red: $(grep -oE '(^|[^A-Z])[LP][1-6]:' "$mo" | grep -oE '[LP][1-6]:' | sort -u | tr '\n' ' ')"
git worktree remove --force "$wt" || fail "mutant worktree not removed"
wt=""
```

## 6. It ends at once (SC-001, SC-003)

```bash
sd=$(mktemp -d); CLEANUP+=("$sd")
fx "$sd"
# Milliseconds from bash's own clock: `date +%s` reads a 1.1 s run as 2 s
# when it crosses a second. The separator follows the locale.
ms() { local t=${EPOCHREALTIME/[.,]/}; echo $((10#$t / 1000)); }
# A bound on a run that would hang without the rule; stock macOS has no
# `timeout`, and there the run is simply not bounded.
TO=""
command -v timeout >/dev/null 2>&1 && TO="timeout 30"
rm "$sd/handoff/CHANGELOG.md"
if MSYS=winsymlinks:nativestrict ln -s /dev/urandom "$sd/handoff/CHANGELOG.md" 2>/dev/null && [ -L "$sd/handoff/CHANGELOG.md" ]; then
  for form in "" "--released handoff"; do
    m0=$(ms)
    out=$(cd "$sd" && $TO bash "$GATE" $form 2>&1) && fail "SC-001 a link to a device passed: $out"
    m1=$(ms)
    case "$out" in *"is a symbolic link"*) ;; *) fail "SC-001 refused, but not as a link: ${out:0:300}" ;; esac
    [ $((m1 - m0)) -lt 2000 ] || fail "SC-001 took $((m1 - m0)) ms"
  done
  echo "SC-001 ok"
elif [ "${QS_SKIP_LINK:-}" = "1" ]; then
  echo "SC-001 SKIPPED ON PURPOSE (QS_SKIP_LINK=1): this system made no link"
else
  fail "SC-001 this system made no symbolic link; set QS_SKIP_LINK=1 to skip it on purpose"
fi
rm -f "$sd/handoff/CHANGELOG.md"
cp handoff/CHANGELOG.md "$sd/handoff/CHANGELOG.md"
have=$(( $(LC_ALL=C wc -c < "$sd/handoff/CHANGELOG.md") ))
# Lines of 64 `x`s, then one line holding exactly what is left: one byte
# over the limit. BINMODE=3 so Windows gawk writes LF, not CR LF.
LC_ALL=C awk -v BINMODE=3 -v n=$((262145 - have)) 'BEGIN { s = ""; for (i = 0; i < 64; i++) s = s "x"; while (n >= 65) { print s; n -= 65 } if (n > 0) { t = ""; for (i = 1; i < n; i++) t = t "x"; print t } }' >> "$sd/handoff/CHANGELOG.md"
size=$(( $(LC_ALL=C wc -c < "$sd/handoff/CHANGELOG.md") ))
[ "$size" = "262145" ] || fail "SC-003 control: the large changelog is $size bytes, not 262145"
m0=$(ms)
out=$(cd "$sd" && $TO bash "$GATE" --released handoff 2>&1) && fail "SC-003 a large changelog passed"
m1=$(ms)
case "$out" in *"262145 bytes"*) ;; *) fail "SC-003 refused, but not for its size: ${out:0:300}" ;; esac
[ $((m1 - m0)) -lt 2000 ] || fail "SC-003 took $((m1 - m0)) ms"
echo "SC-003 ok ($size bytes)"
```

## 7. Scope (FR-013)

```bash
B='\b(flutter|dart|pubspec|supabase|gradle|graphify|speckit|superpowers)\b'
[ "$(printf '+uses speckit\n' | grep -ciE -- "$B")" = "1" ] || fail "FR-013 control: the vocabulary pattern matches nothing"
v=$(git diff "$BASE" -- scripts | grep '^+' | grep -v '^+++' | grep -ciE -- "$B")
[ "$v" = "0" ] || fail "FR-013 $v banned-word lines on a STRICT surface"
git diff --quiet "$BASE" -- handoff pipeline || fail "FR-013 a plugin file changed"
[ -z "$(git ls-files --others --exclude-standard -- handoff pipeline)" ] || fail "FR-013 an untracked file in a plugin"
I='[]a-zA-Z0-9.)][{][0-9]+(,[0-9]*)?[}]'
[ "$(printf '+  /^ [ ]{0,3}##/\n+ x="${1}"\n' | grep -cE -- "$I")" = "1" ] || fail "FR-013 control: the interval pattern does not match exactly the planted interval"
iv=$(git diff "$BASE" -- scripts | grep '^+' | grep -v '^+++' | grep -cE -- "$I")
[ "$iv" = "0" ] || fail "FR-013 $iv added lines hold an interval expression"
echo "FR-013 ok (no count in prose is a review check, not a script check)"
```

## 8. The house suite (SC-006)

```bash
tap=$(mktemp)
"$BATS" -r --print-output-on-failure tests handoff/tests pipeline/tests > "$tap" 2>&1
rc=$?
bash scripts/check-suite.sh 251 "$tap" || fail "SC-006 suite (rc $rc, TAP kept at $tap)"
[ "$rc" = "0" ] || fail "SC-006 bats exited $rc although every line passed"
rm -f "$tap"
echo "SC-006 ok"
echo "ALL OK"
```
