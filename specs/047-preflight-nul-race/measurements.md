# Measurements: the constitution NUL check answers the same way under any load

A record of runs on 2026-11-02, on Ubuntu (bash 5, uutils coreutils 0.10.0,
mawk 1.3.4, bats 1.11.0). "Old" is a scratch worktree at `e255029` (before this
feature) with this feature's `preflight.bats` copied in; "new" is a scratch
worktree at `a90a9dd` (the release piece). Every mutation ran in a scratch
worktree, never the main checkout, and was shown to have landed.

## SC-001: the deterministic test

The test "a NUL in the constitution is found even when the reader stops at its
first match" puts a fake `od` first on `PATH`: it drains its input, prints
` ff fe 23 00`, then about 1 MB of non-NUL lines.

| Side | Runs | Passed |
|---|---|---|
| old | 10 | 0 |
| new | 10 | 10 |

Its first run, on the unchanged script, failed with no `NUL bytes` warning: the
old check had taken the "no NUL" branch.

## SC-002: the load reproduction

The constitution-nul fixture, 400 runs of each check, with eight busy loops
running:

| Check | Wrong answers |
|---|---|
| old: `head -c 4096 | od -An -tx1 | grep -q ' 00'` under `pipefail` | 33 of 400 |
| new: capture `od`'s output, then `case … *' 00'*` | 0 of 400 |

(The spec's context recorded 30 of 400 for the old check on an earlier run.)

## SC-003: every constitution fixture, old script against new

`preflight.sh --dir <fixture> --base-branch main`, stdout and stderr together,
the checkout path masked:

| Fixture | Exit (old/new) | Bytes (old/new) | Result |
|---|---|---|---|
| constitution-bom | 0/0 | 712/712 | identical |
| constitution-nul | 0/0 | 792/792 | identical |
| constitution-set | 0/0 | 702/702 | identical |
| constitution-unclosed | 0/0 | 711/711 | identical |
| constitution-unset | 0/0 | 703/703 | identical |

## Positive controls (FR-003, FR-004, SC-004)

| Mutation | Landed | Expected red |
|---|---|---|
| the old NUL-check line put back in `pipeline/scripts/preflight.sh` | yes (1 match) | "no shipped script that sets pipefail pipes into grep -q" — red, naming `pipeline/scripts/preflight.sh:322` |
| the walk's `-q` rule narrowed to a bare `-q` (flag groups no longer match) | yes | "the walk names a planted pipe into grep -q, -qE or --quiet by its line" — red |
| the walk's zero-file check removed | yes | "the walk fails when it walked no file" — red |

The new worktree was restored and `git diff --quiet` confirmed it clean.

## Full suite at the baseline (F.5)

`1..897`, 897 ok, at `e255029` with the spec folder untracked.
