# Quickstart: verifying the 1.1.0 stamp

Run every command verbatim from the repository root. Every documented output was
MEASURED, never predicted. If a command's output disagrees with what is written here,
this document is wrong and should be fixed — that is the standing rule in this project,
and it has been exercised.

**Execute this document; do not read it.** Extract the bash blocks and run them as one
script:

```console
awk '/^```bash$/{f=1;next} /^```$/{f=0} f' specs/006-release-1-1-0/quickstart.md > /tmp/qs.sh
bash /tmp/qs.sh; echo "EXIT=$?"
```

Note the fence above is `console`, NOT `bash`, and that is deliberate: the extractor
matches `bash` fences, so tagging its own block `bash` would make the script extract
and re-run itself. That defect was in the first draft of this file, and it was caught
by RUNNING the extraction rather than by reading it.

P5 shipped a quickstart whose `tr` command had been written with a real newline instead
of the two characters `\n`. It rendered perfectly and was broken. Reading a command is
not running it.

**The exit code is meaningful.** Every section below sets `fail=1` when its check fails,
and §7 exits non-zero if any did. A previous draft of this file printed `DISAGREE` and
still exited `0`, because the exit status was simply that of the last command — a
`wc -l` that always succeeds. A phase-I reviewer caught it by mutating the tree and
observing `SCRIPT_EXIT=0` on a broken release. A check whose exit code cannot fail is
not a check.

## 0. The negative control — these checks were proven to BITE

Before the stamp was applied, every check below was run against the unstamped tree and
every one of them FAILED, as it should:

| Check | Pre-change output |
|---|---|
| §1 agreement | `DISAGREE plugin=1.0.1 marketplace=1.0.1 changelog=Unreleased` |
| §2 shape | `SHAPE BAD` |
| §3 content hash | `09bf16d6f4a4b59d` (the value it must still print AFTER) |
| §4 handoff fixture | `2.1.0` |

That first line is the whole reason FR-005 exists: two of three sites agreed, and a
check built only from the seed's named `jq` commands would have reported success.

```bash
fail=0
```

## 1. Agreement across all three sites, one verdict (FR-005, SC-001)

```bash
vp=$(jq -r '.version' pipeline/.claude-plugin/plugin.json)
vm=$(jq -r '.plugins[]|select(.name=="pipeline").version' .claude-plugin/marketplace.json)
vc=$(grep -m1 -oP '(?<=^## \[)[^\]]+' pipeline/CHANGELOG.md)
if [ "$vp" = "1.1.0" ] && [ "$vm" = "1.1.0" ] && [ "$vc" = "1.1.0" ]; then
  echo "AGREE 1.1.0"
else
  echo "DISAGREE plugin=$vp marketplace=$vm changelog=$vc"; fail=1
fi
# expect: AGREE 1.1.0
```

One command, three sites, one verdict. It compares against the LITERAL `1.1.0`, not
merely the three against each other — three sites agreeing on a WRONG version is still
a failure, and a phase-I mutation setting all three to `9.9.9` is caught right here
while passing the whole bats suite.

## 2. The heading's shape AND its pinned date (FR-006a, SC-002a)

Shape is tested as a PATTERN: a heading carrying the right version in the wrong form
still breaks every tool that reads the file by shape. The DATE is then tested against
the value the contract pins, because shape alone is not enough — a phase-I mutation set
the date to `1999-01-01` and it passed the bats suite, the CI twin, and every other
check in this document. Nothing anywhere caught it. That is what the last two lines of
this section are for.

```bash
grep -m1 '^## \[' pipeline/CHANGELOG.md \
  | grep -qP '^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$' \
  && echo "SHAPE OK" || { echo "SHAPE BAD"; fail=1; }
# expect: SHAPE OK
# positive control — the pre-existing 1.0.1 heading must also match:
grep -m1 '^## \[1\.0\.1\]' pipeline/CHANGELOG.md \
  | grep -qP '^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$' \
  && echo "CONTROL OK" || { echo "CONTROL BAD"; fail=1; }
# expect: CONTROL OK
d=$(grep -m1 -oP '(?<=^## \[1\.1\.0\] - ).*' pipeline/CHANGELOG.md)
[ "$d" = "2026-08-24" ] && echo "DATE OK" || { echo "DATE WRONG: $d"; fail=1; }
# expect: DATE OK
```

## 3. The entries beneath the heading are byte-identical (FR-004, SC-003)

Exactly one line was replaced by exactly one line, so the entries did not shift line
numbers. Be precise about what this proves: nothing was changed WITHIN lines 6-55. It
does NOT by itself prove nothing was APPENDED at line 56 — below the range, above the
next heading. §6's diff audit closes that gap, because such an entry appears there as a
seventh changed line. The two sections together prove FR-004; neither is complete alone.

```bash
h=$(sed -n '6,55p' pipeline/CHANGELOG.md | sha256sum | cut -c1-16)
[ "$h" = "09bf16d6f4a4b59d" ] && echo "CONTENT OK $h" || { echo "CONTENT CHANGED: $h"; fail=1; }
# expect: CONTENT OK 09bf16d6f4a4b59d
b=$(sed -n '6,55p' pipeline/CHANGELOG.md | wc -c)
[ "$b" = "3104" ] && echo "BYTES OK $b" || { echo "BYTES CHANGED: $b"; fail=1; }
# expect: BYTES OK 3104
```

## 4. Nothing else moved (FR-002, FR-006, SC-002)

```bash
hv=$(jq -r '.plugins[]|select(.name=="handoff").version' .claude-plugin/marketplace.json)
[ "$hv" = "2.1.0" ] && echo "HANDOFF FIXTURE OK $hv" || { echo "HANDOFF MOVED: $hv"; fail=1; }
# expect: HANDOFF FIXTURE OK 2.1.0
u=$(grep -c '^## \[Unreleased\]' pipeline/CHANGELOG.md)
[ "$u" = "0" ] && echo "NO UNRELEASED OK" || { echo "UNRELEASED HEADING PRESENT: $u"; fail=1; }
# expect: NO UNRELEASED OK — rewritten in place, never left open above a new heading.
# A phase-I mutation left one open ABOVE a correct 1.1.0 heading; the bats suite passed,
# because its anchored grep steps over an undated heading. This line is what catches it.
n=$(grep -c '^## \[1\.1\.0\]' pipeline/CHANGELOG.md)
[ "$n" = "1" ] && echo "ONE 1.1.0 HEADING OK" || { echo "1.1.0 HEADING COUNT: $n"; fail=1; }
# expect: ONE 1.1.0 HEADING OK — exactly one, never two
grep -n '^## \[' pipeline/CHANGELOG.md | head -3
# expect: [1.1.0] first, then [1.0.1], then [1.0.0] — descending; no line number relied on
[ -z "$(git status --porcelain -- handoff/)" ] && echo "HANDOFF CLEAN OK" || { echo "HANDOFF DIRTY"; fail=1; }
# expect: HANDOFF CLEAN OK
```

## 5. The suite is green against baseline (FR-007, SC-004)

The full suite exceeds two minutes. Run it with that in mind; slow is not hung.

```bash
bash /c/Users/h_zah/bats/bin/bats --tap -r --print-output-on-failure tests handoff/tests pipeline/tests > /tmp/bats.out 2>&1
e=$?; plan=$(head -1 /tmp/bats.out); okc=$(grep -c '^ok ' /tmp/bats.out)
nok=$(grep -c '^not ok' /tmp/bats.out || true)
non=$(grep -cv -E '^(ok [0-9]+|1\.\.[0-9]+)' /tmp/bats.out || true)
echo "suite: exit=$e plan=$plan ok=$okc notok=$nok nonTAP=$non"
{ [ "$e" = 0 ] && [ "$plan" = "1..121" ] && [ "$okc" = 121 ] && [ "$nok" = 0 ] && [ "$non" = 0 ]; } \
  && echo "SUITE OK" || { echo "SUITE OFF BASELINE"; fail=1; }
# expect: suite: exit=0 plan=1..121 ok=121 notok=0 nonTAP=0
# expect: SUITE OK
```

## 6. The diff audit — every changed line, read (FR-008, SC-005)

The suite proves nothing BROKE. Only the diff proves nothing else CHANGED — and it is
what closes §3's tail gap, because an entry appended at line 56 appears here as a
seventh changed line.

```bash
git diff --stat -- pipeline/ .claude-plugin/
# expect: 3 files changed, 3 insertions(+), 3 deletions(-)
c=$(git diff -- pipeline/ .claude-plugin/ | grep -E '^[+-]' | grep -v -E '^(\+\+\+|---)' | wc -l)
[ "$c" = "6" ] && echo "SIX CHANGED LINES OK" || { echo "CHANGED LINE COUNT: $c"; fail=1; }
git diff -- pipeline/ .claude-plugin/ | grep -E '^[+-]' | grep -v -E '^(\+\+\+|---)'
# expect exactly six lines: the three old values removed, the three new ones added
[ -z "$(git diff --name-only -- pipeline/skills/)" ] && echo "SKILLS UNTOUCHED OK" \
  || { echo "SKILLS TOUCHED"; fail=1; }
# expect: SKILLS UNTOUCHED OK — the grep-pinned orchestrator prose is not touched at all
[ -z "$(git tag --list 'pipeline-v1.1.0')" ] && echo "NO TAG OK" || { echo "TAG EXISTS"; fail=1; }
# expect: NO TAG OK — this run creates NO tag (FR-009); the owner tags after the merge
[ "$(git tag --list 'pipeline-v1.0.1' | wc -l)" = "1" ] && echo "TAG CONTROL OK" \
  || { echo "TAG CONTROL BAD"; fail=1; }
# expect: TAG CONTROL OK — proves the check above can actually find a tag
```

Three changed lines could still be the WRONG three, which is why this section reads the
lines rather than trusting the count.

## 7. The verdict

```bash
[ "$fail" = 0 ] && echo "QUICKSTART PASS" || { echo "QUICKSTART FAIL"; exit 1; }
# expect: QUICKSTART PASS, and the script exits 0
```

Without this block the script exits with the status of its last command, which always
succeeds. That is how a broken release once produced `SCRIPT_EXIT=0` while printing
`DISAGREE` two screens above.
