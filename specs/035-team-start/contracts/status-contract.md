# Contract: status, next and the pipeline line

## `team.sh status <team> <member>`

```json
{ "team": "alpha", "member": "ann", "originRead": true, "prRead": false,
  "tasks": [ { "id": "T-1", "...task fields...": "",
               "status": "in review", "source": "run state", "pr": "https://...",
               "run": true, "phase": "M", "localBranch": false, "originBranch": false, "prClosed": false } ] }
```

Order, first that answers wins: merged PR → `done`; open PR → `in review`; run with `pr_url` → `in review`; `blocked` note → `blocked`; run → `in progress`; local branch → `in progress`; `origin` branch → `in progress`; else `not started`.

## `team.sh next <team> <member>`

The first task, in file order, that is `in progress` or `not started`:

| Task | `action` |
|---|---|
| `not started` | `start` |
| `in progress`, run on this machine | `resume` |
| `in progress`, no run here | `elsewhere` |
| none | `none`, `task: null` |

## `team.sh command <team> <member> <id>`

```
/pipeline "<seed>" --branch <branch> --spec-dir <specDir> [--trailer <t>]... [<flag>]...
```

The seed is always double-quoted. Any other value with a character outside `[A-Za-z0-9._/:@=+,-]` is double-quoted. Inside quotes, `"` and `\` are escaped with `\`.
