# Specification Quality Checklist: preflight.sh coverage and a probe helper

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

**No clarification was needed, and that is unusual enough to state why.** The
seed names each behaviour to cover, names the one behaviour that must *not* be
covered, and states the target count. The three questions that would otherwise
have been asked are settled in the seed and recorded in the spec's Clarifications
section so a later reader does not reopen them.

**FR-016 was verified, not taken on trust.** The seed warns that a previous
review claimed the multi-line comment case was uncovered and was wrong. Rather
than believe either party, the case was measured before this document was
written: the multi-line stripping in the parser was deliberately broken, the
existing test went red, and the parser was restored with its hash re-checked.
The case **is** already pinned. A second test there would be duplication
presented as coverage, which is why the requirement is written as a prohibition.

**Deliberate wording choices, so a later reader does not "fix" them:**

- The spec names no line numbers. Two earlier phases in this campaign shipped
  seeds whose line references had already moved, and FR-024 makes re-deriving
  them from content a requirement rather than a habit.
- The spec describes the probe's streams rather than naming them. The property
  under test is that a warning reaches the diagnostic stream and never the data
  stream; naming the mechanism would not make that clearer to a non-implementer.
- SC-001 and SC-003 state counts because the seed states them as acceptance.
  They are targets the run is measured against, so a mismatch is a finding by
  definition rather than prose that can go stale unnoticed.
- Three behaviours are reachable only by making a program unfindable. The spec
  says so plainly in the Assumptions and carries the matching hazard in the Edge
  Cases — a blunt approach can make the probe fail for a *different* reason and
  pass the test for the wrong cause.
