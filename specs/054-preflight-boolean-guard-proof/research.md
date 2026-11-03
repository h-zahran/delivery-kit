# Research: 054 preflight boolean guard proof

## R1. What counts as a type guard

- **Decision**: an assertion that checks `type == "boolean"`, or compares the
  field with a JSON boolean (`== true`, `== false`, `== $w` with `--argjson`).
- **Rationale**: in jq, `"true" == true` is false, so a comparison with a
  boolean goes red on a string as surely as a `type` check does. A pattern
  over `jq -r` text is not a guard: `-r` prints the string `"true"` and the
  boolean `true` as the same word.
- **Alternatives considered**: counting only `type == "boolean"` lines. That
  search is what made the clarify question claim no guard exists for
  `speckit.constitutionSet`, `tree.dirty` and `capabilities.gitUsable`, which
  is wrong for all three (see the spec's Clarifications correction).

## R2. Which fields need a new assertion

- **Decision**: the base-commit mutant run decides. A mutant that leaves
  `preflight.bats` green marks a field that needs one assertion.
- **Rationale**: Principle II. A search is a claim; the run is a measurement.
- **Expected, not assumed**: `sk_present` and `sk_in_range` green (HOLE);
  the others red.

## R3. Where a new assertion goes

- **Decision**: in an existing test that already reads that field, before any
  other line in it that the mutant would turn red, and after the `status`
  check.
- **Rationale**: a bats test stops at its first failing line. A new
  assertion placed after a line the mutant already turns red never runs, so
  the mutant could not prove it.
- **Candidates** (confirmed by the base run, not by this note):
  `speckit.present` in "the no-speckit fixture reports the tool absent";
  `speckit.versionInRange` in "the web fixture reads version and sh flavour".

## R4. The FR-012 walk

- **Decision**: one new test probes one fixture and asserts
  `[.. | strings | select(. == "true" or . == "false")] | length == 0`.
- **Rationale**: every boolean variable is present in every report, whatever
  its value, so one fixture reaches all of them. A `--arg` mutant emits
  `"true"` or `"false"`, which the walk catches for any field, present or
  future.
- **Limit, stated**: some string fields carry text the caller supplies
  (`featureBranch`, `specDir`, `commitTrailers`, run names). A caller could
  name a branch `true`. The test runs on a fixture whose supplied strings are
  none of these words, and says so in a comment. It is a guard on the
  report's construction, not on its inputs.
- **Alternatives considered**: one `type` line per field (a hand list that
  goes stale, Principle V); a JSON schema (a new dependency).

## R5. Deriving the mutant list

- **Decision** (revised at phase I review): by measurement, not by parsing.
  The rig finds the report template (the `jq -n` call through the line `}'`),
  flips each `--argjson <var> "` in it in a scratch copy, probes once, and
  takes as that var's fields the paths that were booleans and became strings.
  A var whose flip changes no boolean (an array) is not a mutant. A boolean
  no var fills (the literal `jq: true`) is printed as `unmutable`, not
  dropped. The rig refuses to run if any of the spec's seven is missing.
- **Rationale**: Principle V. The first version mapped a path's last key
  through `key: $var` text anywhere in the script, first match winning; a
  second `dirty:` or `present:` anywhere would have flipped the wrong
  variable with no error (phase I review). Measuring each flip cannot
  mis-map.
- **Expected**: nine vars: `sk_present`, `sk_in_range`, `sk_const`, `gh`,
  `adb`, `git`, `git_usable`, `dirty`, `runs_live`.

## R6. Rig safety

- **Decision**: the rig makes one `git worktree add --detach` of the commit
  under a `mktemp -d` folder and never edits a file in it. Each mutant is a
  scratch copy of the worktree's `pipeline/scripts/`, and the suite is pointed
  at it with `PREFLIGHT_UNDER_TEST`, the hook `preflight.bats` already has for
  mutation runs. The rig refuses a mutant whose `cmp` finds no change (NO-OP)
  or that fails `bash -n`, and at the end checks with `cmp` that the
  worktree's script still equals `git show <commit>:pipeline/scripts/preflight.sh`.
  Each bats run is wrapped in `timeout`. It removes only the worktree it made.
- **Rationale**: Principle III and the memory records on rigs: an orphaned
  rig once mutated a tracked file; a no-op `sed` once made a false green.
- **Added at phase I review**: `timeout` puts itself in a process group of
  its own, so cleanup kills each running suite's group by its leader's PID,
  not the subshell above it; only the current batch is signalled; `TMPDIR` is
  made absolute; a commit whose `preflight.bats` lacks the
  `PREFLIGHT_UNDER_TEST` hook is refused; a run that timed out or was cut
  short is `INCOMPLETE`, never a verdict.
- **Scope, stated**: each mutant runs `pipeline/tests/preflight.bats` only.
  HOLE means no test in that file went red, not that the whole suite stayed
  green; other suites that run the script were not measured.
