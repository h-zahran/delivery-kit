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
        "progress": "plan/alpha/{member}/progress.json",
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
| `progress` | yes | Each member's progress record. Holds `{member}`. |
| `progressView` | no | A readable copy of the progress. Holds `{member}`. |

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
| `seed` | yes | The feature description the pipeline specifies from. |
| `trailers` | no | Each one passed to the pipeline as `--trailer`. |
| `flags` | no | More pipeline flags for this task, passed as written. |
| `number` | no | The task's number, as shown to people. |
| `title` | no | The task's title, as shown to people. |

The order of the list is the order the tasks are worked. A task the pipeline
does not run, such as a machine setup, is not in this file.

`scripts/team.sh` checks the shape: each required field is there, each field
has the right type, and no id appears twice. It does not check what a value
means. The pipeline's pre-flight checks the branch name, the spec folder and
each trailer, so those rules live in one place.
