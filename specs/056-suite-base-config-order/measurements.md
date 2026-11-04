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

Run first on commit `34c8742`, and again after each round of phase I's fixes. This table is the last run, on the final text. It ran in a detached worktree outside the repository, removed after the run. The rig stops unless each mutation's old text occurs exactly once and the file changes. It checks the verdict, the exit status and the expected message. Rows that name a test other than the new one run that test's file. Unexpected results: 0 of 25.

| Case | Test | Verdict | Message |
|---|---|---|---|
| control: shipped text | new | ok (rc 0) | - |
| control: sentence rewrapped | new | ok (rc 0) | - |
| fault: swapped | new | not ok (rc 1) | phase B records config after the base suite start that reads it |
| fault: record removed | new | not ok (rc 1) | phase B no longer holds the record sentence |
| fault: start removed | new | not ok (rc 1) | phase B no longer runs the base suite start command |
| fault: record only in Configuration | new | not ok (rc 1) | phase B no longer holds the record sentence |
| fault: both only before phase B | new | not ok (rc 1) | phase B no longer runs the base suite start command |
| fault: both only on phase C's first line | new | not ok (rc 1) | phase B no longer runs the base suite start command |
| fault: start only on phase C's first line | new | not ok (rc 1) | phase B no longer runs the base suite start command |
| fault: start also named before record | new | not ok (rc 1) | phase B records config after the base suite start that reads it |
| fault: other spelling of start right before record | new | not ok (rc 1) | phase B's record sentence no longer sits between the gitignore answer and the branch cut (or a neighbour was reworded) |
| fault: other spelling of start far before record | new | not ok (rc 1) | phase B names suite-base before it records config |
| fault: record moved before init | new | not ok (rc 1) | phase B's record sentence no longer sits between the gitignore answer and the branch cut (or a neighbour was reworded) |
| fault: record moved after the branch cut | new | not ok (rc 1) | phase B's record sentence no longer sits between the gitignore answer and the branch cut (or a neighbour was reworded) |
| fault: record first in phase B | new | not ok (rc 1) | phase B's record sentence no longer sits between the gitignore answer and the branch cut (or a neighbour was reworded) |
| fault: countermand after the record | new | not ok (rc 1) | phase B's record sentence no longer sits between the gitignore answer and the branch cut (or a neighbour was reworded) |
| fault: second definition after the record | new | not ok (rc 1) | phase B's record sentence no longer sits between the gitignore answer and the branch cut (or a neighbour was reworded) |
| fault: inverted (does not record) | new | not ok (rc 1) | phase B no longer holds the record sentence |
| fault: phase B heading renamed | new | not ok (rc 1) | the slice helper's own failure |
| fault: phase C heading renamed | new | not ok (rc 1) | the slice helper's own failure |
| fault: trailer order removed from `configuration.md` | the commit trailers test | not ok (rc 1) | configuration.md no longer orders the trailer write after B's record of config |
| fault: `phases.md` clause reverted | phases.md states the suite reuse rules | not ok (rc 1) | that test's pin |
| fault: Configuration loses `testCommand` | the commit mechanics test | not ok (rc 1) | that test's pin |
| fault: the start's not-started path exits 1 | no usable test command, in `base-suite.bats` | not ok (rc 1) | exit 1, expected 0 |
| fault: the start's not-started message changed | no usable test command, in `base-suite.bats` | not ok (rc 1) | start said ... |

The spec's four faults are rows "swapped", "record removed", "start removed" and "both only before phase B". The others came from phase I's review. Two rows first came back red with another check's message than the rig expected, because an earlier check caught them. Their expectations were corrected, and "other spelling of start far before record" was added so that the `suite-base` check is seen to fire.

Known limit: a start worded with no `suite-base`, such as "Start the base suite now", placed far before the record, stays green. A substring pin cannot list prose, and this file's header says so.

## T005: bash 3.2

Docker image `bash:3.2`, GNU bash 3.2.57, read-only root, no network, with a stand-in `git` that answers only `rev-parse --show-toplevel`.

| Tree | Check | Result |
|---|---|---|
| Commit `34c8742` | the new test | `1..1`, ok, rc 0 |
| The same, with the sentence swapped | the new test | not ok, rc 1: phase B records config after the base suite start that reads it |
| The final text | `bash -n` on preprocessed `prose.bats` and `base-suite.bats` | exit 0, both |
| The final text | the new test | `1..1`, ok, rc 0 |
| The final text, with the start only on phase C's first line | the new test | not ok, rc 1: phase B no longer runs the base suite start command |

`base-suite.bats` needs a real git, so on bash 3.2 it was parsed and not run. CI's macOS job runs it.
