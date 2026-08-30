---

description: "Task list for 012-shellcheck-version-gate"
---

# Tasks: shellcheck, and one version gate instead of two

**Input**: Design documents from `specs/012-shellcheck-version-gate/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: One new suite test is required by the specification (FR-013) and
appears as its own task. No other suite test may be added — FR-020 fixes
the suite delta at exactly one. The other proofs this feature needs are
demonstrations run against the working tree and recorded in the run's
record, never encoded as suite tests.

---

## File-conflict map (read before parallelising anything)

Three of the four user-visible changes edit the same workflow file. Two
edit the same suite file. Tasks touching one file are never run in the
same batch.

| File | Touched by |
|---|---|
| `.github/workflows/ci.yml` | T005, T009, T012, T013 — strictly sequential |
| `tests/portability.bats` | T007, T008 — strictly sequential |
| `tests/helper.bash` | T004 only |
| `scripts/check-versions.sh` | T002 only |

---

## Phase 1: Setup

- [X] T001 Confirm the repository's line-ending policy already normalises shell files, by reading `.gitattributes` and running `git check-attr -a scripts/check-versions.sh`; expect `eol: lf` with no edit to `.gitattributes`. A carriage return in the new script would fail on one matrix platform with a message naming nothing useful.

---

## Phase 2: Foundational — blocking prerequisites

The shared script is written first because two later phases consume it:
User Story 2 calls it from both gates, and User Story 1's scope proof
(contract clause S8) requires it to exist so the discovery rule can be
observed picking it up.

- [X] T002 Write `scripts/check-versions.sh` carrying every check named in `specs/012-shellcheck-version-gate/data-model.md` and contract clauses V3, V4, V5, V6 and V7: the plugin-directory walk, the six per-plugin checks, the reverse walk over marketplace entries with its carriage-return strip, the count reconciliation, the non-empty guards, and the working-directory refusal. Diagnostics keep the substance of the two copies being replaced, including the two that distinguish an absent value from a disagreeing one.

- [X] T003 Verify `scripts/check-versions.sh` standalone, before any caller is changed: it passes on the clean tree; it refuses with a named message when run from a directory holding no marketplace manifest; and it rejects each checked value removed in turn from a scratch copy, naming that value. Record the output in the run's record. Steps 5, 6 and 7 of `specs/012-shellcheck-version-gate/quickstart.md` are the executable form of this task.

---

## Phase 3: User Story 1 — shell code is statically analysed before it merges (Priority: P1)

**Goal**: Every first-party shell file is read by a static analyser on
every pull request, and any finding fails the run.

**Independent test**: Plant one real defect in a file within scope; the
checks reject the tree. Remove it; the checks accept the tree.

- [X] T004 [P] [US1] Suppress the single existing finding at its own line in `tests/helper.bash`, with a written reason naming the test runner as the variable's real reader. Do not export the variable and do not otherwise change the source: contract clause S6 and FR-006a. This is the only file this task touches, so it may run beside T002.

- [X] T005 [US1] Add the static analysis job to `.github/workflows/ci.yml`: one job, one operating system, sharing the workflow's existing triggers. It discovers its file set from tracked files matching the shell extensions with the vendored scaffold directory excluded by pathspec; carries the set to the analyser in a form that survives a path containing a space; fails with a named message when the set is empty; obtains the analyser the way the file's existing step obtains its other external tool and prints its version every run; and carries no job-level suppression list. Write the boundary's reasons into the job as required by contract clause S4 — the vendored exclusion, and the suite-file exclusion with its measured finding count. Check every new word against the strict published-surface's banned set before writing it, per FR-021a; refer to the vendored tree by its path, never by its tool's joined name.

- [X] T006 [US1] Demonstrate the analysis in both directions against the working tree, per contract clause S5 and step 4 of `specs/012-shellcheck-version-gate/quickstart.md`: plant one real defect, echo the planted line to prove the mutation landed, run the discovery-and-analyse command, capture the red output, revert, confirm an empty diff, and capture the green output. Record both outputs in the run's record. Do not encode this as a suite test — FR-020.

- [X] T006a [US1] Demonstrate the empty-set guard, per FR-003a, SC-010 and contract clause S3. Extract the job's discovery-and-guard commands from `.github/workflows/ci.yml`, run them with the exclusion widened until the discovery yields nothing, and observe the job's own named failure and non-zero exit — not merely that the discovery returned zero, which proves nothing about the guard. Record the message. Do not encode this as a suite test.

---

## Phase 4: User Story 2 — one version-agreement gate, not a hand-maintained twin (Priority: P1)

**Goal**: The version-agreement logic exists once, and both gates call
it.

**Independent test**: Remove a version value from any one of its three
recorded places; both gates go red and name the same defect.

- [X] T007 [US2] Replace the body of the existing version-agreement test in `tests/portability.bats` with a call to `scripts/check-versions.sh`, keeping the test's name exactly as it is (contract clause V9) so the suite's own record of what it covers stays continuous. The test changes the repository root to the suite's resolved root before calling, which is the working directory the script requires.

- [X] T008 [US2] Add ONE new test to `tests/portability.bats` asserting that both callers name the one shared script (FR-013, contract clause V1). Write it so it cannot satisfy its own assertion by matching its own text (clause V2): locate each caller's invocation by the shape of the line that performs it, strip trailing comments before inspecting, and exclude the test's own body from what it searches. The existing test that polices the runner invocation line in the same file is the working template.

- [X] T009 [US2] Replace the inline body of the `version` job's first step in `.github/workflows/ci.yml` with a call to `scripts/check-versions.sh`, and replace the comment describing the two gates as a hand-maintained pair with one describing the new arrangement. That comment is pinned by nothing — verified at research item R9 before this task was written. Leave the job's release-tag step byte-for-byte unchanged (contract clause V8).

- [X] T010 [US2] Prove the new parity test can fail, per contract clause V2 and step 8 of `specs/012-shellcheck-version-gate/quickstart.md`: point one caller at a different path, echo the mutated line, run the parity test alone and capture its non-zero exit, restore, and confirm an empty diff. Record the output. A test never observed failing has not been shown to test anything.

- [X] T011 [US2] Prove that removing a version reddens BOTH gates, per FR-014 and step 7 of `specs/012-shellcheck-version-gate/quickstart.md`: delete a version key from one manifest, probe that the key is actually gone before trusting the reds, run the script and the suite gate, restore, and confirm an empty diff. Record the output.

---

## Phase 5: User Story 3 — the third-party test runner is pinned and cached (Priority: P2)

**Goal**: The runner is fetched at an immutable revision and reused
between runs.

**Independent test**: Read the workflow — an immutable revision, the
release name in a comment, a cache keyed on that revision.

- [X] T012 [US3] Change the runner installation step in `.github/workflows/ci.yml` to fetch the pinned COMMIT rather than the mutable release reference, using the initialise-fetch-checkout shape from research item R2. The value is the commit the release reference points AT, not the release object's own identifier — research item R1 records both identifiers and the measured reason the commit is preferred. Keep the release name in a comment beside the pin (FR-016).

- [X] T013 [US3] Add a cache step to `.github/workflows/ci.yml` ahead of the installation step, keyed on the operating system and the pinned revision so that changing the pin misses the cache (FR-017), with the installation step made conditional on a cache miss. Add the one-line note research item R3 requires, stating why the platform's own actions stay on a moving reference while the third-party runner is pinned.

- [X] T014 [US3] Confirm the runner invocation line in `.github/workflows/ci.yml` is unchanged, by running the existing suite test that parses that line for its flags and path operands. The edits above sit in the steps preceding it and must not disturb it.

---

## Phase 6: Polish and cross-cutting verification

- [X] T015 Run the static analysis over the discovered set, now including `scripts/check-versions.sh`, and confirm it is clean; this is contract clause S8's proof that the discovery rule covers code added by this feature.

- [X] T016 Run the full house suite from the repository root and confirm the count is exactly one higher than this run's recorded baseline, with zero failures and zero non-conforming output lines (FR-020, SC-004).

- [X] T017 Scan every file this feature added or edited for the repository's banned absolute-path shapes, one fixed string per shape with a positive control fired before any green is believed; and scan the workflow file against the strict published-surface's banned word set (FR-021, FR-021a). In the same sweep, find every analyser suppression directive in the tracked tree and confirm each carries a written reason beside it (SC-006) — the pre-existing one in the vendored scaffold is out of this feature's scope and is reported, not owned.

- [X] T018 Confirm no plugin file changed, by comparing each plugin manifest, each marketplace entry and each changelog against the base branch (FR-018, SC-008). The expected result is no difference at all.

- [X] T019 Execute `specs/012-shellcheck-version-gate/quickstart.md` end to end — extract every command block and run it, rather than reading it. A command that only looks right is the failure this step exists to catch.

- [X] T020 Confirm no changelog entry was added anywhere (FR-019), by comparing every changelog file against the base branch.

- [X] T021 Record the two success criteria that cannot be observed on this machine and name where they are: SC-005, the matrix passing on all three operating systems, and SC-007, a second run restoring the runner from cache rather than re-fetching it. Both become observable only after the branch is pushed and the workflow has run — SC-007 needs two runs. Write into the run's record that they are outstanding, and check them on the pull request rather than claiming them here. Reporting an unobserved check as passed is the failure this task exists to prevent.

---

## Traceability — every requirement to its task

Written as a table rather than left to prose, so coverage can be checked
by reading rather than by trusting. A requirement that acquires no task
row is a gap; a task that appears in no row is work nobody asked for.

| Requirement | Task(s) |
|---|---|
| FR-001 | T005 |
| FR-002 | T005 |
| FR-003 | T005 |
| FR-003a | T005, T006a |
| FR-004 | T005 |
| FR-005 | T004, T005 |
| FR-006 | T005 |
| FR-006a | T004 |
| FR-007 | T005, T006 |
| FR-008 | T002 |
| FR-009 | T007, T009 |
| FR-010 | T002, T003 |
| FR-011 | T002, T003 |
| FR-012 | T002, T021 |
| FR-013 | T008 |
| FR-014 | T011 |
| FR-014a | none, by design — see below |
| FR-015 | T012 |
| FR-016 | T012 |
| FR-017 | T013 |
| FR-018 | T014, T018 |
| FR-019 | T020 |
| FR-020 | T016 |
| FR-021 | T017 |
| FR-021a | T005, T017 |
| FR-022 | T015 |
| SC-001 | T006 |
| SC-002 | T008, T010 |
| SC-003 | T011 |
| SC-004 | T016 |
| SC-005 | T021 |
| SC-006 | T004, T017 |
| SC-007 | T021 |
| SC-008 | T018 |
| SC-009 | T015 |
| SC-010 | T006a |

Every task appears at least once above except T001 and T019. T001 is a
precondition check that protects FR-012 without implementing it. T019
executes the quickstart, which exercises many of the rows above rather
than owning one.

---

## Requirements with no task, and why

Two requirements are deliberately unmapped. Neither is an oversight, and
saying so here is what keeps them from reading as one.

- **FR-014a** describes a fallback taken only if a single shared
  implementation proves unworkable. It is a contingency, not work. If it
  is ever taken, it is recorded with its reason at that moment.
- **FR-012**'s cross-platform claim is built into T002 (the
  carriage-return strip) but can only be OBSERVED on the matrix, so its
  observation lives in T021 with SC-005.

---

## Dependencies

```text
T001  (setup, no dependents)

T002 ──┬─> T003 ──┬─> T007 ──> T008 ──> T010
       │          │
       │          └─> T009 ──> T011
       │
       └─────────────> T005   (the analysis job's scope proof needs the
                               script to exist)

T004 ──> T005 ──> T006 ──> T006a

T005 ──> T009 ──> T012 ──> T013 ──> T014
        (all four edit the workflow file; strictly sequential)

everything ──> T015 ... T021
```

Story order deviates from priority order for one reason, stated here so
it is not mistaken for an oversight: User Story 2's script is written
first because User Story 1's scope proof requires it to exist. Both are
P1, so neither is deferred by this.

---

## Parallel opportunities

Only one genuine pair exists, because three of the changes share the
workflow file and two share the suite file:

- **T002 and T004** touch `scripts/check-versions.sh` and
  `tests/helper.bash` respectively, with no dependency between them.
  They may run in the same batch.

Everything else is serialised by a shared file or by a real dependency.
Claiming more parallelism than the file map allows is how two agents
overwrite each other.

---

## Implementation strategy

The smallest shippable increment is Phase 2 plus Phase 4: one script,
two callers, one new test. That alone removes the drifted twin the seed
was written about.

Phase 3 is independently shippable and does not depend on Phase 4
finishing, only on the script existing.

Phase 5 is independent of both and could be dropped without affecting
either gate — but it is small, and the mutable reference it removes is a
live supply-chain exposure.

Phase 6 is not optional. Its checks are what turn "it looks done" into
"it was measured".

---

## Phase 7: Convergence

Appended by the convergence pass after implementation. Every item traces
to a requirement the code now satisfies but the repository's own
documentation still contradicts or omits. None of them change behaviour;
all three are prose that has gone stale in the same commit that made it
stale, which is the only moment it is cheap to fix.

- [X] T022 Rewrite the version-agreement paragraph in `CONTRIBUTING.md` per FR-008 and FR-009 (contradicts). It currently tells a reader that BOTH gates loop over top-level directories and that both loops are `for dir in */`. After this feature there is one loop, in `scripts/check-versions.sh`, and two callers of it. The paragraph's substantive claims — selection by name rather than position, coverage of a plugin added later without editing a gate, and non-coverage of a plugin nested below the top level — all remain true and must survive the rewrite; only the "two loops" framing is false. This is the highest-severity finding because the passage describes precisely the hazard this feature removed.

- [X] T023 Reconcile the runner-installation instructions in `CONTRIBUTING.md` and `README.md` with the workflow per FR-015 (partial). Both documents tell a contributor to clone the test runner at a mutable release reference while the workflow now fetches a pinned commit. Either align the documented command with the pin, or state plainly why a contributor's local clone does not need pinning while the automated one does. Do not leave the two silently disagreeing about how the same dependency is obtained.

- [X] T024 Name the new static analysis check in the contributing guide per FR-001 and contract clause S1 (missing). A contributor currently discovers it by going red. One sentence naming what is analysed, and pointing at the workflow comment for the boundary and its reasons, is enough — do not restate the boundary itself in a second place, which would create a new pair to keep in step.
