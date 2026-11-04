# Contract: scripts/run-suite.sh

```text
bash scripts/run-suite.sh [<root>...]
```

Run from the repository root. With no argument, the roots are `tests handoff/tests pipeline/tests team/tests`. The arguments exist for the script's own tests.

`BATS_BIN` overrides the test runner. The default is `$HOME/bats/bin/bats`.

## Output

- **stdout**: one TAP report. Line 1 is the plan, `1..<sum of each file's plan>`. Then each file's lines, in sorted file order, with the file's own plan line dropped and each test line renumbered from 1 to N. A failing test's output comes as `--print-output-on-failure` gives it. Every other line passes through unchanged.
- **stderr**: nothing on a green run. On any other run, one line per fault, each starting `run-suite: `. A message names a path only as the root or file name it was given.

## Exit status

| Row | Situation | Status | stderr names |
|---|---|---|---|
| R1 | Every file exited 0, has one plan, its test lines match the plan, and the total is at least 1 | 0 | nothing |
| R2 | A file's process exited non-zero | 1 | the file and its status |
| R3 | A file printed no plan line | 1 | the file |
| R4 | A file printed more than one plan line | 1 | the file |
| R5 | A file's count of test lines differs from its plan | 1 | the file and both counts |
| R6 | A file's test line has no number | 1 | the file |
| R7 | A file left no exit status, because its worker died | 1 | the file |
| R8 | The total of all plans is 0 | 1 | that no test ran |
| R9 | `xargs` itself failed | 1 | its status |
| R10 | The test runner is missing | 2 | the variable to set, and no machine path |
| R11 | A root does not exist, or holds no `*.bats` file | 2 | the root |
| R12 | The temporary folder could not be made | 2 | that fact |
| R13 | The script was stopped by TERM or INT | 143 | that fact |

R2 to R9 still print the report, so the failing output is there to read.

## Rules

- At least 2 and at most 8 files run at once. See research R3.
- Every exit removes the temporary folder. A stop also stops the test processes.
- The script never changes a file in the repository.
- A `# skip` line and a stray line pass through unchanged. The script does not judge them: `tap-check` does, and its verdict decides the suite record.
