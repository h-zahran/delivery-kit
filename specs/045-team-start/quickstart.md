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
| 2–4 | `team/scripts/team.sh` | the one-line seed check; the `blocked` type check; the `blocked` default | tasks: a task file with a field of the wrong type or a repeated id; tasks are printed in file order |
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
| 68 | `team/scripts/team.sh` | `mine` drops a `next` fault | mine: a team whose task file cannot be read names the fault, and does not hide the others |
| 69 | `team/scripts/team.sh` | `abandoned` not read | status: an abandoned run and a finished run without a pull request are ended |
| 70 | `team/scripts/team.sh` | `finished` not read | status: an abandoned run and a finished run without a pull request are ended |
| 71 | `team/scripts/team.sh` | the copied rule differs from `RUN_END_JQ` | status: how a run ended agrees with the pipeline's own progress.sh |
| 72 | `team/scripts/team.sh` | `run_self` as a function call, where errexit is off | none since 2026-10-15: every read in `next` and `status` now ends in `|| exit 1`, so the in-process call (`run_self() { local c="$1"; shift; "cmd_$c" "$@"; }`) changes no output. Probed on all six `mine` tests and on the combined test they were split from, with the timeout raised: all `ok` |
| 73 | `team/scripts/team.sh` | no refusal after the JSON read in `read_me` | a broken identity file is refused by every reader |
| 74 | `team/scripts/team.sh` | no `\|\| exit 1` after `cmd_tasks` in `cmd_status` | render: a task file that cannot be read writes no page |
| 75 | `team/scripts/team.sh` | an empty file read as JSON | a broken identity file is refused by every reader |
| 76 | `team/scripts/team.sh` | a team key may start with a dot | a member id or a team key that starts with a dot is refused |
| 77 | `team/scripts/team.sh` | a member id may start with a dot | a member id or a team key that starts with a dot is refused |
| 78 | `team/scripts/team.sh` | `render` takes a member not in the roster | render: a member not in the roster is refused before any path is built |
| 79 | `team/scripts/team.sh` | a closed pull request recorded by the run reads `in review` | status: a closed pull request is not in review |
| 80 | `team/scripts/team.sh` | `abandoned` read after the recorded pull request | status: a closed pull request is not in review; status: an abandoned run and a finished run |
| 81 | `team/scripts/team.sh` | `resume` not first | next: a run on this machine is resumed before anything new starts |
| 82 | `team/scripts/team.sh` | `next` without `originRead` and `prRead` | next: says what it could not read |
| 83 | `team/scripts/team.sh` | `iam` opens the file before building it | none: `read_me` stops first on a broken file, so this second guard is not reached |
| 84 | `team/scripts/team.sh` | no EXIT trap for the temporary file | none: the normal path removes it, and no early exit was found |
| 85 | `team/tests/team.bats` | the suite run with a global `commit.gpgsign=true`, `GH_REPO` set and a logging `gh` on `PATH` | none failed, and the logging `gh` was never called |
| 86 | `team/scripts/team.sh` | an origin branch matched as a substring of the list | status: a branch on origin is found among thousands, the task's first, and only by its whole name |
| 87 | `team/scripts/team.sh` | a state file that is not one object with a string phase read as `live` | status: a run state file that cannot be read is unreadable, never a live run |
| 88 | `team/scripts/team.sh` | a state file jq cannot parse read as `live` | status: a run state file that cannot be read is unreadable, never a live run |
| 89 | `team/scripts/team.sh` | the `unreadable` status never chosen | status: a run state file that cannot be read is unreadable, never a live run |
| 90 | `team/scripts/team.sh` | `next` without the `unreadable` action | status: a run state file that cannot be read is unreadable, never a live run |
| 91 | `team/scripts/team.sh` | `render` reads the status through a herestring | render finishes on a status of the size where a Git Bash herestring hangs (a timeout: the process hung until killed) |
| 92 | `team/scripts/team.sh` | `status` reads the task list through a herestring | status finishes on a task list of the size where a Git Bash herestring hangs (a timeout: the process hung until killed) |
| 93 | `team/scripts/team.sh` | `resume` only for a task `in progress` | next: a run still live after its pull request opened is resumed |
| 94 | `team/scripts/team.sh` | `mine` does not name its gathered folder | mine: origin and the pull requests are read once for every team |
| 95 | `team/scripts/team.sh` | no http time limit on `ls-remote` | status: ls-remote has a time limit |
| 96 | `team/scripts/team.sh` | no ssh options on `ls-remote` | status: ls-remote has a time limit |
| 97 | `team/scripts/team.sh` | ssh options added to any ssh command, plink too | status: ls-remote has a time limit |
| 98–103 | `team/skills/*/SKILL.md`, `team/docs/configuration.md` | each new pinned line in `team/tests/prose.bats` | the prose test that pins it |
| 104 | `team/scripts/team.sh` | a file whose top is not an object is read on | a settings file, a roster or a task file whose top is not an object is refused in one line |
| 105 | `team/scripts/team.sh` | a line break in `branch` passes | tasks: a line break in the branch or the spec folder; command: a value with a line break never reaches the pipeline line |
| 106 | `team/scripts/team.sh` | a line break in `specDir` passes | tasks: a line break in the branch or the spec folder |
| 107–108 | `team/scripts/team.sh` | a line break in a trailer passes; in a flag | tasks: a line break in a trailer or a flag |
| 109 | `team/scripts/team.sh` | `q` anchored with `^` and `$` again | none: `tasks` refuses every line break first, so `q` never sees one. Probed on jq 1.8.1: `"main\n"` is plain with `^…$`, not with `\A…\z` |
| 110 | `team/scripts/team.sh` | a `progressView` equal to `tasks` passes | config: a progress page that is the task file or the roster is refused |
| 111 | `team/scripts/team.sh` | a `progressView` equal to `roster` passes | config: a progress page that is the task file or the roster is refused, by its message only: the `{member}` rule still refuses that value |
| 112 | `team/scripts/team.sh` | a `.git` segment passes | config: a path with a .git segment is refused |
| 113 | `team/scripts/team.sh` | `.git` compared with letter case | config: a path with a .git segment is refused |
| 114 | `team/scripts/team.sh` | `render` takes a page that is a member's task file | render: a page that would be a member's task file is refused |
| 115 | `team/scripts/team.sh` | `render` takes a page that is the roster | render: a page that would be the roster or a folder is refused |
| 116 | `team/scripts/team.sh` | `render` compares with letter case | render: a page that would be a member's task file is refused |
| 117 | `team/scripts/team.sh` | `render` takes a page path that is a folder | render: a page that would be the roster or a folder is refused |
| 118 | `team/scripts/team.sh` | the page written in place, not moved into place | none: no failure was found between opening the page and its end, and the EXIT trap removes the unused temporary file |
| 119 | `team/scripts/team.sh` | no EXIT trap in `render` | render: a task file that cannot be read writes no page |

## 3. Record

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | `1..330`, all `ok` (was `1..314`) | 61 of 61 landed and went red |
| 2026-10-13 | Linux | `tests` `1..126`, `handoff/tests` `1..158`, `pipeline/tests` `1..503`, `team/tests` `1..43`, all `ok` | 62–72: 11 landed; 10 went red, 67 is shown equivalent |
| 2026-10-13 | Linux | `team/tests` `1..51`, all `ok` | 73–84: 12 landed; 10 went red, 83 and 84 are shown equivalent; 85 passed |
| 2026-10-15 | Windows 11, Git Bash 5.3.9, jq 1.8.1 | `team/tests` `1..60`: 57 `ok`; 3 timed out at 60 s on a loaded machine (22, 23, 32), three tests not changed here, which timed out on the baseline before this change too (`1..52`, 47 `ok`) | 86–103: 18 landed, 18 went red. The old `team.sh` read the reviewer's 3,000-branch origin as "not started" in 5 of 5 runs, the new one as "in progress" in 5 of 5. |
| 2026-10-15 | Windows 11, Git Bash 5.3.9, jq 1.8.1, a second suite running beside it | `team/tests` `1..60` in five filtered runs that together name each test once: 49 `ok`, 11 `not ok`, each `timeout after 60s` and none an assertion. The same 11, with only the timeout raised in a throw-away copy, all `ok`. The baseline before these changes, `1..52`, timed out on 5 of the same tests | 104–119: 16 landed; 14 went red, 109 and 118 are shown equivalent |
| 2026-10-15 | Windows 11, Git Bash 5.3.9, jq 1.8.1, both branches joined, nothing else running | `team/tests` `1..68`: 65 `ok`, 3 timed out (the two seven-case `tasks` tests at 61-62 s, the three-step `mine` test at 83.5 s). Split into 4+3, 3+4 and three `mine` tests: the 7 run alone all `ok`, the slowest 37 s. `tests` `1..126`, all `ok` | 66 and 68 red on the split tests; 72 shown equivalent, above |
