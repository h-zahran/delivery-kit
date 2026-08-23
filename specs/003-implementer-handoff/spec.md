# Feature Specification: the implementer handoff package, upgraded

**Feature Branch**: `003-implementer-handoff`

**Created**: 2026-08-23

**Status**: Draft

**Input**: User description: "Phase 3 of the dogfood plan — the implementer handoff package, upgraded. Replace the pipeline orchestrator G phase's one-paragraph package description with a full package contract, so a cheaper model receives everything a good handoff carries. Modeled on the owner's field-tested format."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The G gate's "handoff" answer produces a complete package (Priority: P1)

An operator reaches the implementer gate and answers "handoff": the run must write a package a cheaper model can execute with zero re-discovery. Today the orchestrator describes that package in one paragraph; a cheap model given that paragraph's output has to guess what a good handoff carries. After this change, the **G — implementer gate** section of `pipeline/skills/pipeline/SKILL.md` specifies the package's seven parts by name, so every package carries the same complete shape: **Files to provide**, **Repository state**, **Instructions**, **Forbidden list**, **What will bite this feature**, **Validation before "done"**, and **Report-back contract**.

**Why this priority**: The package contract is the feature — P4 field-tests it by handing a real package to a cheap model, and every gap in the contract becomes that model's failure.

**Independent Test**: Read the G section: all seven part names present, each with its content specified; the pre-existing G sentences (derived forbidden list, the P1 VOID sentence, "`--auto` never collapses this gate: it spends money") byte-identical to before.

**Acceptance Scenarios**:

1. **Given** the orchestrator's G section, **When** it is read after this change, **Then** it names all seven parts and specifies each part's content: Files to provide (a table of the spec artefacts — spec, plan, tasks, research, contracts, quickstart, data-model where present — with absolute paths, each verified to exist before the package is written, the verification stated in the package); Repository state (branch checked out, tree state, the verbatim F.5 test baselines plus the analyzer baseline where one exists); Instructions (task order and phase groupings from the tasks file, `[P]`-marked tasks in the same phase may run concurrently, mark each completed task `[X]`, never restructure spec.md/plan.md/tasks.md, the per-phase verification command); Forbidden list (derived, as already specified); What will bite this feature (the run's accumulated non-obvious knowledge from clarify answers, research-file decisions, and mid-run discoveries, each item naming its source; empty is allowed but must be stated as empty); Validation before "done" (a checklist with the exact commands and the baseline numbers); Report-back contract (visible todo board while working, work left uncommitted, report status, files touched, verbatim test output, and anything it could not do).
2. **Given** the pre-existing G sentences, **When** the section is diffed against its previous text, **Then** the derived-forbidden-list sentence, the VOID sentence, and the `--auto` sentence are byte-identical — the seven-part specification is added near, nothing reworded.

---

### User Story 2 - The seven names are pinned by a test (Priority: P2)

A test author finds one new test appended to `pipeline/tests/prose.bats` (no new file) that greps the G section for all seven part names. The test is mutation-verified: deleting any one name from the section turns it red.

**Why this priority**: Without a pin, a later edit can silently drop a part and every future package inherits the gap; the pin is cheap and the suite counts are already gates.

**Independent Test**: `prose.bats` reports `1..9`, all ok; deleting one part name from SKILL.md turns the new test red (mutation check, recorded).

**Acceptance Scenarios**:

1. **Given** the new test and the changed SKILL.md, **When** the focused prose suite runs, **Then** it reports `1..9`, 9 ok.
2. **Given** any one of the seven part names deleted from the G section, **When** the new test runs, **Then** it fails (the mutation is observed and recorded, then reverted).

---

### User Story 3 - The changelog records the change (Priority: P3)

A reader of `pipeline/CHANGELOG.md` finds an Added entry under `## [Unreleased]` describing the upgraded package contract. No version is stamped.

**Why this priority**: The `[Unreleased]` section accumulates until the 1.1.0 release phase; the entry is the release note's raw material.

**Independent Test**: The `[Unreleased]` section carries the new Added entry; `## [Unreleased]` still sits above `## [1.0.1]`; no new version heading exists.

**Acceptance Scenarios**:

1. **Given** the changelog after this change, **When** its headings are listed, **Then** `[Unreleased]` (with the new entry) is above `[1.0.1]`, and no new version heading was added.

---

### Edge Cases

- The seven-part specification may be prose or a compact list — the implementer's choice of shape — but all seven parts are present BY NAME (the test pins the names, not the shape).
- "Add near, never reword": every pre-existing pinned string in SKILL.md stays byte-identical; the existing prose tests (the eight current pins) must stay green.
- `pipeline/CHANGELOG.md` is a STRICT vocabulary surface: the entry must not use banned spellings (the P2 precedent: describe, do not name, banned words).
- The suite grows exactly +1 (`1..118` → `1..119`); any other movement is a finding.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The **G — implementer gate** section of `pipeline/skills/pipeline/SKILL.md` MUST specify the handoff package's seven parts, all present by name — **Files to provide**, **Repository state**, **Instructions**, **Forbidden list**, **What will bite this feature**, **Validation before "done"**, **Report-back contract** — each with its content as given in US1/AC1. Shape (prose or compact list) is the implementer's choice. The existing G sentences — the derived-forbidden-list sentence, the P1 VOID sentence, and "`--auto` never collapses this gate: it spends money" — stay byte-identical.
- **FR-002**: One new test MUST be appended to `pipeline/tests/prose.bats` (no new test file) pinning the seven part names in the G section, and MUST be mutation-verified: deleting any one name from SKILL.md turns it red (observed and recorded, then reverted).
- **FR-003**: `pipeline/CHANGELOG.md` MUST gain an Added entry under the existing `## [Unreleased]` heading describing the upgraded package contract. No version stamp.

### Key Entities

- **The handoff package**: the file phase G writes into the run directory when the gate's answer is "handoff"; its seven parts are the contract this feature pins.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `pipeline/tests/prose.bats` reports `1..9`, 9 ok.
- **SC-002**: The full house suite reports `1..119`, 119 ok, 0 non-TAP lines — growth exactly +1.
- **SC-003**: All previously pinned strings survive: the eight pre-existing prose tests and every portability gate stay green.
- **SC-004**: The mutation check for the new test (one part name deleted → red) is observed and recorded in the run's artifacts before completion.

## Assumptions

- The seven-part contract is modeled on the owner's field-tested handoff format (the handoff plugin's document shape); this feature specifies the PACKAGE contract in the orchestrator's G section only — it does not change the handoff plugin.
- `pipeline/skills/pipeline/SKILL.md` and `pipeline/tests/` are RELAXED vocabulary surfaces; `pipeline/CHANGELOG.md` is STRICT (the P2 precedent binds: the entry describes, never names, banned spellings).
- Global Constraints of the plan of record apply throughout; no version stamp in this phase (`plugin.json` and the marketplace entry stay `1.0.1`).
- The G section's package continues to be written into the run directory under `.delivery-kit/runs/<feature>/` per the 1.0.1 G text; this feature adds the content contract, not a new location.
