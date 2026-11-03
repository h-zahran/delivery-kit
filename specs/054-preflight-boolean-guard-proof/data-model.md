# Data model: 054 preflight boolean guard proof

## Mutant

| Field | Meaning |
|---|---|
| `var` | the `--argjson` variable flipped to `--arg` inside the report template (derived, research R5) |
| `fields` | the report paths that variable fills (for `gh`: `capabilities.gh`, `remote.ghPresent`) |
| `line` | the mutated line, as it stands in the mutated file |
| `red` | every test in `pipeline/tests/preflight.bats` that failed, by name |
| `verdict` | see below |

Verdicts. The field's own guard is red when some failing command, read
back from the line bats reports to the start of that command, reads one of
the var's fields as `.<key>` (FR-011). No hand-written map of guards.

- `CAUGHT`: the own guard is red, and, on the finished branch, the FR-012
  walk is red too.
- `ELSEWHERE`: tests are red, but no failing command reads the field.
- `HOLE`: no test is red.
- `WALK-ONLY`: only the walk catches it (finished branch): no own guard.
- `NO-WALK`: the own guard is red but the walk is not (finished branch).
- `NO-OP`: the file did not change. `BAD`: the mutant fails `bash -n`, or its
  `--argjson <var> "` text does not occur exactly once in the template.
- `INCOMPLETE`: bats exited other than 0 or 1 (124 is the time limit), or the
  plan line's count differs from the ok plus not-ok lines.
- `MISSING`: the mutant wrote no result.

## Measurement record (`measurements.md`)

Two tables, one per run (SC-005). Each table is headed with the commit it ran
against, the date, the rig command and the control: the unmutated worktree's
`preflight.bats` result, which must be green. Each row is one Mutant.

Rules:

- On the base commit, `HOLE` and `ELSEWHERE` are findings, not failures.
- On the finished branch, every row MUST be `CAUGHT` (FR-011). Any other
  verdict fails the rig.
- `NO-OP`, `BAD`, `INCOMPLETE` and `MISSING` fail the rig on either run
  (FR-002), and so does an incomplete or red control.
