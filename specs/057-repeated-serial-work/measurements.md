# Measurements: Remove repeated and serial work from a pipeline run

## T003: bash 3.2

Docker image `bash:3.2`, GNU bash 3.2.57, read-only root, no network, with a stand-in `git` that answers only `rev-parse --show-toplevel`. `/tmp` is a tmpfs mounted with `exec`, because the tests' stand-in tools run from there.

| Tree | Check | Result |
|---|---|---|
| Piece 1's text | `tests/run-suite.bats` | `1..14`, 14 ok, rc 0 |

## T010: the fault run

Through this run's own harness, `.delivery-kit/runs/057-repeated-serial-work/fault-harness.sh`, in a throwaway copy, one fault at a time, with each edit checked to have landed. The harness reports a fault that changed no byte as `NOT-LANDED`.

| Set | Faults | Red | Green | Not landed |
|---|---|---|---|---|
| No fault: `tests/run-suite.bats` and the harness pins | 2 controls | 0 | 2 | 0 |
| `scripts/run-suite.sh`: each contract row, the renumbering, the order, the plan, the job limits, the runner, the roots and the file set | 29 | 29 | 0 | 0 |
| `.delivery-kit.json` and `CONTRIBUTING.md` | 2 | 2 | 0 | 0 |
| The harness rules in `pipeline:spec-review`: each rule removed or inverted | 14 | 14 | 0 | 0 |
| The orchestrator's pointer, and `pipeline/docs/phases.md` | 3 | 3 | 0 | 0 |

Two gaps this run found and closed before that table: stubs without the execute bit were passed over in silence, so the real `getconf` answered; and no test read a second plan line in the report, or a link to a folder.

