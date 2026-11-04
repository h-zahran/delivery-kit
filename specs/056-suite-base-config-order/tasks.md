# Tasks: Phase B records config before the base suite starts

**Input**: `specs/056-suite-base-config-order/` (spec.md, plan.md, research.md, quickstart.md)

**Tests**: the seed asks for a test, so the test comes first and is seen red.

---

## Phase 1: User Story 1 and User Story 2, the order and its test (Priority: P1) 🎯 MVP

**Goal**: B says to record `config` before the start command (FR-001, FR-002), `phases.md` agrees (FR-010), and a test guards the order (FR-003, FR-004, FR-005). The two stories share one sentence, so they are one piece.

**Independent Test**: `bash "$HOME/bats/bin/bats" --filter 'B records config before' pipeline/tests/prose.bats` passes, with plan line `1..1`.

- [X] T001 [US2] In `pipeline/tests/prose.bats`, directly after the test "B starts the base suite run once the branch is cut", add the test "B records config before it starts the base suite run", as research R2 says. Run it and record in `specs/056-suite-base-config-order/measurements.md` that it is red, naming the missing sentence, before T002.
- [X] T002 [US1] In `pipeline/skills/pipeline/SKILL.md`, phase B, directly before ``Record `artifacts.spec`.``, add the sentence from research R1. Rewrap only the lines this touches. Run the new test and confirm it is green.
- [X] T003 [US1] In `pipeline/docs/phases.md`, section "Reusing a suite run", change "once the state file and the feature branch exist" so that it also names `config` as recorded (research R3).

**Checkpoint**: the new test and the skill's size test pass, and `pipeline/scripts/progress.sh` has no diff.

---

## Phase 2: User Story 2, prove the test can go red (Priority: P1)

**Goal**: each fault from the spec makes the test fail (SC-002), and the test runs on bash 3.2.

**Independent Test**: `specs/056-suite-base-config-order/measurements.md` holds one row per fault, with its mutated text and the test's failure message.

- [X] T004 [US2] In a detached worktree outside the repository, run the four faults from research R5 against `pipeline/skills/pipeline/SKILL.md` (swapped, record removed, start removed, correct order only outside phase B). For each one, print the mutated text, run only the new test, and record the result in `specs/056-suite-base-config-order/measurements.md`. Remove the worktree after. Never change the tracked tree.
- [X] T005 [US2] Run the new test in `pipeline/tests/prose.bats` at run time on Docker `bash:3.2`, and record the result in `specs/056-suite-base-config-order/measurements.md`.

**Checkpoint**: all four faults are red for the right reason, and the shipped skill is green.

---

## Phase 3: Release pipeline 1.9.1

**Goal**: the version records name 1.9.1 (FR-009, SC-006).

**Independent Test**: `bash scripts/check-versions.sh` exits 0.

- [X] T006 In `pipeline/CHANGELOG.md`, add the `[1.9.1] - 2026-11-04` section above `[1.9.0]`, with the fix and its test.
- [X] T007 In `pipeline/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, change the pipeline version to `1.9.1`. Run `bash scripts/check-versions.sh`.

**Checkpoint**: the versions agree.

---

## Dependencies

- Phase 1 comes first: Phase 2 mutates the sentence and the test that Phase 1 adds.
- Phase 3 comes last: its changelog describes what the other phases proved.
- T001 comes before T002: the test must be seen red first.
- No task can run in parallel: each one depends on the task before it, and the suite is one file.

## Implementation Strategy

Phase 1 alone closes the gap. Phase 2 proves the guard. Phase 3 ships it. The owner merges and tags after the run. Phase I's review moved the sentence, and added Configuration's sentence, the `configuration.md` sentence and the test in `pipeline/tests/base-suite.bats`, in I's late commit (FR-011 to FR-013).
