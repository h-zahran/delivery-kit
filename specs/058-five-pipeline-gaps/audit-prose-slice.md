# Audit: the callers of `prose_slice` (2026-11-04)

The list comes from the seed, and T017 measured it again: a switch of all 81 region calls (80 direct, and `pf_walk`) to the inside form turned exactly 13 tests red, the 14 named below less test 20, which is a fixture and calls the helper through `run`.

All other region calls stay on the inside form.

## The verdicts

The numbers are from `126f045`, where the list was measured.

| No. | Test | Verdict | Why |
|---|---|---|---|
| 20 | a declared inner line is admitted, and admits nothing else | Kept plain | The helper's own fixture. It records the default's behaviour. No caller needs the line because of it. |
| 39 | the seed-form rule never falls through to a verbatim description | Kept plain, with the reason above the call | `span_seed` |
| 40 | a failed phase rolls nothing back, keeps its place and drops the lock | Kept plain, with the reason | `span_fail` |
| 41 | phase J carries a waved-through red into everything that leaves the machine | Kept plain, with the reason | `span_j` |
| 42 | phase N is degraded but never skipped, and never re-owns an accepted red | Kept plain, with the reason | `span_n` |
| 43 | F.5, J and N reuse only a green suite result for identical files | Kept plain, with the reason | `span_f5` |
| 44 | every red-flag row is pinned, and every pinned row is still there | Kept plain, with the reason | `span_redflags` |
| 56 | late phases commit their own work, each under its kind | One call kept plain, one switched | `span_h5` kept. `span_i` compares by equality, so it switched, and its expected text now stops where phase I does. |
| 59 | K shows the commit list and stops for a path outside the feature | Kept plain, with the reason | `span_k` |
| 61 | the review guide is in the PR body and the DONE summary | Kept plain, with the reason | `span_l` |
| 69 | phase F ends after a round with no CRITICAL or HIGH finding, and narrows later rounds | Kept plain, with the reason | `span_f` |
| 98 | each rare path's old site still sends the run to its section | One call kept plain | Its pre-flight pin ends on `**Base branch:**`, the walk's closing line. |
| 100 | no AI attribution leaves the machine: the ground rule, and M, L, N and the commits obey it | Switched | `span_m` compares by equality, so its expected text now stops where phase M does. |
| 101 | the Resume section is exactly its text: nothing appended after the tracked-state pointer | Switched | `span_resume` compares by equality, so its expected text now stops where the section does. |

## Why a span test keeps the closing line

`assert_span` tests that its expected text is included in the slice. So a span that ends on the closing line is what catches a sentence added at the region's end. Trim that line, and an added sentence passes: the fix would open the mirror-image hole. These tests claim no absence, and their span pins every word in order, so the closing line cannot satisfy them by accident.

A span compared by equality does not need the line. Equality catches an added sentence by itself, so those switched.

## What was measured

Each fault ran through `.delivery-kit/runs/058-five-pipeline-gaps/fault-harness.sh` on a throwaway copy.

| Fault | Test that went red |
|---|---|
| B's `Record config` sentence removed from phase B | B records config before it starts the base suite run |
| A sentence added at phase J's end (plain span) | phase J carries a waved-through red |
| A sentence added at phase I's end (span by equality) | late phases commit their own work |
| A sentence added at the Resume section's end (span by equality) | the Resume section is exactly its text |
| The inside forms keep the closing line | prose_slice's inside forms drop the closing line |
| The plain forms lose the closing line | a declared inner line is admitted |
| A one-line region comes back empty | prose_slice's inside forms refuse a region that is one line |
| A plain caller with no reason on the line above | a region test on a plain form says why |
| A new plain call with a single-quoted name, and with a double-quoted name | a region test on a plain form says why |

The double-quoted plain call first stayed green. The walk read only single-quoted names, so it was widened, and the fault then went red.

## The 056 mutant in full

Both of B's instructions moved onto phase C's first line. `specs/058-five-pipeline-gaps/quickstart.md`, section 4, runs it. Measured 2026-11-04, on a throwaway copy, with the mutant confirmed by `git diff`:

| The test's slice | Result |
|---|---|
| Inside form (this feature) | Red, with the true reason: `phase B no longer runs the base suite start command` |
| Plain form | Its two presence checks passed on phase C's line. It went red only at a later guard, about the sentence's place. |

So the inside form closes the fault: a presence check can no longer be satisfied by the closing line.
