# Implementation Plan: shellcheck, and one version gate instead of two

**Branch**: `012-shellcheck-version-gate` | **Date**: 2026-08-30 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/012-shellcheck-version-gate/spec.md`

## Summary

Three independent changes to repository tooling, none of which touches a
plugin's behaviour.

1. A static shell analysis job is added to the continuous-integration
   workflow. It runs on one operating system, discovers its own file set
   from the repository's tracked-file record, and fails on any finding.
2. The version-agreement logic, which currently exists twice — once in
   the test suite and once inline in the workflow — becomes one script
   in a new top-level `scripts/` directory that both callers invoke. A
   new suite test asserts both callers name that one script, so a
   re-introduced hand-written copy fails the suite.
3. The third-party test runner the workflow clones is pinned to an
   immutable commit and cached, so an upstream retag cannot change the
   code the pipeline executes and three clones per run become one fetch
   per pin change.

## Technical Context

**Language/Version**: POSIX-oriented `bash`, held to what the three
matrix operating systems all provide. No feature newer than the shell
already used by `pipeline/scripts/progress.sh`.

**Primary Dependencies**: `jq` (already required by the existing gates
and installed by the workflow's `Ensure jq` step); `git` (for tracked-file
discovery); the static shell analyser (on the analysis job only); the
third-party test runner (on the test matrix only).

**Storage**: None. Every input is a tracked file.

**Testing**: The house test suite, run from the repository root over
`tests`, `handoff/tests` and `pipeline/tests`. Delta for this feature:
exactly one new test.

**Target Platform**: The existing three-operating-system matrix for the
suite; one operating system for the analysis job.

**Project Type**: Repository tooling for a two-plugin marketplace.

**Performance Goals**: The analysis job adds one short job to the run.
The runner cache removes three network clones per run in the common case.

**Constraints**: No plugin behaviour changes. No changelog entry. The
workflow file sits on the strict published-surface. The suite delta is
exactly one test. Every artefact this feature writes must carry no
absolute machine path.

**Scale/Scope**: Four analysed shell files today, discovered rather than
listed; two plugins; three version stamps per plugin.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution is the unfilled template. The owner was offered
`/speckit-constitution` at pre-flight and declined, so these gates run
against an empty document and cannot fail on a stated principle.

In place of stated principles, this plan is held to the repository's own
written constraints, which are enforced by its suite rather than by a
constitution file:

| Constraint | Where it comes from | Status |
|---|---|---|
| No absolute machine path in any tracked file | tree-wide scan in the suite | Checked, with a positive control, on every artefact written |
| No banned tool name on the strict published-surface | shipped-surface scan in the suite | The workflow is on that surface; every new word checked against the set before writing |
| Stage named paths, never a wildcard | repository constraint and the pipeline's own rules | Phase K names every path |
| Count-free shipped prose | repository constraint | The suite delta is stated as a delta, and no shipped file gains a count |
| Derive coverage, never enumerate it | repository's own recorded lesson | The analysis scope is discovered, not listed |

**Post-design re-check**: passed. The design adds one directory, one
script, one workflow job, one suite test and one inline suppression. No
gate above is weakened by any of them, and the discovery rule strengthens
the fourth and fifth.

## Project Structure

### Documentation (this feature)

```text
specs/012-shellcheck-version-gate/
├── plan.md                                # This file
├── spec.md                                # Phase B output, clarified at C
├── research.md                            # Phase 0 output
├── data-model.md                          # Phase 1 output
├── quickstart.md                          # Phase 1 output
├── checklists/requirements.md             # Spec quality record
├── contracts/
│   ├── version-agreement-contract.md      # What the shared script guarantees
│   └── shell-analysis-contract.md         # What the analysis job guarantees
└── tasks.md                               # Phase E output
```

### Source Code (repository root)

```text
.github/workflows/ci.yml     # EDITED — new analysis job; version job body
                             #   replaced by a script call; runner pinned
                             #   and cached
scripts/                     # NEW top-level directory
└── check-versions.sh        # NEW — the one version-agreement implementation
tests/
├── helper.bash              # EDITED — one inline suppression, with reason
└── portability.bats         # EDITED — the existing gate test now calls the
                             #   script; ONE new test asserts both callers
                             #   name that script
```

**Structure Decision**: A new top-level `scripts/` directory holds the
shared implementation. It is owned by neither the suite nor the workflow,
because both call it. It is inert with respect to every existing gate:
the plugin walk skips a directory carrying no plugin manifest, and the
published-surface lists are registrations rather than enumerations, so an
unregistered directory is simply not vocabulary-scanned. It is NOT inert
with respect to the new analysis job, and that is the point — the shared
script is discovered and analysed by the rule this feature introduces,
which is the first proof that rule works.

## Approach, change by change

### 1. The analysis job

- One job, one operating system, added beside the existing matrix rather
  than inside it.
- The analysed set is produced by asking git for tracked files matching
  the shell extensions, with the vendored scaffold directory excluded by
  pathspec. Measured on the development machine: the rule yields exactly
  the four first-party shell files today, and yields nothing when the
  exclusion is widened to everything — so the empty case is reachable and
  the guard against it is not decoration.
- An empty set fails the job with a named message, because a scan that
  read nothing and a scan that found nothing otherwise report the same
  clean result.
- The analyser is obtained the way the workflow already obtains `jq`:
  use what the runner image provides, install it if absent, and always
  print the version so the log records which analyser produced the
  verdict.
- There are no job-level suppressions. The single finding in the tree is
  suppressed at its own line, in the file that owns it, with the external
  reader named. That is the strongest available reading of "keep any
  disable list short and explicit": the list is empty.
- Test suites written for the test runner are outside the analysed set.
  The reason is measured, not assumed, and is written into the workflow:
  the analyser does read those files, and reports dozens of findings on
  them, of which the large majority are constructs the suites use on
  purpose — deliberate word-splitting in the leak scanners, and single
  quotes that must not expand in pattern fixtures. Bringing them in is a
  separate piece of work with its own suppression budget; this phase
  scopes to shell files, and says so rather than leaving the boundary
  unexplained.

### 2. One version gate

- `scripts/check-versions.sh` receives the whole of the current logic:
  the directory walk, every per-plugin check, the reverse walk over
  marketplace entries, the count reconciliation, and the non-empty guard.
- Diagnostics move into the script unchanged in substance, including the
  two that distinguish an absent value from a disagreeing one.
- The script refuses to run unless its working directory holds the
  marketplace manifest, so a caller that starts somewhere unexpected gets
  a named failure rather than a vacuous pass.
- The suite's existing gate test keeps its name and becomes a call to the
  script, so the suite's own record of what it covers stays continuous.
- The workflow's `version` job replaces its inline body with a call to
  the same script. The tag-matching step in that job is NOT part of the
  twin and is left untouched.
- One new suite test asserts that both callers name the one script. It is
  written so that it cannot match its own assertion text, and it is
  proven able to fail before it is trusted.
- Fallback, per the spec: if a single shared implementation proves
  unworkable, delete the workflow copy and let the suite gate stand
  alone. Not expected, and not to be taken because extraction is
  fiddly — only on a real obstacle, recorded with its reason.

### 3. Pin and cache the runner

- The workflow currently clones the runner at a tag. A tag is mutable: an
  upstream retag silently changes third-party code the pipeline executes.
- The pin is the commit the tag resolves to. The tag is annotated, so the
  upstream repository answers with two identifiers, and the one an obvious
  query prints first is the tag object rather than the commit. Measured:
  BOTH can be fetched and checked out, so an early draft of this plan was
  wrong to say otherwise. The commit is still the right pin, because it is
  what a checked-out copy reports as its own revision, and because a tag
  object's identifier changes when the same code is re-tagged with a
  different message.
- The human-readable release name stays in a comment beside the pin, so
  the pin remains readable.
- A cache keyed on the pin holds the fetched runner. Changing the pin
  changes the key and the cache misses, which is the behaviour wanted.
- The run line that invokes the runner is left alone. An existing suite
  test parses that line for its flags and its path operands; the changes
  here are confined to the steps above it.

## Complexity Tracking

> Filled only for choices that add structure, since the Constitution
> Check has no stated principles to violate.

| Addition | Why needed | Simpler alternative rejected because |
|---|---|---|
| A new top-level `scripts/` directory | Both callers need the script and neither owns it | Placing it in the suite has the workflow reaching into a test directory for a non-test; placing it beside the workflow has the suite reaching into the workflow directory, on a stricter surface than the script needs |
| An empty-set guard in the analysis job | A broken discovery reports exactly what a clean tree reports | Trusting the discovery makes the whole job unfalsifiable, which is the defect this repository keeps rediscovering |
| A working-directory guard in the shared script | Two callers start in two places | Assuming the caller's directory makes one caller silently examine nothing |
| One new suite test rather than none | Without it, a hand-written copy can return and pass | A comment asking maintainers to keep the pair in step is exactly what the workflow already had, and it drifted |
