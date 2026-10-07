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

## 3. Record

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | `1..330`, all `ok` (was `1..314`) | 61 of 61 landed and went red |
