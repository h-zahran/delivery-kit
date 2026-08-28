# Feature Specification: context-guard.sh coverage and a config fixture helper

**Feature Branch**: `010-context-guard-coverage`

**Created**: 2026-08-28

**Status**: Draft

**Input**: Campaign 2, Phase 10 of `main-plan.md` — "context-guard.sh coverage
and a config fixture helper". Quoted verbatim into the run directory as
`seed.md`.

---

## The seed's own line references, re-derived before use

The campaign's standing rule is that **every line reference carried in a seed is
re-derived from content before it is used**, because two earlier phases shipped
seeds whose numbers had already moved. That was done here, before this
specification was written, and it found drift.

| The seed says | Re-derived | Verdict |
|---|---|---|
| hook, `cwd="$PWD"` fallback, `105–111` | `:105` | **accurate** |
| hook, repository-root config discovery, `105–111` | `:109` | **accurate** |
| hook, the gate payloads without a working directory hit first, `:96` | `:96` | **accurate** |
| hook, the seven-day flag sweep, `:344` | `:344` | **accurate** |
| hook, the empty-readings exit, `260–262` | `:262` | **accurate** |
| `tests/helper.bash`, the payload builder, `98–99` | **`152–154`** | **STALE — moved ~54 lines** |
| the guard suite, the four-variable loop, `877–878` | **`867–871`** | **STALE** |
| the guard suite, the patch-file site, `:791` | **`792`** | **STALE by one** |

**The helper reference moved because Phase 9 moved it.** Phase 9 added 46 lines
to `tests/helper.bash` — the payload builder is the same code, 54 lines lower.
The seed was written before that merge. This is the exact failure the standing
rule exists to catch, and it caught it.

**Every reference in THIS document is to content, not to a line number.** The
table above is the only place numbers appear, and it exists to record the drift
rather than to be depended on.

### The seed's count is right, and its list of exceptions is not complete

The seed says twenty-seven repetitions and names **one** exception. Measured:

| Target | Sites | Convertible? |
|---|---|---|
| the **repository** configuration file, guard key only | 22 | yes |
| the **user** configuration file, under the home directory | **4** | yes |
| *subtotal — the conversion target* | **26** | |
| the repository file, but **also carrying a `profile` key** | **1** | **no** |
| a patch file *(the seed names this one)* | 1 | **no** |
| an existing-configuration file *(the seed does **not** name this one)* | 1 | **no** |
| **total configuration-writing sites** | **29** | **26 convert, 3 stay** |

**There are THREE exceptions, not one, and not the two this document first
recorded.** The seed names one. Measuring the targets found a second. Only
*running* the conversion found the third: a site writing the repository
configuration file whose object **also carries a `profile` key** belonging to
another tool. Same class as the existing-configuration site — a top-level key
the guard does not own, which a guard-shaped helper cannot write.

The first draft of this document said twenty-seven convert and two stay. That
was wrong in the direction that matters: a conversion built on it would have
flattened a foreign key out of a fixture.

So the seed is **incomplete, not wrong** — in two ways.

**The twenty-seven that write a configuration file do not all write the same
one.** Four of them write the
*user* configuration file rather than the repository one; they are what proves
the precedence order between the two. A helper that assumed the repository path
could not express them at all. This is why FR-011's path parameter is
**required**, not a convenience.

**And they do not write the same value.** Measured: **nineteen distinct
bodies** across the twenty-seven — windows, thresholds, token counts, and
several deliberately invalid values. What repeats is the *wrapper*, not the
setting. A helper that took no body would collapse nineteen meaningful fixtures
into one, and every test that depends on its own value would break.

### One figure the seed implies and does not state

The byte-cap idiom the second helper would replace has **four** call sites, not
twenty-seven. It is worth extracting for naming and for keeping one awkward
incantation in one place — but this specification will not pretend it is a large
duplication, because a requirement justified by a false number is a requirement
nobody can check.

---

## Clarifications

### Session 2026-08-28

No questions were raised. The seed names each behaviour to cover, states the
target count, names the file that must not change, and states the changelog
routing. Three things that would otherwise have been asked are settled by the
seed or by measurement, and are recorded here so a later reader does not reopen
them:

- **Whether the probed hook may be edited.** No. The seed assigns
  `handoff/hooks/context-guard.sh` to a later phase. This feature reads it.
- **Whether the helper extraction may change any assertion.** No. The conversion
  is mechanical: same values, same assertions, one named way to write them.
- **What to do about the second unnamed exception.** The helper takes its target
  path, so it *could* write either — but **neither exception site is
  converted**, and that was decided by looking at them rather than by preference.
  See below.

### The two exception sites are a different shape, not just a different path

The seed offers a choice — give the helper a target path, "or leave that one
site alone" — and names only one of the two sites. Both were read before
choosing.

| Site | What it writes |
|---|---|
| the 27 | one configuration key, to the repository configuration file |
| the patch file | one configuration key, as the **input to a merge** |
| the existing-configuration file | **three top-level keys**, only one of which is the guard's |

The third is the deciding one. That site exists to prove a merge **preserves
keys the guard does not own** — an unrelated tool's key and a deliberately
unknown future key. Its content is not fixture noise; it *is* the assertion.

Forcing it through a guard-shaped helper would mean either teaching the helper
to write arbitrary top-level keys — at which point it is a JSON-writing helper,
not a configuration helper, and FR-014's "a reader still sees what this site
writes" is lost — or distorting the test to fit the helper.

**So: the helper takes a path, and the two exception sites keep their literal
writes.** Twenty-seven convert. The path parameter still earns its place: it is
what lets a future caller write somewhere else without the helper being wrong,
and it is why neither exception needed special-casing to be *left alone*.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The two paths that only ever run on a real machine are proven (Priority: P1)

The guard reads its configuration from the working directory the harness hands
it, and falls back to the process's own directory when the harness hands it
none. It also looks upward to the repository root, because the harness's working
directory can be a subdirectory. **Neither path has ever executed under test.**

Both are invisible in the suite by construction: the shared payload builder
always supplies a working directory, and the only payloads that omit one are
rejected earlier for a different reason. So a change that broke either would
leave every suite green while the guard silently read no configuration on a real
user's machine.

**Why this priority**: these are the two paths that run for every real user and
for no test. That gap is the whole reason this phase exists.

**Independent Test**: build a payload that reaches the configuration step with
no working directory, and run the guard from a subdirectory of a repository that
carries configuration at its root.

**Acceptance Scenarios**:

1. **Given** a payload carrying no working directory, **When** the guard runs,
   **Then** it falls back to its own directory and reads the configuration
   found there.
2. **Given** a working directory that is a subdirectory of a repository whose
   root carries configuration, **When** the guard runs, **Then** it finds that
   configuration by looking upward.
3. **Given** either test, **When** the payload is inspected, **Then** it is
   shown to have reached the configuration step — not to have exited at the
   earlier gate.

---

### User Story 2 - The quiet housekeeping and empty-input paths are proven (Priority: P2)

The guard also does two things nobody watches: it sweeps its own stale flag
files after seven days, and it exits without warning when a transcript yields no
readings. Both are silent successes today, indistinguishable from not running.

**Why this priority**: below Story 1 because neither misleads a user when it
breaks — the sweep failing leaks files, and the empty path failing produces a
warning against no data. Real, but quieter.

**Independent Test**: age a flag file past the sweep's threshold and confirm it
is removed; hand the guard an existing transcript containing no readings and
confirm it exits without warning.

**Acceptance Scenarios**:

1. **Given** a flag file older than the sweep's threshold, **When** the guard
   runs, **Then** that file is removed.
2. **Given** a transcript that exists but yields no readings, **When** the guard
   runs, **Then** the guard exits successfully and emits no warning.

---

### User Story 3 - A payload missing its session identifier is proven safe (Priority: P2)

The guard keys its per-session state on an identifier the harness supplies. When
that identifier is absent the guard substitutes a placeholder rather than
failing. Nothing tests that substitution.

**Why this priority**: equal to Story 2. A break here would make the guard fail
on a payload shape the harness is free to send.

**Independent Test**: send a payload with no session identifier and confirm the
guard still behaves.

**Acceptance Scenarios**:

1. **Given** a payload carrying no session identifier, **When** the guard runs,
   **Then** it completes without error.

---

### User Story 4 - Two configuration overrides are proven to change behaviour (Priority: P2)

Four environment overrides exist. **Two are tested behaviourally; two are not.**
The two untested ones are covered today only by a test that reads a documentation
snippet and counts the variables it names — which proves the documentation lists
four names, and proves nothing about the guard.

**Why this priority**: a documentation test that reads like a behaviour test is
worse than no test, because it occupies the space where the real one would go.

**Independent Test**: set each override to a value that must change the outcome,
and observe the outcome change.

**Acceptance Scenarios**:

1. **Given** the proportional threshold override set to a value that must change
   whether the guard warns, **When** the guard runs, **Then** the outcome
   changes accordingly.
2. **Given** the absolute threshold override set likewise, **When** the guard
   runs, **Then** the outcome changes accordingly.

---

### User Story 5 - The suite stops writing the same configuration twenty-seven times (Priority: P3)

Twenty-seven sites in the guard suite write the same shape of configuration file
with the same inline incantation. A twenty-eighth and twenty-ninth write a
similar shape to two *different* files, and those two are not part of the
conversion.

**Why this priority**: it improves the suite without changing what it proves, so
it ranks last. It is included because the seed asks for it and because
twenty-seven copies of one line is harder to read than one named helper.

**Independent Test**: the converted sites produce the same results as before,
and the test count does not move.

**Acceptance Scenarios**:

1. **Given** the converted suite, **When** it runs, **Then** every test passes
   and the test count is unchanged.
2. **Given** the conversion, **When** the diff is read, **Then** it is
   mechanical — no assertion is added, removed or altered.

---

### Edge Cases

- **A test that passes at the wrong gate.** The two configuration-discovery
  behaviours sit *after* an earlier gate that rejects most malformed payloads.
  A payload built carelessly is rejected there, the guard exits successfully,
  and a test asserting only success passes **without ever reaching the
  behaviour it names**. Each of those two tests must show it got past that gate.
- **A silent success is indistinguishable from not running.** The sweep, the
  empty-readings path and the missing-identifier path all end in a successful,
  silent exit. Asserting only on exit status proves nothing for any of them;
  each must assert on an observable the behaviour actually changes.
- **An override test that changes nothing.** Setting an override to a value the
  guard would have chosen anyway proves nothing. Each override test must be
  positioned so the outcome differs with and without it.
- **A documentation test wearing a behaviour test's clothes.** The existing
  four-variable check reads a documentation snippet and counts names. It must
  not be counted as coverage of the two overrides, and it must not be removed
  either — it tests the documentation, which is a real thing to test.
- **A helper that hides which file a site writes.** Twenty-seven sites write one
  file and two write others. A helper that assumed the common target would force
  the two exceptions into a shape that quietly writes the wrong path.
- **A vocabulary leak reaches every install.** The guard suite's directory is a
  registered strict-vocabulary surface, so a banned term pasted into a fixture
  ships to every install of the plugin. This feature adds fixtures.

## Requirements *(mandatory)*

### Functional Requirements

**The arithmetic, stated once so it cannot drift.** Seven new tests, and here is
the mapping in full, because the first draft of this very paragraph was off by
one:

| # | Requirement | Behaviour |
|---|---|---|
| 1 | **FR-001** | the working-directory fallback |
| 2 | **FR-002** | discovery at the repository root |
| 3 | **FR-004** | the seven-day flag sweep |
| 4 | **FR-005** | a transcript yielding no readings |
| 5 | **FR-006** | a payload with no session identifier |
| 6 | **FR-007** | the proportional threshold override |
| 7 | **FR-008** | the absolute threshold override |

**FR-003 and FR-009 are NOT tests.** They are properties the tests above must
carry: FR-003 binds the first two, FR-009 binds the last two. Counting either as
a test would put the suite at eight or nine against a stated acceptance of seven
— which is exactly the drift the earlier draft introduced by citing FR-003 as
the flag-sweep test and never naming FR-008 at all.

The helper work (FR-010 to FR-014) adds no test.

**Configuration discovery — the two that have never run**

- **FR-001**: A test MUST prove the guard falls back to its own working
  directory when the payload carries none, and reads configuration from there.
- **FR-002**: A test MUST prove the guard finds configuration at a repository
  root when the working directory it is given is a subdirectory of that
  repository.
- **FR-003**: Both tests MUST demonstrate that their payload reached the
  configuration step. A payload rejected at the earlier gate exits successfully
  and would pass a naive assertion, proving nothing.

**The quiet paths**

- **FR-004**: A test MUST prove the flag sweep removes a flag file older than
  its threshold.
- **FR-005**: A test MUST prove that a transcript yielding no readings produces
  a successful exit and no warning.
- **FR-006**: A test MUST prove the guard completes when the payload carries no
  session identifier.

**The overrides**

- **FR-007**: A test MUST prove the proportional threshold override changes the
  guard's behaviour.
- **FR-008**: A test MUST prove the absolute threshold override changes the
  guard's behaviour.
- **FR-009**: Both MUST be behavioural. The existing test that reads a
  documentation snippet and counts variable names MUST NOT be treated as
  covering either, and MUST NOT be removed — it covers the documentation.

**The helpers**

- **FR-010**: A single named helper MUST replace the repeated configuration-file
  wrapper, and MUST live in the fixture file every suite loads. What repeats is
  the wrapper; the **nineteen distinct bodies** across those sites are each
  meaningful and MUST survive the conversion unchanged.
- **FR-011**: That helper MUST take the target path. Twenty-seven sites write
  the repository configuration file; **two others write different files**, and
  the seed names only one of them. Taking the path is what lets those two be
  left alone rather than special-cased, and lets a future caller write elsewhere
  without the helper being wrong.
- **FR-011a**: The **three** exception sites MUST NOT be converted. Each writes a
  top-level key the guard does not own, or writes to a file that is not a
  configuration file at all. A helper able to express them would no longer be a
  configuration helper. The count is three because the conversion was **run** and
  its counts asserted; reading the targets alone found only two.
- **FR-012a**: One site builds its body with a format substitution rather than a
  literal. Measured: it **converts cleanly**, because the body is a string
  parameter and the caller interpolates before calling. It needs no exception.
  This requirement originally guessed that this site would be the third
  exception. It is not — the third is the `profile`-carrying site above. The
  provision was right and its example was wrong.
- **FR-012**: A second named helper MUST replace the byte-cap idiom. It has
  **four** call sites — the requirement is naming and single-definition, not
  volume, and this document says so rather than implying otherwise.
- **FR-013**: The conversion MUST be mechanical. No assertion is added, removed
  or altered, and the number of tests does not move.
- **FR-014**: Neither helper may hide which file a site writes. A reader of any
  converted site must still see the target named at the call site.

**Scope discipline**

- **FR-015**: `handoff/hooks/context-guard.sh` MUST NOT be modified. A later
  phase owns it. This feature reads it.
- **FR-016**: No changelog entry is written. The campaign's routing ruling
  assigns this phase none.
- **FR-017**: The guard suite's directory is a registered **strict**-vocabulary
  surface. Every fixture this feature adds MUST stay inside that vocabulary — a
  banned term there reaches every install.
- **FR-018**: Every line reference carried in the seed MUST be re-derived from
  content before use. Done, and recorded above; three of eight had drifted.

### Key Entities

- **The guard**: the hook that measures how full the context window is and warns
  once per threshold bucket. It reads configuration, it reads a transcript, and
  it keeps small per-session flag files.
- **The payload**: what the harness hands the guard on its standard input — a
  transcript path, a session identifier and a working directory. Any of the
  three may be absent, and each absence has its own path.
- **The configuration**: a file the guard looks for beside the working directory
  and then at the repository root; values from it are overridden by the
  environment.
- **A flag file**: a small per-session marker the guard writes so it warns once
  per bucket rather than once per call, and sweeps when stale.
- **A reading**: one measurement taken from the transcript. Zero readings is a
  legitimate state with its own exit.
- **The configuration helper**: one named way to write a configuration fixture,
  replacing an incantation repeated twenty-seven times, and taking its target
  path so the two sites that write elsewhere are expressible.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The full house suite, run from the repository root, reports
  `1..154` with zero failures and zero non-conforming output lines. The starting
  point is `1..147`; the increase is exactly the seven new tests.
- **SC-002**: Each of the seven new tests is observed failing before it is
  trusted, by inverting its operative assertion — never by deleting the test —
  with the altered line echoed back before the failure is believed.
- **SC-003**: The suite holding these tests grows by exactly seven, and no other
  suite's count moves.
- **SC-004**: Each of the two configuration-discovery tests is shown to reach
  the configuration step, not to exit at the earlier gate.
- **SC-005**: After the conversion, the guard suite contains **exactly three**
  literal configuration writes — the patch-file site and the
  existing-configuration site, and the site whose object also carries a `profile`
  key — and **no others**. The twenty-six that were converted are written in one
  place, the helper's own body. The number is three rather than zero because
  those three write a shape a guard-only helper cannot express, and a check
  expecting zero would be red on a correct tree.
- **SC-006**: The converted sites are shown to be mechanical: the diff adds,
  removes and alters no assertion.
- **SC-007**: `handoff/hooks/context-guard.sh` is unchanged — its diff is empty.
- **SC-008**: No changelog file is modified.
- **SC-009**: Each override test goes red when its override is removed, and
  passes again when restored.
- **SC-010**: The existing documentation-snippet test is untouched and still
  passes.
- **SC-011**: Every ad-hoc verification search fires a control that must match
  before any zero is believed, and every needle is built where no escaping
  boundary can eat it.
- **SC-012**: The strict-vocabulary scan over the guard suite's directory passes
  with the new fixtures in place.

## Assumptions

- **The seed's list of seven behaviours is accurate and complete for its
  purpose.** Each was located in the hook by content before this specification
  was written, and all seven exist.
- **Two of the seven are reachable only by shaping the payload**, not by shaping
  a fixture, and both sit behind a gate that rejects a careless payload for a
  different reason. That is the hazard named in the Edge Cases.
- **The seed's count of twenty-seven is correct for the repository
  configuration file**, and its list of exceptions is one short. Measured.
- **The byte-cap idiom has four call sites.** Measured; the seed does not state
  a number for it.
- **The guard suite's directory is a strict-vocabulary surface**, so fixtures
  added here are scanned more tightly than the pipeline fixtures of Phase 9.
- **No machine-specific absolute path may enter any file this feature writes.**
  The tracked-tree scan covers this feature's own documents.
