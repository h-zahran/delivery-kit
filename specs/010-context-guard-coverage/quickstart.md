# Quickstart — validating this feature

**Feature**: `010-context-guard-coverage` · **Phase**: D

Nine checks. **Run each block on its own.** Joining them hands the runner only
the last block's status, so a real failure in the middle arrives as success.
That happened in this campaign, which is why this instruction is first.

**Every block ends in an explicit test.** Before trusting any of them, run
**Block 9**, which plants a decoy against each and watches it fail.

**Run from the repository root.**

---

## Preconditions

```bash
git rev-parse --show-toplevel
git rev-parse --abbrev-ref HEAD
test -f .claude-plugin/marketplace.json
```

---

## Block 1 — the full house suite reports `1..154`

SC-001. The baseline before this feature is `1..147`.

```bash
out="$(mktemp)"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests > "$out" 2>&1
suite_status=$?
plan="$(head -1 "$out")"
notok="$(grep -c '^not ok' "$out" || true)"
printf 'plan line : %s\nnot ok    : %s\nexit      : %s\n' "$plan" "$notok" "$suite_status"
test "$plan" = "1..154" && test "$notok" -eq 0 && test "$suite_status" -eq 0
```

**Never pipe the suite into `tail`.** A pipe hands the block the last command's
status — always zero — and cuts the plan line, which `bats` prints first.

---

## Block 2 — the growth is all in one suite

SC-003.

```bash
out="$(mktemp)"
bash "$HOME/bats/bin/bats" --print-output-on-failure handoff/tests/context-guard.bats > "$out" 2>&1
st=$?
before=51   # MEASURED on main, not guessed
plan="$(head -1 "$out")"
printf 'guard suite: %s (exit %s), expected 1..%s\n' "$plan" "$st" "$((before + 7))"
test "$plan" = "1..$((before + 7))" && test "$st" -eq 0
```

Then, separately — a suite's count cannot move unless its own file changed, and
`tests/helper.bash` holds no test:

```bash
moved="$(git diff --name-only main -- '*.bats')"
printf 'bats files changed: [%s]\n' "$moved"
test "$moved" = "handoff/tests/context-guard.bats"
```

---

## Block 3 — the hook is unchanged

FR-015, SC-007. This feature reads the hook; a later phase owns it.

```bash
d="$(git diff --stat main -- handoff/hooks/context-guard.sh)"
printf 'hook diff vs main: [%s]\n' "$d"
test -z "$d"
```

---

## Block 4 — no changelog is modified

FR-016, SC-008. **Three changelog files exist**, so the check covers all of them
rather than naming one.

```bash
touched="$(git diff --name-only main | grep -i 'changelog' || true)"
printf 'changelog paths in the diff: [%s]\n' "$touched"
test -z "$touched"
```

---

## Block 5 — exactly three literal configuration writes remain

SC-005. **Three, not zero** — the patch-file site, the existing-configuration
site, and the site whose object also carries a `profile` key all keep their
literal writes by design. A check expecting zero would be red on a correct tree.
The number is three because the conversion was run and counted; reading the
targets alone found only two.

```bash
awk 'BEGIN{ p="printf"; c="contextGuard"; ctl=0
            if (index("x printf y", p)) ctl++
            if (index("x contextGuard y", c)) ctl++
            print "controls fired: " ctl "/2"
            if (ctl != 2) exit 3
            n = 0 }
     index($0, p) && index($0, c) { n++; print "  literal: " FILENAME ":" FNR }
     END { if (NR == 0) { print "SCANNED NOTHING"; exit 2 }
           print "literal configuration writes: " n
           if (n != 3) exit 1 }' handoff/tests/context-guard.bats
```

And the two survivors must be the expected two, not any other two:

```bash
awk 'BEGIN{ n=0 }
     /printf/ && /contextGuard/ {
       blob=$0; if (index(blob,">")==0) { getline nxt; blob=blob nxt }
       if (index(blob,"existing.json") || index(blob,"patch.json") || index($0,"\"profile\"")) ok++
       else { n++; print "  UNEXPECTED literal at " FNR ": " substr($0,1,70) } }
     END { print "expected survivors: " ok+0 "  unexpected: " n+0
           if (ok != 3 || n != 0) exit 1 }' handoff/tests/context-guard.bats
```

---

## Block 6 — the conversion is mechanical

FR-013, SC-006. Every removed line in the diff must be a configuration write or
a byte-cap idiom; anything else would be an altered assertion.

```bash
strays="$(git diff main -- handoff/tests/context-guard.bats \
  | grep '^-' | grep -v '^---' \
  | grep -v 'contextGuard' \
  | grep -v 'wc -c' \
  | grep -vE '^- *> *"' || true)"
printf 'removed lines that are neither:\n%s\n' "${strays:-  (none)}"
test -z "$strays"
```

**The fourth filter earns its place and is not a loosening.** Several converted
sites wrote their target on a *continuation line* — the `printf` on one line and
`> "$TEST_DIR/.delivery-kit.json"` on the next. The helper takes the target as an
argument, so that second line disappears, and it is neither a configuration write
nor a byte-cap idiom. Without this filter the block is **red on a correct tree**,
which is how it was found.

The pattern is deliberately narrow: a removed line that is **only** a redirect to
a quoted path. Checked rather than asserted — an altered assertion such as
`- [ "$status" -eq 0 ]` still survives the filter and is still caught.

---

## Block 7 — the documentation-snippet test is untouched

SC-010. It reads a documentation file and counts variable names. It is a real
test of a real thing, it is **not** coverage of the two overrides, and it must
survive.

```bash
gone="$(git diff main -- handoff/tests/context-guard.bats \
  | grep '^-.*for v in DELIVERY_KIT_' || true)"
printf 'the doc-snippet test, removed or altered? [%s]\n' "${gone:-no}"
test -z "$gone"
```

---

## Block 8 — no machine-specific path entered anything this feature wrote

Needles are built **from character codes**, so the block cannot match its own
text. Phase 9's first draft of this check matched its own construction lines and
had to be rebuilt; this is that rebuilt version.

```bash
cat > /tmp/scan.awk <<'AWK'
BEGIN{
  bs = sprintf("%c", 92); sl = sprintf("%c", 47)
  d  = sprintf("%c%c", 68, 58)
  n[1] = d bs; n[2] = d sl
  n[3] = sl "c" sl "Users" sl
  n[4] = sprintf("%c%c%c%c%c", 104, 95, 122, 97, 104)
  p[1] = "x " d bs " y"; p[2] = "x " d sl " y"
  p[3] = "x " sl "c" sl "Users" sl " y"; p[4] = "x " n[4] " y"
  ctl = 0
  for (i = 1; i <= 4; i++) if (index(p[i], n[i])) ctl++
  print "controls fired: " ctl "/4"
  if (ctl != 4) exit 3
  hits = 0
}
{ for (i = 1; i <= 4; i++)
    if (index($0, n[i])) { hits++; print "  HIT " FILENAME ":" FNR; break } }
END{ if (NR == 0) { print "SCANNED NOTHING"; exit 2 }
     print "lines scanned: " NR "   hits: " hits; if (hits != 0) exit 1 }
AWK
awk -f /tmp/scan.awk $(git ls-files --cached --others --exclude-standard \
      'specs/010-context-guard-coverage/*')
```

Then the two files this feature **modifies**, added lines only:

```bash
git diff main -- tests/helper.bash handoff/tests/context-guard.bats \
  | grep '^+' | grep -v '^+++' > /tmp/added.txt
printf 'added lines to scan: %s\n' "$(wc -l < /tmp/added.txt)"
awk -f /tmp/scan.awk /tmp/added.txt
```

**`--cached --others --exclude-standard` is load-bearing.** A bare `git ls-files`
sees only the index, so before the commit gate it scans **zero files** and prints
a clean zero. Measured in Phase 9, where exactly that happened. The `NR == 0`
guard is the backstop.

### And the strict-vocabulary scan

FR-017, SC-012. `handoff/tests/` is a **strict** surface — tighter than the
ground Phase 9's fixtures stood on. This is covered by the house suite rather
than by an ad-hoc check, which is the right place for it; Block 1 is therefore
also this criterion's check. Stated here so nobody adds a duplicate.

---

## Block 9 — the decoy drill: prove each check can go red

**Run this before trusting Blocks 3 to 8.** Each decoy is removed afterwards and
the file's object hash checked back. No `git checkout`, no `git clean`, no
`git stash`.

```bash
f="specs/010-context-guard-coverage/plan.md"
before="$(git hash-object "$f")"
printf 'a decoy: \104\072/Github/somewhere\n' >> "$f"
tail -1 "$f"
echo "planted; now run Block 8 -- it MUST report a hit and exit non-zero"
```

```bash
f="specs/010-context-guard-coverage/plan.md"
sed -i '$d' "$f"
printf 'hash restored? %s\n' "$(git hash-object "$f")"
test "$(git hash-object "$f")" = "$before"
```

The decoy is built from octal escapes for the same reason the needles are: a
literal path would sit in this document permanently and make Block 8 red for
ever.

| Block | Decoy | Expected red |
|---|---|---|
| 2 | touch any other `.bats` file | the changed-file list is no longer just this suite |
| 3 | append a comment to the hook | the diff is no longer empty |
| 4 | append a blank line to any changelog | a changelog path appears |
| 5 | convert one of the three exception sites | the literal count is 2, not 3 |
| 6 | alter one assertion in a converted test | a removed line is neither a config write nor a byte-cap idiom |
| 7 | delete the doc-snippet test's loop line | it shows as removed |
| 8 | the decoy above | one hit |

**If a block stays green with its decoy planted, fix the block, not the decoy.**

---

## The seven red-first drills

SC-002 is verified **as each test is written**, in Phase H, and cannot be checked
afterwards:

- Each new test is watched failing **before** it is trusted.
- The red is produced by **inverting the operative assertion**, never by deleting
  the test.
- **The altered line is echoed back** before the failure is believed. A mutation
  that silently matched nothing produced a confident, wrong answer in Phase 9
  until its diff was checked.
- The assertion is restored and the test watched green.

Two of the seven carry an extra burden, because their behaviour is a **silent
success** and inverting a status assertion proves nothing:

- **The sweep test** must show the aged file gone **and** the fresh one kept.
  Inverting only the first would pass against a run that deleted everything.
- **The empty-readings test** must show the output is empty on a run that would
  otherwise have warned — the rig's other cases supply that contrast.

## One measurement this feature owes

Phase 9 nearly doubled a suite's runtime and only noticed afterwards. This
plan claims the same will not happen here. **Measure this suite before and
after**, and record both numbers — a claim about performance is worth what its
measurement is worth.
