# Implementation Plan: the orchestrator builds in pieces

**Branch**: `019-orchestrator-builds-in-pieces` | **Date**: 2026-09-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/019-orchestrator-builds-in-pieces/spec.md`

## Summary

Rewrite the orchestrator document `pipeline/skills/pipeline/SKILL.md` so that
G asks a review question (commits or pauses) on every `claude` run, and H
commits the spec first and then builds and commits one `tasks.md` phase at a
time, using the `piece-next` and `commit-add` commands Phase 19 added. Pause
mode, the hook hard stop, resume and the legacy single-commit rule are written
into H and Resume. Every sentence elsewhere in the file that this makes false
— the `--auto` row, the gate floor, the never-bend reason, MAY-do, Parallel
agents — is rewritten in the same change. New pins go into
`pipeline/tests/prose.bats`, each proven by an inverted mutant; two existing
pins change on purpose. `pipeline/CHANGELOG.md` opens `## [Unreleased]`.

## Technical Context

**Language/Version**: Markdown prose read by an agent (the orchestrator); bash for the tests
**Primary Dependencies**: bats 1.11.0 (pinned in CI); the suite's own `prose_slice` helper; `progress.sh` `piece-next` and `commit-add` (spec 018) as the commands the new prose names
**Storage**: n/a — the prose tells the orchestrator what to write to the run state file (`gates.G.reviewMode`, `measurements.pieceBefore`, `gates.H`, `commits`)
**Testing**: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests` from the repository root
**Target Platform**: the CI matrix — ubuntu, macOS, Windows (Git Bash)
**Project Type**: prose contract inside a plugin, pinned by grep tests
**Performance Goals**: n/a
**Constraints**: the whole-region spans (`When a phase fails`, J, N, red flags, seed forms) are not edited; no line inside the G slice may start with `**` or `#`; the pinned left cells of the gate and never-bend tables do not change; documents outside the orchestrator are Phase 22's
**Scale/Scope**: one document (730 lines), one test file, one changelog

## Constitution Check

*Checked before research and again after design; both pass.*

| Principle | How this plan meets it |
|---|---|
| I. Silence is the failure | A `piece-next` refusal is a hard stop, never a silent fall-back to one commit (FR-007). A legacy state file says out loud that it runs the old way (FR-018). The handoff path says in one line that pieces are off (FR-003). |
| II. Measure; never assert | Every touched pin was found by grep (research R1); the `git status` form was measured on this branch (R4); the dry read against a real tasks file is measured with `piece-next` and saved (SC-003). The suite count is measured before and after. |
| III. A gate must be shown able to go red | Every new pin is run red under an INVERTED mutant — a sentence asserting the opposite — in a worktree, with the mutated line echoed first and a no-op mutant failing the rig. The two changed pins are proven the same way. |
| IV. One implementation | The prose names `piece-next` and `commit-add`; it never re-describes how to find a piece or append a commit. The before-list rule is stated once, in H, and referenced from Resume. |
| V. Derive coverage | Pieces are whatever `piece-next` yields from the tasks file; no piece list is written anywhere. The piece's files are derived from the tree, never listed by the agent from memory. |

Surface rules: `pipeline/skills/` and `pipeline/tests/` are RELAXED surfaces.
Changelog: `## [Unreleased]` opened above `## [1.2.1]` (seed). Departures: none.

## Project Structure

### Documentation (this feature)

```text
specs/019-orchestrator-builds-in-pieces/
├── spec.md
├── plan.md               # this file
├── research.md           # R1–R12
├── data-model.md         # the state the new prose writes
├── quickstart.md         # how to prove it
├── contracts/
│   └── orchestrator-prose.md   # every sentence that must hold, and its pin
├── checklists/
│   └── requirements.md
├── dry-read-017.md       # SC-003, written at implementation
└── tasks.md              # next phase
```

### Source Code (repository root)

```text
pipeline/skills/pipeline/SKILL.md   # G, H, Resume, flags row, Gates, Parallel agents, never-bend row reason, MAY-do
pipeline/tests/prose.bats           # 2 pins changed on purpose; new tests for the review question, pieces, pauses, hook stop, legacy rule, floor
pipeline/CHANGELOG.md               # ## [Unreleased] with ### Added and ### Changed
```

**Structure Decision**: nothing new is created outside the spec directory. The
new pins go in their own `@test` blocks after the region-sliced pins, reusing
`prose_slice`.

## Design notes

- **G** (FR-001–FR-005): the lead paragraph stays byte-identical and gains a
  closing sentence (R3). The pre-answer sentence is replaced (R2). A new plain
  paragraph after the re-entry paragraph states the review question: asked
  once the implementer answer is `claude`, the two answers, recorded as
  `gates.G.reviewMode`, asked every run, never pre-answered, `--auto` never
  collapses it, never re-asked on a re-entry that finds it recorded; the
  `handoff` one-line notice; the claude→handoff flag flip (FR-004).
- **H** (FR-006–FR-018): H is rewritten as a short opening (which flow runs:
  legacy/handoff single-commit, or pieces) and paragraphs for — the spec
  commit; the piece loop with `piece-next` refusal as hard failure; the file
  list (R4) and the before list (R5); the commit (every path named,
  `commitStyle` message, `Piece:` line, `-F` message file, heading as data
  per R6, `commit-add` with the full sha); pause mode (R10); the hook hard
  stop pointing at "When a phase fails" (R1, R9); resume and crash recovery
  (R7, R8). Fan-out, the board and `last_task` keep today's wording inside
  the loop.
- **Resume** gains one paragraph: re-entering H enters the piece `piece-next`
  names, with the rules in H.
- **Gates**: "Up to five stops" and the floor paragraph are rewritten (FR-019);
  the pause joins the conditional-stops paragraph as a stop the developer
  chose; the Implementer row's third cell adds the review question.
- **The flags row** (FR-020): `G stops unless implementer pre-answered it`
  becomes G still stopping for the review question.
- **Never-bend and MAY-do** (FR-021, FR-022): the row reason says every commit
  names every path; MAY-do adds the local spec and piece commits.
- **Parallel agents** (FR-023): H's unit becomes independent tasks within one
  piece; fan-out never crosses a piece boundary.
- **Tests**: see [contracts/orchestrator-prose.md](contracts/orchestrator-prose.md).
  Red first: every new pin is written before the prose and run red against the
  unchanged file (a missing sentence), then green, then inverted-mutant red.

## Complexity Tracking

No constitution violation to justify.
