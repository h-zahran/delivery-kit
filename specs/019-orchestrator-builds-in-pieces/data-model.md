# Data model: the orchestrator builds in pieces

The feature changes prose, not a program. The "data" is what the new prose
tells the orchestrator to write into the run state file,
`.delivery-kit/runs/<feature>/progress.json`. Every key below is written
whole-file with `jq` and checked with `progress.sh validate` straight after,
per the orchestrator's ground rules, except `commits`, which only
`progress.sh commit-add` writes (spec 018).

| Key | Written by | Shape | Rules |
|---|---|---|---|
| `gates.G` | G | object `{ "answer": "claude" \| "handoff", "reviewMode"?: … }` | New runs write an object. 8 of 18 real state files (runs 001–006, 013, 014) hold a plain string here; `jq '.gates.G.reviewMode'` fails on those with "Cannot index string" (measured at F round 2), so read with `.gates.G \| if type == "object" then .reviewMode else null end`. A string is the implementer answer alone, with no review answer. |
| `gates.G.reviewMode` | G | `"commits"` or `"pauses"` | Written once, when the implementer answer is `claude`. Never re-asked on a re-entry that finds it. Absent on the handoff path and on a state file from an older pipeline. |
| `measurements.pieceBefore` | H, at each piece start | `{ "piece": <heading>, "paths": [<path>, …] }` | Written when a new piece starts; kept, not rewritten, when it already names the piece being resumed. `piece` is `piece-next`'s first line, byte for byte. `paths` is every path `git status --porcelain=v1 -z --untracked-files=all --no-renames` listed at that moment. Read back on resume when its `piece` equals the piece `piece-next` names. |
| `gates.H.pauses` | H, pause mode | array of `{ "piece", "answer", "note"?, "shown": { <path>: <blob id or "deleted"> } }` | One entry per answer given at a pause: `go on`, `fix this` (with the developer's `note`), `stop here`. `shown` is each listed path's `git hash-object` as the pause showed it, so an owner edit is measurable after a resume. |
| (path list file) | H, before each commit | `.delivery-kit/runs/<feature>/piece-paths.nul` | The piece's paths, NUL-separated, read by `git --literal-pathspecs add` and `commit` with `--pathspec-from-file=<file> --pathspec-file-nul`, so no path is typed into a command or read as a pattern. |
| (message file) | H, before each commit | `.delivery-kit/runs/<feature>/commit-msg.txt` | Its `Piece:` line is written with `printf '%s'` in the same shell call that commits and records (H10); used by `git commit -F`, inside the ignored run directory so it is never swept into a commit. |
| `gates.H.failure` | H, on a hook rejection | `{ "piece", "reason", "output" }` | `output` is the hook's output, redacted: a credential, endpoint or token is replaced by the fact and its location. Present while the piece is uncommitted; cleared once its commit lands. |
| `commits[]` | `progress.sh commit-add` | spec 018 entry: `sha`, `kind`, `piece`, `tasks`, `files` | Kind `spec` once (piece and tasks empty); kind `piece` once per piece. The sha is the full 40-character id from `git rev-parse HEAD`. |
| `last_task` | H | string | Unchanged meaning: the last completed task, so resume re-enters mid-piece. |

## States of a piece

```text
not started ──build──▶ building ──all tasks [X]──▶ built ──commit──▶ committed ──commit-add──▶ recorded
                          ▲                          │  │                    │
                          └──── fix this (pause) ◀───┘  └─ stop here / hook ─┘ (parked: still built, uncommitted)
```

- **recorded**: `commits` holds a `piece` entry whose `piece` equals the
  heading. `piece-next` skips it. Never rebuilt.
- **committed, not recorded**: a crash between `git commit` and `commit-add`.
  Found by the `Piece: <heading>` line on an unrecorded branch commit
  (research R7); recorded from that commit; never rebuilt.
- **built**: every task ID on `piece-next`'s second line is `[X]` in
  `tasks.md`. On resume it is shown (pause mode) or committed (commits mode),
  never rebuilt.
- **building**: some of its tasks are `[X]`; H continues from `last_task`.
