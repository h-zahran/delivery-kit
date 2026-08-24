# Feature Specification: a cap for the J loop

**Feature Branch**: `005-verify-iters-cap`
**Created**: 2026-08-24
**Status**: Draft
**Input**: User description: "Phase 5 of the dogfood plan — a cap for the J loop. J ("analyzer and full suite") loops until clean with no numeric cap — the only unbounded loop in the product. Give it the same shape as F and M."

## Clarifications

### Session 2026-08-24

- Q: At a J cap breach, when the owner says "proceed anyway", what happens to
  the still-failing tests? → A: Proceed, but RECORD the red — the surviving
  failures are written into the run record and carried into the commit message
  and the pull-request body. The owner may wave a breach through; red never
  ships silently.

## User Scenarios & Testing *(mandatory)*

The orchestrator document is the product. Its readers are an operator deciding
whether a run is safe to leave alone, and a model executing the document
literally. A scenario passes when both read the same thing.

### User Story 1 - The verification loop stops counting (Priority: P1)

An operator starts a run whose new failures cannot be fixed — a flaky
dependency, a genuinely broken change, a fix that reintroduces the failure it
removed. Today the verification phase loops on those failures with no numeric
bound: it is the only loop in the product that can spin without ever reaching a
stop the operator can answer. With `maxVerifyIters` set (default 5), the loop
runs at most that many iterations and then stops and asks, showing what is
still failing.

**Why this priority**: This is the whole feature. Every other loop in the
product — clarification, analysis, pull-request review — already has a cap and
a conditional stop. The verification loop is the exception, and an unbounded
loop inside a phase that runs unattended under `--auto` is the one place a run
can consume time and money with nobody deciding it should.

**Independent Test**: Read the J paragraph. It names a cap, names its default,
and says a breach is a conditional stop rather than a silent continue or a
silent abandonment. Read the F and M paragraphs: the three now describe the
same shape in the same words.

**Acceptance Scenarios**:

1. **Given** the orchestrator's J paragraph, **When** a reader looks for the
   loop's bound, **Then** it names `maxVerifyIters`, states the loop runs at
   most that many iterations, and states that a breach is a conditional stop.
2. **Given** a cap breach, **When** the run reaches it, **Then** the remaining
   failures are shown and the operator is asked whether to continue — the run
   neither continues silently nor marks unresolved failures resolved.
3. **Given** a HARD failure rather than a cap breach, **When** it occurs,
   **Then** the run still stops outright: the cap bounds the fix loop, it does
   not soften what a hard failure means.

### User Story 2 - The key reads identically everywhere it is documented (Priority: P2)

A reader looks up `maxVerifyIters` and finds it in the orchestrator's
Configuration table and in the configuration page's JSON block and key table,
with the name and default character-identical across the two files, described
in the same voice as the caps beside it.

**Why this priority**: The two files have drifted before, and this run's
predecessors made character-identity an acceptance criterion rather than a
hope. A cap whose default differs between two documents is worse than no cap.

**Independent Test**: Extract the key's name and default from each site and
compare character by character.

**Acceptance Scenarios**:

1. **Given** the four documentation sites, **When** the key's name and default
   are extracted from each, **Then** they are character-identical across
   `pipeline/skills/pipeline/SKILL.md` and `pipeline/docs/configuration.md`.
2. **Given** the configuration page's JSON block, **When** it is parsed,
   **Then** it is valid JSON and `maxVerifyIters` is present with the value 5.

### User Story 3 - The change is announced (Priority: P3)

The changelog gains one Added entry under the existing `## [Unreleased]`
heading, naming the key, its default, and what a breach does.

**Why this priority**: The release run stamps a version from what
`[Unreleased]` accumulated. An unannounced key ships silently.

**Independent Test**: The entry exists under `## [Unreleased]`, no version
heading was added, and the heading order is unchanged.

### Edge Cases

- "Proceed anyway" at a J breach never means "forget it happened". The
  failures travel with the work into the commit and the pull request, so a
  reviewer meets them without having to reconstruct the run.
- A cap breach is a CONDITIONAL STOP, not a failure and not a silent pass. The
  remaining failures are shown by name; marking them resolved is fabrication,
  and continuing without asking removes a decision that is the operator's.
- A cap breach and a hard failure are different things and must not be
  conflated. The cap bounds how many times the fix loop may try; a hard failure
  stops the run outright whether or not the cap has been reached.
- The cap counts FIX ITERATIONS, not test failures and not individual fixes: a
  single iteration may fan several independent fixes out across agents.
- `maxVerifyIters` is a nullable-by-convention numeric key like its siblings.
  It has no equivalent of the implementer key's `ask`, so a value an earlier
  configuration layer sets can be replaced by a later layer but never returned
  to unset — the merge rule the previous phase recorded applies here unchanged,
  and this feature does not invent an exception to it.
- NO suite growth this phase: the full house suite stays `1..121` and the prose
  suite stays `1..11`. Any movement is a finding. The previous phase paid the
  prose-pin test debt in full, so nothing here is owed and nothing is queued.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The configuration key `maxVerifyIters` MUST exist with default 5,
  documented in the orchestrator's Configuration table and in
  `pipeline/docs/configuration.md`'s JSON block and key table — name and
  default character-identical across the two files.
- **FR-002**: The orchestrator's **J** paragraph MUST state the cap in the
  seed's own terms: the loop runs until clean against baseline, at most
  `maxVerifyIters` iterations; a cap breach is a conditional stop; a hard
  failure still stops the run outright.
- **FR-003**: A cap breach MUST show the remaining failures and ask whether to
  continue. It MUST NOT mark unresolved failures resolved, and MUST NOT
  continue without an answer.
- **FR-003a**: Where the owner answers "proceed anyway", the surviving
  failures MUST be recorded in the run's state file AND carried into the
  commit message and the pull-request body. J is the last full-suite check
  before code leaves the machine; a waved-through red is a decision the
  owner is entitled to make and the record is entitled to keep. This is the
  one way J's cap differs from the clarification, analysis and review caps,
  and the difference is deliberate.
- **FR-004**: `pipeline/CHANGELOG.md` MUST gain an Added entry under the
  existing `## [Unreleased]` heading naming the key, its default, and the
  breach behaviour. No version stamp. STRICT vocabulary surface.
- **FR-005**: No existing sentence is reworded to accommodate this change
  unless this change makes that sentence FALSE, in which case it is fixed and
  the override is recorded — the standard this project settled on in the
  previous phase, after a deferral was withdrawn for resting on a pin that did
  not exist.

### Key Entities

- **`maxVerifyIters`** — a positive integer, default 5, bounding the number of
  fix iterations the verification phase may run before it stops and asks.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The key's name and default are character-identical across the
  orchestrator and the configuration page; all four site strings appear exactly
  once each.
- **SC-002**: All previously pinned strings survive: `pipeline/tests/prose.bats`
  reports `1..11`, 11 ok, and the Gates table's rows are byte-identical.
- **SC-003**: The full house suite reports `1..121`, 121 ok, 0 non-TAP — growth
  exactly zero.
- **SC-005**: A waved-through J cap breach is discoverable from the commit
  message and the pull-request body alone, without reading the state file.
- **SC-004**: The four capped loops — clarification, analysis, verification and
  pull-request review — describe their caps in the same shape, so a reader who
  understands one understands all four. Verification carries exactly ONE
  documented addition the others do not: a breach waved through is recorded
  into the commit message and the pull request (FR-003a). That addition is
  stated in the verification paragraph itself, so the difference is
  discoverable where it applies rather than being a trap.

## Assumptions

- **Placement is append, never insert.** The key lands at the END of the
  orchestrator's Configuration table and at the END of the configuration page's
  JSON block and key table, after `implementer`. This follows the precedent set
  two phases ago; grouping it beside the other caps would read better but would
  be an insertion, and insertions are how this project has broken pinned
  strings before. The planning phase may overturn this with a recorded reason.
- **The default is 5**, matching the analysis loop rather than the review loop's
  3. The seed states it; no judgement was exercised.
- **The cap is model-instruction only.** No script validates it, exactly as no
  script validates the other caps. This is consistent with the orchestrator
  being a document a model executes, and it is stated here so the absence is
  recorded rather than discovered.
- **`handoff/**` is untouched**, and this change is prose only: no script
  changes, no test changes.
