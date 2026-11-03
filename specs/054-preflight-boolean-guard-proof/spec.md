# Feature Specification: Prove the pre-flight boolean-type guard, then close issue #34

**Feature Branch**: `054-preflight-boolean-guard-proof`

**Created**: 2026-11-03

**Status**: Draft

**Input**: User description: "issue #34: prove the gh/adb boolean-type guard catches --arg, then close the issue"

## Background

Issue #34 reports a hole in the pre-flight report's tests: a test that reads a
field through `jq -r` cannot tell the boolean `true` from the string `"true"`.
Changing how the report emits the `gh` or `adb` capability from a JSON value to
a string left every test green. A consumer that writes `.capabilities.gh | not`
then gets the wrong answer, because the string `"false"` is truthy.

The issue asked for one type assertion beside each value check, and for each
assertion to be proved by a mutation that is seen to land.

**The assertions already exist.** Commit `ad20d2e` (2026-10-11) added both to
the test "capabilities reports jq true and booleans for gh and adb" in
`pipeline/tests/preflight.bats`. Nobody recorded the mutation proof, and nobody
closed the issue. A third record also still calls the hole open: the "Known
gaps" section of `specs/013-preflight-git-probe/spec.md`.

So this feature does not add the `gh` and `adb` assertions. It proves them,
records the proof, closes the records that still call the hole open, and closes
the issue. It also closes the same hole in the five other boolean fields of the
report that no test checks by type (see Clarifications).

## Clarifications

### Session 2026-11-03

- Q: Should this work also add a type check for the five other boolean fields
  in the pre-flight report (`speckit.present`, `speckit.versionInRange`,
  `speckit.constitutionSet`, `capabilities.gitUsable`, `tree.dirty`)? → A:
  Yes, all five: one type assertion per field in an existing test, each proved
  by its own mutant.

**Correction found at plan (2026-11-03), after the answer above.** The
question said none of the five has a type check. That was read from a search
for `type == "boolean"` only. A comparison with a JSON boolean, such as
`.tree.dirty == true`, also goes red on a string, because `"true" == true` is
false in jq. Such comparisons exist for `speckit.constitutionSet`,
`tree.dirty` and `capabilities.gitUsable`. So the hole may be real only for
`speckit.present` and `speckit.versionInRange`. The answer's intent stands:
every one of the five is guarded and proved. FR-008 now lets the measurement,
not a search, decide which fields need a new assertion.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The guard is proved, not assumed (Priority: P1)

The owner reads the feature's measurement record and sees, for each of the
seven boolean fields (`gh`, `adb` and the five FR-008 fields), that emitting
the field as a string turns its guard test red, and that the test is green
again once the change is undone.

**Why this priority**: The issue exists because a guard was once assumed and
measured to be absent. A guard nobody has seen go red is the same claim again.

**Independent Test**: Read the measurement record. For each mutant it names
the exact changed line, the test that went red, and the restore check.

**Acceptance Scenarios**:

1. **Given** the report emits `gh` as a string, **When** the guard test runs,
   **Then** it fails, and the record shows the changed line as it was run.
2. **Given** the report emits `adb` as a string, **When** the guard test runs,
   **Then** it fails, and the record shows the changed line as it was run.
3. **Given** the report emits any one of the five FR-008 fields as a string,
   **When** the test that guards that field runs, **Then** it fails, and the
   record shows the changed line as it was run.
4. **Given** no mutant, **When** the suite runs on the commit's own script,
   **Then** it passes, and that script is byte-identical to the commit's.
5. **Given** a mutation that matched nothing, **When** the rig runs it, **Then**
   the rig reports the mutation as not landed and records no result for it.

---

### User Story 2 - No record still calls the hole open (Priority: P2)

A reader of issue #34, or of the 013 spec's "Known gaps" section, finds the
hole marked closed, with a pointer to this feature's proof.

**Why this priority**: A stale "deferred" line sends the next person to fix
what is already fixed, or to trust a record that disagrees with the code.

**Independent Test**: Read the 013 spec's gap entry and the pull request body.

**Acceptance Scenarios**:

1. **Given** this feature merges, **When** a reader opens the 013 spec's gap
   entry for `gh` and `adb`, **Then** it says CLOSED and names this feature,
   in the same shape the other closed entries in that section use.
2. **Given** the pull request is merged, **When** GitHub processes it,
   **Then** issue #34 closes through a `Closes #34` line in the pull request
   body.

---

### Edge Cases

- A mutant turns other tests red besides the guard test (for `gh`, a test that
  compares the value with `== true`). The record names every test that went
  red. The guard test MUST be among them; another test going red does not
  count as the guard's proof.
- `gh` feeds two report fields from one variable: `capabilities.gh` and
  `remote.ghPresent`. The record says that the `gh` mutant changes both.
- The rig must never change the tracked `pipeline/scripts/preflight.sh`. It
  mutates scratch copies beside a separate checkout, so an interrupted rig
  leaves the real tree clean.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The feature MUST run two mutants, each flipping one variable
  only: `gh` emitted as a string, and `adb` emitted as a string. Each runs on
  a scratch copy beside a checkout separate from the working tree.
- **FR-002**: For each mutant, the feature MUST show the changed line as it
  stands in the mutated file before it trusts any result, and MUST treat an
  unchanged file as a rig failure, not as a pass.
- **FR-003**: For each mutant, the feature MUST record which tests went red,
  by name, and MUST show that the guard test is one of them.
- **FR-004**: The feature MUST show that the unmutated script the suite runs
  against is byte-identical to the commit's, and that the suite is green on it
  (the control run), so a red under a mutant is the mutant's doing.
- **FR-005**: The feature MUST write the proof to
  `specs/054-preflight-boolean-guard-proof/measurements.md`, with the commit
  it ran against and the date.
- **FR-006**: The feature MUST mark the `gh`/`adb` entry in the "Known gaps"
  section of `specs/013-preflight-git-probe/spec.md` as CLOSED, naming this
  feature, in the shape that section already uses for closed entries.
- **FR-007**: The pull request body MUST carry `Closes #34`. The run MUST NOT
  close the issue by any other means.
- **FR-008**: Each of these five boolean fields MUST end the feature with a
  type guard that a mutant has been seen to turn red: `speckit.present`,
  `speckit.versionInRange`, `speckit.constitutionSet`,
  `capabilities.gitUsable` and `tree.dirty`. A type guard is an assertion that
  checks the field's JSON type, or compares it with a JSON boolean; a pattern
  over `jq -r` text is not one. Before any assertion is added, each field's
  mutant runs against the base tree. A field whose mutant leaves the suite
  green gets one type assertion, in an existing test that already reads the
  report, placed before any other line in that test that the mutant would turn
  red. A field whose mutant already goes red gets no new assertion; the record
  names the test that guards it.
- **FR-009**: Each FR-008 assertion MUST be proved by its own mutant (that
  field emitted as a string), under FR-002 to FR-004, and recorded under
  FR-005. FR-001's two mutants plus these five make seven.
- **FR-010**: After the change, every boolean variable the pre-flight script
  passes into its report as a JSON value MUST have a type assertion in the
  suite on a report field it fills. A boolean variable is one whose value is
  `true` or `false` when the report is built. The measurement record MUST list
  each such variable with the test that guards it, and the list MUST be
  derived from the report-building code, not written by hand. A variable that
  fills two fields (`gh` fills `capabilities.gh` and `remote.ghPresent`) needs
  one guard, because the mutation this feature measures changes both fields.
- **FR-012**: The suite MUST hold one test that walks a whole pre-flight
  report and fails if any field anywhere in it is the string `"true"` or
  `"false"`. It names no field, so a boolean added to the report later is
  covered on the day it lands. Before it ships, it MUST be shown to accept the
  reports of every fixture it runs on, and every mutant the rig runs MUST
  turn it red.
- **FR-011**: On the finished branch, if a mutant turns red only tests other
  than its own guard, or no test, the rig MUST report a failure rather than
  record a pass. On the base commit, a mutant that turns no test red is the
  hole being measured: it is recorded as `HOLE`, not as a failure.

### Key Entities

- **Guard test**: the test that holds the type assertion for a given field.
  For `gh` and `adb` it is "capabilities reports jq true and booleans for gh
  and adb" in `pipeline/tests/preflight.bats`.

- **Mutant**: one changed copy of the pre-flight script. It has the field it
  changes, the exact changed line, the tests that went red, and the restore
  check.
- **Measurement record**: the file that holds every mutant's result, the
  commit it ran against, and the date.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After the change, every mutant the rig derives (at least the
  seven: `gh`, `adb` and the five FR-008 fields) turns its own guard test red
  and the FR-012 test red, and each record shows its changed line.
- **SC-005**: The record holds two dated tables: every derived mutant against
  the base tree, and the same mutants against the finished tree.
- **SC-002**: The rig changes 0 files in the working tree: its `git status`
  is the same after the rig as before it. Each mutant runs against a separate
  checkout that holds the feature's own test changes.
- **SC-003**: After the merge, issue #34 is closed, and 0 records in the
  repository still call the `gh`/`adb` hole open.
- **SC-004**: The full suite stays green, with exactly one test more than the
  base commit: the FR-012 test. The FR-008 assertions go into existing tests.

## Assumptions

- The guard test at `pipeline/tests/preflight.bats` already holds both
  `gh`/`adb` assertions; the report-building code is not changed at all, only
  tests change.
- `pipeline/scripts/preflight.sh` emits `gh` and `adb` correctly today; the
  mutants change only a separate copy.
- The rig is a measurement, not a shipped test. Its script is not added to the
  test suites; its output goes into the measurement record.
- The mutation is the one the issue names: the value goes in as text, so jq
  emits a string. Other ways to break the type are out of scope.
