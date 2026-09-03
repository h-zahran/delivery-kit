# Specification Quality Checklist: release pipeline 1.2.0 and handoff 2.1.1

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-03
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

Two items were judged rather than ticked, and the judgement is recorded because
a tick that hides a decision is worth nothing.

**"No implementation details"** — this specification names file paths, a JSON
key, a `grep` pattern and a shell script. For a feature whose entire content is
"change six version strings in five named files", those ARE the user-facing
facts, not implementation leakage: a version number has no existence apart from
the file that records it. The rule's purpose is to stop a spec from deciding
things a plan should decide. Nothing here does. There is no design freedom left
to protect.

**"Success criteria are technology-agnostic"** — same reading, same reason.
SC-001 through SC-005 are stated as outcomes a person can check, and the check
happens to be a command because the artefact happens to be a file.

**One finding was carried out of validation rather than fixed**, and it is the
most useful thing in this document. The agreement gate that guards this release
is BLIND to the defect this release fixes: `scripts/check-versions.sh` reads the
changelog with `grep -m1` against a pattern anchored to
`## [X.Y.Z] - YYYY-MM-DD`, an `## [Unreleased]` heading does not match it, and
so the gate skips over it and reads the previous release's heading instead.
Measured on the tree as it stands: the gate exits 0 and prints
`handoff: plugin=2.1.0 marketplace=2.1.0 changelog=2.1.0` and
`pipeline: plugin=1.1.0 marketplace=1.1.0 changelog=1.1.0` — a clean pass, on
the exact state that has been wrong since 2026-08-25.

Two things follow, both written into the spec:

1. This feature must not treat a green agreement gate as proof that the headings
   were folded (FR-011 says so explicitly). FR-008 is verified on its own.
2. There is no test anywhere that catches a dangling `## [Unreleased]` heading.
   That is a real gap and it is why one survived a release cycle. It is NOT
   closed here — and after the clarify gate that is an ANSWERED DECISION rather
   than a note. The question was put to the owner on 2026-09-03; the answer was
   to keep the seed's scope of five files and nothing else. It stays recorded in
   the spec's Clarifications, Edge Cases and Assumptions so the next planning
   pass inherits it.

Validation ran twice: once at authoring, once after the clarify gate integrated
its answer. Neither pass required a spec rewrite, and no checkbox changed state
in either — 16/16 both times. The second pass STRENGTHENED two items rather than
flipping them: "Scope is clearly bounded" now rests on a measured file count
instead of a stated one, and "Dependencies and assumptions identified" now
records an answered question where it previously recorded an assumption.

