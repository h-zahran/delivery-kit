# Feature Specification: the orchestrator builds in pieces

**Feature Branch**: `019-orchestrator-builds-in-pieces`

**Created**: 2026-09-29

**Status**: Draft

**Input**: User description: "Phase 20: the orchestrator builds in pieces" — the Campaign 3 seed in `main-plan.md`, quoted verbatim in `.delivery-kit/runs/019-orchestrator-builds-in-pieces/seed.md`, with Campaign 3 rulings 15–24 as its design, plus two items carried from Phase 19 (spec 018 and the review of PR #47).

## Context

Developers reported that a finished pipeline run is too large to review by
hand: phase H builds every task at once and phase K makes one commit.
Campaign 3 makes a run build and commit one `tasks.md` phase — a **piece** —
at a time, and lets the developer choose, before building starts, how to
review it.

Phase 19 (spec 018, merged as PR #47) gave the state helper the two commands
this needs: `commit-add` records each commit a run makes, and `piece-next`
names the next piece to build. This feature is the **front half** of the
orchestrator change that uses them: the question at G, the piece-by-piece
build in H, the pause mode, resume, and every sentence in the orchestrator
that the change makes false. The **back half** — the late phases' own
commits, the new K and the review guide in the pull request — is Phase 21.

Everything this feature changes is the orchestrator document
`pipeline/skills/pipeline/SKILL.md`, its pins in `pipeline/tests/prose.bats`,
and the plugin changelog. The orchestrator is prose read by an agent: its
"behaviour" is what that prose instructs, and its tests pin the sentences
that carry each obligation.

**Measured while writing this spec (2026-09-29, `main` = `b0b3f1b`):** the
repository's `SKILL.md` is byte-identical to the installed pipeline 1.2.1 this
run executes on, so every line number the seed cites (taken at `dacf58e`) is
still current. Two pins outside the G slice will go false and are named in
the Requirements: the `--auto` row of the flags table, pinned whole at
`prose.bats:66`, and the docs sentence "Cap breaches … but the gates do not"
(`pipeline/docs/configuration.md:111`, pinned at `prose.bats:195`), which is
Phase 22's to change — see Assumptions.

## Clarifications

### Session 2026-09-29

- Q: When a piece stops before its commit (a hook rejects it, "stop here", or
  a crash), its edits are still uncommitted on resume. How does the run know
  which uncommitted files belong to that piece? → A: Record a snapshot. At
  piece start the run saves, in the state file, the list of paths already
  dirty; on resume it compares against that saved list, not against the
  tree as it stands.

## User Scenarios & Testing *(mandatory)*

The actors are the **developer** who runs the pipeline and later reviews its
work, and the **orchestrator** — the agent that follows `SKILL.md`.

### User Story 1 - The developer chooses how to review, before building starts (Priority: P1)

At G, after the implementer question is settled, the run asks the developer
one more question: review in **commits** (the run builds everything, one
commit per piece, reviewed afterwards) or in **pauses** (the run stops after
each piece for the developer to look). The answer is asked on every run and
is never pre-answered, not even under `--auto`.

**Why this priority**: Nothing else in this feature knows which mode to run
in without it, and it is the choice the developers asked for.

**Independent Test**: Read G in `SKILL.md`: it states the question, the two
answers, where the answer is recorded, that it is asked every run, and that
`--auto` does not collapse it; `prose.bats` pins each of those.

**Acceptance Scenarios**:

1. **Given** a run whose implementer resolves to `claude` (asked or
   pre-answered), **When** G runs, **Then** it asks commits-or-pauses and
   records the answer as `gates.G.reviewMode`.
2. **Given** `--auto` and `--implementer claude`, **When** G runs, **Then** it
   still stops for the review question.
3. **Given** the implementer answer is `handoff`, **When** G runs, **Then** it
   does not ask the review question, says in one line that review pieces are
   not available on that path, and the run keeps today's single-commit flow.
4. **Given** a re-entry (`--resume` or `--from G`) that finds
   `gates.G.reviewMode` recorded, **When** G runs, **Then** it does not ask
   again; the recorded answer stands for the life of the run.

---

### User Story 2 - The run builds and commits one piece at a time (Priority: P1)

In H the run first commits the spec artefacts on their own, then builds the
tasks file piece by piece: it asks `piece-next` for the next piece, builds
that piece's tasks, commits exactly the files the piece changed together with
`tasks.md` carrying the piece's `[X]` marks, and records the commit with
`commit-add`. It repeats until `piece-next` says nothing is left.

**Why this priority**: This is the change that makes a run reviewable.

**Independent Test**: Read H: the spec commit, the loop, how the file list is
taken, the commit message shape, and the `commit-add` call are each stated
and pinned. A dry read of H against a real tasks file lists the pieces
`piece-next` yields and which of them change only `tasks.md`.

**Acceptance Scenarios**:

1. **Given** H starts with the spec artefacts uncommitted, **When** it begins,
   **Then** it commits the feature's spec directory alone first, as
   `docs(spec): <feature>`, and records it with `commit-add` as kind `spec`.
2. **Given** a piece is built, **When** it is committed, **Then** the commit
   holds exactly the paths the piece changed plus `tasks.md`, every path
   named, and its message names the piece and its task range.
3. **Given** a piece whose tasks change no file but `tasks.md`, **When** it is
   committed, **Then** it still gets its own commit and the message says it
   changed no other file.
4. **Given** `piece-next` prints nothing, **When** H checks, **Then** H is
   done.

---

### User Story 3 - In pause mode, the developer reviews each piece before it is committed (Priority: P2)

In pause mode the run stops after each piece is built and before it is
committed, shows the piece, and waits for one of three answers: **go on**,
**fix this**, or **stop here**.

**Why this priority**: It is the second of the two modes the developer
chooses between; commits mode delivers value without it.

**Independent Test**: Read the pause rule in H: what is shown, the three
answers and what each does, that the developer's own edits go into the
piece's commit, and that `--auto` never collapses a pause.

**Acceptance Scenarios**:

1. **Given** pause mode and a built piece, **When** the run pauses, **Then** it
   shows the piece name, its task IDs, the exact file list, a diff summary for
   those files, and the piece's checkpoint result where the tasks file names
   one.
2. **Given** the answer **go on**, **Then** the piece is committed and the
   next one starts.
3. **Given** the answer **fix this** with a description, **Then** the run makes
   the change and shows the piece again.
4. **Given** the answer **stop here**, **Then** the run parks as `--until`
   does: state intact, lock released, resumable.
5. **Given** the developer edited files during the pause, **Then** those files
   go into the piece's commit and the message lists them as edited by the
   owner.

---

### User Story 4 - A stopped or crashed run resumes at the right piece (Priority: P2)

A run can stop mid-H: a pause answered **stop here**, a commit hook that
rejects a piece, or a crash. Resuming enters the piece `piece-next` names; a
recorded piece is never rebuilt, and a piece that was committed but not yet
recorded is recorded from its commit instead of being built again.

**Why this priority**: Without it, a stop in the middle of H loses work or
duplicates it.

**Independent Test**: Read the resume rules in H and in the Resume section:
each case above is stated and pinned.

**Acceptance Scenarios**:

1. **Given** a piece is recorded, **When** the run resumes, **Then** that
   piece is never built again.
2. **Given** a commit hook rejected a piece, **When** the run stopped, **Then**
   it was a hard stop with the piece uncommitted and recorded in the failure
   entry, `--no-verify` was never used, and resuming shows that piece first.
3. **Given** a run crashed after a piece's commit but before its
   `commit-add`, **When** it resumes, **Then** it recognises the piece in that
   commit and records it with `commit-add`, and does not rebuild it.
4. **Given** a state file without `gates.G.reviewMode`, **When** the run
   resumes into H, **Then** it continues today's single-commit flow and says
   so.

---

### User Story 5 - The document stays true everywhere else (Priority: P3)

Every sentence in `SKILL.md` that this change makes false is rewritten in the
same change: the gate count and floor, the `--auto` flags row, the
never-bend reason for staging by name, the MAY-do paragraph, and the
parallel-agents paragraph.

**Why this priority**: A document that contradicts itself is followed
inconsistently; but each rewrite is small.

**Independent Test**: Grep `SKILL.md` for each claim listed in FR-016 to
FR-020; `prose.bats` pins the new wording.

**Acceptance Scenarios**:

1. **Given** the change, **When** `SKILL.md` is read, **Then** no sentence
   still says a run can reach DONE with no gate stopping it, or that G stops
   only when `implementer` is not pre-answered.

### Edge Cases

- **The constitution file.** A constitution written by an accepted pre-flight
  offer is uncommitted when H starts. It is not part of the spec commit or of
  any piece commit; it stays for K's separate governance commit, as today.
- **Files dirty before a piece starts.** Only files the piece itself changed
  go into its commit. A path already dirty when the piece started is never
  swept in; it is left for K.
- **Ignored paths.** Work a task writes under `.delivery-kit/` (baselines,
  saved outputs) is ignored by git, never staged, and never makes a piece
  "change a file".
- **A heading with quotes, backticks or `$(`.** The piece name travels from
  `piece-next`'s output to `commit-add` as data and is never retyped into a
  command, so the shell never interprets it. Real headings in this repository
  hold double quotes (for example `specs/011-pin-safety-prose/tasks.md`).
- **All pieces recorded on entry.** H has nothing to build and says so.
- **A task-less `## Phase` heading.** `piece-next` never offers it (spec 018),
  so H never commits it.
- **The handoff path.** Unchanged: its package forbids commits, so H there
  keeps the single-commit flow (ruling 22).
- **K in this phase.** Unchanged. Changes made by H.5, H.7, I and J are still
  uncommitted when K runs, and K's existing rule commits them. Phase 21
  changes K. **Known interim gap:** a pieces-mode run in which H.5 to J change
  nothing leaves K an empty file list. K is not changed here, and nothing
  ships between this phase and Phase 21 (pipeline 1.3.0 releases after
  both), so no released run can meet it; Phase 21's K must handle it. The
  same holds for H.7 and I, found at H.5: H.7 is "scoped to `codeRoots`" and
  I reviews "the spec, plan, tasks and diff" without saying which diff. In
  the piece flow most of H is committed before they run, so a working-tree
  diff is nearly empty; Phase 21 must name the range (base to HEAD). They are
  not changed here (FR-026).
  **Also for Phase 21, found at deep review (I):** (a) in commits mode no
  human sees a piece commit's file list before the push, because K shows
  only what is left and L shows the branch, title and body; before 1.3.0
  ships, K or L MUST show every path committed on the branch
  (`<base>..HEAD`), and a piece path outside `codeRoots`, the spec
  directory and `tasks.md` should stop and be shown before it is
  committed — a release blocker; (b) a `--from H` after H.5 would be
  offered H.5's appended phase as a piece until H.5 records it as
  `converge`; (c) a state file tracked in git (`git ls-files .delivery-kit`
  non-empty) hands a re-entry a recorded review answer nobody at the
  keyboard gave; (d) a spec directory the owner already committed under
  another subject leaves the spec commit nothing to commit.

## Requirements *(mandatory)*

### Functional Requirements

**G — the review question**

- **FR-001**: G MUST ask the review question — commits or pauses — once the
  implementer answer resolves to `claude`, whether that answer was asked or
  pre-answered, and MUST record it as `gates.G.reviewMode` with the value
  `commits` or `pauses`.
- **FR-002**: The review question MUST be asked on every run. No
  configuration key or flag pre-answers it in this feature, and `--auto`
  MUST NOT collapse it.
- **FR-003**: When the implementer answer is `handoff`, G MUST NOT ask the
  review question, and MUST say in one line that review pieces are not
  available on the handoff path.
- **FR-004**: A re-entry that finds `gates.G.reviewMode` recorded MUST NOT
  ask it again. If a `--implementer handoff` typed on that re-entry replaces
  a recorded `claude`, the existing G rule applies (the flag wins and the run
  says which answer it replaced); the recorded review answer stays in the
  state file unused, commits already made stand, and the rest of the run
  follows the handoff path's single-commit flow, saying so in the same
  one-line notice as FR-003. No flag replaces the review answer itself.
  *Recorded departure from seed requirement 5* ("holds for the life of the
  run"): the handoff path cannot make commits, so after that flip the answer
  is kept but no longer governs the run.
- **FR-004b**: A re-entry into G whose state file already lists G as
  completed without `gates.G.reviewMode` MUST NOT ask the review question:
  that run started before the question existed, or on the handoff path, and
  keeps the single-commit flow for its life. It is never migrated mid-run
  (ruling 24).
- **FR-005**: The pinned sentence "When `implementer` resolves to `claude` or
  `handoff` (config or flag), G records that answer in `gates` and does not
  stop — the choice was typed on purpose." MUST be rewritten so that it stays
  true: a pre-answered implementer question is still not re-asked, but G
  stops for the review question when the answer is `claude`. Its pin in
  `prose.bats` MUST change in the same commit.

**H — piece by piece**

- **FR-006**: When `gates.G.reviewMode` is recorded, H MUST first commit the
  feature's spec directory alone, as `docs(spec): <feature>`, naming every
  path, and record it with `commit-add` as kind `spec`. A spec commit already
  recorded is not made again; one already on the branch but not recorded (a
  crash) is recorded from that commit, not made again.
- **FR-007**: H MUST then loop: ask `piece-next` for the next piece; build
  that piece's tasks — invoking the implement command limited to that piece's
  task IDs, never unscoped — with today's fan-out rules applying within the
  piece;
  take the exact list of paths the piece changed; commit exactly those paths
  plus `tasks.md`; record the commit with `commit-add` as kind `piece`, with
  the piece name, its task IDs and its files. The loop ends when `piece-next`
  prints nothing. A `piece-next` refusal (no `artifacts.tasks`, a missing
  tasks file, no `## Phase <N>:` heading) is a hard failure: H stops per
  "When a phase fails" and never falls back to the single-commit flow.
- **FR-008**: The paths a piece changed MUST be taken by comparing the
  working tree before and after the piece, listing every file (untracked
  files one by one, renames as a delete plus an add); a path already dirty
  before the piece started MUST NOT be included. (The spec directory is
  committed before the first piece, so no spec-directory path is dirty then
  except by a piece's own work.)
  The "before" list MUST be saved in the state file when the piece starts,
  and the comparison MUST use that saved list — also when the piece is
  resumed after a park, a "stop here" or a crash, when the piece's own edits
  are already dirty in the tree.
- **FR-009**: A piece commit's message MUST follow `commitStyle`, name the
  piece and its task range (for example `feat(<feature>): User Story 1
  (T005–T012)`), and, where the piece changed no file but `tasks.md`, say so.
- **FR-010**: The piece name MUST reach `commit-add` exactly as `piece-next`
  printed it, carried as data and never retyped into a command.
- **FR-011**: `last_task` MUST keep its current meaning.

**Pause mode**

- **FR-012**: In pause mode, after a piece is built and before it is
  committed, H MUST stop and show the piece name, its task IDs, the exact
  file list, a diff summary of those files, and the piece's checkpoint result
  where the tasks file names one. It MUST accept three answers — go on, fix
  this, stop here — with the effects in User Story 3.
- **FR-013**: Files the developer edited during a pause — a path new to the
  shown list, or one whose content changed since it was shown — MUST go into
  that piece's commit and be listed in its message as edited by the owner. A
  path already dirty before the piece started is never swept in this way; it
  stays for K (FR-008). Each pause answer is recorded in the state file, and a
  recorded answer never stops a built, uncommitted piece from being shown
  again on resume.
- **FR-014**: A pause MUST be a safe handoff point, and `--auto` MUST NOT
  collapse it.

**Failure and resume**

- **FR-015**: A commit hook that rejects a piece commit MUST be a hard stop:
  the piece stays uncommitted, the failure entry names the piece, and
  `--no-verify` is never used.
- **FR-016**: On resume or `--from H`, H MUST enter the piece `piece-next`
  names; a recorded piece MUST never be rebuilt; a parked or rejected piece is
  the one shown first, and its files are taken against the "before" list
  saved when it started (FR-008).
- **FR-017**: If a commit in `<base>..HEAD` (the run's own commits, never
  the base branch's history) already holds the piece
  `piece-next` names — a crash between commit and `commit-add` — H MUST
  record that piece from that commit and move on, not rebuild it.
- **FR-018**: A run that enters H — fresh, resumed or `--from H` — with
  implementer `claude` and no `gates.G.reviewMode` in its state file (it
  started on an older pipeline, or it began on the handoff path) MUST continue
  today's single-commit flow, and the run MUST say so. Only a run that has not
  yet completed G is asked the review question on re-entry (FR-001); one that
  completed G without it is never migrated (FR-004b).

**The rest of the document**

- **FR-019**: The "Up to five stops" paragraph and the floor paragraph MUST
  be rewritten: G now stops on every run whose implementer is `claude`, so a
  run can no longer reach DONE with no gate stopping it on that path. The
  gates stay five: the review question lives inside G, and a pause is listed
  beside the conditional stops as a stop the developer chose. The same
  rewrite MUST reach every other sentence in `SKILL.md` that the change makes
  false (measured at F): pre-flight item 9 ("like G whenever `implementer` is
  unset or `ask`"), the `implementer` configuration row and the
  `--implementer` flag row ("Pre-answers the G gate"), the `commitStyle` row
  ("Phase K's message shape"), the floor paragraph's tail ("but no gate
  does") and the paragraph after it, the Implementer row of the gate table,
  and MAY-do's closing sentence ("… cannot be undone by editing a file, is
  behind a gate"), which now covers H's local commits.
- **FR-020**: The `--auto` row of the flags table MUST say that G still stops
  for the review question; its whole-row pin at `prose.bats:66` MUST change
  with it.
- **FR-021**: The never-bend row's reason for `git add -A` MUST say that every
  commit, not only K's, names every path it stages. The row's pinned left
  column MUST NOT change.
- **FR-022**: The MAY-do paragraph MUST list local piece commits (and the spec
  commit) among what the pipeline may do without asking; nothing leaves the
  machine before L.
- **FR-023**: The Parallel agents paragraph MUST say that H's fan-out stays
  within one piece.

**Tests and records**

- **FR-024**: `prose.bats` MUST gain pins for: the review question asked on
  every run and not collapsed by `--auto`; a recorded review answer never
  re-asked; a pause never collapsed by `--auto`; the handoff path's one-line
  notice; the hook hard stop with `--no-verify` forbidden; every commit
  naming every path; the legacy state-file rule; the crash recovery of FR-017;
  the heading carried as data of FR-010; the "before" list saved at piece
  start and used on resume (FR-008); the never-migrated rule of FR-004b; and
  each sentence FR-019 rewrites, with the old wording pinned ABSENT. Each new pin MUST be shown to go red
  under an INVERTED mutant — a sentence asserting the opposite — with the
  mutated line echoed before the red is believed.
- **FR-025**: `pipeline/CHANGELOG.md` MUST gain an `## [Unreleased]` heading
  above `## [1.2.1]`, with an `### Added` entry for piece commits and pause
  mode and a `### Changed` entry stating plainly that G now stops on every run
  whose implementer is `claude`.
- **FR-026**: K, L, DONE, H.5, H.7, I and J MUST NOT change, and no file
  outside `SKILL.md`, `prose.bats` and `pipeline/CHANGELOG.md` changes (plus
  this feature's spec directory).

### Key Entities

- **Review mode**: `commits` or `pauses`, recorded once per run under
  `gates.G.reviewMode`.
- **Piece**: one `## Phase <N>:` section of the run's tasks file that has
  tasks (spec 018).
- **Spec commit / piece commit**: local commits H makes, each recorded with
  `commit-add` (kinds `spec` and `piece`).
- **Before list**: the paths already dirty when a piece starts, saved in the
  state file for that piece and read back on resume (FR-008).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every obligation in FR-001 to FR-024 is stated in `SKILL.md` in
  the section that governs it, and every one listed in FR-024 has a pin that
  goes red under an inverted mutant.
- **SC-002**: The house suite from the repository root goes from `1..226`
  (all passing, measured at `b0b3f1b`) to `1..226+N` with every test passing,
  0 non-TAP lines, and the plan line equal to the pass count; the commit
  message names every added and every changed pin, and for FR-005 and FR-020
  quotes the old sentence and the new.
- **SC-003**: A dry read of the new H against
  `specs/017-guard-config-bounds/tasks.md`, measured with `piece-next`, is
  saved in this feature's directory: the pieces in order, and which change
  only `tasks.md`.
- **SC-004**: No sentence in `SKILL.md` still claims a run can reach DONE with
  no gate stopping it on the `claude` path, or that G stops only when
  `implementer` is not pre-answered — checked by grep with a positive
  control.
- **SC-005**: The branch changes exactly `pipeline/skills/pipeline/SKILL.md`,
  `pipeline/tests/prose.bats`, `pipeline/CHANGELOG.md` and this feature's spec
  directory.

## Assumptions

- **This run executes on the installed pipeline 1.2.1**, which has none of
  this behaviour: its own G asks no review question and its H builds in one
  pass. The change takes effect for runs after the 1.3.0 release.
- **The docs are Phase 22's.** `pipeline/docs/configuration.md:111` ("…
  but the gates do not"), pinned at `prose.bats:195`, becomes false once this
  lands; Phase 22 rewrites it and its pin. It is recorded here so Phase 22
  does not discover it. The changelog's historical entries are never edited.
  **The full list for Phase 22, measured at F (2026-09-29):**
  `pipeline/README.md:64` (the Implementer row) and `:76-80` (the floor
  warning); `README.md:313-317` (the floor warning); `pipeline/docs/phases.md:24-25`
  (G and H rows) and `:38-39` ("an `implementer` already set" as nothing to
  ask); `pipeline/docs/configuration.md:65`, `:79` and `:111`;
  `pipeline/commands/pipeline.md:2` (the description's "a human gate at every
  step that leaves the machine or cannot be undone by editing a file", now
  that H commits locally); and, found at H.5, `pipeline/skills/status/SKILL.md:21-23`
  (step 4 reports G as parked only when `gates` holds no answer, so a run
  whose pre-answered implementer is recorded while G waits at the review
  question, and a run paused inside H, are both reported wrongly).
- **A pause needs a person.** Pause mode on an unattended run simply waits,
  like any other stop; the developer chose it.
- **How the orchestrator detects a committed-but-unrecorded piece** (FR-017)
  and **how it carries the heading as data** (FR-010) are plan decisions; the
  spec fixes only the outcome.
