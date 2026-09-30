# Feature Specification: the orchestrator commits late fixes and guides the reviewer

**Feature Branch**: `020-late-commits-review-guide`

**Created**: 2026-09-30

**Status**: Draft

**Input**: User description: "Phase 21: the orchestrator commits late fixes and guides the reviewer" — the Campaign 3 seed in `main-plan.md`, quoted verbatim in `.delivery-kit/runs/020-late-commits-review-guide/seed.md`, with Campaign 3 rulings 15–24 as its design, plus the items Phase 20 recorded for this phase (spec 019 Edge Cases; research R14–R16).

## Context

Phase 20 (spec 019, merged as PR #48, `main` = `8efe515`) made phase H build
and commit one `tasks.md` phase — a **piece** — at a time, after committing
the spec on its own. It left the phases after H unchanged: H.5, H.7, I and J
still leave their changes uncommitted, K still commits "the exact file list"
as one commit, and the pull request carries no guide to the commits. This
feature is the **back half**: every phase after H commits its own work, K
shows the whole commit list, and the pull request and the DONE summary tell
the reviewer how to read the branch, commit by commit.

Everything this feature changes is the orchestrator document
`pipeline/skills/pipeline/SKILL.md`, its pins in `pipeline/tests/prose.bats`,
and the plugin changelog. The orchestrator is prose read by an agent: its
"behaviour" is what that prose instructs, and its tests pin the sentences that
carry each obligation.

**Measured while writing this spec (2026-09-30, `main` = `8efe515`):**
- The phase J cap-breach paragraphs are a byte-exact span (`span_j`,
  `prose.bats:572`, asserted at `:649`); any insertion there goes red, so the
  J change is a span changed on purpose.
- K's gate-table row is `| Commit | K | The exact file list and the exact
  commit message |`; the first two cells are pinned at `prose.bats:21`.
- Phase 20 recorded these items for this phase (spec 019 Edge Cases and
  research): (a) in
  commits mode no human sees a piece commit's files before the push — a
  release blocker for 1.3.0; (b) K has nothing to commit when H.5–J changed
  nothing; (c) H.7 and I do not name which diff they read; (d) a `--from H`
  after H.5 would be offered H.5's appended phase as a piece; (e) a state file
  tracked in git hands a re-entry a recorded answer nobody at the keyboard
  gave; (f) the status skill misreports G and H — Phase 22's, not this
  feature's; (g) the prose says how to READ a plain-string `gates.G` but not
  how to WRITE the review answer into it on a resume into an unfinished G;
  (h) a spec directory the owner already committed under another subject
  leaves the spec commit nothing to commit.

## Clarifications

### Session 2026-09-30

- Q: Under `--auto`, K and L do not stop, so nobody sees the new commit list
  before the push to the public PR branch. How is the 1.3.0 release blocker
  closed? → A: Stop on odd paths. `--auto` still collapses K and L, but when
  any committed or pending path lies outside `codeRoots`, the feature's spec
  directory and `tasks.md`, K stops — even under `--auto` — and shows it.
- Q: When the run's state file is tracked in git, a re-entry finds gate
  answers nobody at the keyboard gave. What does the re-entry do? → A: Stop
  and name it. The re-entry stops, names the tracked state file, and waits
  for the developer to confirm the recorded answers once before any
  recorded answer is used.

## User Scenarios & Testing *(mandatory)*

The actors are the **developer** who runs the pipeline and later reviews the
branch, the **reviewer** who reads the pull request, and the
**orchestrator** — the agent that follows `SKILL.md`.

### User Story 1 - Every phase after H commits its own work (Priority: P1)

H.5 (converge), H.7 (simplify), I (deep review) and J (tests) each end with
one commit of their own when they changed a file, recorded in the state file
under their own kind. Piece commits stay exactly as built: nothing is folded
back, rebased or rewritten.

**Why this priority**: Without it the late changes arrive in one lump at K,
and the review guide has a hole where the fixes are.

**Independent Test**: Read H.5, H.7, I and J in `SKILL.md`: each states its
commit, its recorded kind, and that it commits nothing when it changed
nothing; `prose.bats` pins each.

**Acceptance Scenarios**:

1. **Given** H.5 appended a phase to the tasks file and built it, **When** H.5
   ends, **Then** it commits that work once, recorded as kind `converge` with
   the appended heading as its piece, so `piece-next` never offers it again.
2. **Given** H.7 or I changed files, **When** the phase ends, **Then** it
   commits exactly those paths once, recorded as kind `simplify` or `review`.
3. **Given** J fixed failures, **When** J ends, **Then** it commits exactly
   those paths once, recorded as kind `tests`.
4. **Given** a late phase changed no file, **When** it ends, **Then** it makes
   no commit and says so — except J when the owner waved a red through (US2).

---

### User Story 2 - A red the owner waved through reaches the reviewer (Priority: P1)

J's duty to carry a waved-through red into "the commit message" now names
which commit: J's own. When J changed no file, J makes an empty commit whose
message is the record (ruling 23), so the red is visible in the commit list
and the review guide.

**Why this priority**: The duty exists so a red never reaches a reviewer as
green; with several commits, "the commit message" no longer says where.

**Independent Test**: Read J's cap-breach paragraphs: J's own commit carries
the record, and an empty commit carries it when J changed nothing; the phase
J span is changed on purpose and re-pinned.

**Acceptance Scenarios**:

1. **Given** the owner waved failures through at J's cap breach and J changed
   files, **When** J commits, **Then** J's commit message carries the
   surviving failures, redacted.
2. **Given** the same, but J changed no file, **When** J ends, **Then** it
   makes one empty commit whose message carries them, recorded as kind
   `tests`; hooks run; `--no-verify` is never used.

---

### User Story 3 - K shows the whole commit list (Priority: P1)

K stops showing one file list. It shows every commit the run made on the
branch, oldest first, each with its files, plus anything still uncommitted
with the exact message proposed for it; it commits the remainder only after
the answer.

**Why this priority**: It is the one place, before anything leaves the
machine, where the developer sees every path the run committed — the release
blocker Phase 20 recorded.

**Independent Test**: Read K and its gate-table row: the commit list, the
files per commit, the remainder and its message; the row name stays `Commit`.

**Acceptance Scenarios**:

1. **Given** a run in the piece flow, **When** K runs, **Then** it shows the
   commits in `<base>..HEAD`, oldest first, each with every file it touched.
2. **Given** files still uncommitted, **When** K runs, **Then** it shows them
   and the exact message, and commits them only after the answer.
3. **Given** nothing is left uncommitted, **When** K runs, **Then** it shows
   the list, records that there is nothing to commit, and makes no commit.
4. **Given** a constitution written at pre-flight, **Then** its separate
   commit is unchanged.

---

### User Story 4 - The reviewer is told how to read the branch (Priority: P1)

The pull request body at L, and the DONE summary, carry a review guide: a
table built from the state file's record of commits, in commit order —
commit, kind, piece, task IDs, files — headed with one line telling the
reviewer to read commit by commit, top to bottom. It is shown in full at L,
like the rest of the body.

**Why this priority**: This is the fix for the complaint that started the
campaign: a run too large to review by hand.

**Independent Test**: Read L and DONE: the guide, its columns, its order, its
heading line; a dry read of the guide for a real tasks file is saved.

**Acceptance Scenarios**:

1. **Given** a run that made a spec commit, piece commits and late commits,
   **When** L builds the body, **Then** the guide lists every one, in commit
   order, with its kind, piece, task IDs and files.
2. **Given** the run reaches DONE, **Then** the summary carries the same guide.

---

### User Story 5 - The loose ends Phase 20 left are closed (Priority: P2)

H.7 and I review the run's whole change, not an almost-empty working tree;
a tracked state file cannot hand a re-entry a consent nobody gave; and a
resume into an unfinished G can record the review answer.

**Why this priority**: Each is small, and each makes a Phase 20 rule
misbehave in a real case.

**Independent Test**: Read H.7, I, G and pre-flight/resume for each rule;
`prose.bats` pins each.

**Acceptance Scenarios**:

1. **Given** most of the work is committed, **When** H.7 or I runs, **Then**
   it reads the change as `<base>..HEAD` plus the working tree.
2. **Given** the run's state file is tracked in git, **When** the run
   re-enters, **Then** it stops, names the tracked state file, and uses no
   recorded gate answer until the developer confirms them.
3. **Given** a resume into G whose `gates.G` is a plain string, **When** the
   review answer is recorded, **Then** `gates.G` becomes an object holding
   both answers.
4. **Given** the owner already committed the spec directory under another
   subject, **When** H reaches the spec commit, **Then** H makes none, says
   so, and goes on to the first piece.

### Edge Cases

- **A late phase with nothing to commit** makes no commit and says so; only J
  with a waved-through red makes an empty one.
- **A late phase that creates a path outside `codeRoots`, the spec directory
  and `tasks.md`** (test output, a log) leaves it uncommitted for K, which
  shows it (from I).
- **H.5 with no install of the converge tool** skips as today, and commits
  nothing.
- **The single-commit flow** (the handoff path, a run from an older pipeline)
  keeps today's K — one commit of the whole remainder — when the branch holds
  no commit; the late phases do not commit on that path. A run switched to it
  by `--implementer handoff` after piece commits were made shows those commits
  at K (FR-007b).
- **M and N** already commit review fixes today (N "commits fixes"); their
  commits appear in the commit list and the guide like any other.
- **A commit hook that rejects a late commit** is a hard stop, as for a piece;
  `--no-verify` is never used.
- **The review guide for a long run** lists every commit; it is never
  truncated.

## Requirements *(mandatory)*

### Functional Requirements

**Late commits**

- **FR-001**: In the piece flow, H.5, H.7, I and J MUST each end with one
  commit of their own when they changed a file, naming every path, recorded
  with `commit-add` as kind `converge`, `simplify`, `review` and `tests`.
- **FR-002**: H.5's entry MUST carry, as its piece, the heading of the phase
  converge appended to the tasks file, so `piece-next` never offers that phase
  as a piece.
- **FR-003**: A late phase that changed no file MUST make no commit and MUST
  say so — except J under FR-005.
- **FR-004**: Piece commits MUST stay as built: no rebase, no fixup, no
  amend, no history rewrite.

**J's carry**

- **FR-005**: J's carry duty MUST name J's own commit as the commit message
  that carries a waved-through red. When J changed no file, J MUST make an
  empty commit (`--allow-empty`) whose message is the record, recorded as kind
  `tests`; hooks run and `--no-verify` is never used.
- **FR-006**: The phase J span pin MUST change on purpose in the same commit;
  the commit message MUST quote the old text and the new.

**K**

- **FR-007**: K MUST show every commit in `<base>..HEAD`, oldest first, each
  with every file it touched, then any path still uncommitted with the exact
  proposed message; it MUST commit the remainder only after the answer.
- **FR-007b**: When `<base>..HEAD` holds a commit — the piece flow, or a run
  switched to the single-commit flow after commits were made — and any path
  committed on the branch or still pending lies outside `codeRoots`, the feature's spec directory and
  `tasks.md`, K MUST stop and show those paths — even under `--auto`, which
  otherwise collapses K. The run never commits a path under `.delivery-kit/`
  and never lists one in the remainder; one already in a commit on the branch
  is listed and counts as outside the feature (from I).
- **FR-008**: When nothing is left uncommitted, K MUST record that and make
  no commit.
- **FR-009**: K's gate-table row MUST keep the name `Commit` and show the
  commit list in its "Shown before you answer" column.
- **FR-010**: When `<base>..HEAD` holds no commit, K MUST keep today's
  behaviour.

**The review guide**

- **FR-011**: L's pull-request body and the DONE summary MUST carry a review
  guide: a table built from `commits`, in commit order, with columns commit,
  kind, piece, task IDs and files, headed with one line telling the reviewer
  to read the branch commit by commit, top to bottom.
- **FR-012**: The guide MUST be shown in full at L, with the rest of the body,
  before anything leaves the machine.

**Loose ends from Phase 20**

- **FR-013**: H.7 and I MUST read the run's change as `<base>..HEAD` plus the
  working tree.
- **FR-014**: A re-entry into a run whose state file is tracked in git MUST
  NOT trust its recorded gate answers without the developer confirming them.
  It MUST stop before any recorded answer is used, name the tracked state
  file, and wait for one confirmation from the developer that covers the
  recorded answers; `--auto` does not collapse this stop. The check MUST find
  a copy tracked under other letter case on a file system that ignores case
  (from I).
- **FR-015**: On a resume into an unfinished G whose `gates.G` is a plain
  string, recording the review answer MUST turn `gates.G` into an object
  holding the implementer answer and the review answer.
- **FR-019**: When no untracked file sits in the spec directory, at least one
  file there is tracked, none is uncommitted, and no spec commit is recorded or
  found by its subject, H MUST make no spec commit and MUST say so; a spec
  artefact recorded in `artifacts` that git ignores MUST be a hard failure
  that names it, and any other ignored file there is left alone (from M).

**Tests and records**

- **FR-016**: `prose.bats` MUST gain pins for: each late phase commits its own
  work under its kind; H.5 records its appended heading; J's carry lands in
  J's own commit or an empty one; K shows the commit list and commits the
  remainder only after the answer; the review guide in the PR body and in the
  DONE summary; FR-013 to FR-015 and FR-019. Each new pin MUST be proven by an INVERTED
  mutant, the mutated text echoed before the red is believed.
- **FR-017**: `pipeline/CHANGELOG.md`, under `## [Unreleased]`, MUST add to
  `### Added` (the review guide) and to `### Changed` (late phases commit
  their own work; K shows the commit list).
- **FR-018**: No file outside `SKILL.md`, `prose.bats`,
  `pipeline/CHANGELOG.md` and this feature's spec directory changes, except
  the five user-facing lines the owner had corrected at M (the K and J rows of
  `pipeline/docs/phases.md`, the Commit rows of `README.md` and
  `pipeline/README.md`, and the `codeRoots` row of
  `pipeline/docs/configuration.md`). The rest of the documents, including the
  status skill, are Phase 22's.

### Key Entities

- **Piece flow**: H builds and commits one `tasks.md` phase at a time; it
  runs when `gates.G` records implementer `claude` and a review answer
  (`commits` or `pauses`).
- **Single-commit flow**: every other run (the handoff path, a run started on
  an older pipeline); H builds in one pass and K makes one commit.
- **Late commit**: a commit made by H.5, H.7, I or J, recorded with
  `commit-add` under kind `converge`, `simplify`, `review` or `tests`.
- **Commit list**: the commits in `<base>..HEAD`, oldest first, each with its
  files.
- **Review guide**: a table built from the state file's `commits`, in commit
  order: commit, kind, piece, task IDs, files.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every obligation in FR-001 to FR-015 and FR-019 is stated in `SKILL.md` in
  the section that governs it, and every one listed in FR-016 has a pin that
  goes red under an inverted mutant.
- **SC-002**: The house suite from the repository root goes from `1..233`
  (all passing at `8efe515`) to `1..233+N`, every test passing, 0 non-TAP
  lines, the plan line equal to the pass count; the commit message names every
  added and changed pin and quotes the phase J span's old and new text.
- **SC-003**: A dry read of the new K and L against
  `specs/017-guard-config-bounds/tasks.md` is saved in this feature's
  directory: the review guide the run would print, built from `piece-next`
  output and the late phases, not predicted.
- **SC-004**: No sentence in `SKILL.md` still says K commits one file list in
  the piece flow, or that J's record goes into an unnamed "commit message" —
  checked by grep with a positive control.
- **SC-005**: The branch changes exactly `pipeline/skills/pipeline/SKILL.md`,
  `pipeline/tests/prose.bats`, `pipeline/CHANGELOG.md` and this feature's spec
  directory.

## Assumptions

- **This run executes on the installed pipeline 1.2.1**, which has none of
  Campaign 3's behaviour: its G asks no review question, its H builds in one
  pass, and its K makes one commit.
- **The docs are Phase 22's**, including the status skill (item f) and every
  file spec 019's Assumptions list.
- **M and N keep their commits** as today and appear in the commit list and
  the guide; this feature does not give them a kind of their own.
- **How the guide table is built from the state file**, and **how a tracked
  state file is detected**, are plan decisions; the spec fixes the outcome.
