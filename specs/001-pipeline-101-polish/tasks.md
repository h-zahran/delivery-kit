# Tasks: pipeline 1.0.1 — release-day truth and door polish

**Input**: Design documents from `/specs/001-pipeline-101-polish/`

**Prerequisites**: plan.md, spec.md, research.md, contracts/prose-contract.md, quickstart.md

**Tests**: No new test tasks — the seed pins the suite count at 116. Verification uses the existing gates (prose.bats pins, full house suite), run in the Polish phase and again by the pipeline's own J/N phases.

**Organization**: Grouped by user story. All SKILL.md tasks share one file, so they are sequential (no [P]); the three stamp tasks touch three different files and can run in parallel.

## Phase 1: Setup (anchor verification)

**Purpose**: Prove every insertion anchor and pin exists BEFORE any edit — "add near, never reword" needs a verified "near".

- [X] T001 Verify anchors and baseline: grep `pipeline/skills/pipeline/SKILL.md` for the four anchors (O paragraph's final sentence "never under `--auto` alone.", N.5 "then continue.", G paragraph's "it spends money.", the Ground rules list's last bullet) and the pinned sentence `It never reports verification it did not do`; run `bash /c/Users/h_zah/bats/bin/bats pipeline/tests/prose.bats` and confirm 1..8 ok pre-change. Record anchor line numbers in this file's margin notes on completion.

---

## Phase 2: Foundational

None — no task blocks any story beyond T001's anchor proof.

---

## Phase 3: User Story 1 — Release gate truth (Priority: P1) 🎯 MVP

**Goal**: The O — release paragraph says what an honest O does with `releaseCommand` unset.

**Independent Test**: `grep -c "With \`releaseCommand\` unset there is nothing to publish" pipeline/skills/pipeline/SKILL.md` prints 1; prose.bats still 1..8 ok.

- [X] T002 [US1] Insert contract C1 sentence (contracts/prose-contract.md) into `pipeline/skills/pipeline/SKILL.md`, immediately after the O — release paragraph's final sentence ("…never under `--auto` alone."), byte-for-byte, touching no existing byte.

**Checkpoint**: US1 grep passes; prose.bats 1..8 ok.

---

## Phase 4: User Story 2 — Honest verification and gate hygiene (Priority: P2)

**Goal**: N.5 welcomes real extra verification as extra evidence; G voids stale handoff packages; Ground rules gain the missing-tool question. Same file as US1 → sequential tasks.

**Independent Test**: three greps (quickstart.md §1, lines 2–4) each print 1; the pinned `It never reports verification it did not do` is byte-identical; prose.bats 1..8 ok.

- [X] T003 [US2] Insert contract C2 sentence into `pipeline/skills/pipeline/SKILL.md`, immediately after the N.5 sentence ending "then continue.", leaving the following pinned sentence untouched.
- [X] T004 [US2] Insert contract C3 sentence into `pipeline/skills/pipeline/SKILL.md`, at the end of the G — implementer gate paragraph, after "…it spends money." — that G sentence is guarded by the contract document, not by a prose.bats pin (the pinned `--auto` never collapses O` string lives in the Flags section); it stays byte-identical either way.
- [X] T005 [US2] Append contract C4 bullet to the Ground rules list in `pipeline/skills/pipeline/SKILL.md`, matching the list's bullet style, after the current last bullet.

**Checkpoint**: all four sentences grep-findable; prose.bats 1..8 ok.

---

## Phase 5: User Story 3 — Measured front-door spelling (Priority: P3)

**Goal**: README examples use the canonical `/pipeline:pipeline …`; any short-form claim is measured, never assumed.

**Independent Test**: read `pipeline/README.md` "How it runs" — three canonical examples; short-form sentence matches the recorded measurement (or is absent).

- [X] T006 [US3] Execute research R1's measurement in this live session: the owner types `/pipeline` once; record the observed outcome (resolves / does not resolve / indeterminate) in `.delivery-kit/runs/001-pipeline-101-polish/progress.json` under a `measurements.shortForm` key, via jq. HUMAN-IN-THE-LOOP: needs one owner keystroke.
- [X] T007 [US3] Update `pipeline/README.md` "How it runs" (depends on T006): all three example invocations spell `/pipeline:pipeline …`; add the short-form sentence ONLY per T006's recorded result — whichever sentence is true, none if indeterminate. STRICT surface: hyphenated spec-tool spellings, Global Constraints word bans, count-free.

**Checkpoint**: README reads true; no unmeasured claim.

---

## Phase 6: User Story 4 — The 1.0.1 stamp (Priority: P1, deliberately last: it stamps finished content)

**Goal**: One version, three sites, agreeing.

**Independent Test**: quickstart.md §4 — jq prints `handoff 2.1.0` and `pipeline 1.0.1`; plugin.json agrees; changelog heading parses.

- [X] T008 [P] [US4] Stamp `pipeline/.claude-plugin/plugin.json` version `1.0.1` (jq-verified edit).
- [X] T009 [P] [US4] Stamp the pipeline entry of `.claude-plugin/marketplace.json` version `1.0.1` (jq-verified edit; handoff entry untouched at 2.1.0).
- [X] T010 [P] [US4] Add `## [1.0.1] - 2026-08-21` section to `pipeline/CHANGELOG.md` above `## [1.0.0] …`, matching the file's existing entry style, describing the fixes count-free (re-stamp the date if the merge slips past today).

**Checkpoint**: three sites agree; heading shape parses.

---

## Phase 7: Polish & validation

- [X] T011 Run quickstart.md sections 1–4 (four greps, prose.bats 1..8, README read, version jq) and record outputs.
- [X] T012 Run the full house suite from the repo root (quickstart.md §5): expect `1..116`, 116 ok, 0 non-TAP. Any other count is a finding, not a pass.

---

## Dependencies & Execution Order

- T001 → everything (anchor proof first).
- T002 → T003 → T004 → T005: same file, strictly sequential.
- T006 → T007 (measurement before README edit). T006/T007 independent of T002–T005.
- T008, T009, T010: parallel with each other; run after T002–T007 (the stamp is the last content change).
- T011 → T012 close the run.

### Parallel Opportunities

- T008 + T009 + T010 (three different files).
- The US3 pair (T006–T007) may interleave with Phases 3–4 — different files — but the owner keystroke (T006) is scheduled once, at a moment the board makes visible.

## Implementation Strategy

Single-PR increment: US1 alone is a shippable MVP (the release-day truth fix), but the plan of record ships all four stories plus the stamp in one run and one pull request. Execute sequentially T001→T012; fan out only the stamp trio.
