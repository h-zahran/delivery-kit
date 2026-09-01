# Feature Specification: Pre-flight names git

**Feature Branch**: `013-preflight-git-probe`

**Created**: 2026-08-30

**Status**: Draft

**Input**: User description: "Pre-flight names git. `pipeline/scripts/preflight.sh` probes `jq`, `gh` and `adb` and reports `capabilities: { jq, gh, adb }` — while itself running four `git` commands and while pipeline phases B, K and L are git operations. On a machine without git, pre-flight reports a happy empty base branch and a clean tree, and the failure surfaces mid-run. That contradicts the plugin's own contract that every missing capability is named at pre-flight."

## Clarifications

### Session 2026-08-30

- Q: When git is missing, where in the pre-flight decision list should the stop fire? → A: First, before every other pre-flight decision. The new decision item is still written last so no existing item is renumbered; its own text states that it fires first.
- Q: What should the stop print as the install command, given three supported operating systems? → A: The official download page, `https://git-scm.com/downloads`, and nothing platform-specific.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A machine without git is told so, before any work starts (Priority: P1)

An operator starts a pipeline run on a machine that has no git. Today the probe
reports a clean tree and an empty base branch, the run proceeds through
specification, planning and implementation, and the first git operation fails
somewhere in the middle — after the operator has spent time and money on agents.

After this change the probe reports git as an absent capability, the pre-flight
walk names it, prints the install link, records the answer, and stops. Nothing
is installed on the operator's behalf.

**Why this priority**: This is the whole feature. Every other story serves it.

**Independent Test**: Run the probe with a search path that cannot find git.
The emitted report names git as absent, and the orchestrator's pre-flight walk
stops rather than continuing to the first phase.

**Acceptance Scenarios**:

1. **Given** a machine where git cannot be found on the search path, **When**
   the probe runs, **Then** its report says the git capability is absent, and
   the report is still complete, well-formed and readable by every existing
   consumer.
2. **Given** that report, **When** the pre-flight walk reads it, **Then** the
   walk names git as the missing tool, shows the install link, records
   the answer, installs nothing, and stops before any phase begins.
3. **Given** a machine where git is present, **When** the probe runs, **Then**
   its report says the git capability is present and the walk continues normally.

---

### User Story 2 - Existing consumers of the report are unaffected (Priority: P1)

Several suites and the orchestrator itself read the probe's report. Adding a
capability must not move, rename or re-type anything they already read.

**Why this priority**: A regression here breaks a shipped contract that the
suites and the orchestrator depend on, and it would break silently.

**Independent Test**: Run every existing probe test unchanged. All pass, and the
report still parses as a single well-formed document with no diagnostic text
mixed into it.

**Acceptance Scenarios**:

1. **Given** the change, **When** the existing probe suite runs, **Then** every
   existing test passes without being edited.
2. **Given** the change, **When** the probe runs on any project shape, **Then**
   its report parses cleanly and no pre-existing field has changed name, type or
   meaning.

---

### User Story 3 - The absence is a stop, not a degradation (Priority: P2)

The probe already announces phases it expects to skip when an optional tool is
missing. git is not optional: without it the run cannot branch, commit or push.
Announcing a skip would name a capability nobody acts on.

**Why this priority**: Choosing the wrong consequence would leave the original
defect in place under a new name.

**Independent Test**: With git absent, the report announces no additional skipped
phase on git's account; the consequence lives in the pre-flight walk as a stop.

**Acceptance Scenarios**:

1. **Given** git is absent, **When** the probe runs, **Then** the report's list
   of announced skips gains no entry attributable to git.
2. **Given** git is absent, **When** the pre-flight walk reads the report, **Then**
   it stops under the existing rule that a missing tool is its own question.

---

### Edge Cases

- **The probe itself needs git.** Four of the probe's own reads are git
  commands. With git absent every one of them must fail quietly and leave the
  report complete — the probe reports, it never crashes. The base branch and the
  tree state simply read as empty and clean, exactly as they do today; the
  difference is that the report now says why.
- **Absence is not the same as failure.** The probe asks only whether git can be
  found. A git that exists but errors is out of scope, and the walk's stop is not
  claimed to cover it.
- **The report is still complete when git is absent.** No consumer may have to
  handle a truncated or empty report as the signal for a missing git; the
  capability field is the signal.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The probe MUST report whether git can be found, as an additional
  entry in the capabilities it already reports.
- **FR-002**: The new entry MUST be additive. No existing entry in the report may
  change its name, its type or its meaning.
- **FR-003**: The probe MUST remain report-only when git is absent: it emits a
  complete, well-formed report and succeeds. It MUST NOT abort, and MUST NOT
  write diagnostic text into the report.
- **FR-004**: The probe MUST NOT add any new announced skip attributable to the
  git capability. The announced skips that already exist for an unreadable
  remote may still fire, because an unreadable remote is exactly what an absent
  git produces; what must not appear is a NEW rule that names a phase on git's
  own account.
- **FR-005**: The pre-flight walk MUST treat an absent git as a hard stop, under
  the orchestrator's existing rule that a missing tool is its own question: name
  the tool, show the install link, record the answer, install nothing.
- **FR-005a**: The install link shown MUST be the project's official download
  page, `https://git-scm.com/downloads`, and MUST NOT name any single platform's
  package manager. The pipeline supports three operating systems and cannot know
  which one is in front of it.
- **FR-006**: The stop MUST occur before any phase begins, so no artefact, branch
  or state file is created on a machine that cannot complete the run.
- **FR-006a**: The stop MUST fire before every other pre-flight decision. Two of
  those decisions — the dirty-tree refusal and the ignore-file probe — themselves
  call git, and every later one spends the operator's attention on a run that
  cannot happen.
- **FR-007**: The orchestrator's pre-flight description MUST account for git in
  both places a reader looks: the probe summary a reader sees printed, and the
  ordered list of pre-flight decisions.
- **FR-008**: Existing numbered pre-flight decisions MUST keep their numbers and
  their wording. The git decision is added after the last of them, and its own
  text states that it fires before all of them.
- **FR-009**: The probe suite MUST gain a test proving the capability reads
  present when git is findable, and a test proving it reads absent when git is
  not findable.
- **FR-010**: The absent-git test MUST build its own search path rather than
  reading the ambient environment, so it gives the same verdict on every
  supported platform.
- **FR-011**: The pipeline's own configuration document MUST be updated only if
  it enumerates capabilities; it MUST NOT be edited otherwise. Measured
  2026-08-30: it names no external tool at all, so this requirement resolves to
  "do not edit it". Re-measure before acting rather than trusting this line.
- **FR-012**: The pipeline's changelog MUST gain one entry under its existing
  unreleased heading, naming both the new probe and the stop, and stating no
  count that a later change would falsify.

### How each requirement is verified

Recorded here so the plan does not have to rediscover it. Note how much of this
list moved: most of the prose requirements were originally verified by a human
reading a document once, which is what three review rounds objected to.

- **By the two new probe tests**: FR-001, FR-003, FR-004, FR-009, FR-010.
- **By the new prose pin**, whose reach was mutation-measured: FR-005, FR-005a,
  FR-006a, FR-007, FR-008.
- **By the existing suite passing unedited**: FR-002.
- **By reading the changed documents**: FR-006, FR-012. FR-006 says the stop
  precedes any phase, which is a property of being a pre-flight decision at all
  and has no line to pin; FR-012 is a changelog entry.
- **By measurement, then a decision not to edit**: FR-011.

### Key Entities

- **Capability report**: the set of external tools the probe says can or cannot
  be found. Gains one member; loses none.
- **Pre-flight decision walk**: the ordered list of judgements the orchestrator
  makes from the report before any phase begins. Gains one item; renumbers none.
- **Announced skip**: a named phase the run expects to skip because an optional
  tool is missing. Gains nothing here, deliberately.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a machine without git, an operator learns that git is missing
  before the run creates its first artefact, rather than after implementation has
  begun.
- **SC-002**: The full house suite passes from the repository root with exactly
  **three** more tests than before this change, none failing and none malformed.

  This was two, matching the seed. The owner raised it to three after three
  independent review rounds each found that the feature's own behaviour — the
  stop, its ordering, the printed link, and the probe-block line — was guarded
  by nothing, and could be deleted with every suite green. The seed's number was
  arithmetic written before anyone knew this change would be mostly prose; the
  guard it was blocking is worth more than the arithmetic. The deviation is
  named here, in the pull request and in the commit rather than quietly taken.
- **SC-003**: Both new tests are observed failing before the probe change lands,
  proving each one tests what it claims.
- **SC-004**: Every existing probe test passes without being edited, proving the
  report's existing contract is intact.
- **SC-005**: Every string the suites pin in shipped prose is still present
  after the change.

## Known gaps, deferred with cause

Two review findings are real, are not fixed here, and are named rather than
left for a reader to discover. Both are blocked by a constraint this feature
was specified against, not by effort.

- **CLOSED, by the owner's decision, at the cost of the seed's test count.**
  This gap read: decision item 11 and the `git` probe-block line could both be
  deleted with the whole suite still green. It is now pinned by a test in
  `pipeline/tests/prose.bats`, which is why SC-002 says three rather than two.
  The pin's reach was measured, not assumed — five mutations, each caught:
  deleting the probe-block line; deleting item 11; inverting its ordering from
  fires-first to fires-last; restoring the over-reaching blanket not-read rule;
  and turning the stop into a warning.

- **`gh` and `adb` keep the boolean-type hole this change measured on them.**
  Switching either to `--arg` ships a string with the whole suite green, and a
  consumer writing `.capabilities.gh | not` reads the string `"false"` as
  truthy. Both new git tests assert the type; the two neighbours cannot, because
  giving them the same assertion means editing tests that already exist, which
  SC-004 forbids in this change. It is a one-line addition to each, and the
  measurement that proves it is needed is recorded in `data-model.md`.

- **Several reported fields still speak confidently from reads that never
  happened.** Named, not counted, because a count here would drift the way this
  repository has been bitten by before. With git absent: `baseBranch` reads
  empty, `baseBranchSource` still claims the branch was read from the current
  checkout, `remote.kind` reads `none` as though a remote had been looked for
  and not found, and `tree.dirty` reads `false` as though a tree had been
  examined. Making any of them honest means changing an existing field's type
  or meaning, which FR-002 forbids outright. The harm is bounded at the display
  layer — the orchestrator now prints those lines as *not read* rather than as
  values, and the stop fires before any decision consumes them — but the fields
  themselves are unchanged, and a wider fix belongs to its own change.

- **The probe asks only whether git can be FOUND.** A git that is present but
  refuses to operate — the ownership check that fires routinely on Windows, on
  shared checkouts and inside containers — reports `true`, the stop never
  fires, and the old silence survives for that cause. This is disclaimed in the
  specification's edge cases and in the contract, and the seed asked for
  `command -v` specifically. A usability probe rather than a findability one
  would cover both and costs about the same line; it is the natural next
  change, not this one.

## Assumptions

- The consequence of an absent git is a stop rather than a degradation. The
  description states this directly, and the probe's own reads plus three
  git-operating phases make continuing meaningless.
- The stop belongs to the orchestrator, not to the probe. The probe's stated
  contract is that it only reports, and the absent-git test needs a report to
  read — a probe that aborted would leave nothing to assert on.
- `pipeline/scripts/` and `pipeline/tests/` are relaxed vocabulary surfaces;
  `pipeline/docs/` is strict. The changelog is a strict surface too.
- Recording the answer follows the orchestrator's existing timing rule: state
  writes bind from the moment the state file exists, and on a fresh run no state
  file exists yet at pre-flight. There, the stop and the printed install link
  stand on their own. This is settled by existing orchestrator text and is not a
  new decision.
- Nothing in this change alters what the pipeline does once git IS present.
