# Implementation Plan: pipeline 1.0.1 — release-day truth and door polish

**Branch**: `001-pipeline-101-polish` | **Date**: 2026-08-21 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-pipeline-101-polish/spec.md`

## Summary

Five additive prose fixes to the pipeline plugin's shipped text (four in the orchestrator skill, one measured fix in the README), plus the 1.0.1 version stamp across its three sites. No behavior changes. Every new sentence is contract text quoted verbatim from the plan of record; every existing pinned string survives byte-for-byte.

## Technical Context

**Language/Version**: Markdown prose and JSON manifests; house tooling is bash + jq + bats 1.11.0

**Primary Dependencies**: bats house suite (repo root, `1..116` baseline), `pipeline/tests/prose.bats` (pin gate, `1..8`), jq (version agreement check)

**Storage**: N/A

**Testing**: `bash /c/Users/h_zah/bats/bin/bats -r --print-output-on-failure tests handoff/tests pipeline/tests` (full), `bash /c/Users/h_zah/bats/bin/bats pipeline/tests/prose.bats` (focused)

**Target Platform**: Claude Code plugin, CI matrix ubuntu/macos/windows

**Project Type**: plugin documentation + manifests (pipeline plugin only; `handoff/**` untouched)

**Performance Goals**: N/A (prose)

**Constraints**: pinned strings byte-identical ("add near, never reword"); STRICT surfaces (`pipeline/README.md`, `pipeline/CHANGELOG.md`, `.claude-plugin/`) use hyphenated spec-tool spellings and ban the Global Constraints word list; RELAXED surfaces (`pipeline/skills/`, `pipeline/tests/`) ban only the shorter list; shipped prose is count-free; changelog headings parse as `## [X.Y.Z] - YYYY-MM-DD`

**Scale/Scope**: five files — `pipeline/skills/pipeline/SKILL.md`, `pipeline/README.md`, `pipeline/CHANGELOG.md`, `pipeline/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`; suite count stays 116

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is the unfilled template a fresh `specify init` leaves — it defines no project principles yet, so no constitution gates derive from it. Nothing to check against; recorded honestly rather than invented. (The dogfood plan's Phase 2 exists precisely to make this state visible at pre-flight.)

## Project Structure

### Documentation (this feature)

```text
specs/001-pipeline-101-polish/
├── plan.md              # This file
├── research.md          # Phase 0 output — the short-form measurement decision
├── quickstart.md        # Phase 1 output — validation guide
├── contracts/
│   └── prose-contract.md  # Phase 1 output — the byte-exact sentences and stamp sites
└── tasks.md             # Phase 2 output (/speckit-tasks — not created by plan)
```

data-model.md is deliberately absent: this feature has no entities.

### Source Code (repository root)

```text
pipeline/
├── skills/pipeline/SKILL.md      # FR-001..FR-004: four additive sentences (RELAXED surface)
├── README.md                     # FR-005: measured invocation spelling (STRICT surface)
├── CHANGELOG.md                  # FR-006: ## [1.0.1] heading + entries (STRICT surface)
└── .claude-plugin/plugin.json    # FR-006: version 1.0.1

.claude-plugin/
└── marketplace.json              # FR-006: pipeline entry 1.0.1 (STRICT surface)
```

**Structure Decision**: edits land in the five real files above; no new directories, no new tests (suite stays 1..116).

## Complexity Tracking

No constitution violations to justify (no constitution gates exist yet).
