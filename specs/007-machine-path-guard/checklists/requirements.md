# Specification Quality Checklist: the machine path leaves the repository

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-26
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

Validation ran in one iteration; no rewrites were needed.

**On "no implementation details".** This feature's product IS a check in a
test suite, so the line between what and how sits unusually close to the
code. It was drawn like this: the specification says a check must scan a
named surface for four named shapes, must assert the "found nothing" status
specifically, must share one assembled expression with its control, and must
be portable across the three operating systems. It does not say which tool
runs the scan, how the expression is spelled, how the surface is enumerated,
or where in the file the checks sit. Every one of those constraints is a
property an auditor can verify from the outside by planting a path, renaming
an operand, or running on another platform — which is the test that matters,
not whether the sentence mentions a filename.

Two named files do appear — the test file that gains the checks and the plan
file that gains the amended ruling. Both are the subject of the change rather
than a chosen implementation site: the corrections in User Story 3 are
corrections *to those documents*, and naming them is what makes those
requirements testable at all.

**On the self-referential hazard.** The specification opens with a warning
that this document, and every document this feature produces, lands inside
the surface the feature scans. That warning is load-bearing rather than
decorative: the problem being fixed was created by exactly that mechanism —
a working note carried a path, the tooling copied the note into the tracked
tree, and the path multiplied across six directories. FR-021 makes the
constraint a requirement so the plan, the tasks file and the quickstart
inherit it.

Verified before this checklist was written: `spec.md` matches none of the
four banned shapes and does not contain the account name, each check fired
against a control that must match first.

**On the numbers.** SC-001, SC-002 and SC-005 carry measurements (35/1/0/1
prior hits; 37 lines across 17 files; 121 checks rising to 123) rather than
estimates. All were taken from the repository root on the commit this
feature branches from. They are stated so that any other movement is a
finding rather than a footnote.

**On what is deliberately absent.** No changelog entry (FR-020) and no
widening of the existing vocabulary lists (FR-016). Both are decisions, not
omissions, and both are recorded in the specification with their reasons.
