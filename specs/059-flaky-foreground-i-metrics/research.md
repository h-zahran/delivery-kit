# Research: 059

## R1. Why the stop test went red in the base suite

**Finding**: The test is not flaky. It is red on every run that starts with `SIGINT` ignored.

**Measured 2026-11-05 on `e3a011d`, with bats alone on the one test:**

| How it started | Result | Time |
|---|---|---|
| In the foreground of the Bash tool | ok | 4.0 s |
| As a script's background job, `"$@" &` with no job control | not ok, `# timeout after 60s`, `tests/run-suite.bats` line 459, from line 487, `stop_run INT 2` | 60.5 s |

The red line is the same as in the two base suites of runs 058 and 059. These two are the only base suites since the test was added in `bd1eeed`, and both were red. Every foreground run was green.

**The mechanism.** Bash starts an asynchronous command with `SIGINT` and `SIGQUIT` ignored when job control is off. Bash cannot trap or reset a signal that was ignored at its entry. So `scripts/run-suite.sh`'s `trap stop INT` does nothing, `kill -INT` does nothing, and `wait` holds until the fixture's `sleep 60` ends. That takes the test past its 60-second limit.

**What each start method gives**, measured with a script that prints `trap -p INT` and sends itself `INT`:

| Start | `SIGINT` at entry | Caught? |
|---|---|---|
| Plain foreground | default | yes |
| `cmd &`, no job control | ignored | no |
| `set -m; cmd &` | default | yes |
| `setsid cmd &`, no job control | ignored | no |
| `set -m; setsid cmd &` | default | yes, but `$!` is gone at once, because `setsid` forks when it leads a group |

**Two places do this in the shipped runner** (`pipeline/scripts/progress.sh`):

1. `base_start`: `setsid bash "$SCRIPT_PATH" suite-base-run "$f" … &`.
2. `base_run`: `TMPDIR="$tmpd" bash -c "$SK_CMD" … &`.

Fixing only the first leaves the second, and the command still starts with `SIGINT` ignored.

## R2. How to fix the runner

**Decision**: Use job control at both places. `base_start` always uses `set -m`, and `setsid` goes. `base_run` wraps the command's start in `set -m` and `set +m`, as `scripts/run-suite.sh` does for `xargs`.

**Consequence**: The command then leads a process group of its own, not the runner's. So `base_run_exit` signals `-$BR_CHILD`, falling back to `$BR_CHILD`. `base_stop`'s KILL path does the same with the recorded child id. A TERM to the runner's group still reaches the runner, and its trap stops the command's group.

**Rationale**: `set -m` was already the path on any system with no `setsid`, so that code path has run on macOS since release 1.8.0. The commit that added `setsid` (`22e74b1`) names only a process group as its purpose, and job control gives one. One path is less code than two.

**Alternatives rejected**:
- Keep `setsid` under `set -m`: `$!` dies at once, so the recorded id is wrong.
- Run the command in the foreground of the runner: the TERM trap would wait for the command, and tests read the `child` file.
- Reset the signal with a helper (`env --default-signal`, perl): a new dependency, and coreutils' flag is absent on macOS.
- Lengthen the test limit, retry, or skip: forbidden by FR-003.

**To check after the change**: the runner must outlive the Bash tool call that starts it, now that it shares the caller's session. Measured in `quickstart.md`, step 3.

## R3. What the stop test does when it starts with `SIGINT` ignored

**Decision**: `stop_run` probes the state with a behaviour, not with `trap -p`: a child bash sets a trap and sends itself `INT`. When `INT` is ignored there, the arm still sends a real `INT`, asserts that the script is still alive after it, then ends the script with `TERM` and asserts the same exit status and clean-up. It prints one `#` comment on descriptor 3, so the state is visible.

**Rationale**: The state cannot be changed from bash, so the test tells the truth about it. The `INT` step still sends the real signal and checks a result. No limit is longer, nothing is retried, and nothing is skipped. A behaviour probe does not depend on how bash 3.2 prints `trap -p`.

**Limit, stated**: A caller that itself ignores `SIGINT` passes that state to everything under it, and bash cannot undo it. `suite-base start` gives its command what it was given. That is the same as a foreground run in that caller, so the two do not differ.

## R4. Foreground rule: where it goes

**Decision**: One self-contained ground rule in `pipeline/skills/pipeline/SKILL.md`, and the same rule in the inputs of `pipeline/skills/spec-review/SKILL.md`, so a person who invokes `pipeline:spec-review` alone gets it too.

**Rationale**: A single ground rule binds every brief the orchestrator writes: F, H, H.5, I, J and M. The `bugs` lens is the built-in code-review skill. Measured in an earlier run, it reads git only, takes no brief text beyond its arguments, and runs no suite. The handoff package goes to an external tool with its own limits, so it is not a brief in this sense.

**Text**: `Test runs: each agent brief says: foreground only, no background run, wait loop or monitor; over 600 s, split it, as with bats -f.`

## R5. How phase I is measured

**Decision**: A subcommand, `progress.sh i-measure`, called by the orchestrator, and a gate in `phase-done I`.

**Rationale**:
- `SKILL.md` already asked for these numbers in prose. Runs 056 and 057 kept partial numbers by hand under `reviewI`, and run 058 kept none. A gate that refuses is the only form a run cannot forget.
- The orchestrator is the one actor that sees all five lenses return, the forked `bugs` lens included.
- The earlier memory on auto mode says `progress.sh` subcommands were not blocked, where a whole-file write was. A subagent stamps nothing, so no subagent write can be denied.

**Alternatives rejected**:
- `SubagentStop` hook: the pipeline plugin ships no hooks today. A hook gets the parent session's id and must work out which lens ended from a transcript, and a forked skill may not reach it the same way. More moving parts and more ways to fail in silence.
- Reading subagent transcripts afterwards: depends on the harness's private files.
- A lens stamping itself: a subagent's write may be denied, and a read-only lens must stay read-only.

**Time source**: `date +%s` at each stamp, so seconds are wall time. A lens's seconds run from `dispatch` to the moment the orchestrator records its return. Measured in this run, that overstates the agent's own duration by 49 to 191 s, because the stamp waits for the orchestrator's turn. So `done --seconds <n>` takes the duration a return states when it states one.

## R6. The severity counts' one source

**Decision**: `.delivery-kit/runs/<feature>/findings-I.txt`, written by the orchestrator. Each line is `SEVERITY | lens | file:line | finding | outcome`, where outcome is `fixed`, `deferred` or `declined`. The skill's four-field finding line gains the outcome when the fixes end. Blank lines and `#` lines are allowed.

**Rationale**: The orchestrator already turns every finding into that line. A fixed name in the run directory means no path goes through a shell or into a message. Finding text is data: it is never printed, and a refusal names only the line number.

**Parsing**: The first field is the severity, the second the lens, and the last the outcome, so a `|` in the finding's own text does no harm. A line that fails is counted as unreadable, and its number is recorded and printed. It is not counted as nothing.

## R7. Re-entry

**Decision**: A record that holds a result, `done` or `skipped`, and a findings read, move to `measurements.i.earlier` when something replaces them, and the command says so. A second `done` refuses and prints the recorded value. `dispatch` starts a round in one state write: it also clears the fixes, the recheck and the findings, so the gate asks for each afresh and no old number joins a new round. So no number is silently doubled or lost.

## R8. Proof runs

**The stop test under load**, on the fixed runner, 2026-11-05: 500 passes, 0 red. Every CPU (16) was held busy, with 8 test processes at once. Load average 30 to 43. 150 passes took 174 s, and 350 took 342 s, in two foreground calls. No test code in the foreground path changed after these passes; the later edits are inside the `SIGINT`-ignored arm.

**The stop test with `SIGINT` ignored at entry**: 10 passes, 0 red, about 5 s each. Before the fix: red in 60 s.

**A real base suite on the fixed code**, in a throwaway clone:

| Run | Load | Outcome | Time | `suite-lookup --base` |
|---|---|---|---|---|
| 1 | The 500 passes above, at the same time | red: `values file: a list too long to record…` timed out at 60 s. The stop test was `ok`. | 411 s | not citable |
| 2 | None | green, 1102 of 1102 | 109 s | exit 0, citable |

Run 1's red is another test, `pipeline/tests/preflight.bats`. Alone it takes 16 s, 3 of 3. It reached 60 s under a load this run made on purpose. It is not this feature's cause, and it is reported at DONE as a separate fact.

In run 1, the runner was alive in a later Bash call, so it outlives the call that starts it with job control and no `setsid`.

**Faults planted through the run's harness**, each with a green control:

| Fault | Test | Result |
|---|---|---|
| Runner back on `setsid` | `the base suite's command gets INT as its caller has it` | RED |
| The command's start with no `set -m` | the same | RED |
| The exit trap's TERM to the command's id alone | `a stop ends what the base suite's command started` | RED |
| The stop's KILL to the command's id alone | `the stop's KILL reaches what the base suite's command started` | RED |
| The stop leaves the temporary folder | the stop test | RED |
| The stop leaves a process alive | the stop test | RED, in both signal states |
| The probe inverted | the stop test and the probe's test | RED, both |
| The `SIGINT`-ignored arm removed, with `SIGINT` ignored | the stop test | RED, `# timeout after 60s`: the old failure |
| The holders check inverted, with `SIGINT` ignored | the stop test | RED |

The first form of the arm's check used `kill -0` on the script. The probe-inverted fault stayed green: `kill -0` also succeeds on a child that ended and was not waited for. The check now reads the holding processes.

**Faults on the foreground rule**, each through the harness with a green control: the rule gone from either skill; each of seven required phrases removed in turn; the rule inverted; the rule naming phases; a new sentence that tells agents to run in the background; the base suite's sentence gone. All RED. `SKILL.md` after this piece: 65,364 bytes.

**Faults on the measure**, 24 through the harness with a green control: the gate gone, taking `started`, ignoring the findings, and holding a phase already completed; a missing measure as 0, and a part with no record as done; a skipped lens as zeros, and a lens with findings as null; `accountedSeconds` as a sum, and never null; a second `done` overwriting; `earlier` dropped or silent; an unreadable line silent; the metrics key gone; the reason, severity and lens unchecked; `dispatch` starting all parts; the outcome read from the fifth field; an absent file made empty; seconds as a string; a part gone from the doc. All RED. `SKILL.md` after this piece: 65,413 bytes, 199 more than at the start, 123 free.

**After phase I's fixes.** Faults through the harness: 68 RED and 2 green controls on the first round of fixes, then 15 RED and 2 green controls on the fixes from the recheck, the checkout's removal among them. So 83 caught, 2 of them on both rounds. The first aim at the removal hit another code path and read GREEN, which proves nothing; aimed at `base_stop`, it is RED. Two rules for whoever runs them. A fault that tests the runner's `SIGINT` state must run in the foreground: a background job hands the test `SIGINT` ignored, and the test then says it proves nothing. A code path that runs only with `SIGINT` ignored is now run by the suite itself: a subshell started in the background.

**What a stamp is worth**, measured on this run's five lenses: the orchestrator's stamps ran 49 to 191 s over each agent's own duration. So `done --seconds` takes the return's own number, and refuses one past the time since the part's start. The recheck's number here, 7692 s, holds a pause by the owner and says nothing about what a recheck costs.

**Not reproduced, stated:** the terminal limit in the contract was measured by three lenses under a pty, and was not run again after the fixes. No test exercises the fallback of `group_alive` to a bare id, because every system this suite runs on gives the command a group.

**What CI found.** On the first CI run, 13 of 14 jobs passed. `run-suite: with INT ignored at entry…` failed on `tests (ubuntu-24.04, tests)`, with the `#` comment absent: a background subshell started by that test did not have `SIGINT` ignored there. It did on this machine (bash 5.3.9), macOS and Windows. The cause in that job's bash was not measured. The test now sets the state with `trap '' INT`, so it rests on no bash version's handling of a background subshell. Faults: the arm removed, no `TERM`, any signal, and the state not set, all RED, with a green control.
