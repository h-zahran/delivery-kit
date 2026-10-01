# Research: The release gate reads the whole changelog, and one suite check

All measurements at `main` = `5831822`, 2026-10-01.

## R1 — Where the release rule lives, and how it reads the file

- **Spelling**: the awk regex spells repetitions out —
  `[0-9][0-9][0-9][0-9]`, never `[0-9]{4}` — as the repository's own awk
  fixtures do (`tests/portability.bats`): an awk without interval
  expressions would read every dated heading as undated and refuse the
  real tree on that system only.
- **Decision**: inside the existing `if [ "$p" = "$RELEASED" ]` block of
  `scripts/check-versions.sh`, after today's first-heading comparison. One
  `awk` pass over `./$p/CHANGELOG.md` prints the first line that begins
  `## ` and is not exactly a dated version heading, as `<line>:<text>`; a
  non-empty result dies with
  `$p: line <n> holds '<text>', which is not a dated version heading — this tree is NOT released`.
- **Rationale**: the block is the only place the release form acts, so the
  default run is untouched (FR-002). `awk` exits 0 whether or not it finds
  a line, which matters under `set -euo pipefail`: a `grep -v` pipeline that
  selects nothing exits 1, and the assignment would abort the script with no
  message. The existing first-heading check stays as it is, so a heading
  ABOVE the release still gets today's message (the existing test reads
  "is NOT released", which both messages carry). The heading text is
  printed with line breaks stripped, as the report line already does.
- **Alternatives considered**: replacing the first-heading check with the
  new one (rejected: it changes a message a test pins, for no gain);
  matching only `Unreleased` spellings (rejected at clarify).

## R2 — The suite check's rules

- **Decision**: `scripts/check-suite.sh <expected> <tap-file>`, one `awk`
  pass after stripping a trailing CR from each line. Rules, each with its own
  message: `<expected>` is a positive integer; the file exists and is not
  empty; line 1 is exactly `1..<expected>` and no other line is a plan line;
  the count of lines beginning `ok ` equals `<expected>`; no line beginning
  `ok ` carries `# skip` (any case); no line begins `not ok `; every other
  non-blank line begins `#`. Exit 0 prints one summary line
  (`suite ok: 1..N, N ok, 0 skipped, 0 not ok, 0 non-TAP`).
- **Shape**: each rule K2–K11 is one line ending `# K<n>` (contract);
  compound rules are written as `if`, never `A && B || C`, which the
  shellcheck CI runs (0.9.0) reports; the awk regexes spell repetitions out,
  as R1 says.
- **Rationale**: these are exactly the rules the eleven copies apply between
  them, plus the skip count only two had. A plan line not on line 1, or a
  second plan line, is how a crashed or concatenated run looks. Blank lines
  are ignored, as the copies ignore them. No message prints the file's path:
  a caller's temp path can carry a user name, and the gate script keeps the
  same rule.
- **Alternatives considered**: also taking bats' exit status (rejected: a
  failed test already shows as `not ok`, and a crash as a short count; one
  more argument is one more thing a caller can get wrong); a `TODO` rule
  (bats emits none).

## R3 — Where the two tests go

- **Decision**: the release-rule test goes in `tests/portability.bats`,
  beside "--released refuses a dangling Unreleased heading", and calls the
  gate only through `run bash -c "…"`. The suite-check test goes in a new
  `tests/check-suite.bats`.
- **Rationale**: the "one version-agreement script" test counts lines
  matching `run bash <word>.sh` in `tests/portability.bats` and requires
  exactly one; `run bash -c` does not match, and the existing release test
  already uses it. A `run bash scripts/check-suite.sh` line in that file
  would make the count two. A new file is picked up by `-r`.
- **Alternatives considered**: putting both tests in one new file (rejected:
  the release test reuses the fixture shape that lives in
  `tests/portability.bats`).

## R4 — What `CONTRIBUTING.md` says

- **Decision**: one paragraph in "Running the tests", after the paragraph on
  naming every suite path: a feature quickstart that needs to prove the suite
  passed saves the output and calls
  `bash scripts/check-suite.sh <expected> <tap-file>` instead of writing its
  own check, because hand-written copies drift.
- **Rationale**: that section is where a contributor learns to run the suite.
  STRICT surface: no count, no banned word, no path.

## R5 — The note on clause C4

- **Decision**: a blockquote inserted after C4's last paragraph and before
  `## C5`, starting `> **Later note, 2026-10-01 (feature 023):**`, stating
  that since 1.2.0 a tag run's agreement step passes `--released`, so C4 is
  enforced for the plugin being tagged, and that since 023 the release form
  also refuses an undated heading anywhere in the file.
- **Rationale**: the record is dated history (constitution, "Changelogs are
  history"; the same rule binds a dated record). Adding lines leaves every
  existing line byte-identical, which `git diff 5831822 -- <file>` checks
  (only `+` lines).

## R6 — bash 3.2

- **Decision**: the new script and test code avoid `mapfile`, `${var,,}`,
  associative arrays and empty arrays under `set -u`; all counting happens in
  one `awk` program.
- **Rationale**: macOS CI may run the system bash 3.2; the repository has
  been bitten by the empty-array trap before.
