# Contract: `progress.sh suite-base`

Run from the repository's top level, like every `progress.sh` subcommand.

## `suite-base <feature> start`

Prints exactly one line on stdout and exits 0, unless a check cannot be made
(then exit 1, the reason on stderr).

| Case | Line starts with |
|---|---|
| started | `base suite started on commit <sha> (process <pid>), command "<testCommand as JSON>"` |
| already started for this run | `base suite already started on commit <sha>` |
| a green record for these base files already exists | `base suite not started: a green result is already recorded for commit <sha>` |
| `suiteReuse` is `off` or not `commit`/`files` | `base suite not started: ` + the key's reason |
| no base key (no spec file, HEAD has no commit, a submodule, …) | `base suite not started: ` + the key's reason |
| the run was abandoned | `base suite not started: the run was abandoned` |
| TMPDIR resolves inside the work tree | `base suite not started: TMPDIR lies inside the work tree, and the checkout must lie outside it` |
| the checkout's key is not these files' `--base` key | `base suite not started: the base commit's files are not these files without the spec directory, so its result could never be cited` |

It never: merges, pushes, fetches, creates or deletes a branch, changes the
main tree's HEAD, index or files, takes the repository lock, or writes the
state file. It creates one detached worktree of HEAD's commit in a new
temporary directory, and the bookkeeping directory
`.delivery-kit/runs/<feature>/base-suite/`.

## `suite-base <feature> wait [--slice <seconds>] [--limit <seconds>]`

Defaults: slice 540, limit 900. The limit counts from the first `wait` call
for the run. F.5 passes neither flag; they exist for the tests. The runner
also stops itself after 3,600 seconds.

| Exit | Meaning | Line starts with |
|---|---|---|
| 2 | still running when this call's slice ended, limit not reached | `base suite still running after <n> s of waiting` |
| 0 | ended, with the record's verdict | `base suite ended: green` / `base suite ended: red` |
| 0 | ended without a record | `base suite ended: nothing recorded — ` + reason |
| 0 | the runner was stopped by a TERM that was not the wait's (its own 3,600-second limit) | `base suite ended: stopped` |
| 0 | stopped at the limit | `base suite stopped at the <limit> s limit` |
| 0 | stopped reporting (heartbeat older than 60 s, or the pid is dead with no outcome) — never signalled; when the pid is dead, its worktree is removed | `base suite stopped reporting` |
| 0 | none was started for this run | `no base suite was started for this run` |
| 1 | a usage error or a check not made | (stderr) |

After exit 0 the caller runs `suite-lookup <feature> --base` as before; the
wait never answers whether a result may be cited.

At the limit it sends TERM to the runner's process group (and the runner's
own id where no group exists), only when the heartbeat is fresh, and waits
up to 10 s for the runner to clean up. Only when it has not: KILL to the
group, KILL to the command's recorded id, and the worktree removed. An
outcome the runner wrote meanwhile with a verdict stands. A live id with a
stale heartbeat gets 15 s to beat again before `stopped reporting`.

The worktree is removed through `git worktree remove --force`; when git
refuses, the checkout's own record (`admin`) is removed by path, never by
a repository-wide `git worktree prune`.

## The record

Made by the same writer as `suite-record`: same fields, `feature` = the run,
`tap` = the TAP file's path under `.delivery-kit/runs/<feature>/base-suite/`.
The key is taken in the worktree before the command and again after it; a
difference records nothing (`nothing recorded — what the key covers … is
not what it was`).

## `suite-lookup` summary line (changed text, same decision)

```
<record path>
1..N, N ok (0 skipped), 0 not ok, exit 0 — recorded <time> by run <feature> on commit <sha>, command "<testCommand as JSON>"[ — for these files without the untracked <spec dir>/]
```

Under `files` mode, `on tree <tree>` replaces `on commit <sha>`.
