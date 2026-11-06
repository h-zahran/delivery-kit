# Feature Specification: A phase time is never negative

**Feature Branch**: `060-no-negative-phase-time`

**Created**: 2026-11-06

**Status**: Draft

**Input**: User description: "pipeline-run.json must never show a negative phase time. Run 059's file showed O=-5566 s: phase-start re-stamps a phase's start on a re-entry and keeps the old done, so metrics, run before the new phase-done, pairs the new start with the old end. A phase whose time cannot be read from its timestamps must read as missing (null), never as a false number." The seed is saved verbatim at `.delivery-kit/runs/060-no-negative-phase-time/seed.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A re-entered phase never shows a false time (Priority: P1)

The owner reads each phase's seconds in `pipeline-run.json` to choose the next speed work. Run 059's file showed phase O at -5566 seconds: the phase was started again, its old end was kept, and the metrics ran before its new end. A false number in this file can lead to a wrong choice.

**Why this priority**: These numbers are what the owner's speed work rests on.

**Independent Test**: Start a phase, end it, start it again, run metrics, and read the phase's seconds.

**Acceptance Scenarios**:

1. **Given** a phase started again after it ended, with no new end yet, **When** the metrics run, **Then** its seconds read null, never a negative number.
2. **Given** that phase then ends, **When** the metrics run, **Then** its seconds are the new end minus the new start.
3. **Given** a phase with a normal start and end, including a start and end in the same second, **When** the metrics run, **Then** its seconds are the end minus the start, and 0 stays 0.

### Edge Cases

- A timestamp that does not parse keeps its existing result: null.
- A phase with no end, or no start, keeps its existing result: no seconds key.
- The phase's own timestamps stay in the file, so the record of what happened is not lost.
- A phase started again in the same second as its old end reads 0 until its new end is stamped: one-second stamps cannot tell it from a real 0, and FR-003 holds. The plan's "Limit, stated" says more.
- A `seconds` value the state file holds on a phase with a stamp missing, or not a string, is not kept, so FR-001 holds for any phase.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `pipeline-run.json` MUST NOT hold a negative `seconds` for any phase.
- **FR-002**: A phase whose end is earlier than its start MUST read `seconds: null`.
- **FR-003**: A phase whose end is at or after its start MUST keep its seconds as today, including 0.
- **FR-004**: A test MUST go red on the old behaviour, and it MUST drive the real commands in the order that gave the fault.
- **FR-005**: The change MUST ship as a pipeline release: the manifests, the changelog and the version records agree.
- **FR-006**: No check MUST be dropped, capped or deferred to reach this.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a phase started again with its old end kept, the file holds null, against -5566 in run 059's shape.
- **SC-002**: At DONE, the report states whether F.5 cited the base suite, whether `phaseI` filled with no hand edit, each lens's seconds, and each phase's minutes against run 059.

## Assumptions

- This run executes from the 1.12.0 plugin cache, so it is the first real test of that release, and its own metrics still use the old rule.
- Seconds remain wall time.
