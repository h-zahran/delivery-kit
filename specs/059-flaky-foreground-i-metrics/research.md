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

**Text**: `Test runs in a brief: each agent brief says: foreground only, no background run, wait loop or monitor; over 600 s, split it, as with bats -f.`

## R5. How phase I is measured

**Decision**: A subcommand, `progress.sh i-measure`, called by the orchestrator, and a gate in `phase-done I`.

**Rationale**:
- `SKILL.md` already asked for these numbers in prose, and runs 056, 057 and 058 did not record them. A gate that refuses is the only form a run cannot forget.
- The orchestrator is the one actor that sees all five lenses return, the forked `bugs` lens included.
- The earlier memory on auto mode says `progress.sh` subcommands were not blocked, where a whole-file write was. A subagent stamps nothing, so no subagent write can be denied.

**Alternatives rejected**:
- `SubagentStop` hook: the pipeline plugin ships no hooks today. A hook gets the parent session's id and must work out which lens ended from a transcript, and a forked skill may not reach it the same way. More moving parts and more ways to fail in silence.
- Reading subagent transcripts afterwards: depends on the harness's private files.
- A lens stamping itself: a subagent's write may be denied, and a read-only lens must stay read-only.

**Time source**: `date +%s` at each stamp, so seconds are wall time. A lens's seconds run from `dispatch` to the moment the orchestrator records its return. That is a few seconds late at most, and it is stated in the doc.

## R6. The severity counts' one source

**Decision**: `.delivery-kit/runs/<feature>/findings-I.txt`, written by the orchestrator. Each line is `SEVERITY | lens | file:line | finding | outcome`, where outcome is `fixed`, `deferred` or `declined`. The skill's four-field finding line gains the outcome when the fixes end. Blank lines and `#` lines are allowed.

**Rationale**: The orchestrator already turns every finding into that line. A fixed name in the run directory means no path goes through a shell or into a message. Finding text is data: it is never printed, and a refusal names only the line number.

**Parsing**: The first field is the severity, the second the lens, and the last the outcome, so a `|` in the finding's own text does no harm. A line that fails is counted as unreadable, and its number is recorded and printed. It is not counted as nothing.

## R7. Re-entry

**Decision**: A second `start` of a part moves the old record to `measurements.i.earlier`, and says so. A second `done` refuses and prints the recorded value. So no number is silently doubled or lost.

## R8. Proof runs

To be filled in at the end of piece 1: the passes under load, the load used, and a real base suite on the fixed code.
