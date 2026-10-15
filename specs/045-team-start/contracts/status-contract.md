# Contract: status, next and the pipeline line

## `team.sh status <team> <member>`

```json
{ "team": "alpha", "member": "ann", "originRead": true, "prRead": false,
  "tasks": [ { "id": "T-1", "...task fields...": "",
               "status": "in review", "source": "run state", "pr": "https://...",
               "run": true, "phase": "M", "runEnd": "live",
               "runFile": ".delivery-kit/runs/001-T-1/progress.json", "localBranch": false, "originBranch": false, "prClosed": false } ] }
```

`runEnd` is `live`, `abandoned` or `done` by `RUN_END_JQ` in `pipeline/scripts/progress.sh`, or empty with no run. It is `unreadable` when the state file is not one JSON object with a string `current_phase`, the rule the pipeline's pre-flight applies. `runFile` is the run's state file, `.delivery-kit/runs/<last segment of specDir>/progress.json`, or empty with no run.

Order, first that answers wins: merged PR → `done`; open PR → `in review`; run unreadable → `unreadable`; run abandoned → `abandoned`; run with `pr_url`, its pull request not closed → `in review`; `blocked` note → `blocked`; run at `DONE` → `finished`; run → `in progress`; local branch → `in progress`; `origin` branch → `in progress`; else `not started`.

## `team.sh next <team> <member>`

A task in progress comes before a new one. In order, the first that fits:

| Task | `action` |
|---|---|
| the first whose run is live on this machine (`runEnd` is `live`), whatever its status | `resume` |
| the first `unreadable` | `unreadable` |
| the first `in progress`, no run here | `elsewhere` |
| the first `not started`, in file order | `start` |
| none | `none`, `task: null` |

Every answer also carries `originRead` and `prRead`.

`abandoned` and `finished` are passed over. A task `in review` or `done` is passed over unless its run is still live here: the pipeline runs phases after the pull request opens.

## `team.sh mine`

```json
{ "originRead": true, "prRead": false,
  "teams": [ { "team": "alpha", "member": "ann", "next": { "action": "start", "task": { } },
               "suggested": [], "left": null, "error": null },
             { "team": "beta", "member": null, "next": null,
               "suggested": ["a2"], "left": null, "error": null } ] }
```

One row per team in the settings, in key order. `member` is the saved answer when today's roster holds it, and then `next` is `team.sh next` for it. Otherwise `member` and `next` are null, `suggested` holds the roster ids git's email matches, and `left` names a saved id the roster no longer holds. `error` is the one `team.sh:` line of a team whose files could not be read, without the prefix. `origin` and the pull requests are read once for all teams, so each `next`'s `originRead` and `prRead` equal the top level's.

## `.delivery-kit/team.json`

```json
{ "members": { "alpha": "ann", "beta": "a2" } }
```

## `team.sh command <team> <member> <id>`

```
/pipeline "<seed>" --branch <branch> --spec-dir <specDir> [--trailer <t>]... [<flag>]...
```

The seed is always double-quoted. Any other value with a character outside `[A-Za-z0-9._/:@=+,-]` is double-quoted, judged on the whole value. Inside quotes, `"` and `\` are escaped with `\`. No value holds a line break: `tasks` refuses one first, so the line is always one line.
