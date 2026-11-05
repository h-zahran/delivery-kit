# Tasks: Fix the base suite's red stop test, keep test runs in the foreground, and measure the deep review

**Input**: `specs/059-flaky-foreground-i-metrics/` (spec.md, plan.md, research.md, data-model.md, contracts/commands.md, quickstart.md)

**Tests**: the spec asks for them (FR-004, FR-009, FR-011), so each test comes first and is seen red.

Each phase is one review piece. No setup or foundational phase is needed: no new dependency, and each story stands alone.

---

## Phase 1: User Story 1, the base suite's signal state (Priority: P1) 🎯 MVP

**Goal**: The base suite's command starts with `SIGINT` as its caller had it, and the stop test gives a correct answer in both signal states (FR-001 to FR-005).

**Independent Test**: `"$HOME/bats/bin/bats" pipeline/tests/base-suite.bats` and `"$HOME/bats/bin/bats" tests/run-suite.bats` pass, and quickstart sections 1 to 3 give their expected results.

- [X] T001 [US1] In `pipeline/tests/base-suite.bats`, add three tests: a real `suite-base start` whose test command records a behaviour probe of `SIGINT` (a child bash sets a trap and sends itself `INT`) to a file, asserting that the command can catch `INT` when the test's own process can; a stop by the wait's limit ends the command and a process the command started, now that the command leads its own group; a KILL path where the runner ignores TERM still ends the command's group. Run the file and see the first test red.
- [X] T002 [US1] In `tests/run-suite.bats`, in `stop_run`, add a behaviour probe of `SIGINT` per research R3. When `INT` is ignored there: send the real `INT`, assert the script is still alive, send `TERM`, and go on to the same checks; print one `#` comment on descriptor 3. Add a test that runs a small script with `SIGINT` ignored at entry and asserts the probe says ignored, and one with it not ignored that asserts the opposite. Run `tests/run-suite.bats` from a script's background job, as quickstart section 1 does, and see the stop test green in seconds. A separate run in the foreground stays green.
- [X] T003 [US1] In `pipeline/scripts/progress.sh`, in `base_start`, remove `setsid` and always use `set -m` for the runner's start, and change the comment above it to say why. In `base_run`, wrap the command's start in `set -m` and `set +m`. In `base_run_exit`, signal `-$BR_CHILD`, falling back to `$BR_CHILD`, and change the comment. In `base_stop`, send the KILL to the child's group, falling back to its id. Run `pipeline/tests/base-suite.bats` until green, and run `shellcheck --norc -f gcc pipeline/scripts/progress.sh`.
- [X] T004 [US1] In `pipeline/docs/phases.md`, section "Reusing a suite run", state that the runner and the command each lead a process group by job control, and why. Record the facts in `specs/059-flaky-foreground-i-metrics/research.md`, section R8: run quickstart sections 1, 2 and 3, split the 500 passes across foreground calls, and record the passes, the load, the reds, the time and the real base suite's outcome. Plant each fault and record that it goes red: the runner back on `setsid`; the command's start with no `set -m`; a stop that leaves the temporary folder; a stop that leaves a process alive.

**Checkpoint**: a real base suite on the fixed code is green, and F.5 could cite it.

---

## Phase 2: User Story 2, foreground test runs (Priority: P2)

**Goal**: Every brief requires foreground test runs and says what to do over the 600-second limit (FR-006 to FR-009).

**Independent Test**: `"$HOME/bats/bin/bats" -f 'foreground' pipeline/tests/skills.bats` passes, and goes red when the rule leaves either skill file.

- [X] T005 [US2] In `pipeline/tests/skills.bats`, add tests: the ground rule in `pipeline/skills/pipeline/SKILL.md` holds every required word (`foreground`, `background`, `wait loop`, `monitor`, `600 s`, `split`, `bats -f`), says `each agent brief` and names no phase, so a new unit in the skill's section "Parallel agents" is bound with no change to the rule, and a list of phases in the rule goes red; the same words appear in the lenses' inputs in `pipeline/skills/spec-review/SKILL.md`; phase B's background base suite sentence is still present. Run them and see them red.
- [X] T006 [US2] In `pipeline/skills/pipeline/SKILL.md`, add one ground rule beside "A fault to plant": `**Test runs in a brief:** each agent brief says: foreground only, no background run, wait loop or monitor; over 600 s, split it, as with `bats -f`.` In `pipeline/skills/spec-review/SKILL.md`, add the same rule to "The three lenses". Update every pin these edits touch in `pipeline/tests/skills.bats` and `pipeline/tests/prose.bats`. Run both files until green.
- [X] T007 [US2] Prove the test can fail: remove each required word in turn and each of the two rule lines, invert the rule's text, and see the test red each time. Record the mutants in `specs/059-flaky-foreground-i-metrics/research.md`, section R8.

**Checkpoint**: the rule is in both skills, and a test holds it there.

---

## Phase 3: User Story 3, measuring phase I (Priority: P1)

**Goal**: Each lens's seconds, the fix seconds, and each lens's findings by severity and outcome reach `pipeline-run.json` with no hand edit (FR-010 to FR-018).

**Independent Test**: `"$HOME/bats/bin/bats" pipeline/tests/i-measure.bats` passes.

- [X] T008 [US3] Create `pipeline/tests/i-measure.bats` with one test per row of the `i-measure` table in `specs/059-flaky-foreground-i-metrics/contracts/commands.md`: the exact status and stdout line; an unknown part and a bad reason refused; `done` with no start refused; a second `done` refused, the seconds unchanged; a second `start` moves the old record to `earlier` and says so; `dispatch` starts five parts and not `fixes` or `recheck`; `findings` counts per lens by severity and outcome, a `|` in a finding's text does no harm, each bad line's number is recorded and printed, no finding text and no machine path reach stdout or stderr, an empty file records real zeros, an absent file exits 1. Run the file and see it red.
- [X] T009 [US3] In the same test file, add tests for the gate and the metrics key: `phase-done I` refuses each absent part and an absent findings record, names them and leaves the state file's bytes unchanged; it passes with all of `done`, `skipped` and `missing`; it stays as today for every other phase; `pipeline-run.json` holds `phaseI` per `data-model.md`: a part with no record reads `missing` and its seconds `null` and never 0, a skipped lens has `null` counts, a lens that ran and found nothing has zeros, `accountedSeconds` is the longest lens plus `fixes` plus `recheck` and `null` when any part is not `done` or `skipped`; a state file with no `measurements.i` gives `{"status":"missing"}`; a second `metrics` run writes the same bytes; keys added by hand stay. Assert the JSON types. Run them and see them red.
- [X] T010 [US3] In `pipeline/scripts/progress.sh`, add `cmd_i_measure` per the contract and research R5 to R7, with the parts as one list, the state write under `state_lock`, and the dispatch line, and add it to `usage`. Update the pinned list in `pipeline/tests/progress.bats`. Run `pipeline/tests/i-measure.bats` and `pipeline/tests/progress.bats` until the first group of tests is green.
- [X] T011 [US3] In `pipeline/scripts/progress.sh`, add the gate to `cmd_phase_done` and the `phaseI` key to `METRICS_JQ`, per the contract and `data-model.md`. Run the file until green, and run `shellcheck --norc -f gcc pipeline/scripts/progress.sh`. Run the whole suite in the foreground: a fixture that finishes phase I must follow the gate, so update any that does.
- [X] T012 [US3] In `pipeline/docs/phases.md`, add the section "Measuring phase I": who stamps what, when, the parts, `findings-I.txt` and its line, the outcome words, what `unmeasured` is for, and that seconds are wall time, stamped when the orchestrator records a return. Add a test in `pipeline/tests/i-measure.bats` that the doc's list of parts equals the script's list, read from the script.
- [X] T013 [US3] In `pipeline/skills/pipeline/SKILL.md`: change the metrics ground rule so it no longer says to add findings or agents with `jq`, and keep that added keys stay; add one sentence to phase I that points to "Measuring phase I" in `${CLAUDE_PLUGIN_ROOT}/docs/phases.md` and says `phase-done I` refuses a part with no record. Update the pins in `pipeline/tests/skills.bats` and `pipeline/tests/prose.bats`. Record the skill's byte count: the net spend across T006 and this task is at most 200 bytes.

**Checkpoint**: a fixture's phase I gives every number with no hand edit, and a missing one reads as missing.

---

## Phase 4: Release records

**Purpose**: pipeline 1.12.0 (FR-020).

- [X] T014 In `pipeline/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, set the pipeline's version to 1.12.0. In `pipeline/CHANGELOG.md`, add `## [1.12.0] - 2026-11-05` with what changed, written so that it does not call the test flaky. Run `bash scripts/check-versions.sh`.

---

## Dependencies & Execution Order

- Phases 1, 2 and 3 are independent in behaviour, and can land in any order. They run in this order because Phase 1 holds the only measured saving.
- Phases 2 and 3 both edit `pipeline/skills/pipeline/SKILL.md` and `pipeline/tests/skills.bats`, so they do not run side by side.
- Phase 4 comes last.
- Within a phase, tests come first and are seen red.

## Parallel Opportunities

- T001 and T002 touch different test files, but T002's check and T003 follow T001. One actor runs Phase 1 in order.
- T005 and T008 touch different test files and can start side by side.

## Implementation Strategy

Phase 1 alone gives the measured saving on the next run. Phase 3 gives the numbers for the next speed choice. Phase 2 prevents one large loss and has no number to show.

## Notes

- Every test run in this feature runs in the foreground. Split a run over 600 s.
- This repository's `bats` is at `$HOME/bats/bin/bats`.
- Plant faults in a worktree, per `pipeline:spec-review`, "The fault harness".
