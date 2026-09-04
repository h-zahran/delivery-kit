# Verification rigs for the context guard

Two harnesses for `handoff/hooks/context-guard.sh`. Neither is a test and
neither runs in CI — they are tools you point at the hook when you are about to
believe something about it.

They live here rather than under `handoff/` on purpose: `handoff/` is copied
onto every user's machine at install, and these are maintainer tools. A clone
of this repository gets them; a plugin install does not.

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

Runs a baseline copy of the hook and the working copy over 30 payload and
configuration shapes, comparing stdout and exit code on each. Exit status is 0
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
  decides whether the uncapped re-read runs; it never decides the answer. The
  capped read is a byte suffix, so a suffix holding fifteen or more readings has
  the same last fifteen as the file, and one holding fewer falls back under
  either counting rule. Mutating the count rule to a plain `length` reports
  **every shape as expected**. On a straddle of fourteen positive readings and one
  negative — fifteen by `length`, fourteen by the digit rule — the shipped hook
  spends 5 jq processes, the mutant spends 4, and both emit an identical 556
  bytes. That rule is pinned by the spawn-counting rig in
  `specs/015-guard-jq-spawn-two/quickstart.md`, and nothing here can pin it.
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

Three anchored shapes use it today, and the count is best taken from the file:
`grep -cE '^run_shape .* diff@[0-9a-f]+$' scripts/context-guard/differential.sh` — scoped to ANCHORED assertions, because an unscoped count also picks up the threshold divergence, which belongs to a different rule. This
paragraph said "one shape" while the 2026-09-02 table already said two, and it
still said two after a third arrived. Name the table, never a line distance —
the distance changed the moment a second table was added above.

All three come from the same root: jq's `+` concatenates strings instead of
erroring, so a usage record whose three token fields are all strings yields a
string reading. `all three fields strings` covers the case where that string does
not parse as a number — the old hook's separate median call failed on the whole
stream and collapsed to silence, 0 bytes against 556. `strings that parse as a
number` covers the case where it does — the old hook re-parsed it into a genuine
reading and inflated the median, 556 against 0. `junk alone under the byte cap`
starves the capped read to that junk, so the old hook cleared the fifteen-reading
floor on it and skipped the re-read entirely, 556 against 0 — the only one of
the three that moves the FALLBACK DECISION rather than the median.

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
the capped read already holds the whole file, so the re-read returns the same
median and the floor never matters. The floor-to-zero control differs on the
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

## Related records

- `specs/014-guard-jq-spawn-count/` — the phase these came from, including the
  falsification write-up in `tasks.md` Phase 9.
- `specs/014-guard-jq-spawn-count/quickstart.md` — the jq spawn counting rig.
  Its shim directory must have **no drive letter**: a `C:/...` entry in `PATH`
  splits on its own colon under Git Bash, the shim is never found, and the
  count prints `0`, indistinguishable from a real zero.
