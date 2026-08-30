# Feature Specification: shellcheck, and one version gate instead of two

**Feature Branch**: `012-shellcheck-version-gate`

**Created**: 2026-08-30

**Status**: Draft

**Input**: Campaign 2, Phase 12 of `main-plan.md` — "shellcheck, and one version gate instead of two". The seed is quoted verbatim in the run directory, under the run's `seed.md`.

## Clarifications

### Session 2026-08-30

- Q: Should the vendored third-party scaffold shell be inside the analysis scope? → A: No — out of scope, with the reason written into the workflow. It is not authored here and is regenerated whenever the upstream tool is re-run, so any fix made to it is discarded on the next upgrade.
- Q: How is the analysed set of files determined? → A: Discovered, not listed. The set is every tracked shell file minus the vendored scaffold directory, so a shell file added later is covered on the day it lands rather than when someone remembers to extend a list.
- Q: The one finding on a first-party file reports a variable set but never read within its own file, while the external test harness reads it. Fix or suppress? → A: Suppress, with a reason naming the external reader. The variable is used; the tool cannot see the user. No behaviour is changed to satisfy a tool.
- Q: Where does the single version-agreement implementation live? → A: In a new top-level scripts directory, owned by neither the test suite nor the workflow, since both call it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Shell code is statically analysed before it merges (Priority: P1)

A contributor opens a pull request that touches one of the repository's
own shell files. Today nothing reads that shell for defects; the only
signal is whether the behaviour tests happen to exercise the broken line.
The contributor wants an automated reviewer that reads every first-party
shell file on every pull request and names any defect it finds, so that
an unquoted expansion or a dead variable is caught by the machine rather
than by a reader.

**Why this priority**: This is the phase's headline. The repository ships
shell to other people's machines; static analysis is the cheapest defect
filter available and there is currently none at all.

**Independent Test**: Introduce one deliberate, real shell defect in a
first-party file. The new analysis reports it and the run goes red.
Revert the defect; the analysis reports nothing and the run goes green.

**Acceptance Scenarios**:

1. **Given** a tree whose first-party shell files are clean, **When** the
   continuous-integration run executes, **Then** the shell-analysis job
   reports no findings and passes.
2. **Given** a first-party shell file carrying one real, unsuppressed
   defect, **When** the continuous-integration run executes, **Then** the
   shell-analysis job names the file, the line and the defect
   identifier, and fails.
3. **Given** a finding the maintainers have decided not to change,
   **When** it is suppressed in the source, **Then** the suppression
   carries a written reason on or beside the suppressing line, and the
   job passes.
4. **Given** the analysis tool is unavailable to the runner, **When** the
   job executes, **Then** the job fails loudly rather than passing over
   an unanalysed tree.

---

### User Story 2 - One version-agreement gate, not a hand-maintained twin (Priority: P1)

A maintainer changes a plugin's version. Two independent copies of the
same agreement logic must both accept the change: one inside the test
suite, one inside the continuous-integration workflow. The workflow's own
comment records that the two are kept in step by hand and have already
drifted once. The maintainer wants the logic to exist once, so that the
two callers cannot disagree about what agreement means.

**Why this priority**: A duplicated gate that has drifted is worse than
one gate, because the drift is invisible until a release. The seed names
this as the same-priority half of the phase.

**Independent Test**: Remove a version value from any one of the three
places a version is recorded. Both the suite gate and the workflow gate
go red, and both report the same defect in the same terms.

**Acceptance Scenarios**:

1. **Given** a tree where every plugin's manifest, marketplace entry and
   changelog heading agree, **When** either gate runs, **Then** it
   passes.
2. **Given** a plugin whose manifest version and marketplace entry
   disagree, **When** either gate runs, **Then** both fail and both name
   the plugin and the two disagreeing values.
3. **Given** the shared logic is edited, **When** the suite runs, **Then**
   a test asserts that both callers invoke the one shared implementation,
   so a re-introduced hand-maintained copy cannot pass unnoticed.
4. **Given** a tree containing no plugin directory at all, **When**
   either gate runs, **Then** it fails rather than passing vacuously.

---

### User Story 3 - The third-party test runner is pinned and cached (Priority: P2)

Every continuous-integration run clones a third-party test runner from a
mutable reference on three operating systems. A maintainer wants that
dependency fetched from an immutable reference and reused between runs,
so that an upstream retag cannot silently change the third-party code the
pipeline executes, and so that three clones per run stop being paid for.

**Why this priority**: A supply-chain and cost improvement, not a
correctness gate. Real, but it does not block the phase's headline.

**Independent Test**: Read the workflow: the runner is fetched at an
immutable revision, the human-readable release name is preserved as a
comment, and a cache keyed on that revision is declared. A second run on
an unchanged revision restores from cache rather than re-fetching.

**Acceptance Scenarios**:

1. **Given** the workflow's runner installation step, **When** it is
   read, **Then** it names an immutable revision, and the corresponding
   release name appears as a comment so the pin stays readable.
2. **Given** two successive runs with the pin unchanged, **When** the
   second runs, **Then** it restores the runner from cache.
3. **Given** the pin is changed, **When** the next run executes, **Then**
   the cache misses and the runner is fetched afresh at the new revision.

---

### Edge Cases

- **Vendored third-party shell**: the repository carries vendored
  scaffold shell it does not author and must not gratuitously edit. The
  analysis scope MUST state whether that scaffold is in or out, and the
  reason MUST be written where a reader of the workflow finds it.
- **A file added to the analysed set later**: a scope written as a fixed
  list of filenames goes stale silently the moment a fifth first-party
  shell file lands. Resolved by FR-003: the set is discovered, so the
  staleness cannot arise.
- **A discovery that returns nothing**: a discovery rule that has broken
  — a renamed directory, an exclusion that swallowed everything —
  produces the same clean result as a clean tree. Resolved by FR-003a:
  an empty set is a failure.
- **A second vendored tree arriving later**: discovery admits it
  automatically, which is the cost of discovery. The exclusion is stated
  as a rule about vendored scaffold, so extending it is a one-line,
  visible edit rather than a silent omission.
- **Suppression without reason**: a bare suppression directive silences a
  real defect and reads as a fix. Such a suppression is not acceptable.
- **A finding the tool reports but the code does not have**: where a
  variable is consumed by an external harness rather than by the file
  that declares it, the tool cannot see the use. Such a case is
  legitimately suppressed, with the external consumer named in the
  reason.
- **The analysis tool absent from a contributor's machine**: local
  absence must not silently reduce the gate. The gate's authority lives
  in continuous integration.
- **A version recorded in one place and absent in another**: absence and
  disagreement are two different defects with two different fixes and
  MUST produce two different messages.
- **A stray carriage return from a text-mode tool on one platform**: the
  shared version logic runs on three operating systems and MUST NOT
  false-red a clean tree on any of them.
- **A test-suite caller and a workflow caller with different working
  directories**: the shared implementation must resolve the repository
  root the same way for both, or one caller silently examines nothing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The continuous-integration workflow MUST run static shell
  analysis over the repository's first-party shell files on every pull
  request and every push to the default branch.
- **FR-002**: The analysis job MUST run on one operating system only, and
  the workflow MUST say which.
- **FR-003**: The analysed set MUST be DISCOVERED from the repository's
  own record of tracked files, not enumerated as a list of filenames.
  The rule that produces the set, and the reason for its boundary, MUST
  be written into the workflow where a reader of the job finds it.
- **FR-003a**: The discovery MUST fail the job when it yields an empty
  set. A scan that read nothing and a scan that found nothing MUST NOT
  report the same result.
- **FR-004**: The vendored third-party scaffold shell MUST be excluded
  from the analysed set, and the reason — that it is not authored here
  and is regenerated by re-running the upstream tool, so a fix made to
  it is discarded on the next upgrade — MUST be written into the
  workflow.
- **FR-005**: Every finding the analysis reports on a file within scope
  MUST be either fixed in the source or suppressed with a written reason
  attached to the suppression. A suppression with no reason MUST NOT
  exist.
- **FR-006**: Any list of suppressed finding identifiers MUST be short
  and each entry MUST be individually justified. A blanket suppression
  of a broad class MUST NOT be used.
- **FR-006a**: Where a finding reports a variable set but never read
  within its own file, and an external harness is its real reader, the
  finding MUST be suppressed with a reason naming that reader. The
  source MUST NOT be altered to satisfy the tool, because changing what
  a variable exports to child processes is a behaviour change made for
  a cosmetic reason.
- **FR-007**: The analysis job MUST fail the run when it reports a
  finding, and MUST fail the run when the analysis tool cannot execute.
- **FR-008**: The version-agreement logic MUST exist in exactly one
  executable implementation in the repository, placed in a top-level
  location owned by neither the test suite nor the workflow, since both
  call it.
- **FR-009**: Both the test-suite gate and the continuous-integration
  job MUST obtain their verdict by invoking that one implementation.
  Neither MUST carry its own copy of the comparison logic.
- **FR-010**: The single implementation MUST preserve every check the
  two current copies perform: manifest name present; manifest version
  present; manifest name equal to its directory name; a marketplace
  entry existing under that name; that entry carrying a version; that
  entry's source resolving to the same directory; a changelog heading in
  the pinned format; manifest equal to marketplace; manifest equal to
  changelog; every marketplace entry naming an existing plugin
  directory; the two walks covering the same number of plugins; and at
  least one plugin directory found.
- **FR-011**: The single implementation MUST report a failure by naming
  the plugin and the specific values that disagree, distinguishing an
  absent value from a disagreeing one.
- **FR-012**: The single implementation MUST behave identically on the
  three operating systems the test matrix covers, including where a
  supporting tool emits carriage returns.
- **FR-013**: A test MUST assert that both gates call the one shared
  implementation, so that a re-introduced hand-maintained copy fails the
  suite rather than passing silently.
- **FR-014**: Removing a version from any one of the three recorded
  places MUST turn both gates red.
- **FR-014a**: If a single shared implementation proves unworkable, the
  documented fallback is to delete the workflow's copy and let the
  suite gate stand alone, since that gate already runs on all three
  operating systems and covers everything the workflow copy re-checks.
  Taking the fallback MUST be recorded with its reason, and MUST NOT be
  taken merely because extraction is harder than expected. Extraction is
  preferred, because it keeps the signal in the workflow where a
  reviewer sees it.
- **FR-015**: The third-party test runner MUST be fetched at an
  immutable revision rather than a mutable branch or tag reference.
- **FR-016**: The human-readable release name corresponding to that
  revision MUST be retained in a comment so the pin's meaning stays
  readable.
- **FR-017**: The workflow MUST cache the fetched test runner, keyed on
  the pinned revision, so that changing the pin invalidates the cache.
- **FR-018**: No plugin's runtime behaviour MUST change in this feature.
  The changes are confined to repository tooling, the workflow, the test
  suite and first-party shell sources.
- **FR-019**: No changelog entry MUST be added for this feature. The
  root changelog indexes plugin releases, and this feature releases no
  plugin.
- **FR-020**: The full house test suite, run from the repository root,
  MUST report exactly one more passing test than the pre-feature
  baseline and zero failures, and that additional test MUST be the
  assertion required by FR-013. No other test MUST be added. The
  demonstrations SC-001 and SC-010 require are performed against the
  working tree and recorded in the run's record; encoding either as a
  further suite test would break this count.
- **FR-021**: Every file this feature adds or edits MUST satisfy the
  repository's existing published-surface scans, including the
  absolute-machine-path scan that covers every tracked file.
- **FR-021a**: The workflow file sits on the repository's strict
  published-surface, whose scan rejects a fixed set of foreign tool
  names matched as whole words. Every word this feature writes into that
  file MUST be checked against that set before it is written. The names
  of the tools this feature introduces are not in the set; a name
  written as one joined word where the repository writes it hyphenated
  could be.
- **FR-022**: Every file this feature adds that is itself first-party
  shell MUST fall inside the analysis scope FR-003 defines, and MUST do
  so by virtue of the discovery rule rather than by being added to any
  list. The shared version-agreement implementation is one such file,
  and analysing itself is the first proof the discovery rule works.

### Key Entities

- **First-party shell file**: a tracked shell source this repository
  authors and ships or executes. Distinguished from vendored scaffold by
  authorship, not by location.
- **Vendored scaffold shell**: tracked shell obtained from an upstream
  tool, carried unmodified, and re-obtainable by re-running that tool's
  initialiser.
- **Version stamp**: one plugin's version as recorded in three places —
  its own manifest, its entry in the marketplace index, and the newest
  heading of its changelog. Agreement means all three carry the same
  value.
- **Version-agreement implementation**: the single executable that
  decides whether every version stamp in the repository agrees, and that
  both gates invoke.
- **Analysis scope**: the explicitly stated set of files the static shell
  analysis reads, together with the written reason for its boundary.
- **Suppression**: a directive that tells the analysis to ignore one
  finding, paired with the written reason it exists.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A tree carrying one real, unsuppressed shell defect in a
  file within scope is rejected by the automated checks; the same tree
  with the defect removed is accepted. Both directions are demonstrated,
  not asserted.
- **SC-002**: The number of executable copies of the version-agreement
  logic in the repository is exactly one, and the number of callers of
  it is two.
- **SC-003**: Removing a version value from any one of the three recorded
  places causes both version gates to fail; restoring it causes both to
  pass.
- **SC-004**: The full house suite, run from the repository root, reports
  exactly one more passing test than the pre-feature baseline, zero
  failures and zero non-conforming output lines.
- **SC-005**: The automated checks pass on all three operating systems in
  the existing test matrix.
- **SC-006**: Every suppression present in the tree after this feature
  has a written reason a reader can find without leaving the file.
- **SC-007**: A second automated run whose runner pin is unchanged
  obtains the third-party runner without re-fetching it from the
  network.
- **SC-008**: No plugin's version, manifest, changelog or user-visible
  behaviour differs before and after this feature.
- **SC-009**: A first-party shell file added after this feature, at any
  tracked path outside the vendored scaffold and carrying one of the
  shell extensions FR-003's rule matches, is analysed on the next run
  without any file being edited to admit it. The extension qualifier is
  deliberate and is the boundary FR-003 defines: a shell file added with
  no extension at all would not be discovered. Measured before this was
  written — no tracked file in the repository carries a shell shebang
  without one of those extensions, so the proxy is exact today.
- **SC-010**: A discovery rule that yields no files fails the job, and
  that failure is demonstrated rather than asserted. The demonstration
  is performed against the working tree and recorded; it does not become
  a suite test, because FR-020 fixes the suite delta at one.

## Assumptions

- The four first-party shell files named in the seed are the current
  first-party set. One of the seed's line counts is stale — the shared
  test helper has grown since the seed was written — but the file
  identities are unchanged. Line counts are descriptive in the seed, not
  normative.
- The seed's line-number references into the workflow and the test suite
  are approximate and have shifted since the seed was written. The
  constructs they point at are located by content, not by line number.
- Measured on the development machine before specification: the four
  first-party files produce exactly one finding today, an unused-variable
  report on a variable consumed by the external test harness. The
  vendored scaffold produces roughly ten finding lines across four
  identifiers. These measurements inform the scope decision; they are not
  requirements, and the implementation re-measures rather than trusting
  them.
- The static analysis tool is available to the continuous-integration
  runner's operating system through its standard package channel, and is
  available on the maintainer's machine for local verification.
- The three-operating-system test matrix stays as it is. This feature
  adds an analysis job beside it; it does not restructure the matrix.
- The repository's existing published-surface vocabulary scan does not
  cover the specification directory, but the absolute-machine-path scan
  does. Specification artefacts therefore must carry no machine paths.
- The shared version-agreement implementation is a shell program, because
  both callers are shell contexts and no other runtime is guaranteed
  present on all three matrix operating systems.
- The shared implementation lives in a new top-level scripts directory.
  Two alternatives were considered and rejected: placing it inside the
  test suite, which would have the workflow reaching into a directory of
  tests for something that is not a test; and placing it beside the
  workflow, which would have the test suite reaching into the workflow
  directory, and which sits on a stricter published-surface than the
  script needs. A new top-level directory is inert with respect to every
  existing gate: the plugin walk skips a directory carrying no plugin
  manifest, and the published-surface lists are registrations rather
  than enumerations.
- Discovery reads the repository's own record of tracked files. An
  untracked shell file is therefore not analysed, which is correct: an
  untracked file ships to nobody.
- The test-suite gate keeps its current test name, so that the suite's
  own record of what it covers stays continuous across this change.
