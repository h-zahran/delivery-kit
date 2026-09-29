# Feature Specification: progress.sh learns commits and pieces

**Feature Branch**: `018-progress-commits-pieces`

**Created**: 2026-09-29

**Status**: Draft

**Input**: User description: "Phase 19: progress.sh learns commits and pieces" — the Campaign 3 seed in `main-plan.md`, quoted verbatim in `.delivery-kit/runs/018-progress-commits-pieces/seed.md`.

## Context

Campaign 3 makes a pipeline run build and commit one `tasks.md` phase (a
"piece") at a time, so a developer can review the work in small, ordered
steps. The orchestrator that will do this (Phases 20 and 21) needs two
things from the state helper that it cannot do today:

1. record every commit a run makes, with what it was for;
2. name the next piece to build.

This feature adds only those two abilities. The orchestrator's prose does
not change here.

**Measured while writing this spec (2026-09-29, `main` = `7ceabd9`):** the
state file's `commits` list is read by nothing, as the seed says — but it is
NOT always empty. Of the 17 run state files in this repository, 14 hold
entries, and every one of those entries is a bare commit id written as a
plain string by earlier runs. Nothing validates that shape. Any new writer
therefore meets lists that already hold old-style entries, and must neither
reject them nor be confused by them.

## Clarifications

### Session 2026-09-29

- Q: When `commit-add` is given a commit id that is already recorded with the exact same details, should it succeed without writing anything, instead of failing? → A: Yes. The same id with identical details succeeds and writes nothing; the same id with different details is refused.
- Q: If one recorded commit id is a short form of another, should `commit-add` treat them as the same commit? → A: Accept only full 40-character ids, so a short form can never be recorded. This narrows the seed's "7–40" rule on purpose.

## User Scenarios & Testing *(mandatory)*

The "user" of this feature is the pipeline orchestrator, and behind it the
developer who later reads the commit record.

### User Story 1 - Record a commit with its purpose (Priority: P1)

After the orchestrator makes a commit, it records one entry saying which
commit it was, what kind of work it holds (the spec, a piece, a late-phase
fix, and so on), which piece and tasks it covers, and which files it
changed. The record is what later builds the reviewer's guide and what lets
a resumed run know which pieces are already done.

**Why this priority**: Nothing else in Campaign 3 works without a trustworthy
record. `piece-next` (User Story 2) reads it, and Phase 21's review guide is
built from it.

**Independent Test**: In a scratch repository, create a run state file, record
one entry, and inspect the state file: exactly one new entry exists, with the
right fields and the right JSON types, and the file still validates.

**Acceptance Scenarios**:

1. **Given** a valid run with an empty commit list, **When** a `piece` entry is
   recorded with a commit id, a piece name, two task ids and two file paths,
   **Then** the list holds one entry whose `tasks` and `files` are arrays of
   two strings each, and the state file validates.
2. **Given** a run whose list already holds one entry, **When** a second entry
   is recorded, **Then** the list holds two entries, the first unchanged.
3. **Given** a run whose list holds old-style bare-string commit ids, **When** a
   new entry is recorded, **Then** the old entries are kept exactly as they
   were and the new entry is appended after them.
4. **Given** any of the refusal conditions in FR-004, **When** a record is
   attempted, **Then** the command exits non-zero, names the problem on the
   error stream, and the state file is byte-identical to before.
5. **Given** an entry is already recorded, **When** the exact same record is
   attempted again, **Then** the command exits zero and the state file is
   byte-identical to before.
6. **Given** an entry is already recorded, **When** the same commit id is
   recorded with a different piece, kind, task list or file list, **Then** the
   command is refused as in scenario 4.

---

### User Story 2 - Name the next piece to build (Priority: P1)

Before building, the orchestrator asks which piece comes next. The helper
reads the run's tasks file, walks its piece headings in order, and names the
first one the commit record does not yet cover — together with the task ids
under it. When every piece is covered, it says nothing, and the orchestrator
knows H is finished.

**Why this priority**: This is what makes a run build in pieces, and what
makes a resumed run pick up at the right piece instead of rebuilding a
committed one.

**Independent Test**: In a scratch repository, point a run at a fixture tasks
file with three piece headings, record the first as done, and ask for the
next: the second heading and its task ids are printed.

**Acceptance Scenarios**:

1. **Given** a tasks file with three piece headings and an empty commit list,
   **When** the next piece is asked for, **Then** the first heading's text and
   its task ids are printed.
2. **Given** the first piece is recorded as a `piece` entry, **When** the next
   piece is asked for, **Then** the second heading is printed.
3. **Given** a phase recorded under the `converge` kind (a phase the converge
   step appended), **When** the next piece is asked for, **Then** that phase is
   never printed.
4. **Given** every piece heading is recorded, **When** the next piece is asked
   for, **Then** nothing is printed and the exit status is zero.
5. **Given** a real heading carrying an em dash, an emoji and parentheses,
   **When** it is printed and later recorded, **Then** the recorded name
   matches the heading byte for byte and the heading is skipped afterwards.
6. **Given** any refusal condition in FR-010, **When** the next piece is asked
   for, **Then** the command exits non-zero and names the problem.

---

### User Story 3 - The command list names the new commands (Priority: P3)

A person who calls the helper wrongly sees a usage line that lists every
command, including the two new ones.

**Why this priority**: Small, but a usage line that omits a command hides it.

**Independent Test**: Call the helper with no arguments; the usage text names
both new commands.

**Acceptance Scenarios**:

1. **Given** no arguments, **When** the helper runs, **Then** it exits non-zero
   and the usage text contains `commit-add` and `piece-next`.

### Edge Cases

- **Old-style entries.** A bare-string entry is an old record of a commit id.
  Measured across the 17 real state files: 14 such entries are a 7-character
  short id, 9 are a full 40-character id, 1 is a 9-character id, and 8 are a
  short id followed by a space and the commit subject — 32 in all. The
  duplicate-id check (FR-004d) therefore compares an old entry by its FIRST
  WORD, as a prefix of the new full id. A first word that is not 7 to 40
  lowercase hexadecimal characters matches nothing — an empty or odd old
  entry must never prefix-match every id. Recording a commit whose short
  form already appears is
  refused, because a bare string carries no details and so can never be an
  identical re-record. An old entry never counts as a recorded piece (FR-008),
  because it names no piece.
- **A repeated record.** The same call made twice (a re-run after a crash)
  succeeds the second time and writes nothing (FR-004a). The same id with
  any detail changed is refused (FR-004d).
- **Heading shapes seen in this repository.** Headings such as
  `## Phase 3: User Story 1 — a percentage that can never arrive in time (P1) 🎯 MVP`
  and `## Phase 4: User Story 2 — the window size (P2) — a RULED NON-CHANGE`
  (both in `specs/017-guard-config-bounds/tasks.md`), and lettered headings
  such as `## Phase 9b: M — pull-request review, round 2 of 3 (2026-08-24)`
  (in older specs).
- **Headings that are not pieces.** `## Format: …`, `## Dependencies`,
  `## Parallel opportunities`, `## Implementation strategy`, and rule blocks
  such as `## ⚠️ Four rules that override anything below` are not pieces, and
  their lines do not belong to the preceding piece.
- **A heading with no task lines** (no `- [ ]` / `- [X]` task under it) is
  NOT a piece: it has nothing to build and nothing to mark done, and
  `commit-add` refuses a `piece` entry with an empty task list (FR-004f), so
  a task-less heading offered as a piece could never be recorded and would be
  offered for ever. `piece-next` skips it (FR-008). This is not hypothetical:
  measured 2026-09-29, `specs/017-guard-config-bounds/tasks.md` has seven
  `## Phase <N>:` headings with 2, 0, 10, 3, 4, 7 and 2 tasks — its
  `## Phase 2: Foundational` has none, so that file yields six pieces.
- **Duplicate headings.** Two piece headings with byte-identical text cannot be
  told apart by name. Recording one covers both. This is accepted, not handled;
  see Assumptions.
- **A task line inside a non-piece section** (for example, under
  `## Dependencies`). It belongs to no piece and is never printed.
- **Line endings.** A tasks file written with Windows line endings must yield
  the same heading text and ids as one written with Unix line endings — the
  trailing carriage return is not part of the heading. Measured 2026-09-29:
  the native Windows jq removes the CR itself when it reads a file, so on
  Windows the helper's own CR removal is never exercised; only the Linux and
  macOS runs of the suite prove it.
- **A failed write.** The state file is replaced by moving a finished
  temporary file into place (FR-005), so a write that fails part-way leaves
  the previous file intact. No test forces a part-way failure; what is
  tested is that every refusal leaves the file byte-identical.

## Requirements *(mandatory)*

### Functional Requirements

**Recording a commit (`commit-add`)**

- **FR-001**: The helper MUST provide a `commit-add` command taking, in order:
  the feature, a kind, a commit id, a piece name, a task list, and zero or more
  file paths.
- **FR-002**: `commit-add` MUST append exactly one entry to the run's `commits`
  list holding: `sha` (string), `kind` (string), `piece` (string), `tasks`
  (array of strings, split from one comma-separated argument; an empty
  argument gives an empty array) and `files` (array of strings, one per
  remaining argument, in the order given).
- **FR-003**: The legal kinds MUST be exactly: `spec`, `piece`, `converge`,
  `simplify`, `review`, `tests`, `constitution`, `other`.
- **FR-004**: `commit-add` MUST refuse — non-zero exit, a message on the error
  stream naming the problem, and no change to the state file — when:
  (a) the kind is not a legal kind;
  (b) the commit id is empty;
  (c) the commit id is not exactly 40 characters, each a lowercase
  hexadecimal digit — a full id, never a short form (Clarifications, second
  answer);
  (d) the commit id is already recorded with different details — as an
  entry whose `kind`, `piece`, `tasks` or `files` differ from this call's, or
  as an old-style bare-string entry whose first word is 7 to 40 lowercase
  hexadecimal characters and a prefix of the commit id (an old entry carries no details and so is never an identical
  re-record) — an identical re-record is not refused; see FR-004a;
  (e) the feature has no valid run state file;
  (f) the kind is `piece` and the piece name or the task list is empty;
  (g) the file list is empty and the kind is anything other than `tests`;
  (h) the feature is given but fewer than four further arguments follow it
  (with no feature at all, the helper's existing usage error fires first);
  (i) the kind contains anything other than lowercase letters — so a
  multi-word value such as `spec piece` can never match the legal list;
  (j) the piece name contains a carriage return, a line feed or the U+001F
  unit separator. A name carrying one could never equal a heading
  `piece-next` prints, so the piece would be offered for ever.
  (k) the file list holds an empty path, or the task list holds an empty
  task id (`T001,,T002`, a leading or a trailing comma) — an empty item is
  what an unset variable expands to, so it is the shape a broken caller
  produces (added at deep review, finding M-2).
  (l) the state file's `commits` is present but not a list — refused rather
  than read as empty (added at pull-request review, finding D). `piece-next`
  refuses the same state (FR-010).
  An empty old-style entry (`""`) has no first word and so claims nothing;
  it must never stop a record (added at deep review, finding I-1: it made
  every call fail with jq's own error and exit 5). When an identical object
  entry and an old-style claim both exist for one id — a state reachable only
  by hand-editing — the identical entry wins and the call succeeds (FR-004a).
  An old entry's first word is split on a single space, the only separator
  measured in real files; a leading space or a tab is not handled.
  The two duplicate refusals in (d) carry different messages — one for a
  recorded entry with different details, one for an old-style entry — so a
  test can tell which rule fired.
- **FR-004a**: When the commit id is already recorded as an entry whose
  `kind`, `piece`, `tasks` and `files` are all identical to this call's,
  `commit-add` MUST exit zero and leave the state file byte-identical. A
  re-run after a crash that falls between recording and the next step must
  succeed, because every pipeline phase is re-entered safely by design.
- **FR-005**: `commit-add` MUST write the state file through a temporary file
  that is then moved into place, like every other writer in the helper, and
  the result MUST still pass the helper's own validation.
- **FR-006**: `commit-add` MUST keep every existing entry, including old-style
  bare-string entries, unchanged and in order.

**Naming the next piece (`piece-next`)**

- **FR-007**: The helper MUST provide a `piece-next` command taking the feature.
  It reads the tasks file whose path is recorded in the run's
  `artifacts.tasks`.
- **FR-008**: A piece heading is a line that begins `## Phase `, followed by one
  or more digits, optionally followed by lowercase letters, followed by `:`,
  AND has at least one task line under it (FR-009). A heading of that shape
  with no task line is not a piece and is skipped.
  `piece-next` MUST consider piece headings in file order and select the first
  whose text is not the `piece` of any recorded entry of kind `piece` or kind
  `converge`. The comparison MUST be exact, byte for byte, on the heading text
  after the leading `## `, with ONE trailing carriage return removed.
- **FR-009**: For the selected piece, `piece-next` MUST print two lines: first
  the heading text after `## `, verbatim; second the task ids belonging to it,
  comma-separated, in file order. A task id is `T` followed by one or more
  digits, taken from a line that begins `- [ ] ` or `- [X] ` (or `- [x] `). A
  task line belongs to a piece when it lies after that heading and before the
  next line beginning `## ` (two hashes and a space). A `### ` subheading
  does not end a piece: `specs/017-guard-config-bounds/tasks.md`'s Phase 3
  holds five `### ` subheadings and all ten of its tasks sit beneath them.
- **FR-010**: `piece-next` MUST refuse — non-zero exit, a message naming the
  problem — when: (a) the feature has no valid run state file; (b) the run
  records no `artifacts.tasks`; (c) the recorded tasks file does not exist;
  (d) the tasks file holds no piece at all — no `## Phase <N>:` heading, or
  only such headings with no task line under them;
  (e) the piece it would print has a heading that, after its one trailing
  carriage return is removed, still holds a carriage return (mid-line, or a
  second one before the line end), a NUL, or the U+001F unit separator. Its
  output could not carry such a heading intact — command substitution drops
  a NUL silently (added at deep review) — and `commit-add` refuses a piece
  name holding a CR or U+001F (FR-004j; argv cannot carry a NUL at all), so
  offering it would stall the run on a piece that can never be recorded.
  Measured 2026-09-29: the native Windows jq keeps a lone mid-line CR, so a
  mid-line CR is refused on every OS. But it reads a trailing `a\r\r\n` as
  `a\r`, and the helper then strips that last CR — so on Windows ONLY a
  trailing double CR comes out clean and is offered, where Linux and macOS
  refuse it. Both outcomes are safe: a clean name records and skips.
- **FR-011**: When every piece heading is recorded, `piece-next` MUST print
  nothing and exit zero. "Nothing left" and "something went wrong" must never
  look the same.
- **FR-012**: `piece-next` MUST NOT write to the state file or the tasks file.
- **FR-012a**: `commit-add` MUST print nothing on stdout, in success and in
  refusal alike; its diagnostics go to stderr.

**Usage**

- **FR-013**: The helper's usage line MUST name `commit-add` and `piece-next`
  beside the existing commands.

**Scope**

- **FR-014**: No existing command's behaviour changes. `validate` still
  accepts the state file with or without entries in `commits`, of either
  shape.
- **FR-015**: The orchestrator document, the plugin changelog and every other
  document are unchanged by this feature.

### Key Entities

- **Commit record entry**: one commit the run made. Fields: `sha` (the commit
  id), `kind` (what the commit holds), `piece` (the piece heading it covers, or
  empty), `tasks` (task ids it covers), `files` (paths it changed).
- **Old-style entry**: a bare string in `commits`, holding a commit id and
  nothing else, written by runs before this feature.
- **Piece**: one `## Phase <N>:` section of a run's tasks file, identified by
  its exact heading text.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every refusal condition in FR-004 and FR-010 has its own test.
  EVERY new test — refusal and good case alike, including any added after a
  mutation check — is shown failing against the helper as it was before this
  feature, then passing after.
- **SC-002**: Every good-case scenario in User Stories 1 and 2 has its own
  test, including the old-style-entry scenario and the real-heading
  scenario; array fields are asserted by type, never by value alone.
- **SC-003**: The full house suite, run from the repository root, goes from
  `1..170` with 170 passing to `1..170+N` with 170+N passing, 0 failing and 0
  non-TAP lines, where N is the number of added tests, and the plan line
  equals the pass count. The commit message names every added test.
- **SC-004**: The shell analyser, run exactly as CI runs it, reports nothing
  on the changed files.
- **SC-005**: Replayed against every real run state file in this repository
  other than this run's own (copies, never the originals; the replay counts
  them itself and fails on zero — 17 on 2026-09-29), `commit-add` appends to
  every one without altering an existing entry, and each result still
  validates.
- **SC-006**: The branch's diff against the baseline commit touches exactly
  three paths outside `specs/018-progress-commits-pieces/`:
  `pipeline/scripts/progress.sh`, `pipeline/tests/progress.bats` and the new
  fixture — which is how FR-015 is checked.

## Assumptions

- The piece-heading rule (FR-008) admits a letter suffix (`Phase 9b:`) because
  real tasks files in this repository carry them. Those lettered phases were
  appended after K by review rounds, so in practice they are not present when
  H asks for pieces; admitting them costs nothing and refusing them would
  make the rule wrong about files that exist.
- Duplicate piece headings within one tasks file are not expected; the spec
  tool numbers phases uniquely. Detecting them is out of scope.
- Commit ids are recorded as git prints a full id: 40 lowercase hexadecimal
  characters. A short or uppercase id is refused rather than expanded or
  normalised, so a caller that passes one learns about it. Every caller has
  the full id to hand (`git rev-parse HEAD`), so the rule costs nothing.
- The seed allowed 7 to 40 characters; the owner narrowed it to exactly 40 at
  clarify, so the same commit can never be recorded under two spellings.
- The tasks-file path in `artifacts.tasks` is relative to the repository root,
  as every existing run records it, and the helper runs from the repository
  root, as it always has.
- Only the two new commands are added. Deciding when to call them is the
  orchestrator's job, in Phases 20 and 21.
- **A piece always has a file to record.** Campaign 3's ruling 16 has every
  piece commit carry `tasks.md` with that piece's `[X]` marks, so a `piece`
  entry's file list is never empty, even for a piece whose tasks write only
  to ignored paths (for example, a Setup phase that saves baselines under
  `.delivery-kit/`). FR-004(g) therefore never blocks a real piece. Making
  the commit include `tasks.md` is Phase 20's duty, not this feature's; this
  feature only refuses the empty list that would otherwise hide a broken
  caller. **One case is left for Phase 20 by name:** a run that crashes after
  a piece's commit but before its `commit-add`. On resume the marks are
  already committed, so there is nothing new to commit, and `piece-next`
  offers the piece again. Phase 20's resume step must record that piece from
  the commit that already holds it (its sha and files), which FR-004a then
  makes safe to repeat.
- **File paths are passed as the repository shows them**: relative, never
  starting with `/` or `-`. On Windows, Git Bash rewrites an argument that
  looks like an absolute POSIX path before a native program sees it
  (measured 2026-09-29: `/tmp/x` arrives as `C:/Users/…/Temp/x`). A relative
  path is untouched. A path starting with `-` is protected by passing the
  list after `--`.
