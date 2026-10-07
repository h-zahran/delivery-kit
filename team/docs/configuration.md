# Configuration — the `team` plugin

The plugin reads three things: the `team` block in the repository's
`.delivery-kit.json`, a roster file for each team, and a task file for each
member. Your project writes the roster and the task files. `team:setup`
writes the block.

The block lives in the repository's `.delivery-kit.json` only. It describes
the repository, so `~/.delivery-kit.json` is never read for it.

## The `team` block

```json
{
  "team": {
    "teams": {
      "alpha": {
        "roster": "plan/alpha/roster.json",
        "tasks": "plan/alpha/{member}/tasks.json",
        "progressView": "plan/alpha/{member}/progress.md"
      }
    }
  }
}
```

| Key | Required | Meaning |
|---|---|---|
| `teams` | yes | One entry per team. The key is the team's name: letters, digits, dot, dash and underscore only. |
| `roster` | yes | The team's roster file. One file for the whole team, so it holds no `{member}`. |
| `tasks` | yes | Each member's task file. Holds `{member}`, which is replaced with the member's id. |
| `progressView` | no | Each member's readable progress page, written by `team:status` when asked. Holds `{member}`. |

There is no key for a stored status. Status is read from git and the pull
requests each time; see "Status" below.

Every path is relative to the repository root, uses `/` between folders,
has no `..`, `.` or empty segment, and is not under `.delivery-kit/`. Any
other key in a team entry is refused by name, so a misspelt key is never
silently ignored.

## The roster file

```json
{ "members": [
  { "id": "ann", "name": "Ann Example", "emails": ["ann@example.com"] }
] }
```

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | Replaces `{member}` in the paths. Letters, digits, dot, dash and underscore only. Unique in the roster. |
| `name` | yes | The member's name, as shown to people. |
| `emails` | no | The member's git commit emails. Used only to suggest who is at the keyboard; never to decide it. |

## The task file

```json
{ "tasks": [
  { "id": "T-1", "number": "001", "title": "First task",
    "branch": "ann/alpha/001-T-1-first-task",
    "specDir": "specs/alpha/ann/001-T-1-first-task",
    "seed": "The text the pipeline specifies from.",
    "trailers": ["Plan-Item: T-1"],
    "flags": ["--implementer", "claude"] }
] }
```

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | The task's id. Unique in the file. |
| `branch` | yes | Passed to the pipeline as `--branch`. |
| `specDir` | yes | Passed to the pipeline as `--spec-dir`. |
| `seed` | yes | The feature description the pipeline specifies from. One line. |
| `trailers` | no | Each one passed to the pipeline as `--trailer`. |
| `flags` | no | More pipeline flags for this task, passed as written. |
| `number` | no | The task's number, as shown to people. |
| `title` | no | The task's title, as shown to people. |
| `blocked` | no | A note saying why the task cannot go on. A task with a note is blocked until it is in review or done. |

The order of the list is the order the tasks are worked. A task the pipeline
does not run, such as a machine setup, is not in this file.

`scripts/team.sh` checks the shape: each required field is there, each field
has the right type, and no id appears twice. It does not check what a value
means. The pipeline's pre-flight checks the branch name, the spec folder and
each trailer, so those rules live in one place.

## Who is at the keyboard

`team:start` asks each member once for their team and id, and keeps the
answer in `.delivery-kit/team.json`. That file is per clone and must be
ignored by git: `team.sh iam` refuses to write it otherwise. The roster's
`emails` only suggest the answer.

## Status

Status is never stored. Each time, `team.sh status <team> <member>` reads
these facts for every task, and the first that answers wins:

| Fact | Status | `source` |
|---|---|---|
| A merged pull request for the task's branch | done | `pull request` |
| An open pull request for the task's branch | in review | `pull request` |
| The pipeline's run on this machine recorded a pull request | in review | `run state` |
| The task file has a `blocked` note | blocked | `task file` |
| The pipeline's run on this machine exists | in progress | `run state` |
| The branch exists on this machine | in progress | `local branch` |
| The branch exists on `origin` | in progress | `origin branch` |
| None | not started | |

The run is found at `.delivery-kit/runs/<last segment of specDir>/`, the
name the pipeline gives it. `origin` is read with `git ls-remote`, never
fetched. Pull requests are read with `gh`, probed as `gh`, `gh.exe` and
`gh.cmd`. The output says `originRead` and `prRead`: a source that could
not be read is reported as not read, never taken as "no". Without `gh`, a
merged task never shows as done.

## The commands

| Command | Prints |
|---|---|
| `team.sh config` | the team block |
| `team.sh roster <team>` | the members |
| `team.sh tasks <team> <member>` | the member's tasks, defaults filled |
| `team.sh suggest <team>` | git's email and the roster ids it matches |
| `team.sh iam <team> <member>` | the answer, after writing `.delivery-kit/team.json` |
| `team.sh whoami` | the answer, checked against today's roster |
| `team.sh status <team> <member>` | each task with its status, its source, and what was not read |
| `team.sh next <team> <member>` | `start`, `resume`, `elsewhere` or `none`, with the task |
| `team.sh command <team> <member> <id>` | the `/pipeline` line for the task |
| `team.sh render <team> <member>` | the path of the progress page it wrote |

`--dir <repo>` first runs any of them against another directory. Each one
exits 0 with its answer on stdout, or 1 with one `team.sh:` line on
stderr naming the fault.
