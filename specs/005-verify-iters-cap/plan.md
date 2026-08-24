# Implementation Plan: a cap for the J loop

**Branch**: `005-verify-iters-cap` | **Date**: 2026-08-24 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/005-verify-iters-cap/spec.md`

## Summary

One new configuration key, `maxVerifyIters` (default 5), bounding the
verification phase's fix loop — the only unbounded loop left in the product.
Four documentation sites plus a changelog entry, exactly as the two preceding
phases shaped their keys. Prose only: no script changes, no test changes, suite
stays `1..121` / `1..11`.

The one substantive addition beyond the seed comes from the owner's clarify
answer: a J cap breach the owner waves through must RECORD the surviving
failures — into the run's state file, the commit message and the pull-request
body. J is the last full-suite check before code leaves the machine, so this is
the one place a cap deliberately differs from its siblings.

## Technical Context

**Language/Version**: Markdown prose — the orchestrator is a document a model
executes. There is no compiler and no runtime; a defect here is a false or
unfollowable sentence.
**Primary Dependencies**: none new.
**Testing**: `bash /c/Users/h_zah/bats/bin/bats --tap pipeline/tests/prose.bats`
(stays `1..11`); full house suite from the repository root (stays `1..121`);
row identity by extract-and-diff (quickstart §2).
**Target Platform**: the Claude Code plugin cache.
**Project Type**: other.
**Performance Goals**: not applicable.
**Constraints**: add near, never reword — EXCEPT where this change makes an
existing sentence false, which it does exactly once and which the seed itself
mandates (see R2); `pipeline/docs/configuration.md` and `pipeline/CHANGELOG.md`
are STRICT vocabulary surfaces; suite growth exactly zero; `handoff/**`
untouched; key rows character-identical across the two files.
**Scale/Scope**: three files — `pipeline/skills/pipeline/SKILL.md`,
`pipeline/docs/configuration.md`, `pipeline/CHANGELOG.md`.

## Constitution Check

The project constitution is the unfilled template — the owner declined the
pre-flight offer for the second run running, recorded in the state file's
`gates.constitution`. The plan gate therefore runs against an empty document
and imposes no principles. Stated rather than passed over silently: an empty
constitution is not a satisfied constitution.

## Project Structure

### Documentation (this feature)

```
specs/005-verify-iters-cap/
├── spec.md
├── plan.md              # this file
├── research.md          # R1-R4
├── quickstart.md        # the verification recipe
├── contracts/
│   └── key-contract.md  # the exact strings, pinned
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```
pipeline/
├── skills/pipeline/SKILL.md    # Configuration table row + the J paragraph
├── docs/configuration.md       # JSON block entry + key table row
└── CHANGELOG.md                # one Added entry under [Unreleased]
```

**Structure Decision**: three files, the same three the preceding two phases
touched. `pipeline/README.md` became a fifth documentation site last phase for
a key that removes a consent stop; `maxVerifyIters` removes nothing and adds a
stop, so the front door does not need it. Recorded so the asymmetry is a
decision rather than an oversight.

## Complexity Tracking

No constitution principles to violate, and nothing here warrants a complexity
entry: one key, one default, one reworded sentence the seed itself specifies.

The honest risk is not complexity but repetition. Four review rounds last phase
found the same failure shape over and over: a sentence true in the case its
author pictured and false in one they dropped. The matrix for THIS feature is
small — {cap not reached, cap reached and waved through, cap reached and
declined, hard failure} × {`--auto`, no `--auto`} — and every sentence written
here is checked against all eight cells before it is recorded as done.
