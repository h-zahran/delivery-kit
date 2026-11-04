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

## T011: time at the repository root

`bash scripts/run-suite.sh` from the repository root, at the end of piece 4, on 16 CPUs, 8 files at once, with load from other programs at about 5. Each report passes `progress.sh tap-check`.

| Pass | Wall time | Exit | Plan | ok | not ok | skip |
|---|---|---|---|---|---|---|
| 1 | 104 s | 0 | `1..1000` | 1000 | 0 | 0 |
| 2 | 109 s | 0 | `1..1000` | 1000 | 0 | 0 |
| 3 | 111 s | 0 | `1..1000` | 1000 | 0 | 0 |

Serial, run 056's phase J suite took 561 s on 983 tests. The base run's 983 tests plus this feature's 17 new tests make 1000.

SC-003, the same set of test names as the serial report, is checked at phase J, which runs the serial command on the final commit. Nothing is written after J's last suite, so the result is in the pull request body.

