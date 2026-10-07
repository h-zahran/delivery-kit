# Feature Specification: the base branch can be set once, or named for one run

**Feature Branch**: `031-base-branch-flag`

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "Phase 31 — the base branch can be set once, or named for one run. A team that cuts feature branches from an integration branch, while the remote publishes another default, has no way to say so today."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A base branch set once beats the remote's default (Priority: P1)

A team leader whose team cuts feature branches from an integration branch sets `baseBranchOverride` once in the repository's `.delivery-kit.json` and commits it. Every developer's run then reports the base as an override, naming that file, and phase B cuts the feature branch from it, even though the remote publishes a different default. Nobody types anything per run. For a single different run, `--base-branch <name>` beats the key.

**Why this priority**: Without it, every run in such a repository cuts from the wrong base, and the only workaround is changing the remote's default for the whole team.

**Independent Test**: In a scratch repository with `origin/HEAD` pointing at `main`, `preflight.sh --base-branch-override integration` reports `baseBranch: integration` and `baseBranchSource: override`.

**Acceptance Scenarios**:

1. **Given** `origin/HEAD` points at `main`, **When** pre-flight runs with `--base-branch-override integration`, **Then** it reports `baseBranch` `integration` and `baseBranchSource` `override`.
2. **Given** no remote and a configured `baseBranch` of `trunk`, **When** pre-flight runs with `--base-branch-override integration`, **Then** it reports `integration` from `override`.
3. **Given** no override, **When** pre-flight runs, **Then** the existing order holds unchanged: `origin/HEAD`, then the key, then the current branch.

---

### User Story 2 - A bad name stops before anything is written (Priority: P2)

An operator who types a name git would not accept as a branch name is stopped at pre-flight, with the name and the argument both named.

**Why this priority**: Principle I. A bad name must fail loudly at pre-flight, not later inside B's `git checkout -b`.

**Independent Test**: `preflight.sh --base-branch-override 'two..dots'` exits non-zero, and its message names `'two..dots'` and `--base-branch-override`.

**Acceptance Scenarios**:

1. **Given** a name `git check-ref-format --branch` refuses, **When** pre-flight runs, **Then** it exits non-zero and names the value and the argument.

---

### User Story 3 - A resume keeps the recorded base (Priority: P3)

An operator who resumes a run, typing a different `--base-branch`, is told that the recorded base stands. The run never switches base silently.

**Why this priority**: B records the base and cuts the feature branch from it. A different base after that point is meaningless, and a silent switch would be a lie in the probe block.

**Independent Test**: the orchestrator's **Base branch:** paragraph carries the resume rule, pinned by `pipeline/tests/prose.bats`.

## Edge Cases

- **git absent.** Decision 11 stops the run. The probe block prints an `override` source like a `configured` one: the name was typed or configured, so it is printed with its layer and a note that it was not checked against the repository.
- **The named branch does not exist.** Not checked at pre-flight. B's branch creation fails and names it, as it does today for a configured name.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The pipeline MUST accept a `baseBranchOverride` configuration key and a `--base-branch <name>` flag that beats it, documented in the orchestrator's Configuration and Flags tables, `pipeline/docs/configuration.md`, `pipeline/README.md` and the repository `README.md`.
- **FR-002**: `preflight.sh` MUST accept `--base-branch-override <name>`, and a value given there MUST win over `origin/HEAD`, the configured name and the current branch.
- **FR-003**: When the override wins, `baseBranchSource` MUST be `override`, and the probe line MUST name the layer that set it: the flag, or the configuration file by path.
- **FR-004**: An override that `git check-ref-format --branch` refuses MUST stop `preflight.sh` with a message naming the value and `--base-branch-override`.
- **FR-005**: The `baseBranch` key's precedence MUST NOT change.
- **FR-006**: The orchestrator MUST read the override on a fresh run only, and MUST report, never apply, a different name typed on a resume.
- **FR-007**: Each documentation site that states the override MUST be pinned by a test, and each pin and each script check MUST be shown able to go red (Principle III).

## Success Criteria *(mandatory)*

- **SC-001**: The full suite passes from the repository root, naming every suite path.
- **SC-002**: Each of the nine mutations in `quickstart.md` turns its test red, and each is verified to have landed first.
- **SC-003**: `scripts/check-versions.sh` passes with the `[Unreleased]` entry above `[1.3.1]`.

## Assumptions

- A NEW key, not a change to `baseBranch`. A base branch is a fact about a repository, so it belongs in a committed configuration file, set once. But changing the existing key's precedence would change the meaning of every tracked `.delivery-kit.json` that sets it today.
- The orchestrator flag is named `--base-branch`, and the script argument `--base-branch-override`. The script's existing `--base-branch` already means "configured", and loses to `origin/HEAD` by design. The script reports `override` for both spellings because it never reads configuration; the orchestrator, which resolved the layers, names the layer.
