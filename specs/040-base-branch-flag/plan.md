# Implementation Plan: the base branch can be set once, or named for one run

**Branch**: `040-base-branch-flag` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

## Summary

One new configuration key (`baseBranchOverride`), one new orchestrator flag that beats it (`--base-branch <name>`), and one new pre-flight argument (`--base-branch-override <name>`) that beats `origin/HEAD`, reported as `baseBranchSource: override`, checked with `git check-ref-format --branch`. The orchestrator names the layer that set the override. The `baseBranch` key is unchanged. Five documentation sites, one changelog entry under `[Unreleased]`, three pre-flight tests and one prose test.

## Technical Context

**Language/Version**: Bash (`pipeline/scripts/preflight.sh`), Markdown

**Primary Dependencies**: git (`check-ref-format`), jq — both already required

**Testing**: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests` from the repository root

**Target Platform**: the CI matrix ubuntu/macos/windows

**Project Type**: pipeline plugin — script, prose, docs, changelog

**Constraints**: the `baseBranch` key's precedence is unchanged; `pipeline/docs/configuration.md`, `pipeline/CHANGELOG.md`, `pipeline/README.md` and `README.md` are STRICT vocabulary surfaces; `handoff/**` untouched; no plugin version bump (a release is its own commit).

## Constitution Check

| Principle | Status |
|---|---|
| I. Silence is the failure that matters | Pass. The winning source is printed as `override` with its layer; a bad name stops pre-flight by name; a resume never switches base silently. |
| II. Measure; never assert | Pass. The problem is measured by an existing test at `67db081`; the new behaviour by three new tests. |
| III. A gate must be shown able to go red | Pass. Nine mutations, each verified to land, each turning its test red (`quickstart.md`). |
| IV. One implementation, many callers | Pass. git decides branch-name legality; the rule is not restated. |
| V. Derive coverage; never enumerate it | Not applicable. No list of files or items is added. |

## Files

| File | Change |
|---|---|
| `pipeline/scripts/preflight.sh` | New argument, name check, resolution order |
| `pipeline/skills/pipeline/SKILL.md` | Configuration row, Flags row, git-absent marking, a short **Base branch:** paragraph with a pointer to the docs page; two configuration paragraphs move out, to stay under 65,536 bytes |
| `pipeline/docs/configuration.md` | JSON block, key table, Base branch section with the run's rules, "Resolving the layers" section |
| `pipeline/README.md`, `README.md` | One flag row each |
| `pipeline/CHANGELOG.md` | `[Unreleased]` → Added and Changed |
| `pipeline/tests/preflight.bats` | Three tests |
| `pipeline/tests/prose.bats` | One test pinning the sites; a size test for `SKILL.md`; the moved rules' pins point at the docs page |
| `main-plan.md` | Phase 40 seed |
