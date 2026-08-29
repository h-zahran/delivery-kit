# Implementation Plan: Pin the orchestrator's safety prose

**Branch**: `011-pin-safety-prose` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/011-pin-safety-prose/spec.md`

## Summary

Five passages of `pipeline/skills/pipeline/SKILL.md` carry safety rules and
none is guarded by a test. Append five `@test` blocks to
`pipeline/tests/prose.bats`, each slicing the section of the orchestrator that
governs its rule and matching the operative clauses inside it. The red-flag
table's seven unpinned rows are matched whole-line, with a second check in the
opposite direction so a new row cannot be added without being pinned.

The orchestrator is read, never written. Mutation verification requires
temporarily inverting it; a backup copy is the restore, because the
orchestrator's own never-bend table forbids `git checkout --`, `git reset
--hard`, `git clean` and `git stash`, and those rules bind this work.

## Technical Context

**Language/Version**: bash, run under bats-core (`bats_require_minimum_version 1.5.0`)

**Primary Dependencies**: bats at `$HOME/bats/bin/bats`; `awk`, `grep`, `tr`,
`cmp`, `sed` from the Git Bash environment; `python` 3.14 for two mutations
whose target text contains `|`, `"` and a backtick together

**Storage**: N/A — the tests read one file and assert

**Testing**: `pipeline/tests/prose.bats` for iteration; the full house
(`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
from the repository root) for verdicts

**Target Platform**: Windows 11 under Git Bash, and Ubuntu under GitHub
Actions. Both are exercised; the line-ending question this raises is settled
in research D3 by measurement.

**Project Type**: A Claude Code plugin marketplace. The artefact under test is
prose, not code.

**Performance Goals**: None. The five new tests are file reads; the suite's
per-test timeout is 60 s and the slowest existing test measures ~14.9 s.

**Constraints**: `SKILL.md` unedited at the end and proven so (FR-011).
`pipeline/tests/prose.bats` is the only shipped file changed (FR-012). No
changelog entry (FR-013). Existing pins untouched (FR-010).

**Scale/Scope**: One file changed. Five `@test` blocks and one helper
function, roughly 120 lines. Twenty-two mutation runs.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is the unfilled template — every principle
is still a `[PLACEHOLDER]`. The owner was offered `/speckit-constitution` at
pre-flight and declined for this phase; the decision is recorded in the run
state under `gates.constitution`.

**Consequence, stated rather than glossed.** This gate has nothing to check
against. It is not passed, it is vacuous, and saying "constitution check:
passed" would be a claim about a document with no content in it. No principle
was consulted because none exists. Nothing in this feature would obviously
conflict with a constitution a project like this one would write — it adds
tests, changes no shipped behaviour, and touches one file — but that is an
observation, not a gate result.

**Re-check after Phase 1 design**: unchanged, and vacuous for the same reason.

## Project Structure

### Documentation (this feature)

```text
specs/011-pin-safety-prose/
├── plan.md                      # This file
├── spec.md                      # What must be true
├── research.md                  # Six decisions, each measured
├── data-model.md                # The shape the five pins share
├── quickstart.md                # The runnable verification cycle
├── contracts/
│   └── pin-contract.md          # Eight obligations a pin must meet
├── checklists/
│   └── requirements.md          # Spec quality gate
└── tasks.md                     # Phase E output
```

### Source Code (repository root)

```text
pipeline/
├── skills/pipeline/SKILL.md     # READ ONLY — the document under protection
└── tests/prose.bats             # THE ONLY SHIPPED FILE THIS FEATURE CHANGES

tests/helper.bash                # loaded, not modified — supplies ROOT and the timeout
```

**Structure Decision**: No new files. Five `@test` blocks and one helper
function are appended to `pipeline/tests/prose.bats`, below the eleven tests
already there.

The helper stays in `prose.bats` rather than moving to `tests/helper.bash`.
That file is loaded by all six suites in the tree, and a function only one
suite calls does not belong in the file that reaches the other five. The
helper file's own comments make the same argument about what earns a place
there.

## Approach

### The shape every pin shares

1. Slice the orchestrator between two boundary lines.
2. Assert the slice opened where expected, closed where expected, and contains
   no unexpected heading. Contract C2.
3. For the four multi-line pins, collapse the slice to one line so a rewrap
   cannot move an anchor out from under a match.
4. Match each anchor and print, on failure, which passage broke. Contracts C3
   and C5.

The red-flag pin skips step 3 — a row is a line — and matches whole lines
instead. Contract C4.

### The five pins

| Pin | Region | Anchors | Requirement |
|---|---|---|---|
| Seed-form fall-through | `**Seed forms.**` → `## The twenty phases` | 2 | FR-001 |
| Roll nothing back | `## When a phase fails` → `## Resume` | 3 | FR-002 |
| J carry duty | `**J — analyzer and full suite.**` → `**K — commit.` | 5 | FR-003 |
| N degraded, never skipped | `**N — re-verify and update the PR.**` → `**N.5 — runtime check.**` | 3 | FR-004 |
| Red-flag rows | `## Red flags` → `## When a phase fails` | 7 rows + completeness | FR-005, FR-005a |

Every boundary string occurs exactly once in the document, and every one of
the thirteen clause anchors occurs exactly once. Both facts were measured
before this plan was written; research D1 and D2 record the commands.

### Verification

Twenty-two mutations, each an inversion rather than a deletion, each with the
changed line displayed before its red is believed:

- 13, one per clause anchor, the others left intact
- 7, one per red-flag row
- 1 appending mutant, which the seven rewrites cannot expose
- 1 unpinned-ninth-row mutant, for the reverse completeness check

An earlier draft of this plan counted twenty-one here and filed the ninth-row
mutant among the behavioural checks instead. It is a mutation: it edits the
document and requires a red. The count is corrected rather than the
classification, because three artefacts carried two different totals for the
same work, and this repository has already been bitten by a hand-written count
drifting in the flattering direction.

Plus six behavioural checks, which are not inversions: four rewraps that must
leave all five pins GREEN — the N block, the anchor-dense J block, and the two
LIST-shaped regions a paragraph rewrap would skip — then a relocated passage
that must go red, and a renamed boundary that must fail naming the BOUNDARY
rather than the prose. `quickstart.md` carries all of them as runnable blocks.

**Twenty-two plus six is the whole verification budget, and the two halves are
counted separately on purpose.** A mutation asks "does this pin go red when the
rule is broken". A behavioural check asks "does this pin stay quiet when
nothing is". Both are needed and neither substitutes: a pin that reddens on
everything passes every mutation.

Before any of it, one check in the opposite direction: the five pins must be
GREEN on the unmutated document. Every mutation below succeeds by observing a
red, and a pin that is red on a clean file is red under every mutation too —
so the whole verification pass can be completed and reported as proven while
measuring nothing but a broken test. A check that cannot pass proves as little
as one that cannot fail.

### Order of work

The pins are independent — different regions, different anchors, one shared
helper. The helper is written first because all five call it; after that the
five can be written and mutation-verified in parallel, subject to the run's
cap of three concurrent agents and the rule that two agents never edit one
file. That rule bites here: all five pins live in `prose.bats`. So the writing
is serialised into one file and the *verification* is what parallelises,
except that each mutation edits `SKILL.md`, which is also one file.

**Conclusion, drawn rather than assumed: this feature does not parallelise.**
Both the file being written and the file being mutated are single files, and
concurrent mutation of `SKILL.md` would have two agents inverting different
clauses at once, each seeing the other's red. Phase H runs this serially and
says so, rather than fanning out for the appearance of speed.

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified

No violations to justify — the constitution is empty, so there is nothing to
violate. Recorded as absent rather than as passed.

One design choice costs more than the obvious alternative and is worth naming
here rather than burying in research:

| Choice | Cheaper alternative | Why the cheaper one was rejected |
|---|---|---|
| Two-direction completeness on the red-flag rows | Forward check only — every listed row is present | Forward alone is a positive control: it proves the pin can go red, never that it goes red when it should. A hand-written list that has fallen behind the table passes it perfectly. This repository has already shipped one hand-written coverage list that went stale in the direction that hurts. |
| Twenty-two mutations | Five, one per `@test` | One inversion cannot distinguish a test that checks five clauses from one that checks one and silently skips four. The owner's clarify answer said exactly this about the seven rows; it is true of the J pin's five clauses for the same reason. |
| Whole-line row matching | Substring, matching the rest of the file's idiom | Measured: substring stays green when a mutant appends a cell after the row's final pipe, and that text is read inline by anything reading the document. |
