# Feature Specification: Remove repeated and serial work from a pipeline run

**Feature Branch**: `057-repeated-serial-work`

**Created**: 2026-11-04

**Status**: Draft

**Input**: User description: "Read docs/plans/2026-11-04-speed-and-gaps-seeds.md first. Its section "Run 1" is the seed: remove repeated and serial work." The seed is saved as `.delivery-kit/runs/057-repeated-serial-work/seed.md`.

## Clarifications

### Session 2026-11-04

- Q: Should this run also release its change as pipeline 1.10.0, with a release piece added to the run? → A: Yes. Add a release piece as pipeline 1.10.0. The owner still merges, and the tag follows the merge.
- Q: In phase I, if no harness exists yet and a reviewer other than the tests reviewer suspects a test gap, what should that reviewer do? → A: It names the fault in its finding. The fix step then runs that fault through the harness.

## The owner's rule

A saving must not reappear in another phase. This feature removes work that is done twice or done one file at a time. It drops no check, caps no check, and defers no finding.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - This repository's full suite takes under two minutes (Priority: P1)

A pipeline run in this repository runs the full suite in F.5, J and N. Today the suite runs one file at a time and takes about 561 seconds, on a machine with 16 CPUs. With this feature, the test files run side by side. The result is one report that the pipeline's existing checks read as they read a serial report.

**Why this priority**: This is the largest saving found: about 12 of run 056's 58 minutes. It removes waiting only, so nothing returns later.

**Independent Test**: Run the new command and the old serial command on the same commit. Compare the sets of test names and the time. Pass the report to `progress.sh tap-check`.

**Acceptance Scenarios**:

1. **Given** a green tree, **When** the new command runs, **Then** it prints one valid report, exits 0, and `progress.sh tap-check` accepts the report.
2. **Given** the same commit, **When** the new and the serial commands both run, **Then** both reports hold the same set of test names.
3. **Given** a test that fails, **When** the new command runs, **Then** the report holds a `not ok` line for it, with its output, and the command exits non-zero.

---

### User Story 2 - A broken run can never read as green (Priority: P1)

A test file crashes, prints no plan, or prints fewer tests than its plan names. Or no test file is found. The new command must say so and exit non-zero. A serial run shows these faults on its own. Running files side by side must not hide them.

**Why this priority**: Constitution Principle I. A saving that turns a broken run green is worse than no saving.

**Independent Test**: Force each fault with a stand-in test runner, and assert the exact exit status and message.

**Acceptance Scenarios**:

1. **Given** a test file whose process exits non-zero with all its tests `ok`, **When** the command runs, **Then** it exits non-zero.
2. **Given** a test file that prints no plan line, **When** the command runs, **Then** it exits non-zero and names the file.
3. **Given** a test file whose count of test lines differs from its plan, **When** the command runs, **Then** it exits non-zero and names the file.
4. **Given** no test file under a root, **When** the command runs, **Then** it exits non-zero and names the root.
5. **Given** the test runner is missing, **When** the command runs, **Then** it exits non-zero and says what is missing.

---

### User Story 3 - One fault harness per run (Priority: P2)

A fault script breaks the code on purpose and checks that a test goes red. The harness is its mechanics: the throwaway copy, the test runner's path, and the facts that make it run. The faults are what it tries. Today up to three actors in one run each build their own. With this feature, the first actor that needs a harness saves it in the run directory, and later actors reuse and extend it.

**Why this priority**: The tests reviewer finished last in all of runs 052, 053, 054 and 056. Part of that time was spent rediscovering facts. The saving is a soft estimate (3 to 6 minutes), so it comes second.

**Independent Test**: Read `pipeline:spec-review` and the docs it points at. Confirm the harness's fixed name, who creates it, and who reuses it. Prose tests pin each rule, and a fault run shows each pin goes red when its rule is removed.

**Acceptance Scenarios**:

1. **Given** a run with no harness, **When** an actor first needs to plant a fault, **Then** it saves the harness at the fixed name in the run directory, with the facts it needed.
2. **Given** a run with a harness, **When** a later actor needs to plant a fault, **Then** it reuses and extends the harness, and does not build another.
3. **Given** phase I, **When** the tests reviewer starts, **Then** it writes down its own faults before it reads the harness, and it runs every fault it needs.
4. **Given** a harness that fails, **When** an actor finds the cause, **Then** it repairs the harness in place and records the fact.

### Edge Cases

- **A new test file not yet committed.** The serial command runs every `*.bats` file on disk under the four roots. The new command must run the same set, so it finds files on disk. It does not use `git ls-files`: a tracked-file walk would silently skip an uncommitted test file. This differs from the seed's first measurement, which walked tracked files (the two sets are the same today: 21 files).
- **A skipped test.** The command passes the `# skip` line through. `tap-check` refuses it, as it does today.
- **Stray output.** A line that is neither TAP nor a `#` comment passes through unchanged, so `tap-check` refuses it, as it does today.
- **Text that looks like a test line.** Only a test line at the start of a line is renumbered. A `#` comment that holds `ok 3` is left unchanged.
- **The command is stopped.** `suite-base wait --limit` stops its process group. The command must leave no running child and no temporary folder behind.
- **Tests that share `$TMPDIR`.** Files that run side by side must not collide through shared temporary paths.
- **macOS and bash 3.2.** The command runs on bash 3.2 and needs no tool that the serial command does not need, other than standard POSIX tools.
- **Windows.** CI does not use the command, because it stays serial and sharded. The command's own tests still run in CI on all three systems, using a stand-in test runner.
- **Run 1 itself.** B records `config.testCommand` as resolved, and `suite-key` reads that recorded value. So this run keeps the serial command in F.5, J and N. Run 2 is the first that uses the new command. The evidence for this run is direct measurement.
- **A planted harness.** The run directory can be tracked in a cloned repository. An actor must not run a harness that git tracks. It treats that as no harness and says so.
- **Two reviewers at once.** Phase I's reviewers start together. So only the tests reviewer may create the harness in I. Another reviewer uses it if it exists, or names the fault in its finding, and I's fix step runs that fault.
- **A fault that did not land.** A no-op fault makes a false green. The harness must report a fault that changed no byte, as distinct from a test that stayed green.
- **The working tree.** A harness works only on a throwaway copy, and never edits the tree or writes to git in the repository.
- **`pipeline:spec-review` outside a run.** With no run directory, the skill works as it does today.
- **A run that plants no fault.** There is no harness file, and nothing changes.
- **`SKILL.md` is 65,315 bytes** and the size test fails at 65,536. Run 2's gaps need the 221 free bytes. This feature adds as few as it can.

## Requirements *(mandatory)*

### Functional Requirements

**Part A: the suite side by side**

- **FR-001**: The repository MUST have a script that runs each `*.bats` file found on disk under `tests`, `handoff/tests`, `pipeline/tests` and `team/tests`, at the same time, each in its own test-runner process.
- **FR-002**: `testCommand` in `.delivery-kit.json` MUST call that script.
- **FR-003**: The script MUST print one TAP stream: one plan line first, then every test line of every file, numbered from 1 to N with each number used once. A file's other lines pass through unchanged.
- **FR-004**: The script MUST print the report in a fixed order, whichever file ends first.
- **FR-005**: The script MUST exit 0 only when every file's process exited 0, every file printed exactly one plan line, each file's test lines match its plan, and at least one file ran.
- **FR-006**: On any other outcome the script MUST exit non-zero and name the fault and the file on stderr, without a user name or machine path in the message beyond the repository-relative file name.
- **FR-007**: `progress.sh tap-check` MUST accept the report of a green run, and reject the report of a run with a `not ok`, a skip, or a stray line, with no change to `tap-check`.
- **FR-008**: The script MUST run each file with `--print-output-on-failure`, so a failing test's output reaches the report as it does in the serial command.
- **FR-009**: The script MUST need no new dependency, and MUST run on bash 3.2.
- **FR-010**: The script MUST use the same test runner path as the serial command, and MUST accept the override `BATS_BIN` that `scripts/context-guard/field-order-mutation.sh` already reads.
- **FR-011**: The script MUST limit how many files run at once, from the machine's CPU count, with a fixed upper limit.
- **FR-012**: When the script is stopped, it MUST stop its children and remove its temporary files.
- **FR-013**: CI MUST stay serial and sharded. The serial command in `CONTRIBUTING.md` and `README.md` stays as the plain way to run the suite. `CONTRIBUTING.md` MAY also name the new command, if no test forbids it.

**Part B: one fault harness per run**

- **FR-014**: `pipeline:spec-review` MUST define the fault harness: its fixed name in the run directory, and what it holds (the throwaway copy, the test runner's path, the facts that make it run).
- **FR-015**: The first actor in a run that needs to plant a fault MUST save the harness there. A later actor MUST reuse and extend it, and MUST NOT build another. This binds H, I's fix step and J.
- **FR-016**: The tests reviewer MUST write down its own faults BEFORE it reads the harness, so its judgement stays independent. The harness shares mechanics, never a fault list.
- **FR-017**: The text MUST NOT cap the number of faults, and MUST NOT remove a lens.
- **FR-018**: In phase I only the tests reviewer MAY create the harness. Another reviewer MUST use it if it exists, or else name the fault in its finding. I's fix step MUST run a fault named that way through the harness before it accepts or declines the finding, so the proof is moved and not lost.
- **FR-019**: An actor MUST NOT run a harness that git tracks. It treats that as no harness and says so.
- **FR-020**: A harness MUST work only on a throwaway copy, and MUST report a fault that changed no byte as a fault that did not land.
- **FR-021**: An actor that finds a harness broken MUST repair it in place and record the fact in it.
- **FR-022**: The orchestrator's `pipeline/skills/pipeline/SKILL.md` MUST grow by no more than 100 bytes, and MUST stay under the size test's limit.

**Tests and records**

- **FR-023**: Automated tests MUST cover FR-003 to FR-006, FR-010 and FR-012 with a stand-in test runner, on all three systems in CI.
- **FR-024**: Prose tests MUST pin FR-014 to FR-021, and a fault run MUST show each pin goes red when its rule is removed or inverted.
- **FR-025**: `specs/057-repeated-serial-work/measurements.md` MUST record at least three passes of the final script at the repository root: wall time and the counts of ok, not ok and skip, with the serial time beside them.
- **FR-026**: The change MUST ship as pipeline 1.10.0: the plugin's changelog, its manifest and the marketplace entry MUST all name it, and `scripts/check-versions.sh` MUST agree.

### Key Entities

- **Suite report**: the one TAP stream the script prints.
- **Fault harness**: a file in the run directory, not tracked, that holds the mechanics for planting faults in a throwaway copy.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The full suite at the repository root takes under 120 seconds on the owner's machine, in each of at least three passes. Serial takes about 561 seconds.
- **SC-002**: Each of at least three passes reports the same test count as the serial suite on that commit, with 0 not ok and 0 skip.
- **SC-003**: The set of test names in the new report equals the set in the serial report on the same commit.
- **SC-004**: Every fault in User Story 2 gives a non-zero exit in a forced run, and none reads as green.
- **SC-005**: Each new prose pin goes red under its fault, and a control with no fault stays green.
- **SC-006**: `SKILL.md` grows by at most 100 bytes.
- **SC-007**: This run's DONE summary reports each phase's minutes and gate waiting time against run 056, and says that part A's saving first shows in run 2.
- **SC-008**: In run 2, the first run that uses this feature, the DONE summary reports each phase's minutes against run 056, and whether one harness served the run. This is measured after this run, and is not a gate on it.

## Assumptions

- `tap-check` and `suite-record` need no change. The script fits what they already accept.
- Four passes at 8 files at once were green on `04e2a81` (81 to 97 seconds, 983 ok each), so the test files are safe to run side by side on the owner's machine. Slower machines keep the serial command.
- The suite's existing per-test timeouts are unchanged. The machine's load under 8 files at once is no higher than in those four passes.
- The harness is written by an agent for this project's test tool, so no shipped template is needed. The rules are what ship.
- The pipeline's other users are not affected by part A, because `testCommand` is this repository's setting.
