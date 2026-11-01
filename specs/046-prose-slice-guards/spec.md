# Feature Specification: Every prose slice is guarded, and the slice helper's guards are tested

**Feature Branch**: `046-prose-slice-guards`

**Created**: 2026-11-01

**Status**: Draft

**Input**: GitHub issue #31, "prose.bats: three existing slices have no boundary guards, and the helper's own guards are untested". Seed text kept verbatim in the run directory as `seed.md`.

## Context: what the issue said, and what the file holds now

Issue #31 was written on 2026-08-29 against a smaller `pipeline/tests/prose.bats`.
The file has grown since. Measured on 2026-11-01 at `f72276c`:

- The issue names **three** slice sites with no boundary guard. All three are
  still unguarded. The same file now holds **13** bare `awk '/open/,/close/'`
  range slices outside the `prose_slice` helper, over two documents (the
  orchestrator skill and `pipeline/docs/configuration.md`). Some carry a
  hand-written close check; most carry none.
- The issue names **seven** copies of the flatten idiom (join lines with a
  space, squeeze runs of spaces). The file now holds **55** lines of it: one
  inside `prose_slice` and **54** outside it (one of those split across two
  lines).
- `prose_slice` still reads only the orchestrator (`$ORCH`), so it cannot
  serve a slice of any other document.
- The pre-flight walk slice holds a bold-led line (`**Read item 11 before item
  1.**`) that `prose_slice`'s inner-heading guard refuses. That is why four
  sites keep a bare range with a hand-written close check.
- None of `prose_slice`'s guards has a committed test that makes it fire.

These figures are a record of one count, not a claim about the file in future.
The count is made with `grep -nE "awk '/[^']*/,/" pipeline/tests/prose.bats`
and `grep -c "tr '\\\\n' ' '" pipeline/tests/prose.bats`.

## Clarifications

### Session 2026-11-01

- Q: How much of prose.bats should this change fix — all 13 slices and 54 flatten copies, the slices plus only touched flatten copies, or only the issue's 3 slices? → A: All of it: all 13 slices and all 54 flatten copies go through the helpers, plus a test that refuses new inline copies (FR-003, FR-007, FR-008).

## User Scenarios & Testing *(mandatory)*

The users are the maintainers of this repository: people who edit the
pipeline's prose documents and the people who keep its test suite honest.

### User Story 1 - A renamed heading turns a sliced pin red, everywhere (Priority: P1)

A maintainer renames a heading that one of the prose tests uses as a slice
boundary — for example `**H — implement.**` becomes `**H — implementation.**`,
or `**Base branch:**` is reworded. Today, for most slice sites, the slice
silently runs to end of file, every pin in it can be satisfied from anywhere
below, and the suite stays green while still claiming to check a section.
After this change, every slice in the prose suite goes red on that rename, with
a message that names the boundary that stopped matching.

**Why this priority**: this is the silent failure the issue exists to close
(constitution principle I). A boundary rename has already undone one earlier
fix in this file: pre-flight item 10 was moved off a file-wide pin because a
verbatim copy in an appendix beat it.

**Independent Test**: rename each slice boundary in a scratch copy of the
document, one at a time, and run the prose suite against it. Every rename must
turn at least one test red with a boundary message.

**Acceptance Scenarios**:

1. **Given** the current documents, **When** the prose suite runs, **Then** every test passes and no pin text has changed.
2. **Given** a copy of the orchestrator with `**H — implement.**` reworded, **When** the prose suite runs, **Then** each test that slices on that heading fails and names the closing boundary that was not found.
3. **Given** a copy of the orchestrator with `**Base branch:**` reworded, **When** the prose suite runs, **Then** each test that slices the pre-flight walk fails and says the slice did not close.
4. **Given** a copy of `pipeline/docs/configuration.md` with `## Keys` reworded, **When** the prose suite runs, **Then** each test that slices "Resolving the layers" fails and names the missing boundary.

---

### User Story 2 - The slice helper's guards are proven to fire (Priority: P2)

A maintainer edits `prose_slice` and breaks one of its guards by accident.
Today nothing in the committed suite goes red: the guards were only ever fired
by throwaway probes. After this change, each guard has a committed test that
makes it fire on purpose and checks the exact exit status and the message.

**Why this priority**: a guard that has only ever passed has not been shown
able to fail (constitution principle III). The helper becomes the only slicer
in the file after Story 1, so its guards carry every slice.

**Independent Test**: delete or invert one guard in the helper; the test for
that guard goes red, and no other guard's test is needed to see it.

**Acceptance Scenarios**:

1. **Given** the helper is called with the wrong number of arguments, **When** it runs, **Then** it exits non-zero and prints the arity message.
2. **Given** a form that is neither `raw` nor `flat`, **When** it runs, **Then** it exits non-zero and names the bad form.
3. **Given** a path that does not exist, or is a directory, **When** it runs, **Then** it exits non-zero and says the file cannot be read, naming that file.
4. **Given** an opening boundary that matches nothing, **When** it runs, **Then** it exits non-zero and says the slice is empty.
5. **Given** an opening boundary that matches more than one line, **When** it runs, **Then** it exits non-zero and says the boundary matches more than once.
6. **Given** a closing boundary that matches nothing after the opener, **When** it runs, **Then** it exits non-zero and says the slice is unterminated.
7. **Given** a heading-shaped line inside the slice that the caller did not declare, **When** it runs, **Then** it exits non-zero and prints that line.
8. **Given** each guard test, **When** the guard it targets is removed from the helper in a scratch copy, **Then** that test goes red.

---

### User Story 3 - One flatten, one slicer, and no inline copy can return (Priority: P3)

A maintainer writes a new prose test. Today they copy one of 54 inline
flatten pipelines or one of 13 bare range slices, and a copy that drifts (for
example one that forgets to strip carriage returns) is invisible. After this
change there is one flatten helper and one slice helper, every existing site
uses them, and a test refuses a new inline copy of either.

**Why this priority**: logic written many times drifts (constitution principle
IV). It is the cheapest story to lose without immediate harm, so it is last.

**Independent Test**: add one bare range slice, or one inline flatten
pipeline, to a scratch copy of the test file; the refusing test goes red and
names the line.

**Acceptance Scenarios**:

1. **Given** the converted file, **When** the refusing test walks it, **Then** it finds no bare range slice and no inline flatten outside the two helpers, and says how many lines it walked.
2. **Given** a scratch copy with one inline flatten pipeline added, **When** the refusing test runs on it, **Then** it fails and names that line.
3. **Given** a scratch copy with one bare range slice added, **When** the refusing test runs on it, **Then** it fails and names that line.

---

### Edge Cases

- **A slice whose region legitimately holds a bold-led line.** The pre-flight
  walk holds `**Read item 11 before item 1.**`. The helper must let the caller
  declare that one expected line, so the walk can use the helper, while any
  OTHER heading-shaped line in the same region still fails. Declaring a line
  must never switch the inner-heading guard off for the whole slice.
- **A slice of a document other than the orchestrator.** The helper takes the
  document as an argument; its unreadable-file message names that document,
  not "the orchestrator".
- **Carriage returns.** Some current flatten sites strip carriage returns and
  some do not. The documents carry none today (`.gitattributes` pins `*.md` to
  LF). The flatten helper strips them; on the current tree that changes no
  haystack, and the differential below must show it.
- **A haystack built from more than flattening.** Some sites also strip a
  leading `> ` (blockquote) before flattening. The flatten helper does not
  absorb that step; such a site keeps its own pre-step and hands the result to
  the helper.
- **Section walks that close on "the next heading".** Several sites use an awk
  flag (`on`) to take a section up to the next `## ` heading rather than a
  named closing boundary. They cannot be fooled by a renamed closer, and they
  are out of scope; the refusing test must not flag them.
- **A slice taken twice in one test.** The red-flags test deliberately
  flattens a slice it already holds rather than slicing twice; that shape
  stays, using the flatten helper.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The slice helper MUST take the document to slice as its first
  argument, so one helper serves the orchestrator and every other document the
  prose suite reads.
- **FR-002**: Every existing call of the slice helper MUST be updated to the
  new argument order, and its boundaries, form and name MUST stay as they are.
- **FR-003**: Every bare range slice in `pipeline/tests/prose.bats` that has a
  named opening and closing boundary MUST go through the slice helper, so each
  one is guarded for: a readable file, a non-empty slice, a single opening
  match, opening on its boundary, closing on its boundary, and no undeclared
  heading inside. Coverage MUST be found by walking the file, not by a list.
- **FR-004**: No pin, anchor, row or span text that a test searches for MAY
  change. The converted tests MUST search a haystack byte-identical to the one
  they searched before, on the current documents; a recorded differential MUST
  show this for every converted site.
- **FR-005**: The slice helper MUST let a caller declare heading-shaped lines
  that are expected inside its slice. A declared line MUST be matched exactly
  (whole line), and every undeclared heading-shaped line MUST still fail the
  slice.
- **FR-006**: Each of the helper's guards — arity, form, unreadable file,
  empty slice, opening boundary matched more than once, unterminated slice,
  undeclared inner heading — MUST have a committed test that makes it fire and
  asserts the exact exit status and the message. The "did not open on its
  boundary" guard is labelled near-unreachable in the file; it MAY stay
  untested, and the reason MUST be written beside it.
- **FR-007**: There MUST be one flatten helper (strip carriage returns, join
  lines with a space, squeeze runs of spaces), and every inline copy of the
  flatten pipeline in `pipeline/tests/prose.bats` MUST be replaced by it.
- **FR-008**: A test MUST walk `pipeline/tests/prose.bats` and fail, naming the
  line, when it finds a bare range slice with a named closing boundary or an
  inline flatten pipeline outside the two helpers. It MUST also fail when it
  walked zero lines.
- **FR-009**: The refusing test of FR-008 and each guard test of FR-006 MUST be
  shown able to go red by a positive control that is run, not only written,
  and the run recorded.
- **FR-010**: The section walks that close on the next heading (the `on` flag
  shape) and the JSON block extraction MUST be left as they are, and MUST NOT
  be flagged by the refusing test.
- **FR-011**: Converting the ~31 whole-sentence pins to clause anchors is out
  of scope and MUST NOT be done.
- **FR-012**: The full suite MUST stay green, and in each test root the plan
  line MUST equal the count of passing tests.

### Key Entities

- **Slice**: the lines of one document between an opening and a closing
  boundary, inclusive, used as the haystack for a group of pins.
- **Boundary**: a pattern that must match exactly one opening line, and a
  closing line after it.
- **Declared inner line**: a heading-shaped line a caller names as expected
  inside its slice.
- **Haystack**: the text a pin is searched in — a slice, raw or flattened, or a
  whole flattened document.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After the change, a walk of `pipeline/tests/prose.bats` finds
  zero bare range slices with a named closing boundary and zero inline flatten
  pipelines outside the two helpers (down from 13 and 54 at `f72276c`).
- **SC-002**: For every slice boundary in the prose suite, renaming it in a
  scratch copy turns at least one test red with a boundary message — 100% of
  boundaries, measured by a mutation sweep that also confirms each mutation
  landed.
- **SC-003**: Every converted haystack is byte-identical to its old value on
  the current documents — 100% of converted sites, recorded once with the date
  and the commit.
- **SC-004**: Removing any one tested guard from the helper turns its own test
  red — 100% of the tested guards.
- **SC-005**: The full suite passes, with the plan line equal to the passing
  count in each of the four test roots.
- **SC-006**: The prose test file's wall time grows by no more than 25% over
  its time at `f72276c`, judged by alternating old and new runs on one machine
  (three each), because every converted slice now runs the helper's guards.

## Assumptions

- **Scope is every slice site, not only the three the issue names** (confirmed
  by the owner in Clarifications, 2026-11-01). The issue
  named three because three existed then. Constitution principle V says
  coverage is derived by walking the tree, never listed; doing only the named
  three would leave ten more unguarded slices of the same shape.
- **Scope is every flatten copy, not only seven**, for the same reason.
- This is a change to the test suite only. No shipped document, script or
  plugin manifest changes, so no plugin version or changelog entry is needed
  and nothing is released.
- The suite total changes (new guard tests, the refusing test). That is
  expected; issue #31 notes that an earlier change could not add them because
  its acceptance fixed the total.
- `pipeline/skills/pipeline/SKILL.md` is not touched, so its 65,536-byte limit
  is not at stake.
- The red-flag pin's empty-table guard, which the issue notes is unreachable
  and already labelled so in the file, is left as it is.
- Throwaway probes from issue #30's work are not in the repository; "replacing
  them" means adding committed tests, with nothing to delete.
