# Quickstart: progress.sh coverage and a timeout for every suite

**Date**: 2026-08-27 · **Feature**: `008-progress-coverage-timeout`

Every block below is runnable and is meant to be **run**, not read. Extract them
in order and execute them from the repository root.

**Two rules this guide obeys, both bought the hard way in the previous phase:**

- **No verdict is piped into `tail`, `head` or `grep`.** A pipe hands the block
  the pipe's exit status, not the command's, so a red run would leave the block
  looking green. Output is saved to a file, the status is captured on the very
  next line, and the block closes with an explicit test.
- **Every search that must find nothing fires a control that must find
  something first.** A pattern crossing an argument boundary once reported zero
  over a tree holding thirty-six matches, with no error and a clean exit.

---

## 1. Prerequisites

```bash
cd "$(git rev-parse --show-toplevel)"
git rev-parse --abbrev-ref HEAD
command -v jq >/dev/null && echo "jq ok"
BATS="${BATS:-$HOME/bats/bin/bats}"
"$BATS" --version
{ command -v ps >/dev/null || command -v pkill >/dev/null; } && echo "ps/pkill ok"
```

Expected: the feature branch, `jq ok`, a bats version of at least 1.5.0, and
`ps/pkill ok`. **bats implements the per-test limit itself** - a background
sleep and a signal - so what it needs is `ps` or `pkill`, not an external
`timeout` program. With neither it refuses out loud and exits 1 rather than
passing quietly. An earlier draft of this guide checked for the wrong thing and
called the failure silent; both halves were wrong, and both were corrected by
reading bats' own implementation and then measuring it.

---

## 2. The limit has exactly one home

```bash
grep -c 'BATS_TEST_TIMEOUT' tests/helper.bash
owners="$(mktemp)"
git ls-files -z | xargs -0 grep -ln '^BATS_TEST_TIMEOUT=' > "$owners" 2>/dev/null
cat "$owners"
test "$(wc -l < "$owners")" -eq 1 && echo "exactly one assignment site"
rm -f "$owners"
```

Expected: the shared fixture file names the setting, and it is the **only**
tracked file that assigns it. The root layout suite must no longer appear —
its assignment sat above its own `load` line and was therefore overridden.

**The pattern is anchored to the start of a line, and that is load-bearing.**
This very document mentions the setting several times — in its own search
patterns and in the throwaway fixture of section 5. Once this feature's spec
directory is committed, an unanchored search would find this file too and the
count would be two, so the block would go red for a reason that has nothing to
do with the property it checks. Only the real assignment starts at column zero.

---

## 3. Every suite reaches the fixture — derived, never counted by hand

```bash
suites=$(git ls-files '*.bats' | wc -l)
loaders=$(git ls-files '*.bats' | xargs grep -l '^load ' | wc -l)
printf 'suites=%s loaders=%s\n' "$suites" "$loaders"
test "$suites" -eq "$loaders" && echo "every suite loads the fixture"
```

Expected: the two numbers are equal. **They are derived from the tree**, so a
seventh suite that forgets its load line makes this fail. A hard-coded `6`
could not.

---

## 4. A suite that loads the real fixture receives the value

```bash
R=.delivery-kit/runs/008-progress-coverage-timeout
mkdir -p "$R"
cat > "$R/tmp-reach.bats" <<'EOF'
#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load ../../../tests/helper
@test "the limit reached this suite through the shared fixture" {
  [ -n "$BATS_TEST_TIMEOUT" ]
  echo "value=$BATS_TEST_TIMEOUT"
  [ "$BATS_TEST_TIMEOUT" -ge 30 ]
}
EOF
BATS="${BATS:-$HOME/bats/bin/bats}"
"$BATS" --print-output-on-failure "$R/tmp-reach.bats"
st=$?
rm -f "$R/tmp-reach.bats"
[ "$st" -eq 0 ]
```

Expected: one passing test. This proves the value travels through `load` into a
suite that did not set it, which is the mechanism the first requirement rests on.

**The throwaway suite lives inside the checkout, under the git-ignored run
directory, and that is not incidental.** The shared fixture resolves the
repository root from the *test file's own directory* and refuses when it cannot
find the marketplace manifest there. A throwaway placed in a system temporary
directory therefore aborts before the assertion is ever reached — measured while
writing this guide, which is why the guide does not do it.

---

## 5. The mechanism really stops a test, and names it

```bash
d="$(mktemp -d)"
printf 'BATS_TEST_TIMEOUT=2\n' > "$d/helper.bash"
cat > "$d/stop.bats" <<'EOF'
#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load helper
@test "a test that overruns is stopped and named" { sleep 6; }
EOF
BATS="${BATS:-$HOME/bats/bin/bats}"
( cd "$d" && "$BATS" stop.bats > out.txt 2>&1 )
grep -q 'timeout after 2s' "$d/out.txt" && echo "stopped, and the limit is named"
grep -q 'a test that overruns is stopped and named' "$d/out.txt" && echo "the TEST is named too"
rm -rf "$d"
```

Expected: both lines print. A deliberately tiny limit is used so the block takes
two seconds instead of a minute; the real value is checked in section 4. Nothing
tracked is edited, so nothing has to be undone.

---

## 6. The reason the guard exists survived the move

```bash
grep -n -B4 'BATS_TEST_TIMEOUT=' tests/helper.bash
grep -qi 'job cap' tests/helper.bash && echo "the hazard is still named"
grep -c 'BATS_TEST_TIMEOUT' tests/layout.bats
```

Expected: the surviving assignment carries a comment naming the hazard, and the
root layout suite's count is `0`. A guard whose stated reason is deleted becomes
a magic number to the next person who reads it.

---

## 7. The state suite grew by exactly eleven

```bash
BATS="${BATS:-$HOME/bats/bin/bats}"
out="$(mktemp)"
"$BATS" pipeline/tests/progress.bats > "$out" 2>&1
st=$?
grep -m1 '^1\.\.' "$out"
printf 'not-ok=%s exit=%s\n' "$(grep -c '^not ok ' "$out")" "$st"
rm -f "$out"
[ "$st" -eq 0 ]
```

Expected: the plan line reports 25 tests — 14 before this feature, plus the two
read tests and the nine refusal tests. `not-ok=0`, `exit=0`.

---

## 8. Every refusal names its fault

```bash
d="$(mktemp -d)"; PROG="$(pwd)/pipeline/scripts/progress.sh"
( cd "$d" && bash "$PROG" init 001-demo b main other >/dev/null
  bash "$PROG" phase-done    001-demo ZZZ 2>&1 | grep -q "unknown phase 'ZZZ'"            && echo "C1 names the phase"
  bash "$PROG" from-validate 001-demo E   2>&1 | grep -q "'plan' artefact"                && echo "C2 names the artefact"
  bash "$PROG" from-validate 001-demo F   2>&1 | grep -q "'tasks' artefact"               && echo "C3 names the artefact"
  bash "$PROG" from-validate 001-demo O   2>&1 | grep -q "no artefact rule admits it"     && echo "C4 names all three reasons"
  bash "$PROG" lock-take     001-demo     2>&1 | grep -q "needs a session id"             && echo "C5 names the argument"
  bash "$PROG" read                       2>&1 | grep -q "lock-release"                   && echo "C7 enumerates the subcommands"
  mkdir -p .delivery-kit/lock
  bash "$PROG" lock-take     001-demo s1  2>&1 | grep -q "run lock-take again"            && echo "C6 names the remedy"
  rmdir .delivery-kit/lock
  jq '.completed_phases = "x"' .delivery-kit/runs/001-demo/progress.json > t && mv t .delivery-kit/runs/001-demo/progress.json
  bash "$PROG" validate      001-demo     2>&1 | grep -q "completed_phases must be an array" && echo "C8 names the key"
  jq '.completed_phases = [] | .current_phase = "ZZZ"' .delivery-kit/runs/001-demo/progress.json > t && mv t .delivery-kit/runs/001-demo/progress.json
  bash "$PROG" validate      001-demo     2>&1 | grep -q "is not a phase this pipeline knows" && echo "C9 names the value" )
rm -rf "$d"
```

Expected: nine lines, one per refusal. Note **C6 makes the lock path a
directory** — it does not run a race. The guard above the protected write tests
for a regular file, so a directory passes it and makes the write fail: the same
branch, entered deterministically.

---

## 9. The read contract, including the line-ending trap

```bash
d="$(mktemp -d)"; PROG="$(pwd)/pipeline/scripts/progress.sh"
( cd "$d" && bash "$PROG" init 001-demo b main other >/dev/null
  SF=.delivery-kit/runs/001-demo/progress.json
  bash "$PROG" read 001-demo | jq -e . >/dev/null && echo "RC1 pure data, parser accepts it"
  awk '{printf "%s\r\n", $0}' "$SF" > t && mv t "$SF"
  bash "$PROG" read 001-demo | jq -e .feature >/dev/null && echo "RC3 still accepted with the two-character ending"
  v=$(bash "$PROG" read 001-demo | jq -r .current_phase)
  [ "$v" = "preflight" ] && echo "RC4 command substitution captures cleanly"
  bash "$PROG" read 001-demo | while IFS= read -r l; do case "$l" in *'"feature"'*) printf '%s' "$l" | cat -A > raw.txt;; esac; done
  grep -q '\^M' raw.txt && echo "RC5 the forbidden idiom DOES retain the stray character"
  jq '.completed_phases = "x"' "$SF" > t && mv t "$SF"
  n=$(bash "$PROG" read 001-demo 2>/dev/null | wc -c)
  [ "$n" -eq 0 ] && echo "RC2 broken state puts 0 bytes on the data stream" )
rm -rf "$d"
```

Expected: five lines. **RC5 is the important one** — it proves the shipped
document's warning is still true. The condition is written by the block, never
waited for; it does not arise on every machine.

---

## 10. The folding is one copy, and the test drives it

```bash
grep -n 'fold_leakwords' tests/portability.bats
c=$(grep -c 'paste -sd' tests/portability.bats)
printf 'join sites=%s\n' "$c"
test "$c" -eq 1 && echo "exactly one copy of the join"
```

Expected: the function is defined once, called at load time, and called again
inside the test — and the join it performs appears exactly **once** in the file.
Two would mean the test still carries its own copy, which is the defect this
part exists to remove.

---

## 11. Breaking the real folding turns the test red

```bash
F=tests/portability.bats
before=$(git hash-object "$F")
bak="$(mktemp)"; cp "$F" "$bak"
# The restore is armed BEFORE the mutation, and on EXIT rather than on the happy
# path. The bats run below is DESIGNED to fail; under errexit, an interrupt or a
# tool timeout, a restore written as a plain following line never runs and leaves
# a TRACKED file - the leak guard itself - mutated in the working tree.
trap 'cp "$bak" "$F"' EXIT INT TERM
# Mutate the ONE copy: stop stripping blank lines.
sed -i "s|grep -v '\^\[\[:space:\]\]\*\$' |cat |" "$F"
echo "--- mutated line, echoed before the red is believed ---"
grep -n 'paste -sd' "$F"
BATS="${BATS:-$HOME/bats/bin/bats}"
mut="$(mktemp)"
if "$BATS" -f 'leakwords' "$F" > "$mut" 2>&1; then st=0; else st=$?; fi
printf 'mutated run exit=%s (must be NON-zero)\n' "$st"
cp "$bak" "$F"; trap - EXIT INT TERM; rm -f "$bak"
after=$(git hash-object "$F")
[ "$before" = "$after" ] && echo "file restored byte-for-byte"
rm -f "$mut"
[ "$st" -ne 0 ] && [ "$before" = "$after" ]
```

Expected: the mutated line is echoed, the run exits **non-zero**, and the file is
restored byte-for-byte. The restoration is checked by hash, not assumed — a
quickstart that leaves a tracked file broken is worse than one that never ran.
**Under the old test this run would have stayed green**, which is the whole
reason this part exists.

---

## 12. The whole suite, from the repository root

```bash
BATS="${BATS:-$HOME/bats/bin/bats}"
out="$(mktemp)"
"$BATS" -r --print-output-on-failure tests handoff/tests pipeline/tests > "$out" 2>&1
st=$?
grep -m1 '^1\.\.' "$out"
n_ok=$(grep -c '^ok ' "$out")
n_bad=$(grep -c '^not ok ' "$out")
n_raw=$(grep -vcE '^(ok |not ok |1\.\.|#)' "$out")
printf 'ok=%s not-ok=%s non-TAP=%s exit=%s\n' "$n_ok" "$n_bad" "$n_raw" "$st"
tail -5 "$out"
rm -f "$out"
[ "$st" -eq 0 ]
```

Expected: `1..134`, `ok=134 not-ok=0 non-TAP=0 exit=0`. The starting point was
`1..123`; the increase is exactly the eleven new tests. Any other number is a
finding, not a footnote.

---

## 13. This feature's own documents are clean, controls first

```bash
u=$(printf 'h_%s' 'zah'); dr=$(printf 'D:%s' '\'); cu=$(printf 'C:%sUsers%s' '\' '\')
printf 'x %s y\n' "$u"  | grep -cF "$u"
printf 'x %s y\n' "$dr" | grep -cF "$dr"
printf 'x %s y\n' "$cu" | grep -cF "$cu"
echo "--- the three controls above must each print 1 ---"
for f in specs/008-progress-coverage-timeout/*.md specs/008-progress-coverage-timeout/*/*.md; do
  printf '%-62s %s %s %s\n' "$f" "$(grep -cF "$u" "$f")" "$(grep -cF "$dr" "$f")" "$(grep -cF "$cu" "$f")"
done
```

Expected: three `1`s from the controls, then every document line ending in
`0 0 0`. One fixed string per shape, never one escaped alternation — the
alternation is what collapsed silently in the previous phase.

---

## 14. The diff stays inside the test trees

```bash
dif="$(mktemp)"
git diff --name-only main > "$dif"
cat "$dif"
outside=$(grep -vcE '^(tests/|handoff/tests/|pipeline/tests/|specs/008-)' "$dif")
printf 'files outside the test trees and this feature spec: %s\n' "$outside"
changelogs=$(grep -c 'CHANGELOG' "$dif")
printf 'changelog files touched: %s\n' "$changelogs"
rm -f "$dif"
[ "$outside" -eq 0 ] && [ "$changelogs" -eq 0 ]
```

Expected: `0` outside and `0` changelogs. No shipped script is modified, and the
campaign's routing ruling assigns this phase no changelog entry.
