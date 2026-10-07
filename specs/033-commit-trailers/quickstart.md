# Quickstart: verify the commit trailers

Run from the repository root.

## 1. The suites

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
bash scripts/check-versions.sh
```

Record of one run, 2026-10-07, Linux, at `032-branch-and-spec-dir-flags` = `8c48ddf`: before the change `1..289`, all `ok`. After it, see the table in §3.

## 2. The positive controls

Each mutation runs in a throw-away copy of the tree, never in the checkout. Each one is first checked to have landed: the original text must be present exactly once before it is replaced, or the result is not counted. The file is restored after each run.

| # | Mutation | File | Test that goes red |
|---|---|---|---|
| 1 | Change the `commitTrailers` default cell | `pipeline/skills/pipeline/SKILL.md` | the commit trailers are pinned where the operator reads them |
| 2 | Make the `--trailer` row say it replaces the key | `pipeline/skills/pipeline/SKILL.md` | same |
| 3 | Delete the `Trailers` probe line | `pipeline/skills/pipeline/SKILL.md` | same |
| 4 | Make the add rule a replace rule | `pipeline/skills/pipeline/SKILL.md` | same |
| 5 | Drop `Late` from the reserved tokens | `pipeline/skills/pipeline/SKILL.md` | same |
| 6 | Drop late commits from the list | `pipeline/skills/pipeline/SKILL.md` | same |
| 7 | Add trailers after the message is shown | `pipeline/skills/pipeline/SKILL.md` | same |
| 8 | Use `add` for `addIfDifferent` | `pipeline/skills/pipeline/SKILL.md` | same |
| 9 | Apply a different list on a resume | `pipeline/skills/pipeline/SKILL.md` | same |
| 10 | Omit the Trailers line on a resume | `pipeline/skills/pipeline/SKILL.md` | same |
| 11 | Make the add rule a replace rule | `pipeline/docs/configuration.md` | same |
| 12 | Reword the entry's bold lead | `pipeline/CHANGELOG.md` | same |
| 13 | Skip the line-break check | `pipeline/scripts/preflight.sh` | trailers: a malformed trailer is refused, naming it |
| 14 | Skip the `:` check | `pipeline/scripts/preflight.sh` | same |
| 15 | Skip the token check | `pipeline/scripts/preflight.sh` | same |
| 16 | Skip the empty-value check | `pipeline/scripts/preflight.sh` | same |
| 17 | Skip the reserved-token check | `pipeline/scripts/preflight.sh` | trailers: the run's own markers Piece and Late are refused, in any letter case |
| 18 | Reserve `Piece` only | `pipeline/scripts/preflight.sh` | same |
| 19 | Never add a trailer to the list | `pipeline/scripts/preflight.sh` | trailers: each one is reported, in the order given |
| 20 | Add each trailer to the front | `pipeline/scripts/preflight.sh` | same |

## 3. Record

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | `1..294`, all `ok` | 20 of 20 landed and went red |
