# Measurements: Phase B records config before the base suite starts

Measured 2026-11-04 on Linux, local bats, from the repository root. The base commit is `b80ae0e78345063e09bbd9cbd9a73387a41bb0f0`.

## T001: the test is red before the sentence exists

Command: `bash "$HOME/bats/bin/bats" --filter 'B records config before' --print-output-on-failure pipeline/tests/prose.bats`

```
1..1
not ok 1 B records config before it starts the base suite run
# phase B no longer says to record config
```

Exit status 1. It is red for the right reason: the sentence is absent.

## T004: faults and controls

Run on commit `34c8742` in a detached worktree outside the repository, removed after the run. The rig stops unless each mutation's old text occurs exactly once and the file changes. It then checks the plan line `1..1`, the verdict, the exit status and the exact message. Unexpected results: 0 of 8.

| Case | Mutation landed | Verdict | Message |
|---|---|---|---|
| control: shipped text | n/a | ok (rc 0) | - |
| control: sentence rewrapped | yes | ok (rc 0) | - |
| fault: swapped | yes | not ok (rc 1) | phase B records config after the base suite start that reads it |
| fault: record removed | yes | not ok (rc 1) | phase B no longer says to record config |
| fault: start removed | yes | not ok (rc 1) | phase B no longer runs the base suite start command |
| fault: record only in Configuration | yes | not ok (rc 1) | phase B no longer says to record config |
| fault: both only in phase A's place | yes | not ok (rc 1) | phase B no longer runs the base suite start command |
| fault: start also named before record | yes | not ok (rc 1) | phase B records config after the base suite start that reads it |

The spec's four faults are the first four faults, with "correct order only outside phase B" as the fifth row of faults. The two extra cases are the record moved outside alone, and a second start named before the record (SC-001).

## T005: bash 3.2

Docker image `bash:3.2`, GNU bash 3.2.57, read-only root, no network, with a stand-in `git` that answers only `rev-parse --show-toplevel`.

| Tree | `bash -n` on the preprocessed file | Test |
|---|---|---|
| Commit `34c8742` | exit 0 | `1..1`, ok, rc 0 |
| The same, with the sentence swapped | exit 0 | `1..1`, not ok, rc 1: phase B records config after the base suite start that reads it |

The `${flat%%"$start"*}` cut works on bash 3.2 in both directions.
