# Tasks: Remove repeated and serial work from a pipeline run

**Input**: `specs/057-repeated-serial-work/` (spec.md, plan.md, research.md, contracts/run-suite.md, quickstart.md)

**Tests**: the spec asks for them (FR-023, FR-024), so each test comes first and is seen red.

---

## Phase 1: User Story 1 and User Story 2, the side-by-side suite command (Priority: P1) 🎯 MVP

**Goal**: `scripts/run-suite.sh` runs the test files at the same time and prints one report (FR-001, FR-003 to FR-012), and no broken run reads as green (contract rows R1 to R13).

**Independent Test**: `bash "$HOME/bats/bin/bats" --print-output-on-failure tests/run-suite.bats` passes, with every contract row exercised.

- [X] T001 [US2] Create `tests/run-suite.bats` with a stand-in test runner set through `BATS_BIN`, one test per group of contract rows in `specs/057-repeated-serial-work/contracts/run-suite.md`, using the exact status and message of each row. Include: renumbering and sorted order with files that end out of order, and a `#` comment holding `ok 3` left unchanged (FR-003, FR-004); `tap-check` accepting a green report and rejecting a `not ok`, a skip and a stray line (FR-007); `--print-output-on-failure` reaching the runner (FR-008); at least two files running at once, shown by two stand-ins that wait for each other, and at most 8 (FR-011); a stop that leaves no stand-in and no temporary folder (FR-012); no fixture path in any message; the script's `roots=` line equal to CI's `suite:` matrix (research R8). Run the file and see it red.
- [X] T002 [US1] Create `scripts/run-suite.sh` per `specs/057-repeated-serial-work/contracts/run-suite.md` and research R1 to R6, on bash 3.2 rules. Run `tests/run-suite.bats` until green, and run `shellcheck --norc -f gcc scripts/run-suite.sh`.
- [X] T003 [US2] Run `tests/run-suite.bats` on bash 3.2 in Docker (`bash:3.2`), with the network off, per the method in `specs/056-suite-base-config-order/measurements.md`. Record the result in `specs/057-repeated-serial-work/measurements.md`.

**Checkpoint**: the new tests pass. The script is not yet what `testCommand` calls.

---

## Phase 2: User Story 1, the repository uses the command (Priority: P1)

**Goal**: `testCommand` calls the script (FR-002), and developers can find it, with CI and the serial command unchanged (FR-013).

**Independent Test**: `jq -r '.pipeline.testCommand' .delivery-kit.json` prints `bash scripts/run-suite.sh`, and `git diff main -- .github/workflows/ci.yml` is empty.

- [ ] T004 [US1] Add to `tests/run-suite.bats` a test that `.delivery-kit.json`'s `testCommand` is exactly `bash scripts/run-suite.sh`, and that `CONTRIBUTING.md` still holds the serial command. See it red. In `.delivery-kit.json`, set `pipeline.testCommand` to `bash scripts/run-suite.sh`.
- [ ] T005 [US1] In `CONTRIBUTING.md`, section "Running the tests", directly after the serial command's code block, add a short paragraph: `bash scripts/run-suite.sh` runs the same files side by side and takes less time, it is what the pipeline's `testCommand` calls here, and CI stays serial.

**Checkpoint**: `tests/run-suite.bats` passes, and `git diff main -- .github/workflows/ci.yml` is empty.

---

## Phase 3: User Story 3, one fault harness per run (Priority: P2)

**Goal**: The harness rules ship in `pipeline:spec-review` (FR-014 to FR-021), the orchestrator points at them in at most 100 bytes (FR-022), and each rule is pinned and shown able to go red (FR-024).

**Independent Test**: `bash "$HOME/bats/bin/bats" --filter 'fault harness' --print-output-on-failure pipeline/tests/skills.bats` passes, and its plan line is not `1..0`.

- [ ] T006 [US3] In `pipeline/tests/skills.bats`, add the tests named with `fault harness`: one whole-span pin of the new section in `pipeline/skills/spec-review/SKILL.md` (the file's `span` and `exactly` helpers), one pin of the orchestrator's pointer, and one assertion that the section names no cap on faults. FR-022's limit of 100 bytes is checked once, in T008 and quickstart section 5, and not in a lasting test, because run 2 must be free to change the file. See them red.
- [ ] T007 [US3] In `pipeline/skills/spec-review/SKILL.md`, add the section "## The fault harness" at the end, per FR-014 to FR-021 and research R9 to R11: the fixed names, the first actor saves it, later actors reuse and extend it, the tests reviewer writes `faults-tests.txt` before it reads the harness, no cap, only the tests reviewer may create it in phase I, another reviewer names its fault and I's fix step runs it, a harness that git tracks is no harness, a throwaway copy only, a fault that changed no byte is reported as not landed, repair in place, and no run directory means the skill works as before.
- [ ] T008 [US3] In `pipeline/skills/pipeline/SKILL.md`, section "Ground rules", add one bullet that sends anyone planting a fault to "The fault harness" in `pipeline:spec-review`. Check `wc -c`: at most 65,415 bytes.
- [ ] T009 [US3] In `pipeline/docs/phases.md`, directly before "## Questions that wait", add a short section "## One fault harness per run" for readers: one harness per run, saved in the run directory, and the reviewers' judgement stays independent. Add a pin of it to `pipeline/tests/skills.bats`.
- [ ] T010 [US3] Create the run's fault harness at `.delivery-kit/runs/057-repeated-serial-work/fault-harness.sh`, following the new rules. Run each fault against a throwaway copy: remove and invert each rule in the new section, and break each contract row of `scripts/run-suite.sh`. Prove each fault landed. Record faults, messages and a no-fault control in `specs/057-repeated-serial-work/measurements.md`.

**Checkpoint**: every fault is red for the right reason, and the control is green.

---

## Phase 4: Measure and release (Priority: P1)

**Goal**: The script's time is measured at the repository root (FR-025, SC-001 to SC-003), and the change ships as pipeline 1.10.0 (FR-026).

**Independent Test**: `bash scripts/check-versions.sh` exits 0, and `specs/057-repeated-serial-work/measurements.md` holds at least three passes.

- [ ] T011 [US1] From the repository root, run quickstart sections 2 and 3. Record each pass's time and counts, the comparison of test names with the serial report, and the serial time in `specs/057-repeated-serial-work/measurements.md`.
- [ ] T012 In `pipeline/CHANGELOG.md`, add the `[1.10.0] - 2026-11-04` section above `[1.9.1]`: the fault harness. Say that the suite script is this repository's own and does not ship in the plugin.
- [ ] T013 In `pipeline/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, change the pipeline version to `1.10.0`. Run `bash scripts/check-versions.sh`.

**Checkpoint**: the versions agree, and the measurements meet SC-001 to SC-003.

---

## Dependencies

- Phase 1 comes first: Phase 2 calls the script, and Phase 3's faults break it.
- Phase 3 follows Phase 2: its fault run reads the final script.
- Phase 4 comes last: its measurements and changelog describe what the other phases built. If phase I or J changes `scripts/run-suite.sh`, re-run T011.
- T001 before T002, T004 before its config edit, T006 before T007 and T008: each test is seen red first.

## Parallel opportunities

- None within a piece that is worth the cost: each task depends on the one before it. T005 and T004's config edit touch different files, but T005 is one paragraph.

## Implementation Strategy

Phase 1 proves the script on its own. Phase 2 turns it on for the next run: this run keeps the serial command, because B recorded `testCommand`. Phase 3 is independent of the suite. Phase 4 measures and ships. The owner merges, and the tag follows the merge. Run 2 is the first real use, and it measures the savings.
