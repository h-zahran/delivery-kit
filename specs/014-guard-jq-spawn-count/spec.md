# Feature Specification: The context guard stops counting jq

**Feature Branch**: `014-guard-jq-spawn-count`

**Created**: 2026-09-01

**Status**: Draft

**Input**: User description: "The context guard stops counting jq. `handoff/hooks/context-guard.sh` runs on PostToolUse after EVERY tool call. Before it reads the transcript it spawns five jq processes, and its `read_config` function spawns four more per configuration file it finds, for each of the two files it reads. Measured 2026-08-26: 5, 9 or 13 jq processes for 0, 1 or 2 configuration files present. Process spawn dominates on Windows under Git Bash, which is a supported platform. Target: 2, 3 or 4 on the same three paths."

## Deviation from the seed, with cause

The seed prescribes a spelling for the refactor: emit the fields with `@tsv` and
split them with `IFS=$'\t' read`. **That spelling is measured to be broken and is
not used.** The evidence is in [research.md](./research.md); the summary is
below, and the reasoning for treating this as compliance rather than deviation
is in the Assumptions section.

Nothing else about the seed changes. The counts, the requirement list, the
constraints and the acceptance criteria are all honoured as written, with one
number corrected: the seed states the suite as `1..162`, and it is `1..163`
since Phase 13.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The guard costs less on every tool call (Priority: P1)

The guard runs after every single tool call. On Windows under Git Bash, process
spawn is the dominant cost, and the guard currently starts up to thirteen
separate helper processes before it has read a single byte of the transcript.

Each field it needs is fetched by its own process, and each configuration file
is read four times over. The same information can be fetched once per source.

**Why this priority**: This is the whole feature.

**Independent Test**: Count helper-process invocations for one guard run on each
of the three configuration paths — no configuration file, one, and two — before
and after the change. The counts fall and the guard behaves identically.

**Acceptance Scenarios**:

1. **Given** a machine with no configuration file, **When** the guard runs once,
   **Then** it starts fewer helper processes than before, and the number is
   recorded.
2. **Given** one configuration file, **When** the guard runs once, **Then** the
   same holds.
3. **Given** two configuration files, **When** the guard runs once, **Then** the
   same holds.

---

### User Story 2 - Nothing the guard does changes (Priority: P1)

This is a refactor. Every threshold decision, every message, every exit code and
every rejection of a bad value must be exactly what it was.

**Why this priority**: The guard's job is to fire at the right moment. A
refactor that changes when it fires has broken the product to save some
milliseconds.

**Independent Test**: The hook's existing test suite passes **without being
edited**. A test that needs changing is proof the behaviour changed.

**Acceptance Scenarios**:

1. **Given** the change, **When** the existing hook suite runs, **Then** every
   test passes and none was edited.
2. **Given** any value the guard rejects today — including one written with a
   leading zero — **When** the changed guard reads it, **Then** it is rejected
   identically.
3. **Given** a main-session payload, **When** the changed guard runs, **Then**
   it proceeds, exactly as before.
4. **Given** a subagent payload, **When** the changed guard runs, **Then** it
   exits without acting, exactly as before.

---

### User Story 3 - The record survives the refactor (Priority: P2)

The file carries a written history: a dated incident, the reasoning behind the
median window, the byte-cap fallback, and the rationale for rejecting values
that look like octal. That history is why the arithmetic can be trusted.

**Why this priority**: A refactor that deletes the reasoning leaves working code
nobody dares change next time.

**Independent Test**: Every explanatory comment present before is present after,
uncompressed.

**Acceptance Scenarios**:

1. **Given** the change, **When** the file's comments are compared with the
   previous version, **Then** none was removed or shortened.
2. **Given** the change, **When** a reader looks for why a named failure is
   reported loudly, **Then** that explanation is still there and the failure is
   still reported.

---

### Edge Cases

- **An empty field is the ordinary case, not the exception.** In the main
  session the payload's agent identifier is absent. Any splitting scheme that
  loses or shifts an empty field breaks the common path, not a rare one.
- **A configuration file with a missing key is supported.** Both files are
  optional and so is every key in them. A splitting scheme that shifts values
  when a key is absent installs the wrong setting.
- **A shifted setting can still look valid.** The configuration values are all
  positive integers, so a value that lands in the wrong slot passes validation
  and is installed. The failure is silent — no error, no failing test.
- **The helper emits carriage returns on the supported Windows shell.** Any
  scheme that reads its output line by line inherits them; a scheme that
  captures one line through command substitution does not.
- **A missing configuration file must still cost nothing.** The guard returns
  before starting any process when the file is absent. That is why the count
  varies by path at all.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The guard MUST fetch all four payload fields with a single helper
  invocation instead of one per field.
- **FR-002**: The guard MUST fetch all four configuration values from a file
  with a single helper invocation instead of one per value.
- **FR-003**: The splitting scheme MUST preserve empty fields in every position,
  including the first. It MUST NOT use a separator that the shell treats as
  whitespace.
- **FR-004**: The splitting scheme MUST NOT introduce carriage returns into any
  extracted value on the supported Windows shell.
- **FR-005**: Every default applied today MUST be applied after: the agent
  identifier, transcript path and working directory default to empty, and the
  session identifier defaults to the same placeholder it uses now.
- **FR-006**: All validation MUST stay in the shell and behave identically,
  including the rejection of values that look like octal and the reasoning
  recorded for it.
- **FR-007**: The early return for a missing configuration file MUST stay, so
  that an absent file still costs no helper process.
- **FR-008**: The availability check that runs before anything else MUST stay.
  It is inside the process budget, not exempt from it.
- **FR-009**: Every explanatory comment MUST survive uncompressed. The refactor
  moves code, not the record.
- **FR-010**: Every named failure MUST stay loud. No message the guard reports
  today may become silence.
- **FR-011**: The hook's existing test suite MUST NOT be edited.
- **FR-012**: The changelog of the plugin that owns the hook — not the other
  one — MUST gain one entry under its existing unreleased heading, naming the
  reduction and stating that behaviour is unchanged, and stating no count that a
  later change would falsify.
- **FR-013**: The changed file sits on a surface with a restricted vocabulary.
  The change MUST NOT introduce any of the banned terms there. This is checked
  by the suite, so it is a gate rather than a matter of care.

### Key Entities

- **The payload**: the structured input the guard receives on every tool call.
  Four fields are read from it. Read once after this change, four times before.
- **A configuration file**: an optional file holding up to four settings. Two
  are consulted in precedence order. Each is read once after this change, four
  times before.
- **The process count**: the number of helper processes one guard run starts.
  Varies by how many configuration files exist. It is the thing being reduced,
  and it is measured rather than asserted.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The helper-process count for one guard run falls on all three
  configuration paths, with the before and after numbers measured and recorded
  rather than claimed.
- **SC-002**: The full house suite passes from the repository root with the same
  number of tests as before this change, none failing and none malformed. The
  baseline is measured, not read from the seed, which states a number that a
  later change has since moved.
- **SC-003**: The hook's own test suite passes with no test edited.
- **SC-004**: For every field, the value extracted after the change is identical
  to the value extracted before, across inputs covering a present value, an
  absent key, a null value and an empty string — demonstrated as a comparison,
  not asserted.
- **SC-005**: A main-session payload still proceeds and a subagent payload still
  exits, demonstrated directly rather than inferred from the suite.
- **SC-006**: Every comment present before the change is present after.

### How each requirement is verified

Recorded so the plan does not rediscover it, and so nobody adds a test — the
acceptance criteria fix the suite size, so every check below rides on something
that already exists or on a measurement recorded in the run.

- **By the process count, measured on three paths**: FR-001, FR-002, FR-007,
  FR-008.
- **By the equivalence comparison**, old extraction against new, across present
  / absent / null / empty inputs: FR-003, FR-004, FR-005.
- **By the existing hook suite passing unedited**: FR-006, FR-010, FR-011.
- **By comparing the file's comments before and after**: FR-009.
- **By reading the changed document**: FR-012.
- **By the existing vocabulary gate in the suite**: FR-013.

## Assumptions

- **Departing from the seed's suggested spelling is compliance, not deviation.**
  The seed's own acceptance criteria require identical behaviour and forbid
  editing the hook's tests to make the change pass. The suggested spelling
  violates both, measured. Where a seed's illustration and a seed's acceptance
  criteria conflict, the acceptance criteria are the requirement. This is
  recorded here, in the research file, in the commit and in the pull request
  rather than taken quietly.
- This is not the same kind of decision as raising a test count, which changed
  an acceptance criterion and needed the owner. Here the acceptance criteria are
  unchanged and only one implementation satisfies them.
- The seed's stated suite count is stale by exactly the test the owner
  authorised in the previous phase. The baseline is measured at the start of
  this run and that measurement governs.
- The process-count target from the seed includes the availability check. It is
  not removed to make a number look better.
- The two extraction sites are independent. Either could be changed alone; both
  are changed because both were named.
