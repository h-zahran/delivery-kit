# Feature Specification: The release gate reads every level-2 heading form

**Feature Branch**: `024-gate-every-heading-form`

**Created**: 2026-10-02

**Status**: Draft

**Input**: Seed `## Phase 25: the release gate reads every level-2 heading
form` from `main-plan.md`, quoted verbatim in the run's `seed.md`.

## Context

Phase 24 (`specs/023-gate-reads-whole-changelog/`) made the release form of
the version gate judge every line beginning `## ` in a plugin's changelog. Its
deep review found the other ways Markdown writes a level-2 heading, and left
them for a later decision (that feature's `research.md`, R7). The owner's
ruling, 2026-10-02: **judge every Markdown form**. Nothing here is inside a
plugin: `scripts/`, `tests/` and `specs/` belong to the repository, so no
plugin is released.

Measured 2026-10-02 at `main` = `8bc9b5a`:

- The release form's whole-file rule (`scripts/check-versions.sh`, the awk
  program after the first-heading check) judges a line only when it begins
  exactly `## `. Each of these shapes, appended below the release in a
  scratch copy of `handoff/CHANGELOG.md`, passes the release form (exit 0),
  while a plain `## Notes` control is refused (exit 1):
  - `##` followed by a tab;
  - `##` indented by one space, and by three spaces;
  - `##` with nothing after it (an empty heading);
  - a setext heading: a text line, then a line of `-` characters.
- A `## ` line inside a fenced code block is not a heading, but the rule
  today would refuse it. `handoff/CHANGELOG.md` holds one fenced block
  (lines 316–319) with no `## ` line in it, so nothing is refused wrongly
  today.
- Neither changelog holds a tab, indented or empty `##` heading, or any line
  made only of `-` or `=` characters. Every `## ` line in both is a dated
  version heading.

## Clarifications

### Session 2026-10-02

- Q: Should the release form judge a level-2 heading inside a block quote
  (`> ## Notes`) or a list item (`- ## Notes`)? → A: Yes, refuse them: strip
  the leading quote and list markers, then apply the same heading rule.
- Q: What should the release form do with a code fence that is opened and
  never closed? → A: Refuse it: the release form fails and names the fence
  line. A released changelog never ends inside a code block.
- Q: Should the release form track list items, so that a `##` line indented
  four or more spaces that continues a list item (and so renders as a
  heading inside it) is judged? → A: Yes, track lists: such a line is judged
  as part of the item; the same indent at the top level stays unjudged.
- Q: Should the release form refuse a setext (underlined) heading inside a
  block quote or a list item, as it does a `##` heading there? → A: Yes,
  same as `##`: remove the quote markers from both lines and the list
  markers from the text line, then apply the underline rule.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - No level-2 heading slips past the release form (Priority: P1)

A maintainer pushes a release tag. CI's agreement step runs the gate in its
release form. If the plugin's changelog holds a level-2 heading that is not a
dated version heading, in ANY form Markdown renders as level 2, the step
fails and names the line.

**Why this priority**: a heading written with a tab, an indent, no text or
an underline renders exactly like `## [Unreleased]`, yet passes the gate
today. That is a wrong pass, which the owner ruled unacceptable.

**Independent Test**: in a fixture copy of the repository, plant each shape
below the release, one at a time; the release form refuses each and names
its line, and the default form still passes.

**Acceptance Scenarios**:

1. **Given** a fixture whose changelog holds, below its version heading, one
   of: `##` then a tab and text; `## ` text indented one space; the same
   indented three spaces; an empty `##`; `## Notes ##`, **When** the gate runs
   with `--released <plugin>`, **Then** it exits non-zero, says the tree is
   not released, and names the line and its text.
2. **Given** a fixture whose changelog holds, below its version heading, a
   text line followed by a line of `-` characters (a setext heading),
   **When** the gate runs with `--released`, **Then** it refuses and names
   the heading's line.
3. **Given** a fixture whose changelog holds, below its version heading, a
   dated version heading indented one space, **When** the gate runs with
   `--released`, **Then** it refuses: only the canonical form counts as
   dated.
4. **Given** a fixture whose changelog holds, below its version heading,
   `> ## Notes` or `- ## Notes`, `> Notes` then `> ---`, or a list item
   `- item`, a blank line and
   then `    ## Notes` indented four spaces, **When** the gate runs with
   `--released`, **Then** it refuses and names the line.
5. **Given** a fixture whose changelog opens a code fence below its version
   heading and never closes it, **When** the gate runs with `--released`,
   **Then** it refuses and names the fence's line.
6. **Given** any of the fixtures above, **When** the gate runs with no
   argument, **Then** it exits 0 and prints its usual report.

---

### User Story 2 - What is not a heading is never judged (Priority: P2)

A maintainer keeps a code example or a horizontal rule in a changelog. The
release form must not refuse a line Markdown does not render as a heading.

**Why this priority**: a gate that refuses a correct changelog teaches people
to route around it. The owner's ruling allows a wrong refusal only where the
reading is in doubt; plain non-headings must pass.

**Independent Test**: in a fixture, plant each non-heading below the release;
the release form passes.

**Acceptance Scenarios**:

1. **Given** a fixture whose changelog holds, below its version heading, a
   fenced code block (backticks or tildes) containing a `## ` line, **When**
   the gate runs with `--released`, **Then** it passes.
2. **Given** a fixture whose changelog holds, below its version heading, a
   blank line and then a line of `-` characters (a thematic break), **When**
   the gate runs with `--released`, **Then** it passes.
3. **Given** a fixture whose changelog holds, below its version heading, a
   `## ` line indented four spaces, **When** the gate runs with
   `--released`, **Then** it passes.

---

### User Story 3 - The test fixtures keep their own baseline (Priority: P3)

A contributor adds, by mistake or on purpose, one of the newly refused
shapes to a live changelog. The `--released` tests in the house suite must
still judge their fixtures, not the live tree.

**Why this priority**: Phase 24 fixed exactly this for `## ` lines; widening
the gate without widening the fixture would re-open it.

**Independent Test**: append a newly refused shape to a copy of a live
changelog; the fixture helper removes it and the `--released` tests pass on
that copy.

**Acceptance Scenarios**:

1. **Given** a live changelog holding a newly refused heading shape, **When**
   the suite builds a released fixture from it, **Then** the fixture holds
   no undated level-2 heading in any form, and the `--released` tests pass.
2. **Given** the fixture helper, **When** it is read, **Then** it holds its
   own copy of every pattern it uses and reads none from the gate.

### Edge Cases

- **Containers** (settled at clarify): a level-2 heading inside a block
  quote (`> ## x`) or a list item (`- ## x`, `1. ## x`) also renders as
  level 2, and the release form refuses it, in ATX and setext form alike
  (`> Notes` then `> ---`).
- **An unclosed fence** (settled at clarify): Markdown renders everything
  after an opening fence with no closing fence as code. The release form
  refuses the unclosed fence itself and names its line, so a forgotten
  fence cannot hide a heading.
- **Setext doubt**: a line of `-` directly under a list item, a quote line or
  another heading is a thematic break in Markdown, not an underline. Under
  the owner's ruling a wrong refusal is acceptable where reading the line
  needs more than its neighbour, so the release form may treat any `-` line
  directly under a non-blank text line outside a fence as a setext
  underline.
- **HTML blocks** are not tracked: a `##` line inside one (for example
  inside `<details>`) is judged. That is a wrong refusal at worst, which the
  owner's ruling accepts.
- **Level 1 and level 3**: `#`, `###` and deeper, and a `=` underline (setext
  level 1), are not level-2 headings and are not judged.
- **A tab as indentation**: a tab before `##` reaches column 4, which is
  indented code at the top level; it is not judged, like a four-space
  indent, unless a list item can be open (FR-006).
- **Deep indent inside a list** (settled at clarify): `- item`, a blank
  line, then `    ## Notes` renders as a heading inside the item, and is
  refused; the same `    ## Notes` with no list item open is code, and is
  not judged. The gate does not track each item's exact text column: while
  ANY list item can be open, every deeply indented `##` line is judged
  (FR-006). That catches every heading a nested or widely indented list can
  hold, at the cost of refusing a rare `##` line in a code block inside a
  list item, which the owner's ruling accepts.
- **Fences and containers**: where a fence's end depends on a container
  (a quote ending, a list item ending, a closer at another indent), the gate
  does not guess: it refuses the first unclear line (FR-007). A changelog
  can always be made clean by writing a fence's lines and closer with its
  opener's prefix, as the real `handoff/CHANGELOG.md` fence already does. A
  backtick line whose text holds another backtick is not a fence.
- **The first-heading check** (Phase 24 contract G3) keeps reading the first
  line beginning `## ` and keeps its message.
- **The default run's report**: the `state=` field keeps its meaning; it is
  not widened, because the CI log and an existing test read it.
- **The "one version-agreement script" test** requires exactly one
  `run bash <script>.sh` line in `tests/portability.bats`; a new test there
  calls the gate through `run bash -c`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Under `--released <plugin>`, the gate MUST refuse when the
  plugin's changelog holds an ATX level-2 heading that is not exactly the
  canonical dated version heading: a line whose text (after the container
  removal of FR-005) is `##` followed by a space, a tab or the end of the
  line, with or without a closing run of `#`.
- **FR-002**: Under `--released <plugin>`, the gate MUST refuse when the
  changelog holds a setext level-2 heading: a text line directly followed
  by a line whose text (after quote removal) is one or more `-` characters
  with only spaces or tabs after them. A text line is any non-blank line
  that is not an ATX heading, not a fence line and not inside a fence;
  an indented line counts as text.
- **FR-003**: Only the canonical dated form the gate reads today
  (`## [X.Y.Z] - YYYY-MM-DD`, unindented, nothing after the date) counts as
  dated; every other level-2 heading form MUST be refused, even one
  carrying a version and a date.
- **FR-004**: The gate MUST refuse a code fence that is opened and never
  closed before the end of the file, naming the opening fence's line and
  its text.
- **FR-005**: Containers: before FR-001 and FR-002 apply, the gate MUST
  remove, repeatedly, leading block-quote markers (any indent, `>`, one
  optional space) and, for FR-001, leading list markers (any indent, then
  `-`, `*`, `+`, or digits then `.` or `)`, then a space, a tab or the end
  of the line) and quote markers again, in any order, until neither
  applies (`- > ## Notes` is refused). A level-2 heading inside a block quote or a list item is
  refused.
- **FR-006**: Lists: while a list item can be open, a line indented four or
  more columns MUST be judged after its indent is removed, because it may
  continue the item. A list item can be open from any line that held a list
  marker until an unindented line that is not a list marker and not a block
  quote, read after a blank line, or an unindented ATX heading or fence.
  When no list item can be open, such a line is indented code and is not
  judged.
- **FR-007**: The gate MUST NOT judge: a line inside a fenced code block, or
  the fence lines themselves (a fence opens with three or more backticks or
  tildes, a backtick opener holding no further backtick, and closes with a
  fence of the same character at least as long); a line indented four or
  more columns when no list item can be open (FR-006); and a `-` line whose
  line above is blank. The gate follows a fence only while its shape is
  clean: every line inside starts with the opener's container prefix (its
  quote markers, and its indent with any list marker read as spaces), a
  blank line inside equals that prefix exactly, and the closer is that
  prefix then the fence, with no other line inside shaped like a closer.
  At the first line that breaks this,
  it MUST refuse, naming the opener's line and that line with its text,
  rather than guess where the fence ended.
- **FR-008**: Every refusal MUST name the line number and the line's text,
  every non-printable character shown as `?` (a tab included), and say the
  tree is not released. An ATX refusal reads
  `line <n> holds '<text>', which is not a dated version heading`, as
  today.
- **FR-009**: The walk MUST print at most one refusal: the first, in file
  order.
- **FR-010**: Only the plugin named by `--released` is judged, and no
  message prints an absolute path.
- **FR-011**: The default run (no argument) MUST keep its output and exit
  status, measured on the real tree and on every fixture the new test
  builds; the first-heading message (Phase 24 contract G3) MUST stay; the
  gate MUST stay the one script CI and the suite call, and the "one
  version-agreement script" test MUST stay green unchanged.
- **FR-012**: The suite's released-fixture helper MUST remove every shape
  FR-001 to FR-006 refuse, using its own copy of each pattern, never one
  read from the gate; its rule may be wider than the gate's, never
  narrower.
- **FR-013**: The house suite MUST grow by exactly one test
  (`1..242` → `1..243`), which plants every FR-001 to FR-006 shape and
  every FR-007 negative control. Every changed line under `scripts/` (a
  STRICT surface) MUST avoid the banned vocabulary, machine paths and
  counts in prose, and run under bash 3.2 and the awks the three CI
  systems run, with no interval expressions in awk patterns; no plugin
  file changes.

### Key Entities

- **Release form**: the gate run as `--released <plugin>`; what a tag run
  calls.
- **Level-2 heading**: a line Markdown renders as a second-level heading, in
  ATX (`##`) or setext (underlined) form.
- **Released fixture**: a copy of the repository the suite builds and
  normalises so that `--released` passes before a shape is planted.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every planted heading shape in User Story 1 is refused by the
  release form (0 slip through), each naming its own line, and every fixture
  passes the default form.
- **SC-002**: Every negative control in User Story 2 passes the release form
  (0 wrong refusals on those shapes).
- **SC-003**: A mutant that puts back the gate of `8bc9b5a` makes the new
  test fail, naming its clause; the mutation is confirmed to have landed.
- **SC-004**: The feature quickstart, run as one script, ends ALL OK.
- **SC-005**: The house suite reads `1..243`, 243 ok, judged by
  `scripts/check-suite.sh 243`; CI passes on three operating systems, a run
  confirmed to exist.
- **SC-006**: The real tree passes both forms of the gate, unchanged from
  `8bc9b5a`.

## Assumptions

- The installed pipeline is 1.3.0, so this run builds and commits in pieces.
- No plugin is released: neither plugin directory changes.
- The root `CHANGELOG.md` is an index and gets no entry.
- "Markdown" means CommonMark, the form GitHub renders.
