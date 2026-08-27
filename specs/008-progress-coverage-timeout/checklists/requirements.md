# Specification Quality Checklist: progress.sh coverage and a timeout for every suite

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-27
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

**No markers outstanding.** FR-017's question was asked at clarify on 2026-08-27 and answered: the folding becomes a named function inside the suite file that holds the vocabulary list. The answer, the two rejected alternatives and the reasons are recorded in the spec's Clarifications section. FR-018 and FR-019 were added to pin the behaviour the function must preserve and to forbid the rejected placement; FR-021 and SC-009 were tightened, because the answer means every file this feature edits is under a test tree and no shipped script needs an exception.

**Deliberate wording choices, so a later reader does not "fix" them:**

- The spec names no line numbers. The seed's own line references were measured
  stale before this document was written (FR-022), and repeating them here would
  reintroduce the fault. Everything is located by description.
- The spec names no concrete limit value. FR-002 requires it to be derived from a
  stated measurement; writing a number here would make the requirement circular.
  The measurements themselves are recorded under Assumptions as evidence, which is
  what they are.
- The spec avoids naming the setting, the two-character line ending, and the
  forbidden idiom literally. They are described instead. This keeps the document
  readable by a non-implementer and keeps it clear of the scan surfaces its own
  campaign polices.
- SC-001's counts are stated because the seed states them as acceptance. They are
  a target the run is measured against, not prose that can go stale unnoticed —
  a mismatch is a finding by definition.

**Marker resolved 2026-08-27.** FR-017 carries the chosen shape, the Question
section was replaced by a Clarifications section recording the answer and both
rejected alternatives with their reasons, and the first Requirement Completeness
item above is ticked.
