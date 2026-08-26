# Quickstart: verifying the 1.1.0 stamp

Run every command verbatim from the repository root. Every documented output was
MEASURED, never predicted. If a command's output disagrees with what is written here,
this document is wrong and should be fixed — that is the standing rule in this project,
and it has been exercised three times in this run alone.

**§5 resolves `bats` for itself** — `$BATS`, then `PATH`, then the author's path — and
goes red BY NAME when none of the three is runnable. Override with
`BATS=/path/to/bats bash "$qs"`. CI runs portable equivalents on three platforms.
This caveat used to live HERE, as prose outside every fence, added in the same round
that made execution mandatory — and the extractor keeps only the fenced bash blocks, so
it could never reach the script it was warning about. Anyone on another machine ran
`bash /c/Users/<user>/...`, got exit 127, and read `QUICKSTART FAIL` on a correct
release. A mitigation must travel inside the code it mitigates.

**Execute this document; do not read it.** Extract the bash blocks and run them as one
script:

```console
qs=$(mktemp)
awk '/^```bash$/{f=1;next} /^```$/{f=0} f' specs/006-release-1-1-0/quickstart.md > "$qs"
bash "$qs"; echo "EXIT=$?"; rm -f "$qs"
```

The fence above is `console`, NOT `bash`, deliberately: the extractor matches `bash`
fences, so tagging its own block `bash` would make the script extract and re-run itself.
That defect was in the first draft and was caught by RUNNING the extraction.

**The exit code is meaningful.** Every check sets `fail=1` when it fails, and §8 exits
non-zero if any did. An earlier draft printed `DISAGREE` and still exited `0`, because
the exit status was that of a trailing `wc -l` that always succeeds.

**The diff checks read BOTH the commit range and the working tree, over the SAME scope**
— the whole repository minus `specs/` and `docs/` — because each half is blind to what
the other sees. An early draft used a bare `git diff`, which is empty once the work is
committed: running this document on the committed release printed `CHANGED LINE COUNT: 0`
and failed, while three sibling checks passed vacuously. The next draft swapped wholesale
to `main...HEAD` and inverted the same fault, since a commit range cannot see uncommitted
work at all — edits to the grep-pinned orchestrator prose printed `SKILLS UNTOUCHED OK`
while `git status` showed the file modified. A third draft then widened only the RANGE
half to the whole repository, left the working-tree half pinned to two directories, and
made this claim for both: an uncommitted edit to root `README.md` or
`.github/workflows/` passed every check. §7(e) closes that; §7(d)'s two named
directories remain as the tighter pin they always were. All of it was measured on this
commit. All of it is checked now.

**`base` resolves to `origin/main` when it exists**, because a stale local `main` drags
the merge base backwards and pulls unrelated commits into the range. And note the honest
limit: once this PR merges, `main...HEAD` is empty and §7 goes red. That is a VISIBLE red
on a branch whose work is already landed, not a silent pass, and it is the correct
trade — this document verifies a pending release, not a merged one.

## 0. What the negative control does and does not cover

Before the stamp was applied, these checks were run against the unstamped tree and
FAILED, as they should:

| Check | Pre-change output |
|---|---|
| §1 agreement | `DISAGREE plugin=1.0.1 marketplace=1.0.1 changelog=Unreleased` |
| §2 shape | `SHAPE BAD` |

**That table is the COMPLETE list of checks WATCHED FAILING against the unstamped tree.
Every other assertion in this document has a positive control instead.**

One set, named once. An earlier draft called the same table "the complete list of checks
with a pre-change MEASUREMENT", which is a different set and made the table wrong by its
own description: §3's byte count and content hash WERE measured before any edit — the
contract records `3104` and `09bf16d6f4a4b59d` as pre-change values — and §4's `2.1.0`
fixture likewise. Both have a pre-change measurement and are correctly absent from the
table, because neither could have FAILED pre-change. **This table is about reds observed,
not measurements taken.**

No count is stated, deliberately. The draft before that one said "three checks have no
pre-change measurement", which was the false warrant it had been written to close: the
number was already larger, and the next round of fixes added another while the sentence
still read "three". **A hand-counted claim about this document cannot stay true across an
edit**, so the rule is stated by shape — table above, everything else below.

A check can lack a pre-change red for two reasons, neither a defect: it cannot fail
pre-change by construction (§3's hash is identical before and after by design), or it was
authored during phases I and M, after the unstamped tree was gone. What those have instead
is a **positive control** — the check watched going red on a deliberately broken copy —
recorded finding-by-finding in `specs/006-release-1-1-0/tasks.md`. Worked examples: the
date pin reddened a copy mutated to `1999-01-01` (`DATE WRONG`, exit 1); §7(e) reddened on
an untracked file at the repository root and again on an uncommitted edit to the tracked
root `README.md`; `AT REPO ROOT` reddens from any subdirectory; and `BATS RESOLVED`
reddened for a path that is a directory rather than a regular file.

**A check nobody has watched go red has been read, not verified.** With one limit on that
standard, learned in review round 5: a positive control proves a check CAN go red, never
that it goes red ONLY when it should. An earlier `AT REPO ROOT` guard passed its control
on the machine where its two path spellings happened to agree, then false-redded a correct
release on a machine where they did not. **Both directions need watching.**

```bash
fail=0
# The diff base is RESOLVED AND VALIDATED, never assumed. The old form fell through to a
# bare `main` that may not exist either, and §7 then sprayed six `fatal: bad revision`
# lines and printed five reds — QUICKSTART FAIL on a perfectly correct tree. Measured
# twice: with refs/remotes/origin/main deleted, and in a
# `git clone --depth 1 --branch <feature>` checkout, which is the shape
# actions/checkout@v4 produces by default and which this repo does use. A missing base is
# also what makes §7(d)'s range half go quiet instead of red, so the two failures compound.
# Red loudly here rather than run an audit against a revision that is not there.
base=""
for cand in origin/main main; do
  git rev-parse --verify --quiet "$cand^{commit}" >/dev/null 2>&1 && { base=$cand; break; }
done
if [ -n "$base" ] && git merge-base "$base" HEAD >/dev/null 2>&1; then
  echo "diff base: $base"
else
  echo "NO DIFF BASE — neither origin/main nor main resolves against HEAD, so §7's diff audit cannot run. A shallow or single-branch clone has no origin/main; fetch it first."
  fail=1
fi
# expect: diff base: origin/main

# Every path below is repository-root-relative, and §7(e)'s pathspec '.' means the
# CURRENT directory — so running this from a subdirectory would silently NARROW the
# audit instead of failing. §0 states the requirement in prose, and prose outside a
# fence never reaches the extracted script; that is the same defect §5 closed.
#
# The test asks GIT, not the filesystem. An earlier version compared `pwd -P` against
# `$(cd "$root" && pwd -P)`. `pwd -P` is NOT canonical across Git Bash mount aliases, so
# the two sides were built by different routes and disagreed for the SAME directory:
# measured in a clone under a Temp mount, /c/Users/... one way and /tmp/claude/... the
# other. It printed NOT AT REPO ROOT at the actual repository root and exited 1 on a
# CORRECT release — the precise false red this document exists to prevent, introduced by
# the fix that was meant to prevent it. `--show-prefix` is git's own answer: empty at the
# root, the sub-path anywhere below it, and no path string is compared at all.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && [ -z "$(git rev-parse --show-prefix)" ]; then
  echo "AT REPO ROOT OK"
else
  echo "NOT AT REPO ROOT — run from the top of the checkout; git reports prefix '$(git rev-parse --show-prefix 2>/dev/null)'"
  fail=1
fi
# expect: AT REPO ROOT OK

# portable helpers — this repo's gates use POSIX grep -E, and BSD/macOS has no grep -P
sha16() { if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi | cut -c1-16; }
```

## 1. Agreement across all three sites, one verdict (FR-001, FR-005, SC-001)

```bash
vp=$(jq -r '.version' pipeline/.claude-plugin/plugin.json)
vm=$(jq -r '.plugins[]|select(.name=="pipeline").version' .claude-plugin/marketplace.json)
vc=$(grep -m1 -oE '^## \[[^]]+\]' pipeline/CHANGELOG.md | tr -d '#[] ')
if [ "$vp" = "1.1.0" ] && [ "$vm" = "1.1.0" ] && [ "$vc" = "1.1.0" ]; then
  echo "AGREE 1.1.0"
else
  echo "DISAGREE plugin=$vp marketplace=$vm changelog=$vc"; fail=1
fi
# expect: AGREE 1.1.0
```

It compares against the LITERAL `1.1.0`, not merely the three against each other: three
sites agreeing on a WRONG version is still a failure, and a mutation setting all three to
`9.9.9` is caught here while passing the whole bats suite. That literal comparison is the
one thing this check does that the repository's durable gates do not.

## 2. The heading's shape AND its pinned date (FR-006a, SC-002a)

Shape is tested as a pattern; the date is then tested against the value the contract
pins. Shape alone is not enough — a mutation to `1999-01-01` passed the bats suite, the
CI twin, and every other check in this document. Nothing anywhere caught it.

```bash
grep -m1 -E '^## \[' pipeline/CHANGELOG.md \
  | grep -qE '^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$' \
  && echo "SHAPE OK" || { echo "SHAPE BAD"; fail=1; }
# expect: SHAPE OK
grep -m1 -E '^## \[1\.0\.1\]' pipeline/CHANGELOG.md \
  | grep -qE '^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$' \
  && echo "CONTROL OK" || { echo "CONTROL BAD"; fail=1; }
# expect: CONTROL OK — the positive control; a pattern that accepts anything is no check
d=$(grep -m1 -oE '^## \[1\.1\.0\] - [0-9-]+' pipeline/CHANGELOG.md | sed 's/.* - //')
[ "$d" = "2026-08-24" ] && echo "DATE OK" || { echo "DATE WRONG: $d"; fail=1; }
# expect: DATE OK
```

## 3. The entries beneath the heading are byte-identical (FR-004, SC-003)

This proves nothing changed WITHIN lines 6-55. It does NOT prove nothing was APPENDED at
line 56 — below the range, above the next heading. §7's diff audit closes that gap. The
two together prove FR-004; neither is complete alone.

```bash
h=$(sed -n '6,55p' pipeline/CHANGELOG.md | sha16)
[ "$h" = "09bf16d6f4a4b59d" ] && echo "CONTENT OK $h" || { echo "CONTENT CHANGED: $h"; fail=1; }
# expect: CONTENT OK 09bf16d6f4a4b59d
b=$(sed -n '6,55p' pipeline/CHANGELOG.md | wc -c)
[ "$b" -eq 3104 ] && echo "BYTES OK $((b))" || { echo "BYTES CHANGED: $b"; fail=1; }
# expect: BYTES OK 3104
```

`wc` is compared with `-eq`, not `=`: BSD `wc` LEFT-pads its count when reading stdin —
it right-aligns the number behind leading spaces and appends nothing — so a string
comparison fails on macOS against a perfectly correct file. An earlier draft said
"right-pads", which is inverted. The fix it justifies is correct either way, but this
document's standing rule is that every claim is measured, and that one was not.

## 4. The changelog's structure (FR-003, FR-006, SC-002)

```bash
u=$(grep -c '^## \[Unreleased\]' pipeline/CHANGELOG.md)
[ "$u" -eq 0 ] && echo "NO UNRELEASED OK" || { echo "UNRELEASED HEADING PRESENT: $u"; fail=1; }
# expect: NO UNRELEASED OK — rewritten in place, never left open above a new heading.
# A mutation left one open ABOVE a correct 1.1.0 heading and the bats suite PASSED,
# because its anchored grep steps over an undated heading. This line is what catches it.
n=$(grep -c '^## \[1\.1\.0\]' pipeline/CHANGELOG.md)
[ "$n" -eq 1 ] && echo "ONE 1.1.0 HEADING OK" || { echo "1.1.0 HEADING COUNT: $n"; fail=1; }
# expect: ONE 1.1.0 HEADING OK
order=$(grep -oE '^## \[[^]]+\]' pipeline/CHANGELOG.md | tr -d '#[] ' | head -3 | tr '\n' ' ')
[ "$order" = "1.1.0 1.0.1 1.0.0 " ] && echo "ORDER OK" || { echo "ORDER WRONG: $order"; fail=1; }
# expect: ORDER OK — descending. An earlier draft only PRINTED the headings with an
# "# expect: descending" comment and asserted nothing, so a reordered file passed.
```

## 5. Nothing else moved, and the suite is green (FR-002, FR-007, FR-010, SC-004)

```bash
hv=$(jq -r '.plugins[]|select(.name=="handoff").version' .claude-plugin/marketplace.json)
[ "$hv" = "2.1.0" ] && echo "HANDOFF FIXTURE OK $hv" || { echo "HANDOFF MOVED: $hv"; fail=1; }
# expect: HANDOFF FIXTURE OK 2.1.0
# The bats binary is resolved INSIDE this fence, never named in prose outside it. §0
# mandates execution and the extractor keeps only fenced bash blocks, so a caveat written
# above a fence never reaches the script that actually runs. Order: $BATS, then PATH,
# then the author's path. A binary that cannot be run goes RED by name — a document
# that certifies a release must never report green on a suite it never executed.
bats_bin="${BATS:-$(command -v bats || echo $HOME/bats/bin/bats)}"
# -f as well as -x: a DIRECTORY satisfies [ -x ] on its own, so BATS=/some/dir would
# have printed BATS RESOLVED and then failed to run the suite. Measured, not assumed.
# An if/else, NOT a red followed by a straight-line suite run. F3: the earlier form
# printed the red and then invoked "$bats_bin" ANYWAY, so BATS=/c/Users printed
# "BATS NOT RUNNABLE", then "bash: /c/Users: Is a directory", then a SECOND red, and
# left a stray mktemp file behind. The verdict was correct in every case — already red,
# still red — but a reader debugging one cause read two unrelated failures and a shell
# error. A check that has already refused a binary must not then run it.
if [ -f "$bats_bin" ] && [ -x "$bats_bin" ]; then
  echo "BATS RESOLVED $bats_bin"
  # expect: BATS RESOLVED <a path that exists on this machine>
  # The TAP output goes to a private mktemp file, never a fixed shared path. This is a
  # measured hazard, not a hypothetical: two agents running this document's own review
  # rounds concurrently corrupted /tmp/bats.out — 84 lines under a 1..121 plan, with a NUL
  # byte that made grep answer "Binary file matches", so the counts came back ok=80
  # nonTAP=2680 and this document printed QUICKSTART FAIL on a GREEN suite. Re-run to a
  # private file the same suite was exit=0 plan=1..121 ok=121 notok=0 nonTAP=0. A FALSE RED
  # on a correct release is the one outcome this document exists to prevent. The mktemp is
  # now INSIDE the runnable branch, so the unrunnable path creates no file to leak.
  bo=$(mktemp)
  "$bats_bin" --tap -r --print-output-on-failure tests handoff/tests pipeline/tests > "$bo" 2>&1
  e=$?; plan=$(head -1 "$bo"); okc=$(grep -c '^ok ' "$bo")
  nok=$(grep -c '^not ok' "$bo" || true)
  non=$(grep -cv -E '^(ok [0-9]+|1\.\.[0-9]+)' "$bo" || true)
  echo "suite: exit=$e plan=$plan ok=$okc notok=$nok nonTAP=$non"
  # The inner if/else carries the SAME rule for the same reason. With `rm -f "$bo"` inside
  # an && group, the group's exit status was rm's, so a failing rm — directory permissions,
  # a locked temp file on Windows — made the script print BOTH "SUITE OK" and "SUITE OFF
  # BASELINE" and set fail=1 on a suite that passed. Reproduced directly. That is this
  # document's own named anti-pattern, re-committed by its own cleanup one round after it
  # was written. In an if/else no command's status can select a branch, so cleanup cannot
  # change the verdict.
  if [ "$e" -eq 0 ] && [ "$plan" = "1..121" ] && [ "$okc" -eq 121 ] && [ "$nok" -eq 0 ] && [ "$non" -eq 0 ]; then
    echo "SUITE OK"
    rm -f "$bo"
  else
    echo "SUITE OFF BASELINE — full output kept at $bo"
    fail=1
  fi
  # expect: suite: exit=0 plan=1..121 ok=121 notok=0 nonTAP=0
  # expect: SUITE OK
else
  echo "BATS NOT RUNNABLE: $bats_bin — re-run with BATS=/path/to/bats"
  fail=1
fi
# expect with an unrunnable bats: exactly ONE red, then nothing — no suite line, no
# shell error, no temp file. Measured with BATS=/c/Users, both before and after.
```

The suite exceeds two minutes; slow is not hung.

## 6. No tag was created (FR-009)

```bash
[ -z "$(git tag --list 'pipeline-v1.1.0')" ] && echo "NO TAG OK" || { echo "TAG EXISTS"; fail=1; }
# expect: NO TAG OK — this run creates NO tag; the owner tags AFTER the merge
[ "$(git tag --list 'pipeline-v1.0.1' | wc -l)" -eq 1 ] && echo "TAG CONTROL OK" \
  || { echo "TAG CONTROL BAD"; fail=1; }
# expect: TAG CONTROL OK — proves the check above can actually find a tag
```

## 7. The diff audit — the WHOLE shipped surface, every line read (FR-008, SC-005)

**This section runs AFTER the release commit, not before it.** (a)(b)(c) compare
`"$base"...HEAD`, a commit range that sees nothing while the stamp is still uncommitted,
and (e) affirmatively REQUIRES a clean working tree. Measured by resetting the release
commit and leaving the three edits uncommitted: `FILE LIST DIFFERS`,
`CHANGED FILE ROWS: 0`, `CHANGED LINE TOTAL: 0`, `LINES DIFFER`, `WORKING TREE DIRTY` —
five reds and `QUICKSTART FAIL`. An earlier draft claimed it "works before and after the
commit"; that was never measured and is false. The range base exists to survive the
commit, not to precede it.

Scoped to the whole repository minus this feature's own spec tree — NOT to two
directories. An earlier draft passed `-- pipeline/ .claude-plugin/`, which would have let
an edit to root `README.md`, `CONTRIBUTING.md` or `.github/workflows/` ride inside a
release commit unseen, since the bats suite never reads the diff.

```bash
git diff --stat "$base"...HEAD -- . ':(exclude)specs/'
# expect: 3 files changed, 3 insertions(+), 3 deletions(-)

# (a) the changed FILE LIST, pinned. A line count cannot see a rename or a mode change:
#     `git mv README.md READ.md` emits ZERO +/- lines and would pass a count-only audit.
fl=$(git diff --name-only "$base"...HEAD -- . ':(exclude)specs/' | LC_ALL=C sort)
flh=$(printf '%s\n' "$fl" | sha16)
[ "$flh" = "88cd958dd7a14ba5" ] && echo "FILE LIST OK" || { echo "FILE LIST DIFFERS:"; printf '%s\n' "$fl"; fail=1; }
# expect: FILE LIST OK

# (b) per-file line counts from --numstat, which reads git's own accounting rather than
#     filtering diff TEXT. A content line reading '-- x' renders as '--- x' and any
#     header filter eats it; numstat cannot be fooled that way.
#     The numstat rows are read ONCE and the row COUNT is asserted before anything else
#     reads them. `[ -z "$bad" ]` is TRUE on an empty range, so on its own it printed
#     EACH FILE 1+1 OK for ZERO files — measured with base=HEAD. An earlier fix added the
#     row count as a SIBLING and left this line vacuous, which is the same "a sibling
#     catches it" answer §0 names as the defect. BOTH are closed now: the row count is
#     asserted, AND this line requires a non-empty range on its own account.
ns=$(git diff --numstat "$base"...HEAD -- . ':(exclude)specs/')
rows=$(printf '%s\n' "$ns" | grep -c .)
[ "$rows" -eq 3 ] && echo "THREE CHANGED FILES OK" || { echo "CHANGED FILE ROWS: $rows"; fail=1; }
# expect: THREE CHANGED FILES OK
bad=$(printf '%s\n' "$ns" | awk 'NF && ($1!=1 || $2!=1) {print $3}')
{ [ "$rows" -gt 0 ] && [ -z "$bad" ]; } && echo "EACH FILE 1+1 OK" \
  || { echo "WRONG LINE COUNTS: ${bad:-<empty range: no files to check>}"; fail=1; }
# expect: EACH FILE 1+1 OK
tot=$(printf '%s\n' "$ns" | awk '{i+=$1;d+=$2} END{print i+d}')
[ "$tot" -eq 6 ] && echo "SIX CHANGED LINES OK" || { echo "CHANGED LINE TOTAL: $tot"; fail=1; }
# expect: SIX CHANGED LINES OK

# (c) the six lines themselves, pinned. LC_ALL=C is load bearing: under a UTF-8 word
#     collation (macOS's default) sort de-prioritises punctuation, the -/+ lines
#     interleave instead of grouping, and the digest never matches on a CORRECT tree.
lines=$(git diff "$base"...HEAD -- . ':(exclude)specs/' | grep -E '^[+-]' | grep -v -E '^(\+\+\+ |--- )')
printf '%s\n' "$lines"
lh=$(printf '%s\n' "$lines" | LC_ALL=C sort | sha16)
[ "$lh" = "df3123792d299c9a" ] && echo "LINES MATCH PIN OK" || { echo "LINES DIFFER: $lh"; fail=1; }
# expect: LINES MATCH PIN OK. This display filter is BEST EFFORT and can still discard a
# content line reading '-- x' or '++ x'; that is why (b) above, not this, carries the count.

# (d) two named paths, in BOTH the commit range and the working tree.
#     The range half is gated on $rows from (b). `[ -z "$(git diff --name-only …)" ]` is
#     unconditionally true when the range is EMPTY or the revision is INVALID, because a
#     failed git command yields empty stdout too — measured: an empty range exits 0 with
#     no output and a bad revision exits 128 with no output, and both satisfy [ -z ].
#     It printed UNTOUCHED OK with a stray commit sitting in pipeline/skills/. That is the
#     same "goes quiet instead of red when its input disappears" defect (b) closed one
#     check above, re-committed here — and it fires in the documented post-merge state,
#     where the range is empty and the FR-008 guarantee reports green exactly when it has
#     stopped checking.
for p in pipeline/skills/ handoff/; do
  if [ "$rows" -eq 0 ]; then
    echo "UNTOUCHED UNCHECKED $p — empty range, nothing was compared"; fail=1
  elif [ -z "$(git diff --name-only "$base"...HEAD -- "$p")" ] && [ -z "$(git status --porcelain -- "$p")" ]; then
    echo "UNTOUCHED OK $p"
  else
    echo "TOUCHED: $p"; fail=1
  fi
done
# expect: UNTOUCHED OK pipeline/skills/  and  UNTOUCHED OK handoff/

# (e) the working tree over the WHOLE repository, not two named directories. (d) above
#     pins two specific paths, and on its own it let an UNCOMMITTED edit to root
#     README.md, CONTRIBUTING.md or .github/workflows/ pass every check in this section:
#     (a)(b)(c) are commit-range reads that cannot see uncommitted work at all, and (d)
#     looked only where it was told. Those are exactly the files §7's range half was
#     widened to cover, so the widening had been applied to one half of the audit and
#     then claimed for both. Measured: this document printed QUICKSTART PASS on a tree
#     carrying untracked files it never looked at.
#     Two exclusions, both deliberate, both named. specs/ is this feature's own spec
#     tree, excluded by the same rule (a)(b)(c) already apply. docs/ is an untracked
#     local archive that is part of no shipped surface. Everything else in the
#     repository, tracked or untracked, is in scope.
wt=$(git status --porcelain -- . ':(exclude)specs/' ':(exclude)docs/')
[ -z "$wt" ] && echo "WORKING TREE CLEAN OK" || { echo "WORKING TREE DIRTY:"; printf '%s\n' "$wt"; fail=1; }
# expect: WORKING TREE CLEAN OK
```

## 8. The verdict

```bash
[ "$fail" -eq 0 ] && echo "QUICKSTART PASS" || { echo "QUICKSTART FAIL"; exit 1; }
# expect: QUICKSTART PASS, and the script exits 0
```

Without this block the script exits with the status of its last command, which always
succeeds. That is how a broken release once produced `EXIT=0` while printing `DISAGREE`
two screens above.
