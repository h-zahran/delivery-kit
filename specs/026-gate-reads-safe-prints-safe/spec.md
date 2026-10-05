# Feature Specification: The release gate reads only what it can judge, and prints only what is safe

**Feature Branch**: `026-gate-reads-safe-prints-safe`

**Created**: 2026-10-04

**Status**: Draft

**Input**: Seed `## Phase 27: the release gate reads only what it can
judge, and prints only what is safe` from `main-plan.md`, quoted verbatim
in the run's `seed.md`.

## Context

Phase 26 (`specs/025-gate-closes-phase25-gaps/`, PR #57, merged as
`6fd91f3`) closed every gap Phase 25 left. Its reviews found three older
problems and deferred each, with its reason, in that feature's research
R14. The owner's ruling, 2026-10-04: **close all three.** The ruling on
doubt still binds: a wrong refusal is acceptable, because it fails closed
and the owner fixes the tree; a wrong pass is not. Nothing here is inside
a plugin: `scripts/`, `tests/` and `specs/` belong to the repository, so no
plugin is released.

Measured 2026-10-04 at `main` = `6fd91f3` on a one-plugin fixture built
from `handoff/`:

- **A changelog that is a symbolic link is read wherever it points.** A
  link to `/dev/urandom` ran the default form until it was killed at
  20 s. A link to `/dev/zero` failed on the search tool's own error. The
  NUL check skips anything that is not a regular file. On Linux and
  macOS a committed link is checked out as a link. This machine can make
  one (`core.symlinks` is true); the windows-latest runner is not
  measured.
- **Values read from tracked files are printed raw.** A `plugin.json`
  version of `1.0.0`, a line feed, `::error title=forged::all checks
  passed` and an escape sequence printed a report line holding the
  escape byte, and a `die` message whose second line STARTS with
  `::error`, which a workflow log reads as a command. 2 raw escape bytes
  reached the output.
- **Nothing bounds a changelog's size.** Lines of 499 list markers, each
  passing the walk: 1 MB took the release form 4.1 s, 2 MB 9.2 s and
  4 MB 14.6 s. The real changelogs are 38 KB and 15 KB.

Found while writing this spec, from the script itself: the report line
BEGINS with the plugin's directory name, so a directory named
`::error…` makes that line start with `::` even with every byte masked.

**Every print site, derived from `scripts/check-versions.sh` at
`4016666`** (line numbers there). Values the gate did not write:

| Value | Read from | Printed at |
|---|---|---|
| `p`, the plugin directory name | the working tree | the report line (`:268`, its first field) and every `die` in the plugin loop (`:148`-`:279`, `:498`) |
| `pn`, plugin name | `plugin.json` | `:157`, `:177`, `:179`, `:190`, `:192` |
| `pv`, plugin version | `plugin.json` | the report line, `:273`, `:274` |
| `mv`, marketplace version | `marketplace.json` | the report line, `:273` |
| `ms`, marketplace source | `marketplace.json` | `:192` |
| `cv`, changelog version | the dated heading (digits and dots only) | the report line, `:274` |
| `head`, the dated heading | the changelog (matches the dated pattern) | `:279` |
| `first`, the first heading | the changelog | the report line and `:279`, through `quoted()` already |
| `en`, `es`, entry name and source | `marketplace.json` | `:540`, `:547`, `:556` |
| `RELEASED`, the plugin argument | the command line | `:574` |
| `$1`, an unknown argument | the command line | `:90` |
| the walk's quoted line | the changelog | `:498`, through the walk's `show()` already |
| the plugin path, in another program's own error | the working tree | `jq` opening `plugin.json` (`:146`, `:147`), and `grep` on a missing changelog (`:238`; `:262` is never reached, because the gate dies at `:239`), each on stderr |

The last row was found at analysis (F): another program prints the path
it was given in its own error message, with no masking, and on Windows
native `jq` cannot open a path whose directory name holds `:` or a
control byte at all (measured). FR-014 closes it.

## Clarifications

### Session 2026-10-04

- Q: How large may a changelog be before the gate refuses it, and should the default form refuse too, or only the release form? → A: 256 KB (262,144 bytes), the release form only (FR-003).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The gate reads only a regular changelog of bounded size (Priority: P1)

A pull request from a fork reaches CI. Its changelog is a symbolic link,
or something other than a regular file, or far larger than any real
changelog. Before any tool reads it, the gate refuses it with a message
of its own that names the plugin and the reason. It never hangs.

**Why this priority**: a link to a device hangs the job until the
runner's time limit, and names nothing. That is the worst way a gate can
fail.

**Independent Test**: plant each shape in a fixture and run the gate;
each run ends at once with its message.

**Acceptance Scenarios**:

1. **Given** a plugin whose `CHANGELOG.md` is a symbolic link (to a
   device, or to a regular file), **When** either form runs, **Then** it
   exits non-zero naming the plugin and saying the changelog is a
   symbolic link, and no tool has read through the link.
2. **Given** a `CHANGELOG.md` that exists and is not a regular file (a
   directory), **When** either form runs, **Then** it exits non-zero
   naming the plugin and saying the changelog is not a regular file.
3. **Given** a changelog one byte over the size limit, **When** the
   release form runs, **Then** it exits non-zero naming the plugin, the
   size and the limit; a changelog of exactly the limit is not refused
   for its size, and the default form does not refuse either for size.
4. **Given** a missing changelog, **When** either form runs, **Then** it
   exits non-zero with the gate's own diagnostic line as at `4016666`
   (FR-002).

---

### User Story 2 - Nothing read from a file can write into the log (Priority: P1)

A fork's `plugin.json`, `marketplace.json`, changelog or directory name
holds a line feed, an escape sequence, a byte that is not valid text, or
text shaped like a workflow command. Every value the gate prints is shown
masked and cut, so no output line can start with `::` and no
non-printable byte reaches the log.

**Why this priority**: a forged `::error` line or an escape sequence
misleads whoever reads the CI log, and the gate runs on every pull
request.

**Independent Test**: plant each value in a fixture and run both forms;
read the output for raw bytes and for lines starting with `::`.

**Acceptance Scenarios**:

1. **Given** a plugin version holding a line feed, `::error title=x::y`
   and an escape sequence, **When** the default form runs (the report
   line and these messages are the same in the release form), **Then** the
   output holds no escape byte, no line starts with `::`, and the
   version appears with each non-printable byte shown as `?`.
2. **Given** the same in a marketplace version, name or source, **When**
   the default form runs, **Then** the same holds.
3. **Given** a plugin directory whose name starts with `::`, **When**
   the default form runs, **Then** no output line starts with `::`.
4. **Given** the real tree, **When** either form runs, **Then** it prints
   and exits exactly as at `4016666`.

---

### Edge Cases

- A symbolic link to a regular file inside the repository is refused
  too: the gate does not follow links, and a wrong refusal is acceptable.
- A broken link (to nothing) is a link, refused as one, not reported as
  a missing changelog.
- A changelog over the size limit passes the default form unchanged;
  only the release form refuses it.
- A value longer than the quote cut is cut, with the cut marker, as a
  quoted line is.
- A command-line argument is not read from a tracked file, but it can
  come from a tag name; it is masked too (FR-005).
- The gate's own message text is never masked: it holds an em dash,
  which the C locale would show as `?`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Before any tool reads a plugin's `CHANGELOG.md`, in both
  forms, the gate MUST refuse one that is a symbolic link, naming the
  plugin and saying so, and MUST refuse one that exists and is not a
  regular file, naming the plugin and saying so.
- **FR-002**: A missing changelog MUST keep, in both forms, the gate's
  own diagnostic line it gets at `4016666`
  (`no changelog heading in the pinned '## [X.Y.Z] - YYYY-MM-DD' format`).
  The search tool's own error line, which printed the path raw before
  it, is no longer printed (FR-014).
- **FR-003**: The release form MUST refuse a changelog larger than
  262,144 bytes (256 KB), naming the plugin, its size and the limit,
  before any tool reads its content; the size is read without reading the
  file. The limit is set once in the script. The default form MUST NOT
  refuse for size: it only searches the file, and a run that asked for no
  release must not stop on a large changelog.
- **FR-004**: Every value in the print-site table above MUST be printed
  through one function that shows every byte outside printable ASCII as
  `?` and cuts at the quote cut with the cut marker, as `quoted()` does
  today. `cv` and `head` are printed through it too, though their
  patterns already hold them to ASCII. The one exception is the walk's
  quoted line, which the walk's own `show()` already cuts and masks;
  passing the whole refusal through the function would cut the gate's
  own text.
- **FR-005**: The command-line values (`RELEASED`, an unknown argument)
  MUST be printed through the same function.
- **FR-006**: No line the gate prints MAY start with `::`, with or
  without spaces before it (a workflow log reads a command after leading
  white space). Where a printed value starts a line (the report line's
  first field), its leading spaces and a `:` that directly follows them (or starts the field) MUST be
  shown as `?`.
- **FR-007**: The gate's own message text MUST NOT be masked.
- **FR-008**: On the real tree, both forms MUST print and exit exactly as
  at `4016666`. The walk's four narrowings MUST NOT change; if the
  walk's text changes at all, the narrowing proof
  (`specs/025-gate-closes-phase25-gaps/proof/enumerate.py`) MUST be
  rerun and report 0 wrong passes and each control at least 1.
- **FR-009**: Every byte tool the gate or the tests run on a file or an
  output that may hold a byte which is not valid text MUST run under
  `LC_ALL=C`.
- **FR-010**: Each new rule MUST be shown able to fail: a mutant that
  removes it turns its test red, naming its clause, and the mutation is
  confirmed to have landed.
- **FR-011**: The link test MUST run on all three operating systems
  without a skip, and MUST print, in the test log on a pass as well as a
  failure, which way it took. A link it could not make is a fixture
  failure, except on Windows (Git Bash, MSYS or Cygwin), where the
  runner may not be able to make one: there, and only there, the test
  checks instead what a checkout makes in a link's place (a regular file
  holding the target path), which is refused as having no changelog
  heading. That is a named departure: on such a system the link rule
  itself is not reached, because no link can exist there to reach it.
  The first CI run measures the windows-latest runner, and the pull
  request body reports which way each system took.
- **FR-012**: CI and the suite MUST still call the one script, and the
  "one version-agreement script" test MUST stay green unchanged.
- **FR-013**: The house suite MUST grow from `1..249` to `1..251`: one
  new test for each user story, because each needs its own fixture (a
  changelog that is not a regular file; values in `plugin.json` and
  `marketplace.json`). No test may come near the 60-second per-test
  timeout. Every changed line under
  `scripts/` MUST avoid the banned vocabulary, machine paths and counts
  in prose, and run under bash 3.2 and the awks the three CI systems run.

- **FR-014**: No other program the gate runs, and not the shell, MAY
  print a value from the print-site table in its own error message:
  `plugin.json` is read through standard input, a file the gate reads
  through a redirect is first opened once with the shell's error
  discarded, and a search whose failure the gate reports itself has its
  own error output discarded.
- **FR-015**: A value longer than the quote cut MUST be shown cut, with
  the cut marker; and a value holding a byte that is not valid UTF-8, or
  a printable non-ASCII character, MUST be shown masked when the gate
  runs under a UTF-8 locale, as under the C locale.

### Key Entities

- **Print site**: a place where the gate writes a value it did not
  write itself.
- **Masking function**: the one function every print site goes through.
- **Quote cut**: the most bytes of a value a message shows, 200 today,
  set once in the script; a longer value is cut there and followed by
  the **cut marker**, ` [cut]`.
- **Size limit**: the largest changelog, in bytes, the gate reads.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A changelog that is a link to a device is refused in under
  2 seconds in both forms (today the default form runs until it is
  killed).
- **SC-002**: Across every planted value, the output holds 0 bytes
  outside printable ASCII apart from the gate's own message text, and 0
  lines starting with `::`.
- **SC-003**: A changelog one byte over the limit is refused in under 2
  seconds.
- **SC-004**: On the real tree both forms are byte-identical to
  `4016666`.
- **SC-005**: Each new rule has a mutant that turns a test red.
- **SC-006**: The feature quickstart, run as one script, ends ALL OK; the
  house suite reads `1..<count>` with every test ok, judged by
  `scripts/check-suite.sh <count>`; CI passes on three operating systems,
  a run confirmed to exist and every job's steps read.

## Assumptions

- No plugin changelog gains an entry for this phase: nothing inside a
  plugin changes.
- Every symbolic link is refused, wherever it points: simpler than
  judging targets, and a wrong refusal is acceptable.
- The masking function is today's `quoted()`; its cut length and marker
  stay as they are.
- A size read with `wc -c <` on a regular file took 139 ms for 1 GiB in
  Git Bash, so it reads no content there. On Linux and macOS it is not
  measured; FR-001 sends it only regular files, and the release form's
  limit is checked on a file the tests keep near 256 KB, so even a tool
  that read the whole file stays fast.
- Not in this phase (each recorded in Phase 26's research R14): Windows
  gawk reading a CRLF line end differently; a one-line HTML comment
  keeping later fences refused; a tag that only starts with `pre`,
  `script`, `style` or `textarea`; the 1,000-byte line limit on prose; a
  mechanical check for U1; bats printing a failed test's raw `$output`;
  the quote cut written in both bash and awk; a job time limit in
  `.github/workflows/ci.yml`.
- Not in this phase, found at analysis (F, iteration 2, reasoned from
  the actions runner's source, not measured): the runner's older command
  form `##[…]`. `#`, `[` and `]` are printable, so masking does not
  touch them, and any printed value, not only the report line's first
  field, can carry `##[…]`: the runner's parser for the older form may
  search the whole line (not measured). FR-006 covers `::` only.
  Recorded for a later phase, which should first measure where in a
  line the runner acts on `##[`.
