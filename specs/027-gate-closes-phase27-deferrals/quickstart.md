# Quickstart: validate that the gate follows no link, lets no other program speak, and keeps its own shell options

Run from the repository root on the feature branch, in Git Bash or any
bash 5. The `bash` blocks below are ONE script: extract every `bash` block
in order into a file and run that file with `bash`. Never paste it into an
interactive shell, because a failure exits the shell. Each check prints
its ID and `ok`, or stops with `FAIL`. Blocks 2 and 5 use scratch
worktrees; block 6 needs a system that can make a symbolic link (set
`QS_SKIP_LINK=1` on a system that cannot, and block 6 skips its link
check, saying so); block 8 runs the house suite: run the file in the
background or with a long timeout.

Clause IDs: N1-N7, J1-J2, X1-X2, O1-O2, C1, T1-T3, R1-R2 in
[contracts/release-gate.md](contracts/release-gate.md). `$BASE` is the
branch's base, `5a78ea4`.

## 1. Setup

```bash
set -u
BASE=5a78ea40301ccb8ca5b571544dfd0c2270f079bf
fail() { echo "FAIL $*"; exit 1; }
CLEANUP=()
wt=""
trap '[ -n "$wt" ] && { git worktree remove --force "$wt" 2>/dev/null || { rm -rf -- "$wt"; git worktree prune; }; }; for p in "${CLEANUP[@]+"${CLEANUP[@]}"}"; do [ -n "$p" ] && rm -rf -- "$p"; done' EXIT
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || fail "base $BASE not found"
[ -f .claude-plugin/marketplace.json ] || fail "not at the repository root"
BATS="$HOME/bats/bin/bats"
[ -f "$BATS" ] || fail "bats not found at the path CONTRIBUTING.md gives"
GATE=$PWD/scripts/check-versions.sh
# The new test and the three tests this phase adds plants to.
NEW='^the gate follows no link|^the gate prints every value masked|^a TRAILING malformed marketplace entry|^--released refuses a byte or a line it cannot judge'
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
[ "$got" = "$want" ] || fail "R2 the walk changed (sha256 $got): rerun the Phase 26 proof (FR-012)"
echo "R2 ok"
```

## 4. The changed tests (N1-N7, J1-J2, X1-X2, O1-O2, C1, T1-T3)

```bash
[ "$(grep -c '^@test "the gate follows no link' tests/portability.bats)" = "1" ] \
  || fail "control: expected the new test in the file"
t=$(mktemp); CLEANUP+=("$t")
"$BATS" --print-output-on-failure -f "$NEW" tests/portability.bats > "$t" 2>&1
bash scripts/check-suite.sh 4 "$t" || { cat "$t"; fail "the four changed tests"; }
# N5: the new test says which way it took, on a pass too.
n=$(grep -c '^# nolinks: ' "$t")
[ "$n" = "1" ] || { cat "$t"; fail "N5 expected exactly one '# nolinks:' line, found $n"; }
grep '^# nolinks: ' "$t"
echo "N J X O C T ok"
```

## 5. The tests can go red (base-gate mutant)

In a scratch worktree holding this branch's tests, the gate is put back to
its `$BASE` copy, which has none of this phase's rules. The new test must
report `not ok` on N7 (its first plant, which needs no link), the P
test on X1 and the TRAILING test on J1, and none on a `fixture:`
error.

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
(cd "$wt" && "$BATS" -f '^the gate follows no link|^the gate prints every value masked|^a TRAILING malformed marketplace entry' tests/portability.bats > "$mo" 2>&1)
[ "$(grep -c '^not ok ' "$mo")" = "3" ] && grep -qE '(^|[^A-Z])N7:' "$mo" \
  && grep -qE '(^|[^A-Z])X1:' "$mo" && grep -qE '(^|[^A-Z])J1:' "$mo" && ! grep -q 'fixture:' "$mo" \
  || { cat "$mo"; fail "the tests did not each report their clause against the base gate"; }
echo "gate mutant red: $(grep -oE '(^|[^A-Z])[NXJO][1-7]:' "$mo" | grep -oE '[NXJO][1-7]:' | sort -u | tr '\n' ' ')"
git worktree remove --force "$wt" || fail "mutant worktree not removed"
wt=""
```

## 6. Links end at once; options change nothing; the walk is cheaper (SC-001, SC-003, SC-004)

```bash
sd=$(mktemp -d); CLEANUP+=("$sd")
ms() { local t=${EPOCHREALTIME/[.,]/}; echo $((10#$t / 1000)); }
TO=""
command -v timeout >/dev/null 2>&1 && TO="timeout 30"
fx "$sd/l"
printf '{"name":"OUTSIDE-NAME","version":"9.9.9"}' > "$sd/outside.json"
rm "$sd/l/handoff/.claude-plugin/plugin.json"
if MSYS=winsymlinks:nativestrict ln -s "$sd/outside.json" "$sd/l/handoff/.claude-plugin/plugin.json" 2>/dev/null && [ -L "$sd/l/handoff/.claude-plugin/plugin.json" ]; then
  for form in "" "--released handoff"; do
    m0=$(ms)
    out=$(cd "$sd/l" && $TO bash "$GATE" $form 2>&1) && fail "SC-001 a plugin.json link passed: $out"
    m1=$(ms)
    case "$out" in *"plugin.json is a symbolic link"*) ;; *) fail "SC-001 refused, but not as a link: ${out:0:300}" ;; esac
    case "$out" in *OUTSIDE-NAME*) fail "SC-001 the outside file's text was printed" ;; esac
    [ $((m1 - m0)) -lt 2000 ] || fail "SC-001 took $((m1 - m0)) ms"
  done
  echo "SC-001 ok"
elif [ "${QS_SKIP_LINK:-}" = "1" ]; then
  echo "SC-001 SKIPPED ON PURPOSE (QS_SKIP_LINK=1): this system made no link"
else
  fail "SC-001 this system made no symbolic link; set QS_SKIP_LINK=1 to skip it on purpose"
fi
# What FR-006 allows on standard error, the quickstart's own copy: xtrace
# traces the set command alone (it is off before the shopt runs), verbose
# echoes the whole line. The BASHOPTS options change nothing on the real
# tree, so their plants are the house test's O2, not run here.
optset='set +o xtrace +o verbose +o noglob +o keyword'
optline="$optset; shopt -u dotglob nocasematch"
for form in "" "--released handoff"; do
  plain=$(bash "$GATE" $form 2>/dev/null); plain_rc=$?
  for o in xtrace verbose noglob keyword; do
    out=$(env SHELLOPTS=$o bash "$GATE" $form 2>"$sd/err.txt"); rc=$?
    [ "$rc" = "$plain_rc" ] && [ "$out" = "$plain" ] || fail "SC-003 SHELLOPTS=$o '${form:-default}' changed the exit ($rc) or standard output"
    case $o in
      xtrace) want="+ $optset" ;;
      verbose) want="#!/usr/bin/env bash"$'\n'"$optline" ;;
      *) want="" ;;
    esac
    got=$(cat "$sd/err.txt")
    [ "$got" = "$want" ] || fail "SC-003 SHELLOPTS=$o '${form:-default}' standard error is not what FR-006 allows: ${got:0:300}"
  done
done
echo "SC-003 ok"
fx "$sd/c"
jq '.plugins = [.plugins[0]] + [range(400) | {name: "x\(.)", source: "./handoff"}]' .claude-plugin/marketplace.json > "$sd/c/.claude-plugin/marketplace.json"
git show "$BASE:scripts/check-versions.sh" > "$sd/base-gate.sh"
m0=$(ms); (cd "$sd/c" && bash "$sd/base-gate.sh" >/dev/null 2>&1); m1=$(ms)
(cd "$sd/c" && bash "$GATE" >/dev/null 2>&1); m2=$(ms)
[ $((m2 - m1)) -lt $((m1 - m0)) ] || fail "SC-004 400 entries took $((m2 - m1)) ms, the base gate $((m1 - m0)) ms"
echo "SC-004 ok (400 entries: base $((m1 - m0)) ms, now $((m2 - m1)) ms)"
```

## 7. Scope (FR-016)

```bash
B='\b(flutter|dart|pubspec|supabase|gradle|graphify|speckit|superpowers)\b'
[ "$(printf '+uses speckit\n' | grep -ciE -- "$B")" = "1" ] || fail "FR-016 control: the vocabulary pattern matches nothing"
v=$(git diff "$BASE" -- scripts | grep '^+' | grep -v '^+++' | grep -ciE -- "$B")
[ "$v" = "0" ] || fail "FR-016 $v banned-word lines on a STRICT surface"
git diff --quiet "$BASE" -- handoff pipeline || fail "FR-016 a plugin file changed"
[ -z "$(git ls-files --others --exclude-standard -- handoff pipeline)" ] || fail "FR-016 an untracked file in a plugin"
I='[]a-zA-Z0-9.)][{][0-9]+(,[0-9]*)?[}]'
[ "$(printf '+  /^ [ ]{0,3}##/\n+ x="${1}"\n' | grep -cE -- "$I")" = "1" ] || fail "FR-016 control: the interval pattern does not match exactly the planted interval"
iv=$(git diff "$BASE" -- scripts | grep '^+' | grep -v '^+++' | grep -cE -- "$I")
[ "$iv" = "0" ] || fail "FR-016 $iv added lines hold an interval expression"
[ "$(git diff "$BASE" -- scripts tests | grep '^+' | grep -v '^+++' | grep -cF -- '\/')" = "0" ] || fail "FR-016 an added line holds \\/ (bash 3.2)"
# New test code too: no interval expression in an awk pattern (BSD awk).
ti=$(git diff "$BASE" -- tests | grep '^+' | grep -v '^+++' | grep 'awk' | grep -cE -- "$I")
[ "$ti" = "0" ] || fail "FR-016 $ti added awk lines in the tests hold an interval expression"
echo "FR-016 ok (no count in prose is a review check, not a script check)"
```

## 8. The house suite (SC-007)

```bash
tap=$(mktemp)
"$BATS" -r --print-output-on-failure tests handoff/tests pipeline/tests > "$tap" 2>&1
rc=$?
bash scripts/check-suite.sh 252 "$tap" || fail "SC-007 suite (rc $rc, TAP kept at $tap)"
[ "$rc" = "0" ] || fail "SC-007 bats exited $rc although every line passed"
rm -f "$tap"
echo "SC-007 ok"
echo "ALL OK"
```
