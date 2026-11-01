# Implementation Plan: Every prose slice is guarded, and the slice helper's guards are tested

**Branch**: `046-prose-slice-guards` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/046-prose-slice-guards/spec.md`

## Summary

`pipeline/tests/prose.bats` slices the pipeline's prose documents with bare
`awk '/open/,/close/'` ranges at 13 sites; most have no check that the range
closed, so a renamed heading turns a sectioned pin into a file-wide one with
the suite still green. The file also spells the flatten pipeline out 55 times.
This change gives the existing `prose_slice` helper a `<file>` first argument
and an optional list of declared inner lines, routes all 13 bare ranges and
every existing call through it, adds one `prose_flat` helper that every
flatten site uses, commits a test per helper guard, and adds a test that walks
the file and refuses a new bare range or inline flatten. No pin text changes;
a recorded differential proves every converted haystack byte-identical.

## Technical Context

**Language/Version**: bash (4.x+ on Linux and Windows Git Bash runners; 3.2 on the macOS runner)

**Primary Dependencies**: bats-core 1.11.0 (`$HOME/bats/bin/bats`), awk, grep, tr, sed

**Storage**: N/A

**Testing**: bats; the full suite is `testCommand` in `.delivery-kit.json` (four roots); shellcheck is `analyzeCommand`

**Target Platform**: CI on ubuntu, macOS and Windows runners; local Ubuntu (uutils coreutils)

**Project Type**: test-suite change inside a Claude Code plugin repository

**Performance Goals**: prose.bats wall time grows no more than 25% (SC-006)

**Constraints**: bash 3.2 compatibility (no `${x// /}` over large text, no `mapfile`); no herestring of a whole document (Git Bash hangs at ~64 KB) — whole documents keep reaching the flatten helper by `<` redirect; no pin text changes (FR-004)

**Scale/Scope**: one file, `pipeline/tests/prose.bats` (2,439 lines, 68 tests at `f72276c`); 13 bare range sites, 55 flatten lines (one inside `prose_slice`, 54 outside it, one of those split across two lines), ~60 existing `prose_slice` calls

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | How this plan meets it | Status |
|---|---|---|
| I. Silence is the failure that matters | The change exists to remove a silent pass (an unterminated range). The refusing test fails when it walked zero lines. Guard tests assert the exact exit status, so a guard that stops speaking goes red. | PASS |
| II. Measure; never assert | FR-004's byte-identical claim is produced by a differential run over every converted site, recorded with date and commit in `differential.md`. Counts in this plan are a record of one run (`f72276c`), with the commands that made them in research.md. | PASS |
| III. A gate must be shown able to go red | Each guard test and the refusing test get a positive control that is run (scratch worktree, mutation echoed before its result is believed). The boundary-rename sweep (SC-002) confirms each mutation landed. | PASS |
| IV. One implementation, many callers | One slicer and one flatten helper; the refusing test pins that no inline copy remains or returns. | PASS |
| V. Derive coverage; never enumerate it | The refusing test walks the file instead of listing sites; the sweep derives boundaries from the calls instead of listing them. | PASS |

No violations. Post-design re-check (after Phase 1): still PASS — the
contract adds an optional argument list, not a second slicer.

## Project Structure

### Documentation (this feature)

```text
specs/046-prose-slice-guards/
├── spec.md
├── plan.md              # this file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── prose-helpers.md # the two helpers' call contract
├── differential.md      # written during implementation (FR-004 record)
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
pipeline/tests/
└── prose.bats           # the only file changed
```

**Structure Decision**: one test file changes. No shipped script, document or
manifest changes, so no plugin version bump, changelog entry or release.

## Complexity Tracking

No constitution violations to justify.
