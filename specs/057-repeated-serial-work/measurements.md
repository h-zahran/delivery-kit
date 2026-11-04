# Measurements: Remove repeated and serial work from a pipeline run

All on the final text of phase I's fixes, unless a row says otherwise.

## bash 3.2

Docker image `bash:3.2`, GNU bash 3.2.57, read-only root, no network, with a stand-in `git` that answers only `rev-parse --show-toplevel`. `/tmp` is a tmpfs mounted with `exec`, because the tests' stand-in tools run from there.

| Tree | Check | Result |
|---|---|---|
| Piece 1's text | `tests/run-suite.bats` | `1..14`, 14 ok, rc 0 |
| After phase I's fixes | `tests/run-suite.bats` | `1..22`, 22 ok, rc 0 |

## The fault runs

Through this run's own harness, in a throwaway copy, with each edit checked to have landed. The harness reports a fault that changed no byte as `NOT-LANDED`, and an exit with no `not ok` line as `NO-NOT-OK`. Each list had no-fault controls, all green.

| List | Who | Faults | Red | Green |
|---|---|---|---|---|
| H | phase H, on the pieces as built | 48 | 48 | 0 |
| Tests reviewer | phase I, its own list, written before it read the harness | 72 | 20 | 52 |
| I | the fix step: those survivors and the new branches | 52 | 51 | 1 |
| Last pass | the fix step: the second bugs read | 18 | 17 | 1 |

The tests reviewer's 52 survivors were the reason for most of the test changes. Phase H's list removed whole branches. The reviewer's list hit verdict lines, the report and test names, which is why writing its list first paid off.

Green on the final text, both with no effect a test can show on this machine:

- `report: plan write status ignored`: when stdout cannot be written, `awk` fails too, and that fault fires. The check stays as a second route.
- `rm message reaches stderr`: the `chmod` before it leaves nothing for `rm` to refuse. The silence stays as a second route.

## Time at the repository root

`bash scripts/run-suite.sh` from the repository root, on the final script, on 16 CPUs, 8 files at once, with load from other programs at about 6. Each report passes `progress.sh tap-check`.

| Pass | Wall time | Exit | Plan | ok | not ok | skip |
|---|---|---|---|---|---|---|
| 1 | 111 s | 0 | `1..1007` | 1007 | 0 | 0 |
| 2 | 111 s | 0 | `1..1007` | 1007 | 0 | 0 |
| 3 | 109 s | 0 | `1..1007` | 1007 | 0 | 0 |

Serial, run 056's phase J suite took 561 s on 983 tests. The base run's 983 tests plus this feature's 24 new tests make 1007.

SC-003, the same set of test names as the serial report, is checked at phase J, which runs the serial command on the final commit. Nothing is written after J's last suite, so the result is in the pull request body.

## Phase I's time, against the estimate

The seed estimated that one harness saves 3 to 6 minutes in phase I. This run cannot confirm that. The tests reviewer reused every part of the harness and repaired nothing, but it took 2,060 s, against 1,077 s in run 056, because it ran 72 faults over a much larger change. Run 2 is the first comparable measure.

## The faults, by name

**H**: renumber: ok lines keep their own number; renumber; order: reversed; plan: not the sum; plan: every plan line dropped; R1: exit always 0; R2: exit status not read; R3: no plan not named; R4: two plans not named; R5: count not compared; R6: no number not named; R7: missing status not named; R8: zero tests pass; R9: xargs status ignored; R10: runner not checked; R11: root not checked; R11: an empty root passes; R12: mktemp failure silent; R13: no process group; R13: wrong status; cleanup: folder left behind; jobs: no floor; jobs: no ceiling; one at a time; failing output lost; a root dropped; any file runs; symlinks not followed; BATS_BIN ignored; testCommand back to serial; serial command removed; harness: names changed; harness: no run directory now applies; harness: another may be built; harness: J left out; harness: any reviewer may create it; harness: fix step need not run it; harness: reads it first; harness: shares a fault list; harness: a cap; harness: a lens dropped; harness: edits the tree; harness: no-op fault passes; harness: a tracked file runs; harness: rebuilt, not repaired; pointer removed; phases: no cap line; phases: reads it first.

**I**: HOME unset answers first; README serial command gone; a worker edits the file; dash root reaches find; default runner path; empty BATS_BIN; file as root; find failure ignored; huge plan wraps; jobs: all the CPUs; jobs: constant; jobs: getconf before nproc; jobs: last resort 16; jobs: no getconf fallback; jobs: no number check on nproc; lens span: harness moved; messages before the report; no status: verdict not set; not ok not counted; not ok number not read; number: fault not named; number: outside the plan hidden; number: repeat hidden; phases: a cap added; phases: a fault list shared; phases: pointer gone; pointer: brief not named; pointer: out of the ground rules; read leak: names read back; report: dropped on a fault; report: one fault only; report: plan write status ignored; rules: any red counts; rules: feature not named; rules: no control; rules: no rename; rules: old check; rules: run it unread; rules: runs anyway; rules: runs in the tree; rules: two owners; shared TMPDIR; stderr leaves the report; stop: HUP not trapped; stop: INT not trapped; stop: a path in the message; stop: no KILL; stop: no report; stray line judged; worker plan left out; xargs: verdict not set; xargs: workers left running.

**Last pass**: late plan not seen; read-only leftover; stop: stderr stays silent; CR kept: counting; rules: write before the check; late plan not named; rm message reaches stderr; stop: too slow for base_stop; CR kept: report; rules: no home for the harness; range judged with no plan; failed xargs: TERM only; root: ! reaches find; rules: no owner named; report printed twice; killed xargs: bash line first; worker spelling needs no arguments; rules: control once only.
