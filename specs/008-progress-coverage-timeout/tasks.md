---

description: "Task list for 008-progress-coverage-timeout"
---

# Tasks: progress.sh coverage and a timeout for every suite

**Input**: Design documents from `/specs/008-progress-coverage-timeout/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/refusal-contract.md, quickstart.md

**Tests**: Tests ARE the deliverable here. Every user story below produces test
code; there is no separate implementation to test. The usual "write the test,
watch it fail, then implement" is inverted, and that inversion is the single
most important thing to understand before starting — see **The red-first rule**
below.

**Organization**: grouped by user story, in the spec's priority order.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel — different files, no dependency on incomplete work
- **[Story]**: US1…US4, mapping to the spec's user stories
- Every task names the exact file it touches

## Path Conventions

Repository tooling. Four files change, all under a test tree:

- `tests/helper.bash` — the fixture all six suites load
- `tests/layout.bats` — loses its own limit assignment
- `tests/portability.bats` — folding becomes a function; its test drives it
- `pipeline/tests/progress.bats` — eleven tests appended

`pipeline/scripts/progress.sh` is the **subject** of the new tests and is **not
modified**. It is mutated temporarily during red-first proofs and restored, with
the restoration verified by hash.

---

## ⚠️ The red-first rule — read before starting

These eleven tests cover behaviour that **already works**. There is no fix to
land after them, so "see it red first" cannot mean "run it before the feature
exists". It means this instead:

> For each new test, **break the thing the test watches**, run the test, watch it
> go red, then restore and watch it go green.

**Break the script's message, not the test's own expected string, wherever
possible.** Changing the test's expectation to something absurd proves only that
the test compares two strings. Changing the *script's* message proves the test is
actually watching the script — which is the property that matters.

Three rules bind every mutation, all bought the hard way in the previous phase:

1. **Echo the mutated line before believing the red.** A substitution that
   silently matched nothing produces a green that looks like proof.
2. **Restore from a saved copy and verify by `git hash-object`.** Not by eye, and
   not by re-running the substitution backwards.
3. **Never leave a mutation in place across tasks.** One task, one mutation, one
   restoration, checked.

---

## Phase 1: Setup

**Purpose**: establish the ground truth every later task is measured against.

- [X] T001 Confirm the working tree is clean and the branch is `008-progress-coverage-timeout`, using `git status --porcelain` and `git rev-parse --abbrev-ref HEAD` from the repository root
- [X] T002 Capture the pre-feature baseline into `.delivery-kit/runs/008-progress-coverage-timeout/baseline-suite.txt` by running the house suite from the repository root and saving its output verbatim; confirm it reports `1..123`, 0 failures, exit 0
- [X] T003 [P] Confirm `ps` or `pkill` is on the path; record the result in `.delivery-kit/runs/008-progress-coverage-timeout/baseline-inventory.txt`. bats implements the per-test limit itself and needs one of those two, **not** an external `timeout` program — and it refuses loudly with exit 1 rather than passing quietly when it has neither. This task originally named the wrong prerequisite and called the failure silent; corrected after review, by reading bats' source and measuring it three ways
- [X] T004 [P] Record the current per-suite test counts into `.delivery-kit/runs/008-progress-coverage-timeout/baseline-inventory.txt` by running each of the six suites alone, so any later movement in a suite this feature did not intend to touch is visible

**Checkpoint**: the baseline exists on disk, in a file, not in anyone's memory.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: locate every insertion point by content. **The seed's line numbers
are stale** — the previous phase added 266 lines to `tests/portability.bats`, so
at least one cited range no longer points at what it names (FR-022).

**⚠️ CRITICAL**: no user story work begins until these locations are confirmed.

- [X] T005 Locate the limit assignment in `tests/layout.bats` by grepping for the setting's name, and confirm by line number that it sits **above** that file's `load` line — this is what makes it dead code once the fixture sets the value
- [X] T006 [P] Locate the folding block and the `.leakwords` test in `tests/portability.bats` by grepping for the join command and for the test's name; record both line ranges in `.delivery-kit/runs/008-progress-coverage-timeout/baseline-inventory.txt` and note where they differ from the seed's cited ranges
- [X] T007 [P] Confirm the end of `pipeline/tests/progress.bats` and its current test count, so the eleven new tests are appended after the last existing test and nothing existing is displaced

**Checkpoint**: every edit site is known by content. No task below may use a line
number taken from the seed.

---

## Phase 3: User Story 1 — a hung test is named, not left to burn the job (Priority: P1) 🎯 MVP

**Goal**: every suite carries a per-test limit; exactly one file sets it; the
reason it exists survives.

**Independent Test**: a deliberately over-long test is stopped and named, and
every existing test still passes.

- [X] T008 [US1] Add the per-test limit to `tests/helper.bash`, at the top of the file, set to **60** seconds
- [X] T009 [US1] Add the comment above that assignment in `tests/helper.bash` carrying (a) the hazard it guards — a regression getting a named timeout rather than the platform's job cap — moved from the assignment being removed, and (b) the measurement that selected the value: slowest test 7916 ms, margin 7.58×, and that the local machine is the slowest environment measured
- [X] T010 [US1] Remove the limit assignment from `tests/layout.bats`, and remove or fold its now-duplicated comment so no orphaned explanation is left pointing at a line that no longer exists
- [X] T011 [US1] Verify the value reaches a loading suite: create a throwaway suite in a temporary directory that loads `tests/helper.bash` by absolute path and asserts the limit is set and is at least 30; run it and confirm it passes
- [X] T012 [US1] Verify the mechanism stops and names an over-long test: create a throwaway fixture and suite in a temporary directory with a limit of 2 and a test that sleeps 6; confirm the output carries both the limit and the test's own name. Record the captured output in `.delivery-kit/runs/008-progress-coverage-timeout/timeout-proof.txt`. Nothing tracked is edited, so nothing has to be undone. **Use a throwaway, not the real limit** — a proof at 60 seconds would need a test that hangs for a minute
- [X] T013 [US1] Verify exactly one assignment exists across the tracked tree, by enumerating tracked files with `git ls-files` and searching each; confirm the count is 1 and that `tests/layout.bats` is not in the result
- [X] T014 [US1] Verify every suite reaches the fixture by **deriving** the check: over `tests/*.bats`, `handoff/tests/*.bats` and `pipeline/tests/*.bats`, count tracked suite files and count those carrying a `load` line, and confirm the two are equal. Do not write the number six into anything — a seventh suite that forgets its load line must make this fail
- [X] T015 [US1] Run the full house suite over `tests`, `handoff/tests` and `pipeline/tests` from the repository root and confirm every existing test still passes with the limit in place — a limit that reddens honest work has replaced one problem with a worse one

**Checkpoint**: US1 is complete and testable on its own. The suite is still
`1..123`; no test has been added yet.

---

## Phase 4: User Story 2 — the state-reading contract is proven (Priority: P2)

**Goal**: the two promises two shipped documents make about the read path are
tested.

**Independent Test**: the read path's data stream parses whole; the documented
line-ending trap is reproduced deliberately.

- [X] T016 [US2] Append a test to `pipeline/tests/progress.bats` asserting the read path's data stream is accepted whole by `jq`, **and** that a state file broken to be invalid puts zero bytes on that stream while the fault reaches the diagnostic stream and the exit is non-zero (contract RC1, RC2)
- [X] T017 [US2] Append a test to `pipeline/tests/progress.bats` for the line-ending contract: the test **writes** the two-character ending into the state file itself, then asserts `jq` still accepts the read output (RC3), that command substitution captures a clean value (RC4), and that the line-reading idiom the shipped document forbids visibly retains the stray character (RC5)
- [X] T018 [US2] Red-first proof for T016: break the read path's stream separation by temporarily making the script print its validation fault to the data stream; echo the mutated line, run the test, confirm red, restore from the saved copy and confirm `git hash-object` matches the pre-mutation hash
- [X] T019 [US2] Red-first proof for T017: in `pipeline/tests/progress.bats`, temporarily change that test's line-ending construction to write the single-character ending; echo the mutated line, run the test, confirm the stray-character assertion goes red, restore and confirm the hash matches
- [X] T020 [US2] Run `pipeline/tests/progress.bats` alone and confirm it reports two more tests than the baseline recorded in T004, with zero failures

**Checkpoint**: US2 is complete and independent of US1, US3 and US4.

---

## Phase 5: User Story 3 — every refusal names its cause (Priority: P2)

**Goal**: nine refusal paths, each with a test asserting the message names the
fault.

**Independent Test**: each of the nine goes red when the naming it asserts is
changed in the script to name something else.

**All nine tests are appended to one file, so they are NOT marked [P] against
each other** — two agents must never edit `pipeline/tests/progress.bats`
simultaneously. Their red-first proofs mutate one shared script and are
serialised for the same reason.

- [X] T021 [US3] Append the C1 test to `pipeline/tests/progress.bats`: completing an unknown phase exits non-zero and the message names the offending phase, quoted
- [X] T022 [US3] Append the C2 test to `pipeline/tests/progress.bats`: the from-validation path for the phase whose rule needs the plan artefact names that artefact, quoted, and states the record holds none that exists
- [X] T023 [US3] Append the C3 test to `pipeline/tests/progress.bats`: the from-validation path for a phase in the tasks group names that artefact; the test states in a comment which of the group's four phases it drives and that the branch is shared
- [X] T024 [US3] Append the C4 test to `pipeline/tests/progress.bats`: the final refusal names the phase **and all three reasons**; assert all three, because the enumeration is the useful part
- [X] T025 [US3] Append the C5 test to `pipeline/tests/progress.bats`: taking the lock with the session argument omitted names the missing argument
- [X] T026 [US3] Append the C6 test to `pipeline/tests/progress.bats`: **make the lock path a directory**, then take the lock, and assert the message names the remedy. Carry a comment in the test saying it deliberately does **not** run a race and must not be "fixed" into one — the guard above the protected write tests for a regular file, so a directory passes it and makes the write fail, deterministically
- [X] T027 [US3] Append the C7 test to `pipeline/tests/progress.bats`: fewer than two arguments produces the usage refusal; assert the WHOLE enumeration in one comparison, so any drop and any reorder reddens it. (This task originally said "several subcommands including the first and the last"; a review measured five of the eight silently droppable that way, and the test was strengthened.)
- [X] T028 [US3] Append the C8 test to `pipeline/tests/progress.bats`: a completed-phases value crafted as a string is refused, and the message names **both** the state file path and the key
- [X] T029 [US3] Append the C9 test to `pipeline/tests/progress.bats`: a recorded current phase crafted as an unknown value is refused, and the message names the file and the offending value, quoted
- [X] T030 [US3] Red-first proof for all nine, one at a time and serialised: for each, temporarily change the corresponding message in `pipeline/scripts/progress.sh` to name something else; echo the mutated line, run that one test, confirm red, restore from the saved copy, and confirm `git hash-object` matches before starting the next. Record each result in `.delivery-kit/runs/008-progress-coverage-timeout/mutation-log.txt`
- [X] T031 [US3] Confirm `pipeline/scripts/progress.sh` is byte-identical to its pre-task state with `git diff --stat pipeline/scripts/progress.sh`, which must be empty — nine mutations were applied and nine restored
- [X] T032 [US3] Run `pipeline/tests/progress.bats` alone and confirm eleven more tests than the baseline recorded in T004, with zero failures

**Checkpoint**: US3 is complete. Nine refusals are proven to name their cause,
and each was watched failing.

---

## Phase 6: User Story 4 — the private-vocabulary test drives the real folding (Priority: P3)

**Goal**: one copy of the folding, called by both the suite and its test.

**Independent Test**: breaking the one copy turns the test red; under the old
test it would not have.

- [X] T033 [US4] Extract the folding in `tests/portability.bats` into a named function defined in that same file, taking the private list's path and the base vocabulary and returning the folded result. **Preserve today's behaviour exactly**: an absent, empty or all-blank list returns the base unchanged, with no trailing separator and no empty alternative
- [X] T034 [US4] Replace the load-time folding in `tests/portability.bats` with a call to that function using the repository's own path, keeping the existing guard that only folds when the file is present
- [X] T035 [US4] Rewrite the body of the `.leakwords` test in `tests/portability.bats` to call the same function with a fixture path in the test's own scratch directory, keeping all three assertions it already makes: the extra term matches, a blank line produces no empty alternative, and the shipped terms still match alongside it. **The test count must not move** — one test in, one test out
- [X] T036 [US4] Confirm the join command now appears exactly **once** in `tests/portability.bats`; two occurrences would mean the test still carries its own copy, which is the defect this story exists to remove
- [X] T037 [US4] Red-first proof: save a copy of `tests/portability.bats`, break the one copy of the folding so it stops stripping blank lines, echo the mutated line, run the `.leakwords` test alone, confirm red, restore from the copy and confirm `git hash-object` matches
- [X] T038 [US4] Confirm the empty-contribution case explicitly for the new function in `tests/portability.bats`: with a private list that is empty and one that holds only blank lines, the function returns the base vocabulary unchanged — the case whose regression would make the scan match at every position
- [X] T039 [US4] Run `tests/portability.bats` alone and confirm its test count is **unchanged** from the baseline recorded in T004

**Checkpoint**: all four user stories are independently complete.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T040 Run the full house suite from the repository root and confirm `1..134`, zero failures, zero non-conforming output lines, exit 0; save the output to `.delivery-kit/runs/008-progress-coverage-timeout/final-suite.txt`
- [X] T041 Confirm the increase over the baseline is exactly eleven and that no suite other than the two intended ones moved, by comparing `.delivery-kit/runs/008-progress-coverage-timeout/final-suite.txt` against the per-suite counts in `.delivery-kit/runs/008-progress-coverage-timeout/baseline-inventory.txt`
- [X] T042 [P] Scan `specs/008-progress-coverage-timeout/*.md`, `specs/008-progress-coverage-timeout/*/*.md`, `tests/helper.bash`, `tests/layout.bats`, `tests/portability.bats` and `pipeline/tests/progress.bats` for the four banned path shapes and the account name, one fixed string per shape, **firing a control that must match before believing any zero**
- [X] T043 [P] Confirm `git diff --name-only main` touches nothing outside `tests/`, `handoff/tests/`, `pipeline/tests/` and `specs/008-progress-coverage-timeout/`, and that no changelog file appears in it
- [X] T044 Extract every runnable block from `specs/008-progress-coverage-timeout/quickstart.md` and execute them in order; confirm the whole run exits 0 and each block's stated expectation holds. Fix the quickstart where it is wrong — it is a document that must run, not a document about running
- [X] T045 Confirm `git status --porcelain` is clean of unintended changes, and that the four mutation-and-restore cycles left `pipeline/scripts/progress.sh` and `tests/portability.bats` byte-identical
- [X] T046 Confirm the one from-validation branch that was already covered before this feature is neither duplicated nor rewritten: `git diff main -- pipeline/tests/progress.bats` must show that test's block as unchanged, and the suite must contain exactly one test asserting it (FR-011)
- [X] T047 Confirm the folding function is defined in `tests/portability.bats` and is **absent** from `tests/helper.bash` — grep both, and fire a control that must match before believing the zero. A later reader "tidying" the function into the shared file is exactly what FR-019 forbids
- [X] T048 Write the sentence phase K must carry into `.delivery-kit/runs/008-progress-coverage-timeout/commit-note.txt`: which of the two limit assignments survived, and that it was selected by measuring load order rather than by preference (FR-023, SC-012). **No task commits anything** — this task only makes the required wording available to the phase that does

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies
- **Foundational (Phase 2)**: depends on Setup — **blocks all four stories**, because every story edits a file whose insertion point Phase 2 locates by content
- **US1 (Phase 3)**: depends on Phase 2 only
- **US2 (Phase 4)**: depends on Phase 2 only
- **US3 (Phase 5)**: depends on Phase 2 only
- **US4 (Phase 6)**: depends on Phase 2 only
- **Polish (Phase 7)**: depends on all four stories

### File-level serialisation — read this before fanning out

The stories are independent in *purpose* but they are not independent in *files*:

| File | Stories that touch it | Consequence |
|---|---|---|
| `tests/helper.bash` | US1 only | US1 may run alone in parallel with US2/US3 |
| `tests/layout.bats` | US1 only | same |
| `pipeline/tests/progress.bats` | **US2 and US3** | **US2 and US3 must be serialised** — never two agents on this file |
| `tests/portability.bats` | US4 only | US4 may run in parallel with US1 |
| `pipeline/scripts/progress.sh` | US2 and US3 mutations | **all mutation proofs serialised**, one mutation live at a time |

### Safe parallel grouping

- **Group A**: US1 (Phase 3) and US4 (Phase 6) — disjoint files, may run together
- **Group B**: US2 then US3, in that order, both on the same file — never together, and never alongside a mutation from the other

### Within each story

- Write the test, run it green, then break what it watches and watch it go red,
  then restore and confirm the hash. Never the reverse order, and never skip the
  restoration check.

---

## Parallel Example

```bash
# Safe: disjoint files.
Task: "US1 - per-test limit in tests/helper.bash and tests/layout.bats"
Task: "US4 - folding function in tests/portability.bats"

# NOT safe: same file. Serialise these.
# Task: "US2 - read tests in pipeline/tests/progress.bats"
# Task: "US3 - refusal tests in pipeline/tests/progress.bats"
```

---

## Implementation Strategy

### MVP first

Phases 1, 2 and 3. That delivers the per-test limit on its own — the only part
that protects the build rather than improving confidence in a script. The suite
is still `1..123` at that point, which is the expected reading, not a problem.

### Incremental delivery

1. Setup + Foundational → every edit site known by content
2. US1 → the limit reaches all six suites → suite still `1..123`
3. US2 → `1..125`
4. US3 → `1..134`
5. US4 → still `1..134`, one test reworked, count unmoved
6. Polish → quickstart runs, scans clean, diff confined

---

## Notes

- `[P]` means different files and no dependency on incomplete work. On this
  feature that is a narrow set — see the file-level table above.
- **No task commits, pushes, branches, merges, tags or publishes.** Those belong
  to the pipeline's own later phases, behind their own gates.
- Every count in this file is a target the run is measured against. A mismatch
  is a finding by definition, never a footnote.
- Nothing here writes a changelog entry. The campaign's routing ruling assigns
  this phase none.
