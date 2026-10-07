# Implementation Plan: a member starts the next task, and anyone sees where the work stands

**Branch**: `035-team-start` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

## Summary

`team:start` and `team:status`, two skills. `team.sh` gains seven commands: `suggest`, `iam`, `whoami`, `status`, `next`, `command`, `render`. The `progress` key is removed; the task file gains `blocked` and a one-line seed rule.

## Constitution Check

| Principle | Status |
|---|---|
| I. Silence is the failure that matters | Pass. A source not read is reported as not read. `elsewhere` is reported, never restarted. |
| II. Measure; never assert | Pass. 13 new script tests on scratch repositories with a bare `origin` and a fake `gh`; 3 new prose tests. |
| III. A gate must be shown able to go red | Pass. See `quickstart.md`. |
| IV. One implementation, many callers | Pass. Status is derived in `team.sh status`; `next` and `render` read it. The pipeline keeps its own checks. |
| V. Derive coverage; never enumerate it | Pass. Status is derived each time, never listed by hand. |

## Files

| File | Change |
|---|---|
| `team/scripts/team.sh` | Seven commands; `progress` removed; `blocked` and the one-line seed |
| `team/skills/start/SKILL.md`, `team/skills/status/SKILL.md` | New |
| `team/skills/setup/SKILL.md` | No `progress` question |
| `team/docs/configuration.md`, `team/README.md`, `team/CHANGELOG.md` | Updated |
| `team/tests/team.bats`, `team/tests/prose.bats` | 13 and 3 new tests; old tests updated |
| `specs/034-team-plugin/spec.md` | One line: the Phase 35 change |
| `main-plan.md` | Phase 35 |
