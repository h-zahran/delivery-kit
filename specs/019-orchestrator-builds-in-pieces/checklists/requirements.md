# Specification Quality Checklist: the orchestrator builds in pieces

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-29
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

- **Interface names are the requirement, not a leak.** The feature IS a
  rewrite of the orchestrator document. Its phase letters, the state-file key
  `gates.G.reviewMode`, the helper commands `piece-next` and `commit-add`, and
  the flags `--auto` and `--no-verify` are the contract the orchestrator and
  its pins depend on, so they appear in the requirements. How each sentence
  is worded, and how FR-010 and FR-017 are carried out, is left to the plan.
- **Audience.** The "stakeholder" is the developer who runs the pipeline and
  the orchestrator agent that reads `SKILL.md`; the spec is written for them.
- **Facts the seed did not carry, measured and recorded in Context and
  Assumptions:** the `--auto` flags row, pinned whole at `prose.bats:66`, also
  goes false (FR-020); `pipeline/docs/configuration.md:111`, pinned at
  `prose.bats:195`, goes false too but is Phase 22's; the repository's
  `SKILL.md` is byte-identical to the installed 1.2.1, so the seed's line
  numbers are current.
- **Carried from Phase 19 (spec 018, review of PR #47):** FR-010 (heading as
  data) and FR-017 (a committed-but-unrecorded piece is recorded, not
  rebuilt).
- Validation passed on the first iteration.
