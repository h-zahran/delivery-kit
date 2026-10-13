# Verification rigs for the context guard

Two harnesses for `handoff/hooks/context-guard.sh`. Neither is a test and
neither runs in CI — they are tools you point at the hook when you are about to
believe something about it.

They live here rather than under `handoff/` on purpose: `handoff/` is copied
onto every user's machine at install, and these are maintainer tools. A clone
of this repository gets them; a plugin install does not.

The section "Notes moved from the hook", second from the end, holds the
measurement notes that used to be comments in the hook itself.

| Script | Answers |
|---|---|
| [`differential.sh`](./differential.sh) | "Did this refactor change what the guard does?" |
| [`field-order-mutation.sh`](./field-order-mutation.sh) | "Would the suite notice if the jq field order drifted?" |

## Why they exist

The guard runs after every tool call and its whole job is to speak up. The
failure that matters is **silence**, and silence passes tests that were written
to check what the guard says when it speaks.

Phase 14 shipped a change that passed all 163 tests and 3-OS CI while doing two
things nobody wanted: a configuration value containing a newline was truncated,
taking the three settings after it with it; and a payload field of an
unexpected type made jq exit non-zero, leaving the guard silent — the one
direction the hook's own comments say it must never fail in. `differential.sh`
found both. The suite never would have.

## `differential.sh`

```bash
scripts/context-guard/differential.sh [<baseline-ref>]
```

Runs a baseline copy of the hook and the working copy over every payload,
configuration and transcript shape in the file (`grep -c '^run_shape '
scripts/context-guard/differential.sh` counts them; it said 30 here long after
it stopped being true), comparing stdout and exit code on each. Exit status is 0
only when every shape matches.

**Pin the baseline to a commit id, not a branch.** This repository
rebase-merges, so once your branch lands, `origin/main` *is* your change and
the differential compares the hook with itself — a flawless zero having tested
nothing. The script refuses when the two files are identical rather than
reporting that zero, but the refusal only catches the exact case; a baseline
that is merely *wrong* still runs.

**Run the positive control.** `NEWHOOK=<path>` compares a different file, so
you can point it at a deliberately broken hook and confirm the harness still
reports a difference. A harness that has only ever printed zero has not been
shown capable of printing anything else.

Measured 2026-09-01, working copy against `45e6b12`:

| Run | Result |
|---|---|
| the shipped hook | **30 shapes, 30 identical, 0 different** |
| a control with the config split reverted to `read` | **29 identical, 1 different** — and the one flagged is the newline shape |

### Transcript shapes, added 2026-09-02

The 30 shapes above vary the payload and the configuration. The transcript was a
fixed six readings hardcoded inside `run_shape`, which was enough while the
reading count, the median and the fallback lived in three separate calls that no
refactor was touching. Shapes now vary the file being read: empty, one reading,
fourteen, fifteen, sixteen, an unparseable line among good ones, a non-numeric
token value, a non-numeric cache field, a record whose three token fields are ALL
strings, another whose three strings concatenate into NUMERIC text, a byte cap
that starves the read down to that concatenated junk ALONE, sidechain
entries, a negative reading, a median-window shape, and two byte-cap shapes that
force the uncapped re-read.

**This paragraph carries no total, on purpose.** Count it:
`grep -c '^run_shape "transcript:' scripts/context-guard/differential.sh`. It said
thirteen when there were fourteen, was corrected to fourteen, and was wrong again
within the hour when a fifteenth arrived. Carrying no total did not save the
LIST: a sixteenth shape arrived and the sentence above went on naming fifteen of
them until the release pass. All three times, the shape left out was an asserted
difference, which is the whole evidentiary basis for a divergence
recorded below. A number in prose is a claim that goes stale silently; the exact
figures live in the dated table below, which is a record of one run rather than a
statement about the current file. Fourteen and sixteen matter most — they sit either side of the floor of
fifteen, which is where the fallback is decided.

Measured 2026-09-02, working copy against `168edc1`:

| Run | Result |
|---|---|
| the hook with the one-pass reading change | **45 shapes, 45 as expected, 0 unexpected**, 2 of them asserted to differ |
| a control with the fallback floor set to 0 | **42 as expected, 3 unexpected** — both transcript byte-cap shapes and `config: maxBytes tiny` |
| a control taking the FIRST fifteen readings rather than the last | **44 as expected, 1 unexpected** — the median-window shape |
| a control replacing the count rule with a plain `length` | **45 as expected, 0 unexpected** — the harness cannot see it at all, by construction |

That table is left exactly as it was recorded. It is a record of one run on
2026-09-02, when the harness held 45 shapes and asserted 2 divergences; a
sixteenth transcript shape and a third asserted divergence landed after it. It
is not a statement about the current file, and rewriting it would destroy the
evidence that the count moved.

Measured 2026-09-03 at merged `main` = `90615c3`, against `168edc1`:

| Run | Result |
|---|---|
| the shipped hook | **46 shapes, 46 as expected, 0 unexpected**, 3 of them asserted to differ, exit 0 |

One row, because one run was made. The three control rows above were not
re-run on this date and are not restated here as though they had been.

Measured 2026-09-04, working copy against `2658b62`, for the threshold-boundary
change (feature 017):

| Run | Result |
|---|---|
| the hook with the threshold boundary moved to `-lt 100` | **49 shapes, 49 as expected, 0 unexpected**, 1 asserted to differ, **3 auto-relaxed to same**, exit 0 |
| a control with the baseline set to `f495823~1`, before the one-pass reading change | **49 as expected, 0 unexpected**, **4** asserted to differ, **0 auto-relaxed**, exit 0 |
| a control asserting a settled divergence on a shape that does differ | **48 as expected, 1 unexpected**, exit 1 — the shape reported that its divergence is already in the baseline and the sides should agree |
| three controls on the anchor hard stops: an unresolvable id, a pre-rebase orphan, an unknown expectation | **exit 9 on each**, naming the anchor and the reason |


Measured 2026-09-05, after the feature landed on `main`, anchoring its own shape:

| Run | Result |
|---|---|
| baseline `2658b62`, before the divergence | **49 as expected, 0 unexpected**, 1 asserted to differ, 3 auto-relaxed, exit 0 |
| baseline `5ff33c6`, at the divergence | **49 as expected, 0 unexpected**, 0 asserted to differ, **4** auto-relaxed, exit 0 |

Two rows, two runs. The same assertion, correct on both sides of its own merge
with no edit between them — which is the whole point of the `diff@` form.

**The rebase prediction held.** The anchor is `5ff33c6`, read off `origin/main`
after the merge. The ids the branch itself carried, `2b24438` and `987c9c5`, are
**not** ancestors of `main`: the rebase-merge replaced them. An anchor copied
from the branch would have named a commit reachable from nothing, and
`run_shape` would have refused it by name.

Four rows, because four runs were made (the last row is three runs of the same
shape, one per hard stop). Earlier control rows are not restated.

The count moved from 46 to 49 because this feature added the three
`thresholdPct` boundary shapes. Only one of them is asserted to differ: with
the readings at 50% of a 360000-token window, a threshold of 100 goes from
**silent** on the baseline to firing on the candidate — 0 bytes against 556 —
while 99 and 101 are asserted the *same*, which is how the change is shown to
be bounded rather than merely present.

### Read-ladder shapes, added 2026-10-10

Audit item 12 made the guard read the last 1MB first, then `maxBytes`, then the
whole file, stopping at the first read that holds fifteen readings, and skip a
read that already held the whole file. Six shapes cover it: twenty readings at
the end of a 1.2MB file; a gap that starves the first read while `maxBytes`
holds the file; a gap that starves both capped reads (with `maxBytes` 1500000);
a file of exactly 1MB; a file of 1MB and one byte; and a file one byte past a
`maxBytes` of 1200000. Every one makes the guard speak, and each starved shape
is built so the starved read and the right read print different percentages:
a gap shape says 65% from the starved read and 50% from the right one, an edge
shape 70% and 50%, because cutting one byte off the front of the file cuts its
first line, which holds a reading.

Measured 2026-10-10, working copy against `7b094cd`:

| Run | Result |
|---|---|
| the hook with the read ladder | **55 shapes, 55 as expected, 0 unexpected**, 0 asserted to differ, 4 auto-relaxed, exit 0 |
| a control that never climbs past the first read | **48 as expected, 7 unexpected** — the three byte-cap shapes from before and four of the six new ones |
| a control that calls a file one byte too long already read | **53 as expected, 2 unexpected** — the two one-byte-past shapes |
| a control that skips the whole-file read after a starved `maxBytes` read | **53 as expected, 2 unexpected** — both-caps-starve and one byte past `maxBytes` |

All four rows were run again the same day on the hook with the review fix
described below, the size measured after each read, with the same results.

What the ladder saves is processes and bytes, never an answer, so this harness
can show only that the answer did not move. The saving is pinned by the
`spend:` tests in `handoff/tests/context-guard.bats`, which count every `jq`,
`tail` and `wc` the guard starts, exactly.

Review then found the one way the ladder could change an answer, and it is a
way this harness cannot reach, because its transcripts hold still. Claude Code
appends while the hook runs. The size was measured once, after the 1MB read,
and reused to decide that the `maxBytes` read had held the whole file; a file
that grew past `maxBytes` in between was cut at its start, and the guard went
silent where the old one fired at 95%. The size is now measured again after the
`maxBytes` read. The test "a transcript that grows during the hook is measured
after each read" makes the file grow from inside a `wc` shim, and goes red on
the hook before the fix.

### An asserted difference is relative to a baseline, and now says so

The 2026-09-03 row above was measured against `168edc1`, and its three asserted
divergences were correct against it. Run the same harness against any baseline
that already contains `f495823` — which merged `main` now does — and all three
reported "expected a DIFFERENCE and found none" on a hook nobody had touched.
Measured 2026-09-04: three UNEXPECTED on a correct tree.

Nothing was wrong with the hook, or with the shapes. The assertions had outlived
their baseline and the harness had no way to know, because `diff` says *these two
disagree* without saying *since when*. Left alone that is permanent red — the
failure the `diff` expectation exists to prevent, reached from the other side.

An assertion may therefore name the commit that introduced its divergence:

```
run_shape "<label>" "$PAYLOAD" "<config>" "<transcript-shape>" diff@<commit>
```

If the baseline already contains that commit, the divergence is settled history,
the two sides *should* agree, and the expectation becomes `same` — reported as
`agrees; its asserted divergence (<commit>) is already in the baseline`. If the
baseline does not contain it, `diff` stands unchanged. One assertion, correct on
both sides of its own merge, needing no edit on the day it lands.

The commit must be an id, not a branch or tag: this repository rebase-merges, and
only a post-landing id is reachable from `main` at all. Take the anchor from
`origin/main` AFTER the branch lands, never from the branch: measured 2026-09-04,
`9148066` and `f495823` have identical trees and only the second is an ancestor
of `main`. The harness refuses an unreachable anchor by name.

Both directions were controlled, not assumed — see the second and third rows of
the 2026-09-04 table. A settled divergence that *does* still differ is a real
finding and goes red with its own message, rather than being quietly absorbed.

### What this harness cannot see, and why that is structural

It compares **stdout and exit status only**. Two consequences, both measured
rather than reasoned:

- **A change that only costs a process is invisible.** The guard's reading count
  decides whether it reads more; it never decides the answer. Every read is a
  byte suffix, so a suffix holding fifteen or more readings has the same last
  fifteen as the file, and one holding fewer reads more under either counting
  rule. Mutating the count rule to a plain `length` reports **every shape as
  expected**. On a straddle of fourteen positive readings and one negative —
  fifteen by `length`, fourteen by the digit rule — the shipped hook spent 5 jq
  processes, the mutant 4, and both emitted an identical 556 bytes. That rule
  was pinned by the spawn-counting rig in
  `specs/015-guard-jq-spawn-two/quickstart.md`; since 2026-10-10 the size check
  stops both sides after one read on that rig's short file, and the rule is
  pinned by the `spend:` test for a negative reading instead. Nothing here can
  pin it.
- **A change that only moves stderr is invisible.** `run_shape` captures stderr
  per side and never compares it. Deliberate — the guard's contract is its
  stdout — but it means this harness cannot settle a question about diagnostics.

A third limit is worth knowing before you trust a single clean run: one spurious
`DIFF` on the `agent_id null` shape was observed once and did not reproduce in
five further runs. A single clean run is one sample, not a proof.

### Expectations: a shape may assert that the two sides DIFFER

`run_shape` takes an optional fifth argument, `same` (the default) or `diff`.
A `diff` shape fails when the two sides agree. It exists for a divergence that
has been examined and kept: without it the only options are to leave the shape
out, which lies by omission, or to leave the harness permanently red, which
trains a reader to skim past the one line that matters. An asserted difference
goes red if the divergence is ever quietly repaired — the direction nobody
watches.

The string-reading shapes described below use it, and their count is best
taken from the file:
`grep -cE '^run_shape .* diff@f495823$' scripts/context-guard/differential.sh`.
It is scoped to `f495823`, the commit that brought them in, because the
threshold divergence (`diff@5ff33c6`) is anchored the same way and belongs to a
different rule, and the wider `diff@[0-9a-f]+$` counts it as well. This
paragraph said "one shape" while the 2026-09-02 table already said two, and it
still said two after a third arrived. Name the table, never a line distance —
the distance changed the moment a second table was added above.

They all come from the same root: jq's `+` concatenates strings instead of
erroring, so a usage record whose three token fields are all strings yields a
string reading. `all three fields strings` covers the case where that string does
not parse as a number — the old hook's separate median call failed on the whole
stream and collapsed to silence, 0 bytes against 556. `strings that parse as a
number` covers the case where it does — the old hook re-parsed it into a genuine
reading and inflated the median, 556 against 0. `junk alone under the byte cap`
starves the capped read to that junk, so the old hook cleared the fifteen-reading
floor on it and skipped the re-read entirely, 556 against 0 — the only one of
them that moves the FALLBACK DECISION rather than the median.

The summary line says **AS EXPECTED**, not IDENTICAL, and counts the asserted
differences out separately. It said IDENTICAL for one commit, which reported a
run where a shape differed by design as a run where nothing did.

### Run it only on a branch you have read

The script copies `handoff/hooks/context-guard.sh` out of the **working tree**
and executes it. Isolating `HOME` and the three temporary-directory settings
bounds where the hook writes its flags; it does not sandbox anything. Running
this against a branch you have not read is running that branch's shell script
as yourself.

### Two shapes that reported ok on a hook with its fallback switched off

Worth reading before adding a shape of your own, because the failure looked
exactly like success. The byte-cap shapes were written with a window of a million
tokens. That puts the readings at 18% of the window, below the guard's threshold,
so the guard says **nothing** — and two silences compare equal. Both shapes
reported `ok` against a control whose uncapped re-read had been disabled
outright: the floor-to-zero control passed every shape. Leaving the window at its
default makes the same readings 90%, the guard speaks, and the control is caught.

A shape that cannot make the guard SPEAK cannot tell you it has stopped speaking.

The same defect was then found in a shape that predates all of this: `config:
maxBytes tiny` carried the same million-token window, and it was the only
pre-existing shape that touched the fallback at all. It is now left at the
default window too. Measured on the shipped hook, every transcript shape makes
the guard speak except two: `empty file`, and `strings that parse as a number`
whose whole point is that the new hook is correctly silent where the old one was
loud. A silent shape can catch a guard that starts speaking, never one that
stops — which is why the rest were built to make it speak.

One more claim was corrected rather than defended: the fourteen and fifteen and
sixteen shapes do NOT exercise the fallback on their own. Without a byte cap
the capped read already holds the whole file, so the re-read returned the same
median and the floor never mattered (since 2026-10-10 the guard sees this from
the file's size and makes no re-read). The floor-to-zero control differs on the
byte-cap shapes and on neither plain one. The plain counts still guard against
a crash and against a shape-table slip; they were simply credited with more
than they do.

### The trap it took two goes to find

Each side gets its own `HOME`, `TMPDIR`, `TEMP` **and** `TMP`. The guard writes
its once-per-5%-bucket flag to `$TMPDIR/ctx-warned-<session>`, *not* under
`HOME`. Isolate only `HOME` and the baseline fires first, leaves the flag
behind, and silences the candidate — which reports as "baseline speaks,
candidate is silent" on every shape that fires. That mistake reported **7 of 30
shapes different on a hook that was correct**, and the false report looks
exactly like the catastrophic regression you are hunting.

## `field-order-mutation.sh`

```bash
git worktree add --detach /tmp/mutwt HEAD
scripts/context-guard/field-order-mutation.sh /tmp/mutwt [extra-suite.bats ...]
```

The hook extracts every payload field in one jq call and every configuration
setting in another, joins them with a separator byte, and splits the result
positionally in shell. jq and the shell therefore agree on field order by
convention alone. This rig reorders each array one transposition at a time —
twelve in all — and reports whether the suite notices.

Extra `.bats` files are scored in their own columns, which is how you find out
whether a proposed tripwire adds coverage or duplicates it.

Measured 2026-09-01 at `168edc1`:

| Reorder | `context-guard.bats` |
|---|---|
| all 12 transpositions, both arrays | **RED on every one** |
| `.thresholdTokens` ↔ `.maxBytes` | 5 red: tests 21, 32, 33, 35, 58 |
| `.session_id` ↔ `.cwd` | 46 of 58 red |

Be exact about the provenance of that table, because it matters when you trust
it: it was produced by the scratch rig this script was hardened from. The
committed script was re-run on 2026-09-02 and reproduced the first four rows
identically before being stopped for time — enough to show the rewritten
array-finding works, not enough to call the whole table freshly reproduced. A
full run takes roughly forty minutes, because every row runs the entire
58-test suite twice over.

That result is why no structural field-order test was ever added. Review
asserted twice that a reorder leaves the suite green; the coupling is in fact
pinned **emergently**, because every setting and every payload field already
has a behavioural test asserting its observable effect. Emergent coverage is
invisible to a reviewer looking for a named test — measure before you believe
either answer.

### Three guards, each closing a failure that produced false evidence first

1. **It refuses to run in the main checkout.** An earlier version edited the
   tracked hook in place; a ten-minute tool timeout killed its wrapper but not
   the script, and the orphan went on mutating a tracked file twice more,
   unnoticed. Hash the hook after any long rig.
2. **Every mutant must pass `bash -n` before any suite runs.** An earlier
   version dropped the newline when splicing, fusing the new line with the one
   below. Every mutant was a broken script, every suite failed, and the table
   read as a flawless sweep of catches.
3. **A mutant identical to the original is reported as `NO-OP`, not as a pass.**
   A mutation that did not land is a silent false green.

It also finds both jq arrays **by pattern, never by line number**, and asserts
the field names it expects are actually on the line it found — a rig that
mutates the wrong line still produces a full table of plausible results.

## Notes moved from the hook

These notes used to be comments in `handoff/hooks/context-guard.sh`:
measurement stories, histories of how a fault was found, long experiments
and numbers from past runs. They moved here word for word from the hook at
`3e36d78`, with only the comment markers removed. The hook keeps each
load-bearing rule beside its code, in a shorter form, and a pointer line
naming the section here:

```bash
# Why: scripts/context-guard/README.md, "<section>".
```

A test in `handoff/tests/context-guard.bats` holds every pointer to a section
under this heading and every section to a pointer. In the quoted text,
"above", "below" and "this line" mean the hook, at the pointer.

### Threshold of 100, measured

From the hook, beside `is_valid_threshold`:

100 is the value this rule exists for, and the reason the comparison is
`-lt` rather than `-le`. 450 is obviously a typo for 45 and looks wrong on
sight; "warn me at 100%" reads like a deliberate choice and disarms the
guard just as completely. MEASURED 2026-09-04 against the previous `-le`:
with thresholdPct 100 and observed context at half the window, the guard
emitted nothing at all. Pinned in both directions by the boundary tests in
handoff/tests/context-guard.bats — 100 refused, 99 accepted.

### Payload extraction, measured

From the hook, above the payload `jq` call, on why it is one call:

Every field this hook needs from the payload, in ONE jq call rather than one
call per field. This hook runs on PostToolUse after EVERY tool call, and
process spawn dominates on Windows under Git Bash, which is a supported
platform. Measured 2026-09-01, on the NON-FIRING path — the one that follows
almost every tool call: this took the whole run from 8/12/16 jq processes to
5/6/7, for zero, one and two config files present. A firing run spends one
more, on the emission at the bottom of this file, which is the output itself.

From the hook, above the payload `jq` call, on reading stdin and the drain:

jq READS STDIN ITSELF. The payload used to be copied into a shell variable at
the top of this file and written back out here through a pipe — a `cat` and a
`printf` subshell, on every run, for a value with exactly ONE consumer.

THE DRAIN AFTER A FAILED CALL IS NOT BELT AND BRACES. It was a `|| cat` beside
the call until the jq probe moved onto the same branch. jq reads to end of
input only while the input keeps parsing: hand it something malformed at its
FIRST token and it
aborts at once, having read a buffer's worth and no more. The caller is then
writing into a pipe nobody is reading, and takes the same broken-pipe death
the drain exists to prevent — measured, 3 runs of 3, a 300KB payload
beginning `{not json`: writer exit 141 without this, 0 with it, and 0 on the
hook that copied stdin. This is the mirror image of the fault the copy's
removal closed, and it was found by review rather than by the harness, which
compares the hook's own stdout and never the writer's status.

It costs NOTHING on the path that matters. The branch runs only when jq exits
non-zero, which for a well-formed payload it never does, so the ordinary run
still spends the two processes this change removed and no more.

From the hook, above the payload `jq` call, on the jq probe:

THE PROBE RUNS ONLY AFTER THIS CALL FAILS. It used to run first, on every tool
call, to protect a path taken once per machine: one process, measured
2026-10-10 at about 90 ms of the hook's ~750 ms floor on Windows (alternating
runs, the fastest of thirty each). A jq that cannot run fails this call too,
so asking `jq --version` only then reaches every jq the old probe reported,
and a malformed payload pays one extra process where the ordinary run pays
none. The test is the old one — `jq --version` failing — and NOT a table of
exit codes: 127 and 126 are the obvious ones, but a jq that dies on a missing
library, or a shim that exits 1, is just as unable to run, and an exit-code
rule that missed one would leave the guard silent with no hint, which is the
failure this branch exists to name.

ONE CASE ANSWERS DIFFERENTLY, and it fails safe. A jq that parses the payload
but fails `--version` was reported as missing, and the guard stayed off; now
the payload call succeeds, the probe never runs, and the guard works. Found
by review with a shim that fails only `--version`; the differential cannot
see it, because it varies the hook and never jq.

From the hook, above the payload `jq` call, on consuming stdin:

CONSUME STDIN BEFORE LEAVING, AND THAT IS LOAD BEARING. A reader that exits
without reading leaves the caller writing into a closed pipe. Measured
2026-09-02, a ~200KB payload: a reader that never reads leaves the writer at
exit 141 — killed by the broken pipe — while a reader that consumes it leaves
the writer at 0. A jq that cannot start reads nothing, so the `cat` below
drains the payload BEFORE the hint and its `exit 0`, on the same branch that
drains it for a payload jq could not parse. Do not move the hint above it
because the guard is exiting anyway: what it protects is the caller, not
this hook.

### Subagent payloads, measured

From the hook, above the `agent_id` exit:

Inside a subagent this hook is handed the PARENT's transcript_path and the
PARENT's session_id — measured on 2026-08-18 by logging the hook's stdin and
driving one throwaway subagent; both of its tool calls arrived carrying the
parent session's transcript, indistinguishable from the main-chain calls
around them except for the two fields read here.

### Configuration reader, measured

From the hook, inside `read_config`, on the separator trap:

The trap is QUIETER here than it is up there, which makes it worse. Every
value below is a positive integer, so a value that lands in the wrong slot
PASSES validation and is installed. Measured with thresholdPct absent — an
ordinary shape, since every key is optional — a tab-split installs maxBytes
as thresholdTokens: the guard would fire at ten thousand tokens instead of
six hundred and fifty thousand, with no error and no failing test.

From the hook, inside `read_config`, on the split:

Split with parameter expansion for the reason the payload block gives at
length: `read` stops at the first newline, and a JSON string value may
contain one. Measured here, this was not theoretical — a windowTokens of
"5\n999999" truncated to "5" and took thresholdPct, thresholdTokens and
maxBytes with it, all three silently reverting to their defaults.

Added 2026-10-13, not moved: the user-level file rides the payload call.

Until then every configuration file that existed cost a jq of its own: 2, 3
or 4 jq processes on the ordinary call for no file, the user file only, or
both. The user file's path needs only HOME, so the payload call now reads it
with `--rawfile` and the hook spends 2, 2 or 3. The repository file keeps its
own read, because its path needs the payload's cwd. Counted with a logging jq
first on PATH; a malformed user file still costs 3, as before, and a missing
or directory one 2. The hook still validates and applies each file's four
values in the shell, user then repository then environment, so an invalid
repository value still leaves a valid user value standing.

Timed on Windows under Git Bash, outside bats, the base hook and this one
alternating, HOME and TMPDIR isolated per side, a 1.5MB transcript on the
silent path. A bare `jq -n 1` started in a median 78 and 80 ms over two runs.
Medians over 31 calls each, in the same two runs: no file 642 against 627
and 656 against 648 ms, no saving beyond noise; the user file only 771
against 674 and 820 against 684 ms; both files 911 against 801 and 865
against 800 ms. So one jq start, about 65 to 135 ms, whenever a user file
exists, and nothing without one.

`--rawfile` is in every jq the repository supports: measured on jq 1.6 (the
Windows release build, and apt's on Ubuntu 22.04), 1.7.1 and 1.8.2. On all
three a `--rawfile` that cannot be opened exits 2 BEFORE jq reads stdin, so
the hook can make the payload call again without it. A malformed payload
exits 4 on 1.6 and 5 on 1.7.1 and 1.8.2, never 2. The whole hook, run on
each of the four builds with no file, a user file, a `{not json` user file
and both files, spoke the same bytes as the base hook on every one; on
Ubuntu, a user file made unreadable with `chmod 000` did too.

`fromjson` is not jq's file parser, and three differences were measured. The
file parser keeps every document before an error, so `{...} garbage`, two
documents, and on jq 1.6 a NUL after the document, all applied the first
document's values; `fromjson` rejects the whole text. On the jq 1.6 Windows
build `fromjson` accepted `{"contextGuard":{"windowTokens":"5<NUL>"}}` and
returned a window of 5, where the file parser refused the file. And a
non-object `contextGuard` is a runtime error inside the program, not a parse
error. So the payload call parses with `fromjson?`, catches the program's
errors as four empty values (what the old reader's empty output gave), and
sends any text that is not one JSON document, or that holds a NUL byte, back
to the old reader. A 34-shape probe over the three jq versions found the
values the shell applies identical to the old reader's on every shape. Without
the NUL test, the jq 1.6 Windows build installed that window of 5, and the jq
1.7.1 Windows build installed a window of 3 from a user file holding
`"windowTokens":3<NUL>00000`, where the base hook kept 200000. jq 1.8.2, the
one CI pins, and the Linux builds of all three diverged on no shape, so no
bats test can pin the NUL test on CI; the NUL test in context-guard.bats pins
only that a NUL-bearing user file leaves the guard running.

The fold could not simply append the user's values after the payload's. The
payload's last field, cwd, may hold the separator, and $( ) stripped its
trailing newlines only while it was last. So the user half goes last, in five
fields that cannot hold the separator, taken off the end; the payload half is
the old string, byte for byte, with its trailing newlines stripped in jq.
A cwd ending in newlines, a cwd holding the separator, and a separator inside
a user value each compare equal with the old hook.

### The median window, measured

From the hook, above `READINGS_JQ`, on the median of fifteen:

Current context = input + cache_read + cache_creation per main-chain
assistant message (the same arithmetic status-line tools use). MEDIAN of
the last 15 entries, not the last one: a request that re-sends the full raw
history (a review or advisory tool that forwards the transcript) inflates
entries far above the live context, and a last-entry read fires the guard
early — seen 2026-08-07, the hook reported 45% while the session was
genuinely at 24%.

15 and not 5, because such a tool does not inflate ONE entry. The assistant
messages that follow it read the same oversized cache, so the inflation
persists for four to six CONSECUTIVE entries. Measured against the advisor
tool on 2026-08-15: 122774 -> 252163, 160982 -> 328729, 183166 -> 371027 —
each about 2x, each lasting four to six readings. A 5-wide window is FILLED
by that run, so the median is not merely dragged toward the spike, it IS the
spike: the hook reported 37% where Claude Code's own status line read 19%.
Reading high is the fail-loud direction, so the cost was half a wasted
session rather than a session lost — but a guard that is wrong by 2x teaches
the user to ignore it, which ends in the same place. 15 outvotes a run of 7.

From the hook, above `READINGS_JQ`, on the line budget and the byte cap:

The tail is a budget in LINES while the median needs fifteen READINGS, and the
two diverge badly. Tool results, user turns and sidechain lines all consume
the budget without yielding a reading, and in a session that dispatches
subagents the sidechain lines dominate. At 300 the boundary was reachable:
with ~295 intervening lines the window clipped every honest reading, the
median degenerated to whichever single entry survived, and an inflated one
reported 450% where the session was at 24% — reintroducing the 2026-08-07
incident this arithmetic exists to prevent, and then telling the user to
raise windowTokens, which converts a loud failure into a silent one. 5000
leaves room for several subagent fan-outs between readings, and `.[-15:]`
below already takes the last fifteen MATCHING entries, so nothing downstream
has to change.

But a budget in lines does not bound WORK. 5000 lines of tool results
measured 48MB, and reading it cost 7.2s against a hook that runs on every
tool call — 1.4x under the old 10s timeout, and a hook killed by its timeout
emits nothing, which is a guard that is silently off. Hence the byte cap
below: 8MB brought the common path to 2.0s, until 2026-10-10, when the first
read became 1MB (the ladder below).

### Divergences in the per-line rule

From the hook, above `READINGS_JQ`, on its final `select`:

THE FINAL `select` IS NOT COSMETIC. jq's `+` concatenates STRINGS, so a
usage record whose three token fields are ALL strings does not error — it
yields a string, and jq sorts every string AFTER every number. Without this
line that junk lands inside the fifteen-wide window and pushes the middle
index onto a LARGER reading: measured, readings 100, 200, 300 plus two such
entries report a median of 300 where the true one is 200. An inflated median
is the 2026-08-07 failure exactly, arrived at from a new direction.

It also records divergences from the pre-refactor hook. The count went one,
then two, then three as successive rounds of review measured further; all are
kept, and the differential asserts each rather than hiding it. TAKE THE NUMBER
FROM THE HARNESS, NOT FROM THIS SENTENCE — it has been wrong three times:
`grep -cE '^run_shape .* diff@f495823$' scripts/context-guard/differential.sh`
counts the entries listed below, and a test holds it to that list. It is
scoped to f495823, the commit that brought these divergences in, on purpose:
a later fix (5ff33c6, a threshold of exactly 100) added a divergence asserted
the same way that belongs to a different rule, and the wider
`diff@[0-9a-f]+$` counts that one as well. Until 2026-10-11 this sentence
gave the wider grep. The anchor is not decoration either: a bare ` diff$`
also matches a comment about the diff command and answered four where the
truth was three, in the same breath as telling the reader to count rather
than trust prose.

  1. The concatenation is NOT parseable as a number — "abc". The old code
     emitted it as a line, the separate median call then failed to parse the
     whole stream, and THE GUARD SAID NOTHING. The new code drops it and
     answers from the readings around it. Measured: 0 bytes against 556.

  2. The concatenation IS parseable as a number — "180000" from three string
     fields. The old code's raw output was re-parsed into a genuine reading
     of 180000 and inflated the median; the new code drops it. Measured, on
     two readings of 80000 and three such records: old median 180000 and the
     guard fires at 90%, new median 80000 and it stays silent at 40%.

  3. The junk is STARVED DOWN TO by the byte cap. It no longer counts toward
     the floor of fifteen, so where the old code cleared the floor on fifteen
     string readings and skipped the re-read, this one falls back and answers
     from the real readings. Old fires at 90% on 180000, new is silent at the
     true 15%. This one moves the FALLBACK DECISION, not just the median.

They point in OPPOSITE directions — the first turns silence into speech, the
other two turn speech into silence — and all three are corrections. In the
last two the old guard was speaking because junk had inflated its median or
padded its count, which is the 2026-08-07 fault itself. Restoring any of them
byte-for-byte means restoring a defect.

### The count rule, measured

From the hook, above `SUMMARY_JQ`, on the single pass and its `?`:

The count and the median come from ONE pass over the same list, composed here
ONCE and spent at both call sites below. It used to be three: this program's
ancestor emitted one number per line, a `grep -c` counted those lines, and a
third jq took the median. Measured 2026-09-02 on the NON-FIRING path, which
follows almost every tool call: 4/5/6 jq processes to 3/4/5 on an ordinary
transcript and 5/6/7 to 4/5/6 on the starved one, for zero, one and two
configuration files, and the grep gone.

THE `?` AFTER THE PER-LINE PIPELINE IS LOAD BEARING. Streaming jq treats a
runtime error as an error on THAT INPUT: it reports it and carries on with
the next line. Collect the same pipeline into an array and the error escapes
the array construction and kills the whole program, so jq emits NOTHING —
every reading lost, ctx empty, and the guard silent, which is the one
direction this hook must never fail in. Measured on a transcript whose middle
line carries a string where a token count belongs: without the `?`, no output
and exit 5; with it, the same two numbers streaming gives.

From the hook, above `SUMMARY_JQ`, on what the count counts:

FINITE is the honest word, and this said "every number" until it was measured.
jq calls a NaN a number and renders it "null", which begins with neither — so
`startswith` counts it where the regex and the original grep did not. Measured
on 0, -0.0, -0, 1e30, 1e-7, 0.1+0.2, 2^53+1, a thirty-digit literal, 1e400,
-1e400, 100, -5, -0.5 and 123.4: identical on every one. NaN is the sole
disagreement.

It is left standing rather than closed, and the direction is why. A NaN can
only make the count LARGER, and a larger count can only skip the uncapped
re-read — which returns the same last fifteen readings whenever the capped
read holds fifteen at all, because the capped read is a byte suffix of the
same file. To reach the answer a transcript would need a NaN AND a starved
cap; a token count is a sum of integers and has no route to one. Named here
so the next reader inherits the exception rather than the belief.

`select(. >= 0)` was proposed and is NOT equivalent: -0.0 is >= 0 but its text
form is "-0", which the old `grep -c '^[0-9]'` did not count. Measured, on
100, 0, -5, -0.5, 1e30, 123.4, 1e-7 and -0.0: the regex and `startswith` agree
on all eight, `. >= 0` disagrees on the last.

THE COUNT IS NOT `length`, AND THAT IS LOAD BEARING TOO. The `grep -c` it
replaces counted lines BEGINNING WITH A DIGIT, so a negative reading was
excluded from the count and included in the median — the two look at
different sets, and always have. `length` counts it, moving the fallback
decision by one on such a transcript. Measured on readings 100, -5, 300: the
old count says 2, `length` says 3, and the median is 100 either way. The cap
may never change the answer, so this reproduces the rule rather than
improving it.

ONE PLACE WHERE THAT IS NOT QUITE TRUE, named rather than glossed. The
`select(type == "number")` in the per-line rule removes junk from the array,
and the count is taken over that array — so junk no longer counts toward the
floor of fifteen either. Under a byte cap that starves the read to junk
alone, the old code counted fifteen string readings, cleared the floor,
skipped the fallback and answered from them; this counts none, falls back,
and answers from the real readings. Measured: twenty readings of 30000 then
fifteen junk records, cap set to the junk's byte length — old fires at 90%
on a median of 180000, new is silent at 15% on the true 30000. Fail-safe, and
the differential carries it as a third asserted difference.

### The read ladder, measured

From the hook, above `FIRST_BYTES`:

That fallback read the file twice (until 2026-10-10; the ladder below reads
it up to three times), so it is NOT free and this comment will not pretend
otherwise: measured 8.2s where the uncapped code was 7.2s, on a 48MB
transcript whose readings sit inside the line window but outside the byte
cap. The timeout in hooks.json is 30 because of this path, not because of the
2.0s common one of that time. Trading ~1s in a case that needs megabytes between
readings for 3.6x in every ordinary session is the right trade; a cap that
also bounded the fallback would be faster and occasionally wrong.

Raising the floor from three to fifteen widened the door to that path, and
the honest way to state it is as a rate: the read of the whole file runs
whenever the capped 8MB holds fewer than fifteen readings, which needs upwards
of half a megabyte between consecutive readings. An ordinary session is
nowhere near that; a session whose tool results are that large pays ~1s and
gets the right answer, which is the trade already made above rather than a
new one. (The 1MB first read below climbs far more often — whenever readings
sit more than about 67KB apart — which is what it costs to make the common
read small.)

THE READ NOW CLIMBS: 1MB FIRST, THEN maxBytes, THEN UNCAPPED, and it stops at
the first rung holding fifteen readings. Added 2026-10-10 (audit item 12).
The floor argument above is what makes this free: every rung is a byte suffix
of the same file, so a rung holding fifteen readings has the same last
fifteen as the uncapped read, and the answer cannot depend on which rung gave
it. (Claude Code appends while the hook runs, so a later rung can see lines an
earlier one did not; that is the timing every read here has always had, and
the size check below is written for it.) What changes is the WORK. At the 8MB cap alone a 6.7MB transcript cost
1.6-2.5s per tool call, while the last fifteen readings needed far less:
measured over 35,053 points in 312 real transcripts, half needed 114KB or
less, and 1MB held fifteen readings at 92.5% of them (2MB at 97.3%, 8MB at
every one; the largest needed 5.3MB). So 1MB answers almost every call, and
the 7.5% it starves pay one more read, of maxBytes — the trade the floor
already made one rung up.

The worst path now reads three times where it read twice: 1MB, then maxBytes,
then uncapped. Measured 2026-10-10 on the 48MB transcript described above,
readings inside the line window and outside the byte cap: 9.4s against 8.4s
before (medians of six alternating runs on a loaded machine), still more
than three times under the 30-second timeout in hooks.json.

From the hook, above `measure_size`:

A RUNG THAT HELD THE WHOLE FILE IS NOT READ AGAIN (audit H7). A session holds
fewer than fifteen readings until its fifteenth assistant message, so until
2026-10-10 every call before that read the file twice — the capped read, then
the uncapped one — when the capped read had already taken all of it and the
second returned the same bytes. One `wc -c` decides it, and it runs only
after a rung has starved, so the ordinary call never pays for it.

THE SIZE IS MEASURED AFTER THE READ IT VOUCHES FOR, and again after the next
one. Claude Code appends while the hook runs, and the file only grows: a size
taken AFTER a read is at least what that read saw, so "size <= cap" proves the
read held the whole file. A size taken BEFORE a read proves nothing about it.
Found by review on 2026-10-10: one size taken after the 1MB read and reused
for the maxBytes read let a transcript that grew past maxBytes in between skip
the whole-file read; the readings at its start were cut, and the guard stayed
silent where the old hook fired at 95%. A second `wc`, only when the maxBytes
read also starves, closes it. A transcript truncated in place would defeat
this; Claude Code has never been seen to do that.

### systemMessage, measured

From the hook, inside the once-per-session window note:

NO LONGER A HEDGE — it was measured. On 2026-08-18 a firing carrying both
fields was watched from the user's own terminal: the reason arrived as
`PostToolUse:Bash hook returned blocking error ...` and this string
arrived as a separate `PostToolUse:Bash says: handoff: ...` line.
systemMessage IS honoured alongside a decision on PostToolUse. Earlier
comments here called that unresolvable from inside a session, and they
were right — it took a human watching the screen.

From the hook, above the `systemMessage` text:

`systemMessage` IS documented — "Warning message shown to the user" — and was
measured arriving on 2026-08-18 as its own `PostToolUse:Bash says:` line while
a decision was present in the same emission. So the warning now travels both:
the path that is observed to reach Claude, and the path that is documented to
reach the user. One being withdrawn no longer produces silence.

## Related records

- `specs/014-guard-jq-spawn-count/` — the phase these came from, including the
  falsification write-up in `tasks.md` Phase 9.
- `specs/014-guard-jq-spawn-count/quickstart.md` — the jq spawn counting rig.
  Its shim directory must have **no drive letter**: a `C:/...` entry in `PATH`
  splits on its own colon under Git Bash, the shim is never found, and the
  count prints `0`, indistinguishable from a real zero.
