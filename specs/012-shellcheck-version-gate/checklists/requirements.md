# Specification Quality Checklist: shellcheck, and one version gate instead of two

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-30
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

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`

### Validation record

Two items were failed on the first pass and fixed before this checklist
was marked complete.

1. **"No implementation details"** — the first draft named the analysis
   tool and the test runner by product name throughout, and named
   specific finding identifiers. Both were replaced with role
   descriptions ("static shell analysis", "third-party test runner",
   "finding identifier"). The seed's own tool names remain in the Input
   line and in Assumptions, where naming the measured environment is the
   point.

2. **"Scope is clearly bounded"** — the first draft left the fate of a
   newly added first-party shell file undefined. FR-022 was added, and a
   matching edge case, so a fifth first-party shell file cannot land
   outside the analysed set without the requirement noticing.

### Clarification session, 2026-08-30

Four questions asked, four answered by the owner, all four integrated.
No question was answered on the owner's behalf. Re-validated after
integration: 16/16 items still passing, no regressions.

### Spec quality gate (pipeline phase C.5)

Four checks were run over the spec by hand. Two omissions and one
contradiction were found and fixed:

1. **Omission** — the seed documents a fallback for the shared
   version-agreement implementation (delete the workflow copy, let the
   suite gate stand alone) and the first draft dropped it. Added as
   FR-014a, together with the guard that difficulty alone does not
   justify taking it.

2. **Omission** — the seed's constraint that the workflow file sits on
   the strict published-surface, and that any new tool name must be
   checked against the banned set before it is written, was dropped.
   Added as FR-021a.

3. **Contradiction** — FR-020 fixed the suite delta at exactly one test,
   while SC-010 called for a demonstration that would naturally be
   written as a second test. Resolved in favour of the seed's count:
   both demonstrations are performed against the working tree and
   recorded in the run, and FR-020 now says so explicitly.

All requirements re-read for testability after these edits. Every one
states an observable condition. No term of art is used without either a
Key Entities definition or an in-line gloss.

### Residual, accepted

The specification asserts a suite delta of exactly one test (FR-020,
SC-004) rather than an absolute count. The seed states an absolute
count. The relative form was chosen because an absolute count in a
specification goes stale the moment any other change lands, and this
repository has a standing constraint against count-bearing prose. The
baseline is recorded separately by the run, so the delta resolves to a
number without the specification carrying one.
