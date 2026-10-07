# Implementation Plan: a resume shows the branch and the folder it recorded

**Branch**: `043-resume-shows-branch-and-folder` | **Date**: 2026-10-07, widened 2026-10-08 | **Spec**: [spec.md](spec.md)

## Summary

On a resume, pre-flight gets no `--feature-branch`, `--spec-dir` or `--trailer`, so its report holds none of them. The orchestrator prints the Branch, Spec folder and Trailers lines from the record instead, each marked as recorded. The rule lives in `pipeline/docs/configuration.md`. After review 2, `SKILL.md` reaches it on a plain `--resume` too: the pointer fires when a resumed run's state file records one of the names, and the probe block prints those lines "only when set or recorded".

## Technical Context

**Language/Version**: Markdown

**Primary Dependencies**: none

**Testing**: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests` from the repository root

**Target Platform**: the CI matrix ubuntu/macos/windows

**Project Type**: pipeline plugin — prose, docs, changelog

**Constraints**: `SKILL.md` stays under 65,536 bytes; the gate wording, `cmd_validate` and phases F.5, J, N and N.5 are not changed; `pipeline/docs/configuration.md` and `pipeline/CHANGELOG.md` are STRICT vocabulary surfaces; `handoff/**` untouched; no plugin version bump.

## Constitution Check

| Principle | Status |
|---|---|
| I. Silence is the failure that matters | Pass. A resumed run prints the names it works under; nothing it recorded is left off the screen. |
| II. Measure; never assert | Pass. The gap was found by reading the route a plain `--resume` takes through `SKILL.md` (review 2, item 3), not assumed. |
| III. A gate must be shown able to go red | Pass. Each pin has a mutation in `quickstart.md` that lands and turns it red. |
| IV. One implementation, many callers | Pass. One rule in `configuration.md`; the skill only points to it. |
| V. Derive coverage; never enumerate it | Not applicable. |

## Files

| File | Change |
|---|---|
| `pipeline/docs/configuration.md` | The resume rule for the Branch and Spec folder lines; the folder is the one that holds the `spec.md` named by `artifacts.spec`; the Base branch line prints the recorded base |
| `pipeline/skills/pipeline/SKILL.md` | The pointer adds "or a resumed run's state file records one"; the probe block says "only when set or recorded" |
| `pipeline/CHANGELOG.md` | One sentence in the Phase 41 entry, under `[Unreleased]` |
| `pipeline/tests/prose.bats` | Pins in the Phase 41 test, and the pointer pinned whole in three tests |
