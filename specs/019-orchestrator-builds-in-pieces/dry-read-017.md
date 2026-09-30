# Dry read: 017's tasks.md, piece by piece

**Date**: 2026-09-29 · **Task**: T025 · **Measures**: SC-003 (research R11)

A record of one run on the date above, against `specs/017-guard-config-bounds/tasks.md`
as it stood at commit `b0b3f1b`. It is not a claim about that file, or about
`progress.sh`, at any later date.

## How it was run

In a fresh scratch directory outside the repository (`git init -q`, because
`STATE_ROOT` is relative to the working directory), with the repository's own
`pipeline/scripts/progress.sh`. `$REPO` is the repository root; the absolute
form of the tasks path was used, and is not reproduced here.

```bash
bash "$REPO/pipeline/scripts/progress.sh" init dryread-017 dryread-017 main other
# artifacts.tasks := absolute path of specs/017-guard-config-bounds/tasks.md
jq --arg p "$REPO/specs/017-guard-config-bounds/tasks.md" '.artifacts.tasks = $p' \
  .delivery-kit/runs/dryread-017/progress.json > progress.tmp \
  && mv progress.tmp .delivery-kit/runs/dryread-017/progress.json
bash "$REPO/pipeline/scripts/progress.sh" validate dryread-017

# loop, capped at 20 iterations; stops when piece-next prints nothing
out="$(bash "$REPO/pipeline/scripts/progress.sh" piece-next dryread-017)"
piece="${out%%$'\n'*}"; tasks="${out#*$'\n'}"      # split by expansion, never `read`
bash "$REPO/pipeline/scripts/progress.sh" commit-add dryread-017 piece \
  "$(printf '%040x' "$n")" "$piece" "$tasks" "placeholder-$n.txt"
```

Every call exited 0. The seventh `piece-next` printed 0 bytes and the loop
ended after six pieces. The raw output is kept in the run directory as
`t025-dry-read.txt`, which is ignored by git.

## The pieces, in the order `piece-next` yielded them

| # | Heading (verbatim) | Task IDs | Changes only 017's `tasks.md`? |
|---|---|---|---|
| 1 | `Phase 1: Setup — capture what cannot be recaptured` | T001,T002 | **Yes.** Both tasks write only under `.delivery-kit/runs/`, which git ignores (`.gitignore:4`). The only tracked change is the `[X]` marks. |
| 2 | `Phase 3: User Story 1 — a percentage that can never arrive in time (P1) 🎯 MVP` | T003–T012 (T003,T004,T005,T006,T007,T008,T009,T010,T011,T012) | **No.** Edits `handoff/hooks/context-guard.sh` and `handoff/tests/context-guard.bats`. |
| 3 | `Phase 4: User Story 2 — the window size (P2) — a RULED NON-CHANGE` | T013,T014,T015 | **No, but it changes no code.** T015 only verifies. T013 and T014 write the ruling into a second file, `specs/015-guard-jq-spawn-two/tasks.md` at its T045. The feature's commit `5ff33c6` does change that file. The heading rules the hook out, not every file. |
| 4 | `Phase 5: User Story 3 — the written rule and the enforced rule agree (P3)` | T016,T017,T018,T019 | **No.** Edits `handoff/docs/configuration.md` (T017) and `handoff/tests/context-guard.bats` (T018). |
| 5 | `Phase 6: Polish & cross-cutting` | T020,T021,T022,T023,T024,T025,T026 | **No.** Edits `scripts/context-guard/differential.sh` (T020), `scripts/context-guard/README.md` (T022) and `handoff/CHANGELOG.md` (T023). |
| 6 | `Phase 7: appended by the converge assessment (H.5), 2026-09-04` | T027,T028 | **No.** Edits `scripts/context-guard/differential.sh` and its README. **Appended by that run's H.5** (017 `tasks.md:183`). Once Phase 21 gives H.5 its own commit (ruling 18), H.5 records it as kind `converge`, and `piece-next` counts `piece` and `converge` alike as done, so H would never be offered it. The orchestrator at this phase does not yet make that commit. It appears here only because this dry read recorded every piece as `piece`. |

So, going by the text of the tasks, only piece 1 would change nothing tracked
except `tasks.md`. Piece 3 touches no code, but it touches a second spec file.

## Headings `piece-next` skipped, measured

017's `tasks.md` has thirteen `## ` headings. `piece-next` never yielded seven
of them:

- `## Phase 2: Foundational` (line 52). This is a `Phase <N>:` heading with no task line
  under it: its body is "**None.**" and prose. The loop went straight from
  Phase 1 to Phase 3.
- `## Format: …` (line 20), `## ⚠️ Four rules that override anything below` (27),
  `## Dependencies` (140), `## Parallel opportunities` (164) and
  `## Implementation strategy` (171). None of these is a `Phase <N>:` heading,
  so none is a piece.
- The `### ` subheadings inside Phase 3 open nothing. Their tasks (T003–T012)
  arrived as one piece under the Phase 3 heading.

Every task in the file was already marked `[X]` when this ran.
`piece-next` decides what is done from `commits` alone, never from the marks,
so all six pieces were offered.
