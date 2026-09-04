---

description: "Task list for feature 017 — the guard's own configuration cannot silence it"
---

# Tasks: The guard's own configuration cannot silence it

**Input**: Design documents from `/specs/017-guard-config-bounds/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/threshold-validation.md, quickstart.md

**Tests**: REQUIRED for this feature. The specification demands them by name
(FR-006, FR-007, SC-002, SC-006) and the whole risk here is a suite that goes
green whether or not the work was done.

**Organization**: grouped by user story. US1 is the entire code change; US2 is a
recorded decision with no code; US3 is the written rule catching up with the
enforced one.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelizable — different file, no dependency on an incomplete task
- **[Story]**: US1 / US2 / US3, on user-story phases only

---

## ⚠️ Four rules that override anything below

Each was established by measurement on 2026-09-04 and each is a way this feature
can produce false evidence.

1. **Baseline before edit.** After the one-character change, a green suite is
   ambiguous and there is no way back to an honest "this test could fail".
2. **T005 must be run RED before T008.** It is the only change-prover in the
   feature.
3. **Never claim the 99 pin (T007) as red-before-green.** 99 is valid before and
   after. Its only honest proof is a landed mutation.
4. **Never try to prove T012 load-bearing by reverting it.** Measured: it cannot
   go red, because the value falls back to a default that leaves the assertion
   true. Its defect is a false COMMENT. Attempting the proof fabricates evidence.

And one scope rule: **the window size gets no ceiling and no notice.** FR-008 is
a ruled non-change. A task that adds one has broken the spec (SC-008).

---

## Phase 1: Setup — capture what cannot be recaptured

- [X] T001 Run the house suite from the repository ROOT and save the verbatim output to `.delivery-kit/runs/017-guard-config-bounds/baseline-suite.txt`: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`. Expect `1..167`, 167 ok, 0 not ok, exit 0. **If the count is not 167, stop and report** — the plan's arithmetic depends on it.
- [X] T002 Record the baseline commit id to `.delivery-kit/runs/017-guard-config-bounds/baseline-sha.txt` via `git rev-parse HEAD`. The differential consumes this as an **id**, never a branch name: this repository rebase-merges, so a branch name compares an empty range once the work lands.

## Phase 2: Foundational

**None.** This feature adds no shared infrastructure, no module and no new file
under `handoff/`. Phase 1's baseline is the only prerequisite the user stories
share. Recorded explicitly so its absence reads as a decision rather than an
omission.

---

## Phase 3: User Story 1 — a percentage that can never arrive in time (P1) 🎯 MVP

**Goal**: a warning threshold of exactly 100 is refused, so the guard can no
longer be switched off by a value that looks valid.

**Independent test**: set the threshold to 100, run a session past the point the
default would have warned, and observe a warning arrive. Delivers the whole
feature's value on its own.

### The change-prover, written and run RED first

- [X] T003 [US1] In `handoff/tests/context-guard.bats`, immediately after the existing test at `:459`, add a test named for refusing a threshold of exactly 100. Shape, verified 2026-09-04: `write_config` with `{"windowTokens":1000000,"thresholdPct":100}` and **no** `thresholdTokens`; `transcript_with` five readings of 500000 (50% of the window). Assert `.decision == "block"` and `.reason | test("threshold 45%")`. Add a comment stating that 100 is the first refused value and that this test moves the guard from silent to speaking.
- [X] T004 [US1] Run ONLY that file: `bash "$HOME/bats/bin/bats" --print-output-on-failure handoff/tests/context-guard.bats`. **T003 MUST FAIL**, and the failure must be that the guard emitted nothing. Save the output to `.delivery-kit/runs/017-guard-config-bounds/t003-red.txt`. **This is a gate: if T003 passes here, the test is not testing the defect — stop and re-derive it.**

### The regression pin

- [X] T005 [US1] In `handoff/tests/context-guard.bats`, beside T003, add a test asserting a threshold of 99 is accepted. Shape, verified 2026-09-04: `{"windowTokens":1000000,"thresholdPct":99}`, five readings of 995000 (99% by integer division). Assert `.reason | test("threshold 99%")` — naming the exact value, so a refusal (which would say `threshold 45%`) fails the assertion rather than merely changing the wording. Comment it as a regression pin that passes on both sides of this change, and say that its control is a mutation.

### The edit

- [X] T006 [US1] `handoff/hooks/context-guard.sh:44` — change `is_positive_int "$1" && [ "$1" -le 100 ]` to `is_positive_int "$1" && [ "$1" -lt 100 ]` inside `is_valid_threshold`. **One character. Do not touch `:236` or `:264`** — the window is a ruled non-change. Do not add a bound at any call site: the rule has one implementation and three callers by design (Principle IV).
- [X] T007 [US1] Re-run `handoff/tests/context-guard.bats`. T003 must now PASS and T005 must still pass. Save to `.delivery-kit/runs/017-guard-config-bounds/t003-green.txt`. Report the red-to-green transition with both file paths.

### Proving the pin can fail (Principle III)

- [X] T008 [US1] Prove T005 can go red, since the feature itself cannot show it. (a) Back up `handoff/hooks/context-guard.sh` with `cp`. (b) Mutate `:44` to `-lt 99`. (c) **Print the mutated line and confirm it changed** — a mutation that did not land is a silent false green. (d) Run the file; T005 must FAIL. (e) Restore from the backup and confirm with `cmp` that the file is byte-identical. (f) Record all of it in `.delivery-kit/runs/017-guard-config-bounds/t005-mutation.txt`.

### The three sites that describe or depend on the boundary

- [X] T009 [US1] `handoff/hooks/context-guard.sh:37-42` — the comment above `is_valid_threshold` says a threshold "over 100" is the hazard. Reword to "100 or above", restating the canonical sentence from `contracts/threshold-validation.md`. `handoff/hooks/` is a STRICT-vocabulary surface: carry the existing reasoning, do not compress it.
- [X] T010 [US1] `handoff/hooks/context-guard.sh:620-623` — the invariant comment states that the threshold gate cannot block an over-window reading "because `is_valid_threshold` caps `THRESHOLD_PCT` at 100". The cap is now 99, so a percentage of at least 100 **strictly exceeds** every admissible threshold. Update the number **and** say the invariant now holds by a wider margin. Do not change the code beneath it. (Same file as T009 — these two are serialised, never parallel.)
- [X] T011 [P] [US1] `handoff/tests/context-guard.bats:487` — change `"thresholdPct":100` to `"thresholdPct":99` in the test "the absolute tripwire fires with the relative one unreachable".
- [X] T012 [US1] `handoff/tests/context-guard.bats:485-486` — correct that test's comment, which says "threshold 100% is not reachable here". **This is the actual defect in that test**: after T006 the assertion stays true either way, so the comment is the only thing that was wrong, and a stale comment on a green test is exactly the silence this feature exists to close. State the new value and why it is unreachable for this test's data (99% versus an observed 40%). **Do not attempt to prove this load-bearing by reverting T011 — measured, it cannot go red.**

**Checkpoint**: US1 is complete and independently shippable. The guard now refuses a threshold that could only ever have silenced it.

---

## Phase 4: User Story 2 — the window size (P2) — a RULED NON-CHANGE

**Goal**: ship the decision, not code. Nothing in the hook changes.

**Independent test**: the window behaves identically before and after, at every layer.

- [X] T013 [US2] In `specs/015-guard-jq-spawn-two/tasks.md`, at task **T045** (`:220-226`), record the ruling beside the deferral that raised it: decided 2026-09-04, **no change**; a ceiling or notice needs a number that refuses absurd values while admitting the plausible-but-wrong ones that actually cause the failure (a limit rejecting 100000000 still admits 2000000, which disarms a 200000 window just as completely); and it would reverse a position already taken twice. Mark the threshold half of T045 as closed by this feature. Point at `specs/017-guard-config-bounds/spec.md` so a reader reaches the reasoning without leaving the repository (SC-007).
- [X] T014 [P] [US2] Record the struck candidate so nobody re-proposes it: the seed offered "make the existing misconfiguration report fire independently". It cannot detect this case — that report is gated on observed context **exceeding** the window (`handoff/hooks/context-guard.sh:639`), which a too-large window makes permanently false. Measured, not reasoned. Put this beside the T045 ruling.
- [X] T015 [US2] Prove the non-change: `git diff` the baseline commit for `handoff/hooks/context-guard.sh` and confirm **no hunk touches `:236` or `:264`** or any window handling. Record the result. An accidental bound here is a scope breach (SC-008), not a bonus.

**Checkpoint**: the decision is recorded where the next person to notice the defect will find it.

---

## Phase 5: User Story 3 — the written rule and the enforced rule agree (P3)

**Goal**: no surviving statement of the superseded rule, and a check that stops it coming back.

**Independent test**: read every statement of the rule and compare each to enforced behaviour.

- [X] T016 [US3] Sweep by **derivation, not against a list of two files** — a hand list is how the wording drifted originally (Principle V). Search the shipped surface for statements of the old rule (`grep -rn "above 100" handoff/ README.md` and near-variants). Record every hit with its path and line **before** editing any of them.
- [X] T017 [US3] `handoff/docs/configuration.md:46-53` — reword the rule to "100 or above", restating the canonical sentence from `contracts/threshold-validation.md`. STRICT surface. Fix any further hits T016 found; if T016 found sites beyond this one, say so explicitly, because the plan predicted one.
- [X] T018 [US3] Add a prose pin in `handoff/tests/context-guard.bats`, so the wording cannot drift back. **Shape matters**: assert the operative wording of the contract's sentence is PRESENT on the documentation surface and the superseded wording is ABSENT, derived over the surface (walk `handoff/docs/` and the hook) rather than over a hand-written list of paths — otherwise the pin becomes the stale enumeration Principle V forbids. **Why this file and not `pipeline/tests/prose.bats`**: checked 2026-09-04 — that registry pins the pipeline orchestrator's prose only, and there is no handoff prose registry. `handoff/tests/` is a registered shipped surface and travels with the plugin, so the pin lives beside what it protects. Guard the grep with `|| true` and assert on the captured value: bats runs under `errexit`, so a grep matching nothing aborts the assignment and the check never executes — that exact defect is already recorded in this file around `:775`.
- [X] T019 [US3] Show the T018 pin can go red (Principle III): temporarily reintroduce the superseded wording in `handoff/docs/configuration.md` (after `cp` backup), **print the mutated line to confirm the mutation landed**, run `handoff/tests/context-guard.bats`, confirm the pin FAILS, restore from the backup, and `cmp` to prove the restore is byte-identical. Record it in `.delivery-kit/runs/017-guard-config-bounds/t018-control.txt`.

**Checkpoint**: FR-005 now rests on a check that exists.

---

## Phase 6: Polish & cross-cutting

- [X] T020 [P] `scripts/context-guard/differential.sh` — add three configuration shapes: `thresholdPct` 99, 100 and 101. Assert **100 DIFFERS**; assert 99 and 101 are **the same**. The expectation is the fifth argument and defaults to `same`. The pair of same-assertions is what shows the change is bounded rather than merely present.
- [X] T021 Run the differential with the baseline **commit id** from T002. Read `scripts/context-guard/README.md` first: `HOME`, `TMPDIR`, `TEMP` and `TMP` must ALL be isolated per side per shape, or the old hook's fire-once flag silences the new one and the harness reports false differences on a correct hook. Run the `NEWHOOK` positive control before believing any zero. Expect **0 unexpected** and **exactly one shape asserted to differ**. **A run reporting no differences at all is a FAILED run, not a clean one.**
- [X] T022 [P] `scripts/context-guard/README.md` — add this run to its dated table of runs, as a record of one run rather than a claim about the current file (Principle II).
- [X] T023 [P] `handoff/CHANGELOG.md` — a `### Fixed` entry under the **existing** `## [Unreleased]`. Name the boundary and what a threshold of 100 used to do. **handoff ONLY**: this feature touches no file under `pipeline/`, and BOTH plugins have an open `## [Unreleased]`, so filing under the wrong one is easy and silent. Note that this changes what an existing configuration does, so the release phase must decide the stamp deliberately.
- [X] T024 [P] Run `shellcheck --norc -f gcc` over the changed shell files, the way the automation runs it. The automation's analyser is **older** than a typical local one and reports **more**, so a local pass does not predict it.
- [X] T025 Run the full house suite from the repository ROOT. Compare against T001. **The count MUST have moved** by the number of tests added — an unmoved count is a finding, not a pass. Report `1..N`, ok, not ok, non-TAP and exit code.
- [X] T026 Walk `quickstart.md`'s "What done means" table and confirm every row, naming the evidence file for each. Any row that cannot be evidenced is reported, never marked done.

---

## Dependencies

```
T001, T002  (baseline — blocks everything)
    │
    ├─► T003 ─► T004 (RED gate) ─► T006 ─► T007 ─► T008
    │              ▲                 │
    │           T005 ────────────────┘
    │
    │   T006 ─► T009 ─► T010        (same file, serialised)
    │   T006 ─► T011 ─► T012        (same file, serialised)
    │
    ├─► T013 ─► T014, T015          (US2, independent of US1's code)
    │
    ├─► T016 ─► T017 ─► T018 ─► T019 (US3)
    │
    └─► T020 ─► T021 ─► T022
        T023, T024 (any time after US1)
        T025, T026 (last)
```

**The one hard gate**: T004 must be observed RED before T006 exists. Everything
else is ordering; that one is evidence.

## Parallel opportunities

- **T009/T010 versus T011/T012**: different files (hook versus tests). The pairs run concurrently; **within** each pair the tasks are serialised because they edit one file.
- **US2 (T013–T015) is independent of US1's code** and can run alongside it — it touches only `specs/`.
- **T020, T022, T023, T024**: four different files, all parallelizable once US1 has landed.
- Two agents never edit the same file in one batch. `handoff/hooks/context-guard.sh` is touched by T006, T009 and T010; `handoff/tests/context-guard.bats` by T003, T005, T011 and T012.

## Implementation strategy

**MVP is User Story 1 alone.** T001–T012 deliver the entire defect fix and are
independently shippable. US2 adds no code. US3 makes the documentation honest and
adds the check that keeps it honest.

If the run must stop early, stop at a checkpoint, never mid-story — and never
between T003 and T004, which would leave a failing test with no record of why it
was expected to fail.

---

## Phase 7: appended by the converge assessment (H.5), 2026-09-04

Two items the plan could not have contained, because both were discovered by
running the work rather than by reading it.

- [X] T027 **DONE 2026-09-05.** Convert this feature's own differential assertion to `diff@`, in a
  follow-up commit on this branch.** `scripts/context-guard/differential.sh`
  asserts `config: thresholdPct exactly 100` with a plain `diff`, because at the
  time it was written the commit introducing that divergence did not exist — it
  was the commit being written. The moment this lands, that assertion inherits
  exactly the staleness the `diff@` form was added this session to cure: the next
  feature to use a baseline containing it will see "expected a DIFFERENCE and
  found none" on a correct tree. Change it to `diff@<commit>` once that commit exists — and TAKE THE ID FROM
  `origin/main` AFTER THE BRANCH LANDS, never from this branch. This repository
  rebase-merges, so the on-branch id is not the id that lands: measured
  2026-09-04, `9148066` and `f495823` have identical trees and only the second
  is an ancestor of `main`. An anchor taken from the branch would be an orphan
  that resolves (it lives in the reflog until gc) and never matches — which is
  precisely the defect T028 cured, re-introduced by its own follow-up. The
  harness now refuses such an anchor by name rather than degrading quietly. A NOTE comment sits above the call
  so the requirement is visible at the site, but a comment is not a check —
  **this is real outstanding work, not a nicety.**

- [X] T028 **Harness repair, unplanned and owner-approved.** The three assertions
  added by `f495823` reported UNEXPECTED against any baseline containing that
  commit — three reds on a correct tree, which would have recurred for every
  future feature. Cause: `diff` says *these two disagree* without saying *since
  when*. Fixed by letting an assertion name its introducing commit
  (`diff@<commit>`); when the baseline already contains it the expectation
  becomes `same`. Controlled in three directions and recorded in
  `scripts/context-guard/README.md`. Approved at the H gate before implementing.

  **Closed 2026-09-05, and the prediction held exactly.** The anchor is
  `diff@5ff33c6`, taken from `origin/main` after the merge. The branch's own
  ids — `2b24438` and `987c9c5` — are **not** ancestors of `main`; the
  rebase-merge replaced them with `5ff33c6` and `1494f5b`. An anchor copied off
  the branch would have named a commit reachable from nothing, and the guard
  added in T028 would have refused it by name rather than letting it degrade.

  Verified on both sides of its own merge:

  | Baseline | Result |
  |---|---|
  | `2658b62`, before the divergence | `DIFFERS, as asserted` — 1 asserted to differ, 3 auto-relaxed, exit 0 |
  | `5ff33c6`, at the divergence | `agrees; its asserted divergence (5ff33c6) is already in the baseline` — 0 asserted, 4 auto-relaxed, exit 0 |

  No plain `diff` assertion remains in the harness; all four are anchored.
