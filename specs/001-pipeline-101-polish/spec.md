# Feature Specification: pipeline 1.0.1 — release-day truth and door polish

**Feature Branch**: `001-pipeline-101-polish`

**Created**: 2026-08-21

**Status**: Draft

**Input**: User description: "Phase 1: pipeline 1.0.1 — release-day truth and door polish. Five agreed fixes from the 2026-08-21 live-run review, plus the 1.0.1 stamp, in one run. All edits are additive prose; no behavior changes."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The release gate tells the truth when there is nothing to release (Priority: P1)

An operator runs the pipeline in a repository whose configuration leaves `releaseCommand` unset. The run reaches the O — release gate. Today the orchestrator text only describes showing a command; it does not say what an honest O looks like with no command configured. After this change, the O paragraph says it plainly: nothing to publish, record that, move on.

**Why this priority**: This is the exact situation the 2026-08-21 live field run hit. It is the "release-day truth" the version name promises, and it touches the least reversible phase.

**Independent Test**: Grep `pipeline/skills/pipeline/SKILL.md` for the new O sentence; it is present verbatim, and the O paragraph's existing sentences are byte-identical to before.

**Acceptance Scenarios**:

1. **Given** the shipped orchestrator text, **When** one greps for "With `releaseCommand` unset there is nothing to publish: record that in the state file and move on — the gate guards a command, it does not invent one.", **Then** exactly that sentence is found in the O — release paragraph, after its previously final sentence.
2. **Given** the shipped orchestrator text, **When** the prose pin suite runs (`pipeline/tests/prose.bats`), **Then** all pinned strings still pass (1..8 ok).

---

### User Story 2 - Honest extra verification and safe gate hygiene (Priority: P2)

An operator's run does real verification beyond the configured strategy (N.5), or changes its answer at the implementer gate after a handoff package was written (G), or needs a tool the machine lacks (Ground rules). Today the orchestrator is silent on all three. After this change it says: extra verification is welcome and reported as exactly what it is; a stale handoff package is deleted or stamped VOID; a missing tool is its own question — named, with the install command shown, never installed silently.

**Why this priority**: All three close honesty gaps the live run surfaced, but none sits on the release path itself.

**Independent Test**: Three greps on `pipeline/skills/pipeline/SKILL.md`, one per new sentence/bullet; each is found verbatim; the pinned sentence `It never reports verification it did not do` is byte-identical.

**Acceptance Scenarios**:

1. **Given** the shipped orchestrator text, **When** one greps for "Verification beyond the configured strategy is welcome when it is real — run it, then report it as exactly what it is: extra evidence, not the configured check.", **Then** it is found in the N.5 — runtime check section, after the sentence ending "then continue."
2. **Given** the shipped orchestrator text, **When** one greps for "If the gate's answer later changes, delete the written package file (or stamp it VOID at the top) before proceeding — a stale package addressed to another model is an instruction nobody should find.", **Then** it is found in the G — implementer gate paragraph.
3. **Given** the shipped orchestrator text, **When** one greps for "**A missing tool is its own question.**", **Then** a new Ground rules bullet is found carrying: "When the run needs a tool the machine lacks, stop: name the tool, show the exact install command, and record the answer in the state file. Never install anything silently."
4. **Given** the shipped orchestrator text, **When** one greps for "It never reports verification it did not do", **Then** the sentence is present byte-identically.

---

### User Story 3 - The README's front-door spelling is measured, not assumed (Priority: P3)

A new user reads `pipeline/README.md` "How it runs" and types an example invocation. Only `/pipeline:pipeline` has been observed to resolve in the field; the short form `/pipeline` is unmeasured. After this change, the three example invocations use the canonical namespaced spelling, and any sentence about the short form exists only if a live-session measurement proved what it claims — no claim at all if it cannot be determined.

**Why this priority**: A wrong invocation in the README fails every new user at the door, but the fix is one file and carries a measure-first rule that must not be skipped.

**Independent Test**: Read the "How it runs" section: all three examples spell `/pipeline:pipeline …`; any short-form sentence is backed by a measurement recorded in this run's artifacts.

**Acceptance Scenarios**:

1. **Given** the updated README, **When** one reads the three example invocations in "How it runs", **Then** each uses `/pipeline:pipeline …`.
2. **Given** a live-session measurement of the short form, **When** the measurement proves resolution or non-resolution, **Then** the README carries whichever sentence is true — and no sentence when the result is indeterminate.

---

### User Story 4 - The 1.0.1 stamp agrees everywhere (Priority: P1)

A user installing or updating the plugin sees one version, everywhere it is declared.

**Why this priority**: A stamp that disagrees across its three sites breaks install tooling and trust; it is also the release artifact of this whole phase.

**Independent Test**: One `jq` line over the marketplace manifest plus a read of the plugin manifest and the changelog heading.

**Acceptance Scenarios**:

1. **Given** the stamped tree, **When** one runs `jq -r '.plugins[] | "\(.name) \(.version)"' .claude-plugin/marketplace.json`, **Then** it prints `handoff 2.1.0` and `pipeline 1.0.1`.
2. **Given** the stamped tree, **When** one reads `pipeline/.claude-plugin/plugin.json`, **Then** its version is `1.0.1`.
3. **Given** the stamped changelog, **When** one reads `pipeline/CHANGELOG.md`, **Then** a heading `## [1.0.1] - <ship day>` sits above `## [1.0.0] …` (shipped: `## [1.0.1] - 2026-08-22`), its entries describe the fixes, and no entry states a count that a later change falsifies.

### Edge Cases

- Pinned strings: every grep-pinned string in the orchestrator must survive byte-for-byte — all additions are "add near, never reword".
- Vocabulary: `pipeline/README.md` and `pipeline/CHANGELOG.md` are STRICT surfaces (hyphenated spec-tool spellings only; banned whole words per Global Constraints); the orchestrator skill file and its tests are RELAXED.
- The short-form measurement is indeterminate: the README then carries no short-form claim at all — silence is the correct output.
- Count-free prose: the changelog entry must not state "five fixes" or any other count a later change falsifies (the seed's own wording is for humans, not for the shipped file).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The O — release paragraph of `pipeline/skills/pipeline/SKILL.md` MUST gain, after its final sentence: "With `releaseCommand` unset there is nothing to publish: record that in the state file and move on — the gate guards a command, it does not invent one."
- **FR-002**: The N.5 — runtime check section MUST gain, after the sentence ending "then continue.": "Verification beyond the configured strategy is welcome when it is real — run it, then report it as exactly what it is: extra evidence, not the configured check." The pinned sentence `It never reports verification it did not do` MUST stay byte-identical.
- **FR-003**: The G — implementer gate paragraph MUST gain: "If the gate's answer later changes, delete the written package file (or stamp it VOID at the top) before proceeding — a stale package addressed to another model is an instruction nobody should find."
- **FR-004**: The Ground rules list MUST gain one bullet: "**A missing tool is its own question.** When the run needs a tool the machine lacks, stop: name the tool, show the exact install command, and record the answer in the state file. Never install anything silently."
- **FR-005**: `pipeline/README.md` "How it runs" MUST be updated only after a live-session measurement of whether `/pipeline` resolves: the three example invocations use `/pipeline:pipeline …`, and a short-form sentence exists only if the measurement proved it resolves — whichever sentence is true, and no claim at all if the result cannot be determined.
- **FR-006**: The 1.0.1 stamp MUST land in three places and agree: `pipeline/.claude-plugin/plugin.json` version `1.0.1`; the pipeline entry in `.claude-plugin/marketplace.json` version `1.0.1`; `pipeline/CHANGELOG.md` gains `## [1.0.1] - <ship day>` (shipped: 2026-08-22) above `## [1.0.0] …`, listing the fixes count-free.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Each new sentence from FR-001 through FR-004 is findable by exact grep in its named file.
- **SC-002**: The prose pin suite passes: `bash /c/Users/h_zah/bats/bin/bats pipeline/tests/prose.bats` reports 1..8, all ok.
- **SC-003**: The full house suite passes from the repository root: `1..116`, 116 ok, 0 non-TAP lines.
- **SC-004**: `jq -r '.plugins[] | "\(.name) \(.version)"' .claude-plugin/marketplace.json` prints `handoff 2.1.0` and `pipeline 1.0.1`, and `pipeline/.claude-plugin/plugin.json` agrees.
- **SC-005**: The README's three example invocations read `/pipeline:pipeline …`, and any short-form claim is traceable to a recorded measurement.

## Assumptions

- All six requirements ship in one run and one pull request; the owner merges and tags `pipeline-v1.0.1` afterward.
- The suite count stays 116: this phase adds no tests and removes none.
- The exact sentences in FR-001 through FR-004 are contract text, quoted verbatim from the plan of record (`main-plan.md`, Phase 1 section); they are to be inserted character-for-character.
- The stamp date is the ship day — the day the commit gate runs (shipped 2026-08-22; the merge day cannot be known at that gate). If the merge slips materially, re-dating is the owner's call at merge time, not a gate's.
- Global Constraints of the plan of record apply throughout (pinned strings, STRICT/RELAXED vocabulary, count-free prose, changelog heading shape).
- Mid-run owner ruling (recorded in the run state file, `gates["H.7"]` and phase I): beyond the FR list, the owner ordered review findings fixed in this run, in unpinned text only — a scoping paragraph under the FR-004 bullet (required-vs-optional tools, the state-write carve-out, the human runs the install), a package-location and VOID-preference note in the G paragraph plus a cross-reference on the idempotency rule, the "Up to five stops" requalification in the Gates section and README (with the closed C/O list), the "missing required tool" conditional stop, the N.5 no-invented-command tie-back, and a matching changelog bullet. The scoping paragraph narrows the face value of FR-004's sentence for the pre-flight moment when no state file exists; the contract sentences themselves are untouched (verified byte-identical).
