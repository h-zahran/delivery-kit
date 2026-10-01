# Implementation Plan: Release pipeline 1.3.0

**Branch**: `022-release-pipeline-1-3-0` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/022-release-pipeline-1-3-0/spec.md`

## Summary

Stamp the `pipeline` plugin 1.3.0: one line in its manifest, one line in the
marketplace, and the changelog's `## [Unreleased]` heading turned into
`## [1.3.0] - 2026-10-01`. Nothing else in a shipped file changes. The
version-agreement gate and the house suite confirm the result; CI confirms it
on three systems. Tagging is after the owner's merge.

## Technical Context

**Language/Version**: JSON manifests and Markdown; bash 5 for the checks

**Primary Dependencies**: `sed` (the edits), `jq` (read-only checks), bats
1.11.0 (the house suite), `scripts/check-versions.sh` (the agreement gate)

**Storage**: files in the repository

**Testing**: the house suite from the root —
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`;
shellcheck as CI runs it; `quickstart.md` as one extracted script

**Target Platform**: the Claude Code plugin marketplace; CI on Ubuntu, macOS
and Windows

**Project Type**: plugin repository (two plugins, one marketplace)

**Performance Goals**: not applicable

**Constraints**: three shipped files, one changed line each (FR-006); the
changelog text below the heading byte-identical (FR-004); `marketplace.json`
edited with `sed`, because a `jq` round-trip reflows its `tags` arrays
(measured again at `d9a085e`, CRs stripped: lines 15–19 and 27–31 differ —
research R2);
nothing under `handoff/`

**Scale/Scope**: three lines

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | How this plan meets it |
|---|---|
| I. Silence is the failure | Every check in `quickstart.md` asserts an exact count or an exact rc, and the checks that could pass vacuously carry a control (R3). |
| II. Measure; never assert | Each claim in the spec is a measurement dated `d9a085e`; the quickstart re-measures after the edit. |
| III. A gate must be shown able to go red | The tag-mode agreement check (`--released pipeline`) is run against `d9a085e`, where it must FAIL, before it is trusted to pass on the branch (R3). |
| IV. One implementation | The plan calls `scripts/check-versions.sh`; it adds no second copy of its walk. |
| V. Derive coverage | The version sites are found by search (spec, Edge Cases), not taken from a list; the byte-identity check compares the whole file, not a chosen region. |
| Changelogs are history | Released sections are untouched; the open block is stamped as it stands (FR-004). The truth-pass on its text was P22's. |
| Development workflow | Suite from the root over all three paths; CI on three systems; every path named at K; no force-push, no tag before the merge. |

Result: PASS. No violation to justify.

## Project Structure

### Documentation (this feature)

```text
specs/022-release-pipeline-1-3-0/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── release-stamp.md
├── checklists/
│   └── requirements.md
└── tasks.md            # /speckit-tasks
```

### Source Code (repository root)

```text
.claude-plugin/marketplace.json          # pipeline entry: version line
pipeline/.claude-plugin/plugin.json      # version line
pipeline/CHANGELOG.md                    # the [Unreleased] heading
```

**Structure Decision**: no new file outside the spec directory. The three
files above are the whole shipped change.

## Post-design Constitution Check

Re-checked after `research.md`, `data-model.md`, the contract and the
quickstart were written: PASS, unchanged.

## Complexity Tracking

None.
