# Implementation Plan: every commit the run makes can carry trailers

**Branch**: `042-commit-trailers` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

## Summary

One configuration key (`commitTrailers`), one repeatable orchestrator flag that adds to it (`--trailer <token: value>`), and one repeatable pre-flight argument (`--trailer <text>`). Pre-flight checks each trailer and reports `commitTrailers`. The orchestrator records the list in the state file's `config`. One `progress.sh` helper, `with_trailers`, adds it to a copy of each commit's message, from the shared `commit_named` and from J's `--record` commit. It first used `git interpret-trailers`; after review 2 it appends the lines itself (see `spec.md`, "Changed after review 2"). The skill keeps short rows, a probe line and a pointer; the full rules are in `pipeline/docs/configuration.md`. One changelog entry under the existing `[Unreleased]`, four pre-flight tests, eight `progress-git.bats` tests and one prose test.

## Technical Context

**Language/Version**: Bash (`pipeline/scripts/preflight.sh`), Markdown

**Primary Dependencies**: git, jq — both already required

**Testing**: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests` from the repository root

**Target Platform**: the CI matrix ubuntu/macos/windows

**Project Type**: pipeline plugin — script, prose, docs, changelog

**Constraints**: without trailers nothing changes; `SKILL.md` stays under 65,536 bytes; the gate wording, `cmd_validate` and phases F.5, J, N and N.5 are not changed; `pipeline/docs/configuration.md`, `pipeline/CHANGELOG.md`, `pipeline/README.md` and `README.md` are STRICT vocabulary surfaces; `handoff/**` untouched; no plugin version bump.

## Constitution Check

| Principle | Status |
|---|---|
| I. Silence is the failure that matters | Pass. Each bad trailer stops pre-flight by name. The probe line names each trailer's layer. A resume never switches the list silently. |
| II. Measure; never assert | Pass. `interpret-trailers` was measured on a `Piece:`-ending message, a prose-ending message, a one-line subject, a `---` line, and a repeat, at git 2.43.0. |
| III. A gate must be shown able to go red | Pass. 36 mutations, each verified to land, each turning its test red (`quickstart.md`). The `progress.sh` ones run through `PROGRESS_SH_UNDER_TEST`. |
| IV. One implementation, many callers | Pass. One helper, `with_trailers`, serves every commit subcommand, and `show-message` prints what it makes. |
| V. Derive coverage; never enumerate it | Not applicable. |

## Files

| File | Change |
|---|---|
| `pipeline/scripts/preflight.sh` | `add_trailer`, the `--trailer` argument, one output key |
| `pipeline/scripts/progress.sh` | `with_trailers`, called from `commit_named` and from J's `--record` commit |
| `pipeline/tests/progress-git.bats` | Eight tests |
| `pipeline/skills/pipeline/SKILL.md` | Configuration row, Flags row, probe line, two names in the pointer list |
| `pipeline/docs/configuration.md` | JSON block, key table, new section |
| `pipeline/README.md`, `README.md` | One flag row each |
| `pipeline/CHANGELOG.md` | `[Unreleased]` → Added, third entry |
| `pipeline/tests/preflight.bats` | Four tests |
| `pipeline/tests/prose.bats` | One test |
| `main-plan.md` | Phase 42 seed |
