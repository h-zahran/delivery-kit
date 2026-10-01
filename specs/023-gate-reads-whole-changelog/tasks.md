---

description: "Task list for the release rule, the suite check and the C4 note"
---

# Tasks: The release gate reads the whole changelog, and one suite check

**Input**: Design documents from `specs/023-gate-reads-whole-changelog/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: the spec asks for exactly two (FR-009). Each is written FIRST and
shown red before the code it covers is written.

**Run directory**: `$RUN` = `.delivery-kit/runs/023-gate-reads-whole-changelog/`.

**Pieces**: each `## Phase` below is one piece and one commit.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: User Story 1 — the release form refuses an undated heading anywhere (Priority: P1)

**Goal**: FR-001–FR-003, contract G1–G7.

**Independent Test**: `bats -f 'below|undated' tests/portability.bats` runs
exactly one test, and it passes.

- [X] T001 [US1] In `tests/portability.bats`, directly after the test "--released refuses a dangling Unreleased heading, and the default run does not", add one test named "--released refuses an undated heading below the release, and the default run does not". It builds and normalises a released fixture the way that test does (copy, normalise, require `--released` to pass first), then, for each of two plants placed BELOW the first dated heading of the copied plugin's changelog — `## [Unreleased]`, and `## unreleased` — proves the plant landed below (the first `## ` line is still the dated heading), runs the gate through `run bash -c "…"` only (never `run bash <script>.sh`, which the one-script test counts), and asserts: the default form exits 0 and its line for the copied plugin (`<copied>: plugin=… state=released`) says `state=released` — not merely some line; the release form exits non-zero, and its output carries `is NOT released`, the plant's line number and the plant's text. It then plants an undated heading in a DIFFERENT plugin's changelog of the clean fixture and asserts `--released <copied>` still exits 0 (G6). Every failure branch echoes its contract ID first (`G1: …`, `G2: …`, `G5: …`, `G6: …`), so a red names the clause it caught. Run it and save the output to `$RUN/t001-red.txt`: it must FAIL (the gate does not judge lower headings yet), for the release-form assertion and not for a fixture error.
- [X] T002 [US1] In `scripts/check-versions.sh`, inside the `if [ "$p" = "$RELEASED" ]` block and after the existing first-heading comparison, add the whole-file rule of research R1: one `awk` pass over `./$p/CHANGELOG.md` that prints the first line beginning `## ` that is not exactly `## [X.Y.Z] - YYYY-MM-DD` as `<line>:<text>` (the regex spells repetitions out, `[0-9][0-9][0-9][0-9]`, per research R1), and a `die` naming that line number and its text (line breaks stripped) and ending `— this tree is NOT released`. Add a comment in the file's own style saying why the rule reads the whole file and why it uses `awk` rather than a `grep -v` pipeline under `pipefail`. Change nothing the default form runs.
- [X] T003 [US1] Run T001's test, the existing "--released refuses a dangling Unreleased heading…" and "--released refuses a plugin name that matches nothing…" tests, and "one version-agreement script, and both gates call it", from `tests/portability.bats`; save to `$RUN/t003-green.txt`. All pass. Then run `bash scripts/check-versions.sh` and compare its output and exit status with the `5831822` script's on the `5831822` tree (quickstart block 2); save to `$RUN/t003-default.txt`: identical (G5).

**Checkpoint**: `bats -f 'below|undated' tests/portability.bats` reads `1..1`, `ok 1`.

---

## Phase 2: User Story 2 — one suite check (Priority: P2)

**Goal**: FR-004–FR-007, contract K1–K11.

**Independent Test**: `bats tests/check-suite.bats` runs exactly one test, and it passes.

- [ ] T004 [US2] Create `tests/check-suite.bats` (a `#!/usr/bin/env bats` file loading `helper` as the other root suites do) with one test, "check-suite.sh passes one clean run and refuses every broken shape for its own reason". It writes TAP fixtures under `$TEST_DIR` and runs `bash "$ROOT/scripts/check-suite.sh" <n> <file>` with `run`: the clean shape (K1) exits 0 with the summary line; each of K2 (no argument, one argument, a non-number, zero, three arguments), K3 (a missing file), K4 (an empty file, a blank-only file), K5 (a wrong first plan line), K6 (a second plan line), K7 (one `ok` short), K8 (`# skip` and `# SKIP`), K9 (a `not ok`) and K10 (a stray line) exits non-zero with its contract message fragment; the clean shape and K8 again with CRLF line ends give the same verdicts (K11); and no refusal's output contains the fixture's path. Every failure branch echoes its contract ID first (`K5: …`), so a red names the rule it caught. Run it and save to `$RUN/t004-red.txt`: it must FAIL because the script does not exist yet.
- [ ] T005 [US2] Create `scripts/check-suite.sh` per contract `check-suite.md` and research R2 and R6: `set -u`, the `check-suite.sh: ` die prefix of `scripts/check-versions.sh`, argument checks in bash, then one `awk` program that strips a trailing CR and classifies each line as `data-model.md` lists. Every rule K2–K11 is ONE line ending with the comment `# K<n>` — K11 is the line that strips a trailing CR — (the quickstart's mutants delete that line), and each `# K<n>` appears exactly once in the file. A tagged line holds only its refusal: classification, counting, the read and every `next` go on untagged lines, so deleting any tagged line leaves a clean `1..1`/`ok 1 x` run accepted (contract, last paragraph). Compound rules are written as `if`, never `A && B || C`; awk regexes spell repetitions out. No message prints a path. A header comment says what the script is for, who calls it, and that it replaces hand-written copies. Run T004's test; save to `$RUN/t005-green.txt`: it passes. Run `shellcheck --norc -f gcc scripts/check-suite.sh`; save to `$RUN/t005-shellcheck.txt`: no finding.
- [ ] T006 [US2] In `CONTRIBUTING.md`, in "Running the tests", after the paragraph that begins "Name every suite path", add the paragraph of research R4: a feature quickstart that proves the suite passed saves the output and calls `bash scripts/check-suite.sh <expected> <tap-file>` rather than writing its own check. No count, no path, no banned word.
- [ ] T007 [US2] Run quickstart block 1 and block 3's second half (the suite-check test read by the suite check itself); save to `$RUN/t007.txt`: `K1-K11 ok`.

**Checkpoint**: `bats tests/check-suite.bats` reads `1..1`, `ok 1`.

---

## Phase 3: User Story 3 — the C4 note (Priority: P3)

**Goal**: FR-008.

- [ ] T008 [US3] In `specs/016-release-two-plugins/contracts/version-agreement.md`, insert the note of research R5 after the last paragraph of clause C4 and before the `## C5` heading, separated by blank lines, as a blockquote beginning `> **Later note, 2026-10-01 (feature 023):**`. Change no existing line.
- [ ] T009 [US3] Run quickstart blocks 1 and 5; save to `$RUN/t009.txt`: `FR-008 ok`, `FR-007 ok`, `FR-010 ok`.

---

## Phase 4: Polish

- [ ] T010 Run the whole of `quickstart.md` (blocks 1–6) as one extracted script with `bash`, in the background or with a timeout of at least 20 minutes; save to `$RUN/final-quickstart.txt`. It ends `ALL OK`, with the gate mutant red, every suite-check mutant K2–K11 red, and SC-004 read by `scripts/check-suite.sh 242`.

---

## Dependencies & Execution Order

- Phase 1 before Phase 2: Phase 2's T007 and the quickstart use only
  Phase 2's files, but Phase 4 needs both.
- Within a phase, tasks run in order: each test is written and shown red
  before its code.
- Phase 3 depends on Phase 1 (the note describes the release form's new
  rule).
- Nothing here tags, pushes or publishes.

## Implementation Strategy

Phase 1 closes the gap the 1.3.0 release only caught by hand. Phase 2 ends
the copying. Phase 3 corrects the record. Each phase is one commit a
reviewer can read alone.
