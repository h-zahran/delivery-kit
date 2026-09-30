# Tasks: the orchestrator commits late fixes and guides the reviewer

**Input**: Design documents from `specs/020-late-commits-review-guide/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/orchestrator-prose.md, quickstart.md

**Tests**: REQUIRED. FR-016 and SC-001 demand a pin for each obligation, each shown red before the prose lands and red again under an INVERTED mutant after.

**Run directory**: `.delivery-kit/runs/020-late-commits-review-guide/` (ignored by git) holds every saved output below. Written `$RUN` below. `$P20` is `.delivery-kit/runs/019-orchestrator-builds-in-pieces/`.

## Format: `[ID] [P?] [Story] Description`

## ⚠️ Four rules that override anything below

1. **Sentences come from the contract, byte for byte.** Every sentence a task adds to `SKILL.md`, and every pin a task adds to `prose.bats`, is read out of `contracts/orchestrator-prose.md` by `$RUN/contract.py` (T003) — never retyped. Retyping is how an em dash becomes a hyphen and a pin goes red for a reason nobody wrote.
2. **Red first, in the checkout.** A new pin is written before its prose and run against the unchanged `SKILL.md`; it must be `not ok` with its own message. A new pin green before its prose exists proves nothing — fix it before writing the prose.
3. **Mutations happen in a scratch tree, never in the checkout** (memory: a mutation rig belongs in a worktree). The rig echoes each mutated line before its result is believed, and exits non-zero on a mutant that changed nothing.
4. **Spans.** `span_n`, `span_fail` and `span_seed` are never edited, and no task writes inside the regions they pin. `span_j` changes only in T008/T010, on purpose (FR-006). K's heading line `**K — commit. STOPS AND ASKS.**` stays byte-identical (research R2). No line strictly inside a contract slice may start with `**` or `#`.

---

## Phase 1: Setup

- [X] T001 Run the house suite from the repository root and save its verbatim output to `$RUN/baseline-suite.txt`: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`. Record the plan line, ok count, not-ok count, non-TAP line count and exit code in `$RUN/baseline-counts.txt`. Expect the plan line SC-002 names for `8efe515`, every test ok, 0 non-TAP, exit 0. **If it differs, stop and report** — every later count is arithmetic on it.
- [X] T002 Record `git rev-parse HEAD` to `$RUN/baseline-sha.txt`, and copy `pipeline/skills/pipeline/SKILL.md` and `pipeline/tests/prose.bats` unchanged to `$RUN/SKILL.md.orig` and `$RUN/prose.bats.orig`.

---

## Phase 2: Foundational

- [X] T003 Copy `$P20/contract.py` and `$P20/mutate.py` into `$RUN/` and point them at `specs/020-late-commits-review-guide/contracts/orchestrator-prose.md`. `contract.py` must read every `- <ID>: `…`` bullet (IDs such as `L1`, `C5`, `GT7`), the C1 row from the `New:` code block, and each Absent string, and print them tab-separated; remove P20's lookup of a `New (two sentences, both pinned)` block, which this contract does not have. It must fail when an ID in the "Test blocks" table's Pins column (ranges like `L1–L9` expanded) is missing from the bullets, or a bullet ID is in no Pins cell — except C1 (its row is the `New:` code block) and C4 (`span_j`, proven by T008/T010). Save its output to `$RUN/contract-sentences.tsv`. Prove `mutate.py` with one control mutant against an EXISTING pin (the phase H sentence `A recorded piece is never rebuilt.` inverted to `A recorded piece is rebuilt.`), expecting `CAUGHT` in the H test, and with one no-op mutant, expecting a refusal; save both to `$RUN/t003-rig-control.txt`. Run Python's bash through `shutil.which("bash")`, never a bare `"bash"` (memory: Python's `bash` is WSL bash).

**Checkpoint**: the contract reads whole, and the rig catches a known mutant and refuses a no-op.

---

## Phase 3: User Story 1 — every phase after H commits its own work (Priority: P1) 🎯 MVP

**Goal**: H.5, H.7, I and J each end with one late commit, under their kind, in the piece flow; the rule is written once after H.5; H.7 and I read the run's change; MAY-do names late commits.

**Independent Test**: `bats pipeline/tests/prose.bats -f 'late phases'` passes; the H.5 slice holds L1–L9, H.7 holds S1–S2, I holds I1–I2, Never-bend holds C5–C6.

### Tests for User Story 1 (write first, run red)

- [X] T004 [US1] In `pipeline/tests/prose.bats`, append a test `late phases commit their own work, each under its kind` that pins, with `pins_in`, L1–L9 over `prose_slice '^\*\*H\.5 — converge\.\*\*' '^\*\*H\.7 — simplify\.\*\*' flat 'phase H.5'`, S1–S2 over `prose_slice '^\*\*H\.7 — simplify\.\*\*' '^\*\*I — deep review\.\*\*' flat 'phase H.7'`, and I1–I2 over `prose_slice '^\*\*I — deep review\.\*\*' '^\*\*J — analyzer and full suite\.\*\*' flat 'phase I'`. In the existing test `the gate floor counts the review question, and every commit names every path`, replace the MAY-do pins (P20's N2 and N3) with C5 and C6. Keep `@test` names ASCII (memory: a test can be counted and never run).
- [X] T005 [US1] Run `bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/prose.bats` and save to `$RUN/us1-red.txt`. The new test and the gate-floor test must be `not ok`, each on its first missing pin's message; every other test `ok`.

### Implementation for User Story 1

- [X] T006 [US1] In `pipeline/skills/pipeline/SKILL.md`: after H.5's first paragraph, add plain paragraphs holding L1, L2 and L3; then L4, L5, L6, L7 and L8; then L9. In H.7, append S1 and S2 after its existing sentences. In I, replace the first sentence with I1 and "Fixes fan out." with I2. In MAY-do, replace P20's N2 text with C5 and the closing sentence with C6. Every sentence from `$RUN/contract-sentences.tsv`.
- [X] T007 [US1] Run `pipeline/tests/prose.bats`; save to `$RUN/us1-green.txt`. Every test `ok`.

**Checkpoint**: the late commits are described; J's carry still names "the commit message".

---

## Phase 4: User Story 2 — a red the owner waved through reaches the reviewer (Priority: P1)

**Goal**: J's carry names J's own commit; an empty commit carries it when J changed nothing; J commits once when its loop ends; the J span changes on purpose.

**Independent Test**: the J test and the new J test pass; the J slice holds C2, C3, J1–J3; `span_j` matches the new region.

### Tests for User Story 2 (write first, run red)

- [X] T008 [US2] Build the new J region in a scratch copy of `SKILL.md` by applying T010's edit there, and save the old and new flattened J regions to `$RUN/span-j-old.txt` and `$RUN/span-j-new.txt`. In `pipeline/tests/prose.bats`, test `phase J carries a waved-through red into everything that leaves the machine`: replace the pin at `:629` with C2 and the pin at `:641` with C3, and replace `span_j`'s heredoc body with the contents of `$RUN/span-j-new.txt`, pasted in — the shipped test never reads the ignored run directory. Append a test `J's carry lands in J's own commit, or in an empty one` pinning J1–J3 with `pins_in` over `prose_slice '^\*\*J — analyzer and full suite\.\*\*' '^\*\*K — commit\.' flat 'phase J'`.
- [X] T009 [US2] Run `pipeline/tests/prose.bats`; save to `$RUN/us2-red.txt`. The J test and the new test `not ok`; every other test `ok`.

### Implementation for User Story 2

- [X] T010 [US2] In `pipeline/skills/pipeline/SKILL.md`, J: append J1 to J's first paragraph; replace the carry sentence with C2 and follow it with J2 and J3; replace "the commit message carries it alone and the duty is discharged there." with C3. Nothing else in the J region changes. Confirm the flattened J region now equals `$RUN/span-j-new.txt`.
- [X] T011 [US2] Run `pipeline/tests/prose.bats`; save to `$RUN/us2-green.txt`. Every test `ok`.

**Checkpoint**: every late phase, J included, is described.

---

## Phase 5: User Story 3 — K shows the whole commit list (Priority: P1)

**Goal**: K splits by whether `<base>..HEAD` holds a commit; with commits it shows the commit list and the remainder, commits after the answer, records "nothing to commit", and stops for an odd path or an unshowable commit even under `--auto`; K's gate row shows the commit list; the conditional-stops list names both new stops.

**Independent Test**: the new K test passes; the K slice holds K1–K12; the Gates section holds GT7 (row), GT8 and GT9.

### Tests for User Story 3 (write first, run red)

- [X] T012 [US3] In `pipeline/tests/prose.bats`, append a test `K shows the commit list and stops for a path outside the feature` pinning K1–K12 with `pins_in` over `prose_slice '^\*\*K — commit\.' '^\*\*L — push and open a pull request\.' flat 'phase K'`, GT8 and GT9 with `pins_in` over the flattened Gates slice, and GT7 with `rows_in` over `prose_slice '^## Gates$' '^## Parallel agents$' raw 'gates'` — the Gates slice taken ONCE, raw, and flattened from that.
- [X] T013 [US3] Run `pipeline/tests/prose.bats`; save to `$RUN/us3-red.txt`. The new test `not ok`; every other test `ok`.

### Implementation for User Story 3

- [X] T014 [US3] In `pipeline/skills/pipeline/SKILL.md`: keep K's heading `**K — commit. STOPS AND ASKS.**` and replace the rest of K's paragraph with K1; then K2, K3 and K4; then K5, K9, K10, K11, K12 and K6; then K7 and K8. In `## Gates`, replace the Commit row with GT7, replace the sentence beginning "Conditional stops:" with GT8, and add GT9 after the sentence ending "is one of them, and `--auto` does not collapse it."
- [X] T015 [US3] Run `pipeline/tests/prose.bats`; save to `$RUN/us3-green.txt`. Every test `ok` — the J test included, which proves the span still closes on K's unchanged heading.

**Checkpoint**: the release blocker is closed in the prose.

---

## Phase 6: User Story 4 — the reviewer is told how to read the branch (Priority: P1)

**Goal**: L's body and the DONE summary carry the review guide, built from `commits`, unrecorded commits recorded first, headed with one line, never truncated.

**Independent Test**: the new guide test passes; the L slice holds V1–V6, the DONE slice D1.

### Tests for User Story 4 (write first, run red)

- [X] T016 [US4] In `pipeline/tests/prose.bats`, append a test `the review guide is in the PR body and the DONE summary` pinning V1–V6 with `pins_in` over `prose_slice '^\*\*L — push and open a pull request\.' '^\*\*M — PR review' flat 'phase L'`, and D1 over `prose_slice '^\*\*DONE\.\*\*' '^## Gates$' flat 'DONE'`.
- [X] T017 [US4] Run `pipeline/tests/prose.bats`; save to `$RUN/us4-red.txt`. The new test `not ok`; every other test `ok`.

### Implementation for User Story 4

- [X] T018 [US4] In `pipeline/skills/pipeline/SKILL.md`: in L, add V1 after its first sentence, and after L's paragraph add one paragraph holding V2, V6, V3, V4 and V5; in DONE, append D1.
- [X] T019 [US4] Run `pipeline/tests/prose.bats`; save to `$RUN/us4-green.txt`. Every test `ok`.

**Checkpoint**: the campaign's fix — the guide — is in the prose.

---

## Phase 7: User Story 5 — the loose ends Phase 20 left are closed (Priority: P2)

**Goal**: a tracked state file stops a re-entry; a plain-string `gates.G` takes the review answer; a spec the owner already committed makes no spec commit; the `--auto` row names the new stops.

**Independent Test**: the new test and the changed flags-row pin pass; Resume holds R2–R6, G holds G9, H holds H23, Flags holds C1.

### Tests for User Story 5 (write first, run red)

- [X] T020 [US5] In `pipeline/tests/prose.bats`: in `auto never collapses the release gate`, replace the flags-row pin with the new C1 row; append a test `a tracked state file stops a re-entry, and a plain-string gates.G takes the review answer` pinning R2–R6 over `prose_slice '^## Resume$' '^## Not in v1$' flat 'resume'` and G9 over `prose_slice '^\*\*G — implementer gate\.\*\*' '^The package carries seven parts' flat 'phase G'`; and append a test `a spec the owner already committed makes no spec commit` pinning H23 over `prose_slice '^\*\*H — implement\.\*\*' '^\*\*H\.5 — converge\.\*\*' flat 'phase H'`.
- [X] T021 [US5] Run `pipeline/tests/prose.bats`; save to `$RUN/us5-red.txt`. The flags-row test and both new tests `not ok`; every other test `ok`.

### Implementation for User Story 5

- [X] T022 [US5] In `pipeline/skills/pipeline/SKILL.md`: in `## Resume`, add a paragraph holding R2, R3, R4, R5 and R6 after the first paragraph; in G, add G9 after `read it that way, never as an error.`; in H, add H23 after the sentence ending `is recorded from that commit, not made again.`; in `## Flags`, replace the `--auto` row with C1. Afterwards run every contract slice through `prose_slice`: each still opens and closes on its boundary.
- [X] T023 [US5] Run `pipeline/tests/prose.bats`; save to `$RUN/us5-green.txt`. Every test `ok`.

**Checkpoint**: every FR-001–FR-015 and FR-019 sentence is in place and pinned.

---

## Phase 8: Polish & cross-cutting

- [X] T024 [P] In `pipeline/CHANGELOG.md`, under `## [Unreleased]`: add to `### Added` the review guide (L's pull-request body and the DONE summary list every commit with its kind, piece, task IDs and files, in commit order); add to `### Changed` that in the piece flow H.5, H.7, I and J each commit their own work, J's waved-through red rides in J's own commit or an empty one, K shows the whole commit list and stops even under `--auto` for a path outside the feature, and a re-entry stops when the state file is tracked in git. Keep the heading shapes `tests/` checks; name the spec tool's commands generically, never by a tool-specific slash name (the changelog is scanned with the full banned-vocabulary list).
- [X] T025 [P] Write the dry read `specs/020-late-commits-review-guide/dry-read-017.md` per `quickstart.md` step 4, saving the raw loop output to `$RUN/t025-dry-read.txt`. The file names paths repo-relative ONLY — never the scratch directory or an absolute path — because the tree-wide machine-path scan cannot see an uncommitted file (memory: a tracked-file gate is blind to an uncommitted tree).
- [X] T026 In `pipeline/tests/prose.bats`, append a test `the old K, J, I and MAY-do wordings are gone` (it cannot be red first: the strings are already gone by now, so T027's restore mutants and this task's positive control are its red) feeding every Absent string of the contract to `absent_in` over the flattened file. Then run `quickstart.md` step 3 (the positive control: every string found in `$RUN/SKILL.md.orig`, none in the new file); save to `$RUN/t026-sc004.txt`.
- [X] T027 Mutation sweep with `$RUN/mutate.py`: one INVERTED mutant per contract ID, the ID list READ FROM `$RUN/contract-sentences.tsv`, never typed — the rig fails unless mutants = contract IDs = new or changed pins in `prose.bats`. Each mutant asserts the opposite (for example K5 → "`--auto` collapses K even when a path lies outside"; R4 → "any other exit status means untracked") and names the test that must go red; plus one mutant per Absent string restoring it, and one per changed-on-purpose pin restoring its OLD text. Save to `$RUN/t027-mutations.txt`. Every mutant `CAUGHT` in its named test; the rig exits 0.
- [X] T028 Run the house suite from the repository root and save to `$RUN/t028-final-suite.txt`. Expect the T001 plan line plus N, where N = `grep -c '^@test' pipeline/tests/prose.bats` minus the same count on `$RUN/prose.bats.orig`; every test ok, 0 not ok, 0 non-TAP, exit 0, plan line = ok count. List every added and every changed test by name in `$RUN/t028-added-tests.txt`, with the old and new text of every pin under the contract's "Changed on purpose" and a pointer to `$RUN/span-j-old.txt` / `span-j-new.txt` — the commit message quotes them (SC-002, FR-006).
- [X] T029 Run, after T025, `quickstart.md` steps 6 and 7 (scope and shell analysis), and the suite's machine-path pattern (`TREE_PATHS` in `tests/portability.bats`) directly over `specs/020-late-commits-review-guide/`, which is uncommitted and so invisible to the tree-wide scan. Save all three to `$RUN/t029-scope.txt`; only the four allowed paths change, shellcheck is clean, 0 machine-path hits.

---

## Dependencies

- Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8.
- Every story edits `SKILL.md` and `prose.bats`, so the stories run in order, never in parallel.
- T024 and T025 touch different files and may run in parallel; T029 runs after T025, whose file its machine-path scan must see; T026–T028 read the finished files and run after T024 and T025.

## Parallel opportunities

Within this feature, only Phase 8's `[P]` tasks. Every story writes the same two files.

## Implementation strategy

MVP is US1 + US3: the late commits exist and K shows them, which closes the release blocker. US2 makes a waved-through red visible in the list; US4 adds the guide, the campaign's fix; US5 closes Phase 20's loose ends and makes the `--auto` row agree. Each story is red, then green, before the next starts.

---

## Phase 9: Convergence

Appended by the converge assessment (H.5), 2026-09-30. Verdict: converged on FR-001 to FR-019 and SC-001 to SC-005; these are its Low findings.

- [X] T030 In `specs/020-late-commits-review-guide/contracts/orchestrator-prose.md`, Recorded departures: the `--auto` flags row (C1) names K's stops and the tracked-state stop but not L's stops for a commit it cannot show or a stale entry; GT8 and GT9 carry those, per research R13 (partial)
- [X] T031 In `specs/020-late-commits-review-guide/contracts/orchestrator-prose.md`, Recorded departures: in a run switched to the single-commit flow after commits were made, with nothing left for K and a red waved through at J when J changed nothing, J2 names K's commit but K4 makes none; the state file and the pull-request body still carry the record, and only a run with no remote loses the commit-message copy, per FR-005 (partial)
- [X] T032 In `.delivery-kit/runs/020-late-commits-review-guide/t028-added-tests.txt`, list each added test's pin IDs from the contract's Test blocks table, and cite the final-tree suite run (1..240, measured after the K12 rewording), per SC-002 (partial)

