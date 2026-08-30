# Implementation Plan: Pre-flight names git

**Branch**: `013-preflight-git-probe` | **Date**: 2026-08-30 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/013-preflight-git-probe/spec.md`

## Summary

Add one capability probe and one pre-flight decision. `preflight.sh` gains a
`command -v git` check beside the `gh` and `adb` checks and reports `git` in its
`capabilities` object; the orchestrator gains a decision item saying that an
absent git stops the run before any other pre-flight decision. Two tests, one
changelog entry, no change to any existing key or any existing decision item.

The script stays report-only. It does **not** abort when git is missing — the
absent-git test needs a report to read, and "the script only reports" is the
contract its own header states.

## Technical Context

**Language/Version**: Bash (must run under Git Bash on Windows, GNU bash on
Linux, and bash 3.2 on macOS); Markdown for the orchestrator and changelog.

**Primary Dependencies**: `jq` (already required and probed); `bats-core` for
the suites; `shellcheck` for static analysis.

**Storage**: N/A.

**Testing**: `bats-core`, run from the repository root:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`

**Target Platform**: Linux, macOS and Windows. CI runs all three; a test that
reads the ambient environment gives different verdicts on different runners, so
every capability test builds its own search path.

**Project Type**: Command-line plugin. The probe is a script whose stdout is a
machine contract; the orchestrator is a document read by a model.

**Performance Goals**: N/A. One extra `command -v`, once per run.

**Constraints**:

- Stdout stays pure JSON; every diagnostic goes to stderr.
- No existing key changes name, type or meaning.
- Exactly two new tests. A third would falsify SC-002.
- Every pinned string stays intact. `pipeline/tests/prose.bats` slices the probe
  block with `awk '/^Project type : /,/^Will skip /'` and the decision walk with
  `awk '/^The script only reports.../,/^\*\*Base branch:\*\*/'`, then pins
  strings inside each. Additions must not reword anything inside either slice.
  A new LINE inside a slice is safe — the slice grows, every pinned string is
  still found. Only the `Implementer` template line and item 10's operative
  sentence are pinned verbatim, and neither is touched.
- `pipeline/scripts/` and `pipeline/tests/` are relaxed vocabulary surfaces.
  `pipeline/CHANGELOG.md` is strict: it must not contain the banned tool names,
  so the changelog says "spec tool", never the tool's own package name.
- Changelog headings and count-free prose rules apply.

**Scale/Scope**: Three files edited, one changelog entry. Roughly 15 lines of
script and test, roughly 20 lines of prose.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

No constitution is set for this repository (`.specify/memory/constitution.md`
absent; the pre-flight probe reported `constitutionSet: false`). The owner was
offered the constitution command at pre-flight and declined. These gates
therefore run against an empty document and pass vacuously — recorded here so
the absence is visible rather than silent.

The repository's own governing constraints, which are NOT vacuous, are the
Constraints list above. They are checked at Phase F and again at Phase J.

**Post-design re-check**: unchanged. Nothing in the Phase 1 design introduces a
new dependency, a new surface, or a new consent point.

## Project Structure

### Documentation (this feature)

```text
specs/013-preflight-git-probe/
├── plan.md              # This file
├── spec.md              # The specification
├── research.md          # Phase 0 output — the four decisions and their evidence
├── data-model.md        # Phase 1 output — the capability report's shape
├── quickstart.md        # Phase 1 output — how to prove this works
├── contracts/
│   └── capabilities.md  # Phase 1 output — the probe's stdout contract
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
pipeline/
├── scripts/
│   └── preflight.sh          # the probe — gains one capability check
├── tests/
│   └── preflight.bats        # the probe suite — gains exactly two tests
├── skills/pipeline/
│   └── SKILL.md              # the orchestrator — gains one decision item
├── docs/
│   └── configuration.md      # measured: names no external tool; NOT edited
└── CHANGELOG.md              # gains one `### Added` entry under `## [Unreleased]`
```

**Structure Decision**: No new files. Every change is an addition to a file that
already exists, in the four directories listed above. The feature's whole
surface is one JSON key, one prose decision item, two tests and one changelog
entry.

### Exact insertion points, measured 2026-08-30

| File | Where | What |
|---|---|---|
| `pipeline/scripts/preflight.sh` | immediately before the `gh_present` line, beside the existing `gh` and `adb` probes | `git_present=false; command -v git >/dev/null 2>&1 && git_present=true` |
| `pipeline/scripts/preflight.sh` | the closing `jq -n` call | a `--argjson git "$git_present"` binding, and `git: $git` inside `capabilities` |
| `pipeline/tests/preflight.bats` | appended at the end | two tests |
| `pipeline/skills/pipeline/SKILL.md` | inside the probe block, immediately before the `Base branch` line | a `git` line of its own |
| `pipeline/skills/pipeline/SKILL.md` | after decision item 10, before the `**Base branch:**` paragraph | new decision item 11 |
| `pipeline/CHANGELOG.md` | under the existing `## [Unreleased]` | a new `### Added` section with one entry |

## Design decisions

Full reasoning and evidence in [research.md](./research.md). In brief:

1. **The script reports; the orchestrator stops.** The script's own header says
   it only reports and that a missing capability never crashes a phase. A `die`
   would also leave the absent-git test with no report to assert on.
2. **git is a capability, never a `willSkip` entry.** A `willSkip` entry names a
   phase that will be skipped. There is no such phase: without git the run
   cannot start.
3. **The new decision item is numbered last and fires first.** Numbering it 1
   would renumber ten existing items, which the specification forbids. Item 10
   already sets this precedent — it says its check fires before the walk begins.
4. **The absent-git test omits `git` from the suite's existing `PROBE_TOOLS`
   list.** The list already contains `git`; the test builds a search path from
   the other five entries. No new mechanism is invented.

## Complexity Tracking

No constitution violations to justify. The table is omitted.
