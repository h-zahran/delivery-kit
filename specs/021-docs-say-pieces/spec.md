# Feature Specification: the documentation says pieces

**Feature Branch**: `021-docs-say-pieces`

**Created**: 2026-09-30

**Status**: Draft

**Input**: User description: "Phase 22: the documentation says pieces" — the Campaign 3 seed in `main-plan.md`, quoted verbatim in `.delivery-kit/runs/021-docs-say-pieces/seed.md`, plus the items Phases 20 and 21 recorded for this phase (spec 019 Assumptions, "The full list for Phase 22"; spec 020 contract, Recorded departures).

## Context

Phases 20 and 21 (specs 019 and 020, merged as PRs #48 and #49, `main` =
`db2875d`) changed what a pipeline run does. G now asks a second question on
every run whose implementer is Claude — **commits** or **pauses** — and no
setting answers it in advance. H commits the spec on its own, then builds and
commits one `tasks.md` phase (a **piece**) at a time; in pause mode it stops
before each piece's commit. H.5, H.7, I and J each end with a commit of their
own. K shows the whole commit list, not one commit. L's pull-request body and
the DONE summary carry a review guide: one row per commit, oldest first. A
fresh run can no longer reach the end without a stop.

The orchestrator document says all this. The user-facing documents mostly
still describe the old run. This feature makes them say what the run does. It
changes no behaviour.

**Measured while writing this spec (2026-09-30, `main` = `db2875d`)**, one
grep per claim over the tracked Markdown and JSON outside `specs/`,
`main-plan.md`, `.specify/` and `docs/` (hits in `pipeline/CHANGELOG.md` and in
the orchestrator are listed apart):

| Claim | Hits in user-facing files |
|---|---|
| "five stops" | `README.md:56` (the pipeline section heading) |
| "five gates" | `README.md:288`, `pipeline/README.md:57` (headings; still true — the gates are five — but the text under them is not) |
| "no gate stopping" / "without a single gate" | `pipeline/docs/configuration.md:109`, `README.md:315`, `pipeline/README.md:78` |
| "pre-answers the implementer gate" | `pipeline/docs/configuration.md:65` and `:79`, `README.md:411`; "Pre-answer the implementer gate" at `README.md:367` and `pipeline/README.md:99` |
| "at clarify only" / "but the gates do not" | `pipeline/docs/configuration.md:82-83`, `:102`, `:111` |
| "unless `implementer` already answered it" / "an `implementer` already set" | `pipeline/docs/phases.md:24` and `:39` |
| "the feature's commit" (singular) | `pipeline/docs/configuration.md:150`; the orchestrator's pre-flight item 9 (`pipeline/skills/pipeline/SKILL.md:249`) |
| "one commit" / "single commit" | no user-facing hit |
| "You choose who implements" / Ship row "Commit, push" | `pipeline/README.md:36` and `:38` |

Also stale, found by reading rather than grep: `pipeline/docs/phases.md` H
row (says nothing of the spec commit, pieces or pause mode), H.5, H.7 and I
rows (say nothing of their own commits), L row (says nothing of the review
guide); `pipeline/skills/status/SKILL.md:21-23` (step 4 calls a gate phase
parked only when `gates` holds no answer for it — wrong for a run waiting at
G's review question with a recorded implementer, and silent on a run paused
inside H, which is not a gate phase).

Found at analysis (F, round 1), and added to the contract:
`pipeline/docs/configuration.md:56` (`commitStyle` "the commit gate shows"),
`:97-98` ("pre-answers the gate"), `:129-130` ("never stages anything outside
the commit gate", false now that H and the late phases commit);
`pipeline/docs/phases.md:31` (L collapsed by `--auto`, silent on L's own
stops); `pipeline/README.md:66` (the same, for L's row), `:84-85` ("the commit
gate names every path"), `:40-41` and `:51` ("which gate it is waiting on");
`README.md:389`
("pre-answers a gate") and the "What to do" cell at `:434`; and the status
skill's own description line. `pipeline/CHANGELOG.md`'s Unreleased section
says K stops under `--auto` but not that L does too.

Pinned by the house suite (so an edit to them edits a pin, not the count):
`pipeline/tests/prose.bats` pins the configuration page's `implementer`
table row whole and the sentence "Cap breaches, a missing required tool, hard
failures and a failed runtime check still stop it, but the gates do not." in
it; it pins the changelog's released 1.1.0 wording too, which is history and
stays.

Phase 21 already corrected five user-facing lines at its review — the K and J
rows of `pipeline/docs/phases.md`, the Commit rows of `README.md` and
`pipeline/README.md`, and the `codeRoots` row of
`pipeline/docs/configuration.md`. They are re-checked here, not assumed.

## Clarifications

### Session 2026-10-01

- Q: Should the tagline "stopping to ask you at every step that leaves your machine or cannot be undone by editing a file" stay as it is, in all five copies? → A: Keep it; it is still true (G's review question is the consent for the local commits, and K shows each commit before anything leaves). No manifest changes.
- Q: How much should the root README say about pieces and the review guide? → A: Fix the false lines, and add one sentence saying a run commits in pieces, linking to the new section in `pipeline/README.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The gate tables tell the truth about G and the floor (Priority: P1)

A developer reads the pipeline README (root or plugin) before running with
`--auto` and `implementer` set. Today it warns them that such a run "can
reach the end without a single gate stopping it" and tells them G is
skippable by the `implementer` setting. Both are false for a Claude run: G
stops for the review question every time. After this feature, the gate
tables and the floor warnings describe G's two questions, say which one a
setting can answer, and state the floor as the orchestrator does.

**Why this priority**: the floor warning is a safety statement. A false one
misleads the reader about when the run will stop, in both directions.

**Independent Test**: grep the four READMEs and the configuration page for
each claim in the Context table; every hit is either gone or rewritten to
match the orchestrator's Gates section.

**Acceptance Scenarios**:

1. **Given** the root and plugin READMEs, **When** a reader looks up the
   Implementer gate row, **Then** it names both questions (who builds; for
   Claude, commits or pauses) and says only the first can be answered by the
   `implementer` setting.
2. **Given** the floor warnings in both READMEs and the configuration page,
   **When** read, **Then** none says a fresh run can reach the end with no
   gate stopping it; each says a fresh Claude run stops at G for the review
   question and a handoff run parks at H, and that a re-entry past G can
   reach the end with no gate.
3. **Given** the `implementer` rows and flag rows, **When** read, **Then**
   they say the setting pre-answers the implementer *question*, not the
   gate.

---

### User Story 2 - The phase reference shows pieces and late commits (Priority: P1)

A developer whose run stopped inside H, or who wants to know what H.5 left
behind, opens `pipeline/docs/phases.md`. After this feature, the G, H, H.5,
H.7, I and L rows say what those phases now do: G's review question; H's spec
commit, one commit per piece and pause mode; each late phase's own commit;
L's review guide. The note under the table no longer lists "an `implementer`
already set" as a gate with nothing to ask.

**Why this priority**: this page is where `--until` and `--from` users go to
learn what a phase leaves behind; commits are exactly that.

**Independent Test**: read each row against the orchestrator's text for that
phase; no row claims less or more than the orchestrator says.

**Acceptance Scenarios**:

1. **Given** the phase table, **When** a reader reads H's row, **Then** it
   names the spec commit, one commit per piece, and pause mode, and says a
   handoff run keeps one commit at K.
2. **Given** the H.5, H.7 and I rows, **When** read, **Then** each says the
   phase ends with a commit of its own when it changed a file.
3. **Given** the L row, **When** read, **Then** it says the pull-request body
   carries the review guide.

---

### User Story 3 - A short guide to reviewing a run commit by commit (Priority: P2)

A reviewer receives a pull request from a pipeline run. After this feature,
the plugin README has a short section telling them what the commits are
(spec, one per piece, the late phases' commits, review and re-verify
commits), where the guide table is, and how to read the branch.

**Why this priority**: the seed asks for it, and it is the payoff of the
whole campaign for the reviewer — but the false claims matter more.

**Independent Test**: the section exists in `pipeline/README.md`, names every
commit kind the orchestrator records, and its links resolve.

**Acceptance Scenarios**:

1. **Given** `pipeline/README.md`, **When** a reviewer looks for how to read
   a run's pull request, **Then** a section tells them to read the review
   guide top to bottom, names each commit kind, and says a handoff run has
   one feature commit, from K, while M's and N's fixes and an accepted
   constitution still get rows of their own.

---

### User Story 4 - The status skill reports a run waiting at the review question or a pause (Priority: P2)

A developer asks `pipeline:status` where a run stands. Today step 4 calls G
parked only when `gates` has no answer for it, so a Claude run waiting at the
review question (implementer recorded, review answer not) is reported as not
waiting, and a run paused inside H is never reported as waiting. After this
feature, step 4 names both.

**Why this priority**: the status skill is prose an agent follows; a wrong
instruction there gives a wrong answer to "what do I type next".

**Independent Test**: read step 4 against the orchestrator's G and H pause
text; both waits are named.

**Acceptance Scenarios**:

1. **Given** a state file with `current_phase` G, `gates.G.answer` `claude`
   and no `gates.G.reviewMode`, **When** the status skill's step 4 is
   followed, **Then** it reports the run waiting at G's review question.
2. **Given** a state file with `current_phase` H and `gates.G.reviewMode`
   `pauses`, **When** step 4 is followed, **Then** it says the run stops
   before each piece's commit in this mode, so a run left at H is most likely
   waiting at a pause, and it names the pause answers recorded under
   `gates.H.pauses` so far. (The state file records answers, not a pause
   that is showing; the skill says so rather than guess.)

---

### Edge Cases

- A claim that is still true in one place and false in another (for example
  "five gates" as a heading is true; the text under it is not) is judged per
  hit, and the grep hit list records the verdict for each.
- History is never edited: released `pipeline/CHANGELOG.md` sections and the
  prose pins on them stay byte-identical. Only `## [Unreleased]` may change,
  and only where the P20/P21 entries are incomplete.
- The tagline, in its three wordings — the long form "stopping to ask you at
  every step that leaves your machine or cannot be undone by editing a file"
  (`pipeline/README.md:3-5`), the short form "… at every step that leaves
  your machine." (`README.md:26`, `pipeline/.claude-plugin/plugin.json`,
  `.claude-plugin/marketplace.json`), and "with a human gate at every step
  that leaves the machine or cannot be undone by editing a file"
  (`pipeline/commands/pipeline.md:2`) — stays true: the orchestrator names G's review question as the consent for
  the local commits H and the late phases make, and K shows each before
  anything leaves. It is left as is (owner's answer at C).
- A handoff run keeps the single-commit flow. Every rewritten sentence that
  describes pieces must not make the handoff path sound like it has them.
- A run started on pipeline 1.2.1 keeps 1.2.1's behaviour. The documents
  describe 1.3.0; they need not describe the migration beyond one clause.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `pipeline/docs/phases.md` MUST describe G's review question
  (commits or pauses, asked on every fresh Claude run, never pre-answered), H's
  spec commit, per-piece commits and pause mode, the late commits of H.5,
  H.7, I and J, K's commit list and L's review guide; and the note under the
  table MUST NOT list "an `implementer` already set" as a gate with nothing
  to ask (a pre-answered `handoff` is one).
- **FR-002**: `pipeline/docs/configuration.md`'s `implementer` row and its
  "The implementer key" section MUST say the key pre-answers the implementer
  question only, that a Claude run still stops at G for the review question,
  and MUST restate the range of stops so it matches the orchestrator's Gates
  section: no fresh run reaches the end without a stop; a re-entry past G
  can. The sentence pinned by the house suite MUST keep its role (the list of
  what still stops a run) and its pin MUST change with it.
- **FR-003**: `pipeline/README.md`'s gate table, `--auto` notes, floor warning
  and flag row MUST describe G's two questions and the floor as FR-002 does;
  its Build and Ship rows MUST say where commits are made.
- **FR-004**: `pipeline/README.md` MUST gain a short section on reviewing a
  run commit by commit: the review guide, the commit kinds, and the handoff
  exception.
- **FR-005**: `README.md` MUST describe the pipeline with its gates and stops
  truthfully: the section heading at `:56` MUST NOT say "five stops"; the
  gate table, the floor warning, the configuration table row and the flag row
  MUST match FR-002 and FR-003. It MUST gain one sentence, no more, saying a
  run commits in pieces, linked to FR-004's section in `pipeline/README.md`.
- **FR-006**: `pipeline/skills/status/SKILL.md` step 4 MUST report a run
  waiting at G's implementer or review question, at K (`gates.K.answer`
  absent, since K now records its list before its answer), parked at H for a
  handoff report, or in pause mode left at H, and a recorded failure entry;
  its description line MUST say gate or pause.
- **FR-007**: The singular "the feature's commit" MUST become plural where
  the run now makes several — the orchestrator's pre-flight item 9 and
  `pipeline/docs/configuration.md:150` — and nothing else in the orchestrator
  changes.
- **FR-008**: `pipeline/CHANGELOG.md` MUST change only under
  `## [Unreleased]`, and only where a P20 or P21 entry is incomplete about a
  user-visible behaviour; released sections MUST stay byte-identical.
- **FR-009**: For each claim — "five stops", "no gate stopping", "K commits",
  "one commit", "pre-answers the implementer gate" (with its variants
  "pre-answer the implementer gate", "pre-answers the gate", "pre-answers a
  gate") — the grep command and its hit list MUST be in the commit message,
  each grep first fired against a known hit as a positive control, and each
  run over flattened files so a phrase wrapped across lines is found.
- **FR-010**: The link checker MUST stay green, and every new link MUST
  resolve, anchors included.
- **FR-011**: The house suite MUST keep P21's count, `1..240`, with 0 not ok
  and 0 non-TAP: this feature adds and removes no test; it only edits the
  pins whose sentences it rewrites.
- **FR-012**: Every rewritten sentence MUST agree with the orchestrator; where
  a document and the orchestrator differ, the orchestrator wins and the
  document changes.
- **FR-013**: Every changed line on a STRICT surface (`pipeline/README.md`,
  `pipeline/CHANGELOG.md`, `pipeline/docs/`, `pipeline/commands/`,
  `.claude-plugin/` and the root documents) MUST avoid the banned whole words
  `flutter|dart|pubspec|supabase|gradle|graphify|speckit|superpowers` (write
  "spec-kit"), and on a RELAXED surface (`pipeline/skills/`) the words
  `supabase|graphify|superpowers`; and no changed line MAY state a count of
  tests, suites or plugins that the next change would make false.

### Key Entities

- **Claim**: a sentence shape the seed names, with its grep, its positive
  control and its hit list.
- **Site**: one file and line where a claim, or a stale description found by
  reading, appears; judged false, true, or history.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Each of the five seed claims, grepped over the user-facing
  files, returns zero false hits (a hit that is true, or history, is listed
  with its reason).
- **SC-002**: Every site in the Context table and every stale row found by
  reading is rewritten or recorded as true, with none left unjudged.
- **SC-003**: The house suite reports `1..240`, 240 ok, 0 not ok, 0 non-TAP,
  from the repo root.
- **SC-004**: The link checker is green.
- **SC-005**: No released changelog byte and no orchestrator sentence other
  than pre-flight item 9 changes (checked by diff against `db2875d`).

## Assumptions

- **This run executes on the installed pipeline 1.2.1.** Its own G asks no
  review question and its K makes one commit; that does not change what the
  documents must say about 1.3.0.
- **The tagline stays** (see Edge Cases; the owner confirmed it at C). No
  manifest changes.
- **"five gates" headings stay.** The gates are still five; a pause is a stop
  the developer chose, not a sixth gate, as the orchestrator says.
- **The orchestrator is the source of truth.** This feature does not revisit
  any P20/P21 behaviour; a document that disagrees with the orchestrator is
  wrong.
- **Scope is the documents plus the status skill and item 9.** Other
  orchestrator wording is P20's and P21's, already reviewed; the release
  (version bump, changelog fold) is Phase 23's.
