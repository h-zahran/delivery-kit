# Feature Specification: the feature branch and the spec folder can be named for one run

**Feature Branch**: `032-branch-and-spec-dir-flags`

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "Phase 32 — the feature branch and the spec folder can be named for one run. The spec tool's `NNN-slug` names the feature branch, the spec folder and the run, and nobody can choose them."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A run names its feature branch (Priority: P1)

A developer whose team names branches by owner runs `/pipeline` with `--branch <owner>/<area>/003-thing`. Phase B cuts the feature branch under that name. The run's name and the spec folder still come from the spec tool.

**Why this priority**: Without it, every branch carries the spec tool's `NNN-slug`, and a team rule for branch names must be applied by hand after the run.

**Independent Test**: `preflight.sh --feature-branch 'team/one/003-thing'` reports `featureBranch: team/one/003-thing`.

**Acceptance Scenarios**:

1. **Given** `--feature-branch team/one/003-thing`, **When** pre-flight runs, **Then** it reports that name in `featureBranch`.
2. **Given** a name `git check-ref-format --branch` refuses, **When** pre-flight runs, **Then** it exits non-zero and names the value and `--feature-branch`.
3. **Given** a name equal to the resolved base branch, **When** pre-flight runs, **Then** it exits non-zero and says so.

---

### User Story 2 - A run names its spec folder (Priority: P1)

A developer whose team keeps specs in nested folders runs `/pipeline` with `--spec-dir specs/<area>/<owner>/003-thing`. Phase B hands the folder to the spec tool as `SPECIFY_FEATURE_DIRECTORY`, checks that `spec.md` landed there, and takes the run's name from the folder's last segment.

**Why this priority**: Without it, every spec lands in `specs/NNN-slug`, and a team's folder layout cannot be followed.

**Independent Test**: `preflight.sh --spec-dir 'specs/team/one/003-thing'` reports `specDir: specs/team/one/003-thing`.

**Acceptance Scenarios**:

1. **Given** a nested relative folder that does not exist, **When** pre-flight runs, **Then** it reports the folder in `specDir`.
2. **Given** a folder that is absolute, holds a backslash, climbs out with `..`, has an empty or `.` segment, sits under `.delivery-kit/`, or ends in an illegal run name, **When** pre-flight runs, **Then** it exits non-zero and names the value and `--spec-dir`.
3. **Given** a folder that already exists, **When** pre-flight runs, **Then** it exits non-zero and names it.
4. **Given** a run name that already has a state file, **When** pre-flight runs, **Then** it exits non-zero and names the state file.

---

### User Story 3 - A resume keeps the recorded names (Priority: P2)

A developer who resumes a run, typing a different `--branch` or `--spec-dir`, is told that the record stands. The run never switches silently.

**Why this priority**: B records both names and acts on them. A different name after that point is meaningless, and a silent switch would be a lie.

**Independent Test**: the orchestrator's **Feature branch and spec folder:** paragraph carries the resume rule, pinned by `pipeline/tests/prose.bats`.

## Edge Cases

- **git absent.** Decision 11 stops the run. The branch name is not checked by git, and the probe line says so. The spec folder checks never ask git.
- **The spec tool writes elsewhere.** B checks `<folder>/spec.md` and stops, naming both paths.
- **Only one flag.** Each works alone. `--branch` alone keeps the spec tool's folder and run name. `--spec-dir` alone names the branch after the folder's last segment, the run's name.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The pipeline MUST accept `--branch <name>` and `--spec-dir <path>`, documented in the orchestrator's Flags table, `pipeline/docs/configuration.md`, `pipeline/README.md` and the repository `README.md`.
- **FR-002**: `preflight.sh` MUST accept `--feature-branch <name>` and `--spec-dir <path>`, and report them as `featureBranch` and `specDir`, empty when not given.
- **FR-003**: `preflight.sh` MUST refuse a feature branch name `git check-ref-format --branch` refuses, and one equal to the resolved base branch, naming the value and the argument.
- **FR-004**: `preflight.sh` MUST refuse a spec folder that is absolute, holds a backslash, climbs out with `..`, has an empty or `.` segment, sits under `.delivery-kit/`, ends in a run name with characters outside letters, digits, dot, dash and underscore, already exists, or whose run name already has a state file, naming the value and `--spec-dir`.
- **FR-005**: Phase B MUST hand `--spec-dir` to the spec tool as `SPECIFY_FEATURE_DIRECTORY`, MUST check that `<folder>/spec.md` exists, and MUST cut the feature branch under `--branch` when it was typed.
- **FR-006**: The orchestrator MUST read both flags on a fresh run only, and MUST report, never apply, a different value typed on a resume.
- **FR-007**: No configuration key is added.
- **FR-008**: Each documentation site that states the flags MUST be pinned by a test, and each pin and each script check MUST be shown able to go red (Principle III).

## Success Criteria *(mandatory)*

- **SC-001**: The full suite passes from the repository root, naming every suite path.
- **SC-002**: Each of the 26 mutations in `quickstart.md` turns its test red, and each is verified to have landed first.
- **SC-003**: `scripts/check-versions.sh` passes with the `[Unreleased]` entry above `[1.3.1]`.

## Assumptions

- Flags only, no keys. Each value names one feature. A key set once would name every run the same. A caller that builds names from its own settings passes them as flags.
- The orchestrator flag is `--branch`. The script argument is `--feature-branch`, because the script's `--base-branch` already exists and a bare `--branch` beside it reads as the same thing.
- The run's name is the spec folder's last segment. `progress.sh` already refuses `/` in a run name and keeps the branch as a separate value, so no change is needed there.
- The spec tool's `SPECIFY_FEATURE_DIRECTORY` is described in its specify command in 0.15.2 and 0.16.5, the two ends of the tested range.
