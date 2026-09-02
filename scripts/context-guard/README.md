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
strings, another whose three strings concatenate into NUMERIC text, sidechain
entries, a negative reading, a median-window shape, and two byte-cap shapes that
force the uncapped re-read.

**This paragraph carries no total, on purpose.** Count it:
`grep -c '^run_shape "transcript:' scripts/context-guard/differential.sh`. It said
thirteen when there were fourteen, was corrected to fourteen, and was wrong again
within the hour when a fifteenth arrived — and the shape it omitted both times
was an asserted difference, which is the whole evidentiary basis for a divergence
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

Three shapes use it today, and the count is best taken from the file:
`grep -c '^run_shape .* diff$' scripts/context-guard/differential.sh`. This
paragraph said "one shape" while the table twelve lines above already said two.

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
