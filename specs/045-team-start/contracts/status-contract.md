# Contract: status, next and the pipeline line

## `team.sh status <team> <member>`

```json
{ "team": "alpha", "member": "ann", "originRead": true, "prRead": false,
  "tasks": [ { "id": "T-1", "...task fields...": "",
               "status": "in review", "source": "run state", "pr": "https://...",
               "run": true, "phase": "M", "runEnd": "live", "localBranch": false, "originBranch": false, "prClosed": false } ] }
```

`runEnd` is `live`, `abandoned` or `done` by `RUN_END_JQ` in `pipeline/scripts/progress.sh`, or empty with no run.

Order, first that answers wins: merged PR → `done`; open PR → `in review`; run abandoned → `abandoned`; run with `pr_url`, its pull request not closed → `in review`; `blocked` note → `blocked`; run at `DONE` → `finished`; run → `in progress`; local branch → `in progress`; `origin` branch → `in progress`; else `not started`.

## `team.sh next <team> <member>`

A task in progress comes before a new one. In order, the first that fits:

| Task | `action` |
|---|---|
| the first `in progress` with its run on this machine | `resume` |
| the first `in progress`, no run here | `elsewhere` |
| the first `not started`, in file order | `start` |
| none | `none`, `task: null` |

Every answer also carries `originRead` and `prRead`.

`abandoned` and `finished` are passed over.

## `team.sh mine`

```json
{ "originRead": true, "prRead": false,
  "teams": [ { "team": "alpha", "member": "ann", "next": { "action": "start", "task": { } },
               "suggested": [], "left": null, "error": null },
             { "team": "beta", "member": null, "next": null,
               "suggested": ["a2"], "left": null, "error": null } ] }
```

One row per team in the settings, in key order. `member` is the saved answer when today's roster holds it, and then `next` is `team.sh next` for it. Otherwise `member` and `next` are null, `suggested` holds the roster ids git's email matches, and `left` names a saved id the roster no longer holds. `error` is the one `team.sh:` line of a team whose files could not be read, without the prefix.

## `.delivery-kit/team.json`

```json
{ "members": { "alpha": "ann", "beta": "a2" } }
```

## `team.sh command <team> <member> <id>`

```
/pipeline "<seed>" --branch <branch> --spec-dir <specDir> [--trailer <t>]... [<flag>]...
```

The seed is always double-quoted. Any other value with a character outside `[A-Za-z0-9._/:@=+,-]` is double-quoted. Inside quotes, `"` and `\` are escaped with `\`.
