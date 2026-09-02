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
