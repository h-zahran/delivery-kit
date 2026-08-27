# Quickstart — validating this feature

**Feature**: `009-preflight-coverage-probe` · **Phase**: D

Ten checks. **Run each block on its own.** Do not concatenate them into one
script: joining blocks hands the runner only the last block's exit status, and a
real failure in the middle arrives as a success. That happened in this campaign
and is why this instruction is first.

**Every block ends in an explicit test**, so it can go red. Before trusting any
of them, run **Block 10**, which plants a decoy against each check and watches it
fail. A check that cannot fail is not a check.

**Run from the repository root.** A check can pass in a worktree and fail at the
root; that has held a release here before.

---

## Preconditions

```bash
git rev-parse --show-toplevel
git rev-parse --abbrev-ref HEAD
test -f .claude-plugin/marketplace.json
```

The branch must be `009-preflight-coverage-probe`. The last line is the test.

---

## Block 1 — the full house suite reports `1..147`

The headline acceptance (SC-001). The baseline before this feature is `1..134`.

```bash
out="$(mktemp)"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests > "$out" 2>&1
suite_status=$?
plan="$(head -1 "$out")"
notok="$(grep -c '^not ok' "$out" || true)"
printf 'plan line : %s\n' "$plan"
printf 'not ok    : %s\n' "$notok"
printf 'exit      : %s\n' "$suite_status"
test "$plan" = "1..147" && test "$notok" -eq 0 && test "$suite_status" -eq 0
```

**Never pipe the suite into `tail` or `head` alone.** A pipe hands the block the
*last* command's status — always zero — and cuts the plan line, which `bats`
prints first. Redirect to a file, capture the status on the next line, and close
with a test. That is what this block does.

---

## Block 2 — the growth is all in one suite: `1..33`

SC-003. This suite goes from 20 to 33; no other suite's count moves.

```bash
out="$(mktemp)"
bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/preflight.bats > "$out" 2>&1
st=$?
plan="$(head -1 "$out")"
printf 'preflight plan : %s (exit %s)\n' "$plan" "$st"
test "$plan" = "1..33" && test "$st" -eq 0
```

To confirm no other suite moved, run this second block separately:

```bash
moved="$(git diff --name-only main -- '*.bats')"
printf 'bats files changed: [%s]\n' "$moved"
test "$moved" = "pipeline/tests/preflight.bats"
```

**A suite's count cannot move unless its own file changed**, because
`tests/helper.bash` holds no `@test`. So this block, Block 1's `1..147` and this
block's own `1..33` pin SC-003 mechanically: 147 − 134 = 33 − 20 = 13.

*An earlier draft of this block printed every suite's plan line and ended in
`test -n "$f"` — which is true whatever the counts are. It could not go red on
the property it claimed to check, which by this repository's own standard makes
it decoration rather than a check.*

---

## Block 3 — the probed script is unchanged

FR-021 and SC-006. This feature reads `preflight.sh`; it does not edit it.

```bash
d="$(git diff --stat main -- pipeline/scripts/preflight.sh)"
printf 'probe diff vs main: [%s]\n' "$d"
test -z "$d"
```

---

## Block 4 — no changelog is modified

FR-022 and SC-007. **There are three changelog files in this repository**, so the
check must cover all of them rather than name one.

```bash
touched="$(git diff --name-only main | grep -i 'changelog' || true)"
printf 'changelog paths in the diff: [%s]\n' "$touched"
test -z "$touched"
```

---

## Block 5 — the probe invocation line appears exactly once

SC-004. After the conversion the line lives only in the helper's body.

**Read this before believing the number.** `run --separate-stderr` on its own is
**not** unique to the probe: `pipeline/tests/progress.bats` uses it twice for a
different script, and always did. The property is about the line that invokes
*the probe*, so the needle pairs the `run` with the probe.

```bash
awk 'BEGIN{ r = "run --separate-stderr"; p = "$PROBE"; ctl = 0
            if (index("xx run --separate-stderr yy", r)) ctl++
            if (index("xx $PROBE yy", p)) ctl++
            print "controls fired: " ctl "/2"
            if (ctl != 2) exit 3
            n = 0 }
     index($0, r) && index($0, p) { n++; print "  " FILENAME ": " $0 }
     END { print "probe invocation lines: " n; if (n != 1) exit 1 }' \
  $(git ls-files '*.bats' '*.bash')
```

The `awk` exits non-zero when the controls do not fire **or** when the count is
not one, so this block is the test. Nothing is piped.

And nothing in the suite may still invoke the script directly:

```bash
awk 'BEGIN{ a = "run "; b = "preflight.sh"; ctl = 0
            if (index("xx run  yy", a)) ctl++
            if (index("xx preflight.sh yy", b)) ctl++
            print "controls fired: " ctl "/2"
            if (ctl != 2) exit 3
            n = 0 }
     index($0, a) && index($0, b) { n++; print "  STRAY " FILENAME ":" FNR ": " $0 }
     END { print "stray direct invocations: " n; if (n != 0) exit 1 }' \
  $(git ls-files 'pipeline/tests/*.bats')
```

---

## Block 6 — the conversion is mechanical

FR-019 and SC-005: no assertion is added, removed or altered in the twenty-four
converted call sites.

The property that makes this checkable: in the diff against the base branch,
**every removed line must be a probe invocation line.** An assertion that was
altered would show up as a removed line that is not one.

```bash
strays="$(git diff main -- pipeline/tests/preflight.bats \
  | grep '^-' | grep -v '^---' \
  | grep -v 'separate-stderr' \
  | grep -v '^-  PF=' || true)"
printf 'removed lines that are not probe invocations:\n%s\n' "${strays:-  (none)}"
test -z "$strays"
```

**One removed line is allowed, and only one.** The suite's `setup()` currently
resolves the probe's path into `PF`. After the conversion nothing reads it —
`PROBE`, resolved once in `tests/helper.bash`, supersedes it — so that assignment
is removed as dead. It is an assignment, not an assertion, so removing it does
not breach FR-019.

Without that exemption this block goes red on a correct diff, which is the
mirror-image failure of the one it exists to catch. The exemption is written as
narrowly as possible: the assignment line and nothing else. `FIX` stays, because
every call site still names its fixture (FR-020), and the suite's header comment
stays, because what it explains is still true.

The suite count in Block 2 is the other half of this: a conversion that changed
an assertion would move a result, and a conversion that dropped a test would move
the count.

---

## Block 7 — no test was added for the multi-line comment case

FR-016 and SC-010. That case is already pinned, and a second test there would be
duplication presented as coverage — and would make fourteen new tests against a
stated thirteen.

The existing test must still be present and untouched, and no new test may name
that case:

```bash
existing="$(git diff main -- pipeline/tests/preflight.bats \
  | grep '^-.*constitutionSet is true once the constitution carries real principles' || true)"
printf 'the existing multi-line-comment test, removed or altered? [%s]\n' "${existing:-no}"
test -z "$existing"
```

---

## Block 8 — the six new fixtures are tracked

FR-023. **Controls matter here more than anywhere else in this document.**
`git check-ignore -v` exits 0 when it matches a *negation* rule too, so reading
its output as "ignored" is a trap that would report every fixture as excluded.
Use the quiet form, and prove it can say both things first.

**The file list must include files not yet committed.** A bare `git ls-files`
sees only the index, so before the commit gate it reports every new fixture as
absent — and a scan that lists nothing reports a clean zero. Use
`--cached --others --exclude-standard`, which is tracked plus untracked minus
ignored, and is what "would this be tracked" actually means here.

```bash
fail=0
for p in .delivery-kit/runs/x/progress.json node_modules/x/y.js; do
  git check-ignore -q -- "$p" || { echo "CONTROL FAILED: $p should be ignored"; fail=1; }
done
for p in README.md pipeline/scripts/preflight.sh; do
  git check-ignore -q -- "$p" && { echo "CONTROL FAILED: $p should not be ignored"; fail=1; }
done
echo "controls done (fail=$fail)"
for d in speckit-no-version speckit-no-flavour foreign-agent \
         constitution-nul constitution-bom constitution-unclosed; do
  n="$(git ls-files --cached --others --exclude-standard "pipeline/tests/fixtures/$d" | wc -l)"
  printf '  %-24s visible-and-not-ignored files: %s\n' "$d" "$n"
  test "$n" -gt 0 || fail=1
done
test "$fail" -eq 0
```

---

## Block 9 — no machine-specific path entered anything this feature wrote

The needles are built **inside `awk`** with `sprintf("%c", 92)`, and the block is
written with `print` so no backslash ever crosses a shell, an argv, a heredoc or
a file write. A scan written any other way lost its backslashes on the way to
disk in this campaign, searched for a drive letter alone, matched its own
construction line, and could never have found a real hit.

```bash
cat > /tmp/scan.awk <<'AWK'
BEGIN{
  bs = sprintf("%c", 92); sl = sprintf("%c", 47)
  d  = sprintf("%c%c", 68, 58)
  n[1] = d bs
  n[2] = d sl
  n[3] = sl "c" sl "Users" sl
  n[4] = sprintf("%c%c%c%c%c", 104, 95, 122, 97, 104)
  p[1] = "x " d bs " y"; p[2] = "x " d sl " y"
  p[3] = "x " sl "c" sl "Users" sl " y"
  p[4] = "x " n[4] " y"
  ctl = 0
  for (i = 1; i <= 4; i++) if (index(p[i], n[i])) ctl++
  print "controls fired: " ctl "/4"
  if (ctl != 4) exit 3
  hits = 0
}
{ for (i = 1; i <= 4; i++)
    if (index($0, n[i])) { hits++; print "  HIT " FILENAME ":" FNR ": " $0; break } }
END{ if (NR == 0) { print "SCANNED NOTHING"; exit 2 }
     print "lines scanned: " NR
     print "hits: " hits; if (hits != 0) exit 1 }
AWK
awk -f /tmp/scan.awk $(git ls-files --cached --others --exclude-standard \
      'specs/009-preflight-coverage-probe/*' \
      'pipeline/tests/fixtures/speckit-no-version/*' \
      'pipeline/tests/fixtures/speckit-no-flavour/*' \
      'pipeline/tests/fixtures/foreign-agent/*' \
      'pipeline/tests/fixtures/constitution-nul/*' \
      'pipeline/tests/fixtures/constitution-bom/*' \
      'pipeline/tests/fixtures/constitution-unclosed/*')
```

Then the two files this feature **modifies** rather than creates, where only the
added lines are its own work:

```bash
git diff main -- tests/helper.bash pipeline/tests/preflight.bats \
  | grep '^+' | grep -v '^+++' > /tmp/added.txt
lines=$(wc -l < /tmp/added.txt)
printf 'added lines to scan: %s\n' "$lines"
awk -f /tmp/scan.awk /tmp/added.txt
```

### Three things in these blocks are load-bearing

**Every needle is built from character codes, so the block cannot match its own
text.** The first draft of this check wrote the needles as literals — and then
found five hits, all of them its own construction lines and its own decoy. A
scan that reports its own source is a scan whose real output nobody will read.
Verified the only way that settles it: the scan was run **over its own file** and
reported zero hits while its controls still fired 4/4.

**The scope is this feature's own files, not the tree.** `tests/portability.bats`
is the repository's path detector and necessarily contains every one of these
patterns; `tests/helper.bash` carries one in a comment that predates this work.
Scanning them here would report a permanent, meaningless red. The tracked tree as
a whole is already covered by that suite — this block covers only what this
feature writes.

**The file list must include files not yet committed** — see Block 8. A bare
`git ls-files` reports this feature's spec documents as absent until the commit
gate, and a scan of nothing prints a clean zero. The `NR == 0` guard is the
backstop: an empty scan exits 2, which is not green.

**Two things in that block are load-bearing.**

`--cached --others --exclude-standard` is not decoration. A bare `git ls-files`
lists only what is already in the index, and this feature's spec documents are
not committed until the commit gate — so the scan would run over **zero files**
and print a clean `hits: 0`. Measured: as first written, this block scanned
nothing and passed. That is the exact failure this campaign keeps meeting.

The `NR == 0` guard is the second half of the same lesson. Even with the right
file list, a mistyped path glob would hand `awk` no input, and "no input" and "no
hits" print the same reassuring zero. The guard makes an empty scan exit 2, which
is not green.

---

## Block 10 — the decoy drill: prove each check can go red

**Run this before trusting Blocks 3 to 9.** A positive control proves a check
*can* fire; it never proves it fires *only* when it should — so each decoy is
removed afterwards and the file's object hash is checked back to its original
value. No `git checkout`, no `git clean`, no `git stash`: the decoy is appended
and then deleted by line, so nothing can discard work.

For each decoy: record the hash, plant, run the named block, **watch it go red**,
remove, confirm the hash is back.

The decoy itself is built from octal escapes, for the same reason the needles
are: a decoy written as a literal path would sit in this document permanently and
make Block 9 red forever.

```bash
f="specs/009-preflight-coverage-probe/plan.md"
before="$(git hash-object "$f")"
printf 'a decoy: \104\072/Github/somewhere\n' >> "$f"
tail -1 "$f"
echo "planted; now run Block 9 -- it MUST report a hit and exit non-zero"
```

```bash
f="specs/009-preflight-coverage-probe/plan.md"
sed -i '$d' "$f"
after="$(git hash-object "$f")"
printf 'hash restored? %s\n' "$after"
test "$after" = "$before"
```

Repeat the same shape for the other checks:

| Block | Decoy | Expected red |
|---|---|---|
| 2 (second) | touch any other `.bats` file | the changed-file list is no longer just this suite |
| 3 | append a comment line to `pipeline/scripts/preflight.sh` | the diff is no longer empty |
| 4 | append a blank line to any one of the three changelogs | a changelog path appears in the diff |
| 5 | add a second `run --separate-stderr` line naming `$PROBE` to the suite | the count is 2, not 1 |
| 6 | alter one assertion in a converted test | a removed line is not a probe invocation |
| 7 | delete the existing multi-line-comment test's name line | it shows as removed |
| 9 | the decoy above | one hit |

**If a block stays green with its decoy planted, the block is wrong — fix the
block, not the decoy.**

---

## The thirteen red-first drills

SC-002 is not verified by this document; it is verified **as each test is
written**, in Phase H, and cannot be checked afterwards. The rule, recorded here
so it is not lost:

- Each new test is watched failing **before** it is trusted.
- The red is produced by **inverting its operative assertion**, never by deleting
  the test — a deleted test proves only that the file was edited.
- **The altered line is echoed back** before the failure is believed. A mutation
  that silently matched nothing produced a confident, wrong answer in this
  feature's own research until its diff was checked.
- The assertion is then restored and the test watched green.

For the four warning tests, SC-009 asks for more: each must also go red when the
warning is **removed from the script**, and pass again when it is restored, with
the script left byte-identical.

**Do that on a copy of the script, not the tracked one.** Copy it to a temporary
path, mutate the copy, print the mutation's diff, drive the probe through the
copy, then confirm the tracked script's own diff is still empty. That is how this
feature's research was done, and it is why the tracked script's diff was empty
throughout.
