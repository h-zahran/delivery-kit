# Feature Specification: The release gate closes the gaps Phase 25 left

**Feature Branch**: `025-gate-closes-phase25-gaps`

**Created**: 2026-10-03

**Status**: Draft

**Input**: Seed `## Phase 26: the release gate closes the gaps Phase 25
left` from `main-plan.md`, quoted verbatim in the run's `seed.md`.

## Context

Phase 25 (`specs/024-gate-every-heading-form/`, PR #55, merged as
`ceff931`) made the release form of the version gate judge every Markdown
level-2 heading in a plugin's changelog. Its reviews left three gaps, a NUL
byte with no message, four wrong refusals the strict rules accept, and some
weak spots in the tests. The owner's ruling, 2026-10-03: **close all of
them.** The ruling on doubt still binds: a wrong refusal is acceptable,
because it fails closed and the owner fixes the changelog; a wrong pass is
not. Nothing here is inside a plugin: `scripts/`, `tests/` and `specs/`
belong to the repository, so no plugin is released.

Measured 2026-10-03 at `main` = `ceff931` (and again at `88cb603`, where
only `main-plan.md` changed), on a one-plugin fixture built from `handoff/`:

- **A lone CR inside a line passes.** `Notes`, a CR, then `## x` is a
  level-2 heading to Markdown, which reads a CR as a line end. Read as the
  Linux and macOS awks read bytes, the release form exits 0 on it, while a
  plain `## x` control exits 1. `.gitattributes` forces LF, so a CRLF
  cannot reach a commit; only a lone CR can. Neither changelog holds a CR.
- **The first-heading text is printed raw.** The default form prints
  `state=UNRELEASED-ABOVE:<text>` with only CR and LF removed, and the
  release form's first-heading refusal quotes the same line raw. An escape
  sequence in the first heading reaches the log through both. Both real
  first headings are plain ASCII.
- **A long nested-quote line is slow.** One line of `> ` repeated: 50,000
  markers take 0.9 s, 100,000 take 1.4 s, 200,000 take 22 s and 400,000
  take 123 s. The longest line in the two changelogs is 107 characters.
  A refusal quotes its whole line.
- **A NUL byte stops the gate silently.** A changelog holding one makes
  both the default form and the release form exit 1 with no output at all.
- **Four wrong refusals**, none of them a level-2 heading to CommonMark:
  a fence on item `2.` of a numbered list; a fence anywhere below an HTML
  block such as `<details>` … `</details>`; `### Notes` then `---`; and
  `> Notes`, `>`, `> ---`.
- **Test weak spots**, each found by the Phase 25 reviews and listed in
  the seed.

A reference CommonMark reader (markdown-it-py 4.0.0, CommonMark mode) is
installed on this machine, and the Phase 25 enumeration rig is kept in
`.delivery-kit/runs/024-gate-every-heading-form/review-r3/`.

## Clarifications

### Session 2026-10-03

- Q: When a changelog line holds a lone CR byte, should the release gate refuse the line, or split it at the CR and judge each part as Markdown does? → A: Refuse the line (FR-001).
- Q: How long may a line be before the release gate refuses it, and how much of a line should a refusal quote before cutting it? → A: 1,000 characters, and 200 characters quoted before the cut marker (FR-003, FR-004).
- Q: Contract H8 checks the default form "on every fixture"; should each test's combined copy hold every refused plant with H8 reworded, or should the default form run on every plant's copy? → A: The full combined copy, with H8 reworded (FR-013).
- Q: Should the run attempt all four wrong refusals, or only some? → A: Attempt all four; any whose proof fails stays refused with its reason recorded (FR-008, FR-010).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - No byte hides a heading or the gate's reason (Priority: P1)

A maintainer tags a release. A changelog line that Markdown splits with a
CR, a first heading holding an escape sequence, a line far too long to
judge, or a NUL byte each reaches the release form. The gate refuses each
one with a message of its own that names the plugin, the line where there
is one, and the reason; nothing from the file reaches the log unmasked or
uncut.

**Why this priority**: a lone CR is the one known wrong pass left in the
release form, and the owner ruled a wrong pass out. The masking and length
rules keep a tracked file from writing into a public CI log.

**Independent Test**: plant each shape below the release in a fixture and
run both gate forms.

**Acceptance Scenarios**:

1. **Given** a changelog line `Notes`, a lone CR, then `## x`, **When** the
   release form runs, **Then** it refuses, naming the line and showing the
   CR as `?`.
2. **Given** a first heading holding an escape sequence above the release,
   **When** the default form runs, **Then** its `state=` field shows each
   non-printable character as `?` and it exits as it does today; **When**
   the release form runs, **Then** its first-heading refusal shows them the
   same way.
3. **Given** a line longer than the limit, **When** the release form runs,
   **Then** it refuses, naming the line and its length, before judging the
   line, and the quoted text is cut with a marker.
4. **Given** a changelog holding a NUL byte, **When** either form runs,
   **Then** the gate stops with a message of its own naming the plugin.
5. **Given** the real tree, **When** either form runs, **Then** the output
   and exit status are byte-identical to `main` at `88cb603`.

---

### User Story 2 - A safe shape is not refused, where that is proven (Priority: P2)

A maintainer writes a normal numbered list holding a fence, a `<details>`
block followed later by a fence, a thematic break under a heading, or a
thematic break after an empty quote line. Where the walk can stop refusing
the shape without ever passing a heading Markdown renders, and that is
proven, it passes; where the proof cannot be made, it is still refused and
the spec says why.

**Why this priority**: each is a wrong refusal, which the owner accepts. It
costs a maintainer a reworded changelog, never a bad release.

**Independent Test**: for each narrowed shape, a passing plant; for each,
the enumeration proof in the run directory.

**Acceptance Scenarios**:

1. **Given** a shape narrowed under FR-009, **When** the release form
   runs, **Then** it passes.
2. **Given** the enumeration for that shape, **When** it is run against
   the narrowed walk, **Then** the walk passes no level-2 heading the
   reference reader renders; **When** it is run against a walk with the
   narrowing done wrongly, **Then** it passes at least one (the positive
   control).
3. **Given** a shape kept refused, **When** the spec is read, **Then** it
   says why the proof could not be made.

---

### User Story 3 - The tests can fail, and say why (Priority: P3)

A contributor changes the gate or the test helpers. Every helper the
`--released` tests use can go red when its check fails, prints its own
reason when it does, and passes data to the shell as arguments.

**Why this priority**: the Phase 25 reviews showed checks that could never
fail and a helper that aborts with no message. A test that cannot fail
proves nothing.

**Independent Test**: one mutant per helper change turns a test red.

**Acceptance Scenarios**:

1. **Given** a plugin source holding a `"` or a `$`, **When** a
   `--released` test runs the gate, **Then** no part of that source runs as
   shell.
2. **Given** a gate that prints an absolute path in a PASSING run, in any
   spelling the platform prints, **When** the tests run, **Then** one goes
   red naming U2.
3. **Given** a plant that did not land, **When** `forms_passes` checks it,
   **Then** the test goes red naming the fixture.
4. **Given** a fixture helper that leaves a refused shape behind, **When**
   its self-check runs, **Then** it fails, and a failed `mv` fails too.
5. **Given** `forms_at` asked for a line the copy does not hold, **When**
   it runs, **Then** it prints its own message.

### Edge Cases

- **CRLF**: cannot reach a commit (`.gitattributes` forces LF). Windows
  gawk strips a CR that comes before an LF, so a test plants a LONE CR.
  The CR rule judges the raw line, so a CRLF in a working copy, where one
  could exist, is refused too.
- **A CR inside a fence**: refused like any other. Markdown would split
  the line there, and a split line can close a fence.
- **The first-heading check (Phase 24 G3)** still reads the first line
  beginning `## `; only what it prints changes.
- **Masking under a C locale**: the walk runs under the C locale, so a
  non-ASCII byte becomes `?` too; under a UTF-8 locale an invalid byte
  such as a lone `` (a bare terminal control) would pass `[:print:]`
  unmasked. Both real first headings are plain ASCII, so the real tree's
  output is unchanged.
- **Length**: counted in bytes. The limit has wide room above the longest
  real line (107), so the byte count cannot refuse the real tree.
- **A NUL byte in the default form**: today it exits 1 silently; it keeps
  exiting non-zero and gains a message. The real tree holds none, so its
  output does not change.
- **Narrowing and the other rules**: a narrowed shape stays refused when
  another rule refuses it (for example a `##` line, a CR, or an over-long
  line).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Under `--released <plugin>`, the gate MUST refuse any
  changelog line that holds a CR byte, naming the line and showing the CR
  as `?`. (Splitting the line at the CR, as Markdown does, was the
  alternative; refusing is chosen because it is the simpler rule and
  leans to refusing.)
- **FR-002**: The default form's `UNRELEASED-ABOVE:` state field and the
  release form's first-heading refusal MUST show every non-printable
  character as `?`, as the walk's quoted lines already do.
- **FR-003**: Under `--released`, the gate MUST refuse any changelog line
  longer than 1,000 bytes, naming the line and its length, before the line
  is judged. (The owner's answer said characters; the walk counts bytes,
  because it runs under the C locale for FR-004's masking. For ASCII text
  the two are equal, and for any other text bytes refuse sooner.)
- **FR-004**: Every line the gate quotes in a refusal MUST be cut to at
  most 200 characters, followed by a marker saying it was cut, when it is
  longer, and MUST show every non-printable byte as `?`, an invalid byte
  such as a lone `` included. The cut length and the line limit are
  each set once, so the two places that cut cannot drift.
- **FR-005**: In both forms, a changelog holding a NUL byte MUST stop the
  gate with a non-zero status and a message of the gate's own naming the
  plugin and saying it holds a NUL byte.
- **FR-006**: Each new refusal MUST print no absolute path, and MUST be
  shown able to fail: a mutant that removes the rule turns its test red,
  naming its clause, and the mutation is confirmed to have landed.
- **FR-007**: The default run (no argument) MUST keep its output and exit
  status on the real tree; the first-heading check MUST keep reading the
  first line beginning `## `; CI and the suite MUST still call the one
  script; and the "one version-agreement script" test MUST stay green
  unchanged.
- **FR-008**: The four wrong refusals MUST each be attempted: a fence on an
  ordered marker other than `1` when it continues a numbered list; a fence
  below an HTML block that has ended; a `-` run directly under an ATX
  heading; a `-` run after an empty quote line in the same quote.
- **FR-009**: A shape MAY stop being refused only when (a) the reference
  CommonMark reader, run over a systematic enumeration of the shape in
  every container the Phase 25 rig covers, finds that the narrowed walk
  passes no level-2 heading it renders, and (b) the same enumeration, run
  against a walk with that narrowing done wrongly, finds at least one (the
  positive control). The enumeration, its inputs and its results MUST be
  kept in the run directory and summed up in the pull-request body.
- **FR-010**: A shape whose proof under FR-009 cannot be made MUST stay
  refused, and this spec MUST record, under that shape, why.
- **FR-011**: Every `run bash -c` in the `--released` tests MUST pass the
  directory, the root and the plugin name as arguments, never inside the
  command string.
- **FR-012**: The absolute-path check MUST read every output the
  `--released` tests capture, passing runs included, in every spelling of
  the test directory and the root the platform prints.
- **FR-013**: The default form MUST be run on a copy holding every refused
  plant of each test that the default form accepts; contract H8 is
  reworded to say exactly that, instead of "on every fixture the new tests
  build", and names the plants it leaves out (the NUL plant, which FR-005
  stops in both forms, and a first heading above the release).
- **FR-014**: `forms_passes` MUST prove its plant landed before it judges
  the run, as `forms_refused` does through `forms_at`.
- **FR-015**: The fixture helper's self-check MUST be able to fail: it
  checks the file it left with a test that does not share its code path,
  and a failed `mv` fails the helper with a `fixture:` message.
- **FR-016**: `forms_at` MUST print its own `fixture:` message when the
  line it looks for is missing, under errexit as well.
- **FR-017**: The fixture helper MUST keep its own copy of every pattern,
  never one read from the gate, and MUST remove every shape FR-001 and
  FR-003 refuse (a CR, an over-long line) from a live changelog, so a live
  changelog holding one cannot redden a correct tree.
- **FR-018**: The house suite MUST grow from `1..248` by the tests the
  tasks name, preferring plants added to the existing `--released` tests;
  no test may approach the 60-second per-test timeout. Every changed line
  under `scripts/` MUST avoid the banned vocabulary, machine paths and
  counts in prose, run under bash 3.2 and the awks the three CI systems
  run, with no interval expressions in awk patterns; no plugin file
  changes.

### Key Entities

- **Release form**: the gate run as `--released <plugin>`.
- **Wrong refusal**: a shape the release form refuses although Markdown
  renders no level-2 heading there; accepted by the owner's ruling.
- **Narrowing**: a change that stops one wrong refusal.
- **Enumeration proof**: the reference reader's verdict on every shape the
  rig generates, run against the narrowed walk and against a wrongly
  narrowed one (the positive control).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Each planted shape of User Story 1 is refused with its
  message (0 wrong passes on those shapes), and the default form on the
  real tree is byte-identical to `88cb603`.
- **SC-002**: A line of 400,000 quote markers is refused in under 2
  seconds on this machine (measured by the quickstart; the tests only
  require it to finish inside the per-test timeout), and no refusal line
  is longer than the quoted cut plus its fixed message.
- **SC-003**: Each narrowing kept has an enumeration proof with 0 wrong
  passes and a positive control with at least 1; each shape not narrowed
  has its reason in this spec.
- **SC-004**: Each helper change has a mutant that turns a test red.
- **SC-005**: The feature quickstart, run as one script, ends ALL OK.
- **SC-006**: The house suite reads `1..<count>` with every test ok,
  judged by `scripts/check-suite.sh <count>`, the count fixed by the tasks;
  CI passes on three operating systems, a run confirmed to exist and every
  job's steps read.

## Assumptions

- The reference reader and the Phase 25 rig are run-time evidence only,
  not repository dependencies; nothing under `tests/` needs them.
- 1,000 for the line limit (counted in bytes, FR-003) and 200 characters
  for the quoted cut (the owner's answer at clarify) leave wide room above the longest real line
  (107) and keep a refusal readable.
- A NUL byte is detected before the awk walk reads the file: what an awk
  does with a NUL in a string differs between the CI awks.
- The owner merges; the pipeline opens the pull request and stops.
