# Feature Specification: progress.sh coverage and a timeout for every suite

**Feature Branch**: `008-progress-coverage-timeout`

**Created**: 2026-08-27

**Status**: Draft

**Input**: Campaign 2, Phase 8 of `main-plan.md` — "progress.sh coverage and a
timeout for every suite". Quoted verbatim into the run directory as `seed.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A hung test is named, not left to burn the job (Priority: P1)

A maintainer changes something that makes one test hang — a loop with no exit,
a command that waits on input that never arrives, a lock that is never released.
Today, five of the six suites have no per-test limit, so that single test runs
until the whole build is killed by the platform's job cap. The maintainer sees
a build that was cancelled after hours with no indication which test was at
fault.

After this feature, every suite carries a per-test limit. The hang stops in
seconds, the suite names the test that exceeded it, and the maintainer knows
where to look.

**Why this priority**: it is the only requirement here that protects the build
itself. The coverage work below improves confidence in a script; this one
prevents a whole class of build outcome that gives no information at all. One
suite already carries this protection and documents why; the other five simply
never got it.

**Independent Test**: set the limit deliberately low, plant a sleep in a test in
each suite, and confirm each suite reports that test as timed out by name.
Delivers value on its own: the coverage work need not exist for the limit to
protect the build.

**Acceptance Scenarios**:

1. **Given** a test that would run forever, **When** any of the six suites runs
   it, **Then** the run ends within the configured limit and the output names
   the test that exceeded it.
2. **Given** the existing suite as it stands today, **When** it runs on the
   slowest machine available, **Then** no test is stopped by the limit — the
   limit exceeds the slowest real test with margin that is stated, not assumed.
3. **Given** the limit, **When** a reader asks which file sets it, **Then**
   exactly one file assigns it and no second assignment can silently win or
   lose depending on load order.

---

### User Story 2 - The state-reading contract two shipped surfaces rest on is proven (Priority: P2)

Two shipped documents instruct their reader to obtain a run's state through one
specific command rather than by reading the file directly, and one of them warns
about a platform-specific hazard in that command's output. Nothing tests either
claim. A change to the command that broke the promise — extra text on the output
stream, a validation message printed where the data belongs — would ship green.

After this feature, both halves of that promise are tested: the output is data
and nothing but data, and the documented hazard behaves exactly as documented,
including that the documented workaround works.

**Why this priority**: it is a contract two shipped surfaces already depend on
in production, and it currently has zero coverage. It ranks below the timeout
only because a broken contract is a wrong answer, while a hung suite is no
answer at all.

**Independent Test**: run the command against a valid run and confirm its output
is accepted whole by a strict parser; construct the hazard deliberately and
confirm the documented workaround survives it while the documented trap does
not.

**Acceptance Scenarios**:

1. **Given** a valid run state, **When** the state-reading command runs,
   **Then** everything it puts on the data stream is accepted whole by a strict
   parser, with nothing else mixed in.
2. **Given** a state file whose lines end in the two-character sequence this
   platform sometimes produces, **When** the state-reading command runs,
   **Then** a strict parser still accepts the output, and the specific
   line-reading idiom the shipped document forbids is shown to retain the stray
   character.
3. **Given** a run whose state file is invalid, **When** the state-reading
   command runs, **Then** the fault is reported on the diagnostic stream and
   the data stream stays empty — a caller parsing the data stream sees nothing
   rather than a half-message.

---

### User Story 3 - Every refusal the state script can make is proven to name its cause (Priority: P2)

The state script refuses in many distinct situations, each with its own message
naming what was wrong. Only a small number of those refusals are exercised. The
rest could regress into a bare non-zero exit, or into a message naming the wrong
thing, and every suite would stay green. The people who meet these messages are
meeting them at the worst moment — something is already broken — so a message
that does not name the fault costs real time.

After this feature, each named refusal has its own test asserting the message
identifies the thing that was wrong.

**Why this priority**: equal in value to Story 2 and independent of it. Either
can ship without the other.

**Independent Test**: drive the script into each refusal in turn and assert both
the non-zero result and the presence of the naming in the message.

**Acceptance Scenarios**:

1. **Given** each of the nine currently-unreached refusal situations, **When**
   the script is driven into it, **Then** it exits non-zero and its message
   names the specific thing that was wrong.
2. **Given** any one of those nine tests, **When** the message it asserts is
   changed to name something else, **Then** that test goes red — the assertion
   is on the naming, not merely on the exit status.

---

### User Story 4 - The private-vocabulary test exercises the real folding (Priority: P3)

The suite supports an optional, untracked file of additional forbidden terms,
folded into the shipped list at load time. Because that file is private by
definition, nothing in a public build ever exercises the folding. A test exists
that claims to cover it — but it rebuilds the folding logic inside itself and
checks its own copy. A defect introduced in the real folding is therefore not
caught by the test whose name says it is covered.

After this feature, that test drives the real folding. Breaking the real folding
turns the test red.

**Why this priority**: the defect is a false sense of coverage rather than a
live failure, and the shipped list still works either way. It ranks last, but it
is the same class of fault the previous phase was created to close, so it is not
deferred.

**Independent Test**: introduce a defect into the real folding and confirm the
reworked test reddens; the old test would not have.

**Acceptance Scenarios**:

1. **Given** the reworked test, **When** the real folding logic is broken,
   **Then** the test goes red.
2. **Given** the reworked test, **When** the suite runs normally with no private
   file present, **Then** it passes, and the number of tests in the suite is the
   same as before this change.
3. **Given** a private file containing a blank line, **When** the real folding
   runs, **Then** no empty alternative is produced — the behaviour the existing
   comment says is load-bearing is still proven.

---

### Edge Cases

- **The limit and the slowest real test.** The slowest test measured on the
  slowest environment available takes just under eight seconds. The one suite
  that already sets a limit sets it at ten seconds. Applying ten seconds to all
  six suites would leave under two seconds of margin on the slowest test, on the
  slowest machine measured — a machine that is *slower than* the slowest
  continuous-integration runner. The limit must be chosen from the measurement,
  not inherited from the existing value.
- **Two assignments, one winner.** The suite that already sets a limit sets it
  *before* it loads the shared file. If the shared file also sets it, the shared
  file's value wins there — silently. Leaving both in place creates a line that
  reads like the owner and is not. Exactly one assignment must survive.
- **A refusal that names nothing.** A test asserting only a non-zero exit passes
  even if the message is emptied. Each refusal test must assert the naming.
- **The private-vocabulary file is absent in every public run.** The reworked
  test must not require that file to exist at the repository root, and must not
  create one there — the real folding has to be reachable with a fixture instead.
- **An invalid state file on the read path.** The read path validates first.
  The fault must reach the diagnostic stream only; a caller parsing the data
  stream must see nothing rather than a partial message.
- **Line-ending hazard is platform-conditional.** The hazard the shipped
  document warns about does not occur on every machine. The test must construct
  the condition deliberately rather than wait for a machine that exhibits it,
  or it silently tests nothing on most machines.

## Requirements *(mandatory)*

### Functional Requirements

**The per-test limit**

- **FR-001**: The shared fixture file loaded by all six suites MUST set a
  per-test time limit, so that every suite carries one.
- **FR-002**: The limit's value MUST exceed the slowest existing test, measured
  rather than assumed, on the slowest environment available; the measurement and
  the resulting margin MUST be recorded in the feature's own documents.
- **FR-003**: Exactly one assignment of the limit MUST remain in the repository.
  The existing per-suite assignment MUST be removed, because it is evaluated
  before the shared file is loaded and would therefore be overridden without any
  visible sign.
- **FR-004**: The reason the removed assignment existed — that a regression
  reintroducing an unbounded walk should get a named timeout rather than the
  platform's job cap — MUST survive the removal, carried in the surviving
  assignment's own comment. Removing a guard's stated reason along with its
  duplicate assignment loses the only record of why it is there.
- **FR-005**: The change MUST take effect in all six suites, and that MUST be
  demonstrated rather than asserted.

**The state-reading contract**

- **FR-006**: A test MUST prove that the state-reading command's data stream is
  accepted whole by a strict parser, with nothing else present on it.
- **FR-007**: A test MUST prove the documented line-ending contract: that a
  strict parser still accepts the output when the state file carries the
  two-character line ending, and that the line-reading idiom the shipped
  document forbids does retain the stray character. The condition MUST be
  constructed by the test, never waited for.
- **FR-008**: Both tests MUST be appended to the existing state-script suite.
  Existing tests in that file MUST NOT be restructured.

**The refusal paths**

- **FR-009**: Nine tests MUST be added, one for each of these currently
  unreached refusals: completing a phase that is not a known phase; the
  artefact rule for the phase requiring the plan artefact; the artefact rule for
  the group of phases requiring the tasks artefact; the final refusal when no
  rule admits the requested phase; taking the lock with no session identifier;
  losing the lock creation race; the bare usage refusal; the refusal for a
  completed-phases value that is not a list; and the refusal for a recorded
  current phase the script does not know.
- **FR-010**: Each of the nine MUST assert that the message names the thing that
  was wrong, not merely that the command failed.
- **FR-011**: The one refusal branch already covered MUST NOT be duplicated or
  rewritten.
- **FR-012**: All nine MUST be appended to the same existing suite, which MUST
  NOT be restructured.

**The private-vocabulary folding**

- **FR-013**: The test that claims to cover the private-vocabulary folding MUST
  exercise the repository's real folding logic rather than a copy of it
  rebuilt inside the test.
- **FR-014**: Breaking the real folding logic MUST turn that test red. This MUST
  be demonstrated, not argued.
- **FR-015**: The three behaviours the existing test already checks — the extra
  term matches, a blank line produces no empty alternative, and the shipped
  terms still match alongside it — MUST all still be checked.
- **FR-016**: The number of tests in that suite MUST be unchanged by this work.
- **FR-017**: The reworked test MUST NOT require or create a private-vocabulary
  file at the repository root. The real folding MUST become a named function,
  defined in the same suite file that holds the vocabulary list. Load time calls
  it with the repository's own path; the test calls it with a fixture path. Both
  callers therefore run one copy of the logic, which is what makes breaking that
  copy visible. (Resolved at clarify, 2026-08-27 — see Clarifications.)
- **FR-018**: That function MUST preserve today's behaviour exactly. In
  particular, when the private list contributes nothing — absent file, empty
  file, or a file of only blank lines — the shipped list MUST come back
  unchanged, not with a trailing separator and not with an empty alternative.
- **FR-019**: The function MUST NOT be placed in the shared fixture file. Only
  one of the six suites folds a private vocabulary, and that shared file is
  already being changed by this feature for the per-test limit. Putting two
  unrelated concerns in one file is the coupling this decision exists to avoid.

**Scope discipline**

- **FR-020**: No changelog entry is written by this feature. The change is
  test-and-tooling only, and the campaign's routing ruling assigns it none.
- **FR-021**: No shipped behaviour changes. The state script, the hook and the
  pre-flight script are read by the new tests and MUST NOT be modified by them.
  Every file this feature edits lives under a test tree; the folding function
  required above is a test-file change, so it forces no exception.
- **FR-022**: The line references carried in the seed MUST be treated as stale
  and re-derived from content. The previous phase added a large block to one of
  the two files named, so at least one of the seed's references no longer points
  at what it names. Locating by content, not by number, is required.
- **FR-023**: The commit message MUST state which of the two limit assignments
  survived and why. The seed leaves that choice open and asks for it to be
  stated; a reader who later finds one assignment where there were two must be
  able to learn from the history that the removal was deliberate and measured,
  not accidental.
- **FR-024**: "Append, do not restructure" binds every existing test EXCEPT the
  private-vocabulary test, which the seed separately and explicitly requires to
  be reworked. The two instructions are not in conflict once that exception is
  named, and naming it here is what stops a later reader from reading the
  rework as a violation. The exception is narrow: one test, and only the part of
  it that rebuilds logic it should be calling. Its three existing assertions
  survive (FR-015) and the suite's test count does not move (FR-016).

### Key Entities

- **The six suites**: two at the repository root and four under the two plugins.
  All six load one shared fixture file, by two different relative spellings.
- **The shared fixture file**: the single file every suite loads. It is where a
  setting that must reach all six belongs.
- **The state script**: the tool the pipeline uses as its memory. It reads,
  validates, records phases, and holds a lock. It refuses loudly, by design,
  with a message naming the fault.
- **A refusal**: a non-zero exit accompanied by a message that names what was
  wrong. The naming is the property under test; the exit status alone is not.
- **The private vocabulary**: an optional, untracked list of extra forbidden
  terms, folded into the shipped list when present. Private by definition, so
  never exercised by a public build unless a test does so deliberately.
- **The real folding**: the repository's own logic that strips blank lines from
  the private list and joins the rest into the scan's alternation. The thing the
  reworked test must drive.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The full house suite, run from the repository root, reports
  `1..134` with zero failures and zero non-conforming output lines. The
  starting point is `1..123`; the increase is exactly the eleven new tests.
- **SC-002**: Each of the eleven new tests is observed failing before its
  subject is in place, by inverting its assertion or breaking the clause it
  rests on — never by deleting the test. The altered line is echoed back before
  the failure is believed.
- **SC-003**: The reworked private-vocabulary test is observed failing when the
  real folding logic is broken, and passing when it is restored.
- **SC-004**: The per-test limit is in effect in all six suites, shown two ways:
  every suite is confirmed to load the file that sets it, and at least one suite
  is observed actually stopping a deliberately over-long test and naming it. The
  seed asks for the second; the first is what makes the claim "all six" rather
  than "the one we watched".
- **SC-005**: With the limit in place, the existing suite still reports every
  test passing on the slowest environment measured — no test is stopped by the
  limit.
- **SC-006**: Exactly one assignment of the limit exists in the repository, and
  a search for the setting's name returns that one site plus documentation.
- **SC-007**: The number of tests in the suite holding the private-vocabulary
  test is the same before and after this work.
- **SC-008**: No changelog file is modified.
- **SC-009**: The state script, the hook and the pre-flight script are unchanged.
  Every file this feature touches is under a test tree; a diff confined to those
  trees is the proof.
- **SC-010**: The nine refusal tests each go red when the naming they assert is
  changed to name something else — proving they test the message, not the exit.
- **SC-011**: Every ad-hoc verification search used during this work fires a
  control that must match before any zero is believed.
- **SC-012**: The commit message names which limit assignment survived and why,
  readable from the history without consulting this specification.

## Assumptions

- **The slowest environment is the local development machine, not a
  continuous-integration runner.** Measured 2026-08-27: the full suite takes
  224.6 seconds locally across 123 tests, against 155 seconds on the slowest
  hosted runner and 17 seconds on the fastest. A limit chosen against the local
  measurement is therefore conservative for every hosted runner.
- **The slowest single test measured 7916 milliseconds**, locally. Any limit
  chosen must exceed this with stated margin. The existing ten-second value does
  not provide meaningful margin and is not carried forward by default.
- **Removing the existing per-suite assignment is the correct resolution of the
  seed's open choice**, because that assignment is evaluated before the shared
  file loads and the shared file would override it. This is a measurement, not a
  preference. Its stated reason is preserved per FR-004.
- **The seed's line references are stale.** The previous phase added 266 lines
  to one of the two files the seed cites, moving the cited test far from the
  number given. The folding logic itself is still close to where the seed says.
  Content, not line numbers, locates both.
- **The state script's read path is a validate followed by a copy of the file to
  the data stream.** Its output is therefore whatever the file holds; the tests
  can construct the line-ending condition by writing the file.
- **The nine refusal situations named in the seed all exist in the script
  today** and were confirmed present before this specification was written.
- **`.leakwords` is absent from this repository**, as it is untracked by design,
  so the folding is currently unexercised in every public run.
- **Test files under both test trees are relaxed surfaces** for the vocabulary
  scans, so the new tests may name terms the shipped surfaces ban.
- **No machine-specific absolute path may enter any file this feature writes.**
  The tracked-tree scan added by the previous phase covers this feature's own
  documents.

## Clarifications

### Session 2026-08-27

**Q1: Where should the real folding live, so that a test can drive it?**

FR-013 requires the private-vocabulary test to exercise the real folding rather
than a copy of it. The folding currently runs once at suite load time, against a
fixed path at the repository root, as a few inline lines. A test cannot call it,
because it is not a callable thing.

**Answer: a named function inside the same suite file** that holds the vocabulary
list. The load-time site calls it with the repository's own path; the test calls
it with a fixture path. Recorded as FR-017, FR-018 and FR-019.

**Why, in the owner's words and the measurements behind them:**

- It is the smallest change that satisfies FR-013. The logic ends up in exactly
  one place, immediately beside the list it extends, with both callers visible
  in the same file.
- The rejected alternative of moving it to the shared fixture file was declined
  because only one of the six suites folds a private vocabulary — the other five
  would gain a function they never call — and because that shared file is
  already being edited by this same feature for the per-test limit. Two
  unrelated concerns arriving in one file in one commit is a coupling worth
  avoiding, and FR-019 now forbids it explicitly so a later reader does not
  "tidy" the function into the shared file.
- The rejected alternative of running the suite in a child process against a
  planted private file was declined because it would require writing that file
  into a live checkout — which the Edge Cases forbid — or copying the whole tree,
  which tests a copy and is slow enough to invite flakiness.

**Consequence for scope**: every file this feature edits is under a test tree.
FR-021 and SC-009 were tightened accordingly — no shipped script needs an
exception, and a diff confined to the test trees is the proof.
