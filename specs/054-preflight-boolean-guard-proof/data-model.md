# Data model: 054 preflight boolean guard proof

## Mutant

| Field | Meaning |
|---|---|
| `var` | the `--argjson` variable flipped to `--arg` (derived, research R5) |
| `fields` | the report paths that variable fills (for `gh`: `capabilities.gh`, `remote.ghPresent`) |
| `line` | the mutated line, as it stands in the mutated file |
| `red` | every test in `pipeline/tests/preflight.bats` that failed, by name |
| `verdict` | see below |

Verdicts, decided from `red` alone, with no hand-written map of guards:

- `CAUGHT`: at least one test other than the FR-012 walk is red, and, on the
  finished branch, the walk is red too.
- `HOLE`: no test is red.
- `WALK-ONLY`: only the FR-012 walk is red (finished branch): the field has no
  guard of its own.
- `NO-WALK`: tests other than the walk are red, but the walk is not
  (finished branch): the walk missed a string boolean.
- `NO-OP`: the file did not change. `BAD`: the mutant fails `bash -n`, or its
  `--argjson <var> "` text does not occur exactly once.

The record then names, for each row, which red test is the field's guard: a
test whose red line reads that field (FR-003).

## Measurement record (`measurements.md`)

Two tables, one per run (SC-005). Each table is headed with the commit it ran
against, the date, the rig command and the control: the unmutated worktree's
`preflight.bats` result, which must be green. Each row is one Mutant.

Rules:

- On the base commit, `HOLE` is a finding, not a failure.
- On the finished branch, every row MUST be `CAUGHT` (FR-011). Any other
  verdict, `WALK-ONLY` included, fails the rig.
- `NO-OP` or `BAD` fail the rig on either run (FR-002).
