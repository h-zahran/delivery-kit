# Feature Specification: the machine path leaves the repository

**Feature Branch**: `007-machine-path-guard`

**Created**: 2026-08-26

**Status**: Draft

**Input**: Campaign 2, Phase 7 of `main-plan.md` — "the machine path leaves the repository". Seed preserved verbatim at `.delivery-kit/runs/007-machine-path-guard/seed.md`.

## ⚠️ This specification is inside the surface it specifies

Every file in this directory is tracked, and the guard this feature builds
scans the whole tracked tree. **A concrete banned path written into any of
these documents becomes a hit on the guard they describe** — the spec, the
plan, the tasks file, the quickstart, and any research or contract file.

That is not a hypothetical. It is the exact mechanism that produced the
problem: a seed carried a machine path, the spec tool copied the seed into
`specs/`, and the path multiplied across six feature directories.

**The rule for every document in this feature: name a banned shape
descriptively, or assemble it from parts in a command. Never write one
joined.** Regex forms are safe to write out (the character after the final
slash is a bracket, not a name character); concrete example paths are not.
Only files under root `tests/` may write them joined, because root `tests/`
is outside the scan by construction.

## Clarifications

### Session 2026-08-26

- Q: The repository already holds one list of banned machine-path patterns,
  used by the checks that scan what a stranger installs. This feature adds a
  second, wider scan whose pattern is slightly tighter, so that deliberate
  elided prose survives. Should the two share one list, or stay separate?
  → A: Keep them separate, with a comment in each pointing at the other.
  Sharing the tighter pattern would change what the existing
  installed-surface checks catch, and this feature must change no existing
  behaviour. The drift risk that separation creates is accepted and recorded.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The maintainer stops publishing their own identity (Priority: P1)

The repository is public. Anyone who reads it — a prospective contributor, a
recruiter, an attacker doing reconnaissance — can currently read the
maintainer's operating-system account name 35 times, absolute drive-rooted
paths of their working directory six times, and one per-machine agent-projects
path: **43 lines across 17 files**. Six of those were found only during review,
in spellings the four banned shapes never covered. None of it is needed by anyone. It is there
because a working note was written on one machine and committed without anyone
noticing what the note contained.

**Why this priority**: It is the only finding in the whole review that is
already published. Everything else is a repository that could be better; this
is information that is out and cannot be recalled from anyone who has already
cloned. Every day it stays is another day of exposure, and every future
pipeline run that copies a seed makes more copies of it.

**Independent Test**: Clone the repository fresh, search the working tree for
the four banned path shapes, and find nothing. Delivers the whole of the
privacy value on its own, with no test and no comment change.

**Acceptance Scenarios**:

1. **Given** a fresh clone of the default branch, **When** the tracked tree is
   searched for a Git-Bash home prefix followed by a name character, **Then**
   no line matches.
2. **Given** the same clone, **When** it is searched for either Windows
   drive-path shape or for the per-machine agent-projects prefix followed by a
   name character, **Then** no line matches.
3. **Given** any file that was edited to remove a path, **When** its change is
   compared line by line against the previous version, **Then** only the path
   token differs — every surrounding word, number and date is identical.
4. **Given** the three deliberately elided prose references that name the
   shape without naming a person, **When** the tree is searched, **Then** those
   three lines are unchanged and do not match.

---

### User Story 2 - The guard that would have caught it exists (Priority: P2)

A scrub with no guard is a scrub that gets undone. The repository already
bans these shapes, and already has a test that enforces the ban — but that
test only reads the files a stranger installs, and the leak lived in the
working records, which no test reads. The next working record can reintroduce
it, silently, exactly as the last six did.

**Why this priority**: Second because the exposure is closed by Story 1 alone,
but this is what makes the closure permanent. Without it the same class of
change reopens the hole and nothing goes red.

**Independent Test**: Reintroduce a machine path into any tracked file outside
root `tests/`, run the suite, and watch it fail by name. Remove it, watch it
pass.

**Acceptance Scenarios**:

1. **Given** a clean tracked tree, **When** the suite runs, **Then** the new
   scan passes and reports the surface it covered.
2. **Given** a machine path planted in a tracked file outside root `tests/`,
   **When** the suite runs, **Then** the new scan fails and names the shape.
3. **Given** a companion control that must match, **When** the suite runs,
   **Then** it matches — proving the scan is capable of going red at all.
4. **Given** one of the scan's path operands is renamed or made unreadable,
   **When** the suite runs, **Then** the scan fails rather than silently
   reporting a clean surface.
5. **Given** the deliberately elided prose references from Story 1, **When**
   the scan runs, **Then** they do not match and the suite stays green.

---

### User Story 3 - The record stops describing a repository that no longer exists (Priority: P3)

The test file carries a long comment explaining which trees are scanned and
which are deliberately not, and why. The reasoning is still correct. Two of
its facts are two moves out of date: it names a directory that no longer
exists, and it does not know that the working records moved somewhere that IS
published. A reader trusting that comment would reach the wrong conclusion
about what is covered. Separately, a decision taken just before this feature —
retiring two stale workspace registrations while keeping their branches — has
no written record anywhere.

**Why this priority**: Third because nothing breaks if it waits. It is
included here because both records describe exactly the surface this feature
changes, and a comment corrected in the same change as the behaviour it
describes is a comment that stays true.

**Independent Test**: Read the corrected comment against the actual tree and
find no false statement. Read the amended ruling and find the decision, its
date, and what was deliberately kept.

**Acceptance Scenarios**:

1. **Given** the corrected comment, **When** each factual claim is checked
   against the tree, **Then** every claim holds.
2. **Given** the corrected comment, **When** a reader asks which mechanism now
   covers the working records for paths, **Then** the comment names it.
3. **Given** the amended ruling, **When** a reader asks what happened to the
   two retired workspaces, **Then** the record states that the registrations
   were removed, that the branches were kept, and why they must not be pushed.

---

### Edge Cases

- **A reference that names the shape but no person.** Three prose lines
  describe the problem using an elided form. One of them is the recorded
  deferral of this very sweep. Erasing them would erase the paper trail that
  explains why the debt existed. The scan's pattern must be narrow enough that
  a name character is required, so the elided form survives.
- **The scan's own file.** Root `tests/` holds the denylist and the fixtures
  the scanners are fired at. A scan covering it fails on its own contents.
  That tree is excluded by construction, and the exclusion must be stated as a
  construction reason, not an exemption. Re-measured 2026-08-26 after the
  guard landed: **eight** lines in that tree match — the two path denylists
  themselves, and six synthetic fixtures that exist so the scanners can be
  fired at something. Four of the eight were added by this feature. None is a
  leak, and none can be removed without disabling the check it serves.

  An earlier draft of this document said "exactly two", which was the count
  before this feature added its own control fixtures. It is corrected here
  rather than quietly, because a record making a false claim about what is
  scanned is precisely the fault this feature exists to fix, and shipping a
  fresh one inside the fix would be the joke writing itself.
- **The specification itself.** See the warning at the top of this document.
  Every file this feature produces lands inside the scanned surface.
- **A pattern that silently stops matching.** A search whose expression is
  mangled in transit reports zero hits and exits successfully — a result
  indistinguishable from a clean tree. Measured on this machine: a combined
  expression lost one level of escaping and reported nothing over a tree
  holding thirty-seven matches. Every check must fire a control that MUST match
  before any result claiming nothing matched is believed.
- **A rename or an unreadable file.** A search tool reports "found nothing"
  and "could not look" differently. A check that treats them alike switches
  itself off the moment a path is renamed.
- **A platform whose search tool differs.** The suite runs on three operating
  systems, one of which rejects a common word-boundary escape. Portable
  constructs only.
- **One line carrying two occurrences.** Counting lines and counting
  occurrences give different answers on at least one line. Both numbers are
  recorded so neither is mistaken for the other.

## Requirements *(mandatory)*

### Functional Requirements

**Removing what is published**

- **FR-001**: The tracked tree MUST NOT contain the maintainer's operating
  system account name in any path, anywhere — root `tests/` included. The
  scan's exclusion of that tree (FR-009) is about the denylist and the
  fixtures it holds, NOT a licence for an account name to live there.
  Measured 2026-08-26: root `tests/` contains no account name today, so this
  requirement is absolute rather than carved out.
- **FR-002**: Where a removed path named a test runner, the replacement MUST
  resolve to the same location on the maintainer's machine through a
  home-directory reference, and MUST contain no account name. The project's
  contributing guide already documents this exact spelling; the replacement
  MUST match it.
- **FR-003**: Where a site already resolves through an environment variable
  and then a search path before falling back to a literal, the resolution
  order MUST be preserved and only the fallback replaced.
- **FR-004**: Where a removed path has no portable equivalent because the
  surrounding text is prose describing a one-time measurement, the account
  name MUST be replaced by a neutral placeholder and nothing else in the line
  may change.
- **FR-005**: The tracked tree MUST NOT contain an absolute drive-rooted path
  to the maintainer's working directory.
- **FR-006**: The tracked tree MUST NOT contain an absolute per-machine
  agent-projects path. Where one is used as a pointer to a document, the
  pointer MUST survive as the document's name without its path.
- **FR-007**: Every edit made under FR-001 through FR-005 MUST be a token
  substitution. No surrounding word, number, date or line break may change.
  **FR-006 is the one exception, and it is deliberate**: the plan file's
  opening pointer is preamble rather than a dated log, and dropping its path
  leaves a sentence that has to be reworded to still read as English. Stated
  here because an Assumption blessing an exception the requirement forbids is
  a contradiction, not a carve-out.
- **FR-008**: The three elided prose references that name the shape without
  naming a person MUST be left exactly as they are.

**The guard**

- **FR-009**: The suite MUST gain a check that scans every tracked file except
  those under root `tests/` for four path shapes: the Git-Bash home prefix
  followed by a name character; the Windows user-directory prefix; the Windows
  drive root; and the per-machine agent-projects prefix followed by a name
  character.
- **FR-010**: The scan's expression MUST be assembled exactly once and MUST be
  the same expression its control uses. A control that exercises a different
  expression proves nothing about the scan.
- **FR-011**: The scan MUST assert the search tool's "found nothing" status
  specifically. A status meaning "could not look" — a renamed path, an
  unreadable file, an expression the platform rejects — MUST fail the check.
- **FR-012**: The suite MUST gain a companion check that fires the same
  assembled expression at a fixture that MUST match, and asserts that it does.
- **FR-013**: The companion check MUST carry a written statement of what it
  does and does not prove: that the scan is capable of failing, never that the
  scan fails only when it should.
- **FR-014**: The scan MUST NOT match the three elided prose references of
  FR-008.
- **FR-015**: The scan MUST use only constructs that behave identically on all
  three operating systems the suite runs on.
- **FR-016**: The existing per-surface vocabulary lists MUST NOT be widened to
  reach the working records. The vocabulary scans are scoped to what a
  stranger installs on purpose; nearly every working record matches the banned
  vocabulary by design, so registering them would fail the scan on contents
  that are correct.
- **FR-022**: The existing path denylist MUST NOT be modified. The new scan
  carries its own patterns, and the two lists stay separate. Each MUST carry a
  comment naming the other, stating that they are deliberately separate, that
  they cover different surfaces, and that a change to one is a prompt to
  consider the other. Neither comment may claim the two are kept in step
  automatically, because nothing does that.
- **FR-023**: Modifying the existing denylist to share the new tighter pattern
  is explicitly out of scope. It would change which lines the existing
  installed-surface checks catch — a behaviour change to a shipped gate, made
  as a side effect of a scrub.

**The record**

- **FR-017**: The comment describing which trees are scanned MUST have its
  false factual claims corrected while its design rationale is preserved.
- **FR-018**: That comment MUST name the new scan as the mechanism that now
  covers the working records for paths, and MUST state that the vocabulary
  scans still do not cover them.
- **FR-019**: The plan file MUST record, under the existing ruling about the
  retired workspaces, that both registrations were removed, that both branches
  were kept, that they remain unpushed, and why.

**Scope boundaries**

- **FR-020**: No plugin changelog entry is produced. This feature changes no
  behaviour a user of either plugin can observe.
- **FR-021**: No document produced by this feature may contain a joined banned
  path literal, for the reason stated at the top of this specification.

### Key Entities

- **Banned path shape**: One of four textual patterns that identify a location
  on one particular machine. Three name a person; the fourth names a drive
  layout. Each is already listed in the project's existing path denylist.
- **Scanned surface**: The set of files a check reads. This feature introduces
  a second, wider surface — every tracked file except root `tests/` — that
  coexists with the existing narrower vocabulary surfaces rather than
  replacing them.
- **Elided reference**: A prose mention of a banned shape with the identifying
  portion replaced by an ellipsis. Deliberate, documentary, and required to
  survive the scan.
- **Positive control**: A fixture that the scan MUST match, proving the scan
  can fail. Distinct from the scan itself, and load-bearing precisely because
  a mangled expression is indistinguishable from a clean tree.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A search of the tracked tree for any of the four banned shapes
  returns zero results, on the default branch, from a fresh clone. Before this
  feature the same four searches returned 35, 1, 0 and 1 results.
- **SC-002**: Forty-three lines across seventeen files change. Forty-two of
  them differ from their previous version by a path token and nothing else;
  the forty-third is FR-006's pointer, which is reworded under the exception
  FR-007 names. Proven mechanically by canonicalising every accepted spelling
  on BOTH sides of the diff and comparing: exactly one line survives as a
  non-substitution, and it is that one.

  An earlier draft said thirty-seven. That was true when it was written and
  went stale within this same feature, when review found six more sites in
  spellings the four shapes never covered. Corrected here rather than quietly.
- **SC-003**: The three elided prose references are byte-identical before and
  after.
- **SC-004**: Planting a banned path in any tracked file outside root `tests/`
  makes the suite fail, and the failure names the shape that matched. Removing
  it makes the suite pass again.
- **SC-005**: The whole suite reports 123 checks, all passing, no malformed
  output, run from the repository root — two more than the 121 measured before
  this feature, and no other movement.
- **SC-006**: The suite passes on all three operating systems in continuous
  integration.
- **SC-007**: Every factual claim in the corrected comment holds when checked
  against the tree.
- **SC-008**: No file produced by this feature matches the scan it describes.
- **SC-009**: Both path denylists carry a comment naming the other and stating
  that they are deliberately separate. A reader who changes one is told, in
  place, to consider the other.
- **SC-010**: The scan is demonstrated to fail before it is made to pass. It is
  run against the tree while the paths are still present and observed failing,
  and the failure output is recorded. Only then are the paths removed. A check
  that has only ever been seen green is not known to be a check at all.
- **SC-011**: The change adds no new banned vocabulary to any **scanned**
  surface. Measured 2026-08-26: the vocabulary scans read only the `SHIPPED_*`
  trees and the three relaxed pipeline directories, and this feature touches
  none of them. It does NOT claim the feature's own documents contain no banned
  word — they do, because the tasks file has to spell the denylist out to check
  it. That is exactly why `specs/` is not a vocabulary-scanned surface.

## Assumptions

- The maintainer's test runner lives at a fixed location beneath the home
  directory on this machine, so a home-directory reference resolves to the
  same place the removed absolute path named. Verified before the seed was
  written; the contributing guide already documents that spelling.
- The working records under the feature directories are dated evidence of
  completed work, not living documents. They are corrected for the path token
  and nothing else, because a record edited for style stops being evidence.
- The plan file's opening reference to a supporting document is preamble
  rather than a dated log, so rewording it to drop the path is in scope where
  rewording a record would not be.
- Root `tests/` stays outside the new scan permanently, not provisionally. It
  holds the denylist and the fixtures; that is a construction constraint, not
  a temporary exemption.
- The count of 121 checks is a measurement taken from the repository root on
  the merge commit this feature branches from, not an estimate.
- The retired workspace branches are the sole carriers of a history that has
  no common ancestor with the published branch. They are never pushed. This
  feature records that decision; it does not revisit it.

### What the guard covers, stated honestly

The account name is **removed and guarded**: zero occurrences anywhere in the
tracked tree, and any reappearance fails the suite.

Absolute working-directory paths are **removed but not guarded**. All six
sites in forward-slash and msys spellings — which the four banned shapes never
covered — were found during review and scrubbed; the tracked tree now holds
none. But the pattern was NOT widened to catch that class, so a fresh one
could land tomorrow without a test going red.

That was a decision, not an oversight, and it was measured. A branch of the
shape `[A-Za-z]:[\\/]` matches the colon-slash in every `https://` URL in the
repository. An msys branch broad enough to catch a drive-rooted path also
catches the elided form the narrowing exists to protect. The candidate produced
42 hits over a tree with none. A guard that cries wolf is a guard somebody
switches off, so this one stays narrow and says what it does not cover, rather
than going wide and becoming noise. Widening it properly needs its own design
pass and its own per-branch controls; it is not a thing to bolt onto a scrub.

Do not summarise this feature as "the exposure is closed". The accurate summary
is: **the account name is closed and guarded; drive-rooted paths are closed and
not guarded.**

### Accepted risks and recorded deferrals

- **Two denylists can drift.** The clarification above chose separation over a
  shared list, on the grounds that sharing would change a shipped gate's
  behaviour as a side effect of a scrub. The cost is real and is the same
  shape as a twin already flagged elsewhere in the review: two lists kept in
  step by hand. FR-022's cross-referencing comments are the mitigation, and
  they are a prompt, not a mechanism. Recorded so nobody later reads the
  separation as an oversight.
- **The drive-root shape names one drive letter.** The existing denylist bans
  a specific Windows drive root rather than any drive letter, and this feature
  matches the four existing shapes rather than extending them. A maintainer
  working from a different drive would not be caught. Deliberately deferred:
  the seed scoped this feature to the four shapes already banned, generalising
  the pattern is a change to what the repository considers a leak, and that is
  a decision to take on its own rather than inside a scrub. Recorded here so
  the gap is known rather than discovered.

