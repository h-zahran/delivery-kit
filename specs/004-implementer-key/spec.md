# Feature Specification: pre-answer the implementer gate — the loop closes

**Feature Branch**: `004-implementer-key`

**Created**: 2026-08-23

**Status**: Draft

**Input**: User description: "Phase 4 of the dogfood plan — pre-answer the implementer gate, the loop closes. With this key set, a run under --auto touches the human at clarify only."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A typed choice pre-answers the G gate (Priority: P1)

An operator who always wants the same implementer sets the new `implementer` configuration key (or passes the new `--implementer` flag) once. From then on, a run reaching the G gate finds the choice already typed: G records the configured answer in the state file's `gates` key and does not stop. Under `--auto`, the run now touches the human at clarify only. Unset means what it means today: G asks.

> **SCOPED at H.7 and phase I (2026-08-23)**: "touches the human at clarify only" is a CEILING, not a promise of a stop. It holds for `claude`; with `handoff` the run parks at H instead. And where clarify raises no questions and `releaseCommand` is unset, an `--auto` run reaches DONE with no gate stopping it at all. The shipped prose in `SKILL.md`, `configuration.md` and the changelog states that floor; this requirement's wording is the pre-H.7 record. Raised by the phase I contract lens (M6) and security lens (Important 1).

**Why this priority**: This closes the loop the dogfood plan named — every other gate already collapses or records; G was the last always-stop with a pre-answerable question.

**Independent Test**: With the key unset, G stops and asks (unchanged behavior). With `implementer` set to `claude` or `handoff` (config or flag), the G section's new sentences instruct recording without stopping, and everything else about G is byte-identical.

**Acceptance Scenarios**:

1. **Given** `implementer` unset, **When** a run reaches G, **Then** the gate stops and asks exactly as before — the new sentences change nothing for the unset path.
2. **Given** `implementer` set (config or flag), **When** a run reaches G, **Then** the orchestrator's G section carries, verbatim, the quoted sentence pair: "When `implementer` is set (config or flag), G records the configured answer in `gates` and does not stop — the choice was typed on purpose. Everything else about G is unchanged, and a set `implementer` silences nothing else: cap breaches, hard failures and every other gate still stop exactly as before."
3. **Given** both the config key and the flag set to different values, **When** configuration resolves at pre-flight, **Then** the flag wins (standard precedence — flags beat config files).

---

### User Story 2 - The key reads identically everywhere it is documented (Priority: P2)

A reader finds the `implementer` key in FOUR places: the orchestrator's Configuration table, the orchestrator's Flags table (as `--implementer <claude|handoff>`), and `pipeline/docs/configuration.md`'s JSON block and key table. The names and defaults are character-identical across the two files, and the docs page explains the key in one paragraph: what it pre-answers, that unset means ask, and that it exists so an `--auto` run touches the human at clarify only.

> **SCOPED at H.7 and phase I (2026-08-23)**: "touches the human at clarify only" is a CEILING, not a promise of a stop. It holds for `claude`; with `handoff` the run parks at H instead. And where clarify raises no questions and `releaseCommand` is unset, an `--auto` run reaches DONE with no gate stopping it at all. The shipped prose in `SKILL.md`, `configuration.md` and the changelog states that floor; this requirement's wording is the pre-H.7 record. Raised by the phase I contract lens (M6) and security lens (Important 1).

**Why this priority**: The two files have drifted before; the plan of record makes character-identity an acceptance criterion, not a hope.

**Independent Test**: Extract the key's rows from both files and compare character-for-character; read the docs paragraph.

**Acceptance Scenarios**:

1. **Given** the four documentation sites, **When** the key's name and default are extracted from each, **Then** they are character-identical across `pipeline/skills/pipeline/SKILL.md` and `pipeline/docs/configuration.md`.
2. **Given** `pipeline/docs/configuration.md` (a STRICT vocabulary surface), **When** its new paragraph is read, **Then** it states what the key pre-answers, that unset means ask, and the clarify-only purpose — with no banned spellings.

---

### User Story 3 - The changelog records the change (Priority: P3)

A reader of `pipeline/CHANGELOG.md` finds an Added entry under `## [Unreleased]` for the new key and flag. No version stamp.

**Why this priority**: `[Unreleased]` accumulates until the 1.1.0 release phase.

**Independent Test**: The entry exists under `[Unreleased]`; `[Unreleased]` still sits above `[1.0.1]`; no new version heading.

**Acceptance Scenarios**:

1. **Given** the changelog after this change, **When** its headings are listed, **Then** `[Unreleased]` (with the new entry) is above `[1.0.1]` and no version heading was added.

---

### Edge Cases

- An illegal `implementer` value (anything but `claude` or `handoff`) is a configuration error surfaced at pre-flight by name — never silently coerced to a legal value, and never treated as unset (a typo must not silently turn an intended pre-answer back into a stop, nor a stop into an answer).
- The G gate row `| Implementer | G |` in the Gates table stays byte-identical — the key changes when G stops, not what G is.
- A set `implementer` silences ONLY the G stop: the constitution offer, clarify questions, cap breaches, hard failures, K/L (when not `--auto`), and O all stop exactly as before.
- NO suite growth this phase: the full house suite stays `1..119` and prose stays `1..9` — any movement is a finding. (Test debt for the new prose is recorded, not spent, this phase.)
- `handoff/**` is untouched (plan Decision 4): the handoff plugin's setup skill does NOT learn this key in this plan.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The configuration key `implementer` MUST exist with default unset and legal values `claude` and `handoff`, documented in the orchestrator's Configuration table and in `pipeline/docs/configuration.md`'s JSON block and key table — names and defaults character-identical across the two files.
- **FR-002**: The flag `--implementer <claude|handoff>` MUST exist, documented in the orchestrator's Flags table, and MUST beat the config key (standard precedence, matching the existing resolution order).
- **FR-003**: The orchestrator's G paragraph MUST gain, verbatim, the quoted sentence pair: "When `implementer` is set (config or flag), G records the configured answer in `gates` and does not stop — the choice was typed on purpose. Everything else about G is unchanged, and a set `implementer` silences nothing else: cap breaches, hard failures and every other gate still stop exactly as before." Added near; no existing sentence reworded.
- **FR-004**: `pipeline/docs/configuration.md` MUST explain the key in one paragraph: what it pre-answers, that unset means ask, and that it exists so an `--auto` run touches the human at clarify only. STRICT vocabulary surface.

> **SCOPED at H.7 and phase I (2026-08-23)**: "touches the human at clarify only" is a CEILING, not a promise of a stop. It holds for `claude`; with `handoff` the run parks at H instead. And where clarify raises no questions and `releaseCommand` is unset, an `--auto` run reaches DONE with no gate stopping it at all. The shipped prose in `SKILL.md`, `configuration.md` and the changelog states that floor; this requirement's wording is the pre-H.7 record. Raised by the phase I contract lens (M6) and security lens (Important 1).
- **FR-005**: `pipeline/CHANGELOG.md` MUST gain an Added entry under the existing `## [Unreleased]` heading for the key and flag. No version stamp.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The `implementer` key/flag rows are present and character-identical across `pipeline/skills/pipeline/SKILL.md` and `pipeline/docs/configuration.md` (extracted and diffed).
- **SC-002**: All previously pinned strings survive: `pipeline/tests/prose.bats` reports `1..9`, 9 ok, and the G gate row `| Implementer | G |` is byte-identical.
- **SC-003**: The full house suite reports `1..119`, 119 ok, 0 non-TAP — growth exactly zero.
- **SC-004**: The run's own field test: THIS phase is executed with the G answer "handoff" — the package is written, the run parks at H, an external implementer executes the package, and `--resume` consumes its report. The park and resume evidence is recorded in the run's artifacts.

## Assumptions

- Precedence needs no new machinery: the existing resolution order (defaults → user config → repo config → `--config` → individual flags) already places flags last-wins; the key and flag slot into it.
- "Character-identical" binds the key name, the value set, and the default — not the surrounding prose, which serves different audiences in the two files.
- `pipeline/skills/pipeline/SKILL.md` and `pipeline/tests/` are RELAXED vocabulary surfaces; `pipeline/CHANGELOG.md` and `pipeline/docs/configuration.md` are STRICT.
- Global Constraints of the plan of record apply; no version stamp this phase.
- SC-004's external implementer is any cheap model the owner picks; its work lands uncommitted per the package's Report-back contract, and this run's K commits it only after the resume's verification.
