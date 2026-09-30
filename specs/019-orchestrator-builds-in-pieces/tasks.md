# Tasks: the orchestrator builds in pieces

**Input**: Design documents from `specs/019-orchestrator-builds-in-pieces/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/orchestrator-prose.md, quickstart.md

**Tests**: REQUIRED. FR-024 and SC-001 demand a pin for each obligation, each shown red before the prose lands and red again under an INVERTED mutant after.

**Run directory**: `.delivery-kit/runs/019-orchestrator-builds-in-pieces/` (ignored by git) holds every saved output below. Written `$RUN` below.

## Format: `[ID] [P?] [Story] Description`

## ⚠️ Four rules that override anything below

1. **Sentences come from the contract, byte for byte.** Every sentence a task adds to `SKILL.md` is copied from `contracts/orchestrator-prose.md` — the test pins the same string. Retyping one by hand is how an em dash becomes a hyphen and a pin goes red for a reason nobody wrote.
2. **Red first, in the checkout.** A new pin is written before its prose and run against the unchanged `SKILL.md`; it must be `not ok` with its own message. A new pin that is green before its prose exists proves nothing — fix it before writing the prose.
3. **Mutations happen in a scratch tree, never in the checkout** (memory: a mutation rig belongs in a worktree). The rig echoes each mutated line before its result is believed, and exits non-zero on a mutant that changed nothing.
4. **Do not edit the whole-region spans.** `## When a phase fails`, `## Red flags`, **J**, **N** and **Seed forms** carry byte-exact spans (`prose.bats:569-660`, `:699`). No task writes inside them; H points at "When a phase fails" instead (research R1).

---

## Phase 1: Setup

- [X] T001 Run the house suite from the repository root and save its verbatim output to `$RUN/baseline-suite.txt`: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`. Record the plan line, ok count, not-ok count, non-TAP line count and exit code in `$RUN/baseline-counts.txt`. Expect `1..226`, 226 ok, 0 not ok, 0 non-TAP, exit 0. **If the count is not 226, stop and report** — every later count is arithmetic on it.
- [X] T002 Record `git rev-parse HEAD` to `$RUN/baseline-sha.txt`, and copy `pipeline/skills/pipeline/SKILL.md` and `pipeline/tests/prose.bats` unchanged to `$RUN/SKILL.md.orig` and `$RUN/prose.bats.orig`.

---

## Phase 2: Foundational

- [X] T003 Write the mutation rig `$RUN/mutate.py`: for each mutant in a list of `(name, file, old, new)`, build a scratch tree (a `mktemp -d` holding copies of `.claude-plugin/`, `tests/`, `handoff/` and `pipeline/`, then `git init -q` — the suite's `find_root` accepts it), replace `old` with `new` in that tree's copy of `file` exactly once, matching `old` with its whitespace normalised (each run of spaces in `old` matches any run of spaces and newlines, because contract sentences wrap freely in the file) and refusing when it matches zero or several times, write the file back with `newline=''` so no CR is added, echo the mutated region, run `bats pipeline/tests/prose.bats` there, and report `CAUGHT` when some test is `not ok` and `MISSED` otherwise. Exit non-zero on a no-op mutant, on a zero-or-many match, or on any `MISSED`. Prove the rig with one control mutant against an EXISTING pin (the G lead sentence at `prose.bats:216` inverted to "STOP AND ASK, even when"): it must print `CAUGHT`. Save to `$RUN/t003-rig-control.txt`.

**Checkpoint**: the rig catches a known mutant and refuses a no-op.

---

## Phase 3: User Story 1 — the developer chooses how to review, at G (Priority: P1) 🎯 MVP

**Goal**: G asks commits-or-pauses on every `claude` run, records it, never re-asks it, and never lets `--auto` collapse it; the handoff path says in one line that pieces are off.

**Independent Test**: `bats pipeline/tests/prose.bats -f 'review question'` passes, and G's slice holds sentences C2, G1–G6.

### Tests for User Story 1 (write first, run red)

- [X] T004 [US1] In `pipeline/tests/prose.bats`, replace the pin at `:218` (the old G pre-answer sentence) with the two C2 sentences from `contracts/orchestrator-prose.md`, keeping the test's flattened G slice; and append a new test `G asks the review question on every run and never lets --auto collapse it` that searches the same G slice (the awk range at `:213`) for G1–G6 and G8, one `grep -qF` each with its own message. Keep `@test` names ASCII.
- [X] T005 [US1] Run `bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/prose.bats` and save to `$RUN/us1-red.txt`. The G pre-answer test and the new test must be `not ok`, each failing on its FIRST missing sentence's message; every other test `ok`.

### Implementation for User Story 1

- [X] T006 [US1] In `pipeline/skills/pipeline/SKILL.md`, G section: append G1 to the end of the lead paragraph (the lead's first sentence unchanged); replace the pre-answer sentence with the two C2 sentences; after the re-entry paragraph that ends "stamp it VOID per the G rule below before going on.", add one paragraph holding G2, G3, G4, G5 and G6 in that order, then G8 beside the existing "Record the answer under `gates.G`" sentence (G7 lands in T018). No line in the G slice may start with `**` or `#`.
- [X] T007 [US1] Run `pipeline/tests/prose.bats`; save to `$RUN/us1-green.txt`. Every test `ok`.

**Checkpoint**: G is complete; H still builds in one pass.

---

## Phase 4: User Story 2 — the run builds and commits one piece at a time (Priority: P1)

**Goal**: H commits the spec first, then loops `piece-next` → build → commit exactly the piece's paths plus `tasks.md` → `commit-add`.

**Independent Test**: the new H test passes, and H's slice holds H1, H3–H12 (with H4b) and H20.

### Tests for User Story 2 (write first, run red)

- [X] T008 [US2] In `pipeline/tests/prose.bats`, append a test `H commits the spec, then one commit per piece, every path named` that takes `prose_slice '^\*\*H — implement\.\*\*' '^\*\*H\.5 — converge\.\*\*' flat 'phase H'` and pins H1, H3, H4, H4b, H5, H6, H7, H8, H9, H10, H11, H12, H20 and H22, one `grep -qF` each with its own message.
- [X] T009 [US2] Run `pipeline/tests/prose.bats`; save to `$RUN/us2-red.txt`. The new test must be `not ok` on H1's message; every other test `ok`.

### Implementation for User Story 2

- [X] T010 [US2] In `pipeline/skills/pipeline/SKILL.md`, rewrite H (`**H — implement.**` up to `**H.5 — converge.**`): an opening holding H1; a paragraph for the single-commit flow ("Invoke `/speckit-implement`." — today's first sentence); then the piece flow — H3; H4 and H4b; H5 and H6; H7; H8, H9 and H10; H11 and H12; then ONE shared paragraph holding today's fan-out, board and `last_task` sentences ("Fan independent tasks of the same phase … so resume re-enters mid-phase.") followed by H20 — written once, never copied into each flow (Principle IV). Keep `**H — implement.**` as the first bytes of H and add no line starting with `**` or `#` inside H.
- [X] T011 [US2] Run `pipeline/tests/prose.bats`; save to `$RUN/us2-green.txt`. Every test `ok`.

**Checkpoint**: commits mode is fully described.

---

## Phase 5: User Story 3 — in pause mode, the developer reviews each piece first (Priority: P2)

**Goal**: pause mode stops after each piece, before its commit, shows it, and takes go on / fix this / stop here.

**Independent Test**: the new pause test passes, and H's slice holds H13–H16, H19 and H21.

### Tests for User Story 3 (write first, run red)

- [X] T012 [US3] In `pipeline/tests/prose.bats`, append a test `a pause shows the piece, takes three answers, and --auto never collapses it` over the same H slice as T008, pinning H13, H14, H15, H16, H19 and H21.
- [X] T013 [US3] Run `pipeline/tests/prose.bats`; save to `$RUN/us3-red.txt`. The new test must be `not ok` on H13's message; every other test `ok`.

### Implementation for User Story 3

- [X] T014 [US3] In `pipeline/skills/pipeline/SKILL.md`, H: add a pause-mode paragraph after the commit paragraph holding H13, H14, H15, H16 and H21, and H19 beside H11/H12.
- [X] T015 [US3] Run `pipeline/tests/prose.bats`; save to `$RUN/us3-green.txt`. Every test `ok`.

**Checkpoint**: both review modes are described.

---

## Phase 6: User Story 4 — a stopped or crashed run resumes at the right piece (Priority: P2)

**Goal**: a hook rejection is a hard stop without `--no-verify`; a legacy state file keeps the single-commit flow; Resume enters the piece `piece-next` names.

**Independent Test**: the two new tests pass; H holds H2, H17, H18; G holds G7; Resume holds R1.

### Tests for User Story 4 (write first, run red)

- [X] T016 [US4] In `pipeline/tests/prose.bats`, append a test `a hook that rejects a piece commit is a hard stop, never --no-verify` over the H slice pinning H17 and H18; and a test `a state file without a review answer keeps the single-commit flow` pinning H2 over the H slice, G7 over the G slice (the awk range at `:213`, flattened) and R1 over `prose_slice '^## Resume$' '^## Not in v1$' flat 'resume'`.
- [X] T017 [US4] Run `pipeline/tests/prose.bats`; save to `$RUN/us4-red.txt`. Both new tests `not ok` on their first sentence's message; every other test `ok`.

### Implementation for User Story 4

- [X] T018 [US4] In `pipeline/skills/pipeline/SKILL.md`: in H, add H2 after H1, and a hook paragraph holding H17 and H18 after the commit paragraph; in G, add G7 at the end of the review-question paragraph T006 wrote; in `## Resume`, add a paragraph holding R1 after the existing one.
- [X] T019 [US4] Run `pipeline/tests/prose.bats`; save to `$RUN/us4-green.txt`. Every test `ok`.

**Checkpoint**: H and Resume are complete.

---

## Phase 7: User Story 5 — the document stays true everywhere else (Priority: P3)

**Goal**: the `--auto` row, the gate floor, the Implementer row, Parallel agents, the never-bend reason and MAY-do say what the new G and H do.

**Independent Test**: the new floor test and the changed flags-row pin pass.

### Tests for User Story 5 (write first, run red)

- [X] T020 [US5] In `pipeline/tests/prose.bats`: in `auto never collapses the release gate`, replace the flags-row pin at `:66` with the new row C1 from the contract; append a test `the gate floor counts the review question, and every commit names every path` pinning GT1, GT2, GT2b, GT3, GT4 and GT5 over `prose_slice '^## Gates$' '^## Parallel agents$' flat 'gates'`, GT6, CF1, CF2 and CF3 as raw rows over the file (`grep -qxF`), P1 over `prose_slice '^## Parallel agents$' '^## The rules that never bend$' flat 'parallel'`, N1, N2 and N3 over `prose_slice '^## The rules that never bend$' '^## Red flags' flat 'never-bend'`, PF1 over the walk awk range at `:123` (flattened), and each of the seven ABSENT strings in the contract as absent from the flattened file, each with its own message. Write every negative pin in exactly this form, because both obvious forms are wrong under bats: `if grep -qF -- "$s" <<<"$flat"; then echo "old wording is back: $s"; false; fi`. (`n=$(grep -cF …)` exits 1 on a zero count and aborts the test in the GREEN state; a bare `! grep -qF` never fails a bats test.)
- [X] T021 [US5] Run `pipeline/tests/prose.bats`; save to `$RUN/us5-red.txt`. The flags-row test and the new test `not ok`; every other test `ok`.

### Implementation for User Story 5

- [X] T022 [US5] In `pipeline/skills/pipeline/SKILL.md`, copying every sentence from the contract: replace the `--auto` row with C1; replace the `implementer` and `commitStyle` configuration rows with CF1 and CF3 and the `--implementer` flag row with CF2; in pre-flight item 9 replace "like G whenever `implementer` is unset or `ask`, it needs an answer only the owner can give" with PF1; in `## Gates`, replace the "Up to five stops …" paragraph with the contract's text (holding GT1, and no longer listing "a pre-answered `implementer` at G"), replace the floor paragraph with "State the floor honestly." + GT2 + GT2b + GT4 (dropping "— but no gate does" and "a run CAN reach DONE without a single gate stopping it"), start the "That combination …" paragraph with GT5 and keep its last two sentences, replace the Implementer row with GT6, and add GT3 after the conditional-stops paragraph; in `## Parallel agents`, replace "H — independent tasks in the same phase" with P1; in the never-bend table, replace the `git add -A` row's reason's first sentence with N1 (left cell unchanged); in MAY-do, add N2 after "create and check out the feature branch," and replace the closing sentence with N3. Afterwards re-run the seven contract slices through `prose_slice`/awk: each still opens and closes on its boundary.
- [X] T023 [US5] Run `pipeline/tests/prose.bats`; save to `$RUN/us5-green.txt`. Every test `ok`.

**Checkpoint**: every FR-001–FR-024 sentence is in place and pinned.

---

## Phase 8: Polish & cross-cutting

- [X] T024 [P] In `pipeline/CHANGELOG.md`, open `## [Unreleased]` above `## [1.2.1] - 2026-09-08`, with `### Added` (piece commits: the spec commit, one commit per `tasks.md` phase, each recorded; pause mode and its three answers) and `### Changed` (stating plainly that G now stops on every run whose implementer is `claude`, for the review question, even under `--auto` and with `implementer` pre-answered). Keep the heading shapes `tests/` checks. The changelog is scanned with the full banned-vocabulary list: name the implement command generically ("the spec tool's implement command"), never by its tool-specific slash name.
- [X] T025 [P] Write the dry read `specs/019-orchestrator-builds-in-pieces/dry-read-017.md`: in a scratch directory (a `git init -q` tree; `STATE_ROOT` is relative to the working directory, so run from there), `init` a scratch run with the repository's `pipeline/scripts/progress.sh`, point `artifacts.tasks` at the ABSOLUTE path of `specs/017-guard-config-bounds/tasks.md`, then loop `piece-next` → record the printed piece with `commit-add <feature> piece <sha> "$piece" "$tasks" <file>` (a made-up 40-character lowercase-hex sha, DIFFERENT for every piece or `commit-add` refuses it as a conflict, and one placeholder file per piece, since `commit-add` refuses a `piece` entry with no files) until it prints nothing, capturing each output through `$()`. Record the pieces in order with their task IDs, measured; mark the `## Phase 7` piece as appended by that run's H.5 (017 `tasks.md:183`), which H.5 commits as kind `converge` in a real run, so H would never see it; and for each piece whether it would change only `tasks.md`, read from its tasks' text (research R11). Save the raw loop output to `$RUN/t025-dry-read.txt`. The saved `dry-read-017.md` names paths repo-relative ONLY — never the scratch directory or the absolute tasks path — because the tree-wide machine-path scan cannot see an uncommitted file and CI would find it first.
- [X] T026 Run the SC-004 greps from `quickstart.md` step 3 — one per ABSENT string in the contract — on the flattened new `SKILL.md` and, as the positive control for EACH grep, on the flattened `$RUN/SKILL.md.orig`; save to `$RUN/t026-sc004.txt`. Every grep 0 on the new file and at least 1 on the original.
- [X] T027 Mutation sweep with `$RUN/mutate.py` (T003): one INVERTED mutant per pin in `contracts/orchestrator-prose.md`, the ID list READ FROM THE CONTRACT by the rig (every bullet ID, plus C1, C2a, C2b), never typed by hand — the rig fails unless the number of mutants equals the number of contract IDs equals the number of new `grep -qF` pins in `prose.bats`. Each mutant is rewritten to assert the opposite (for example G3 "`--auto` never collapses it" → "`--auto` collapses it"; H18 "is never used" → "is used when a hook blocks the piece"), plus one mutant per ABSENT string restoring it. Save to `$RUN/t027-mutations.txt`. Every mutant `CAUGHT`; the rig exits 0.
- [X] T028 Run the house suite from the repository root and save to `$RUN/t028-final-suite.txt`. Expect `1..(226+N)` where N is the number of `@test` blocks added (count them with `grep -c '^@test' pipeline/tests/prose.bats` against `$RUN/prose.bats.orig`), N+226 ok, 0 not ok, 0 non-TAP, exit 0. List every added and every changed test by name in `$RUN/t028-added-tests.txt`, and save the old and new text of C1 and C2 (FR-005, FR-020) there too — the commit message quotes both (SC-002).
- [X] T029 [P] Run `git diff --name-only main...HEAD` plus `git status --porcelain` and confirm only `pipeline/skills/pipeline/SKILL.md`, `pipeline/tests/prose.bats`, `pipeline/CHANGELOG.md` and `specs/019-orchestrator-builds-in-pieces/` changed (SC-005); run `shellcheck --norc -f gcc` over `git ls-files '*.sh' '*.bash'` minus `.specify/`. Also run the suite's machine-path pattern (`TREE_PATHS` in `tests/portability.bats:93`) directly over `specs/019-orchestrator-builds-in-pieces/` — the tree-wide scan walks `git ls-files`, and this directory is not committed yet, so the scan cannot see it. Save all three to `$RUN/t029-scope.txt`; 0 hits required. (The three-OS CI run is checked after the push, at L and N — it cannot run before.)

---

## Dependencies

- Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8.
- US2–US4 all edit H in `SKILL.md` and append to `prose.bats`, so they run in order, never in parallel.
- US5 edits other sections of the same two files; it runs after US4 to keep one writer per file.
- T024, T025 and T029 touch different files and may run in parallel; T026–T028 read the finished files and run after them.

## Parallel opportunities

Within this feature, only Phase 8's `[P]` tasks. Every story writes the same two files.

## Implementation strategy

MVP is US1 + US2: G asks the question and commits mode works. US3 adds pause mode; US4 makes a stop or crash safe; US5 makes the rest of the document agree. Each story is red, then green, before the next starts.

---

## Phase 9: Convergence

Appended by the converge assessment (H.5), 2026-09-29. Verdict: converged on FR-001 to FR-026 and SC-001 to SC-005; these are its Low findings.

- [X] T030 In `pipeline/CHANGELOG.md` (`### Changed`), replace "A run started on an earlier version keeps the single-commit flow for its whole life." with wording true under FR-004b and FR-018: a run started on an earlier version that has already passed G keeps the single-commit flow for its whole life; one that has not yet completed G is asked the review question there. Re-run `tests/portability.bats` per FR-004b (contradicts)
- [X] T031 In `specs/019-orchestrator-builds-in-pieces/spec.md` Assumptions, add `pipeline/skills/status/SKILL.md:21-23` to the Phase 22 list: step 4 reports G as parked only when `gates` holds no answer, so a pre-answered `gates.G.answer` waiting at the review question, and a paused H, both read wrongly per FR-001, FR-012 (partial)
- [X] T032 In `specs/019-orchestrator-builds-in-pieces/spec.md` Edge Cases, record beside "K in this phase" that H.7 (`SKILL.md` "scoped to `codeRoots`") and I ("the spec, plan, tasks and diff") do not say WHICH diff; in the piece flow most of H is committed before they run, so a working-tree diff is nearly empty — Phase 21 must name the range (base..HEAD). Not changed here: FR-026 freezes them, and nothing ships between Phase 20 and Phase 21 per Edge Cases (partial)
- [X] T033 In `pipeline/tests/prose.bats`, test `the gate floor counts the review question, and every commit names every path`: assert the pre-flight walk slice's last line starts with `**Base branch:**` before PF1 is searched, so a renamed closer cannot widen the slice to end of file; prove it with one mutant renaming `**Base branch:**` in a scratch tree (`$RUN/mutate.py`), expecting that test red, saved to `$RUN/t033-mutation.txt` per plan: slices (partial)
- [X] T034 In `specs/019-orchestrator-builds-in-pieces/dry-read-017.md` row 6, say that H.5 committing the appended phase as kind `converge` is Phase 21's behaviour (ruling 18), not the orchestrator's today per SC-003 (partial)
