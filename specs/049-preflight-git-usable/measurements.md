# Measurements: 049-preflight-git-usable

A record of runs on 2026-11-02, local Ubuntu, git 2.53.0, bats 1.11.0, on
branch `049-preflight-git-usable` after the spec commit `c76a65d`. Counts
here describe these runs, not the current files.

## Baseline (F.5)

Full `testCommand` before any change: `1..914`, 914 ok, 0 not ok, 0 skipped.

## T007: the new tests against the unchanged script

`bats -f git pipeline/tests/preflight.bats`: `1..17`, 8 not ok — every new
or extended test, each for its own reason:

| Test | Red because |
|---|---|
| git present when git is findable (extended) | no `gitUsable` key |
| git absent, and the report survives it (extended) | no `gitUsable` key |
| a git that refuses the repository for ownership | no `gitUsable` key (precondition passed) |
| an unusable git reports names unchecked | exit 1: the old probe ran the override check and git printed `fatal: detected dubious ownership` |
| a git that opens no repository here | no `gitUsable` key (precondition passed) |
| a git that is found but cannot run | no `gitUsable` key (precondition passed) |
| the git reasons the script assigns are the ones the git stop instructs | the script assigned no reason |
| the script probes git in one place | `command -v git` appeared 2 times |

The reason-set test was then moved to the prose piece (T014): its second
side is text that piece writes, so in the probe piece it could only be red.

## T009: with the classifier

`bats pipeline/tests/preflight.bats`: `1..107`, 107 ok, 0 skipped.
quickstart.md steps 1 to 3 printed `usable`, `refused-ownership` (exit 0)
and `no-repository`, as expected.

## T010: mutations (FR-012)

Each mutant is a copy of `pipeline/scripts/` in the scratchpad, run with
`PREFLIGHT_UNDER_TEST`; the tracked script's checksum was compared before and
after (unchanged). Each mutated line was printed by `diff` to prove it landed.
Filter: `capability report|unusable git|probes git|without git` (8 tests).

| Mutant | Change | Red |
|---|---|---|
| a | drop `-c safe.directory='*'` from the lifted call | refuses for ownership; names unchecked |
| b | swap `refused-ownership` and `no-repository` | refuses for ownership; names unchecked; no repository here |
| c | skip the `git --version` step | found but cannot run |
| d | `have_git` back to `git_present` | names unchecked |
| e | `--argjson git_usable` to `--arg` (a string) | present; absent; refuses; no repository; cannot run |
| f | a second `command -v git` probe | probes git in one place |

Every new test went red under at least one mutant.
