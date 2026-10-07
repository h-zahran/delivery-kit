# Tasks: a team plugin, set up once

**Input**: Design documents from `/specs/034-team-plugin/`

**Tests**: 17 script tests and 3 prose tests. The full suite grows from `1..294` to `1..314`.

- [X] T001 Write `team/scripts/team.sh`: `config`, `roster`, `tasks`.
- [X] T002 Write `team/tests/team.bats`. The case loops read on fd 4 and count their cases.
- [X] T003 Add `team/.claude-plugin/plugin.json`. Run "every plugin directory owns a non-empty shipped-surface list": red, `SHIPPED_TEAM is empty or missing`. Add `SHIPPED_TEAM`.
- [X] T004 Register the plugin: marketplace, root README, root changelog index, CI, contributing guide, `.delivery-kit.json`.
- [X] T005 Write `team/skills/setup/SKILL.md`, `team/README.md`, `team/CHANGELOG.md`, `team/docs/configuration.md`.
- [X] T006 Write `team/tests/prose.bats`.
- [X] T007 Fix the two-plugin version fixture in `tests/portability.bats`: it copied two plugin directories and the whole marketplace, so a third entry named a directory the copy did not hold.
- [X] T008 Run the 47 mutations in `quickstart.md`. Each must land, then go red.
- [X] T009 Run the full suite with the new files marked intent-to-add.
- [ ] T010 Shell analysis: run by CI's `shell-analysis` job. Not run locally.
