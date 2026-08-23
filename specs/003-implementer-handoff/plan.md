# Implementation Plan: the implementer handoff package, upgraded

**Branch**: `003-implementer-handoff` | **Date**: 2026-08-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-implementer-handoff/spec.md`

## Summary

The **G — implementer gate** section of the pipeline orchestrator gains a
compact named list specifying the handoff package's seven parts, added
near the existing paragraph with every pre-existing sentence
byte-identical; one new prose test pins the seven names (red-first, then
mutation-verified); the changelog's `[Unreleased]` section gains the
Added entry. No version stamp.

## Technical Context

**Language/Version**: Markdown (SKILL.md, CHANGELOG), bats 1.11.0 (tests)

**Primary Dependencies**: none new — the prose test uses the existing `grep` pattern style of `pipeline/tests/prose.bats`

**Storage**: N/A

**Testing**: focused — `bash /c/Users/h_zah/bats/bin/bats pipeline/tests/prose.bats` (grows `1..8` → `1..9`); full house suite from repo root (grows `1..118` → `1..119`)

**Target Platform**: the CI matrix ubuntu/macos/windows (bash everywhere)

**Project Type**: plugin prose + tests + changelog (pipeline plugin only)

**Performance Goals**: N/A (prose and one grep-gate test)

**Constraints**: add near, never reword — every existing G sentence byte-identical (three called out: the derived-forbidden-list sentence, the P1 VOID sentence, "`--auto` never collapses this gate: it spends money"); `pipeline/CHANGELOG.md` is a STRICT vocabulary surface; suite growth exactly +1; part names are quoted contract (contracts/package-contract.md)

**Scale/Scope**: three files — `pipeline/skills/pipeline/SKILL.md`, `pipeline/tests/prose.bats`, `pipeline/CHANGELOG.md`. No fixtures, no scripts.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo's own `.specify/memory/constitution.md` is still the unfilled
template — no gates derive from it. (P2 made this state visible in the
pre-flight probe; the principles remain the owner's to write, and the
owner has not yet chosen to. Recorded, not blocking.)

## Project Structure

### Documentation (this feature)

```text
specs/003-implementer-handoff/
├── plan.md                # This file
├── research.md            # Shape, spelling, red-first and mutation strategy
├── quickstart.md          # Validation guide
├── contracts/
│   └── package-contract.md  # The seven part names (quoted) + byte-pinned G sentences
└── tasks.md               # Phase 2 output (/speckit-tasks)
```

data-model.md is deliberately absent: the "entity" is a document
contract, and contracts/package-contract.md is its home.

### Source Code (repository root)

```text
pipeline/
├── skills/pipeline/SKILL.md   # FR-001: the seven-part package contract in G
├── tests/prose.bats           # FR-002: one appended test pinning the seven names
└── CHANGELOG.md               # FR-003: Added entry under [Unreleased]
```

**Structure Decision**: everything edits the three real files above;
the package contract text lives inside the G section itself (the spec
requires it there — no separate reference file).

## Complexity Tracking

No constitution violations to justify (no constitution gates exist yet —
see above).
