---

description: "Task list for the release form reading every level-2 heading form"
---

# Tasks: The release gate reads every level-2 heading form

**Input**: Design documents from `specs/024-gate-every-heading-form/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: the spec asks for exactly one new test (FR-013). It is written
FIRST and shown red before the code it covers is written.

**Run directory**: `$RUN` = `.delivery-kit/runs/024-gate-every-heading-form/`.

**Pieces**: each `## Phase` below is one piece and one commit.

**Commit messages**: no `Co-Authored-By`, no `Claude-Session` and no
"Generated with" line, in any commit or pull-request text this run writes.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: User Stories 1 and 2 — the release form reads every heading form, and nothing else (Priority: P1)

**Goal**: FR-001–FR-011 and FR-013; contract H1–H9.

**Independent Test**: `bats -f 'every level-2 heading form' tests/portability.bats`
runs exactly one test, and it passes.

- [ ] T001 [US1] In `tests/portability.bats`, directly after the test "--released refuses an undated heading below the release, and the default run does not", add one test named exactly `--released refuses every level-2 heading form, and judges no non-heading` (ASCII only: bats 1.11 silently skips a test whose name is not). It builds and normalises a released fixture the way that test does (copy each plugin's `plugin.json` and `CHANGELOG.md` and the marketplace, call `normalise_to_released` on its own line, require `--released <copied>` to pass first), then runs one plant at a time on a fresh copy. Every plant is APPENDED to the copied plugin's changelog after a blank line, `Plain text.` and a blank line: that unindented paragraph after a blank line clears "a list item can be open" (research R2 step 4), so no plant's reading depends on what came before it. The gate is run only through `run bash -c "cd …; bash \"$ROOT/scripts/check-versions.sh\" …"`, never `run bash <script>.sh` (the one-script test counts those). ALL REFUSED plants run BEFORE any passing plant, so that against an older gate the first red names an H1–H6 clause. Each refused plant asserts a non-zero exit, `is NOT released`, the expected line number and the expected quoted text, AND, on the same copy, that the default form exits 0 with `<copied>: … state=released` (H8). Refused plants, contract `contracts/release-form.md`: H1 `##` + tab + `Notes` (quoted as `##?Notes`); ` ## Notes`; `   ## Notes`; `##` alone; `## Notes ##`. H2 ` ## [1.0.0] - 2026-01-01`. H3 `Notes` then `---` (names the `Notes` line and says `underlined at line <n+1>`). H4 `> ## Notes`; `>## Notes`; `- ## Notes`; `* ## Notes`; `+ ## Notes`; `1. ## Notes`; `1) ## Notes`; `- > ## Notes`; `1. > ## Notes`; `> Notes` then `> ---`; `- Notes` then `  ---` (names the `- Notes` line). H5 `- item`, a blank line, `    ## Notes`; `- item` then `    ## Notes` with no blank line; `- a`, `  - b`, a blank line, `  c`, a blank line, `    ## Notes`; `-` alone (an empty item, after the blank line), then `    ## Notes` (each names the `## Notes` line). H6 three backticks then `unclosed`; three tildes then `unclosed` (each names the fence line and says `never closed`); UNCLEAR fences, each saying `may already have ended` and naming the opener's line and the unclear line: `- ` + three backticks, then `## Notes`; two spaces + three backticks, then three backticks at column 0; `> ` + three backticks, then `x`; `- ` + three backticks, then three spaces + three backticks; four spaces + three backticks, then `## Notes`; `- item`, then two spaces + `> ` + three backticks, then `> ## Notes`; `- > ` + three backticks, then `>` alone; `>` + three backticks, then `>` + four spaces + three backticks. For these, assert `opened at line <n> ` and `at line <m>, which holds '<text>'` (the comma follows the number). A HEADING after a clean close: three backticks, `> ` + three backticks, three backticks, `## Notes` (names the `## Notes` line as H1). For every refused plant, the expected text is the RAW planted line with each non-printable character as `?`, and the expected line number is found with `grep -n -x -F` on that planted line in the copy (the plant is unique in it). H6/FR-009 `## Notes`, a blank line, three backticks, `unclosed`: the output names the `## Notes` line, holds `is NOT released` exactly once, and does not say `never closed`. PASSING plants (H7), each asserting `--released` exits 0: three backticks, `## Notes`, three backticks; the same with `~~~`; `- item`, a blank line, two spaces + three backticks, two spaces + `## x`, two spaces + three backticks (the real tree's shape); a blank line then `---`; `    ## Notes` (four spaces); a tab then `## Notes`; then ALL of these in one changelog, each preceded by its own `Plain text.` and blank line, so that no plant's reading depends on the one before it (a list item left open by one plant would make the next plant's deep `## Notes` judged). H9: a refused plant in the OTHER plugin's changelog leaves `--released <copied>` exiting 0, and no output anywhere in the test contains `$TEST_DIR` or `$ROOT`. Every failure branch echoes its contract ID first (`H1: …`, `H7: …`), and a fixture failure echoes `fixture: …`, so a red names the clause it caught. Run it and save the output to `$RUN/t001-red.txt`: it must FAIL, on an H1–H6 assertion, not on a fixture error.
- [ ] T002 [US1] In `scripts/check-versions.sh`, inside the `if [ "$p" = "$RELEASED" ]` block and after the first-heading comparison, replace the Phase 24 whole-file awk program and its `die` with the walk of research R2, steps 1 to 10 in that order, with R4a and R7: one awk program over `./$p/CHANGELOG.md`, the canonical pattern still passed as `DATED_RE` through the environment; tab expansion with stops every 4 columns; repeated quote removal and the quote depth; the fence rules of step 3 (the opener's continuation prefix; a closer is exactly that prefix then the fence; a line inside must start with the prefix, a blank one must equal it with trailing spaces removed; a closer shape at any other indent, or any other line, is refused as unclear in R7's form) and step 7 (a fence opens at any indent; record its prefix); the list-state clear rule; the setext test BEFORE list-marker removal; repeated removal of list markers AND `>` markers, in any order, until neither applies, any list marker setting "a list item can be open" (a bare `-` not refused at step 5 reaches this step); the fence opener (a backtick opener holding no further backtick); the four-column code rule only when no list item can be open; the ATX test; the previous-line kinds of data-model.md (an indented-code line counts as text); a `refused` flag set before every `exit`; and an END block that reports an open fence only when nothing was refused. It prints one refusal in R7's form, every non-printable character shown as `?`, and the gate dies with `$p: <refusal> — this tree is NOT released`. Indents are counted with a column function: no interval expressions, no `gensub`, no array `length`. A comment in the file's style says what the walk keeps and why each doubt leans to refusing. Change nothing the default form runs, and keep the first-heading check and its message.
- [ ] T003 [US1] Run T001's test, the three other `--released refuses` tests and "one version-agreement script, and both gates call it" from `tests/portability.bats`; save to `$RUN/t003-green.txt`: all pass, plan line equal to the ok count. Run quickstart blocks 1 and 2 (default output byte-identical to `$BASE`'s, and the real tree passes `--released` for both plugins); save to `$RUN/t003-default.txt`: `H8 ok`. Run `shellcheck --norc -f gcc scripts/check-versions.sh`; save to `$RUN/t003-shellcheck.txt`: no finding.

**Checkpoint**: `bats -f 'every level-2 heading form' tests/portability.bats` reads `1..1`, `ok 1`.

---

## Phase 2: User Story 3 — the test fixtures keep their own baseline (Priority: P3)

**Goal**: FR-012; research R5.

**Independent Test**: quickstart block 5 passes.

- [ ] T004 [US3] In `tests/portability.bats`, widen `normalise_to_released` per research R5, with its own patterns and nothing read from the gate. Per changelog, one awk pass, keeping no state, REPEATEDLY removes from a copy of each line leading spaces and tabs, `>` markers (with one optional space or tab after), and list markers (`-`, `*`, `+`, or digits then `.` or `)`, then a space, a tab or the end of the line), testing the line BEFORE the first removal and AFTER every one (a bare `-` is an underline to the gate, and removing it as a list marker would leave an empty string). It drops the line when any of those tested forms is a fence line (three or more backticks or tildes), one or more `-` then only spaces or tabs, or `##` followed by a space, a tab or the end of the line — unless the raw line is exactly canonical. It then ASSERTS the state it leaves by running that same wide test over the result: no line but a canonical one matches, and at least one canonical heading remains; each failure echoes `fixture: …` and returns 1. Keep the existing self-check that the canonical pattern accepts a dated heading and refuses `## [Unreleased]`. Update the helper's comment: why the rule is wider than the gate's, and why it keeps no state. No interval expressions.
- [ ] T005 [US3] Run quickstart blocks 1 and 5; save to `$RUN/t005.txt`: `FR-012 ok`. Then the control in the opposite direction: in a scratch worktree, put back the `$BASE` copy of `tests/portability.bats` (the narrow helper) beside this branch's gate, plant block 5's shapes in every live changelog the marketplace names, and run the `--released refuses` tests; save to `$RUN/t005-control.txt`: at least one goes red with a `fixture:` message, which shows block 5 can fail.

**Checkpoint**: every `--released refuses` test passes on a live changelog holding every refused kind.

---

## Phase 3: Polish

- [ ] T006 Run the whole of `quickstart.md` (blocks 1–7) as one extracted script with `bash`, in the background or with a timeout of at least 20 minutes; save to `$RUN/final-quickstart.txt`. It ends `ALL OK`, with the gate mutant red naming an H clause and SC-005 read by `scripts/check-suite.sh 243`.

---

## Dependencies & Execution Order

- Phase 1 before Phase 2: T005's control needs this branch's gate.
- Within Phase 1, T001 is written and shown red before T002.
- Phase 3 needs both.
- Nothing here tags, pushes or publishes. SC-005's CI half is checked by
  the pipeline after these tasks: L confirms a run exists for the pushed
  head, and N reads each job's steps.

## Parallel Opportunities

None worth taking: T001 and T004 both edit `tests/portability.bats`, and
T002 depends on T001's red.

## Implementation Strategy

Phase 1 closes every wrong pass the owner ruled out. Phase 2 keeps the suite
from reddening on a correct tree when a live changelog holds one of the newly
refused shapes. Each phase is one commit a reviewer can read alone.
