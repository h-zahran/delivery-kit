# Tasks: a member starts the next task, and anyone sees where the work stands

- [X] T001 `team.sh`: remove `progress`; add `blocked`; refuse a seed with a line break.
- [X] T002 `team.sh`: `suggest`, `iam`, `whoami`.
- [X] T003 `team.sh`: `status` (one `git ls-remote`, one `gh pr list`, per-task local facts), `next`, `command`, `render`.
- [X] T004 Tests in `team/tests/team.bats`: a scratch repository with a bare `origin`, a fake `gh` first on `PATH`.
- [X] T005 `team/skills/start/SKILL.md`, `team/skills/status/SKILL.md`; `team:setup` without the `progress` question.
- [X] T006 Docs, README, changelog; prose pins.
- [X] T007 Mutations (`quickstart.md`), each landed, each red by bats' exit status.
- [X] T008 Full suite with new files marked intent-to-add.
- [ ] T009 Shell analysis: CI's `shell-analysis` job. Not run locally.
- [X] T010 `team.sh`: one answer per team in `iam`, `whoami` with `stale`, and `mine`. Each team is read in its own process (`run_self`).
- [X] T011 `team.sh`: `abandoned` and `finished` from the run's end, by the pipeline's `RUN_END_JQ`; `next` passes over both.
- [X] T012 Tests: two teams, the first file form, stale answers, `mine`, the run's end, and the agreement test with `pipeline/scripts/progress.sh`.
- [X] T013 Skills, configuration page, README, changelog, prose pins.
- [X] T014 Mutations 62–72 (`quickstart.md`); shellcheck 0.11.0 locally on the files CI analyses.
- [X] T015 Final review fixes: `|| exit 1` on every assignment from a function, empty JSON refused, ids and keys start with a letter or digit, closed pull request, `next` order and read flags, `resume` skips the clean-tree check, no prompts from git or gh, `jq -b` for writes, the temporary file cleaned, the suite isolated.
- [X] T016 Mutations 73–85 (`quickstart.md`).
