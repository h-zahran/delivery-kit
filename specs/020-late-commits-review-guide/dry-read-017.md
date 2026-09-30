# Dry read: the review guide for 017's tasks.md

**Date**: 2026-09-30 (re-run at I, after the guide program gained code
spans, a longer fence for a backtick, and its line-break refusal) · **Task**: T025 · **Measures**: SC-003

A record of one run on the date above, against
`specs/017-guard-config-bounds/tasks.md` as it stood at commit `8efe515`, with
this branch's `pipeline/scripts/progress.sh` (unchanged by this feature). It is
not a claim about either file at any later date.

## How it was run

The script is `.delivery-kit/runs/020-late-commits-review-guide/t025-dry-read.sh`
(ignored by git, like every run artefact). In a fresh scratch git repository
outside this one it:

1. `init`s a run, points `artifacts.tasks` at 017's tasks file, and makes and
   records a real `docs(spec): …` commit as kind `spec`;
2. loops `piece-next`, splitting its output by parameter expansion, making one
   REAL commit per piece (a placeholder file, and a `Piece: <heading>` line)
   and recording it with `commit-add` as kind `piece`, until `piece-next`
   prints nothing;
3. copies the tasks file, appends a `## Phase N: Convergence` section with one
   task (the next phase number and task ID, derived from the file), points
   `artifacts.tasks` at the copy, and records H.5's commit as kind `converge`
   with the heading `piece-next` printed for it;
4. makes and records one `simplify` and one `review` commit, and one EMPTY
   `tests` commit (`git commit --allow-empty --only`, recorded with no files);
5. makes one commit it does not record (an M fix), finds it by walking
   `git rev-list --reverse main..HEAD` against `commits`, and records it as
   kind `other` with its files from `git diff-tree` (contract V3);
6. extracts the guide program from `data-model.md` (never retyped) and runs it
   with the branch's `rev-list`.

The Files column is what `commit-add` recorded; the placeholder commits in the
scratch repository do not touch a real `tasks.md`.

## What `piece-next` printed, in order

```
== spec commit
== piece-next 1: Phase 1: Setup — capture what cannot be recaptured | T001,T002
== piece-next 2: Phase 3: User Story 1 — a percentage that can never arrive in time (P1) 🎯 MVP | T003,T004,T005,T006,T007,T008,T009,T010,T011,T012
== piece-next 3: Phase 4: User Story 2 — the window size (P2) — a RULED NON-CHANGE | T013,T014,T015
== piece-next 4: Phase 5: User Story 3 — the written rule and the enforced rule agree (P3) | T016,T017,T018,T019
== piece-next 5: Phase 6: Polish & cross-cutting | T020,T021,T022,T023,T024,T025,T026
== piece-next 6: Phase 7: appended by the converge assessment (H.5), 2026-09-04 | T027,T028
== piece-next after the last piece: []
== piece-next once converge appended: Phase 8: Convergence T046 
== piece-next after H.5 records it: []
== unrecorded before V3: 01ab34002d59862da4bd183fc433c54cdae54ae4
```

017's own `Phase 7` was appended by a converge run on 2026-09-04, before this
feature existed, and never recorded as `converge`, so `piece-next` offers it as
an ordinary piece (a `piece` row). The `Phase 8: Convergence` this run appended
is offered once, recorded as `converge`, and never offered again. 017 has no
`## Phase 2:` with tasks, so there is no Phase 2 row.

## The guide, as L and DONE would print it

Read this branch commit by commit, top to bottom: each row is one commit, oldest first.

| Commit | Kind | Piece | Task IDs | Files |
|---|---|---|---|---|
| 119fbf2 | spec |  |  | `specs-017.txt` |
| 7161e51 | piece | `Phase 1: Setup — capture what cannot be recaptured` | T001,T002 | `piece-1.txt`, `tasks.md` |
| 9d316a8 | piece | `Phase 3: User Story 1 — a percentage that can never arrive in time (P1) 🎯 MVP` | T003,T004,T005,T006,T007,T008,T009,T010,T011,T012 | `piece-2.txt`, `tasks.md` |
| 020cf56 | piece | `Phase 4: User Story 2 — the window size (P2) — a RULED NON-CHANGE` | T013,T014,T015 | `piece-3.txt`, `tasks.md` |
| d81b87d | piece | `Phase 5: User Story 3 — the written rule and the enforced rule agree (P3)` | T016,T017,T018,T019 | `piece-4.txt`, `tasks.md` |
| 1f4706f | piece | `Phase 6: Polish & cross-cutting` | T020,T021,T022,T023,T024,T025,T026 | `piece-5.txt`, `tasks.md` |
| 4fe9a63 | piece | `Phase 7: appended by the converge assessment (H.5), 2026-09-04` | T027,T028 | `piece-6.txt`, `tasks.md` |
| 4ff6141 | converge | `Phase 8: Convergence` | T046 | `converge.txt`, `tasks-copy.md` |
| 0d431ee | simplify |  |  | `simplify.txt` |
| 2cac72b | review |  |  | `review.txt` |
| ea5b872 | tests |  |  | (no files: empty commit) |
| 7f6fd76 | other |  |  | `m-fix.txt` |

The program exited 0. Its two refusals — an entry not on the branch, and a
commit not recorded — were measured separately (research R9).
