# Data model: the base suite run

## Bookkeeping directory `.delivery-kit/runs/<feature>/base-suite/`

| File | Written by | Holds |
|---|---|---|
| `commit` | `start` | HEAD's commit id the worktree is detached at |
| `tree` | `start` | the worktree's absolute path (under a `dk-base-suite.` temporary directory) |
| `pid` | `start` | the runner's process id (and, with `setsid` or `set -m`, its group id) |
| `started` | `start` | epoch seconds when the runner was launched |
| `heartbeat` | runner | epoch seconds of the runner's last sign of life, every 5 s |
| `child` | runner | the process id of `testCommand` |
| `suite.tap` | runner | `testCommand`'s stdout and stderr |
| `runner.log` | runner | the runner's own stderr (a refusal's reason) |
| `outcome` | runner, or `wait` at the limit | one line: `green`, `red`, `nothing recorded — <reason>`, or `stopped at the <n> s limit`; written last, by rename |
| `wait-started` | first `wait` | epoch seconds; the limit counts from it |

States, read by `wait` in this order:

1. no `pid` file → none started.
2. `outcome` present → ended (prints it).
3. `heartbeat` older than 60 s, or the pid not alive → stopped reporting;
   never signalled (its id may now belong to another process). When the pid
   is dead, the worktree `tree` names is removed if it is still there.
4. otherwise running; at the limit, stop it (see the contract).

## Suite record

Unchanged fields (see `pipeline/docs/phases.md`, "Reusing a suite run"):
`key, mode, head, tree, bytes, command, platform, verdict, plan, ok,
skipped, notOk, nonTap, rc, recordedAt, feature, tap`. A base record is
indistinguishable from any other record with the same key, by design: the
lookup judges the key and the counts, never who made it.
