# Implementation Plan: progress.sh coverage and a timeout for every suite

**Branch**: `008-progress-coverage-timeout` | **Date**: 2026-08-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/008-progress-coverage-timeout/spec.md`

## Summary

Four independent pieces of work, all confined to the repository's test trees.
One per-test time limit moves into the file all six suites already load, and the
single existing per-suite assignment is removed because it is measurably
overridden. Eleven tests are appended to the state script's suite: two for its
read path, nine for refusal paths that carry a named message today and are
proven by nothing. One existing test, which claims to cover a folding step and
in fact rebuilds it, is reworked to drive the real code.

No shipped script changes. No changelog entry. The starting suite is `1..123`;
the finishing suite is `1..134`, and every one of the eleven is watched failing
before it is trusted.

## Technical Context

**Language/Version**: POSIX shell, run under Bash. Test suites in bats 1.11.0.
Four of the six suites declare `bats_require_minimum_version 1.5.0`; the root
portability suite and the handoff guard suite do not. Measured, and a non-issue
for this feature: a throwaway suite carrying no such declaration still honoured
the per-test limit. The gap is pre-existing and out of scope here.

**Primary Dependencies**: bats; `jq` (required by the state script and asserted
at its top); an external `timeout` program, which the per-test limit needs and
which is present at `/usr/bin/timeout` here. No dependency is added by this
feature.

**Storage**: none. The state script writes JSON files under a git-ignored
directory; the tests drive it inside per-test scratch directories.

**Testing**: the house suite, run from the repository root:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`

**Target Platform**: Linux, macOS and Windows, the three the build already
covers. The macOS runner ships the BSD flavour of the text tools, which is the
real portability check for anything new written here.

**Project Type**: repository tooling. There is no application; the product is a
pair of plugins and the suites that keep them honest.

**Performance Goals**: none, beyond not making the suite slower. The eleven new
tests drive a small shell script inside a scratch directory; none of them sleeps
and none of them races.

**Constraints**: append to existing suites, never restructure them — with the
one named exception the seed itself requires (FR-024). No shipped script is
touched. No changelog entry. No machine-specific absolute path may appear in any
file this feature writes, because the previous phase's tracked-tree scan covers
this feature's own documents.

**Scale/Scope**: four files touched, all under a test tree. Eleven tests added,
one reworked, one assignment moved and one removed.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Not applicable — no constitution is set.** The offer to write one was made at
pre-flight and declined by the owner, as a standing answer for this whole
campaign; that answer is recorded in the run's state file. The planning gates
therefore have an empty document to check against.

In its place, the repository's own invariants were used. They are not
aspirational; each is enforced by a test that is green today, and this plan is
checked against each:

| Invariant | Enforced by | This feature |
|---|---|---|
| No machine-specific absolute path anywhere in the tracked tree | the tracked-tree scan added by the previous phase | passes — every path written here is relative or uses the portable home reference |
| Shipped surfaces carry no banned vocabulary | the surface-scoped vocabulary scans | not engaged — both test trees are relaxed surfaces |
| Every plugin's manifest, marketplace entry and changelog agree | the version gate | not engaged — no version moves, no changelog entry |
| Shipped prose states no count that the next change falsifies | review practice, carried from the previous campaign | passes — the counts in this feature live in the spec and this plan, neither of which ships |
| A check must be able to go red | the previous phase's whole subject | **this feature is an application of it** — three of its four parts exist because a check cannot currently go red |

**Post-design re-check**: passed. The Phase 1 design adds no file outside the
test trees, moves no version, and writes no count into a shipped file. The one
structural change — turning inline folding into a named function — stays inside
the suite file that already owns it, which is what the owner chose at clarify
and what FR-019 now forbids relaxing.

## Project Structure

### Documentation (this feature)

```text
specs/008-progress-coverage-timeout/
├── plan.md              # This file
├── research.md          # Phase 0 output — the measurements every decision rests on
├── data-model.md        # Phase 1 output — the entities and their rules
├── quickstart.md        # Phase 1 output — the runnable validation guide
├── contracts/
│   └── refusal-contract.md   # Phase 1 output — what each refusal must name
├── checklists/
│   └── requirements.md  # Written at specify, updated at clarify
└── tasks.md             # Phase 2 output — NOT created by the plan command
```

### Source Code (repository root)

```text
tests/
├── helper.bash          # CHANGED — gains the per-test limit, and the reason for it
├── layout.bats          # CHANGED — loses its own assignment (measurably overridden)
└── portability.bats     # CHANGED — folding becomes a named function; its test drives it

handoff/tests/
└── context-guard.bats   # unchanged — inherits the limit through the file it loads

pipeline/tests/
├── preflight.bats       # unchanged — inherits the limit
├── progress.bats        # CHANGED — eleven tests appended
└── prose.bats           # unchanged — inherits the limit

pipeline/scripts/
└── progress.sh          # UNCHANGED — the subject of the new tests, not their target
```

**Structure Decision**: four files change, all under a test tree. Three of the
six suites are untouched and still receive the limit, because they load the
changed fixture file — that inheritance is the point of the first requirement,
and it is what the quickstart proves rather than assumes.

## Implementation approach

### Part 1 — the per-test limit

1. Add the limit to the shared fixture file, at the top, with the reason
   carried over from the assignment being removed and the measurement that
   selected the value.
2. Remove the assignment from the root layout suite. It sits above that suite's
   `load` line and is therefore overridden — measured, see research D2.
3. Prove the reach: confirm all six suites load the fixture file, and watch one
   suite actually stop an over-long test and name it.

**Order matters.** Step 3's proof must be run with the limit deliberately
lowered, then restored — a proof run at 60 seconds would need a test that hangs
for a minute. The quickstart does this with an override rather than by editing
the file, so nothing has to be undone afterwards.

### Part 2 — the read path

Two tests appended to the state script's suite:

1. The data stream is accepted whole by a strict parser, and a broken state
   file leaves that stream empty while the fault goes to the diagnostic stream.
2. The line-ending contract: the test writes the two-character ending itself,
   then shows a strict parser still accepts the output, that capturing through
   command substitution is clean, and that the idiom the shipped document
   forbids does retain the stray character.

### Part 3 — the nine refusals

Nine tests appended to the same suite, one per path, each asserting the message
names the fault rather than only that the command failed. All nine triggers are
deterministic and none sleeps; research D4 records each trigger, including the
only one that needed thought — the creation race, entered by making the lock
path a directory so the guard above it passes and the protected write fails.

### Part 4 — the folding

1. Extract the inline folding into a named function in the same suite file,
   preserving today's behaviour exactly: when the private list contributes
   nothing, the shipped list comes back unchanged, with no trailing separator
   and no empty alternative.
2. Call it at load time with the repository's own path.
3. Rewrite the test's body to call the same function with a fixture path,
   keeping all three assertions it already makes and keeping the suite's test
   count unmoved.
4. Break the function and watch the test go red. Restore it and watch it pass.

### Verification discipline, binding on every part

- **Every one of the eleven new tests is watched failing before it is trusted**,
  by inverting its assertion or breaking the clause it rests on — never by
  deleting it. The altered line is echoed back before the red is believed,
  because a substitution that silently did nothing produces a false green.
- **Every ad-hoc search fires a control that must match** before any zero is
  believed. The campaign's global constraint records why: a pattern crossing an
  argument boundary once reported zero over a tree holding thirty-six.
- **The full suite runs from the repository root**, never from a subdirectory.

## Complexity Tracking

No constitution violations to justify — no constitution is set, and the
repository invariants used in its place are all satisfied.

One deviation from the seed's literal wording is recorded rather than hidden:

| Deviation | Why | Where it is recorded |
|---|---|---|
| The seed says "append, do not restructure", and this feature reworks one existing test | The same seed separately and explicitly requires that test to be fixed. The two instructions collide only until the exception is named. | FR-024, and the C.5 audit in the run's state file |
| The seed cites line numbers that no longer point at what they name | The previous phase added 266 lines to one of the two files cited | FR-022; everything is located by content instead |
