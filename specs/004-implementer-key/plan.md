# Implementation Plan: pre-answer the implementer gate — the loop closes

**Branch**: `004-implementer-key` | **Date**: 2026-08-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/004-implementer-key/spec.md`

## Summary

One new configuration key (`implementer`, default unset, legal values
`claude`/`handoff`) and one new flag (`--implementer <claude|handoff>`,
beats the key), documented character-identically in the orchestrator's
two tables and the configuration page's JSON block and key table; the G
paragraph gains the seed's quoted sentence pair; the changelog gains its
Added entry. Prose only — no script, no test file changes, suite stays
`1..119`. The run itself is the feature's field test: G is answered
"handoff", the package is written, the run parks at H, and the resume
consumes the external implementer's report.

## Technical Context

**Language/Version**: Markdown (SKILL.md, configuration.md, CHANGELOG)

**Primary Dependencies**: none new

**Storage**: N/A

**Testing**: focused — `bash /c/Users/h_zah/bats/bin/bats --tap pipeline/tests/prose.bats` (stays `1..9`); full house suite from repo root (stays `1..119`); row identity by extract-and-diff (quickstart §2)

**Target Platform**: the CI matrix ubuntu/macos/windows

**Project Type**: plugin prose + docs + changelog (pipeline plugin only)

**Performance Goals**: N/A

**Constraints**: add near, never reword; the G gate row `| Implementer | G |` byte-identical; `pipeline/docs/configuration.md` and `pipeline/CHANGELOG.md` are STRICT vocabulary surfaces; suite growth exactly zero; `handoff/**` untouched (plan Decision 4); key rows character-identical across the two files (name, values, default — contracts/key-contract.md pins the exact strings)

**Scale/Scope**: three files — `pipeline/skills/pipeline/SKILL.md`, `pipeline/docs/configuration.md`, `pipeline/CHANGELOG.md`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This repo's constitution is still the unfilled template. THIS run is
the first whose pre-flight printed the Constitution line and made the
one-time offer (P2's feature, live); the owner declined, and the
decline is recorded in the state file's `gates.constitution`. No gates
derive from the empty document. Recorded, not blocking.

## Project Structure

### Documentation (this feature)

```text
specs/004-implementer-key/
├── plan.md              # This file
├── research.md          # Row wording, placement, and field-test strategy
├── quickstart.md        # Validation guide
├── contracts/
│   └── key-contract.md  # The exact key/flag row strings + the quoted G sentences
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

data-model.md is deliberately absent: a configuration key is not an
entity; contracts/key-contract.md carries the exact strings.

### Source Code (repository root)

```text
pipeline/
├── skills/pipeline/SKILL.md    # FR-001/002 rows in both tables; FR-003 quoted G sentences
├── docs/configuration.md       # FR-001 JSON block + key table row; FR-004 paragraph
└── CHANGELOG.md                # FR-005 Added entry
```

**Structure Decision**: three real files, additive edits only. The
run's own G gate ("handoff") field-tests the P3 package machinery —
that is SC-004, executed by the pipeline itself, not by a file edit.

## Complexity Tracking

No constitution violations to justify (no constitution gates exist —
see above).
