# Specification Quality Checklist: Pin the orchestrator's safety prose

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-29
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

### Validation record — pass 1

All sixteen items passed on the first read. One change was made during
drafting, and two judgement calls are recorded rather than treated as
failures.

**The change.** An earlier draft wrote FR-001 and its acceptance scenario
around the literal token `#123`. That token is the orchestrator's own
illustrative example, not a requirement of this feature, and pinning a spec to
it would have made the requirement read as narrower than it is. Both now say
"an unfetchable issue reference". The literal spelling survives into the plan,
which is where the pin's anchor text is actually chosen.

**First judgement call — the two file paths.** `pipeline/skills/pipeline/SKILL.md`
and `pipeline/tests/prose.bats` appear throughout the spec and read like
implementation detail. They are kept. This feature's entire subject is those
two specific files; a spec that said only "the orchestrator document" would be
unactionable. They are declared as Key Entities so the naming is explicit
rather than incidental.

**Second judgement call — where the shell idiom lives.** The requirements
state obligations only: anchor on the operative clause (FR-006), restrict the
search to the governing region (FR-007), fail loudly on an empty slice
(FR-008). The mechanism that satisfies them — slice the region, collapse it to
one line, search for the clause — appears once, under Assumptions, as a stated
preference inherited from the existing suite. That placement is deliberate: it
is a constraint the plan should honour, not a thing the spec demands.

**A limit of this checklist, stated plainly.** These sixteen items were
assessed by reading the spec, not by executing anything. "Requirements are
testable" here means each one names an observable outcome, not that a test has
been written and watched fail. The proof for that is SC-002 and SC-003, and it
is discharged during implementation, not here.
