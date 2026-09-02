# Feature Specification: The guard stops counting jq, part two

**Feature Branch**: `015-guard-jq-spawn-two`

**Created**: 2026-09-02

**Status**: Draft

**Input**: User description: "Phase 17 — the guard stops counting jq, part two. Reduce process spawns in `handoff/hooks/context-guard.sh` without changing any behaviour. F7: stop the `cat` + `printf` two-process detour on stdin by letting the JSON parser read stdin directly (this saves no parser call — it removes two other processes). F8: collapse the transcript reading from three parser calls plus a line count into one parser call (two on the starved fallback path). The fallback arithmetic — the floor of fifteen, the median of the last fifteen, and the uncapped re-read — may not change. Comments must be carried, not compressed; `handoff/hooks/` is a STRICT-vocabulary surface."

## Clarifications

### Session 2026-09-02

- Q: The old reading count only counts lines that begin with a digit, so a negative reading is skipped by the count but still used in the median. Should the new single-pass count copy that quirk exactly? → A: Yes — copy it exactly. The fallback decision must be provably identical on every possible input, including one that cannot occur in practice. The extra clause and its comment are the price of that proof.
- Q: When the parser is unavailable the guard exits early, and today it has already consumed stdin. If the parser reads stdin directly, that path consumes nothing. How should that be closed? → A: Consume stdin inside the parser-unavailable branch only. The hazard is closed by construction rather than by a measurement of what the caller tolerates. One extra process is spent on the rare disabled path; the ordinary path still loses both.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — the transcript is read once, not three times (Priority: P1)

The context guard runs after every single tool call. On the path it takes
almost every time — the non-firing path — it currently starts three separate
JSON-parser processes and one line-counting process to answer two questions
about the transcript: how many usage readings are in it, and what the median of
the last fifteen is. Both answers come from the same list of numbers. One
parser pass can produce both.

**Why this priority**: This is the only requirement that removes a parser
process, and the parser is the most expensive process the guard starts. On
Windows under Git Bash — a supported platform — process spawn dominates the
guard's cost, and the guard's cost is paid on every tool call in every session.

**Independent Test**: Count the processes the guard starts over a fixed
transcript, before and after, with the process-counting rig committed for that
purpose. The count must drop by one parser process and one line-counter
process, on both the ordinary path and the starved fallback path.

**Acceptance Scenarios**:

1. **Given** a transcript holding twenty readings and no configuration file,
   **When** the guard runs and does not fire, **Then** it starts three parser
   processes where it previously started four, and no line-counting process.
2. **Given** a transcript whose capped read yields fewer than fifteen readings,
   **When** the guard runs, **Then** it re-reads the transcript uncapped exactly
   as before, starts four parser processes where it previously started five, and
   reports the same percentage.
3. **Given** any transcript, **When** the guard runs before and after the
   change with identical inputs, **Then** stdout and exit status are
   byte-identical.

---

### User Story 2 — stdin reaches the parser without a two-process detour (Priority: P2)

The guard reads its whole stdin payload into a shell variable, then writes that
variable back out to the parser through a pipe. The value has exactly one
consumer. Reading it into a variable and writing it out again costs two
processes and buys nothing.

**Why this priority**: It removes two processes from every run, but no parser
process. It ranks below Story 1 because the saving is smaller and because it
touches the one part of the guard where a mistake makes the guard silent rather
than wrong. It is separable: if it cannot be shown safe, Story 1 ships alone.

**Independent Test**: Count the processes the guard starts, before and after.
Separately, confirm that the caller's write to the guard's stdin still
completes with a success status on every path the guard can take, including the
path where the parser is unavailable and the guard exits early.

**Acceptance Scenarios**:

1. **Given** an ordinary payload on stdin, **When** the guard runs, **Then** it
   starts no process to copy stdin into a variable and no subprocess to write
   that variable back out, and produces the same output as before.
2. **Given** the JSON parser is unavailable, **When** the guard runs, **Then**
   the guard still consumes its whole stdin before exiting, and the process
   writing that stdin sees a successful write — no broken-pipe failure.
3. **Given** a payload larger than the operating system's pipe buffer, **When**
   the guard runs on any path, **Then** the writing process completes with
   status zero.

---

### User Story 3 — the record survives the refactor (Priority: P3)

The code being moved is surrounded by comments that name dated production
incidents and explain why each piece of arithmetic is the shape it is. A
refactor that leaves the code correct and the explanation gone has removed the
only thing that stops the next person reintroducing the incident.

**Why this priority**: It changes no behaviour, so it ships last in importance;
but a violation is not repairable later, because what is lost is knowledge
nobody will know to look for.

**Independent Test**: Read the incident dates, the named failure modes and the
load-bearing statements present in the file before the change, and confirm each
is still present after it.

**Acceptance Scenarios**:

1. **Given** the file before the change, **When** each dated incident reference
   and each stated reason for the fallback arithmetic is listed, **Then** every
   listed item is present in the file after the change.
2. **Given** the changed file, **When** it is checked against the repository's
   restricted-vocabulary rules for this directory, **Then** it passes.

---

### Edge Cases

- **A transcript with no readings at all.** The guard must stay silent, exactly
  as before, and must not report a percentage.
- **A transcript with exactly fourteen, exactly fifteen, and exactly sixteen
  readings.** Fourteen and sixteen sit either side of the fallback floor. The
  fallback must be taken on fourteen and not on fifteen or sixteen, unchanged.
- **A line in the transcript that is not valid JSON.** It is skipped, and every
  valid line around it is still counted. It must not abort the whole read.
- **A line that is valid JSON but whose reading value is not a number.** Today
  the parser reports an error for that one line and carries on with the next.
  After the change the same line must still be skipped and the surrounding
  lines still counted — a single bad line must never empty the whole result.
- **A reading value that is negative.** The old count does NOT count it — the
  count only counts entries whose text begins with a digit — while the median
  still includes it. The new single-pass count MUST reproduce that exactly, so
  the fallback decision is identical on every possible input. A negative token
  total cannot occur in practice; the case is pinned anyway, because "cannot
  occur" is an assertion and this change is required to rest on proof.
- **Sidechain entries.** They are excluded today and must stay excluded.
- **The parser is not installed.** The guard prints its one-time hint and exits
  quietly. Stdin must still be consumed on this path.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The guard MUST produce byte-identical output and an identical
  exit status, for every payload shape, configuration shape and transcript
  shape, before and after this change.
  **ONE MEASURED EXCEPTION, which cannot be closed without reintroducing a
  defect.** On a usage record whose three token fields are ALL strings, the old
  code concatenated them into a string reading, its separate median call then
  failed to parse that reading, and the whole read collapsed: the guard said
  NOTHING. The new code drops the junk and answers from the readings around it.
  Measured: 0 bytes against 556. The divergence is in the fail-loud direction
  and it repairs a silence; the only route back to byte-identical output here
  is back to that silence. The comparison harness now carries the shape and
  ASSERTS the difference, so a later change that quietly removes it goes red.
- **FR-002**: The guard MUST obtain the reading count and the median from a
  single parser pass over the capped transcript read, replacing the separate
  count pass, the separate median pass and the separate line-counting process.
- **FR-003**: The fallback MUST remain: when the capped read yields fewer than
  fifteen readings, the transcript is re-read without the byte cap, and the
  answer comes from that re-read. The floor value of fifteen MUST NOT change.
- **FR-004**: The median MUST remain the median of the last fifteen readings,
  taken by sorting them and selecting the element at the middle index rounded
  down, with zero as the value when there are no readings.
- **FR-005**: The starved path MUST spend exactly one additional parser process
  over the ordinary path — no more than one conditional second call.
- **FR-006**: A malformed or non-numeric transcript line MUST NOT prevent the
  readings around it from being counted.
- **FR-007**: The guard MUST let the parser read stdin directly, without first
  copying it into a shell variable and writing it back out.
- **FR-008**: On the path where the parser is unavailable, the guard MUST
  consume its whole stdin before exiting, so the caller's write always
  completes. This MUST be done by consuming stdin inside that branch, not by
  relying on the caller tolerating an unread pipe: the hazard is closed by
  construction. The one process this costs is spent only on the disabled path.
  **No automated test covers this, and saying so is part of meeting it.** The
  comparison harness always has a working parser, so it never enters the
  branch; the suite's parser-unavailable test feeds standard input from a
  here-string, which is a temporary file rather than a pipe and so can never
  see a broken one. The evidence is a direct measurement, repeated in the
  quickstart: writer exit 0 with the consume step, 141 with it deleted, 0 on
  the baseline. The test that would close the gap pipes a payload larger than a
  pipe buffer into the guard and asserts the writer's own exit status.
- **FR-016**: The new single-pass reading count MUST count exactly the entries
  the old count counted — those whose text representation begins with a digit —
  so that a negative reading is excluded from the count and included in the
  median, as it is today.
  **The comparison harness cannot verify this, and the requirement claimed it
  could.** The count decides only whether the uncapped re-read RUNS; it never
  decides the answer, because the capped read is a byte suffix and its last
  fifteen readings are the file's last fifteen whenever it holds fifteen at
  all. Mutating the rule to a plain count reports every shape identical.
  Verified instead by process count, on a straddle of fourteen positive
  readings and one negative — fifteen under a plain count, fourteen under this
  rule: the shipped guard spends five parser processes and the mutant spends
  four, while both emit an identical 556 bytes. The negative-reading shape is
  still carried; it shows the median tolerates such a reading, which is all it
  ever showed.
- **FR-009**: The single string that defines the transcript-reading program
  MUST remain defined once and used by both the capped and the uncapped call,
  so the two cannot drift apart.
- **FR-010**: Every dated incident reference, every named failure mode and
  every "this is load-bearing" statement present in the file before the change
  MUST be present after it. Comments MAY move; they MUST NOT be compressed,
  summarised or deleted.
- **FR-011**: The existing test file for the guard MUST NOT be edited. This
  change adds no tests and must break none.
  *Overridden by the owner on 2026-09-02, and the requirement is left standing
  rather than rewritten, because a requirement quietly reworded to match what
  happened records nothing.* One test could not be satisfied: it required the
  median program to appear as a SEPARATE parser call in both the guard and the
  setup skill, which is a fact about how many processes the guard starts and
  not about which reading it believes — and removing that separate call is
  precisely this feature. The owner chose to bring the setup skill to the same
  one-pass form and then update the test's two extraction anchors. Both
  programs are now named variables in both files, matched by one anchor each.
  The test count is unchanged at 163. All seven duplicated sites were mutated
  one at a time and all seven were caught, with both files verified restored by
  hash afterwards.

  **The first version of this change DID weaken the test, and review caught
  it.** Recorded because the mistake is more instructive than the fix. The
  skill's old anchors WERE its call sites, so there was no declaration to drift
  from a use. Once both anchors moved to a variable name, a skill whose two
  declarations matched the guard byte for byte could invoke something else
  entirely and the test stayed green — measured, on a skill rewritten to take a
  five-wide window while still claiming to measure the guard's way. A fourth
  part now pins the skill's invocation to the two programs it declares, and the
  same mutation goes red. Moving an anchor from a use to a declaration silently
  drops the coupling between them: that is the general lesson, and it cost
  nothing to learn only because someone re-derived the reach rather than
  trusting a mutation count.
- **FR-012**: The process-count reduction MUST be measured, on both transcript
  shapes and for zero, one and two configuration files present, and both
  columns of measured numbers recorded in the commit message.
- **FR-017**: The change record MUST be an entry under the existing
  "Unreleased" heading of the handoff plugin's own change log, in its "Changed"
  subsection, naming the reduction.
- **FR-013**: Identical behaviour MUST be established by running the old and
  new guard side by side over a set of shapes and comparing their output, not
  by assertion. The comparison set MUST be extended to cover the transcript
  shapes this change touches.
- **FR-014**: The change record MUST state what was measured rather than assert
  that behaviour is unchanged.
- **FR-015**: If FR-007 and FR-008 cannot be shown safe, that half MUST be
  dropped and the reason recorded; the transcript half MUST still ship.
  *Resolved before implementation*: the hazard was measured — a reader that does
  not read leaves the writer at exit 141 — and closed by construction rather
  than by argument. Both halves ship. The contingency is retained as written
  because a later reader needs to know it existed and how it was discharged.

### Key Entities

- **Payload**: the JSON object the caller writes to the guard's stdin. Carries
  the agent identifier, the transcript path, the session identifier and the
  working directory.
- **Transcript**: a file of JSON lines. Each line may carry a usage record; the
  guard reads a token total from each such line, skipping sidechain entries.
- **Reading**: one token total taken from one transcript line.
- **Capped read**: the tail of the transcript, bounded by a byte cap and a line
  cap. An optimisation that may never change the answer.
- **Fallback**: the uncapped re-read, taken when the capped read yields fewer
  than fifteen readings.
- **Restricted-vocabulary surface**: a directory whose files are held to a
  fixed set of allowed words and phrasings, enforced by the test suite. The
  guard's directory is one. It is why a comment cannot be reworded freely, and
  why "tidying" prose here is a change that must pass a check, not a style
  preference.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the ordinary transcript shape, the guard's parser process
  count per non-firing run falls from four, five and six — for zero, one and
  two configuration files — to three, four and five.
- **SC-002**: On the fallback transcript shape, the same count falls from five,
  six and seven to four, five and six.
- **SC-003**: The line-counting process count per run falls from one to zero.
  The process that copies standard input falls from one to zero. Both are
  measured rather than inferred. Stated the way the counting rig reports it, so
  the two numbers cannot be read as a contradiction: the rig counts every
  process of the copying kind, and that total falls from **two to one** — the
  second is the one that reads the warning flag further down the hook, which
  this change does not touch and does not claim to.
- **SC-004**: The full test suite, run from the repository root, reports the
  same one hundred and sixty-three tests, zero failures and zero unparsed
  lines, both before and after the change.
- **SC-005**: The guard's own test file shows an empty difference against the
  pinned baseline commit. **NOT MET, by the owner's decision recorded at
  FR-011.** Measured: 35 insertions and 3 deletions against `168edc1`, all of
  them in the two extraction anchors of one test and the comments explaining
  why they moved. The criterion is reported as unmet rather than restated to
  fit, so a later reader sees the exception instead of inheriting a clean
  sheet that was never earned.
- **SC-006**: The side-by-side comparison reports zero differing shapes across
  the full extended set — which includes a negative-reading shape and the
  fourteen, fifteen and sixteen reading shapes either side of the fallback
  floor — and the comparison harness is shown capable of reporting a difference
  by running it against a deliberately altered guard first.
- **SC-007**: Every incident date and named failure mode present in the file
  before the change is present after it.

## Assumptions

- The measured baseline is the one recorded on 2026-09-01 at commit `168edc1`:
  four, five and six parser processes on the ordinary shape and five, six and
  seven on the fallback shape, per non-firing run, for zero, one and two
  configuration files.
- The baseline for every difference check is pinned to that commit identifier
  rather than to a branch name, because this repository rebase-merges and a
  branch name stops being a baseline the moment the work lands.
- The side-by-side comparison harness and the process-counting rig already
  exist in the repository and are used as they are, extended only with the new
  transcript shapes.
- A fourth file is changed, which the requirements above did not anticipate:
  `handoff/skills/setup/SKILL.md`. It carries the same reading rule as the
  guard so the window it proposes is derived the guard's way, and the suite
  pins the two character for character — so it could not stay behind while
  the guard moved. It gains the same one-pass form and the same two named
  programs, and its reading was verified identical to the old two-call form
  across thirteen transcript shapes.
- The comparison harness must isolate the home directory and all three
  temporary-directory settings separately for each side of each shape, or it
  reports false differences.
- The process-counting rig's shim directory must contain no drive letter, or
  the shim is never found and the count reads zero — indistinguishable from a
  real reduction to zero.
- No project constitution exists, so planning runs against an empty governance
  document. The owner declined to write one for this change.
- The change is released as part of the handoff plugin's next patch release;
  it therefore lands before that release is cut.
- The change record's destination is fixed by FR-017 rather than left to
  judgement, because the plugin's change log is the file a release reads.
