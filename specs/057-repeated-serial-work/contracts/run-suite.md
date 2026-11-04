# Contract: scripts/run-suite.sh

```text
bash scripts/run-suite.sh [<root>...]
```

Run from the repository root. With no argument, the roots are `tests handoff/tests pipeline/tests team/tests`. The arguments exist for the script's own tests.

`BATS_BIN` overrides the test runner. The default is `$HOME/bats/bin/bats`.

## Output

- **stdout**: one TAP report. Line 1 is the plan, `1..<sum of each file's plan>`. Then each file's lines, the roots as given and each sorted, with the file's first plan line dropped and each test line renumbered from 1 to N. A failing test's output comes as `--print-output-on-failure` gives it. A carriage return at a line's end is stripped, as `tap-check` does. Every other line passes through unchanged.
- **stderr**: nothing on a green run. On any other run, one line per fault, each starting `run-suite: `, after the report: the pipeline keeps stdout and stderr in one file, and `tap-check` reads the plan as its first line. A message names a path only as the root or file name it was given.

## Exit status

| Row | Situation | Status | stderr names |
|---|---|---|---|
| R1 | Every file exited 0, has one plan, its test lines match the plan, and the total is at least 1 | 0 | nothing |
| R2 | A file's process exited non-zero | 1 | the file and its status |
| R3 | A file printed no plan line | 1 | the file |
| R4 | A file printed more than one plan line | 1 | the file |
| R5 | A file's count of test lines differs from its plan | 1 | the file and both counts |
| R6 | A file's test line has no number | 1 | the file |
| R7 | A file left no exit status, because its worker died or its status file was removed | 1 | the file |
| R8 | The total of all plans is 0 | 1 | that no test ran |
| R9 | `xargs` itself failed. What it left running is stopped | 1 | its status |
| R10 | The test runner is missing | 2 | the variable to set, and no machine path |
| R11 | A root does not exist, is a file, would read as a `find` expression, or holds no `*.bats` file | 2 | the root |
| R12 | The temporary folder could not be made | 2 | that fact |
| R13 | The script was stopped by TERM, INT or HUP. What ignores TERM gets KILL after 3 seconds | 143 | that fact |
| R14 | `find` failed under a root. `bats -r` carries on here, and this refuses, because fewer files must not read as green | 2 | the root |
| R15 | A test number repeats, or lies outside the file's plan. Renumbering would hide it from `tap-check` | 1 | the file |
| R16 | A file's plan line is too large to be real | 1 | the file |
| R17 | The report could not be written | 1 | that fact |
| R18 | A file's plan line is not its first line | 1 | the file |

R2 to R9, and R13 to R18 where it ran, still print the report, so the failing output is there to read.

## Rules

- Half the CPUs, at least 2 and at most 8 files, run at once. See research R3.
- Each file has a `TMPDIR` of its own, inside the temporary folder.
- Every exit but a SIGKILL removes the temporary folder. A stop also stops the test processes. A SIGKILL to the script cannot be trapped, and its test files then run on.
- The script never changes a file in the repository.
- A `# skip` line and a stray line pass through unchanged. The script does not judge them: `tap-check` does, and its verdict decides the suite record.
