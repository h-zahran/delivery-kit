# Feature Specification: preflight.sh coverage and a probe helper

**Feature Branch**: `009-preflight-coverage-probe`

**Created**: 2026-08-27

**Status**: Draft

**Input**: Campaign 2, Phase 9 of `main-plan.md` — "preflight.sh coverage and a
probe helper". Quoted verbatim into the run directory as `seed.md`.

## Clarifications

### Session 2026-08-27

No questions were raised. The seed is unusually complete: it names each of the
thirteen behaviours to cover, it names the one behaviour that must **not** be
covered because it already is, and it states the target count. Three things that
would otherwise have been asked are settled by the seed itself and are recorded
here so a later reader does not reopen them:

- **Whether to add a test for the multi-line comment case.** No. The seed says
  so explicitly, and says a previous review claimed otherwise and was wrong. The
  existing fixture already opens with a multi-line comment carrying a bracketed
  token, and an existing test goes red without multi-line stripping. Verified
  before this specification was written.
- **Whether the probe helper may change any assertion.** No. The conversion is
  mechanical: same arguments, same assertions, fewer process spawns.
- **Whether the probed script's behaviour may change.** No. Same flags, same
  keys, output still parses whole. This feature reads the script; it does not
  edit it.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every way the probe can refuse is proven to say why (Priority: P1)

The pre-flight probe is the first thing a run does, and the first thing a person
meets when a run will not start. It refuses in several distinct ways — an
argument it does not know, a flag given without its value, a directory it cannot
enter, a required tool missing — and each refusal carries its own message naming
the fault. Only some of those refusals are exercised today. The rest could
degrade into a bare failure, or into a message naming the wrong thing, and every
suite would stay green.

After this feature, each refusal has a test asserting that the message names
what was wrong.

**Why this priority**: these are the messages a person reads at the moment
nothing works yet. A refusal that does not name its cause turns a five-second
fix into a search.

**Independent Test**: drive the probe into each refusal in turn and assert both
the non-zero result and the naming.

**Acceptance Scenarios**:

1. **Given** each unreached refusal, **When** the probe is driven into it,
   **Then** it exits non-zero and its message names the specific fault.
2. **Given** any one of those tests, **When** the message it asserts is changed
   to name something else, **Then** that test goes red.

---

### User Story 2 - Every way the probe warns and continues is proven to warn (Priority: P1)

The probe also has a second, quieter class of behaviour: conditions it reports
without stopping. A recorded value that is empty, a repository initialised for a
different agent, a governance file saved in an encoding it cannot read. Each
emits a warning on the diagnostic stream and carries on. Nothing tests that the
warning is emitted, that it names the condition, or — critically — that the
data stream stays clean while the warning is on the diagnostic one.

**Why this priority**: equal to Story 1. A warning that silently stops being
emitted is worse than a refusal that does, because nothing fails to draw
attention to it.

**Independent Test**: construct each condition, confirm the warning appears on
the diagnostic stream naming the condition, and confirm the data stream still
parses whole.

**Acceptance Scenarios**:

1. **Given** each unreached warning condition, **When** the probe runs, **Then**
   the warning names the condition, the run still succeeds, and the data stream
   still parses whole.
2. **Given** a governance file the probe cannot parse, **When** the probe runs,
   **Then** it reports the file as not carrying principles rather than guessing.

---

### User Story 3 - The degradations the probe announces are proven per cause (Priority: P2)

Before any work starts, the probe names which phases will be skipped and why.
Those decisions have several distinct causes — no remote at all, a remote that
is not the expected host, the absent command-line client, an absent device tool
on a mobile project. Only one cause is covered today. A change that made one
cause stop producing its skip would leave a run believing a phase will happen
when it will not.

**Why this priority**: a wrong skip list is a wrong plan for the whole run, but
it degrades loudly at the phase itself, so it ranks below the two above.

**Independent Test**: construct each cause and assert the announced skip list
names the right phase for the right reason.

**Acceptance Scenarios**:

1. **Given** a mobile project with the device tool absent, **When** the probe
   runs, **Then** the runtime-check phase is announced as skipped, with the tool
   named as the reason.
2. **Given** a remote that is not the expected host, **When** the probe runs,
   **Then** the review phase is announced as skipped.
3. **Given** the command-line client absent, **When** the probe runs, **Then**
   the review phase is announced as skipped, for that reason.

---

### User Story 4 - The last unpinned base-branch route is pinned (Priority: P2)

The probe resolves which branch a run should build on, by three routes in a
fixed order, and reports which route won. Two of the three are pinned by tests.
The third — the fallback used when there is neither a published default nor a
configured one — is not. That fallback is the route a fresh local repository
takes, so it is the one a newcomer meets first.

**Why this priority**: independent of the others and small, but it closes the
last gap in a resolution order the whole run depends on.

**Independent Test**: run the probe in a repository with neither of the first
two routes available and assert both the branch and the reported route.

**Acceptance Scenarios**:

1. **Given** a repository with no published default branch and no configured
   override, **When** the probe runs, **Then** it reports the current branch and
   names the fallback as the route.

---

### User Story 5 - The suite stops paying for twenty-four near-identical spawns (Priority: P3)

Nearly every test in this suite starts the same way: run the probe against a
fixture and capture both streams separately. That line appears two dozen times,
and one fixture is probed five separate times. Each is a process spawn, which is
the expensive operation on the slowest platform this repository supports.

After this feature, that line is a single named helper. The tests assert exactly
what they asserted before.

**Why this priority**: it improves the suite without changing what it proves, so
it ranks last. It is included because the seed asks for it and because the
duplication makes the suite harder to read than it needs to be.

**Independent Test**: the converted call sites produce the same results as
before, and the number of tests does not move.

**Acceptance Scenarios**:

1. **Given** the converted suite, **When** it runs, **Then** every test passes
   and the test count is unchanged.
2. **Given** the conversion, **When** the diff is read, **Then** it is mechanical
   — no assertion is added, removed or altered.

---

### Edge Cases

- **A refusal that names nothing.** A test asserting only a non-zero exit passes
  with the message emptied. Each refusal test must assert the naming.
- **A warning proven only by its exit status.** The probe succeeds in every
  warning case, so exit status proves nothing there. The assertion must be on
  the diagnostic stream's content.
- **The stream separation is itself the property.** A warning must never reach
  the data stream. Each warning test must confirm the data stream still parses
  whole, or the warning could be corrupting the output nobody noticed.
- **Removing a tool from the search path removes more than one tool.** Several
  of these conditions are constructed by making a program unfindable. A blunt
  emptying of the search path can make the probe fail for a different reason
  than the one under test, which would pass the test for the wrong cause. Each
  such test must confirm it failed for the reason it names.
- **The fallback route needs two absences at once.** It is reached only when
  neither of the earlier routes applies, so a test that supplies a configured
  override cannot reach it. Every existing test supplies one.
- **A helper that hides a difference is worse than the duplication.** The two
  dozen call sites are not all identical — some pass an extra argument, and the
  new tests need shapes none of them use. The helper must be able to express
  every existing call exactly, and must not force a caller into a shape that
  quietly changes what is probed.
- **One behaviour must NOT be covered.** The multi-line comment case is already
  pinned by an existing fixture and test. Adding a second test for it would be
  duplication presented as coverage.

## Requirements *(mandatory)*

### Functional Requirements

**The arithmetic, stated once so it cannot drift.** Thirteen new tests: ten for
the script's unreached branches (FR-001 to FR-007, FR-011 to FR-013) and three
for the governance-file parser (FR-008, FR-014, FR-015). Each requirement in
those two groups is **exactly one test**. Where a single branch is reachable by
two routes, one test exercises both — see FR-012, which is the only such case
and the one most likely to be split by accident.

**Refusals**

- **FR-001**: A test MUST prove the probe refuses an argument it does not
  recognise, and that the message names the offending argument and lists the
  legal ones.
- **FR-002**: A test MUST prove the probe refuses a flag supplied without its
  value, and that the message names what the flag needed.
- **FR-003**: A test MUST prove the probe refuses a directory it cannot enter,
  and that the message names the directory.
- **FR-004**: A test MUST prove the probe refuses when its required data tool is
  not on the search path, and that the message names the tool. The test MUST
  confirm the refusal happened for that reason and not another.

**Warnings that do not stop the run**

- **FR-005**: A test MUST prove the probe warns when the recorded version is
  empty, still succeeds, and still emits a data stream that parses whole.
- **FR-006**: A test MUST prove the same for an empty recorded script flavour.
- **FR-007**: A test MUST prove that a repository carrying another agent's skill
  directory produces both the foreign-agent warning and a recorded invocation
  form of "none", together, in one run.
- **FR-008**: A test MUST prove the probe warns when the governance file is
  saved in an encoding it cannot read, and reports that file as not carrying
  principles rather than guessing.
- **FR-009**: Every warning test MUST assert on the diagnostic stream's content,
  never on exit status alone, because the probe succeeds in all of these cases.
- **FR-010**: Every warning test MUST also confirm the data stream still parses
  whole. A warning leaking into the data stream is the regression these tests
  exist to catch.

**Announced degradations**

- **FR-011**: A test MUST prove the runtime-check phase is announced as skipped
  when a mobile project has no device tool available, with the tool named.
- **FR-012**: **One** test MUST prove the review phase is announced as skipped,
  exercising BOTH causes inside it — a remote that is not the expected host, and
  the command-line client absent. One test, not two: the seed counts this as a
  single branch because it IS one branch in the script, reachable by two routes,
  and writing two tests would put the suite at fourteen new tests against a
  stated acceptance of thirteen. The already-covered no-remote case MUST NOT be
  duplicated.

**Base branch**

- **FR-013**: A test MUST prove the fallback route: with no published default
  branch and no configured override, the probe reports the current branch and
  names the fallback as the source. The two already-covered routes MUST NOT be
  duplicated.

**Governance-file parsing**

- **FR-014**: A test MUST prove the byte-order-mark on the first line is stripped
  before the file is judged.
- **FR-015**: A test MUST prove a comment opened and never closed does not
  swallow the rest of the file.
- **FR-016**: **No test may be added for the multi-line comment case.** It is
  already pinned: the existing fixture opens with a multi-line comment carrying
  a bracketed token, and an existing test goes red without multi-line stripping.
  This was verified before the specification was written. A second test there
  would be duplication presented as coverage.

**The probe helper**

- **FR-017**: A single named helper MUST replace the repeated invocation line,
  and MUST live in the fixture file every suite loads.
- **FR-018**: The helper MUST be able to express every existing call site
  exactly, including the ones that pass an extra argument, and the shapes the
  new tests need — in particular, running with no configured base branch at all,
  and running with a modified search path.
- **FR-019**: The conversion MUST be mechanical. No assertion is added, removed
  or altered, and the number of tests does not move.
- **FR-020**: The helper MUST NOT hide which fixture a call probes. A reader of
  any converted test must still see the fixture named at the call site.

**Scope discipline**

- **FR-021**: The probed script MUST NOT be modified. Same flags, same keys,
  data stream still parses whole. This feature reads it; it does not edit it.
- **FR-022**: No changelog entry is written. The campaign's routing ruling
  assigns this phase none.
- **FR-023**: Any new fixture MUST live under the existing fixtures directory,
  which the ignore rules re-include wholesale, and MUST add no dependency of its
  own.
- **FR-024**: Every line reference carried in the seed MUST be re-derived from
  content before use. Two previous phases in this campaign shipped seeds whose
  line numbers had already moved.

### Key Entities

- **The probe**: the script a run executes before anything else, to report what
  the machine and the repository can support. It reports; it does not decide.
- **A refusal**: a non-zero exit and a message naming the fault. The naming is
  the property under test.
- **A warning**: a message on the diagnostic stream, with the run continuing and
  the data stream unaffected. Exit status proves nothing about a warning.
- **An announced degradation**: a named phase and a stated reason, published
  before any work begins, so a run never silently drops a phase.
- **The resolution order**: three routes to a base branch, tried in a fixed
  order, with the winner named in the output.
- **The probe helper**: one named way to invoke the probe from a test, replacing
  a line repeated two dozen times.
- **A fixture**: a small directory shaped like a repository, used to put the
  probe in a known state. Fixtures live in one place and carry no dependencies.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The full house suite, run from the repository root, reports
  `1..147` with zero failures and zero non-conforming output lines. The starting
  point is `1..134`; the increase is exactly the thirteen new tests.
- **SC-002**: Each of the thirteen new tests is observed failing before it is
  trusted, by inverting its operative assertion — never by deleting the test —
  with the altered line echoed back before the failure is believed.
- **SC-003**: The suite holding these tests grows from twenty to thirty-three
  tests, and no other suite's count moves.
- **SC-004**: The repeated invocation line appears exactly once in the
  repository after the conversion, as the helper's own body.
- **SC-005**: The converted call sites are shown to be mechanical: the diff adds,
  removes and alters no assertion.
- **SC-006**: The probed script is unchanged — its diff is empty.
- **SC-007**: No changelog file is modified.
- **SC-008**: Each refusal test goes red when the naming it asserts is changed to
  name something else.
- **SC-009**: Each warning test goes red when the warning it asserts is removed
  from the script, and passes again when restored, with the script left
  byte-identical.
- **SC-010**: No test added for the multi-line comment case; the existing test
  covering it is untouched.
- **SC-011**: Every ad-hoc verification search fires a control that must match
  before any zero is believed, and every needle is built where no escaping
  boundary can eat it.

## Assumptions

- **The seed's list of ten branches is accurate and complete for its purpose.**
  Each was located in the script by content before this specification was
  written, and all ten exist.
- **Three of the thirteen behaviours are reached by making a program
  unfindable** rather than by shaping a fixture. That is the only way to
  construct them, and it carries the risk named in the Edge Cases: the test must
  confirm it failed for the reason it names.
- **The fallback base-branch route cannot be reached by any existing test**,
  because every existing call site supplies a configured override. The helper
  must therefore support omitting it.
- **The probed script exits zero for every warning case.** Warnings are reported,
  not failures, so exit status carries no information in those tests.
- **The multi-line comment case is already covered.** Verified against the
  fixture and the existing test before writing this document, because the seed
  warns that a previous review got this wrong.
- **The fixtures directory is re-included wholesale by the tracked ignore
  rules**, so a new fixture is tracked without any further registration.
- **Both directories this feature touches are relaxed surfaces** for the
  vocabulary scans, so fixtures may carry terms the shipped surfaces ban.
- **No machine-specific absolute path may enter any file this feature writes.**
  The tracked-tree scan covers this feature's own documents.
