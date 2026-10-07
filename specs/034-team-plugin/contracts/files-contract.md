# Contract: the team plugin's inputs

The formats are in `team/docs/configuration.md`. This file records the commands.

| Command | Reads | Prints |
|---|---|---|
| `team.sh config` | `.delivery-kit.json` | `{"teams": {...}}` |
| `team.sh roster <team>` | the block, the roster | `[{id, name, emails}]` |
| `team.sh tasks <team> <member>` | the block, the roster, the member's task file | `[{id, number, title, branch, specDir, seed, trailers, flags}]` |

`--dir <repo>` first runs any of them against another directory. Exit 0 with JSON on stdout, or exit 1 with one `team.sh: <fault>` line on stderr.
