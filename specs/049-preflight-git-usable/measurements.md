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

## T014: the prose piece

`bats pipeline/tests/prose.bats`: `1..95`, 95 ok after the pins and the two
rare-paths spans were updated (the spans regenerated with a verbatim copy of
`rare_section`'s pipeline). The reason-set test, moved here from the probe
piece, passed in `preflight.bats`.

Prose mutations, each in a detached worktree (removed afterwards), each
mutated line printed to prove it landed:

| Mutant | Change | Red |
|---|---|---|
| trigger-back | decision 11's trigger back to `capabilities.git` | the git stop is pinned in both surfaces |
| pipeline-runs-it | "It is never run by the pipeline" to "It is run by the pipeline" | the git stop is pinned in both surfaces |
| no-safe-dir | the `safe.directory` command replaced by "the fix" | the git stop is pinned in both surfaces |
| drop-reason-item | the `broken` item loses its backticks | the git reasons the script assigns are the ones the git stop instructs |

## Phase I: the review round, and its fixes

Five lenses, one round: contract (COMPLIANT; 4 MEDIUM, 5 LOW), security
(1 MEDIUM, 4 LOW), tests (3 HIGH, 2 MEDIUM, 2 LOW), bugs (12 findings),
simplify (2 MEDIUM, 8 LOW). No CRITICAL. The findings and what became of
each are in the run's state file (`gates.I`).

The security lens measured the central claim on git 2.53.0: a hostile
repository planting 28 programs ran none under the lifted
`rev-parse --git-dir` (one `execve`, traced), while the same plants fired
under `status` and `commit`. git's own `Documentation/config/safe.txt`
says, at v2.35.2 to v2.37.0, that `-c safe.directory` is not respected; at
v2.38.0 it moves to protected configuration. So before 2.38 every
ownership refusal reads `no-repository` (the contract now says so).

After the fixes: `prose.bats`, `preflight.bats` and `skills.bats`,
`1..216`, 216 ok. Mutations re-run against the fixed code (classifier now
runs `rev-parse` first, `--version` only after it fails):

| Mutant | Change | Red |
|---|---|---|
| a | drop the one-command lift | refuses for ownership; exit codes only; names unchecked |
| b | swap `refused-ownership` and `no-repository` | refuses; exit codes only; names unchecked; no repository here |
| c | skip the `--version` step | found but cannot run |
| d | the override gate back to `git_present` | names unchecked |
| i | the feature-branch gate back to `git_present` (missed before the fixes) | names unchecked |
| e | `--argjson git_usable` to `--arg` | all five per-reason tests and both extended ones |
| f | a second presence probe spelled `type -P git` | probes git in one place |
| g | the lifted call becomes `status --porcelain` (missed before the fixes) | refuses for ownership: the planted program ran |
| h | the classifier matches git's message text (missed before the fixes) | exit codes only |
| P1 | decision 11's action back to "print the link" (missed before) | the git stop is pinned |
| P2 | the link "for every reason" (missed before) | the git stop is pinned |
| P5 | decision 11 told to run the trust command (missed before) | the git stop is pinned; each rare path's old site |
| P6 | decision 11's trigger back to `capabilities.git` | the git stop is pinned |
| P7 | "they must not trust it" to "they may trust it" | the git stop is pinned; each rare-paths section is exactly |

The tracked script's checksum was unchanged after the script mutants; the
prose mutants ran in a detached worktree, removed afterwards.
