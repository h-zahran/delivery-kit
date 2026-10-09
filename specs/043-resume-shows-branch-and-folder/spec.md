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
- **FR-002**: The rule MUST be stated in `pipeline/docs/configuration.md`, in the run's rules and in the note for readers. Each statement MUST be pinned and shown able to go red. `SKILL.md` changes as little as it can: it must stay under 65,536 bytes. Its pointer sends the run to the docs page when `--branch` or `--spec-dir` is set, or a resumed run's state file records one, and the probe block prints the lines "only when set or recorded" (see the notes below).

## Success Criteria *(mandatory)*

- **SC-001**: The full suite passes.
- **SC-002**: Both mutations in `quickstart.md` turn the pin red.

## Assumptions

- The sentence mirrors Phase 42's rule for the Trailers line, word for word where the subject allows.
- `pipeline/CHANGELOG.md` gains one sentence in the Phase 41 entry, still under `[Unreleased]`: the gap was never released.

## Changed after review 2 (2026-10-08)

- A plain `--resume` types none of the names, so the pointer never fired and FR-001 was not met (review 2, item 3). The pointer now also fires when a resumed run's state file records one, and the probe block prints the lines "only when set or recorded". FR-002's "`SKILL.md` does not change" no longer holds: three edits are in it, these two and, after review 3, the state-file read before the probe block (see review 4 below).
- `artifacts.spec` is the path of `spec.md`, so the Spec folder line is the folder that holds it (item 12).
- On a resume the Base branch line prints the recorded base, marked as recorded. The Trailers line already had its resume rule (Phase 42).
- `plan.md`, `contracts/resume-contract.md` and `checklists/requirements.md` were added (item 14).

## Changed after review 4 (2026-10-10)

- FR-001's "on a resume" means every re-entry: `--resume`, `--from`, and a resume chosen at the resume prompt (decision item 8). The last two render the probe block as a fresh run first, and nothing said to render it again (review 4, item 7). `SKILL.md`'s third edit now says the block is rendered from the state file on every re-entry, again if it was already shown, once decision item 7's lock is held and the tracked-state check under **Resume** has run, so the recorded lines never come from a state file whose tracked status is not yet known.
