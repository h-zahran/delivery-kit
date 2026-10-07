# Implementation Plan: a team plugin, set up once

**Branch**: `034-team-plugin` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

## Summary

A third plugin, `team` 0.1.0: `team:setup` (a skill), `scripts/team.sh` (`config`, `roster`, `tasks`), a README, a configuration page and a changelog. Two suites: `team/tests/team.bats` for the script and `team/tests/prose.bats` for the rules in prose. Registration in eight places.

## Technical Context

**Language/Version**: Bash, Markdown

**Primary Dependencies**: jq

**Testing**: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests team/tests` from the repository root

**Target Platform**: the CI matrix ubuntu/macos/windows

**Constraints**: no team's words in shipped files (`tests/portability.bats`); `pipeline/**` and `handoff/**` untouched; jq read only through command substitution; bash 3.2 compatible (no `mapfile`, no `${x,,}`, no `base64 -d`). A roster or task file is read by path, never through a herestring: Git Bash hangs a herestring of about 64 KB.

## Constitution Check

| Principle | Status |
|---|---|
| I. Silence is the failure that matters | Pass. Every fault is named. An unknown key is refused, never ignored. |
| II. Measure; never assert | Pass. 17 script tests, 3 prose tests. Each case loop counts its cases. |
| III. A gate must be shown able to go red | Pass. 47 mutations (`quickstart.md`). |
| IV. One implementation, many callers | Pass. Branch, folder and trailer rules stay in the pipeline's pre-flight. |
| V. Derive coverage; never enumerate it | Pass. The registration tests find the new plugin by its manifest. |

## Files

| File | Change |
|---|---|
| `team/.claude-plugin/plugin.json` | New |
| `team/scripts/team.sh` | New |
| `team/skills/setup/SKILL.md` | New |
| `team/README.md`, `team/CHANGELOG.md`, `team/docs/configuration.md` | New |
| `team/tests/team.bats`, `team/tests/prose.bats` | New |
| `.claude-plugin/marketplace.json` | Entry and description |
| `README.md` | Opening, table row, install line, layout |
| `CHANGELOG.md` | Index line |
| `.github/workflows/ci.yml`, `CONTRIBUTING.md`, `.delivery-kit.json` | `team/tests` in the suite command; `team` in `codeRoots` |
| `tests/portability.bats` | `SHIPPED_TEAM`; the two-plugin version fixture keeps two marketplace entries |
| `main-plan.md` | Phase 34 |
