# Implementation Plan: A phase time is never negative

**Branch**: `060-no-negative-phase-time` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

## Summary

One rule in `METRICS_JQ` in `pipeline/scripts/progress.sh`: a phase whose end is earlier than its start reads `seconds: null`. Shipped as pipeline 1.12.1.

## Technical Context

**Language/Version**: bash, with bash 3.2 as the floor. jq 1.6 and later.

**Dependencies**: None new.

**Storage**: `pipeline-run.json`, derived. The state file does not change.

**Testing**: `bash scripts/run-suite.sh`. Changed: `pipeline/tests/progress-git.bats`.

**Scope**: One jq condition, two tests, one comment, three version records.

## Constitution Check

| Principle | How this feature meets it |
|---|---|
| I. Silence is the failure that matters | A false number becomes a plain null. |
| II. Measure; never assert | The fault was read from run 059's file, and the test drives the same commands in the same order. |
| III. A gate must be shown able to go red | The new test is seen red on the old rule, and inverted faults run through the harness. |
| IV. One implementation, many callers | One rule in the one jq program. |
| V. Derive coverage; never enumerate it | Not touched. |

No violations.

## Decision: the rule goes in the metrics, not in `phase-start`

`phase-start` keeps the old `done` on a re-entry. Clearing it there would also stop the fault, but it would drop the record of when the phase last ended, and it would change a state write that many commands rest on. The file is derived, so the derived value is the right place to refuse a false number. The timestamps stay in the file.

**Alternative rejected**: `phase-start` removes `done`. It loses a fact, for no gain to the reader.

## Limit, stated

A re-entered phase with no new end reads null until its end is stamped. A phase started again after a clock moved back also reads null, which is the honest answer.

## Pieces

1. The rule and its tests.
2. Release records: pipeline 1.12.1.

## Faults

Planted through `.delivery-kit/runs/060-no-negative-phase-time/fault-harness.sh`, on a copy of the tree, with `pipeline/tests/progress-git.bats`, filter `phase time`. Each fault landed, or the harness reads NO-OP.

| Label | The rule became | Result |
|---|---|---|
| control | A comment in the test file changed | GREEN, 2 ok |
| strict | `$d > $s` | RED, both tests |
| removed | No `$d >= $s` | RED, both tests |
| inverted | `$d < $s` | RED, both tests |

The two tests were first run on the old rule. Both went red, each at its null check.
