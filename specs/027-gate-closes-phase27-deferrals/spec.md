# Feature Specification: The release gate closes what Phase 27 deferred

**Feature Branch**: `027-gate-closes-phase27-deferrals`

**Created**: 2026-10-05

**Status**: Draft

**Input**: Seed `## Phase 28: the release gate closes what Phase 27
deferred` from `main-plan.md`, quoted verbatim in the run's `seed.md`.

## Context

Phase 27 (`specs/026-gate-reads-safe-prints-safe/`, PR #59, merged as
`5a78ea4`) closed the three problems Phase 26 deferred, and several older
ones its reviews found. It deferred the rest, each with its reason, in
that feature's research R10, in its spec's Assumptions (the `##[` form)
and in the PR #59 body. The owner's ruling, 2026-10-05: **close
everything Phase 27 deferred.** The ruling on doubt still binds: a wrong
refusal is acceptable, because it fails closed and the owner fixes the
tree; a wrong pass is not. Nothing here is inside a plugin: `scripts/`,
`tests/` and `specs/` belong to the repository, so no plugin is
released.

Measured 2026-10-05 at `main` = `5a78ea4` on a one-plugin fixture built
from `handoff/`:

- **A link is still followed everywhere but the changelog.** A
  `plugin.json` that is a symbolic link to a JSON file outside the tree
  was read, and that file's name printed (`plugin.json name
  'SECRET-NAME-OUTSIDE' does not match its directory`, exit 1). A
  `marketplace.json` that is a link, and a plugin directory that is a
  link, each passed (exit 0), saying nothing of the link. All three CI
  runners can make a link (Phase 27's L1 printed `# links: made` on
  each).
- **`jq`'s own errors quote fork-written text.** A trailing marketplace
  entry whose `name` is an object holding `::error title=x::y` printed
  `jq: error (at .claude-plugin/marketplace.json:28): object
  ({"::error t...) is not valid in a csv row`, exit 5 (jq's status). A
  `.plugins` that is a string printed `Cannot iterate over string
  ("::error ti...)`, then the gate's own line. Neither line starts with
  `::`; the quoted text never passes through `shown`.
- **The runner's older command form, `##[...]`, is not masked.** `#`,
  `[` and `]` are printable. Where in a line the runner acts on `##[`
  was never measured.
- **The caller's shell options reach the gate.** With
  `SHELLOPTS=xtrace` in the environment, the gate traced 120 lines to
  standard error, among them `+ pv=$'1.0.0\E[2K'`: every value it read,
  uncut. Bash escaped the control bytes (0 raw escape bytes reached the
  output), and every trace line starts with `+ `. `BASH_ENV` names a
  file bash runs before the gate's first line (it ran).
- **Each marketplace entry costs a process.** 100 extra entries took
  2.8 s, 400 took 9.1 s, none 0.9 s: about 20 ms an entry. Each entry
  runs `norm_source` in a `$( )` subshell (its share is not measured).
- **Three test weaknesses** in `tests/portability.bats`: the P0 scan
  misses a name ending `_s` set by `printf -v`, `read` or `for`, a
  `$( )` with no `$` inside, and a `die` continued onto a second line;
  K3's plant needs 50,000 quote-marker pairs under the size limit, so it
  fails on a correct tree once the copied changelog passes 153,948
  bytes (`handoff`'s is 38,028); `gate_safe` removes every em dash
  before it checks, so a raw em dash in a value passes it.

**Every path the gate reads below the repository root, derived from
`scripts/check-versions.sh` at `2e5b6d7`** (identical to `5a78ea4`
under `scripts/`; line numbers there):

| Path | Read at | Link rule today |
|---|---|---|
| `.claude-plugin/` and `.claude-plugin/marketplace.json` | `:86` (`-f`), then `jq` at `:220`, `:222`, `:234`, `:618` | followed |
| each plugin directory `<p>/` | the `for dir in */` loop, `:168` | followed |
| `<p>/.claude-plugin/` and `<p>/.claude-plugin/plugin.json` | `:175` (`-f`), then `jq` at `:188`, `:189` | followed |
| `<p>/CHANGELOG.md` | after the link check | refused (Phase 27) |
| `<ed>/.claude-plugin/plugin.json`, from a marketplace source | the reverse walk's `-f` | followed |

**Every `jq` read, and what a fork controls in it:** `:188`, `:189`
(`plugin.json`, read on standard input); `:220`, `:222`, `:234` (the
marketplace entry named like the plugin); `:618` (every entry's name
and source, for the reverse walk). Each can fail on a file whose shape
is wrong, and each failure prints `jq`'s own message.

## Clarifications

### Session 2026-10-05

- Q: How should the gate get its `##[` rule, when measuring needs a GitHub runner and nothing may be pushed before gate L? → A: Mask `##[` in every printed value now (the wider rule); a probe runs once in this pull request's CI, its result is recorded in research as the measurement, and the probe is removed before merge (FR-003, FR-004).
- Q: What should the gate do about `BASH_ENV`, which bash runs before the gate's first line? → A: Record it as a limit in research: only the caller sets `BASH_ENV`, never a fork's files, and a caller who sets it controls the whole shell already; CI and the suite set none. No code change (FR-007).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The gate follows no link (Priority: P1)

A pull request from a fork commits a `plugin.json`, a `marketplace.json`,
a `.claude-plugin` directory or a whole plugin directory as a symbolic
link, pointing anywhere. Before any tool reads through it, in both
forms, the gate refuses it with a message of its own that names what it
refused.

**Why this priority**: a link lets a fork make the gate read, and print,
a file outside the checkout, or judge a tree other than the one the pull
request holds.

**Independent Test**: plant each link in a fixture and run the gate (N1
in both forms, one plant each of N2, N3 and N4 in both forms too, the
others in the default form: research R8); each run exits 1 with the
gate's own line.

**Acceptance Scenarios**:

1. **Given** a `plugin.json` that is a link to a JSON file outside the
   tree, **When** either form runs, **Then** it exits 1 saying
   `plugin.json` is a symbolic link, and nothing from the outside file
   is printed.
2. **Given** a `marketplace.json` that is a link, **When** either form
   runs, **Then** it exits 1 saying so.
3. **Given** a plugin directory, or a `.claude-plugin` directory, that
   is a link, **When** either form runs, **Then** it exits 1 saying so.
4. **Given** the real tree, **When** either form runs, **Then** it
   prints and exits exactly as at `5a78ea4`.

---

### User Story 2 - No program but the gate speaks, and no option changes it (Priority: P1)

A fork's `marketplace.json` has a shape `jq` cannot read, or the caller
runs the gate with shell options set, or a value holds `##[`. The gate
stops with its own message; no other program's error line, no trace
line and no runner command reaches the log.

**Why this priority**: a line the gate did not write is a line it did
not mask, and the gate runs on every pull request.

**Independent Test**: plant each shape and run the gate; the output is
only the gate's own lines, printed safely.

**Acceptance Scenarios**:

1. **Given** a trailing marketplace entry whose `name` is an object,
   **When** the gate runs, **Then** it exits 1 with its own message and
   no line starts with `jq:`.
2. **Given** a `.plugins` that is a string, **When** the gate runs,
   **Then** the same holds.
3. **Given** `SHELLOPTS=xtrace`, `verbose`, `noglob` or `keyword`, or
   `BASHOPTS=dotglob` or `nocasematch`, in the environment, **When**
   either form runs, **Then** it exits as without it, its standard
   output is the same, and no value reaches standard error.
4. **Given** a value holding `##[`, **When** the gate prints that
   value, **Then** no `##[` appears in the output.

---

### User Story 3 - The walk costs no process per entry, and the tests check what they claim (Priority: P2)

A marketplace with many entries is walked without a process per entry,
and the tests that guard the gate cannot be passed by the wrong output
or broken by a longer changelog.

**Why this priority**: a fork can make the walk slow; a test that cannot
fail, or that fails on a correct tree, guards nothing.

**Independent Test**: time the walk over many entries; mutate each test
helper and see its test go red.

**Acceptance Scenarios**:

1. **Given** a marketplace with 2,000 extra entries, **When** the gate
   runs, **Then** it is refused for its count inside the 15-second bound
   research R5 sets from the measured cost.
2. **Given** a `die` line that prints a raw value through any of the
   shapes the P0 scan missed, **When** the P test runs, **Then** it
   fails on P0.
3. **Given** a changelog that leaves room under the limit for the
   plant's margin and a 1,001-byte line, **When** K3 runs, **Then** its
   plant fits, with no fixed floor.
4. **Given** an output holding an em dash the gate did not write,
   **When** `gate_safe` checks it, **Then** it fails.

---

### Edge Cases

- A link to a file inside the repository is refused too: the gate
  follows no link, and a wrong refusal is acceptable.
- A broken link (to nothing) is a link, refused as one.
- A linked plugin directory that holds a `.claude-plugin` is refused by
  the forward loop; a marketplace source that passes through a link
  below the top level is refused by the reverse walk as a link, not
  reported as naming no plugin.
- `jq` failing because a file is missing or unreadable stays
  distinguishable from `jq` failing on a file whose shape is wrong.
- `BASH_ENV` runs before the gate's first line; nothing inside the gate
  can stop it, and it is recorded as a limit (FR-007). So does
  `BASHOPTS=extdebug`: bash prints the script's path, as invoked, before
  the first line (found at pull request review), recorded the same way.
- A caller's `BASHOPTS` sets `shopt` options before the first line:
  `dotglob` made the plugin loop read a hidden plugin directory, so a
  marketplace entry the count should refuse passed, and `nocasematch`
  made `--RELEASED` the release form (measured at review). The first
  line turns both off (FR-005).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Before any tool opens a file or prints a value through it
  (one stat, which reads nothing, tells a plugin directory from another
  folder), in both forms, the gate MUST refuse, naming what it refused and the plugin where there is one,
  each path in the table above that is a symbolic link: the repository's
  `.claude-plugin` directory and `marketplace.json`; a plugin directory;
  a plugin's `.claude-plugin` directory and `plugin.json`; and, in the
  reverse walk, every component of a source, its `.claude-plugin`
  directory and its `plugin.json`. The changelog
  rule stays as it is.
- **FR-002**: A `jq` read that fails MUST stop the gate with its own
  message and exit 1, and no line from `jq`, nor bash's own line about a
  NUL in a value read through `$( )`, MAY reach the output. A file
  that cannot be read and a file whose shape `jq` cannot read MUST give
  different messages.
- **FR-003**: Where in a line the GitHub runner acts on `##[` MUST be
  measured on a runner: a probe that prints `##[` at a line's start and
  mid-line runs once in this pull request's CI, from inside an existing
  test (so the count stays as FR-016 fixes it), the run and what the
  runner did are recorded in research, and the probe is removed before
  the pull request merges. The measurement records; it does not narrow
  FR-004. Done: measured in pull request #61's first CI run,
  37405126582 (the runner acts on `##[` mid-line too; research R3), and
  the probe then removed.
- **FR-004**: Every value the gate prints MUST be shown so that `##[`
  never appears in it, wherever in the line: the masking shows it
  changed (the plan sets the exact form). The gate's own text holds no
  `##[`.
- **FR-005**: At its first line, before anything it reads, the gate MUST
  turn off every shell option a caller can set through `SHELLOPTS` or
  `BASHOPTS` that prints or changes what the gate does; the research
  lists them (R4: `xtrace`, `verbose`, `noglob` and `keyword`, then
  `shopt -u dotglob nocasematch`), at least `xtrace` and `verbose`.
- **FR-006**: With each option of FR-005 set through `SHELLOPTS` or
  `BASHOPTS`, both forms MUST exit as without it and print the same
  standard output; on standard error only the gate's own first lines
  (the `#!` line and the line that turns the options off, echoed or
  traced before it runs) MAY appear, never a value (measured at D: no
  line of a script can stop bash echoing the line that turns `verbose`
  off).
- **FR-007**: `BASH_ENV` runs before any line of the gate, so no line of
  it can stop that. The research MUST record it as a limit, with the
  reason: only the caller sets `BASH_ENV`, never a fork's files, and a
  caller who sets it controls the whole shell already; CI and the suite
  set none. The gate and its callers do not change for it. The same
  holds, and is recorded the same way (the owner confirmed it at gate G,
  2026-10-06), for `SHELLOPTS=noexec` and
  `SHELLOPTS=onecmd`: with either, the gate exited 0 printing nothing
  (measured at D), and no line of it can stop that, because none runs
  (a first-line `set +o onecmd` printed nothing either). It is recorded
  the same way, by the same reasoning, for `BASHOPTS=extdebug`: bash
  prints two lines naming the script as invoked, an absolute path when
  run by one, before the gate's first line (measured at pull request
  review; research R4). The owner has not ruled on `extdebug`; it is
  put to the owner in the pull request.
- **FR-008**: `norm_source` MUST set a variable, as `shown` does, and
  the walks MUST start no process per entry for it. No per-entry check
  this phase adds MAY grow with a source's length unbounded: the reverse
  walk refuses a source of more than 64 components, counted from the
  source before any file test, and its link check stops at the first
  missing prefix. The research MUST
  record the cost per entry before and after, on the fixture above.
- **FR-009**: The P0 scan MUST also find a name ending `_s` set by
  `printf -v`, `read` or `for`, a `$( )` with no `$` inside, and a `die`
  message continued with `\`; or the research replaces the scan with a
  check that cannot miss a print site, and says which.
- **FR-010**: K3's plant MUST be sized from the room under the size
  limit, with no fixed floor: it MUST fit whenever the copy leaves room
  under the limit for the plant's margin and a line one byte over the
  line limit.
- **FR-011**: `gate_safe` MUST remove only the gate's own text before it
  checks, never every em dash.
- **FR-012**: On the real tree, both forms MUST print and exit exactly
  as at `5a78ea4`. The walk's text MUST NOT change; if it must, the
  proof (`specs/025-gate-closes-phase25-gaps/proof/enumerate.py`) MUST
  be rerun and report 0 wrong passes and each control at least 1. CI and
  the suite MUST still call the one script, and the "one
  version-agreement script" test MUST stay green unchanged.
- **FR-013**: Each new rule MUST be shown able to fail: a mutant that
  removes it turns its test red, naming its clause, and the mutation is
  confirmed to have landed.
- **FR-014**: The link tests MUST run on all three operating systems
  without a skip, and print, on a pass as on a failure, which way they
  took, as Phase 27's L1 does.
- **FR-015**: Every byte tool the gate or the tests run on a file or an
  output that may hold a byte which is not valid text MUST run under
  `LC_ALL=C`; a locale-dependent rule MUST also be tested with `LANG` set
  to a UTF-8 locale and `LC_ALL` unset, as CI runners set them.
- **FR-016**: The house suite MUST grow from `1..251` to `1..252`: one
  new test for User Story 1, whose link plants need their own fixtures,
  which also holds User Story 2's option plants (they compare a fixture
  run with and without an option) and its unreadable-`marketplace.json`
  plant; every other plant goes into an existing test. No test may come near
  the 60-second per-test timeout; a test over 30 s on this machine has
  its runs reduced. Every changed line under `scripts/` MUST avoid the
  banned vocabulary, machine paths and counts in prose. Every changed
  line under `scripts/` and every new line of test code MUST run under
  bash 3.2 and the awks the three CI systems run, hold no interval
  expression in an awk pattern, and never put `\/` inside a pattern
  substitution.

### Key Entities

- **Read path**: a path below the repository root the gate opens or
  lists, in the table above.
- **`jq` read**: a place the gate hands a file to `jq`.
- **Inherited option**: a shell option set by the caller's environment
  (`SHELLOPTS`) before the gate runs.
- **Runner command**: a line shape the CI runner acts on, `::` at a
  line's start, and `##[` where measured.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A `plugin.json` link to a file outside the tree is refused
  in under 2 seconds in both forms (timed by the quickstart), every other
  planted link is refused, and no byte of a file outside the tree
  reaches the output.
- **SC-002**: Across every planted shape, the output holds 0 lines the
  gate did not write, 0 bytes outside printable ASCII apart from the
  gate's own text, 0 lines starting with `::`, and 0 `##[` in any line.
- **SC-003**: With each `SHELLOPTS` option of FR-005 set, both forms
  exit as without it, standard output is byte-identical, and standard
  error holds no value; with each `BASHOPTS` option of FR-005 set, the
  plant it changed exits and prints exactly as without it (contract O2).
- **SC-004**: The walk's cost per marketplace entry falls, measured
  before and after on the same fixture.
- **SC-005**: On the real tree both forms are byte-identical to
  `5a78ea4`.
- **SC-006**: Each new rule and each changed test helper has a mutant
  that turns a test red.
- **SC-007**: The feature quickstart, run as one script, ends ALL OK; the
  house suite reads `1..252` with every test ok, judged by
  `scripts/check-suite.sh 252`; CI passes on three operating systems, a
  run confirmed to exist and every job's steps read.

## Assumptions

- No plugin changelog gains an entry for this phase.
- Every link is refused, wherever it points: simpler than judging
  targets, and a wrong refusal is acceptable.
- The `##[` measurement needs a GitHub runner. It runs in this pull
  request's own CI (no push before gate L), and masking `##[` everywhere
  is the wider rule, safe whatever the measurement finds: no real value
  or heading holds `##[`.
- Not in this phase (each recorded in Phase 26's research R14): Windows
  gawk reading a CRLF line end differently; a one-line HTML comment
  keeping later fences refused; a tag that only starts with `pre`,
  `script`, `style` or `textarea`; the 1,000-byte line limit on prose; a
  mechanical check for U1; bats printing a failed test's raw `$output`;
  the quote cut written in both bash and awk; a job time limit in
  `.github/workflows/ci.yml`.
