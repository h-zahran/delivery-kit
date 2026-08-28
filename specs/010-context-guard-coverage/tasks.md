---

description: "Task list for 010-context-guard-coverage"
---

# Tasks: context-guard.sh coverage and a config fixture helper

**Input**: Design documents from `/specs/010-context-guard-coverage/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md — **all complete and measured, each behaviour with a control.** No task below re-derives a payload shape or re-measures a behaviour.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to
- Every task names its exact file path

---

## Three rules that bind every task below

### The red-first drill — part of each test task, never a task of its own

1. **Invert the operative assertion.** Never delete the test — a deleted test
   proves only that the file was edited.
2. **Echo the altered line back** and read it. A mutation that silently matched
   nothing produced a confident, wrong answer in Phase 9 until its diff was
   checked.
3. **Run the single test, watch it go red**, and confirm it failed on the line
   you altered.
4. **Restore, re-run, watch it go green.**

### Two of the seven need more than an inverted status

Their behaviour is a **silent success**, and the guard exits 0 on nearly every
path — so inverting a status assertion proves nothing:

- **The sweep test** asserts the aged file is gone **and** the fresh one kept.
  Inverting only the first would still pass against a run that deleted
  everything.
  **What shipped is wider than this.** Review showed one-aged-plus-one-fresh
  cannot tell `-mtime +7` from `+3` through `+6`. The test now straddles the
  boundary with a seven-day file kept beside an eight-day file gone, and
  covers all three swept name patterns rather than one.
- **The empty-readings test** asserts the output is empty on a run whose rig
  would otherwise have warned.

### Every test lives in one file

All seven go into `handoff/tests/context-guard.bats`, so the test tasks are
**strictly sequential** — none is `[P]`, and no fan-out applies. Said here
rather than discovered mid-batch.

---

## Phase 1: Setup (shared infrastructure)

- [x] T001 (FR-010, FR-011) Add `write_config <path> <body>` to `tests/helper.bash`, exactly per contracts/fixture-helper-contract.md. **Both parameters are required by measurement**: four of the twenty-seven sites write the USER configuration file, and there are nineteen distinct bodies. It writes the body **verbatim** — several are deliberately invalid and must reach the validator unrepaired.
- [x] T002 (FR-012) Add `bytes_of <file> <lines>` to `tests/helper.bash`. Four call sites. The trailing-whitespace strip is load-bearing on this platform; one definition cannot be copied wrongly.
- [x] T003 **CHECKPOINT.** Run the full house suite from the repository root. It must still report **`1..147`**, zero `not ok`, exit 0 — nothing calls either helper yet, so adding them must change no result.

---

## Phase 2: Foundational (blocking prerequisites)

**⚠️ T006 is a hard checkpoint. No new test may be added before it passes.**

- [x] T004 (FR-013) Convert the twenty-six convertible configuration-writing sites in `handoff/tests/context-guard.bats` to `write_config`. Mechanical substitution: same target, same body, same assertions. **Twenty-two write the repository file and four write the user file** — the target stays visible at every call site (FR-014). **Three sites are NOT converted**: each carries a top-level key the guard does not own, or writes to a non-configuration file. The conversion script asserts 26/3/4 and refuses to write unless all three counts match.
- [x] T005 (FR-012, FR-012a) Convert the four byte-cap sites to `bytes_of` in `handoff/tests/context-guard.bats`. One of them also feeds the site that builds its configuration body by substitution — the caller interpolates before calling, and no exception is needed.
- [x] T006 **CHECKPOINT.** Full house suite still **`1..147`**; `handoff/tests/context-guard.bats` alone still **`1..51`**. **If either moved, fix the conversion before going further** — otherwise every later red has two possible causes.
- [x] T007 (FR-011a, SC-005) Run quickstart Block 5 against `handoff/tests/context-guard.bats`: **exactly three** literal configuration writes remain, and they are the expected three — the patch-file site, the existing-configuration site, and the `profile`-carrying site. Then Block 6: every removed line is a configuration write or a byte-cap idiom.

---

## Phase 3: User Story 1 — the two paths that only run on a real machine (P1)

**Goal**: the working-directory fallback and repository-root discovery, each with the control that makes it mean something.

**Independent test**: build a payload that reaches the configuration step without a working directory; run from a subdirectory of a repository.

- [x] T008 [US1] Add the working-directory fallback test to `handoff/tests/context-guard.bats` (FR-001). Payload carries a **valid transcript** and no working directory; run the guard from a directory holding configuration and assert it warns. **Add the control in the same test**: the same payload from a directory holding no configuration must be silent. Red-first drill: invert the warning assertion.
- [x] T009 [US1] Add the repository-root discovery test to `handoff/tests/context-guard.bats` (FR-002). Working directory **two levels** below a repository root that holds configuration — two, because one level is explainable by a plain parent search. **Control in the same test**: the same shape with no repository must be silent. Red-first drill: invert the warning assertion.
- [x] T010 [US1] (FR-003, SC-004) Record in `handoff/tests/context-guard.bats`, as a comment inside each of those two tests, **why the warning itself proves the payload reached the configuration step**: a payload that died at the earlier gate exits silently, so a warning cannot be produced without having passed it. No separate assertion is needed, and saying so stops a later reader adding a redundant one.

**Checkpoint**: the guard suite reports `1..53`.

---

## Phase 4: User Story 2 — the quiet housekeeping and empty-input paths (P2)

- [x] T011 [US2] Add the seven-day sweep test to `handoff/tests/context-guard.bats` (FR-004). Age one flag file past the threshold by setting its timestamp back, leave a second fresh, and **drive the guard to WARN** — the sweep runs only after the firing decision. Assert the aged file is **gone** and the fresh one **kept**; removal alone would also be satisfied by anything that cleared the directory. Red-first drill: invert the kept-file assertion, not only the removed one.
  - **Shipped wider, after review.** The task as written is left above because
    it is the record of what was asked. Two rounds of review found the
    fixture it describes proves only that *an* age filter exists: measured,
    `-mtime +0`/`+3`/`+4`/`+5`/`+6`/`+365` are all indistinguishable from
    `+7` against one aged and one fresh file. The shipped test plants a
    **seven-day** file that must survive beside an **eight-day** file that
    must go — the only pair that separates `+7` from `+6` — and plants all
    three swept name patterns, an aged file none of them name, and an aged
    directory that one does. Every mutant listed above now goes red.
- [x] T012 [US2] Add the empty-readings test to `handoff/tests/context-guard.bats` (FR-005). A transcript that **exists** and parses to nothing usable. Assert exit 0 and **empty output**, against a rig that would otherwise have warned. Red-first drill: invert the empty-output assertion.

**Checkpoint**: the guard suite reports `1..55`.

---

## Phase 5: User Story 3 — a payload with no session identifier (P2)

- [x] T013 [US3] Add the missing-identifier test to `handoff/tests/context-guard.bats` (FR-006). Assert the guard warns **and that its flag file is named for the placeholder** — that filename is the only externally visible proof the substitution happened, and "did not crash" is nearly unfalsifiable. Red-first drill: invert the filename assertion.

**Checkpoint**: the guard suite reports `1..56`.

---

## Phase 6: User Story 4 — the two overrides, behaviourally (P2)

- [x] T014 [US4] Add the proportional-threshold test to `handoff/tests/context-guard.bats` (FR-007). One setting that must warn and one that must not, against the same rig. Assert on the **reason wording** — the proportional path words itself as a percentage of the window. Red-first drill: invert the silent case.
- [x] T015 [US4] Add the absolute-threshold test to `handoff/tests/context-guard.bats` (FR-008). **Pin the proportional threshold at 99%**, or it fires first and this test passes with the absolute setting doing nothing at all. Assert on the **reason wording** — the absolute path words itself as a token count past a token threshold. Red-first drill: invert the silent case.
- [x] T016 [US4] (FR-009, SC-010) Confirm the existing documentation-snippet test in `handoff/tests/context-guard.bats` is **untouched and still passing**. It counts variable names in a documentation file; it is a real test of a real thing, it is not coverage of either override, and it must not be removed to make room.

**Checkpoint**: the guard suite reports `1..58`; the house suite `1..154`.

---

## Phase 7: User Story 5 — the fixture helpers (P3)

**The implementation happened in Phases 1 and 2**, because every later phase would otherwise wait on it. This phase is where its acceptance is proven.

- [x] T017 [US5] (SC-005) Prove quickstart Block 5 against `handoff/tests/context-guard.bats` on the finished tree: exactly three literal configuration writes, and they are the three named ones.
- [x] T018 [US5] (SC-006) Prove quickstart Block 6 against `handoff/tests/context-guard.bats` on the finished tree: the conversion added, removed and altered no assertion.
- [x] T019 [US5] Prove the contract's six conformance shapes are all expressible, per contracts/fixture-helper-contract.md — including a write to the user configuration file and a deliberately invalid body.

---

## Phase 8: Polish and cross-cutting

- [x] T020 (SC-001) Run quickstart Block 1 from the repository root: **`1..154`**, zero `not ok`, exit 0. Redirect to a file and test the captured status — never pipe the suite into `tail`.
- [x] T021 (SC-003) Run quickstart Block 2, both parts: the guard suite is `1..58`, and the only changed `.bats` file is `handoff/tests/context-guard.bats`.
- [x] T022 [P] (FR-015, SC-007) Run quickstart Block 3: `git diff` on `handoff/hooks/context-guard.sh` is empty.
- [x] T023 [P] (FR-016, SC-008) Run quickstart Block 4: no changelog path appears in the diff. **Three changelog files exist**; the check covers all of them.
- [x] T024 [P] (SC-010) Run quickstart Block 7: the documentation-snippet test was not removed or altered.
- [x] T025 [P] (SC-011) Run quickstart Block 8: no machine-specific path entered anything this feature wrote. Needles built from character codes; the file list includes files not yet committed; an empty scan exits non-zero.
- [x] T026 (FR-017, SC-012) Confirm the strict-vocabulary scan over `handoff/tests/` passes with the new tests in place. This runs inside the house suite — Block 1 is its check, and no duplicate is added.
- [x] T027 Run quickstart Block 9, the decoy drill, for every row of its table. Plant, watch red, remove, confirm the object hash returned. **No `git checkout`, `git clean` or `git stash`.**
- [x] T028 (SC-002) Write the seven red-first drill records into `.delivery-kit/runs/010-context-guard-coverage/progress.json` under `measurements.H`: the test's name, the assertion inverted, the altered line as echoed back, and the failure message. SC-002 cannot be checked after the fact — a missing entry means that drill did not happen, and the record must say so rather than fill it in.
- [x] T029 [US4] (SC-009) Run the override-removal drill for T014 and T015, on `handoff/tests/context-guard.bats`. This is **beyond** the red-first inversion and is not the same drill: for each override test, remove the override the test sets — leaving everything else as it is — and confirm the test goes **red**, then restore it and watch it go green. Inverting an assertion proves the assertion is load-bearing; removing the override proves the OVERRIDE is. Record both in the run state.
- [x] T030 (FR-018) Confirm no new line reference entered any file this feature wrote, on `specs/010-context-guard-coverage/` and the two modified files. FR-018 was discharged at Phase A — three of the seed's eight references had drifted, one because Phase 9 moved it — and this task is the standing half: the documents this feature adds must anchor to content so they cannot drift the same way for Phase 11.
- [x] T031 **Measure `handoff/tests/context-guard.bats` runtime before and after**, and record both numbers in the run state. Phase 9 nearly doubled a suite's runtime and only noticed afterwards; plan.md claims that will not happen here, and a claim about performance is worth what its measurement is worth.

---

## Dependencies

```text
Phase 1 (T001-T003)  the two helpers -> CHECKPOINT 1..147
        |
Phase 2 (T004-T007)  convert 27 + 4  -> CHECKPOINT 1..147 / 1..51
        |            <-- HARD GATE: nothing new before this passes
        +--> Phase 3 (US1, T008-T010)
        +--> Phase 4 (US2, T011-T012)
        +--> Phase 5 (US3, T013)
        +--> Phase 6 (US4, T014-T016)
        |
Phase 7 (US5, T017-T019)   verification of the Phase 1-2 work
Phase 8 (T020-T029)        whole-suite, quickstart, records
```

**Story independence**: US1 to US4 are genuinely independent — different paths, different payloads, no shared fixture. They are ordered by priority, not dependency. **US5 is the exception**: its implementation is Phases 1–2 because everything else builds on the converted suite.

## Parallel opportunities

| Where | What | Why not more |
|---|---|---|
| T022–T025 | four independent quickstart blocks | read-only checks over different properties |

**Everything else is sequential.** All seven tests live in one file, and two agents never edit one file in the same batch. This is a fact about the work, not a missed opportunity.

## Implementation strategy

**The order is fixed.** Helpers → convert → **checkpoint** → tests. The
checkpoint at T006 is what makes every later red attributable to a new test.

**MVP scope**: Phases 1, 2 and 3. That delivers both helpers, the converted
suite, and the two tests for paths that run for every real user and for no test
— `1..149` — and it is the half of this feature that closes a real gap rather
than tidying one.

**Incremental delivery**: each phase ends on a stated count, so a run that stops
between phases leaves a tree whose state is known from a number.

---

## Progress at the 2026-08-28 handoff

**T001 to T007 are complete and ticked above.** The context guard fired during
T007's verification; the boundary is named in the handoff document.

**T008 is the exact next action** — the working-directory fallback test. Nothing
in Phases 3 to 8 has been started.

One correction landed inside T007 and is already reflected in this file and in
the quickstart: **running** the conversion found a THIRD unconvertible site that
neither the seed nor the specification named. Counts are **26 convert, 3 stay**,
not 27 and 2.
