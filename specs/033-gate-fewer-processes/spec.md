# Feature Specification: The release gate starts fewer processes, and its walk is tested on its own

**Feature Branch**: `033-gate-fewer-processes`

**Created**: 2026-10-08

**Status**: Draft

**Input**: Seed `## Phase 33: the release gate starts fewer processes, and
its walk is tested on its own` from `main-plan.md`, quoted verbatim in the
run's `seed.md`.

## Context

Audit item 11 — the whole-tool audit of 2026-10-06, its R1 (merge the
gate's `jq` reads) and R2 (move the heading walk out of the single-quoted
string and test it directly). The owner's plan for audit items 9 to 15
sends this one item through the pipeline, because it changes the gate
every fork pull request meets. Nothing here is inside a plugin:
`scripts/`, `tests/` and `specs/` belong to the repository, so no plugin
is released; the next release (pipeline 1.4.0) comes after item 15. The
ruling on doubt still binds: a wrong refusal is acceptable, because it
fails closed and the owner fixes the tree; a wrong pass is not.

Measured 2026-10-08 at `main` = `2b38f74` (Windows, Git Bash, jq 1.8.1):

- **One gate run on the real tree takes 2.4 to 2.9 s** (2,386, 2,657 and
  2,929 ms, three runs). It starts 14 `jq` processes: two for the
  marketplace and six for each of the two plugins.
- **`tests/portability.bats` starts the gate 210 times** and took 535 s
  alone (52 tests; counted on a throwaway copy of the gate with one added
  line, so the three tests that read the gate's own bytes were red there
  and only there). Its slowest tests: "the gate reads only a regular
  changelog of bounded size" 27.3 s, "--released refuses a dangling
  Unreleased heading…" 23.8 s, three more `--released refuses …` tests
  between 22.2 and 23.2 s. The per-test limit is 60 s.

**Every `jq` process the gate starts, at `2b38f74`
(`scripts/check-versions.sh`):**

| Line | File | What it reads | Its own failure message |
|---|---|---|---|
| `:174` | marketplace | the shape check (`market_shape`), once | not one object whose plugins is a list…; not valid JSON |
| `:320` | each `plugin.json` | the shape check (`plugin_shape`) | not one object with a string name and version…; not valid JSON |
| `:326` | each `plugin.json` | `.name // empty` | could not be read |
| `:328` | each `plugin.json` | `.version // empty` | could not be read |
| `:360` | marketplace, per plugin | is there an entry named like the plugin | no marketplace entry named … |
| `:362` | marketplace, per plugin | that entry's `.version // empty` | could not be read |
| `:375` | marketplace, per plugin | that entry's `.source // empty` | could not be read |
| `:766` | marketplace, once | every entry's name and source, as `@tsv` | could not be read |

**A recorded decision this feature overrides.** The comment at
`scripts/check-versions.sh:347-353` says the three marketplace queries are
"deliberately NOT collapsed into one", because they carry three different
diagnostics (no entry, an entry with no version, an entry with no source),
and "the saving was measured at two process spawns per plugin. Clarity
wins." This feature collapses them anyway, on the audit's measurement
that the spawns are most of the suite's cost. The three diagnostics stay
three (FR-002); the comment is replaced by one that states the new
mechanism and why, never left describing code that is gone.

**The heading walk** is an awk program of 184 lines (`:545-728`) inside
one single-quoted bash string that opens on `:544` and closes on `:729`
of `scripts/check-versions.sh`, run only for the plugin
named by `--released`, on its `CHANGELOG.md`, with `DATED_RE`,
`LINE_LIMIT` and `QUOTE_CUT` in its environment and `LC_ALL=C`. Its
output is the refusal text; bash then shows `##[` as `#?[` (`:732`) and
stops with the plugin's name and "this tree is NOT released". It can be
tested only by running the whole gate on a copied tree. An apostrophe in
one of its comments ends the string; that has broken the gate before.

## Clarifications

### Session 2026-10-08

- Q: Should the gate refuse its own walk file when that file is a symbolic link? → A: No (option B): the walk file is code with the gate's own trust, no link rule; the departure from the seed is recorded in research (FR-006).
- Q: Where should the old-versus-new comparison of the gate live after this feature merges? → A: A one-time quickstart step against `2b38f74`, its result recorded in research; no frozen copy of the old gate; the suite's message tests guard the merged tree (option B, FR-003).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One read per file, every message unchanged (Priority: P1)

A maintainer or a fork pull request runs the gate, in either form. It
reads each `plugin.json` with one `jq` process and the marketplace with
one, and prints and exits exactly as the gate at `2b38f74` does, on every
tree the suite builds.

**Why this priority**: the gate runs on every pull request and in 210
places of the suite; the spawns are most of its cost. But a faster gate
that says something different is a regression in a security gate, so
byte-identity is part of the story, not a follow-up.

**Independent Test**: run the old gate (`2b38f74`) and the new one over
the same fixture set, in both forms, and compare standard output,
standard error and exit status; the difference is empty but for the
asserted Windows set of FR-002. Count the `jq` processes of one run on the
real tree.

**Acceptance Scenarios**:

1. **Given** the real tree, **When** either form runs, **Then** it prints
   and exits exactly as at `2b38f74`, and starts one `jq` process per
   `plugin.json` plus one for the marketplace.
2. **Given** a fixture where the marketplace has no entry named like a
   plugin, or an entry with no version, or with no source, **When** the
   gate runs, **Then** each prints its own message, as at `2b38f74`.
3. **Given** a `plugin.json` or `marketplace.json` that is malformed,
   unreadable, of the wrong shape, or holds a NUL, **When** the gate runs,
   **Then** each prints the same message as at `2b38f74`, and no `jq:` line
   reaches the output.
4. **Given** a name, version or source holding a tab, a line feed, a
   carriage return, a backslash, `##[`, a byte that is not valid text, or
   a value longer than the cut, **When** a message names it, **Then** the
   printed bytes equal those at `2b38f74`.

---

### User Story 2 - The walk lives in its own file and is tested on its own (Priority: P1)

A contributor changing how the release form judges a changelog edits a
plain awk file, and tests it by feeding it a changelog on standard input,
without building a copied tree or starting the gate.

**Why this priority**: most of the 210 spawns test changelog forms only;
and a program inside a single-quoted string breaks on an apostrophe.

**Independent Test**: the walk file run on a changelog on standard input,
with the gate's three environment values, prints the same refusal text
the gate's walk printed for that changelog; the gate's own output on the
real tree is unchanged.

**Acceptance Scenarios**:

1. **Given** the gate run from any working directory (as the suite runs
   it, from a fixture), **When** the release form reaches the walk,
   **Then** it runs the walk file that sits beside the gate.
2. **Given** the walk file missing or unreadable, **When** the release
   form reaches the walk, **Then** the gate stops with its own message,
   exit 1, never 0.
3. **Given** a changelog on standard input, **When** a test runs the walk
   file directly, **Then** it prints the refusal text the gate prints for
   that changelog (before the gate's own prefix and suffix), or nothing
   for a changelog the gate accepts.

---

### User Story 3 - The suite gets faster, and says by how much (Priority: P2)

The maintainer sees, recorded once, how long `tests/portability.bats` and
one gate run took before and after, measured on the same machine.

**Why this priority**: the speed is the reason for the change; it must be
measured, not asserted (Principle II), but it is not itself a gate.

**Independent Test**: alternate runs of the old and new tree on one
machine, and record the wall times in one dated table in research.

**Acceptance Scenarios**:

1. **Given** the measurement, **When** the research is read, **Then** it
   names the `jq` processes per run before and after, one gate run's time
   before and after, and `tests/portability.bats`'s time before and after.

---

### Edge Cases

- Two marketplace entries with the same name: at `2b38f74` the per-plugin
  version and source reads print one line per matching entry. The merged
  read reproduces what the old gate printed and how it exited, proved by a
  fixture in the differential.
- A name, version or source that is `false`, `null` or missing: `// empty`
  made it empty at `2b38f74`, and its own "has no …" message fired. Same
  after.
- A value holding the merged read's field separator: impossible by
  construction, or refused, never split wrongly.
- Windows jq writes a CR before each line feed; the CR must never reach a
  value (`jq -b`, or the CR removed where it is read).
- A marketplace listed past `entries_limit`, a source past
  `source_limit` or `component_limit`, a link anywhere on a source's path:
  every Phase 27 and 28 refusal fires in the same order as at `2b38f74`.
- The walk file under the C locale: the gate passes `LC_ALL=C` to the walk
  as today; a test of the walk does too.
- An apostrophe in the walk file is ordinary text: a test runs a copy of
  the gate beside a copy of the walk file with one added in a comment, and
  the gate still runs (the shipped walk file's text is not changed).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001 One process per file.** The gate starts one `jq` process for
  the marketplace (its shape and its entry list) and one for each
  `plugin.json` (its shape, name and version, and that plugin's three
  marketplace answers: is there an entry, its version, its source), per
  gate run, in both forms: 1 + N processes for N plugins. On the real
  tree that is 3 instead of 14. The seed asked for the per-plugin
  marketplace answers to come from the one marketplace read; that would
  cut every entry apart in bash, which was measured quadratic (a
  132,000-byte list took 2.4 s, a 528,000-byte one 39.4 s), and a fork
  sets the list's size. Research records this departure and the count
  before and after, measured.
- **FR-002 Every message stays byte-identical.** Both forms
  (`check-versions.sh` and `check-versions.sh --released <plugin>`) print
  the same standard output and standard error and exit with the same
  status as at `2b38f74`, on every fixture the suite builds and on the
  differential's own fixtures. The three marketplace diagnostics of
  `:347-353` stay three messages. A malformed file, an unreadable one and
  a missing one stay distinguishable (Phase 28, requirement 2). Every
  value still passes through `shown` before it is printed. No `jq:` line
  reaches the output. Two new messages exist, each reachable only through
  a broken installation of the gate itself (FR-006, the contract). On the
  fixtures that exist today, one difference is intended, and asserted
  rather than allowed: on Windows the old gate's `jq -r` wrote a CR before every
  line feed inside a value, and Git Bash kept it (measured: a name
  `a\nb` read as `a\r\nb`), so the same JSON gave different values on
  Windows and on Linux. The new gate gives the Linux bytes on every
  system. The same holds for entries sharing a name, whose values were
  read one per line. A value ending in a CR, or in line feeds, read the
  same on both systems before and still does (measured). The
  differential, run on Windows,
  asserts it: the fixture LF1 (a plugin name holding a line feed, printed
  by the mismatch line) must differ; a run whose tree holds such a value
  or such a name may differ; any other run must not (research R5, R10).
- **FR-003 Proved by a differential.** A differential runs the gate at
  `2b38f74` and the new gate over the same fixture set, in both forms, and
  compares standard output, standard error and exit status; the
  difference is empty but for the asserted Windows set of FR-002, which
  must appear on Windows and nowhere else. The fixture set holds at least every fixture shape
  `tests/portability.bats` builds plus the edge cases above. It runs once,
  as a quickstart step against `2b38f74` read from git history (CI clones
  one commit, so it cannot run there), and its result is recorded in
  research; no frozen copy of the old gate is kept. It is shown able to go
  red: a mutant that changes one message by one byte turns it red. After
  the merge, the suite's existing message tests guard the messages.
- **FR-004 Three jq versions agree.** The merged reads give the same
  values under jq 1.7, 1.8.1 and 1.8.2. Any output split by `read`,
  `mapfile` or a process substitution uses `jq -b`, or removes the CR
  where it is read. No separator splits the values: every character but
  NUL can sit in a JSON string, and a NUL cannot cross a command
  substitution, so each value is written with its length in bytes before
  it (research R4). This replaces the seed's "a field separator no value
  can hold … is chosen and stated"; research R12 records the departure. Two traps broke a
  one-`jq` refactor in this repository before: jq's `+` joins two strings
  rather than failing, and `jq -r` prints the boolean `true` and the
  string `"true"` the same. The boolean is covered by a fixture (a
  version `true`, refused by the shape check). The `+` is covered by
  construction: every `+` in the new programs joins strings on purpose,
  each operand a string the shape check guarantees or a length the
  program writes, and research R1 states it.
- **FR-005 The walk lives in its own file.** The awk program moves to a
  file under `scripts/` beside the gate. Its text does not change: the
  moved program is proved byte-identical to the old single-quoted body,
  less the quoting. One rule follows it, and changes no judgement: it
  prints an end token as the walk's last line (FR-006; added at phase I,
  research R12). If the program must change, the proof
  (`specs/025-gate-closes-phase25-gaps/proof/enumerate.py`) is rerun and
  must report 0 wrong passes and each control at least 1.
- **FR-006 The gate finds the walk beside itself.** The gate locates the
  walk file from its own path (`BASH_SOURCE`), never from the caller's
  working directory. A missing or unreadable walk file stops the gate with
  its own message and exit 1, and so does a walk whose output does not end
  with its end token (an empty walk file, or one of comments alone, runs
  an empty program and exits 0), so the release form can never exit 0
  without the walk having run to its end. The walk file is code, with
  the gate's own trust, not data from the tree being judged: no
  symbolic-link rule applies to it. This departs from the seed's sentence
  that the Phase 27 and 28 link rules apply to it; research records the
  departure and its reason (CI runs the pull request's own `scripts/`, so a
  link rule on the gate's own file would protect nothing).
- **FR-007 The walk is tested on its own.** Tests run the walk file
  directly on a changelog on standard input, with `DATED_RE`,
  `LINE_LIMIT` and `QUOTE_CUT` in the environment as the gate passes them,
  `LC_ALL=C`, and no `jq`. Changelog forms the suite now checks by spawning
  the whole gate move to these direct tests wherever nothing but the walk
  is under test. Enough end-to-end gate tests stay to prove the gate and
  the walk are joined, and to keep each refusal's full line (prefix,
  masking, suffix) pinned. The seed asked the spec to list which stay;
  the list is derived from the test file and lives in research R8, beside
  the inventory it comes from.
- **FR-008 The direct tests read the same values as the gate.** The
  values the direct tests pass (`DATED_RE`, `LINE_LIMIT`, `QUOTE_CUT`) are
  the gate's own, read from the gate or proved equal to it, so a change to
  the gate's pattern cannot leave the direct tests testing an old one.
- **FR-009 Nothing else moves.** CI and the suite still call the one
  script; the walk file is run by the gate, never by CI, and a test of
  the whole gate reaches it only through the gate (only the direct walk
  tests of FR-007 run it themselves). The "one
  version-agreement script, and both gates call it" test stays green
  unchanged. The P0 print-site scan (`die_raw`) still reads the gate;
  research R8 says whether it also reads the walk file, and why (the seed
  asked the spec to say it; the answer is recorded there). The
  heading walk's comments keep their meaning; a comment in the gate that
  described the moved text or the merged reads is updated in the same
  change, never left describing code that is gone.
- **FR-010 The shipped root surface.** The walk file is under `scripts/`,
  so its comments obey the root surface's rules: STRICT vocabulary, no
  machine path, no count in prose.
- **FR-011 Portability.** Bash 3.2 and every awk CI runs (gawk, and the
  BSD awk on macOS); no interval expressions in awk patterns; never `\/`
  inside a pattern substitution. Every byte tool the gate, the walk or the
  tests run on a file that may hold a byte which is not valid text runs
  under `LC_ALL=C`. A locale-dependent rule is tested with `LANG` set to a
  UTF-8 locale and `LC_ALL` unset.
- **FR-012 Tests match in the shell.** A new or moved test matches text
  in the shell (`[[ $s == *"$want"* ]]`), never with `grep … < <(printf
  …)`, which on Git Bash reported a match that was not there in 43 of
  1,800 calls under load (measured 2026-10-08).

### Key Entities

- **The gate**: `scripts/check-versions.sh`, called by CI's version job,
  its release-tag job, and the suite.
- **The walk file**: the heading walk, moved out of the gate into its own
  awk file under `scripts/`.
- **The differential**: the old gate and the new one, run over one fixture
  set in both forms, compared byte for byte.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `jq` processes per gate run on the real tree: 14 at
  `2b38f74`, 3 after (one for the marketplace, one per `plugin.json`),
  measured.
- **SC-002**: The differential over every fixture, in both forms, reports
  no difference but the asserted Windows set (present on Windows, absent
  elsewhere), and goes red on a one-byte message mutant.
- **SC-003**: `tests/portability.bats` alone and one gate run on the real
  tree are each measured before and after on the same machine,
  alternating runs, and recorded in one dated table. No target is set;
  the record is the outcome. No test in the file takes over 40 s alone on
  Windows.
- **SC-004**: A mutant that drops each new rule turns its test red, naming
  its clause: a missing walk file, an unreadable one, the walk found from
  the caller's directory, a field split that loses or moves a value.
  Each mutation is confirmed to have landed before its red is believed.
- **SC-005**: The feature quickstart, run as one script, ends ALL OK.
- **SC-006**: Full house suite from the repo root: `1..426` at
  `2b38f74`, plus the tests this feature adds, minus those it moves; the
  exact count is fixed in tasks and judged by `bash
  scripts/check-suite.sh <that count>`.
- **SC-007**: CI green on all three operating systems; a run is confirmed
  to EXIST before its result is read, and every job's steps are read.

## Assumptions

- The INSTALLED pipeline 1.3.1 runs this feature: G asks the review
  question; there is no pending-question queue and no suite reuse.
- The shape checks at `:174` and `:320` are kept as the first thing done
  with each file; merging may fold a read into the shape check's own
  process only where its exit status still separates "not valid JSON"
  (any status but 0 and 1) from "wrong shape" (1).
- The order in which the gate's checks fire is part of its output: on a
  tree with two faults, the same fault is reported first after as before.
- Not in this feature: running test files in parallel (audit R5), moving
  the gate tests into their own file (R6), resolving `ROOT` once per file
  (R10), a timing warning in CI (R11), a release script (R9).
- Changelog routing: none; nothing inside a plugin changes.
