# Feature Specification: Pin the orchestrator's safety prose

**Feature Branch**: `011-pin-safety-prose`

**Created**: 2026-08-29

**Status**: Draft

**Input**: User description: "Pin the pipeline orchestrator's five unpinned safety-prose passages with grep-gate tests."

## User Scenarios & Testing *(mandatory)*

The actor throughout is a **maintainer of this repository** editing the
orchestrator's prose. The orchestrator, `pipeline/skills/pipeline/SKILL.md`,
is not code: it is the instruction document a model reads and obeys. Deleting
a sentence from it removes a behaviour as surely as deleting a function body,
and nothing in the tree notices. The regression suite
`pipeline/tests/prose.bats` is the only thing that notices, and today it does
not watch these five passages.

### User Story 1 - A dangerous deletion goes red (Priority: P1)

A maintainer reflows, trims or rewords the orchestrator and, in doing so,
removes one of five safety passages. The suite fails, names the passage, and
the maintainer sees what they took out before it ships.

**Why this priority**: This is the entire point of the feature. Every other
story is a quality constraint on how this one is delivered.

**Independent Test**: Invert any one of the five passages in the orchestrator
so it asserts the opposite of the safety rule, run the suite, and observe a
failure naming that passage. Restore the file and observe green.

**Acceptance Scenarios**:

1. **Given** the orchestrator's seed-form rule forbidding a fall-through from
   an unfetchable issue reference to a verbatim feature description, **When**
   it is rewritten to permit the fall-through, **Then** the suite fails and
   the message names the seed-form rule.
2. **Given** the failure-handling instruction "ROLL NOTHING BACK", **When** it
   is rewritten to instruct a rollback, **Then** the suite fails and the
   message names the roll-nothing-back rule.
3. **Given** phase J's duty to carry waved-through failures into the commit
   message and the pull-request body, **When** the duty is rewritten to permit
   silence, **Then** the suite fails and the message names the carry duty.
4. **Given** phase N's "DEGRADED, NEVER SKIPPED" rule, **When** it is
   rewritten to permit skipping N, **Then** the suite fails and the message
   names the N rule.
5. **Given** any one of the seven currently-unpinned red-flag table rows,
   **When** its reality column is rewritten to endorse the rationalisation it
   exists to refuse, **Then** the suite fails and the message names that row.

---

### User Story 2 - An innocent reflow stays green (Priority: P2)

A maintainer rewraps a paragraph of the orchestrator to a different column
width, or moves a sentence within its own section. Nothing about the meaning
changes. The five new pins stay green, so the maintainer gets no false alarm
and learns to trust a red.

**Why this priority**: A pin that reddens on formatting trains its readers to
ignore it. The existing file records this hazard about itself; this feature
must not add to it. Subordinate to Story 1 because a brittle pin still
protects the passage — it just costs more to live with.

**Independent Test**: Rewrap each of the four multi-line passages to a
different line width without changing a word, run the suite, and observe that
all five new tests stay green. The red-flag rows are not part of this test:
a table row is one line and cannot be rewrapped, which is why the
clarification above pins those rows whole.

**Acceptance Scenarios**:

1. **Given** a pinned passage spanning several lines, **When** its line breaks
   move but its words do not, **Then** the pin for that passage still passes.
2. **Given** a pinned passage, **When** a neighbouring unpinned sentence in
   the same section is reworded, **Then** the pin for that passage still
   passes.

---

### User Story 3 - A relocated passage does not satisfy its pin (Priority: P3)

A maintainer moves a safety passage out of the section that governs the
behaviour — into an appendix, a comment, or a block headed as illustrative —
while leaving the words somewhere in the file. The pin fails, because a rule
that is not where the model reads it is not in force.

**Why this priority**: The existing suite records a real instance of this:
a rule pasted verbatim into an appendix headed "not instructions" satisfied a
file-wide pin. The fix was to slice the region first. Lowest of the three
because it is a narrower attack than outright deletion.

**Independent Test**: Move a pinned passage from its governing section to the
end of the orchestrator, run the suite, and observe the pin fail.

**Acceptance Scenarios**:

1. **Given** a pinned passage inside a named section, **When** the passage is
   moved outside that section but left in the file, **Then** its pin fails.

---

### Edge Cases

- **A pinned region's boundary marker is itself reworded.** The section
  headings that bound each slice are part of what is pinned: a slice that
  silently collapses to nothing must fail loudly, not pass on an empty
  string. Every slice states the failure it is protecting against.
- **The red-flag table gains a ninth row.** Growth is allowed, but never
  silent. A new row that nobody pins is the same gap this feature exists to
  close, arriving one row later, so the suite must notice it: the pin checks
  both directions — every row it names is still in the table, and every row in
  the table is named by a pin. Adding a row and adding it to the pin list is a
  two-line change; adding a row alone goes red and says so.
- **A pinned clause's wording is correct but its subject is swapped.** The
  suite already records a mutant that kept a sentence's tail and changed its
  subject, staying green. Each new pin includes enough of its clause that the
  subject cannot be swapped underneath it.
- **The orchestrator is edited during verification.** Mutation testing
  requires temporarily inverting the orchestrator. The file must be proven
  byte-identical to its starting state afterwards, and the proof must be a
  comparison, not an assumption.

## Clarifications

### Session 2026-08-29

- Q: For the seven red-flag table rows, how much of each row should the test pin? → A: The whole row, verbatim.
- Q: The red-flag pin is one test covering seven rows. How many mutations should prove it works? → A: All seven rows, inverted one at a time.

Both answers are recorded in the requirements below. The reasoning behind
them is worth keeping, because each one costs something.

**Whole rows.** A red-flag row is one line, so the reflow tolerance Story 2
asks for does not apply to it — there is nothing to rewrap. What a
whole-row pin does cost is a red on an innocent typo fix. That is accepted:
the alternative leaves the "Thought" column mutable, and the Thought column
is the half a model matches its own rationalisation against. A pin that
watches only the refusal, and not the thought being refused, is watching the
less dangerous half.

**Seven mutations, not one.** One mutation proves the test can go red. It
cannot distinguish a test that checks seven rows from a test that checks one
and silently skips six — a dropped list entry, a typo, a loop that exits
early all read as green under a single inversion. Seven inversions cost
seven suite runs and are the only thing that proves the list is complete.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The regression suite MUST fail when the seed-form rule
  forbidding a fall-through from an unfetchable issue reference to a verbatim
  feature description is removed or inverted.
- **FR-002**: The regression suite MUST fail when the "ROLL NOTHING BACK"
  instruction in the failure-handling procedure is removed or inverted,
  including the reason it gives — that tidying up destroys the evidence the
  owner needs.
- **FR-003**: The regression suite MUST fail when phase J's duty to record
  waved-through failures and carry them into the commit message and the
  pull-request body is removed or inverted, including its redaction rule and
  its rule that a new set of failures is a new stop.
- **FR-004**: The regression suite MUST fail when phase N's "DEGRADED, NEVER
  SKIPPED" rule is removed or inverted, including the accompanying rule that
  a failure the owner accepted at J is not re-owned at N.
- **FR-005**: The regression suite MUST fail when any of the seven
  currently-unpinned red-flag table rows is altered in any way — removed,
  reworded in the column that states the rationalisation, reworded in the
  column that refuses it, or left intact with text appended after its final
  cell. Each of the seven rows is pinned as a whole line, character for
  character. A pin that merely requires the row to appear somewhere within a
  line is not sufficient: appended text is read inline by anything reading the
  document, and a within-line match does not see it.
- **FR-005a**: The regression suite MUST fail when a red-flag row is added to
  the table without being added to the pin. The pin therefore checks both
  directions: every row it names is present, and every row present is named.
- **FR-006**: Each new pin MUST anchor on the operative clause of its passage
  — the words that carry the obligation — rather than on a whole sentence
  reproduced verbatim. The red-flag rows are the stated exception and are
  pinned whole: a table row occupies a single line, so it cannot be reflowed,
  and the tolerance FR-006 buys elsewhere would buy nothing there while
  leaving half of each row free to change.
- **FR-007**: Each new pin MUST restrict its search to the region of the
  document that governs the behaviour, so that text relocated outside that
  region does not satisfy the pin. This binds all five, the red-flag rows
  included: pinning a row whole says how much of the row is checked, not where
  it is looked for, and a row pinned across the whole file is satisfied by a
  copy sitting in an appendix. The suite already records that exact escape
  succeeding against a file-wide pin.
- **FR-008**: Each region slice MUST fail loudly when its boundaries cannot be
  found, rather than passing on an empty result.
- **FR-009**: Each new pin MUST name the specific passage that failed, not
  merely report that the test failed. Where a pin checks several passages, the
  message MUST identify which one — a message that names the test rather than
  the passage sends the maintainer back to read the test to find out what they
  broke.
- **FR-010**: The five new pins MUST be added to the existing prose regression
  suite, and MUST NOT alter, convert or reword any pin already in it.
- **FR-011**: The orchestrator document MUST NOT be changed by this work. Any
  edit made to verify a pin MUST be reverted, and the file proven identical to
  its starting state.
- **FR-012**: The prose regression suite is the only shipped file this work
  changes. The specification artefacts this feature generates for itself are
  not shipped files and are committed alongside it, as every prior feature in
  this repository has done.
- **FR-013**: No changelog entry is produced for this work.

### Key Entities

- **The orchestrator** — `pipeline/skills/pipeline/SKILL.md`, the prose
  document under protection. Read by this work, never written by it.
- **The prose suite** — `pipeline/tests/prose.bats`, the regression gate. The
  only file this work changes.
- **A pin** — one test that asserts a named passage of the orchestrator is
  still present and still says what it said.
- **A region slice** — the bounded excerpt of the orchestrator a pin searches,
  named by the headings or sentences that open and close it.
- **The five passages** — the seed-form fall-through rule; the
  roll-nothing-back rule; phase J's carry duty; phase N's
  degraded-never-skipped rule; the seven unpinned red-flag rows.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The full suite, run from the repository root over all three test
  directories, reports exactly 159 tests, zero failures, and no output outside
  the reporting format — five more tests than the 154 it reports today.
- **SC-002**: All five new pins are demonstrated to fail when their passage is
  inverted. Inverting means rewriting the passage to assert the opposite of
  the safety rule; deleting the passage does not count as a demonstration.
- **SC-002a**: Every individual anchor is demonstrated, not every test. A test
  that checks five clauses is proven by five inversions, one per clause, with
  the other four left intact; the red-flag pin is proven by seven, one per
  row. This is the clarified answer applied consistently: a single inversion
  proves a test can go red, and cannot distinguish a test that checks five
  things from one that checks one and silently skips four. Twenty
  demonstrations in total — thirteen clause anchors across the four
  single-passage pins, plus seven rows. Read this number together with SC-002b
  and FR-005a, which each require one more: the whole verification runs
  twenty-two mutations. Twenty is the ANCHOR count, not the total, and the two
  are stated apart because a reader checking "were all mutations run" against a
  single figure will otherwise conclude one run is missing or one was extra.
- **SC-002b**: The row pins match whole lines, and this is demonstrated
  against an appending mutant specifically: a row left intact with extra text
  added after its final cell. Such a mutant is read inline by anything reading
  the document, and a substring match stays green on it. Every one of the
  seven row inversions is a rewrite, so the rewrites alone cannot expose this;
  it gets its own demonstration.
- **SC-003**: Before each inversion is trusted as a demonstration, the changed
  line is displayed, proving the edit landed. An edit that changed nothing
  cannot be counted.
- **SC-003a**: The five new pins are confirmed PASSING on the unmodified
  orchestrator before any inversion is attempted. Every demonstration below
  succeeds by observing a failure, and a pin that fails on an unmodified
  document fails under every inversion too — so the whole verification pass can
  be completed and reported as proven while measuring only a broken test. A
  check that cannot pass proves as little as one that cannot fail.
- **SC-004**: All five new pins pass again once the orchestrator is restored.
- **SC-005**: Every string pinned by the suite before this work is still
  present in the orchestrator, character for character.
- **SC-006**: The orchestrator is byte-identical to its pre-work state, proven
  by comparison, and the working tree shows no change to it.
- **SC-007**: Rewrapping any of the four multi-line pinned passages to a
  different line width, without changing a word, leaves its pin passing. The
  red-flag rows are excluded by construction, not by exemption: a table row is
  a single line and has no line width to change.

## Assumptions

- The red-flag table has eight rows and exactly one of them is pinned today,
  so seven are unpinned. An earlier review said six; seven is the measured
  count and is what this feature delivers.
- The existing suite's whole-sentence pins are deliberate and remain as they
  are. Converting them is separate work and is out of scope here.
- The suite's existing idiom for bounded pins — slice the region, collapse it
  to a single line, search for the clause — is the right shape for this work,
  because it is the shape the file already uses for its most attack-resistant
  pins.
- The suite is run with the same harness and from the same working directory
  as every other run in this campaign; a pin that passes elsewhere and fails
  from the repository root has not passed.
- Line numbers cited in the source request are a convenience for locating the
  passages and are not part of any requirement; pins anchor on text, never on
  a line number.
- Both directories this work touches — the orchestrator's and the suite's —
  are RELAXED surfaces under this campaign's conventions, so no additional
  review ceremony attaches to editing the suite beyond what is specified here.
  That relaxation does not weaken FR-011: the orchestrator is unedited because
  this feature says so, not because the surface is strict.
- FR-006 constrains how a pin is written rather than what it does at runtime,
  so it is judged by review rather than by a test. What is testable about it
  is its consequence, and that is SC-007: a pin anchored on a clause survives
  a reflow, and a pin anchored on a reproduced sentence does not.
