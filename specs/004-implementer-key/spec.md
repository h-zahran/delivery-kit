# Feature Specification: pre-answer the implementer gate — the loop closes

**Feature Branch**: `004-implementer-key`

**Created**: 2026-08-23

**Status**: Draft

**Input**: User description: "Phase 4 of the dogfood plan — pre-answer the implementer gate, the loop closes. With this key set, a run under --auto touches the human at clarify only."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A typed choice pre-answers the G gate (Priority: P1)

An operator who always wants the same implementer sets the new `implementer` configuration key (or passes the new `--implementer` flag) once. From then on, a run reaching the G gate finds the choice already typed: G records the configured answer in the state file's `gates` key and does not stop. Under `--auto`, the run now touches the human at clarify only. Unset means what it means today: G asks.

> **SCOPED at H.7 and phase I, revised at phase M rounds 1-3 (2026-08-23)**: "touches the human at clarify only" is one point on a range — neither a promise of a stop nor an upper bound (it was annotated as a CEILING until a round-3 reviewer noted cases sit ABOVE it). Above it: the release gate stops whenever `releaseCommand` is set and `--auto-release` was not typed, and the pre-flight constitution offer stops whenever the constitution is unset. Below it: with `--auto`, no clarify questions, `releaseCommand` unset, the constitution set and a remote to push to, a run reaches DONE with no gate stopping it at all. It holds for `claude`; with `handoff` the run parks at H instead. The shipped prose in `SKILL.md`, `configuration.md` and the changelog states that range, and the "one paragraph" FR-004 requires shipped as THREE. This requirement's wording is the pre-H.7 record. Raised by the phase I contract lens (M6) and security lens (Important 1).

**Why this priority**: This closes the loop the dogfood plan named — every other gate already collapses or records; G was the last always-stop with a pre-answerable question.

**Independent Test**: With the key unset, G stops and asks (unchanged behavior). With `implementer` set to `claude` or `handoff` (config or flag), the G section's new sentences instruct recording without stopping, and everything else about G is byte-identical.

> **SUPERSEDED at phase M round 1 (2026-08-23)**: G's "STOP AND ASK" lead WAS reworded — it had become false — so "everything else about G is byte-identical" no longer holds. The pinned sentence pair and the Gates-table row remain byte-identical, which is what the tests and the contract actually guard. See `tasks.md`, phase M round 1.

**Acceptance Scenarios**:

1. **Given** `implementer` unset, **When** a run reaches G, **Then** the gate stops and asks exactly as before — the new sentences change nothing for the unset path.
2. **Given** `implementer` set (config or flag), **When** a run reaches G, **Then** the orchestrator's G section carries, verbatim, the quoted sentence pair *(REWORDED TWICE at phase M round 4 — adding `ask` made "when `implementer` is set … does not stop" false, since `ask` is set and G does stop; the shipped text is in `contracts/key-contract.md`, and it is four sentences)*: "When `implementer` is set (config or flag), G records the configured answer in `gates` and does not stop — the choice was typed on purpose. Everything else about G is unchanged, and a set `implementer` silences nothing else: cap breaches, hard failures and every other gate still stop exactly as before."
3. **Given** both the config key and the flag set to different values, **When** configuration resolves at pre-flight, **Then** the flag wins (standard precedence — flags beat config files).

---

### User Story 2 - The key reads identically everywhere it is documented (Priority: P2)

A reader finds the `implementer` key in FIVE places (FOUR as originally specified, plus `pipeline/README.md`, added at phase M round 4 on the owner's instruction — the plugin's front door describes the consent model and was silent on a key that removes one of its five stops): the orchestrator's Configuration table, the orchestrator's Flags table (as `--implementer <claude|handoff|ask>`), `pipeline/docs/configuration.md`'s JSON block and key table, and — since phase M round 4 — a sentence in `pipeline/README.md`. The names and defaults are character-identical across the orchestrator and the configuration page, and the docs page explains the key in one paragraph: what it pre-answers, that unset means ask, and that it exists so an `--auto` run touches the human at clarify only.

> **SCOPED at H.7 and phase I, revised at phase M rounds 1-3 (2026-08-23)**: "touches the human at clarify only" is one point on a range — neither a promise of a stop nor an upper bound (it was annotated as a CEILING until a round-3 reviewer noted cases sit ABOVE it). Above it: the release gate stops whenever `releaseCommand` is set and `--auto-release` was not typed, and the pre-flight constitution offer stops whenever the constitution is unset. Below it: with `--auto`, no clarify questions, `releaseCommand` unset, the constitution set and a remote to push to, a run reaches DONE with no gate stopping it at all. It holds for `claude`; with `handoff` the run parks at H instead. The shipped prose in `SKILL.md`, `configuration.md` and the changelog states that range, and the "one paragraph" FR-004 requires shipped as THREE. This requirement's wording is the pre-H.7 record. Raised by the phase I contract lens (M6) and security lens (Important 1).

**Why this priority**: The two files have drifted before; the plan of record makes character-identity an acceptance criterion, not a hope.

**Independent Test**: Extract the key's rows from both files and compare character-for-character; read the docs paragraph.

**Acceptance Scenarios**:

1. **Given** the four table and JSON documentation sites (the README sentence is prose, not a pinned string), **When** the key's name and default are extracted from each, **Then** they are character-identical across `pipeline/skills/pipeline/SKILL.md` and `pipeline/docs/configuration.md`.
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

- An illegal `implementer` value (none of `claude`, `handoff` or `ask`) is a configuration error surfaced at pre-flight by name — never silently coerced to a legal value, and never treated as unset (a typo must not silently turn an intended pre-answer back into a stop, nor a stop into an answer).

  > **CORRECTED in the product at phase M round 1 (2026-08-23)**: "anything but `claude` or `handoff`" fires on the documented default, `null`, which IS "anything but" — read literally it stopped every run in existence. The shipped orchestrator now says "a value that is none of `claude`, `handoff` or `ask` — unset is not a value and never stops anything" (it read "neither `claude` nor `handoff`" until round 4 added `ask`). This requirement's trailing clause already implied it; the wording here is the pre-correction record.
- The G gate row `| Implementer | G |` in the Gates table stays byte-identical — the key changes when G stops, not what G is.
- A pre-answered `implementer` (`claude` or `handoff`) silences ONLY the G stop; `ask` silences nothing: the constitution offer, clarify questions, cap breaches, hard failures, K/L (when not `--auto`), and O all stop exactly as before.
- NO suite growth this phase: the full house suite stays `1..119` and prose stays `1..9` — any movement is a finding. (Test debt for the new prose is recorded, not spent, this phase.)

  > **SUPERSEDED at phase M round 4, owner-ordered (2026-08-23)**: the debt WAS spent — prose `1..11`, house `1..121`, two new tests, mutation-verified. Any OTHER movement is still a finding. Same override as SC-002 and SC-003 above.
- `handoff/**` is untouched (plan Decision 4): the handoff plugin's setup skill does NOT learn this key in this plan.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001** *(value set widened to `claude`, `handoff`, `ask` at phase M round 4 — see FR-002's note)*: The configuration key `implementer` MUST exist with default unset and legal values `claude`, `handoff` and `ask`, documented in the orchestrator's Configuration table and in `pipeline/docs/configuration.md`'s JSON block and key table — names and defaults character-identical across the two files.
- **FR-002**: The flag `--implementer <claude|handoff|ask>` MUST exist, documented in the orchestrator's Flags table, and MUST beat the config key (standard precedence, matching the existing resolution order).

  > **AMENDED at phase M round 4, owner-ordered (2026-08-23)**: the value set is now `claude`, `handoff`, `ask`. `ask` is the command-line re-arm the phase I security lens asked for (Important 3) and this run had deferred as a specification change — the owner overrode the review cap with "fix everything, no deferred", which makes it one. Without it, an operator inheriting a tracked `implementer` had no route back to a stopping gate. The contract's four pinned strings and its verbatim G pair were re-pinned in the same pass; see `contracts/key-contract.md`.
- **FR-003**: The orchestrator's G paragraph MUST gain, verbatim, the quoted sentence pair: "When `implementer` is set (config or flag), G records the configured answer in `gates` and does not stop — the choice was typed on purpose. Everything else about G is unchanged, and a set `implementer` silences nothing else: cap breaches, hard failures and every other gate still stop exactly as before." Added near; no existing sentence reworded.

> **OVERRIDDEN at phase M round 1 (2026-08-23)**: SEVEN pre-existing regions WERE reworded — the `--auto` flags row, the G section's "STOP AND ASK" lead, pre-flight item 9's "like C and G" clause and the probe block's render instruction at phase M rounds 1-2; the Gates paragraph at phase I; and, at round 4, the Configuration section's "`null` means *work it out*" line and the H-park paragraph's "the answer stands, on this path and every other" sentence. The count read "four", then "five", before reviewers found the sixth and seventh — which is itself the annotate-one-instance asymmetry this run kept repeating. Each had been made FALSE by this diff, and two independent reviewers measured that none of them is pinned by any test or by this contract. A sentence this change made false is not protected churn — the same ground on which H.7 reworded the docs section. Recorded as a deliberate override, not an oversight; see `tasks.md`, phase M round 1.
- **FR-004**: `pipeline/docs/configuration.md` MUST explain the key in one paragraph: what it pre-answers, that unset means ask, and that it exists so an `--auto` run touches the human at clarify only. STRICT vocabulary surface.

> **SCOPED at H.7 and phase I, revised at phase M rounds 1-3 (2026-08-23)**: "touches the human at clarify only" is one point on a range — neither a promise of a stop nor an upper bound (it was annotated as a CEILING until a round-3 reviewer noted cases sit ABOVE it). Above it: the release gate stops whenever `releaseCommand` is set and `--auto-release` was not typed, and the pre-flight constitution offer stops whenever the constitution is unset. Below it: with `--auto`, no clarify questions, `releaseCommand` unset, the constitution set and a remote to push to, a run reaches DONE with no gate stopping it at all. It holds for `claude`; with `handoff` the run parks at H instead. The shipped prose in `SKILL.md`, `configuration.md` and the changelog states that range, and the "one paragraph" FR-004 requires shipped as THREE. This requirement's wording is the pre-H.7 record. Raised by the phase I contract lens (M6) and security lens (Important 1).
- **FR-005**: `pipeline/CHANGELOG.md` MUST gain an Added entry under the existing `## [Unreleased]` heading for the key and flag. No version stamp.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The `implementer` key/flag rows are present and character-identical across `pipeline/skills/pipeline/SKILL.md` and `pipeline/docs/configuration.md` (extracted and diffed).
- **SC-002**: All previously pinned strings survive: `pipeline/tests/prose.bats` reports `1..9`, 9 ok, and the G gate row `| Implementer | G |` is byte-identical.

  > **AMENDED at phase M round 4, owner-ordered (2026-08-23)**: superseded by the owner's "fix everything, no deferred", which spent the prose-pin test debt. Prose is `1..11` and the house suite `1..121`; the +2 is one test for the G pre-answer contract and one for the consent sites outside the G slice, both mutation-verified with a positive control. Any OTHER movement is still a finding.
- **SC-003**: The full house suite reports `1..119`, 119 ok, 0 non-TAP — growth exactly zero.

  > **SUPERSEDED at phase M round 4, owner-ordered (2026-08-23)**: the owner overrode the review cap with "fix everything, no deferred", which spent the prose-pin test debt research R3 had recorded. Prose is now `1..11` and the house suite `1..121` — growth of exactly TWO tests: `the G pre-answer contract is pinned sentence by sentence` and `the implementer key's consent surface is pinned outside the G slice`. The spend was made twice: its first shape kept the count frozen by hosting the consent contract inside test 9, and a round-4 reviewer showed that hid it in a test named for the handoff package. The `--auto` row and the `--auto-release` assurance stayed in test 6, where they belong. Mutation-verified with a positive control first: 17 mutations, 17 correct, including 14 inversions that had cleared the suite before the pins were extended through their operative clauses.
- **SC-004**: The run's own field test: THIS phase is executed with the G answer "handoff" — the package is written, the run parks at H, an external implementer executes the package, and `--resume` consumes its report. The park and resume evidence is recorded in the run's artifacts.

## Assumptions

- Precedence needs no new machinery: the existing resolution order (defaults → user config → repo config → `--config` → individual flags) already places flags last-wins; the key and flag slot into it.
- "Character-identical" binds the key name, the value set, and the default — not the surrounding prose, which serves different audiences in the two files.
- `pipeline/skills/pipeline/SKILL.md` and `pipeline/tests/` are RELAXED vocabulary surfaces; `pipeline/CHANGELOG.md` and `pipeline/docs/configuration.md` are STRICT.
- Global Constraints of the plan of record apply; no version stamp this phase.
- SC-004's external implementer is any cheap model the owner picks; its work lands uncommitted per the package's Report-back contract, and this run's K commits it only after the resume's verification.
