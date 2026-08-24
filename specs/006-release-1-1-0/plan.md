# Implementation Plan: release pipeline 1.1.0

**Branch**: `006-release-1-1-0` | **Date**: 2026-08-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-release-1-1-0/spec.md`

## Summary

Move the `pipeline` plugin from `1.0.1` to `1.1.0` at the three places a version is stated, and close the changelog's open `[Unreleased]` section into a dated `1.1.0` heading over the four features already accumulated there. Nothing else changes. The whole feature is THREE edited lines carrying four pinned strings — the heading is one line but two strings, old and new — and its difficulty is entirely in NOT doing more than that.

The interesting decision was made at clarification: the seed names P1's `jq` line as the proof of agreement, but `jq` reads JSON and the third site is a markdown heading — so that check would happily pass a tree whose changelog still said `[Unreleased]`. The verification is therefore one command over all three sites yielding one verdict.

## Technical Context

**Language/Version**: Markdown prose and JSON manifests. House tooling is bash, `jq`, and bats 1.11.0.

**Primary Dependencies**: the bats house suite from the repository root (`1..121` baseline); `jq` for both JSON sites; `grep` for the markdown heading. No build, no runtime, no package manager.

**Storage**: N/A — three files on disk.

**Testing**: the existing house suite, unchanged. **No test is added.** The plan's Global Constraints record the prose-pin debt as PAID by P4 and name P5 and P6 directly: do not re-queue it (FR-010). A new test would also move the count FR-007 freezes.

**Target Platform**: the Claude Code plugin cache, which reads the manifest; the marketplace listing, which advertises the plugin; and human readers of the changelog.

**Project Type**: `other` — a documentation-and-manifest plugin. No source code is compiled or executed by this change.

**Performance Goals**: N/A.

**Constraints**: exactly THREE lines change on the shipped surface — two JSON `version` values and one changelog heading — carrying four pinned strings, because the heading is one line but two strings, old and new. Nothing else changes. Suite count frozen at the measured baseline. No tag created by this run (FR-009). The orchestrator's grep-pinned prose is not touched at all, so "add near, never reword" is satisfied by having nothing to reword — a fact to verify in the diff rather than assume.

**Scale/Scope**: three files, three changed lines, four pinned strings, one date.

## Constitution Check

`.specify/memory/constitution.md` exists but is the **unfilled template** — every principle is still a `[PRINCIPLE_N_NAME]` placeholder. Pre-flight reported `constitutionSet: false` for exactly this reason, and the owner declined the offer to write one for a third consecutive run. The gates therefore run against an empty document and **PASS vacuously**. That is recorded here rather than reported as a pass, because a vacuous pass and a real one are not the same evidence.

No violation is possible where no principle is stated. Nothing in this feature would strain a plausible constitution in any case: it adds no dependency, no abstraction, no surface, and no behaviour.

## Project Structure

### Documentation (this feature)

```
specs/006-release-1-1-0/
├── spec.md
├── plan.md               # this file
├── research.md           # R1-R4
├── contracts/
│   └── version-contract.md   # the four exact strings, pinned
├── quickstart.md         # the runnable proof
└── checklists/
    └── requirements.md
```

No `data-model.md`. The spec's Key Entities are three literal strings and one recorded measurement — there is no schema, no relationship and no lifecycle to model. Pinning the exact strings in `contracts/version-contract.md` is the useful form of the same information, and a near-empty `data-model.md` would be a stub that later phases must read and learn nothing from. Stated here so its absence is a decision, not an omission.

### Source Code (repository root)

```
pipeline/
├── .claude-plugin/
│   └── plugin.json       # SITE 1 — "version": "1.0.1" -> "1.1.0"
└── CHANGELOG.md          # SITE 3 — "## [Unreleased]" -> "## [1.1.0] - 2026-08-24"

.claude-plugin/
└── marketplace.json      # SITE 2 — plugins[name=="pipeline"].version -> "1.1.0"
```

**Structure Decision**: no structure changes. The three paths above are the entire footprint. `handoff/` is untouched — its own `2.1.0` entry in the same marketplace file stays exactly as it is, and the plan's excluded list names any handoff change as a separate 2.2.0 candidate.

## Complexity Tracking

Nothing to track. No new abstraction, dependency, indirection or file is introduced. The one place complexity could have crept in — inventing a bespoke verification harness — was avoided by extending the check the project already uses rather than replacing it (research R2).

## Phase 0 — Research

See [research.md](./research.md). Four questions:

- **R1** — how to rewrite the heading so the content beneath it is provably unchanged.
- **R2** — the shape of the one-command agreement check, and why the seed's named command is insufficient alone.
- **R3** — test debt: none, and why that is a ruling rather than a deferral.
- **R4** — what the diff must look like, and how "nothing else moved" is proven rather than asserted.

## Phase 1 — Design & Contracts

**Contract**: [contracts/version-contract.md](./contracts/version-contract.md) pins the four exact strings — two JSON values, the old heading and the new one — plus the shape pattern the new heading must satisfy and the list of what must NOT move.

**Quickstart**: [quickstart.md](./quickstart.md) is the runnable proof, in seven sections: the recorded negative control; the one-command agreement verdict; the heading shape test with its positive control AND the date checked against the pinned value; the content-identity comparison; the nothing-else-moved checks; the full suite against baseline; the diff audit; and a final verdict block that makes the script's EXIT CODE meaningful. Every documented output is measured at the time it is written, never predicted — and the document is EXECUTED rather than read before it is trusted, per the lesson P5 recorded when a `tr` command written into a quickstart turned out to be broken in a way review could not see.

**Constitution re-check after design**: unchanged — still vacuous, still recorded as vacuous.
