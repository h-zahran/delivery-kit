---

description: "Task list for 011-pin-safety-prose"
---

# Tasks: Pin the orchestrator's safety prose

**Input**: Design documents from `/specs/011-pin-safety-prose/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/pin-contract.md, quickstart.md

**Tests**: This feature's deliverable IS tests. The "implementation" tasks
below write them; the verification tasks prove each one can fail for the right
reason. Both are mandatory here, not optional.

**Organization**: Grouped by user story. Note the parallelism finding before
starting — it changes how these are executed.

---

## Parallelism: none, and why

Every implementation task writes `pipeline/tests/prose.bats`. Every
verification task edits `pipeline/skills/pipeline/SKILL.md`. Two agents never
edit the same file in one batch, so with two single files there is nothing to
fan out. Concurrent mutation is worse than merely blocked: two agents
inverting different clauses at once each see the other's red and neither can
tell which mutation caused it.

**No task below carries a `[P]` marker, and that is a measured conclusion, not
an omission.** Run them in order.

---

## Phase 1: Setup

- [X] T001 Verify the working tree is clean and on branch `011-pin-safety-prose`, and record the current commit id of `pipeline/skills/pipeline/SKILL.md` for the identity proof in T035
- [X] T002 Copy `pipeline/skills/pipeline/SKILL.md` to the scratch directory as `SKILL.md.orig`, then confirm with `cmp` that the copy is byte-identical; this backup is the ONLY restore path, because `git checkout --`, `git reset --hard`, `git clean` and `git stash` are all forbidden by the orchestrator's never-bend table
- [X] T003 Run `pipeline/tests/prose.bats` alone and record its plan line and pass count, so the five new tests can be counted against a measured starting point rather than against the seed's number

---

## Phase 2: Foundational (blocks every user story)

**Purpose**: Two throwaway-and-shipped tools nothing else can start without —
the slice helper every pin calls, and the mutation harness every verification
task runs through.

- [X] T004 Add a `prose_slice` helper function to `pipeline/tests/prose.bats`, below the existing `setup()` and above the first `@test`, taking an open pattern, a close pattern and a form (`raw` or `flat`), and returning the sliced region with carriage returns stripped
- [X] T005 Give `prose_slice` in `pipeline/tests/prose.bats` the three validation rules from contracts/pin-contract.md C2: the slice's first line matches the open pattern, its last line matches the close pattern, and it holds no heading-shaped line (`^**` or `^#`) other than the closing one — each failing with a message naming the region and which boundary was not found
- [X] T006 Prove `prose_slice` can fail, as a THROWAWAY probe rather than a committed test: from a scratch script, call it with a close pattern matching nothing and confirm it reports the missing closing boundary instead of silently returning the rest of the file. A helper that cannot say no propagates one silent failure to all five callers. Leave nothing behind in `pipeline/tests/prose.bats` — the committed proof of this behaviour is T039, which reaches it through a real boundary rename

### The mutation harness

Twenty-two mutations follow. Written out longhand, each is six steps that must
all happen in order, and the one that gets dropped when a step is copied
twenty-two times is the `echo`. That is the step whose absence is invisible: a
`sed` that matches nothing exits 0 and changes nothing, the suite then passes
for the honest reason, and the run records a mutation that never happened. A
harness is written once and cannot be copied wrongly.

- [X] T006a Write a throwaway mutation harness at `$SCRATCH/mutate.sh` (NOT in the repository) taking a literal `from` string and a literal `to` string: it applies the replacement to `pipeline/skills/pipeline/SKILL.md` with python rather than `sed` — the target strings contain `|`, `"`, backticks and em-dashes together, and escaping all four into a `sed` expression is how a mutation quietly becomes a no-op
- [X] T006b Make `$SCRATCH/mutate.sh` REFUSE to continue when the replacement changed nothing, and print the changed line when it did. Both halves are load-bearing: without the refusal the run records a mutation that never landed, and without the print there is no evidence it landed beyond the harness's own say-so (SC-003)
- [X] T006c Have `$SCRATCH/mutate.sh` run `pipeline/tests/prose.bats` with output redirected to a file and the exit status captured on the NEXT line — never through a pipe, which hands the block the status of the last command in it and can never go red — then restore `pipeline/skills/pipeline/SKILL.md` from `SKILL.md.orig` and prove the restore with `cmp` before returning
- [X] T006d Prove `$SCRATCH/mutate.sh` can itself fail: hand it a `from` string that appears nowhere in `pipeline/skills/pipeline/SKILL.md` and confirm it refuses rather than reporting a passing mutation. A harness that cannot say no propagates one silent false green to all twenty-two mutations

---

## Phase 3: User Story 1 — a dangerous deletion goes red (P1)

**Goal**: Each of the five passages, when inverted, turns the suite red with a
message naming the passage.

**Independent test**: Invert any one anchor in
`pipeline/skills/pipeline/SKILL.md`, run `pipeline/tests/prose.bats`, see a
red naming that passage; restore and see green.

### The five pins

- [X] T007 [US1] Add the seed-form pin to `pipeline/tests/prose.bats`, slicing `**Seed forms.**` → `## The twenty phases` in flat form, anchoring the `gh`-and-remote precondition and the never-fall-through rule (FR-001)
- [X] T008 [US1] Add the roll-nothing-back pin to `pipeline/tests/prose.bats`, slicing `## When a phase fails` → `## Resume` in flat form, anchoring `ROLL NOTHING BACK` with its reason clause, the `current_phase` rule and the lock release (FR-002); note in a comment that the last two are a deliberate superset of FR-002, per research D2, so review reads them as intent
- [X] T009 [US1] Add the J carry-duty pin to `pipeline/tests/prose.bats`, slicing `**J — analyzer and full suite.**` → `**K — commit.` in flat form, anchoring the carry duty, the reason it exists, the new-failures-are-a-new-stop rule, the no-pull-request discharge and the redaction rule (FR-003)
- [X] T010 [US1] Add the N degraded pin to `pipeline/tests/prose.bats`, slicing `**N — re-verify and update the PR.**` → `**N.5 — runtime check.**` in flat form, anchoring `DEGRADED, NEVER SKIPPED`, the closing sentence and the do-not-re-own rule (FR-004)
- [X] T011 [US1] Add the red-flag pin to `pipeline/tests/prose.bats`, slicing `## Red flags` → `## When a phase fails` in raw form, matching each of the seven rows as a WHOLE LINE (`grep -qxF`, never `grep -qF` — see contracts C4) and naming the missing row on failure (FR-005)
- [X] T012 [US1] Add the reverse completeness check to the red-flag pin in `pipeline/tests/prose.bats`: every data row in the table must appear in an eight-row reference list — the seven pinned here plus `"Fix everything" is implied…`, which the existing test pins — failing with the text of the unlisted row (FR-005a)

### The green baseline — before any mutation

- [X] T012a [US1] Run `pipeline/tests/prose.bats` on the UNMUTATED
  `pipeline/skills/pipeline/SKILL.md` and confirm all sixteen tests pass — the
  eleven that were there plus the five just written. Record the plan line.

  This task is not bookkeeping. Every one of the twenty-two mutations below
  succeeds by observing a red, and a pin that is red on the clean file is red
  under every mutation too. Without this baseline the entire verification pass
  can be completed, reported as proven, and be measuring nothing but a broken
  test. It is the same fault this feature exists to close, pointed at the
  feature itself: a check that cannot pass proves as little as one that cannot
  fail.

### Verification — thirteen clause inversions

Each one runs through `$SCRATCH/mutate.sh` from T006a–T006d, which applies the
inversion, refuses if nothing changed, prints the changed line, runs the
suite, restores from `SKILL.md.orig` and proves the restore with `cmp`.
Inverting means rewriting the clause to assert the OPPOSITE — a deletion is
the easy case and does not count (SC-002).

- [X] T013 [US1] Invert the seed-form `gh`-and-remote precondition in `pipeline/skills/pipeline/SKILL.md`; confirm T007 goes red; restore
- [X] T014 [US1] Invert the seed-form never-fall-through rule in `pipeline/skills/pipeline/SKILL.md` so it permits the fall-through; confirm T007 goes red; restore
- [X] T015 [US1] Invert `ROLL NOTHING BACK` in `pipeline/skills/pipeline/SKILL.md` to instruct a rollback; confirm T008 goes red; restore
- [X] T016 [US1] Invert the `current_phase` rule in `pipeline/skills/pipeline/SKILL.md` so it advances past the failed phase; confirm T008 goes red; restore
- [X] T017 [US1] Invert the lock-release rule in `pipeline/skills/pipeline/SKILL.md` so a failed run holds the lock; confirm T008 goes red; restore
- [X] T018 [US1] Invert J's carry duty in `pipeline/skills/pipeline/SKILL.md` so surviving failures need not be carried; confirm T009 goes red; restore
- [X] T019 [US1] Invert J's reason clause in `pipeline/skills/pipeline/SKILL.md`; confirm T009 goes red; restore
- [X] T020 [US1] Invert J's new-failures-are-a-new-stop rule in `pipeline/skills/pipeline/SKILL.md` so an earlier answer covers later failures; confirm T009 goes red; restore
- [X] T021 [US1] Invert J's no-pull-request discharge in `pipeline/skills/pipeline/SKILL.md`; confirm T009 goes red; restore
- [X] T022 [US1] Invert J's redaction rule in `pipeline/skills/pipeline/SKILL.md` so the value is recorded rather than its location; confirm T009 goes red; restore
- [X] T023 [US1] Invert `DEGRADED, NEVER SKIPPED` in `pipeline/skills/pipeline/SKILL.md` so N may be skipped; confirm T010 goes red; restore
- [X] T024 [US1] Invert N's closing sentence in `pipeline/skills/pipeline/SKILL.md`; confirm T010 goes red; restore
- [X] T025 [US1] Invert N's do-not-re-own rule in `pipeline/skills/pipeline/SKILL.md` so N re-enters the fix loop; confirm T010 goes red; restore

### Verification — seven row inversions

- [X] T026 [US1] Invert the reality column of red-flag row 2 (`"The cap is close…"`) in `pipeline/skills/pipeline/SKILL.md` to endorse the rationalisation; confirm T011 goes red naming that row; restore
- [X] T027 [US1] Invert red-flag row 3 (`"The baseline probably covers this failure"`) in `pipeline/skills/pipeline/SKILL.md`; confirm T011 goes red naming that row; restore
- [X] T028 [US1] Invert red-flag row 4 (`"The suite is slow…"`) in `pipeline/skills/pipeline/SKILL.md`; confirm T011 goes red naming that row; restore
- [X] T029 [US1] Invert red-flag row 5 (`"The reviewer would accept this"`) in `pipeline/skills/pipeline/SKILL.md`; confirm T011 goes red naming that row; restore
- [X] T030 [US1] Invert red-flag row 6 (`"It works on the happy path, ship it"`) in `pipeline/skills/pipeline/SKILL.md`; confirm T011 goes red naming that row; restore
- [X] T031 [US1] Invert red-flag row 7 (`"The gate will obviously be answered yes"`) in `pipeline/skills/pipeline/SKILL.md`; confirm T011 goes red naming that row; restore
- [X] T032 [US1] Invert red-flag row 8 (`"Re-running this phase might duplicate work"`) in `pipeline/skills/pipeline/SKILL.md`; confirm T011 goes red naming that row; restore

### Verification — the appending mutant

- [X] T033 [US1] Leave red-flag row 7 intact in `pipeline/skills/pipeline/SKILL.md` and APPEND a cell after its final pipe, per quickstart.md section 4; confirm T011 goes red; restore. This is the only mutant that distinguishes whole-line matching from substring matching, and none of T026–T032 can expose it because every one of them is a rewrite (SC-002b)
- [X] T034 [US1] Add the completeness mutant per quickstart.md section 7: insert a ninth red-flag row in `pipeline/skills/pipeline/SKILL.md` without adding it to the pin list; confirm T012 goes red naming the unpinned row; restore

### Restore proof

- [X] T035 [US1] Prove `pipeline/skills/pipeline/SKILL.md` is byte-identical to `SKILL.md.orig` with `cmp`, and that `git status --short` does not list it (FR-011, SC-006)

---

## Phase 4: User Story 2 — an innocent reflow stays green (P2)

**Goal**: A rewrap that changes no words leaves all five pins passing.

**Independent test**: Rewrap the N block to a different width, run
`pipeline/tests/prose.bats`, see all five new tests green.

- [X] T036 [US2] Rewrap the N block in `pipeline/skills/pipeline/SKILL.md` to a different line width without changing a word, per quickstart.md section 6; confirm all five new pins stay GREEN; restore and prove with `cmp` (SC-007)
- [X] T037 [US2] Rewrap the J block in `pipeline/skills/pipeline/SKILL.md` the same way, since J carries the most anchors and is the likeliest to have one straddling a line break; confirm all five pins stay GREEN; restore and prove with `cmp`

---

## Phase 5: User Story 3 — a relocated passage does not satisfy its pin (P3)

**Goal**: Text moved out of its governing section fails the pin, even though
the words are still in the file.

**Independent test**: Move a pinned passage to the end of the orchestrator,
run `pipeline/tests/prose.bats`, see the pin fail.

- [X] T038 [US3] Move the roll-nothing-back paragraph in `pipeline/skills/pipeline/SKILL.md` out of `## When a phase fails` to the end of the document; confirm T008 goes red even though the words are still present; restore and prove with `cmp`
- [X] T039 [US3] Rename the closing boundary `## Resume` in `pipeline/skills/pipeline/SKILL.md`, per quickstart.md section 5; confirm T008 fails naming the missing BOUNDARY rather than naming the prose — the silent-widening case contracts C2 exists to catch; restore and prove with `cmp`

---

## Phase 6: Polish and verdict

- [X] T040 Confirm every string pinned by the eleven pre-existing tests in `pipeline/tests/prose.bats` is still present in `pipeline/skills/pipeline/SKILL.md`, by running those eleven tests and seeing them pass (SC-005)
- [X] T041 Read `pipeline/tests/prose.bats` and confirm no line above the new helper was altered — the eleven existing tests are byte-identical (FR-010)
- [X] T042 Confirm `git status --short` lists only `pipeline/tests/prose.bats` and the `specs/011-pin-safety-prose/` artefacts, and no other shipped file (FR-012)
- [X] T043 Confirm no CHANGELOG file was touched (FR-013)
- [X] T044 Run the full house suite from the repository root — `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests` — redirecting to a file and capturing the exit status on the NEXT line, because a pipe into `tail` hands the block tail's status and can never go red. The target is the house baseline recorded at F.5 plus exactly five, which is expected to read `1..159`; if F.5 measures a baseline other than 154 the expectation moves with it and 159 was the wrong number, not the suite. Confirm the derived total, 0 not ok, 0 non-TAP output, status 0 (SC-001)

---

## Dependencies

```
T001–T003  Setup
   ↓
T004–T006  prose_slice helper          ← blocks everything
   ↓
T007–T012  the five pins written        ← must precede any verification
   ↓
T013–T034  twenty-one mutations         ← each restores before the next starts
   ↓
T035       restore proof
   ↓
T036–T037  reflow (US2)   ─┐
T038–T039  relocation (US3) ┘  ← both need the pins from T007–T012
   ↓
T040–T044  verdict
```

US2 and US3 depend on Phase 3's pins existing, but not on Phase 3's mutations
having run. They are ordered after it because both mutate the same file and
serialising is the only safe order, not because of a data dependency.

---

## Implementation strategy

**MVP is Phase 2 plus Phase 3.** The helper and the five pins, with all
twenty-one mutations proven, deliver the whole point of the feature: a
dangerous edit goes red. Phases 4 and 5 prove the pins are the RIGHT shape —
tolerant of reflow, intolerant of relocation — which is quality, not
capability.

**Do not skip Phase 4.** A pin that reddens on a rewrap is worse than no pin
in one specific way: it teaches its readers that reds from this file are
noise. That is the failure mode the existing suite documents about itself, and
the reason the seed asked for clause anchors in the first place.

**The restore after every mutation is not optional and not deferrable.**
Batching mutations to save restores means running the suite against a document
carrying several inversions at once, where one pin's red masks another's
green. Each mutation stands alone.
