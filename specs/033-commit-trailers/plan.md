# Implementation Plan: every commit the run makes can carry trailers

**Branch**: `033-commit-trailers` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

## Summary

One configuration key (`commitTrailers`), one repeatable orchestrator flag that adds to it (`--trailer <token: value>`), and one repeatable pre-flight argument (`--trailer <text>`). Pre-flight checks each trailer and reports `commitTrailers`. The orchestrator adds the trailers to each commit's message file with `git interpret-trailers --in-place --if-exists addIfDifferent` before any gate shows it. Five documentation sites, one changelog entry under the existing `[Unreleased]`, four pre-flight tests and one prose test.

## Technical Context

**Language/Version**: Bash (`pipeline/scripts/preflight.sh`), Markdown

**Primary Dependencies**: git (`interpret-trailers`), jq — both already required

**Testing**: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests` from the repository root

**Target Platform**: the CI matrix ubuntu/macos/windows

**Project Type**: pipeline plugin — script, prose, docs, changelog

**Constraints**: without trailers nothing changes; the six commit sites' pinned text is unchanged; `pipeline/docs/configuration.md`, `pipeline/CHANGELOG.md`, `pipeline/README.md` and `README.md` are STRICT vocabulary surfaces; `handoff/**` and `progress.sh` untouched; no plugin version bump.

## Constitution Check

| Principle | Status |
|---|---|
| I. Silence is the failure that matters | Pass. Each bad trailer stops pre-flight by name. The probe line names each trailer's layer. A resume never switches the list silently. |
| II. Measure; never assert | Pass. `interpret-trailers` was measured on a `Piece:`-ending message, a prose-ending message, and a repeat, at git 2.43.0. |
| III. A gate must be shown able to go red | Pass. 20 mutations, each verified to land, each turning its test red (`quickstart.md`). |
| IV. One implementation, many callers | Pass. One **Trailers:** paragraph serves all six commit sites. git places the trailers. |
| V. Derive coverage; never enumerate it | Not applicable. |

## Files

| File | Change |
|---|---|
| `pipeline/scripts/preflight.sh` | `add_trailer`, the `--trailer` argument, one output key |
| `pipeline/skills/pipeline/SKILL.md` | Configuration row, Flags row, pre-flight invocation, probe line, git-absent marking, **Trailers:** paragraph |
| `pipeline/docs/configuration.md` | JSON block, key table, new section |
| `pipeline/README.md`, `README.md` | One flag row each |
| `pipeline/CHANGELOG.md` | `[Unreleased]` → Added, third entry |
| `pipeline/tests/preflight.bats` | Four tests |
| `pipeline/tests/prose.bats` | One test; the Phase 32 test's slice now ends at **Trailers:** |
| `main-plan.md` | Phase 33 seed |
