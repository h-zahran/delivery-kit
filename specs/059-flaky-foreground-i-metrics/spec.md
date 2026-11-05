# Feature Specification: Fix the base suite's red stop test, keep test runs in the foreground, and measure the deep review

**Feature Branch**: `059-flaky-foreground-i-metrics`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "Fix the flaky run-suite test, require foreground test runs in every brief, and measure phase I. Purpose: cut the time one pipeline run takes. No check is dropped, capped or deferred. A saving must not reappear in another phase." The seed is saved verbatim at `.delivery-kit/runs/059-flaky-foreground-i-metrics/seed.md`.

## Clarifications

### Session 2026-11-05

- Q: Which findings of phase I should the metrics file count? → A: Found, per lens: for each lens, the count per severity, and how many were fixed, deferred or declined.
- Q: What should the run do if the flaky stop test will not go red under load? → A: Try 500 passes under load. If it stays green, hold the suspected timing on purpose with a stub. If the forced timing gives the same red at the same line, name it as the cause and fix it. The report says that the natural red did not come back.

### Measured during the spec audit, 2026-11-05

The second answer's fallback was not needed. This run's own base suite went red at the same line, and the cause is now measured. The test is not flaky: it fails on every run that starts with `SIGINT` ignored. A non-interactive shell's background job starts with `SIGINT` ignored, and bash cannot catch or reset a signal that was ignored at its entry. `suite-base start` starts its runner that way on any system with `setsid`. So `kill -INT` does nothing, the wait holds until the fixture's `sleep 60` ends, and the 60-second test limit fires. Measured: the test alone in the foreground, green in 4 s; the test alone with `SIGINT` ignored at entry, red in 60 s at `tests/run-suite.bats` line 459, from line 487, `stop_run INT 2`. Runs 058 and 059 are the only base suites since the test was added, and both were red. The green runs were in the foreground.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The base suite is not red because of how it was started (Priority: P1)

A pipeline run starts the full test suite on its base commit, and later phases cite that result. One test, `run-suite: TERM, INT and HUP end the test processes and remove the temporary folder`, goes red in that base suite on every Linux run, on a sound commit, with a 60-second timeout at its `INT` step. It passes in the foreground. The cause is measured: the base suite starts its runner so that every process under it ignores `SIGINT`. The red result makes the test-baseline phase run the whole suite itself: 155 seconds against 10 seconds. So the saving of release 1.8.0 is lost on every run until this is fixed. Any project's own test suite gets the same changed signal state, so a base suite can differ from a foreground run for reasons that have nothing to do with the code.

**Why this priority**: It is the only item here with a measured saving, and it costs every run.

**Independent Test**: Start a real base suite in a fixture whose test command reports its `SIGINT` state, and read the report. Run the stop test with `SIGINT` ignored at entry and read the result. Run it at least 500 passes under load.

**Acceptance Scenarios**:

1. **Given** a caller that does not ignore `SIGINT`, on a system with `setsid` and on one without it, **When** the base suite's runner runs the test command, **Then** the test command starts with `SIGINT` not ignored, as it does in the foreground. A caller that ignores it passes that state on, and bash cannot undo it.
2. **Given** the stop test, **When** it runs with `SIGINT` ignored at its own entry, for example from a person's background job, **Then** it gives the same result as in the foreground, and it does not hold for 60 seconds.
3. **Given** the fix, **When** it lands, **Then** no timeout is longer, no retry is added, no test is skipped, and the `INT` step still sends a real `SIGINT` and checks its result.
4. **Given** the fixed code, **When** the test runs at least 500 passes under load, **Then** it stays green on every pass, and the count is recorded.
5. **Given** the fixed code with a fault planted, **When** the test runs, **Then** it goes red. A stop that does not end the test processes, or a temporary folder that stays, still fails it. So does a runner that again starts its command with `SIGINT` ignored.

---

### User Story 2 - An agent never waits on its own background test run (Priority: P2)

The pipeline's agents run tests. In run 058, a reviewer started a test run in the background and waited on it. That run lost 5 hours of wall time, and part of that time the machine was asleep. The owner wants every agent told plainly to run tests in the foreground, and told what to do when a run does not fit the foreground limit.

**Why this priority**: It is very small and it prevents one large loss. This run cannot show the saving as a number.

**Independent Test**: List every brief that can run a test. Check that each one carries the rule, by a test that derives the list and goes red when a brief loses the rule.

**Acceptance Scenarios**:

1. **Given** the build agents of phase H, the reviewers of phase I, and the fix agents of phases I, J and M, **When** any of them receives its brief, **Then** the brief requires foreground test runs, and forbids background runs, wait loops and monitors.
2. **Given** a test run that does not fit the 600-second foreground limit, **When** an agent reads the rule, **Then** the rule tells it to split the run, with a named way to split it.
3. **Given** the orchestrator's own background base suite in phase B, **When** the rule is read, **Then** the base suite stays as it is, and nothing in the rule forbids it.

---

### User Story 3 - The owner can see which part of the deep review costs the most (Priority: P1)

Deep review (phase I) is 60% or more of a run's time without the owner's waits, and nobody can say which part of it costs the most. The pipeline's own instructions already tell the orchestrator to add findings and agent counts to the run's metrics file. Runs 056 and 057 kept some by hand, and run 058 kept none. The owner wants the numbers to arrive without depending on memory, so the next speed choice is a measured one.

**Why this priority**: The next speed work cannot be chosen without it.

**Independent Test**: Drive a recorded phase I through the new recording path in a fixture. Read the run's metrics file. Check each lens's seconds, the fix seconds and the findings per severity, and check that a measure that was not taken reads as missing.

**Acceptance Scenarios**:

1. **Given** a run's phase I, **When** each lens returns, **Then** that lens's seconds are recorded, though the lenses return at different times.
2. **Given** the fixes of phase I, **When** they end, **Then** their seconds are recorded.
3. **Given** the findings of phase I, **When** they are recorded, **Then** the metrics file holds, for each lens, a count per severity and how many were fixed, deferred or declined, read from one stated source.
4. **Given** a lens that was skipped, or a measure that was never taken, **When** the metrics file is written, **Then** that measure reads as missing, never as 0.
5. **Given** a metrics file that holds these numbers, **When** the metrics command runs again at a later phase boundary, **Then** the numbers are unchanged.
6. **Given** a run that resumes in phase I, **When** the numbers are recorded again, **Then** the file says plainly what was measured, and no number is silently doubled or lost.

---

### Edge Cases

- A lens is skipped by rule, because the code-review skill is absent or `codeRoots` resolves empty: its time and findings read as missing, with the skip visible.
- The machine sleeps during a lens: the recorded seconds are wall time, and the file does not claim otherwise.
- The source of the severity counts holds a line in an unexpected shape: it is not counted silently as nothing. The record says that it could not read that line.
- A subagent's write to the state file may be denied by the auto-mode classifier: the recording must still work, or say that it did not.
- A run started on an older pipeline has no such numbers: its metrics file stays valid and the numbers read as missing.
- A test run under load takes longer than the foreground limit: the agent splits it, and does not move it to the background.
- The stop test runs on Windows and macOS CI as well as on Linux: the fix holds on all three, and on bash 3.2.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The measured cause and the measurements in "Clarifications" MUST be recorded in the feature's research notes, with the red that was reproduced. The report MUST say that the red is natural and that the test is not flaky.
- **FR-002**: `suite-base start` MUST add no ignore of `SIGINT` of its own, on a system with `setsid` and on one without it, so the test command starts in the state its caller had. The stop test MUST NOT hold for 60 seconds when it itself starts with `SIGINT` ignored. The plan MUST say how each is done, and whether the test can still send a real `SIGINT` in that state.
- **FR-003**: The fix MUST NOT lengthen a timeout, add a retry, or skip a test.
- **FR-004**: The stop test MUST still go red when a stop leaves a test process alive or leaves the temporary folder, shown by forcing each failure. A test MUST go red when the base-suite runner adds that ignore.
- **FR-005**: The fix MUST be proven by at least 500 passes under load, with the counts recorded in the feature's research notes, and by a real base suite on the fixed code. A pass with `SIGINT` ignored at entry MUST be among the runs.
- **FR-006**: Every brief that can run a test MUST require foreground test runs and MUST forbid background runs, wait loops and monitors. This covers the build agents of phase H, the reviewers and fix agents of phase I, and the fix agents of phases J and M.
- **FR-007**: The rule MUST say what an agent does when a run does not fit the 600-second foreground limit: split it, with a named way to split it.
- **FR-008**: The orchestrator's own background base suite in phase B MUST stay as it is.
- **FR-009**: A test MUST go red when a brief named in FR-006 loses the rule. The test MUST derive its list from the briefs where it can, and MUST NOT rely on a hand-written list that can go stale in silence.
- **FR-010**: The pipeline MUST record, for phase I, each lens's seconds, the seconds of the fixes, and, for each lens, the findings per severity and how many were fixed, deferred or declined. `progress.sh metrics` MUST put them in the run's `pipeline-run.json`.
- **FR-011**: The recording MUST go through a `progress.sh` subcommand with a test, or a hook with a test. It MUST NOT depend on new prose alone.
- **FR-012**: The recording of a lens MUST work when the lenses return at different times, and the plan MUST name who records each return.
- **FR-013**: The severity counts MUST have one stated source. A line in that source that cannot be read MUST be reported, and never counted as nothing.
- **FR-014**: A measure that was not taken MUST read as missing, never as 0, in the state file and in `pipeline-run.json`.
- **FR-015**: Running the metrics command again MUST keep the recorded numbers unchanged, as it keeps other added keys.
- **FR-016**: A re-entry into phase I MUST NOT silently double or lose a recorded number. The plan MUST state the rule.
- **FR-017**: The prose at `pipeline/skills/pipeline/SKILL.md` about adding metrics with `jq` MUST agree with the new way of recording, so that a reader is not told two ways.
- **FR-018**: `pipeline/skills/pipeline/SKILL.md` MUST stay within its limit of 65,536 bytes, and MUST spend as few of its 322 free bytes as it can. Logic goes in `pipeline/scripts/progress.sh`, reviewer text in `pipeline/skills/spec-review/SKILL.md`, and rare text in `pipeline/docs/rare-paths.md`.
- **FR-019**: No lens, check, fault or test MUST be dropped, capped or deferred to reach these results.
- **FR-020**: The change MUST ship as a pipeline release: the manifests, the changelog and the version records agree, as this repository's release recipe requires.

### Key Entities

- **Lens measure**: one reviewer's name, its seconds, and whether it ran, was skipped, or was not measured.
- **Fix measure**: the seconds of phase I's fixes, or missing.
- **Severity count**: for one lens, the number of findings at each severity and how many were fixed, deferred or declined, from one stated source, with any unreadable line reported.
- **Brief**: the text an agent receives for its task, in a skill file or a document the skill names.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Before the fix, the test is red on every run with `SIGINT` ignored at entry. After the fix it is 0 reds over at least 500 passes under load, and 0 reds with `SIGINT` ignored at entry.
- **SC-002**: On the next run, whose base commit holds the fix, the test-baseline phase cites the base suite and takes under 30 seconds, against 155 seconds in run 058. This run's own base commit does not hold the fix, so this run's base suite is red and this run cannot show it. A real base suite on the fixed code, run by hand, shows the cause is gone.
- **SC-003**: Every brief named in FR-006 carries the rule, and removing it from any one of them turns a test red.
- **SC-004**: The first run on the new release holds, in its metrics file, a time for each lens that ran, a fix time, and each lens's counts per severity and per outcome, with no hand edit.
- **SC-005**: The longest lens time, plus the fix and recheck times, can be read against phase I's total, because the lenses run at once. Each lens's own time is there as well, so the owner can see which part costs the most.
- **SC-006**: No phase takes longer because of this change by more than the seconds that recording itself takes. No check is removed.

## Assumptions

- This run executes from the 1.11.0 plugin cache, so its own metrics file will not hold the new numbers. The first measurement is the next run. This run measures each lens by hand as a baseline.
- The foreground rule is prevention. Its saving cannot be shown as a number, and the DONE report claims no minutes for it.
- One green base suite does not prove the fix. The evidence is the measured cause, the passes under load, and a test that goes red when the cause comes back.
- Seconds are wall time. They hold whatever the machine did in that time, sleep included.
- CI's own layout stays as it is: serial and sharded.
- Not in scope: finding Windows faults before the push, and any cut to the work inside phase I. The numbers from this work choose that next step.
