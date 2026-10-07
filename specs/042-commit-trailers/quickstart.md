# Quickstart: verify the commit trailers

Run from the repository root.

## 1. The suites

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
bash scripts/check-versions.sh
```

Record of one run, 2026-10-07, Linux, at `032-branch-and-spec-dir-flags` = `8c48ddf` (the first version of Phase 41): before the change `1..289`, all `ok`. After it, see the table in §3.

## 2. The positive controls

Each mutation runs in a throw-away copy of the tree, never in the checkout. Each one is first checked to have landed: the original text must be present exactly once before it is replaced, or the result is not counted. The file is restored after each run.

| # | Mutation | File | Test that goes red |
|---|---|---|---|
| 1 | `with_trailers` returns before adding anything | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | every "trailers:" test that commits with a list |
| 2 | J's `--record` sets `MF` without `with_trailers` | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: J's empty record commit carries them, and is still read as J's record (alone) |
| 3 | `commit_named` sets `MF` without `with_trailers` | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | the spec, piece, late and remainder "trailers:" tests, not J's |
| 4 | `addIfDifferent` → `add` | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: remainder-commit carries them, never adds one twice, and leaves the caller's file alone |
| 5 | Drop `--no-divider` | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: piece-commit joins them to its Tasks and Piece lines, the body kept byte for byte |
| 6 | Drop `Tasks` from the reserved tokens | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a recorded list that is not one-line strings, or that uses a run marker, is refused, naming it |
| 7 | Drop `Piece` from the reserved tokens | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 8 | Accept any recorded list | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 9 | Skip the `:` check | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 10 | Skip the token check | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 11 | Skip the empty-value check | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 12 | Commit the caller's file in place | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: remainder-commit carries them, never adds one twice, and leaves the caller's file alone |
| 13 | `--where end` → `--where start` | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | the five "trailers:" tests for each commit subcommand |
| 14 | Drop `Tasks` from the reserved tokens | `pipeline/scripts/preflight.sh` | trailers: the run's own markers Piece, Late and Tasks are refused, in any letter case |
| 15 | Skip the line-break check | `pipeline/scripts/preflight.sh` | trailers: a malformed trailer is refused, naming it |
| 16 | Skip the `:` check | `pipeline/scripts/preflight.sh` | same |
| 17 | Skip the token check | `pipeline/scripts/preflight.sh` | same |
| 18 | Skip the empty-value check | `pipeline/scripts/preflight.sh` | same |
| 19 | Skip the reserved-token check | `pipeline/scripts/preflight.sh` | trailers: the run's own markers Piece, Late and Tasks are refused, in any letter case |
| 20 | Reserve `Piece` only | `pipeline/scripts/preflight.sh` | same |
| 21 | Never add a trailer to the list | `pipeline/scripts/preflight.sh` | trailers: each one is reported, in the order given |
| 22 | Add each trailer to the front | `pipeline/scripts/preflight.sh` | same |
| 23 | Change the `commitTrailers` row | `pipeline/skills/pipeline/SKILL.md` | the commit trailers are pinned where the operator reads them |
| 24 | Change the `--trailer` row | `pipeline/skills/pipeline/SKILL.md` | same |
| 25 | Delete the `Trailers` probe line | `pipeline/skills/pipeline/SKILL.md` | same |
| 26 | Drop `commitTrailers` from the pointer list | `pipeline/skills/pipeline/SKILL.md` | same |
| 27 | Make the add rule a replace rule | `pipeline/docs/configuration.md` | same |
| 28 | Drop `Tasks` from the reserved tokens | `pipeline/docs/configuration.md` | same |
| 29 | Pass the flags' trailers first | `pipeline/docs/configuration.md` | same |
| 30 | Rename `config.commitTrailersFrom` | `pipeline/docs/configuration.md` | same |
| 31 | Drop J's `--record` from the list of commits | `pipeline/docs/configuration.md` | same |
| 32 | Allow a trailer by hand | `pipeline/docs/configuration.md` | same |
| 33 | Drop the recorded layer from the resume rule | `pipeline/docs/configuration.md` | same |
| 34 | Reword the entry's bold lead | `pipeline/CHANGELOG.md` | same |
| 35 | Accept an empty recorded trailer | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a recorded list that is not one-line strings, or that uses a run marker, is refused, naming it |
| 36 | Let the record hold the key's list alone | `pipeline/docs/configuration.md` | the commit trailers are pinned where the operator reads them |

Two `progress.sh` mutations (rows 2 and 3) first left `MF` empty. They went red because the commit failed, not because a trailer was missing. They were rerun in the form above, and went red for the right reason.

## 3. Record

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | `1..294`, all `ok` | 20 of 20 landed and went red (first version) |
| 2026-10-07 | Linux | `1..369`, all `ok` | 36 of 36 landed and went red (rebuilt on Phase 41) |
