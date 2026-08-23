# Implementation Plan: constitution — probe it, print it, offer it once

**Branch**: `002-constitution-probe` | **Date**: 2026-08-22 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-constitution-probe/spec.md`

## Summary

One new boolean in the pre-flight probe (`speckit.constitutionSet`), two test-first bats tests proving it both ways, a `Constitution` line plus a one-time `/speckit-constitution` offer in the orchestrator's pre-flight text, and a `## [Unreleased]` changelog section. No version stamp; the external script contract is otherwise unchanged.

## Technical Context

**Language/Version**: bash (preflight.sh), bats 1.11.0 (tests), Markdown (SKILL.md, CHANGELOG)

**Primary Dependencies**: jq (already required by the script); the existing fixture convention under `pipeline/tests/fixtures/`

**Storage**: N/A

**Testing**: focused — `bash /c/Users/h_zah/bats/bin/bats pipeline/tests/preflight.bats`; full house suite from repo root (grows `1..116` → `1..118`)

**Target Platform**: the CI matrix ubuntu/macos/windows (bash everywhere)

**Project Type**: plugin script + tests + docs (pipeline plugin only)

**Performance Goals**: N/A (one file stat, a BOM sniff, one awk pass and two greps per probe)

**Constraints**: stdout stays pure JSON; same flags, same keys plus exactly one new boolean; RELAXED vocabulary on script/tests, STRICT on CHANGELOG; probe-line wordings are quoted contract; fixtures are plain file trees (re-included wholesale by the tracked `.gitignore`), no dependencies

**Scale/Scope**: five files — `pipeline/scripts/preflight.sh`, `pipeline/tests/preflight.bats`, `pipeline/skills/pipeline/SKILL.md`, `pipeline/CHANGELOG.md`, `pipeline/docs/configuration.md` (offer disclosure, added by the P2 PR review) — plus two small fixture trees

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo's own `.specify/memory/constitution.md` is still the unfilled template — no gates derive from it. (This feature exists to make exactly that state visible; the irony is recorded deliberately.)

## Project Structure

### Documentation (this feature)

```text
specs/002-constitution-probe/
├── plan.md              # This file
├── research.md          # Detection-mechanism decision, fixture and red-first strategy
├── quickstart.md        # Validation guide
├── contracts/
│   └── probe-contract.md  # The boolean's semantics + the probe-line wordings
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

data-model.md is deliberately absent: no entities.

### Source Code (repository root)

```text
pipeline/
├── scripts/preflight.sh          # FR-001: emit speckit.constitutionSet
├── tests/preflight.bats          # FR-002: two appended tests (red first)
├── tests/fixtures/
│   ├── constitution-unset/       # fresh-init-shaped: template-placeholder constitution
│   └── constitution-set/         # written principles
├── skills/pipeline/SKILL.md      # FR-003: probe line + one-time offer (quoted wordings)
└── CHANGELOG.md                  # FR-004: ## [Unreleased] above ## [1.0.1]
```

**Structure Decision**: two new plain-file fixture trees follow the existing `pipeline/tests/fixtures/<name>/` convention; everything else edits the four real files above.

## Complexity Tracking

No constitution violations to justify (no constitution gates exist yet — see above).
