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
| 4 | Drop the same-line check (`[ "$l" != "$t" ] \|\| continue 2` → `:`) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: another value under the same token is added; the same line is not |
| 5 | Always add a blank line before the trailers (force `block=0`) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: piece-commit joins them to its Tasks and Piece lines, the body kept byte for byte |
| 6 | Drop `Tasks` from the reserved tokens | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a run marker, no colon or an empty value is refused, naming it |
| 7 | Drop `Piece` from the reserved tokens | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 8 | Accept any recorded list | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a recorded list that is not an array of non-empty strings is refused |
| 9 | Skip the `:` check | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 10 | Skip the token check | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a token git would read differently is refused |
| 11 | Skip the empty-value check | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a run marker, no colon or an empty value is refused, naming it |
| 12 | Commit the caller's file in place | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: remainder-commit carries them, never adds one twice, and leaves the caller's file alone |
| 13 | `show-message` prints the caller's file, not the copy | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | show-message prints the exact message the commit then carries, and leaves the file alone |
| 14 | Drop `Tasks` from the reserved tokens | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: the run's own markers Piece, Late and Tasks are refused, in any letter case |
| 15 | Skip the line-break check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: a malformed trailer is refused, naming it, one case per check |
| 16 | Skip the `:` check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 17 | Skip the token check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 18 | Skip the empty-value check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 19 | Skip the reserved-token check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: the run's own markers Piece, Late and Tasks are refused, in any letter case |
| 20 | Reserve `Piece` only | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 21 | Never add a trailer to the list | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: each one is reported, in the order given |
| 22 | Add each trailer to the front | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
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
| 35 | Accept an empty recorded trailer | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a recorded list that is not an array of non-empty strings is refused |
| 36 | Let the record hold the key's list alone | `pipeline/docs/configuration.md` | the commit trailers are pinned where the operator reads them |
| 37 | Allow `skip-checks` as a token | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a trailer that skips GitHub's checks is refused, in any letter case |
| 38 | Drop `[ci skip]` from the skip-ci values | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 39 | Allow `Co-authored-by` as a token | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a trailer that names another author or closes an issue is refused |
| 40 | Break the closing-keyword pattern in the value | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 41 | Allow a token ending in a non-alphanumeric | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a token git would read differently is refused |
| 42 | Allow an empty token | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 43 | Allow a one-character token | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 44 | Allow `_` in a token | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 45 | Allow a token starting with a non-letter | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 46 | Refuse only CR and LF, not every control character | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a line break or any other control character in a recorded trailer is refused |
| 47 | Reserve `Piece` by substring | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a token that only holds a run marker's letters commits exactly |
| 48 | `show-message` skips `need_git_top` | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | show-message refuses a run marker in the message, a bad recorded trailer, and a subdirectory |
| 49 | Skip the control-character check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: a malformed trailer is refused, naming it, one case per check |
| 50 | Allow `_` in a token | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 51 | Allow a one-character token | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 52 | Allow a token starting with a non-letter | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 53 | Name `(--trailer)` in an error again | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 54 | Allow `skip-checks` as a token | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: one that skips GitHub's checks, names another author or closes an issue is refused |
| 55 | Drop `[no ci]` from the skip-ci values | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 56 | Take the token up to the last colon | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: a value holding a colon is reported whole |
| 57 | Reserve `Piece` by substring | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: dashed tokens and tokens holding a marker's letters are accepted, in order |
| 58 | Drop the `owner/repo` part of the closing pattern | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a trailer that names another author or closes an issue is refused |
| 59 | Count a one-word last paragraph as a trailer block | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a one-word last paragraph is not a trailer block, and a spaces-only line splits paragraphs |
| 60 | Forget the trailers already added from the list | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: the same trailer twice in the list is added once |
| 61 | Count a spaces-only line as text | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a one-word last paragraph is not a trailer block, and a spaces-only line splits paragraphs |
| 62 | Drop the `:?` from the closing pattern | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: one that skips GitHub's checks, names another author or closes an issue is refused |

Two `progress.sh` mutations (rows 2 and 3) first left `MF` empty. They went red because the commit failed, not because a trailer was missing. They were rerun in the form above, and went red for the right reason.

## 3. Record

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | `1..294`, all `ok` | 20 of 20 landed and went red (first version) |
| 2026-10-07 | Linux | `1..369`, all `ok` | 36 of 36 landed and went red (rebuilt on Phase 41) |
| 2026-10-08 | Linux | `1..425`, all `ok`, at `30344a8` | After review 2, on `main` `4076ecf`: rows 1-22, 35 and 37-57 (the script rows) landed and went red. Row 15 first survived: the new control-character check also catches a line break. The test now checks the line-break reason, and row 15 goes red. Row 9 goes red on the message: without the `:` check, the token check refuses the value with another reason. Rows 23-34 and 36 test text this change did not touch. |
| 2026-10-08 | Linux | `1..439`, all `ok`, review 3 | Rows 58-62 landed and went red. Each had survived review 3's fresh mutants; each now has a case. |
