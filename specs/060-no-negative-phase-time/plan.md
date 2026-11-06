# Implementation Plan: A phase time is never negative

**Branch**: `060-no-negative-phase-time` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

## Summary

Two rules in `METRICS_JQ` in `pipeline/scripts/progress.sh`: a phase whose end is earlier than its start reads `seconds: null`, and a phase with a stamp missing or not a string holds no `seconds` key. Shipped as pipeline 1.12.1.

## Technical Context

**Language/Version**: bash, with bash 3.2 as the floor. jq 1.6 and later.

**Dependencies**: None new.

**Storage**: `pipeline-run.json`, derived. The state file does not change.

**Testing**: `bash scripts/run-suite.sh`. Changed: `pipeline/tests/progress-git.bats`.

**Scope**: One jq condition and one jq branch, two tests and a doc pin, one comment, one section in `pipeline/docs/phases.md`, three version records.

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

A re-entered phase with no new end reads null until its end is stamped, and stays null if no new end comes. A phase whose end is earlier than its start after a clock moved back also reads null, which is the honest answer.

The rule cannot catch a stale end that is not earlier than the new start. A phase started again in the same second as its old end reads 0 until its new end is stamped, and after a clock moved back a running phase can read a positive number. One-second stamps cannot tell these from a real end, and FR-003 requires 0 to stay 0. Only a `phase-start` that moves the old pass aside would close them, as it would also keep the first pass's time, which `phase-start` overwrites. That reverses this plan's decision, so it goes to the owner as a candidate seed.

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
| tolerance | `$d >= $s - 1` | RED, both tests |
| no-s-guard | No `$s != null` | RED, the first test |
| no-start-key | A phase with only `done` gets a key | RED, the first test |
| stored-kept | A `seconds` the state file holds is kept | RED, the first test |
| unparsed-no-key | A stamp that does not parse loses the key | RED, both tests |
| stamps-erased | A phase with a stamp missing loses its stamps | RED, the first test |
| non-object-dies | The branch runs on an entry that is not an object | RED, the first test |
| done-stale | `phase-done` keeps the old end | RED, the second test |
| start-stale | `phase-start` keeps the old start | RED, the second test |
| stale-run-file | The old run file's phases replace the state file's | RED, the first test |
| doc-swap | The doc's no-key sentence changed | RED, the doc pin |

The two tests were first run on the old rule. Both went red, each at its null check. The table is from the tests as the review's fixes left them: the second test now sleeps instead of editing the first pass. The first test catches tolerance every time, through its phase J. The second catches tolerance only when the stamps land exactly one second apart, and strict only when the new start and end land in one second.
