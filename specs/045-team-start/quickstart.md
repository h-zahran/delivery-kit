# Quickstart: verify team:start and team:status

## 1. The suites

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests team/tests
bash scripts/check-versions.sh
```

## 2. The positive controls

Each mutation runs in a throw-away copy, with the new files marked intent-to-add. Each is first checked to have landed exactly once. Red means bats exited non-zero and ran at least one test.

| # | File | What is broken | Test that goes red |
|---|---|---|---|
| 1 | `team/scripts/team.sh` | `progress` is a legal key again | config: an unknown key in a team is refused |
| 2–4 | `team/scripts/team.sh` | the one-line seed check; the `blocked` type check; the `blocked` default | tasks: a malformed task file; tasks are printed in file order |
| 5 | `team/scripts/team.sh` | email match is case-sensitive | suggest: the git email is matched to the roster |
| 6–7 | `team/scripts/team.sh` | `iam` writes where git does not ignore; `iam` takes any member | iam: tests |
| 8–10 | `team/scripts/team.sh` | each `whoami` check | whoami: no answer yet, or an answer the roster no longer holds |
| 11–12 | `team/scripts/team.sh` | `origin` never read; branch names not parsed | status: each task's status comes from the run, a branch, the task file, or nothing |
| 13–15 | `team/scripts/team.sh` | pull requests never read; merged not done; open not in review | status: a pull request beats every other source |
| 16–20 | `team/scripts/team.sh` | each lower source in the order: run with a PR, blocked, run, local branch, origin branch | status tests; next: a run on this machine is resumed |
| 21 | `team/scripts/team.sh` | `prClosed` never set | status: a pull request beats every other source |
| 22–23 | `team/scripts/team.sh` | in-progress tasks skipped; `resume` never chosen | next: a run on this machine is resumed before anything new starts |
| 24–27 | `team/scripts/team.sh` | quoting off; seed not escaped; trailers dropped; flags dropped | command: the pipeline line carries the seed, the names, each trailer and the flags |
| 28–31 | `team/scripts/team.sh` | `\|` not escaped; branch shown for a task not started; no `progressView` check; the "not read" note dropped | render: tests |
| 32–61 | `team/skills/*/SKILL.md`, `team/docs/configuration.md`, `team/CHANGELOG.md` | each pinned line in `team/tests/prose.bats`, one per line, found by the runner | the prose test that pins it |
| 62 | `team/scripts/team.sh` | the first file form not read | iam: the first form of the file is read as one answer and rewritten |
| 63 | `team/scripts/team.sh` | answers not checked to be strings | whoami: no answer yet, or a file that holds no answers |
| 64 | `team/scripts/team.sh` | `iam` drops the other teams | iam: one answer per team, and a second team keeps the first |
| 65 | `team/scripts/team.sh` | `whoami` takes an id the roster no longer holds | whoami: an answer the settings or the roster no longer hold is listed as stale |
| 66 | `team/scripts/team.sh` | `mine` uses an id that left the team | mine: a member who left is asked again |
| 67 | `team/scripts/team.sh` | `mine` drops a roster fault | none: `suggest` reads the same roster next and reports the same fault, so the output does not change |
| 68 | `team/scripts/team.sh` | `mine` drops a `next` fault | mine: a member who left is asked again, and a team that cannot be read does not hide the others |
| 69 | `team/scripts/team.sh` | `abandoned` not read | status: an abandoned run and a finished run without a pull request are ended |
| 70 | `team/scripts/team.sh` | `finished` not read | status: an abandoned run and a finished run without a pull request are ended |
| 71 | `team/scripts/team.sh` | the copied rule differs from `RUN_END_JQ` | status: how a run ended agrees with the pipeline's own progress.sh |
| 72 | `team/scripts/team.sh` | `run_self` as a function call, where errexit is off | mine: a member who left is asked again, and a team that cannot be read does not hide the others |

## 3. Record

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | `1..330`, all `ok` (was `1..314`) | 61 of 61 landed and went red |
| 2026-10-13 | Linux | `tests` `1..126`, `handoff/tests` `1..158`, `pipeline/tests` `1..503`, `team/tests` `1..43`, all `ok` | 62–72: 11 landed; 10 went red, 67 is shown equivalent |
