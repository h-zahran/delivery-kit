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

And the three survivors must be the expected three, not any other three:

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
# The four machine-path shapes are READ FROM tests/portability.bats, not
# retyped. A hand-rolled copy dropped two of them, on the one file this feature
# touches that no automated scan reaches: root tests/ is excluded from the
# tree-wide scan (':(exclude)tests/') and appears in no SHIPPED list.
eval "$(grep -E '^TP_(DRIVE_ROOT|WINDOWS_USERS|GITBASH_HOME|AGENT_PROJECTS)=' tests/portability.bats)"
for v in TP_DRIVE_ROOT TP_WINDOWS_USERS TP_GITBASH_HOME TP_AGENT_PROJECTS; do
  eval "[ -n \"\${$v:-}\" ]" || { echo "$v did not load — the scan would be narrower than it claims"; exit 1; }
done

# THE UNION, not either list. tests/portability.bats deliberately does not cover
# the forward-slash drive form — widening it there was measured and rejected,
# because the general shape matches every URL in the repository. This block's
# surface is small enough to carry it, and the first derived-needle version
# DROPPED it: Block 9 plants exactly that shape and the drill stayed green.
drivefwd="$(printf '%b' '\x44\x3a\x2f')"
RE="$TP_DRIVE_ROOT|$TP_WINDOWS_USERS|$TP_GITBASH_HOME|$TP_AGENT_PROJECTS|$drivefwd"

# NO USERNAME IS HARDCODED HERE, and that is a correction. An earlier version
# encoded this machine's own username into this tracked file, hex-escaped — a
# form built to slip past the very scans it was helping to run. That is worse
# than the leak it was looking for, and a username reaching a public branch is
# the one incident this repository's own guards record. A username leaks as
# part of a PATH, and both path shapes above already cover that. For a bare
# private term the git-ignored .leakwords list is the mechanism that exists,
# and it is folded in when present.
if [ -f .leakwords ]; then
  extra="$(grep -v '^[[:space:]]*$' .leakwords | paste -sd'|' -)"
  [ -n "$extra" ] && RE="$RE|$extra"
fi

ctl=0
printf '%b\n' 'x \x44\x3a\x5c y'                        | grep -qE "$TP_DRIVE_ROOT"     && ctl=$((ctl+1))
printf '%b\n' 'x \x43\x3a\x5cUsers\x5c y'               | grep -qE "$TP_WINDOWS_USERS"  && ctl=$((ctl+1))
printf '%b\n' 'x \x2fc\x2fUsers\x2fbob y'               | grep -qE "$TP_GITBASH_HOME"   && ctl=$((ctl+1))
printf '%b\n' 'x \x7e\x2f\x2eclaude\x2fprojects\x2fq y' | grep -qE "$TP_AGENT_PROJECTS" && ctl=$((ctl+1))
printf '%b\n' 'x \x44\x3a\x2f y'                        | grep -qE "$drivefwd"          && ctl=$((ctl+1))
printf 'controls fired: %s/5\n' "$ctl"
[ "$ctl" -eq 5 ] || { echo "a control did not fire — the scan below would mean nothing"; exit 1; }

# The SPEC files only. The two modified files are covered by part 2, which reads
# the lines this feature ADDS — and that distinction is load-bearing:
# tests/helper.bash carries a pre-existing comment naming the mixed path form
# with the identifying part elided. That is documentation, not a leak, and
# scanning the whole file with the forward-slash needle reports it.
files="$(git ls-files --cached --others --exclude-standard \
           'specs/010-context-guard-coverage/*')"
n="$(printf '%s\n' $files | grep -c .)"
printf 'files to scan: %s\n' "$n"
[ "$n" -gt 0 ] || { echo "SCANNED NOTHING — refusing to report a pass"; exit 1; }

# `/dev/null` as a trailing operand, exactly as tests/portability.bats does.
# With no file operands grep reads STDIN, so an empty list prints the same clean
# zero a clean tree does — and a bare `false` in a guard does not stop a block
# that has no `set -e`, so the guard above must exit, not merely report.
hits="$(grep -nE "$RE" -- $files /dev/null || true)"
printf 'hits: [%s]\n' "${hits:-none}"
# Handed to part 2 through a FILE, because rule 1 of this document says each
# block is run on its own and a variable does not survive that.
tmp="${TMPDIR:-/tmp}"
printf '%s' "$RE" > "$tmp/dk-scan-re"
test -z "$hits"
```

The block above already scans the two modified files whole. To scan only
the lines this feature **adds** to them — a tighter read of the same
surface — reuse `$RE` from the block above, in the same shell:

```bash
# Self-contained: it reads the needle set from the file the block above wrote,
# rather than inheriting a variable. An earlier version said "in the same
# shell", which contradicted this document's own first rule — and run the
# documented way, $RE was empty, `grep -E ""` matched every line, and the block
# went red naming a leak that did not exist.
tmp="${TMPDIR:-/tmp}"
[ -s "$tmp/dk-scan-re" ] || { echo "run the block above first — it writes the needle set"; exit 1; }
RE="$(cat "$tmp/dk-scan-re")"

git diff main -- tests/helper.bash handoff/tests/context-guard.bats \
  | grep '^+' | grep -v '^+++' > "$tmp/added.txt"
printf 'added lines to scan: %s\n' "$(wc -l < "$tmp/added.txt")"
[ -s "$tmp/added.txt" ] || { echo "no added lines were read — that is not a pass"; exit 1; }
hits="$(grep -nE "$RE" -- "$tmp/added.txt" /dev/null || true)"
printf 'hits: [%s]\n' "${hits:-none}"
test -z "$hits"
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
# Written to a FILE, not held in a shell variable. Each block here is meant
# to be extracted and run on its own, and a variable set in one block is
# gone in the next — so the one check that proves the tree was restored was
# the one check that could not be run the documented way.
# ${TMPDIR:-/tmp}, never a bare $TMPDIR. On most Linux shells TMPDIR is
# UNSET, so the bare form wrote to /decoy-hash-before, failed with
# permission denied, and the next line still planted a machine path in a
# tracked file — leaving the restore check comparing against nothing. The
# hook itself uses ${TMPDIR:-${TEMP:-/tmp}} for the same reason.
tmp="${TMPDIR:-/tmp}"
git hash-object "$f" > "$tmp/decoy-hash-before"
cat "$tmp/decoy-hash-before"
printf 'a decoy: \104\072/Github/somewhere\n' >> "$f"
tail -1 "$f"
echo "planted; now run Block 8 -- it MUST report a hit and exit non-zero"
```

```bash
f="specs/010-context-guard-coverage/plan.md"
# NOT `sed -i '$d'`. BSD sed reads -i's operand as a backup suffix, so on
# the macOS runner in this repository's matrix that form takes `$d` as the
# suffix, errors, and changes nothing — leaving the planted machine path in
# a tracked file in a public repository, which is the exact outcome the
# octal escape above exists to avoid.
sed '$d' "$f" > "$f.trimmed" && mv "$f.trimmed" "$f"
printf 'hash restored? %s\n' "$(git hash-object "$f")"
tmp="${TMPDIR:-/tmp}"
test "$(git hash-object "$f")" = "$(cat "$tmp/decoy-hash-before")"
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

- **The sweep test** must show the aged files gone **and** the ones inside the
  threshold kept. Inverting only the first would pass against a run that
  deleted everything. The shipped fixture plants a seven-day file that must
  SURVIVE beside an eight-day file that must GO — measured as the only pair
  that distinguishes `-mtime +7` from `+3` through `+6` — plus all three
  swept name patterns, an aged file the patterns do not name, and an aged
  directory that they do.
- **The empty-readings test** must show the output is empty on a run that would
  otherwise have warned — the rig's other cases supply that contrast.

## One measurement this feature owes

Phase 9 nearly doubled a suite's runtime and only noticed afterwards. This
plan claims the same will not happen here. **Measure this suite before and
after**, and record both numbers — a claim about performance is worth what its
measurement is worth.
