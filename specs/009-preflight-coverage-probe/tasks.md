---

description: "Task list for 009-preflight-coverage-probe"
---

# Tasks: preflight.sh coverage and a probe helper

**Input**: Design documents from `/specs/009-preflight-coverage-probe/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md — **all complete and measured.** No task below needs to re-derive a fixture shape or re-measure a behaviour; every one is recorded in research.md.

**Tests**: This feature *is* tests. Thirteen new ones, each watched failing before it is trusted.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to
- Every task names its exact file path

---

## Two rules that bind every task below

### The red-first drill — part of each test task, never a task of its own

A test is not done when it passes. It is done when it has been **watched failing
for the right reason** and then watched passing. Inside the same task:

1. **Invert the operative assertion** — change what it asserts to the opposite,
   or to a value that must not match. **Never delete the test**: a deleted test
   proves only that the file was edited.
2. **Echo the altered line back** and read it. A mutation that silently matched
   nothing produced a confident, wrong answer during this feature's own research
   until its diff was checked.
3. **Run the single test. Watch it go red**, and read the failure message —
   confirm it failed on the assertion you inverted, not on something else.
4. **Restore the assertion. Run it again. Watch it go green.**

A test task that skips this is not complete, whatever its result says.

### Two agents never edit the same file

**All thirteen tests live in one file**, `pipeline/tests/preflight.bats`, so the
test tasks are **strictly sequential** — none is marked `[P]`, and no fan-out
applies to them. The six fixture trees are separate directories and *are*
parallel. Say this out loud rather than discovering it mid-batch.

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: the one helper every later task calls. Nothing consumes it yet, so
nothing can break yet.

- [ ] T001 (FR-017) Add `PIPELINE`, `PROBE` and `BASH_ABS` to `tests/helper.bash`, resolved at load time beside the existing `HANDOFF` and `HOOK`. `BASH_ABS` **must** be resolved at load time — a test that has already narrowed its own search path cannot find `bash` to resolve. See contracts/probe-helper-contract.md, "What it adds to that file".
- [ ] T002 (FR-017) Add the `probe` helper function to `tests/helper.bash`, exactly per contracts/probe-helper-contract.md: a thin pass-through taking an optional leading `--path <dir>`, with `run --separate-stderr` at the function's own level and **never inside a subshell**. It supplies no probe flag of its own. **Verifiable when done**: the full suite still reports `1..134` — nothing calls the helper yet, so adding it must change no result. If a count moved, `tests/helper.bash` broke something for another suite.

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: convert the existing suite and prove the conversion changed nothing.

**⚠️ CRITICAL**: T005 is a hard checkpoint. No new test may be added before it
passes. Without it, every later red has two possible causes and the run has to
bisect to find out which.

- [ ] T003 (FR-019) Convert all twenty-four probe call sites in `pipeline/tests/preflight.bats` to the `probe` helper. Mechanical substitution only: same arguments, same order, same assertions. Each call site still names its own fixture at the call site (FR-020).
- [ ] T004 Remove the now-dead `PF=` assignment from `setup()` in `pipeline/tests/preflight.bats`. `PROBE` supersedes it. **This is the only removed line in the whole conversion that is not a probe invocation** — the contract says so and the quickstart's Block 6 exempts exactly it. Leave `FIX` alone; leave the suite's header comment alone.
- [ ] T005 **CHECKPOINT.** Run the full house suite from the repository root. It must report **`1..134`**, zero `not ok`, exit 0 — and `pipeline/tests/preflight.bats` alone must still report **`1..20`**. The conversion adds no test and changes no result. **If either number moved, stop and fix the conversion before going any further.**
- [ ] T006 Run quickstart Block 5 (the probe invocation line appears exactly once, and no stray direct invocation remains) and Block 6 (every removed line is a probe invocation or the one exempt assignment) against `pipeline/tests/preflight.bats`. Both must pass before any new test is written.

---

## Phase 3: User Story 1 — every way the probe can refuse is proven to say why (P1)

**Goal**: four refusals, each proven to name its own fault. **SC-008** is the red-first drill on all four: each must go red when the naming it asserts is changed to name something else.

**Independent test**: drive the probe into each refusal and assert both the
non-zero result and the naming.

**No fixture is needed for this story.** Three of the four refuse before reading
anything; the fourth constructs an empty search path in the per-test temporary
directory.

- [ ] T007 [US1] Add the unrecognised-argument test to `pipeline/tests/preflight.bats` (FR-001). Assert a non-zero exit **and** that the diagnostic stream names the offending argument **and** lists the legal ones. Red-first drill: invert the message assertion to a string the probe cannot emit.
- [ ] T008 [US1] Add the flag-without-its-value test to `pipeline/tests/preflight.bats` (FR-002). Assert on the substring the script chose. **Do not assert on the line number or the script path** — that line comes from the shell's own parameter expansion, and its line number moves whenever the script is edited (FR-024). Red-first drill: invert the substring assertion.
- [ ] T009 [US1] Add the cannot-enter test to `pipeline/tests/preflight.bats` (FR-003). Assert the message names the directory it was given. Red-first drill: invert the assertion to a different path.
- [ ] T010 [US1] Add the required-data-tool-absent test to `pipeline/tests/preflight.bats` (FR-004), using the helper's `--path` with an **empty** directory in `BATS_TEST_TMPDIR`. Assert non-zero **and** that the refusal names the data tool — an empty search path can break the probe several ways, and a test asserting only a non-zero exit would pass for any of them. Red-first drill: invert the tool-name assertion.

**Checkpoint**: the suite reports `1..138`; this suite reports `1..24`.

---

## Phase 4: User Story 2 — every way the probe warns and continues, plus the governance parser (P1)

**Goal**: four warning conditions and two parser edges, six tests. Every warning
test asserts on the **diagnostic stream's content** (FR-009) and confirms the
**data stream still parses whole** (FR-010) — the probe exits zero in all of
these, so exit status carries no information.

**Independent test**: construct each condition, confirm the warning names it, and
confirm the data stream is unharmed.

### The six fixture trees — parallel, different directories

Exact contents are in data-model.md, Part 2. **Build them from that document; do
not improvise.** Each is tracked; the ignore rules already re-include the
fixtures tree, verified with controls in both directions including the new
`.agents/` shape.

- [ ] T011 [P] [US2] Create `pipeline/tests/fixtures/speckit-no-version/` per data-model.md §1 — init-options carrying a flavour and **no version key**, plus both `.specify` directories and a local skills entry.
- [ ] T012 [P] [US2] Create `pipeline/tests/fixtures/speckit-no-flavour/` per data-model.md §2 — the mirror: a version and **no script key**.
- [ ] T013 [P] [US2] Create `pipeline/tests/fixtures/foreign-agent/` per data-model.md §3. **There must be no `.claude/skills/speckit-*` and no `.claude/commands/speckit.*.md` anywhere in this tree** — either one silences the warning entirely. That is the measured negative control.
- [ ] T014 [P] [US2] Create `pipeline/tests/fixtures/constitution-nul/` per data-model.md §4 — a UTF-16LE save, written with one `printf` and the octal escapes given there.
- [ ] T015 [P] [US2] Create `pipeline/tests/fixtures/constitution-bom/` per data-model.md §5 — **a mark followed by nothing but whitespace.** A mark followed by real prose is vacuous; measured twice, in two sessions.
- [ ] T016 [P] [US2] Create `pipeline/tests/fixtures/constitution-unclosed/` per data-model.md §6 — the comment **on the very first byte**, principles after it. Any real text before the comment makes the fixture vacuous; measured in this feature's research.
- [ ] T017 [US2] (FR-023) Verify all six fixtures with quickstart Block 8 (controls in both directions, then each fixture visible and not ignored). Then drive the probe against each and confirm it produces the single outcome data-model.md records for it — before any test depends on them.

### The six tests — sequential, one file

- [ ] T018 [US2] Add the empty-recorded-version test to `pipeline/tests/preflight.bats` (FR-005), reading `speckit-no-version`. Assert the warning's content, exit 0, and that the data stream parses whole. Red-first drill: invert the warning assertion.
- [ ] T019 [US2] Add the empty-recorded-flavour test to `pipeline/tests/preflight.bats` (FR-006), reading `speckit-no-flavour`. Same three assertions. Red-first drill: invert the warning assertion.
- [ ] T020 [US2] Add the foreign-agent test to `pipeline/tests/preflight.bats` (FR-007), reading `foreign-agent`. Assert the warning **and** an invocation form of `none`, **together, in one run** — the requirement asks for both. Red-first drill: invert the invocation-form assertion.
- [ ] T021 [US2] Add the unreadable-encoding test to `pipeline/tests/preflight.bats` (FR-008), reading `constitution-nul`. Assert the warning names the condition and that the file reads as **not** carrying principles. Red-first drill: invert the reads-as-not-set assertion.
- [ ] T022 [US2] Add the byte-order-mark test to `pipeline/tests/preflight.bats` (FR-014), reading `constitution-bom`. Assert the file reads as **not** carrying principles. Red-first drill: invert that assertion.
- [ ] T023 [US2] Add the unclosed-comment test to `pipeline/tests/preflight.bats` (FR-015), reading `constitution-unclosed`. Assert the file **does** read as carrying principles — the rest of the file was not swallowed. Red-first drill: invert that assertion.
- [ ] T024 [US2] **SC-009 drill for the four warning tests** (T018, T019, T020, T021). For each: `cp` the probed script to a temporary path, remove that one warning from the **copy**, print the copy's diff and confirm it is exactly what was intended, drive the test through the copy and watch it go red, then confirm `git diff` on `pipeline/scripts/preflight.sh` is **empty**. **Never mutate the tracked script.** That is how this feature's research was done and why the script's diff stayed empty throughout.

**Checkpoint**: the suite reports `1..144`; this suite reports `1..30`.

---

## Phase 5: User Story 3 — the announced degradations are proven per cause (P2)

**Goal**: two tests. Both build a shim search path in `BATS_TEST_TMPDIR`; neither
adds a tracked file.

**Independent test**: construct each cause and assert the announced skip list
names the right phase for the right reason.

- [ ] T025 [US3] Add the runtime-check-skip test to `pipeline/tests/preflight.bats` (FR-011): the existing mobile fixture probed through a shim path that omits the device tool. **Select the `N.5` entry by phase — never read the first element of the list**; this run also announces a review skip, so an indexed read passes or fails on ordering. Assert the reason names the tool. Red-first drill: invert the reason assertion.
- [ ] T026 [US3] Add the **one** review-skip test to `pipeline/tests/preflight.bats` (FR-012), exercising **both** causes inside it. One test, not two — it is one branch in the script reached by two routes, and two tests would make fourteen against a stated thirteen. Route (a): a client shim **on the path** plus a non-GitHub remote — without the shim this passes here for route (b)'s reason and proves nothing. Route (b): a GitHub remote and **no** client shim. Include the **negative control**: client shim present **and** a GitHub remote must produce an **empty** skip list. **Do not duplicate the already-covered no-remote case.** Red-first drill: invert the negative control's assertion.

**Checkpoint**: the suite reports `1..146`; this suite reports `1..32`.

---

## Phase 6: User Story 4 — the last unpinned base-branch route is pinned (P2)

**Goal**: one test, and one detail that decides whether it means anything.

**Independent test**: run the probe where neither of the first two routes is
available, and assert both the branch and the reported route.

- [ ] T027 [US4] Add the base-branch fallback test to `pipeline/tests/preflight.bats` (FR-013): a scratch repository in `BATS_TEST_TMPDIR` initialised on a named branch, **with one empty commit**, probed with the base-branch flag **omitted entirely**. Assert both the branch name and that the route is named as the fallback. **The commit is load-bearing** — on an unborn branch the reported branch is the literal string `HEAD`, because the command the fallback uses exits 128 while printing that word, and the script discards the status. Without the commit the route assertion still passes while the branch name means nothing. Red-first drill: invert the branch-name assertion.

**Checkpoint**: the suite reports `1..147`; this suite reports `1..33`.

---

## Phase 7: User Story 5 — the suite stops paying for twenty-four near-identical spawns (P3)

**Goal**: verification only. **The implementation happened in Phase 2**, because
every later phase calls the helper, so it could not wait for its priority order.
This phase is where its acceptance is proven.

**Independent test**: the converted call sites produce the same results as
before, and the number of tests does not move.

- [ ] T028 [US5] Prove SC-004 with quickstart Block 5: the probe invocation line appears exactly once in the repository, as the helper's body, and no stray direct invocation remains in `pipeline/tests/`. **`run --separate-stderr` on its own is not unique to the probe** — `pipeline/tests/progress.bats` uses it twice for a different script and always did, so the needle must pair the `run` with the probe.
- [ ] T029 [US5] Prove SC-005 with quickstart Block 6: in the diff against the base branch, every removed line in `pipeline/tests/preflight.bats` is a probe invocation, save the one exempt `PF=` assignment.
- [ ] T030 [US5] Prove FR-018 against contracts/probe-helper-contract.md, "Conformance": all eight call shapes are expressible, and the suite as written uses each shape the contract lists.

---

## Phase 8: Polish and cross-cutting

- [ ] T031 (SC-001) Run quickstart Block 1 from the repository root: the full house suite reports **`1..147`**, zero `not ok`, exit 0. Redirect to a file and test the captured status — **never pipe the suite into `tail` or `head`**, which discards the status and cuts the plan line.
- [ ] T032 Run quickstart Block 2 (both sub-blocks): this suite reports `1..33`, and the only changed `.bats` file is `pipeline/tests/preflight.bats`. Together with Block 1 this pins SC-003 mechanically: 147 − 134 = 33 − 20 = 13.
- [ ] T033 [P] Run quickstart Block 3: `git diff` on `pipeline/scripts/preflight.sh` is empty (FR-021, SC-006).
- [ ] T034 [P] Run quickstart Block 4: no changelog path appears in the diff. **There are three changelog files** — the check covers all of them rather than naming one (FR-022, SC-007).
- [ ] T035 [P] Run quickstart Block 7: no test was added for the multi-line comment case, and the existing test covering it was not removed or altered (FR-016, SC-010).
- [ ] T036 [P] (SC-011) Run quickstart Block 9: no machine-specific path entered any file this feature wrote. Needles are built from character codes so the scan cannot match its own text; the file list includes files not yet committed; an empty scan exits non-zero rather than printing a clean zero.
- [ ] T037 Run quickstart Block 10, the decoy drill, for every row of its table. Plant, watch red, remove, confirm the file's object hash returns to its original value. **No `git checkout`, no `git clean`, no `git stash`.** A block that stays green with its decoy planted is a broken block — fix the block, not the decoy.
- [ ] T038 Write the thirteen red-first drill records into `.delivery-kit/runs/009-preflight-coverage-probe/progress.json` under `measurements.H`, one entry per test in `pipeline/tests/preflight.bats`: the test's name, the assertion that was inverted, the altered line as echoed back, and the failure message the red produced. **SC-002 cannot be checked after the fact** — it is satisfied while each test is written or it is not satisfied at all, so this task records evidence rather than re-deriving it. A missing entry means that drill did not happen; say so rather than filling it in.

---

## Dependencies

```text
Phase 1 (T001-T002)  the helper
        |
Phase 2 (T003-T006)  convert -> CHECKPOINT 1..134 / 1..20
        |            <-- HARD GATE: nothing new before this passes
        |
        +--> Phase 3 (US1, T007-T010)   no fixture needed
        +--> Phase 4 (US2, T011-T024)   six fixtures, then six tests
        +--> Phase 5 (US3, T025-T026)   shim paths only
        +--> Phase 6 (US4, T027)        scratch repo only
        |
Phase 7 (US5, T028-T030)  verification of the Phase 2 work
Phase 8 (T031-T038)       whole-suite and quickstart
```

**Story independence**: US1, US2, US3 and US4 are genuinely independent of one
another — different behaviours, different constructions, no shared fixture. They
are ordered by priority, not by dependency. **US5 is the exception**: its
implementation is Phase 2 because everything else calls it.

## Parallel opportunities

| Where | What | Why not more |
|---|---|---|
| T011–T016 | the six fixture trees | separate directories, no shared file |
| T033–T036 | four independent quickstart blocks | read-only checks over different properties |

**Everything else is sequential**, and this is not a missed opportunity — all
thirteen tests live in `pipeline/tests/preflight.bats`, and two agents never edit
one file in the same batch. A fan-out here would serialise into conflicts.

## Implementation strategy

**The order is fixed and is not a preference.** Helper → convert → **checkpoint**
→ fixtures → tests. The checkpoint at T005 is what makes every later red
attributable to a new test rather than to the conversion; skipping it trades a
two-minute run for a bisect.

**MVP scope**: Phase 1 + Phase 2 + Phase 3 (US1). That delivers the helper, the
converted suite and the four refusal tests — `1..138` — and is independently
valuable: the refusal messages are what a person reads at the moment nothing
works yet.

**Incremental delivery**: each phase ends on a stated suite count, so a run that
stops between phases leaves a tree whose state is known from a number rather
than from memory.
