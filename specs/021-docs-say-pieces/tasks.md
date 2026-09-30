# Tasks: the documentation says pieces

**Input**: Design documents from `specs/021-docs-say-pieces/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/doc-sites.md, quickstart.md

**Tests**: NO NEW TESTS (seed; FR-011). Two existing pins change with their sentences (research R2), each proven red first and red again under an inverted mutant. Everything else is verified by the quickstart's greps, each with a positive control, and by the house suite.

**Run directory**: `.delivery-kit/runs/021-docs-say-pieces/` (ignored by git), written `$RUN` below.

## Format: `[ID] [P?] [Story] Description`

## ⚠️ Rules that override anything below

1. **The contract says what each site must say.** Every edit is to a site in `contracts/doc-sites.md` (by ID), and the new text carries the meaning its "New text must say" cell gives — checked against the orchestrator (`pipeline/skills/pipeline/SKILL.md`), which wins on any difference (FR-012). A site not in the contract is not edited; a new stale site found while editing is added to the contract first.
2. **Pinned sentences stay byte-for-byte** unless the contract says they change: in `pipeline/docs/configuration.md`, "With `ask` the gate simply asks, as it does when the key is unset", "An illegal value stops pre-flight by name: never coerced, never treated as unset.", "Layers merge by silence, not by erasure" and the heading `## The implementer key`.
3. **History is never edited.** Released `pipeline/CHANGELOG.md` sections stay byte-identical; only `## [Unreleased]` gains two lines (T012).
4. **STRICT vocabulary** (FR-013) on every changed line of `README.md`, `pipeline/README.md`, `pipeline/docs/` and `pipeline/CHANGELOG.md`; RELAXED on `pipeline/skills/`. Write "spec-kit", never the banned whole words. No changed line states a count of tests, suites or plugins.
5. **Mutations happen in a scratch tree, never in the checkout** (memory: a mutation rig belongs in a worktree), and the mutated line is echoed before its result is believed.

---

## Phase 1: Setup

- [X] T001 Run the house suite from the repository root and save its verbatim output to `$RUN/baseline-suite.txt`: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`. Record the plan line, ok count, not-ok count, non-TAP line count and exit code in `$RUN/baseline-counts.txt`. Expect `1..240`, 240 ok, 0 not ok, 0 non-TAP, exit 0. **If it differs, stop and report.** Record `git rev-parse HEAD` in `$RUN/baseline-sha.txt`.
- [X] T002 Run `quickstart.md` steps 1 and 2 (extracted to a script file, never retyped) and save the output to `$RUN/claims-before.txt`. Expect every positive control ok; this hit list is the before-picture T014 is compared with. Copy `pipeline/docs/configuration.md` and `pipeline/tests/prose.bats` unchanged to `$RUN/configuration.md.orig` and `$RUN/prose.bats.orig`.

**Checkpoint**: baseline recorded; the claim greps are shown able to find a known hit.

---

## Phase 2: User Story 1 — the gate tables tell the truth about G and the floor (Priority: P1) 🎯 MVP

**Goal**: sites C1–C5 and C7–C9, R5, R6, R8, R10–R14, M4, M5, M8, M9 and M11–M14 of the contract say what the orchestrator's Gates section says.

**Independent Test**: `quickstart.md` step 2 reports no hit for "no gate stopping", "without a single gate" or any "pre-answer(s) … gate" pattern in `README.md`, `pipeline/README.md` or `pipeline/docs/`; `pipeline/tests/prose.bats` passes.

### Pins first (run red)

- [X] T003 [US1] In `pipeline/tests/prose.bats`, test "the implementer key's consent surface is pinned outside the G slice": replace the pinned `implementer` table row (the `grep -qF '| \`implementer\` | Pre-answers the implementer gate: …'` line) with the new row, and the pinned sentence "Cap breaches, a missing required tool, hard failures and a failed runtime check still stop it, but the gates do not." (the `<<<"$dflat"` grep, not the `$cflat` ones, which pin released changelog text) with its new sentence. Write the two new texts first as `$RUN/pin-row.txt` and `$RUN/pin-sentence.txt` (one line each), meeting contract C1 and C3; the pins are read from those files, never retyped. Keep each pin's failure message meaningful, and rewrite the comment above the docs pin, which says the two shipped surfaces agree verbatim (research R2). Run `bats pipeline/tests/prose.bats -f "consent surface"` against the unchanged `pipeline/docs/configuration.md`: it must be `not ok`, failing on the row pin first; save to `$RUN/us1-red.txt`.

### Implementation

- [X] T004 [US1] In `pipeline/docs/configuration.md`, rewrite C1 (the `implementer` row, to the exact text of `$RUN/pin-row.txt`), C2 (the first paragraph of `## The implementer key`), C3 (the range paragraph, carrying the exact sentence of `$RUN/pin-sentence.txt`), C4 (`pre-answers a gate` → answers a gate's question in advance), C5 (line 150, `the feature's commit` → `commits`), C7 (`pre-answers the gate and you want the stop back`), C8 (`never stages anything outside the commit gate`) and C9 (the `commitStyle` row). Keep rule 2's pinned sentences byte-for-byte. Run `bats pipeline/tests/prose.bats`: all ok; save to `$RUN/us1-green.txt`.
- [X] T005 [P] [US1] In `pipeline/README.md`, rewrite R5 (the line under `## The five gates`), R6 (the Implementer row and its "Skippable by" cell), R8 (the Push & PR row's "Skippable by" cell), R10 (the "Other things still stop a run" paragraph — the contract's whole conditional-stop list, and a pause), R11 (the floor warning), R12 (the `--implementer` flag row), R13 ("the commit gate names every path") and R14 (`pipeline:status` "which gate", lines 40–41 and 51); R9 is kept unless its paragraph is touched.
- [X] T006 [P] [US1] In `README.md`, rewrite M4 (the line under `### The five gates`), M5 (the Implementer row), M8 (the "Other things stop a run too" paragraph, as R10), M9 (the floor warning), M11 (the `--implementer` flag row), M12 (the `pipeline.implementer` configuration row), M13 (BOTH cells of the troubleshooting row "A run reached the end without asking you anything") and M14 ("a value which pre-answers a gate", line 389).
- [X] T007 [US1] Prove the two changed pins with inverted mutants in a scratch copy of the tree (rule 5), the copy taken before batch 3 starts so no half-written file from T010, T012 or T013 lands in it (the test reads only `configuration.md` and released changelog text, but the copy must be whole): one mutant inverts the new row's meaning (for example, says the key pre-answers the whole gate), one inverts the new sentence's meaning (for example, says the gates do not stop a fresh run); echo each mutated line; each must turn "consent surface" `not ok`; a mutant that changes nothing must be refused. Save to `$RUN/us1-mutants.txt`.

**Checkpoint**: `prose.bats` green; both pins shown red under an inverted mutant.

---

## Phase 3: User Story 2 — the phase reference shows pieces and late commits (Priority: P1)

**Goal**: contract P1–P3 and P6–P9 rewritten (P6 now includes L's own `--auto` stops; P9 the pre-flight row); P4 and P5 re-checked.

**Independent Test**: each row of `pipeline/docs/phases.md`'s table read against the orchestrator's text for that phase.

- [X] T008 [US2] In `pipeline/docs/phases.md`, rewrite P1 (G row), P2 (H row), P3 (H.5, H.7 and I rows), P6 (L row), P7 (DONE row), P8 (the note under the table) and P9 (the pre-flight row), and re-check P4 (J) and P5 (K) against the orchestrator, recording in `$RUN/us2-recheck.txt` that each still holds (or fixing it and adding it to the contract). Keep each row one table line.

**Checkpoint**: no row claims less or more than the orchestrator for its phase.

---

## Phase 4: User Story 3 — a short guide to reviewing a run commit by commit (Priority: P2)

**Goal**: contract R2, R3, R15, M1, M2, M3.

**Independent Test**: `quickstart.md` step 5 reports every same-file anchor ok; the house suite's link test passes; the new section names every commit kind `pipeline/scripts/progress.sh` accepts.

- [X] T009 [US3] In `pipeline/README.md`, rewrite R2 (the Build row) and R3 (the Ship row), and add R15: a short section `## Reviewing a run commit by commit`, placed after `## The five gates` and its warning, naming the review guide, each commit kind in `progress.sh`'s `KINDS` (spec, piece, converge, simplify, review, tests, constitution, other), M's and N's commits, and the handoff exception as the contract's R15 words it (one feature commit from K; M's and N's fixes and an accepted constitution still get rows). Link to `docs/phases.md` where a phase is named.
- [X] T010 [US3] In `README.md`, rewrite M1 (the heading `### pipeline — one feature, twenty phases, five stops` → `… five gates`), M2 (the table-of-contents link at line 14 → `#pipeline--one-feature-twenty-phases-five-gates`) and M3 (the "five stars" paragraph), adding exactly one sentence that says a Claude run commits in pieces and links to `pipeline/README.md#reviewing-a-run-commit-by-commit` (owner, at C). Depends on T009 (the anchor). Run `quickstart.md` step 5 and save to `$RUN/us3-anchors.txt`.

**Checkpoint**: every anchor resolves, same-file ones included.

---

## Phase 5: User Story 4 — the status skill reports a run waiting at the review question or a pause (Priority: P2)

**Goal**: contract S1, S1f and S4.

**Independent Test**: step 4 of `pipeline/skills/status/SKILL.md`, followed against the two state-file shapes in the spec's US4 scenarios, gives the answers the scenarios name.

- [X] T011 [US4] In `pipeline/skills/status/SKILL.md`, rewrite step 4 per research R7: C and O unchanged; G waiting for its implementer answer when `gates.G` holds none, or for its review answer when `gates.G.answer` is `claude` and `gates.G.reviewMode` is absent (a plain-string `gates.G` is the implementer answer alone); K waiting when `gates.K.answer` is absent (a plain-string `gates.K` is the answer); L waiting unless `gates.L` holds the push answer (a removal record is not it); H, when G's implementer answer is `handoff` (object or plain string), most likely parked for the implementer's report, saying the file cannot show whether the report was already consumed; H with `gates.G.reviewMode` `pauses` most likely waiting at a pause — name the answers under `gates.H.pauses` and say the file cannot show whether a pause is showing now; a failure entry under `gates.H` or a late phase's letter reported as the stop it is. Change the description line (S1f) to "the gate or pause it is waiting on". Walk both US4 scenarios, plus a K-waiting and a handoff-parked state, against the new text and save the walk to `$RUN/us4-walk.txt`.
- [X] T012 [US4] In `pipeline/CHANGELOG.md`, add two bullets under `## [Unreleased]` → `### Changed` (S4, research R5): `pipeline:status` now reports a run waiting at G's review question, at K, parked at H for a handoff report, or in pause mode left at H; and L, like K, stops even under `--auto` for a commit it cannot show or a state-file record of a commit not on the branch. Nothing else in the file changes.

**Checkpoint**: both scenarios answered; the changelog diff against `db2875d` only adds lines, under Unreleased.

---

## Phase 6: Polish & cross-cutting

- [X] T013 In `pipeline/skills/pipeline/SKILL.md`, change pre-flight item 9's "the feature's commit" to "the feature's commits" (S2) and nothing else; `git diff --stat` shows one line changed. Run `bats pipeline/tests/prose.bats`: all ok.
- [X] T014 Run `quickstart.md` steps 1, 2, 3 and 5 as one extracted script and save the output to `$RUN/claims-after.txt`. Judge every remaining hit (true, history, or unrelated) in `$RUN/claims-verdicts.md` — this file is what the commit message quotes (FR-009). Grep every changed line (`git diff -U0 db2875d` `+` lines) for the STRICT and RELAXED banned words and for a stated count of tests, suites or plugins (FR-013); save to `$RUN/vocab-check.txt`.
- [X] T015 Run the house suite from the repository root (quickstart step 4); save to `$RUN/final-suite.txt`. Expect `1..240`, 240 ok, 0 not ok, 0 non-TAP, exit 0 — the same plan line as T001.

---

## Dependencies

- T001–T002 first. T003 → T004 → T007 (red, green, mutants). T005 and T006 are independent of T003–T004 and of each other.
- T008 depends only on Setup. T009 → T010 (the anchor). T005 and T009 both edit `pipeline/README.md`, and T006 and T010 both edit `README.md`: never in the same batch.
- T011 → T012. T013 after T004 (its check runs the pins T003 turned red). T014 and T015 last.

## Parallel opportunities

- Batch 1 (after Setup): T003, T005, T006, T008, T011 — five different files.
- Batch 2: T004 (after T003), T009.
- Batch 3: T007, T010, T012, T013 (T013's `prose.bats` run needs T004's green). Then T014, T015.

## Implementation strategy

US1 is the MVP: the false floor and implementer claims are the safety-relevant ones. US2 follows; US3 and US4 add the new section and the status fix. The whole feature ships as one change.
