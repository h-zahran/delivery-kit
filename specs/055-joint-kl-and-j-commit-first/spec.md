# Feature Specification: One stop for K and L, and J commits before its last suite run

**Feature Branch**: `055-joint-kl-and-j-commit-first`

**Created**: 2026-11-03

**Status**: Draft

**Input**: Owner, after run 054's timing review: "merge K and L" and "let N reuse J's suite result", confirmed in their corrected form.

## Background

Run 054 measured 84 machine minutes and 113 minutes of waiting at gates; K
waited 55 minutes and L 28, one straight after the other. N ran the full
suite again (about 9 minutes) because J's late commit moved HEAD after J's
suite ran, and under `suiteReuse: commit` a new commit is a new state.

Checked before this spec (2026-11-03):

- Merging K and L removes one round trip, not the owner's reading time.
- Letting N reuse a result recorded BEFORE J's commit is not safe here:
  tests such as `tests/portability.bats` read `git ls-files`, so a tree
  before a commit does not prove the tree after it. The safe form is that
  J's last full-suite run happens on the commit J leaves, so N's lookup
  matches it under today's `commit` rule. No reuse rule is weakened.
- `late-commit` already refuses a second J commit only on the `--record`
  path (`progress.sh`, the "exactly once" checks); a second ordinary J
  commit is not refused by the script, only by the skill's prose.

## User Scenarios & Testing

### User Story 1 - One stop instead of two at the end (Priority: P1)

When K has nothing left to commit, the owner answers one question that
shows the commit list and the push and pull-request content together.

**Independent Test**: A run whose `<base>..HEAD` holds commits and whose
tree has nothing left for K to commit stops once between J and M, not twice.

**Acceptance Scenarios**:

1. **Given** commits on the branch and nothing left to commit at K,
   **When** the run reaches K, **Then** one stop shows K's full commit list
   (with `codeRoots` and every outside path marked) and L's branch name,
   title and full body, and one answer covers both.
2. **Given** something is left to commit at K (a remainder, a constitution
   commit, or J's record commit still to make), **When** the run reaches K,
   **Then** K and L stop separately, exactly as before this feature.
3. **Given** the joint stop, **When** the owner answers no, **Then** nothing
   is pushed and the run stops under the `--until` rule, as a no at K does.
4. **Given** the joint stop answered yes, **When** the run pushes, **Then**
   the guide is rebuilt first and must equal the one shown; if it differs,
   the run stops and asks again.

### User Story 2 - N cites J's suite run (Priority: P1)

When J changes files, its last full-suite run is on the commit it leaves,
so N can cite that run instead of running the suite again.

**Independent Test**: A run where J makes a late commit records a green
suite result whose key equals N's `suite-key`, and N's `suite-lookup`
exits 0.

**Acceptance Scenarios**:

1. **Given** J's first run is green and J changed no file, **Then** J makes
   no commit, as today.
2. **Given** J changed files (fixes, or a record it writes), **When** J ends,
   **Then** J commits them first and runs the full suite on that commit; J
   writes nothing after that run.
3. **Given** the run on J's commit is red with a new failure, **When** J
   fixes it, **Then** J makes another late commit and runs the suite again,
   within `maxVerifyIters`.
4. **Given** a red the owner waved through after J's last commit, **Then**
   the record still reaches a commit exactly once (J's empty record commit,
   or riding in a J commit).

### Edge Cases

- `--auto` collapses K and L already; the joint stop changes nothing then,
  and every stop `--auto` does not collapse (a path outside the feature, a
  commit K cannot show, a stale `commits` entry, an open waiting question)
  still stops.
- L's own checks (`record-branch`, a stale `commits` entry, `pending-check`,
  the guide's refusals) run BEFORE the joint question, so a yes is never
  followed by a stop that could have been raised first.
- A resume into L after a joint yes finds both `gates.K` and `gates.L`
  recorded and does not ask again; a resumed K whose commit list differs
  from what the answer covered asks again.

## Requirements

### Functional Requirements

- **FR-001**: When `<base>..HEAD` holds a commit and K has nothing left to
  commit (no remainder, no constitution commit, no J record commit to
  make), K and L MUST be asked as one stop, showing K's full content and
  L's full content.
- **FR-002**: Otherwise K and L MUST stop separately, unchanged.
- **FR-003**: L's checks that can stop the run (`record-branch` refusals, a
  stale `commits` entry, `pending-check`, the guide's refusals) MUST run
  before the joint question.
- **FR-004**: A joint yes MUST be recorded as `gates.K` in K's full shape
  (`list`, `answer`, the commit list and remainder it covered) and as
  `gates.L`, each marking that it was answered jointly.
- **FR-005**: Before the push, the guide MUST be rebuilt and compared with
  the one shown; a difference stops the run and asks again.
- **FR-006**: A joint no MUST push nothing and stop under the `--until` rule.
- **FR-007**: `--auto` behaviour MUST be unchanged; the gate table, the gate
  count and the "floor" paragraph MUST say when K and L are one stop.
- **FR-008**: When J has changed files, J MUST commit them (its late commit)
  before its last full-suite run, and that run MUST be on the commit J
  leaves. J MUST write nothing after its last full-suite run.
- **FR-009**: J MAY make more than one late commit, one per fixing
  iteration, within `maxVerifyIters`; the prose that says J commits once
  MUST change accordingly, everywhere it appears.
- **FR-010**: `late-commit J --record` MUST still put the record in a commit
  exactly once when J already made late commits, and `record-branch`,
  `commit-list` and `guide` MUST accept a branch holding several `Late: J`
  commits.
- **FR-011**: The docs (`pipeline/docs/phases.md`, and
  `pipeline/docs/configuration.md` where it says "N cannot cite J's run
  once K commits") MUST describe both changes.

## Success Criteria

- **SC-001**: A test proves two ordinary `late-commit J` calls in one run
  each record a `tests` commit, a second `snapshot late J` behaves as
  documented, and `--record` afterwards behaves per FR-010.
- **SC-002**: The prose pins in `pipeline/tests/prose.bats` and
  `pipeline/tests/skills.bats` cover the joint stop and J's commit-first
  rule, and each pin goes red when its sentence is removed (one mutation
  per pin, recorded).
- **SC-003**: The full suite from the repository root is green, with every
  existing test still passing.
- **SC-004**: The next real run measures: one stop between J and M when K
  had nothing to commit, and `suiteCited: true` when J made a commit.

## Assumptions

- No new configuration key and no new flag.
- Released as pipeline 1.9.0.
- Departure, named per the constitution's Governance: this change is built
  by helpers outside a pipeline run, so phases C, C.5 and F did not run; the
  integrated diff gets I's five review lenses before merge instead.
