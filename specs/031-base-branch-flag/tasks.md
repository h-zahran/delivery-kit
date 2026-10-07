# Tasks: the base branch can be set once, or named for one run

**Input**: Design documents from `/specs/031-base-branch-flag/`

**Prerequisites**: plan.md, spec.md, contracts/flag-contract.md, quickstart.md

**Tests**: test-first. Three pre-flight tests and one prose test. The full suite grows from `1..276` to `1..280`.

## Phase 1: User Story 1 — a base branch set once beats the remote's default (P1)

- [X] T001 [US1] In `pipeline/tests/preflight.bats`, add "base branch: an override beats origin/HEAD, and is reported as an override" and "base branch: the override beats the configured name where there is no remote". Run them: both fail on `unknown argument '--base-branch-override'`.
- [X] T002 [US1] In `pipeline/scripts/preflight.sh`, accept `--base-branch-override <name>`, list it in the unknown-argument message, and put it first in the resolution order with source `override`. T001's tests pass.

## Phase 2: User Story 2 — a bad name stops before anything is written (P2)

- [X] T003 [US2] In `pipeline/tests/preflight.bats`, add "base branch: an override git would not accept as a branch name is refused, naming it". It fails before T004.
- [X] T004 [US2] In `pipeline/scripts/preflight.sh`, refuse a name `git check-ref-format --branch` refuses, naming the value and the argument. Skip the check when git is absent: decision 11 stops the run.

## Phase 3: User Story 3 — documentation and the resume rule (P3)

- [X] T005 [US3] In `pipeline/skills/pipeline/SKILL.md`: the Configuration row for `baseBranchOverride`, the Flags row, the pre-flight invocation sentence, the git-absent marking for `override`, and the **Base branch:** paragraph with the resume rule.
- [X] T006 [US3] `pipeline/docs/configuration.md`: the JSON block, the key table and the Base branch section; one flag row in `pipeline/README.md` and in `README.md`.
- [X] T007 [US3] `pipeline/CHANGELOG.md`: `[Unreleased]` → Added. `scripts/check-versions.sh` passes.
- [X] T008 [US3] In `pipeline/tests/prose.bats`, add "the base-branch override is pinned where the operator reads it", pinning the five sites in `contracts/flag-contract.md`.

## Phase 4: Verification

- [X] T009 Run the nine mutations in `quickstart.md` §2 in a throw-away copy. Each must land, then go red.
- [X] T010 Run the full suite from the repository root, naming every suite path, with this feature's new files marked intent-to-add so the tracked-file scans read them. Record of one run, 2026-10-07, Linux: `1..280`, all `ok`; `scripts/check-versions.sh` exit 0, pipeline `UNRELEASED-ABOVE:## [Unreleased]`.
- [ ] T011 Shell analysis: run by CI's `shell-analysis` job. Not run locally: no analyser is installed on the machine that made this change.
