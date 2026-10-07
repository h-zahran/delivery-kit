# Implementation Plan: the feature branch and the spec folder can be named for one run

**Branch**: `041-branch-and-spec-dir-flags` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

## Summary

Two orchestrator flags (`--branch <name>`, `--spec-dir <path>`) and two pre-flight arguments (`--feature-branch <name>`, `--spec-dir <path>`). Pre-flight checks both and reports them as `featureBranch` and `specDir`. Phase B hands the folder to the spec tool as `SPECIFY_FEATURE_DIRECTORY`, checks the spec landed there, takes the run's name from the folder's last segment, and cuts the branch under the typed name. No configuration key. Five documentation sites, one changelog entry under the existing `[Unreleased]`, eight pre-flight tests and one prose test.

## Technical Context

**Language/Version**: Bash (`pipeline/scripts/preflight.sh`), Markdown

**Primary Dependencies**: git (`check-ref-format`), jq — both already required

**Testing**: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests` from the repository root

**Target Platform**: the CI matrix ubuntu/macos/windows

**Project Type**: pipeline plugin — script, prose, docs, changelog

**Constraints**: without the flags nothing changes; `pipeline/docs/configuration.md`, `pipeline/CHANGELOG.md`, `pipeline/README.md` and `README.md` are STRICT vocabulary surfaces; `handoff/**` and `progress.sh` untouched; no plugin version bump.

## Constitution Check

| Principle | Status |
|---|---|
| I. Silence is the failure that matters | Pass. Each bad value stops pre-flight by name. A spec written elsewhere stops B. A resume never switches names silently. |
| II. Measure; never assert | Pass. The spec tool's support for `SPECIFY_FEATURE_DIRECTORY` was read in 0.15.2 and 0.16.5. The new behaviour is measured by eight new tests. |
| III. A gate must be shown able to go red | Pass. 26 mutations, each verified to land, each turning its test red (`quickstart.md`). |
| IV. One implementation, many callers | Pass. git decides branch-name legality. The run-name rule matches `progress.sh`'s `feature_ok`. |
| V. Derive coverage; never enumerate it | Not applicable. |

## Files

| File | Change |
|---|---|
| `pipeline/scripts/preflight.sh` | Two arguments, their checks, two output keys |
| `pipeline/skills/pipeline/SKILL.md` | Two Flags rows, two probe lines, the pointer list, phase B's pointer and branch-name clause |
| `pipeline/docs/configuration.md` | New section |
| `pipeline/README.md`, `README.md` | Two flag rows each |
| `pipeline/CHANGELOG.md` | `[Unreleased]` → Added, second entry |
| `pipeline/tests/preflight.bats` | Eight tests |
| `pipeline/tests/prose.bats` | One test pinning the sites |
| `main-plan.md` | Phase 41 seed |
