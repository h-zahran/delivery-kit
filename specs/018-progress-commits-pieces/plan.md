# Implementation Plan: progress.sh learns commits and pieces

**Branch**: `018-progress-commits-pieces` | **Date**: 2026-09-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/018-progress-commits-pieces/spec.md`

## Summary

Add two subcommands to `pipeline/scripts/progress.sh`. `commit-add` appends one
typed entry to the run's `commits` list — refusing bad input by name, and
succeeding without a write on an identical re-record. `piece-next` reads the
run's tasks file and prints the first `## Phase <N>:` section that has tasks
and is not yet recorded, as two clean lines. Both are one jq program each,
driven from bash, because every measured hazard on this platform (research
R1–R5) sits at a boundary between the two. Tests go in
`pipeline/tests/progress.bats`, against a new fixture tasks file whose headings
are copied from real ones.

## Technical Context

**Language/Version**: bash (the script's `#!/usr/bin/env bash`, `set -euo pipefail`); no bash-4-only features, since macOS may run the system bash
**Primary Dependencies**: jq ≥ 1.7 (`--rawfile`, `--args --`, `$ARGS`). Measured on 1.8.1; `--args --` was never measured on 1.6, so 1.6 is not claimed. CI's runner images carry 1.7 or later, and the suite's `-`-leading path test measures each of them
**Storage**: the run state file, `.delivery-kit/runs/<feature>/progress.json`
**Testing**: bats 1.11.0 (pinned in CI), from the repository root
**Target Platform**: Git Bash on Windows with a native Windows jq; Linux; macOS — the CI matrix
**Project Type**: command-line helper inside a plugin
**Performance Goals**: beyond the spawns `validate` already makes, at most two jq spawns per `commit-add` call (classify, then append) and two per `piece-next` call (read `artifacts.tasks`, then the walk)
**Constraints**: stdout carries results only; diagnostics on stderr; no `while read` over jq output; no CR may reach stdout
**Scale/Scope**: one script (~180 lines today), one test file, one fixture

## Constitution Check

*Checked before research and again after design; both pass.*

| Principle | How this plan meets it |
|---|---|
| I. Silence is the failure | `piece-next` separates "nothing left" (empty, exit 0) from "nothing to read" (a named refusal, exit 1). A tasks file with no piece is refused, never reported as done. A legacy first word that is not a plausible id matches nothing rather than everything. |
| II. Measure; never assert | Every design choice cites a dated measurement (research R1–R7). SC-005's replay over every real state file — counted by the replay itself, failing on zero — is run and its output saved. |
| III. A gate must be shown able to go red | Every new test is run red against the unchanged script first (R8 makes that meaningful: each refusal test checks its message, not only the exit code). Boundaries are tested on both sides (R9). |
| IV. One implementation | The legal kinds are one variable, used by the check and by its message. `commit-add` and `piece-next` reuse `cmd_validate` and `state_file`; nothing re-derives the state path. |
| V. Derive coverage | The pieces are derived from the tasks file, never listed. The kinds have two views pinned equal: the script's `KINDS` and the contract's eight, written literally in the test, whose count is asserted to be 8. |

Surface rules: `pipeline/scripts/` and `pipeline/tests/` are RELAXED surfaces.
No changelog entry (seed: routing none). No document changes (FR-015).

## Project Structure

### Documentation (this feature)

```text
specs/018-progress-commits-pieces/
├── spec.md
├── plan.md               # this file
├── research.md           # R1–R9, measured
├── data-model.md
├── quickstart.md
├── contracts/
│   └── progress-commands.md
├── checklists/
│   └── requirements.md
└── tasks.md              # next phase
```

### Source Code (repository root)

```text
pipeline/scripts/progress.sh             # + KINDS, cmd_commit_add, cmd_piece_next, usage, dispatcher
pipeline/tests/progress.bats             # + the new tests
pipeline/tests/fixtures/tasks-pieces/
└── tasks.md                             # NEW: real heading shapes, task-less heading, ### subheadings, non-piece sections
```

**Structure Decision**: the feature lives entirely in the existing helper and
its existing suite. The fixture goes in its own directory under
`pipeline/tests/fixtures/`, beside the project-layout fixtures, and is
re-included by the existing `!pipeline/tests/fixtures/**` rule in
`.gitignore`. It is named for what it holds, not for a test.

## Design notes

- **`commit-add` order of checks**: argument count; kind (letters only, then
  membership); sha empty; sha shape; piece rules (non-empty for `piece`; no
  CR, LF or U+001F); file rule; then state file (`sf="$(cmd_validate …)"` —
  captured, because `cmd_validate` prints the path on stdout and `commit-add`
  must print nothing); then ONE jq call printing `new`, `same`, `conflict` or
  `legacy` (R7), branched with `case` whose default arm dies; then, for `new`,
  one jq call that appends through `$sf.tmp` and `mv`, passing the files as
  `--args -- "$@"`. Cheap checks first, so a bad call never spawns jq.
- **`piece-next`**: `cmd_validate`; read `artifacts.tasks` (one line via `$()`);
  refuse if empty or missing; then ONE jq call with `--rawfile` over the state
  file that prints one line — `none`, `done`, `bad`, or `next` US heading US ids (R3,
  R5, R6). Bash branches on the status word and prints with `printf '%s\n%s\n'`.
- **Kinds**: `KINDS=" spec piece converge simplify review tests constitution other "`,
  matched word by word with an exact comparison. Measured at analyze (review
  F7): the substring idiom `PHASES` uses accepts `spec piece`, because that
  string with spaces round it IS a substring of the list. **Changed at H.7
  (simplify):** the first build put a letters-only guard in front of the
  substring idiom; review showed that patched the input rather than the test,
  and the exact word loop replaced both. `PHASES` has the same hole today
  ("A B" and "C C.5" were measured to pass); it is out of this feature's
  scope, and a comment at `phase_known` records it and names the fix.
- **`piece-next` status words**: `none`, `done`, `bad` (the next heading, after its one
  trailing CR is stripped, still holds a CR or U+001F) or `next`, again branched with `case` and a dying default.
- **`usage`**: the existing test at `pipeline/tests/progress.bats:311` pins the
  WHOLE command list as one literal, so any addition breaks it. That test is
  edited to the new list — it becomes US3's red-first test — rather than a
  weaker second test being added beside it (review F1).
- **Dispatcher**: `commit-add) shift 2; cmd_commit_add "$feature_arg" "$@" ;;`
  and `piece-next) cmd_piece_next "$feature_arg" ;;`.

## Complexity Tracking

No constitution violation to justify.
