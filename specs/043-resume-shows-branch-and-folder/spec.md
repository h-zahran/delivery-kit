# Feature Specification: a resume shows the branch and the folder it recorded

**Feature Branch**: `043-resume-shows-branch-and-folder`

**Created**: 2026-10-07

**Status**: Draft

**Input**: "Phase 43 — on a resume, the probe block leaves out the Branch and Spec folder lines, because pre-flight gets neither value."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The operator sees the names a resumed run works under (Priority: P1)

An operator resumes a run that was started with `--branch` and `--spec-dir`. The probe block prints the Branch and Spec folder lines from the record: the branch from the state file, the folder from `artifacts.spec`, each marked as recorded.

**Independent Test**: the run's rules in the "Feature branch and spec folder" section of `pipeline/docs/configuration.md` carry the rule, pinned by `pipeline/tests/prose.bats`.

## Requirements *(mandatory)*

- **FR-001**: On a resume, the orchestrator MUST print the Branch and Spec folder lines from the record.
- **FR-002**: The rule MUST be stated in `pipeline/docs/configuration.md`, in the run's rules and in the note for readers. Each statement MUST be pinned and shown able to go red. `SKILL.md` does not change: it must stay under 65,536 bytes, and its pointer already sends the run to the docs page when `--branch` or `--spec-dir` is set.

## Success Criteria *(mandatory)*

- **SC-001**: The full suite passes.
- **SC-002**: Both mutations in `quickstart.md` turn the pin red.

## Assumptions

- The sentence mirrors Phase 42's rule for the Trailers line, word for word where the subject allows.
- `pipeline/CHANGELOG.md` gains one sentence in the Phase 41 entry, still under `[Unreleased]`: the gap was never released.
