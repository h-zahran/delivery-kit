# Implementation Plan: release pipeline 1.2.0 and handoff 2.1.1

**Branch**: `016-release-two-plugins` | **Date**: 2026-09-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/016-release-two-plugins/spec.md`

## Summary

Stamp two versions and close two changelog headings. Six version strings across
five files; nothing else.

The technical approach is shaped almost entirely by one measured finding: **the
obvious tool rewrites the files.** A `jq` round trip with no change at all
rewrites all three JSON manifests end to end, because the tracked files keep an
array inline and `jq` expands it. So every edit is a line-anchored `sed` whose
match count is asserted before the write and whose diff is asserted to be one
line after it. See [research.md](./research.md) D1.

The second shaping finding is that **the gate guarding this release is blind to
the defect it fixes.** `scripts/check-versions.sh` passes today, on the broken
tree, because it reads the changelog with `grep -m1` against a date-anchored
pattern that `## [Unreleased]` does not match — so it silently reads the previous
release's heading. This plan therefore verifies the heading fold directly and
fires a positive control to prove that verification can fail.

## Technical Context

**Language/Version**: Bash (POSIX-ish, run under Git Bash on Windows and under
the runner's shell on Linux and macOS). No compiled language is involved.

**Primary Dependencies**: `jq` (for READING the manifests in checks — never for
writing them, per research D1), `grep`, `sed`, `git`, and `bats` v1.11.0 for the
suite.

**Storage**: N/A. The artefacts are five tracked text files.

**Testing**: `bats`, run from the repository root over three suite paths:
`tests`, `handoff/tests`, `pipeline/tests`. Plus `scripts/check-versions.sh`,
which is invoked both by the suite and by CI.

**Target Platform**: Linux, macOS and Windows under Git Bash. All three must
pass; a change green on one is not finished.

**Project Type**: A plugin marketplace repository publishing two Claude Code
plugins from one tree.

**Performance Goals**: N/A. Nothing in this feature runs at request time.

**Constraints**: Exactly five files may change. The content beneath each
changelog heading must be byte-identical before and after. No test may be added
or edited — the clarify gate settled that.

**Scale/Scope**: Six version strings, two headings, five files, one line changed
per file.

## Constitution Check

*GATE: passed before Phase 0. Re-checked after Phase 1 — result at the foot of
this section.*

Evaluated against `.specify/memory/constitution.md` v1.0.0.

| Principle | Verdict | How this plan satisfies it |
|---|---|---|
| **I. Silence is the failure that matters** | **PASS, and load-bearing** | The agreement gate is measured blind to a dangling heading (research D4). This plan does not lean on it. FR-008 is verified by a direct search, and T-numbered tasks assert a match COUNT before every write, because a `sed` that matches nothing exits 0 and changes nothing — success and total failure print the same thing. |
| **II. Measure; never assert** | **PASS** | Every design decision in research.md was produced by running something: the `jq` reformat, the gate's green-on-broken pass, the absence of version assertions in the suite, the `### Added` / `### Changed` evidence behind the minor-versus-patch calls. Nothing is argued from memory. |
| **III. A gate must be shown able to go red** | **PASS, with an obligation added** | This feature adds no gate, so the principle's "every new gate ships with a positive control" does not bind by its letter. It binds by its spirit anyway: the FR-008 check is new verification, and unproven verification is the thing this principle exists to stop. The plan therefore fires a positive control that runs the FR-008 search against a copy that still carries the heading, and requires it to report a finding. Separately, research D5 records that the manifest-versus-changelog comparison ALREADY has a positive control in `tests/portability.bats`, which rewrites a heading to 9.9.9 and requires the script to refuse it. |
| **IV. One implementation, many callers** | **PASS, not engaged** | No logic is written, so no pair can drift. The plan invokes `scripts/check-versions.sh` rather than restating what it does, which is the principle's positive form. |
| **V. Derive coverage; never enumerate it** | **PASS** | The "five files" figure was DERIVED by searching the tree for version strings, not listed from memory — and the search found two further matches that must NOT change, which a hand-written list would have missed in exactly the direction this principle warns about. |

**Section: "What ships, and what is scanned"** — all five edited files are
already registered on a shipped-surface list, so none becomes newly unscanned. No
file is added to a shipped tree. The changelog immutability rule is honoured by
FR-007, and its corollary — text under an open heading must be corrected BEFORE
the stamp freezes it — was honoured earlier the same day in commits `10ad24a`
and `c2259d5`, which is why this plan may treat the content as final.

**Section: "Development workflow"** — the suite runs from the repository root
naming all three paths; CI must be green on all three operating systems; the
commit names every path and stages no wildcard; the pull request is opened and
not merged.

**Post-Phase-1 re-check**: **PASS, unchanged.** The Phase 1 artefacts introduce
no new component, no new dependency and no new gate. The one obligation Principle
III added above is carried into `quickstart.md` as a runnable control rather than
left as a sentence.

## Project Structure

### Documentation (this feature)

```text
specs/016-release-two-plugins/
├── plan.md              # This file
├── spec.md              # Phase B output, clarified at C, hardened at C.5
├── research.md          # Phase 0 output — six measured decisions
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output — every block is meant to be RUN
├── contracts/
│   └── version-agreement.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase E output, not created here
```

### Source Code (repository root)

This feature edits no source code. Its "source" is five tracked metadata and
documentation files, and the exhaustive list is the deliverable:

```text
.claude-plugin/
└── marketplace.json          # two entries, one version string each

pipeline/
├── .claude-plugin/
│   └── plugin.json           # "version": "1.1.0" -> "1.2.0"
└── CHANGELOG.md              # "## [Unreleased]" -> "## [1.2.0] - 2026-09-03"

handoff/
├── .claude-plugin/
│   └── plugin.json           # "version": "2.1.0" -> "2.1.1"
└── CHANGELOG.md              # "## [Unreleased]" -> "## [2.1.1] - 2026-09-03"
```

Two further files match the outgoing version strings and MUST NOT be touched:
`pipeline/scripts/preflight.sh` and `pipeline/tests/prose.bats`, both of which
carry comments describing what the 1.1.0 release did. They are history.

**Structure Decision**: no new directory and no new file is created under any
shipped tree. Everything this feature produces beyond the five edits lives under
`specs/016-release-two-plugins/` and `.delivery-kit/runs/016-release-two-plugins/`,
neither of which ships or is scanned. The constitution written earlier in this
run lives at `.specify/memory/constitution.md` and is committed separately, per
the orchestrator's rule that a governance file never rides inside a feature's
commit.

## Complexity Tracking

No Constitution Check violations. This table is intentionally empty.

The feature is the simplest shape available: five single-line edits. The one
place where a simpler-looking option was rejected is recorded in research D1 —
`jq` is simpler to write and rewrites three files, so it is not simpler at all.
