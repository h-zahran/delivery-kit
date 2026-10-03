---

description: "Task list for the release gate closing the gaps Phase 25 left"
---

# Tasks: The release gate closes the gaps Phase 25 left

**Input**: Design documents from `specs/025-gate-closes-phase25-gaps/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: the spec asks for tests (FR-006, FR-018, SC-004). Each test
change is written FIRST and shown red before the code it covers is
written. One new test is added; the suite reads `1..249`.

**Run directory**: `$RUN` = `.delivery-kit/runs/025-gate-closes-phase25-gaps/`.

**Pieces**: each `## Phase` below is one piece and one commit.

**Commit messages**: no `Co-Authored-By`, no `Claude-Session` and no
"Generated with" line, in any commit or pull-request text this run writes.

**Every gate run in a test** goes through `run bash -c '…' _ <args>` with
the data as arguments (FR-011), never `run bash <script>.sh` (the
one-script test counts those).

## Format: `[ID] [P?] [Story] Description`

## Phase 1: User Story 1 — no byte hides a heading or the gate's reason (Priority: P1)

**Goal**: FR-001-FR-007; contract K1-K5, K7.

**Independent Test**: quickstart blocks 1-3 pass, and block 4's base-gate
mutant turns a test red naming K1, K3 or K5.

- [X] T001 [US1] In `tests/portability.bats`, after the test "--released judges no non-heading, and only the named plugin", add the test `--released refuses a byte or a line it cannot judge` (ASCII name). It builds a one-plugin fixture with `forms_base one` and plants, each on a fresh copy after `Plain text.` and a blank line, IN THIS ORDER, so that against an older gate the first red names K1, not a timeout: (K1) `CRplant`, a LONE CR, `## x` — built with `$'\r'`, never a literal CR byte in the file; prove the CR landed by counting CR bytes in the copy with `tr -cd '\r' | wc -c` (exactly 1), and find its line with `grep -n -F 'CRplant'`, never a grep pattern holding a CR; assert a non-zero exit, `line <n> holds a carriage return` and `CRplant?## x`. (K3, K4) a line of 1,001 `x` bytes: refused, `line <n> is 1001 bytes long`, the quote exactly 200 `x` then ` [cut]`; a line of exactly 1,000: not refused for its length. (K4) a line holding a lone `\x9b` byte and `## x`: the refusal shows `?` for it and holds no `\x9b` byte. (K5) a NUL byte inside a body line: both the default form and `--released` exit non-zero, saying `holds a NUL byte` and naming the plugin. (K3) LAST of all, after K1 and the 1,001-byte plant, a line of 400,000 `> ` markers then `x`: refused for its length. Long lines are located with `LC_ALL=C awk 'length($0) > 1000 { print NR }'`, never passed to `forms_at` or `grep` as an argument (an 800 KB argument fails on Linux). (K4) across every plant, no output line is longer than 400 characters. Every failure branch echoes its clause first (`K1: …`), a fixture failure echoes `fixture: …`, and every captured output passes the absolute-path check (U2; until T011 exists, the existing `$TEST_DIR`/`$ROOT` case). Also in the test "--released refuses a dangling Unreleased heading, and the default run does not", add a plant (K2): a first heading `## [Unreleased] ` followed by an escape sequence (ESC `[31m`) above the release; assert the default form exits as it does today and its `state=` field holds `?` where the ESC was and no ESC byte; assert the `--released` refusal holds no ESC byte. Run both tests and save to `$RUN/t001-red.txt`: they must FAIL on a K assertion, not a fixture error.
- [X] T002 [US1] In `scripts/check-versions.sh`: set the line limit and the quote cut ONCE, as named shell values beside the dated pattern, passed to awk through the environment as the pattern is (research R4), and used by the bash first-heading refusal too; (K5) in the per-plugin loop, before the dated-heading `grep`, count NUL bytes in `./$p/CHANGELOG.md` with `tr -cd '\000' | wc -c`, compared with arithmetic, and `die "$p: CHANGELOG.md holds a NUL byte, which the gate cannot read — this tree is NOT released"` in both forms; (K2) mask `$first` with `${first//[![:print:]]/?}` in the `UNRELEASED-ABOVE:` field and in the first-heading refusal, and cut the refusal's quote of `$first` to the quote cut with ` [cut]`, both under `LC_ALL=C` (a helper function with a local `LC_ALL`), so both count and mask bytes; run the walk's awk under `LC_ALL=C`; (K3) as the walk's first per-line rule refuse a line longer than the limit: `line <n> is <len> bytes long, longer than the release form judges: '<show>'`; (K1) as the second rule, refuse a raw line holding a CR: `line <n> holds a carriage return, which Markdown reads as a line end: '<show>'`; (K4) make `show()` mask, then cut a text longer than the quote cut to its first characters plus ` [cut]`. No count in a comment; no interval expression. A comment in the file's style says why each rule comes first, why the walk runs under the C locale, and why a CR is refused, not split.
- [X] T003 [US1] Run T001's two tests, every other `--released` test and "one version-agreement script, and both gates call it"; save to `$RUN/t003-green.txt`: all pass, the plan line equal to the ok count. Run quickstart blocks 1-2; save to `$RUN/t003-default.txt`: `K7 ok`. Then one mutant per new rule in a scratch worktree (remove the NUL check; remove the masking of `$first`; raise the line limit far above the plant; remove the CR rule; remove the cut), each confirmed landed by printing the mutated line, each turning T001's test or the dangling test red naming K5, K2, K3, K1 or K4; save to `$RUN/t003-mutants.txt`. Run `shellcheck --norc -f gcc scripts/check-versions.sh`; save to `$RUN/t003-shellcheck.txt`: no finding.

**Checkpoint**: the new test passes, and the base-gate mutant turns it red.

---

## Phase 2: User Story 2 — a safe shape is not refused, where that is proven (Priority: P2)

**Goal**: FR-008-FR-010; contract K6; research R6-R10.

**Independent Test**: quickstart block 7 prints one `KEPT` or `REVERTED`
line per narrowing and exits 0.

- [X] T004 [US2] Write `specs/025-gate-closes-phase25-gaps/proof/enumerate.py` (research R10). It takes the gate script's path and extracts the walk's awk program byte-for-byte from it. It frames every case as a changelog (the release heading, a blank line, `Plain text.`, a blank line, then the case) and generates every sequence of ONE TO THREE lines before (from: none, `Para`, `- a`, `> Para`, `1. a`, `1.`, `5. a`, `123456789. a`, `1234567890. a`, `<details>`, `<div>`, `<pre>`, `<x`, `<!--`, `-->`, `</details>`, `### Plantnote`, `> Notes`, `>`, a blank line, `  - b`), a prefix (none, two, three and four spaces, `> `, `>`, `- `, `  - `, `1. `, `2. `, `2) `, `10. `, `1234567890. `, `- > `, `> - `, `    > `), a body (a fence opener then `## x` then a closer, with the body lines both at column zero and at the opener's continuation indent; a fence opener, then `-->` or `</pre>`, then `## x`, then a closer; `### x`; `>`; `---`; `--`; `## x`) and a line after (none, `## x`, `  ## x`, `    ## x`, `---`, `Notes` then `---`, `> ---`, `-->`). For each case it asks markdown-it-py (CommonMark mode) whether a level-2 heading other than the release heading is rendered. It runs the walk in batch (per-file state reset, `nextfile` on a refusal, the end check per file) after checking the batch copy against the full gate on a handful of cases, TWICE, in generated and reversed order; it reruns one file per walk run every case where the two orders disagree and a fixed-seed sample of 2,000 cases the reader renders as a level-2 heading, and reports a disagreement as a reset bug (non-zero exit). It finds bash with `shutil.which`, never the bare name. It holds each narrowing's positive control as an explicit text substitution on the extracted walk; a substitution that changes nothing is an error. It decides KEPT or REVERTED per narrowing by running the gate's walk on that narrowing's passing plant (refused: REVERTED, no control run; passed: KEPT, and its control must find at least one wrong pass). It prints per walk the case count, the rendered-heading count, the wrong-pass count and the run time, then one line `KEPT <N>` or `REVERTED <N>` per narrowing. It exits non-zero for each cause research R10 lists (the gate's walk passes a rendered heading; a kept narrowing's control finds none; the two orders disagree; a sampled rerun disagrees with the batch; a control substitution changes nothing), and zero otherwise. It holds no machine path. Run it against today's walk (every narrowing REVERTED) and save to `$RUN/t004-baseline.txt`: 0 wrong passes, and the run time recorded. If the run takes more than 30 minutes, draw the third line before only from each narrowing's own lines, and record that.
- [X] T005 [US2] N1 (research R6): in `tests/portability.bats`, first add to the `judges no non-heading` test the passing plant `1. a`, `2. ` + a fence, `   code`, three spaces + a fence closer, and to the `code fence whose end is unclear` test the still-refused neighbours `Para`, `1.`, `2. ` + a fence and `1234567890. a`, `2. ` + a fence (`Para`, `2. ` + a fence is already there) (K6); show the passing plant red. Then in `scripts/check-versions.sh` implement the R6 rule, with its one-to-nine-digit count done by a loop. Run the proof with the narrowed walk and with its positive control (R6 without the non-empty and nine-digit conditions); save to `$RUN/t005-proof.txt`. If either half fails, revert the rule and the passing plant, and record under FR-010 in `spec.md` why N1 stays refused.
- [X] T006 [US2] N2 (research R7): plants first — passing: `<details>`, a blank line, `x`, a blank line, `</details>`, a blank line, a fence, `code`, a fence; still refused: `<!--`, a fence, `-->`, `## x`, a fence (already there), `<div>`, a fence with no blank line between, and `<x`, `<!--`, a blank line, a fence, `-->`, `## x`, a fence. Then implement R7 in `scripts/check-versions.sh`, classifying EVERY `<` line whatever the current state. Proof with the narrowed walk and its positive control (every `<` line cleared at a blank); save to `$RUN/t006-proof.txt`. Revert and record under FR-010 if either half fails.
- [X] T007 [US2] N3 (research R8): plants first — passing: `### Plantnote`, `---`; move Phase 25's `### x` then `---` out of the refused loop in the `every bare level-2 heading form` test into the passing plants; still refused: `- a`, `  ### x`, `  ---` and `Para`, `    > ### x`, `---` (already there) and `> ### x`, `> ---`. Then implement R8. Proof with the narrowed walk and its positive control (any `###` line counted as a heading); save to `$RUN/t007-proof.txt`. Revert and record under FR-010 if either half fails, putting the `### x` plant back in the refused loop.
- [X] T008 [US2] N4 (research R9): plants first — passing: `> Notes`, `>`, `> ---`; still refused: `Para`, `    >`, `---` (already there). Then implement R9. Proof with the narrowed walk and its positive control (an indented `>` counted as an empty quote line); save to `$RUN/t008-proof.txt`. Revert and record under FR-010 if either half fails.
- [X] T009 [US2] Run `enumerate.py` once more over the walk holding every kept narrowing, together; save to `$RUN/t009-proof.txt`: 0 wrong passes, one `KEPT` or `REVERTED` line per narrowing. Run every `--released` test and the one-script test; save to `$RUN/t009-green.txt`. Run `shellcheck --norc -f gcc scripts/check-versions.sh`: no finding.

**Checkpoint**: every narrowing is kept with its proof, or reverted with its reason in the spec.

---

## Phase 3: User Story 3 — the tests can fail, and say why (Priority: P3)

**Goal**: FR-011-FR-017; contract H8 (reworded), U1-U6.

**Independent Test**: quickstart blocks 3 and 5 pass, and one mutant per
helper change turns a test red.

- [X] T010 [US3] In `tests/portability.bats`, change every `run bash -c` in the `--released` tests (the two older ones, `forms_base`, `forms_refused`, `forms_passes`, `forms_default`, the two-plugin run, and T001's test) to pass the directory, the root and the plugin name as arguments: `run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$d" "$ROOT" "$copied"` for the release form and the same without `--released "$3"` for the default form (U1). Keep the "one version-agreement script" test green unchanged.
- [X] T011 [US3] Add a helper `forms_no_path` that fails, naming U2, when `$output` holds the test directory or the root in any spelling: as given; the `-m`, `-u` and `-w` forms of `cygpath` where it exists; where it does not, the `/c/…` and `C:/…` forms built with parameter expansion when the path has a drive letter. Call it after EVERY `run` in the `--released` tests, passing runs included (U2). Show it red with a mutant gate that prints its own directory on a passing run.
- [X] T012 [US3] Make each `--released` test's combined default-form copy hold every refused plant of that test that the default form accepts, each after its own `Plain text.` and blank line, leaving out by name the NUL plant and a first heading above the release (H8 reworded, FR-013); the contract's H8 already says so.
- [X] T013 [US3] Make `forms_passes` take the line it planted and call `forms_at` on it before judging (U3); update every caller.
- [X] T014 [US3] In `normalise_to_released`: drop any line holding a CR and any line longer than 1,000 bytes, with the helper's own constants, its awk run under `LC_ALL=C` so it counts bytes as the gate does (U6, FR-017); replace the self-check's second half with an independent bash test over the dropped file (a different code path from the awk program) that fails on any line the gate could refuse; guard the `mv` with a `fixture:` message (U4). Keep the dated-pattern self-check and never read a pattern from the gate.
- [X] T015 [US3] Make `forms_at` take its count with `|| true` and print `fixture: …` when the line is missing, under errexit as well (U5).
- [X] T016 [US3] One mutant per helper change, each in a scratch worktree, each confirmed landed: a gate printing an absolute path on a passing run (T011 goes red naming U2); a `forms_passes` call whose plant is missing (red naming the fixture); a fixture helper that keeps a `## Notes` line (its self-check fails); `mv` made to fail (the helper fails); a `forms_at` call on a missing line (prints `fixture:`). Save to `$RUN/t016-mutants.txt`. Run quickstart blocks 1 and 5; save to `$RUN/t016.txt`: `FR-017 ok`.

**Checkpoint**: every helper change has a mutant that turns a test red.

---

## Phase 4: Polish

- [ ] T017 Run the whole of `quickstart.md` (blocks 1-8) as one extracted script with `bash`, in the background, with no timeout shorter than the proof's recorded run time plus 20 minutes; save to `$RUN/final-quickstart.txt`. It ends `ALL OK`, with the gate mutant red naming a K clause, the proof's `KEPT`/`REVERTED` lines, and SC-006 read by `scripts/check-suite.sh 249`.

---

## Dependencies & Execution Order

- Phase 1 before Phase 2: the proof extracts the walk Phase 1 changed.
- Phase 2 before Phase 3: Phase 3 rewrites every gate call, including the
  plants Phase 2 adds.
- Within each phase, a test change is written and shown red before the
  code it covers.
- Phase 4 needs all three.
- Nothing here tags, pushes or publishes. SC-006's CI half is checked by
  the pipeline after these tasks: L confirms a run exists for the pushed
  head, and N and DONE read every job's steps.

## Parallel Opportunities

None worth taking: almost every task edits `tests/portability.bats` or
`scripts/check-versions.sh`, and the narrowings in Phase 2 must be proven
one at a time and then together.

## Implementation Strategy

Phase 1 closes the last known wrong pass and the silent exits. Phase 2
relaxes only what a proof allows. Phase 3 makes the tests able to fail.
Each phase is one commit a reviewer can read alone.
