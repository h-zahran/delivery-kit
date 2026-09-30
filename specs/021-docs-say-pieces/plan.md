# Implementation Plan: the documentation says pieces

**Branch**: `021-docs-say-pieces` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/021-docs-say-pieces/spec.md`

## Summary

Bring the user-facing documents in line with what Phases 20 and 21 made the
orchestrator do. Rewrite the false sites the spec's Context table lists, and
the stale rows found by reading, in `pipeline/docs/phases.md`,
`pipeline/docs/configuration.md`, `pipeline/README.md` and `README.md`; add a
short "reviewing a run commit by commit" section to `pipeline/README.md` and
one linked sentence to `README.md`; fix step 4 of
`pipeline/skills/status/SKILL.md`; make pre-flight item 9's "the feature's
commit" plural; and add two lines under the changelog's `## [Unreleased]` — the
status fix, and L's `--auto` stops (research R5). The orchestrator is the source of truth and is otherwise
untouched. Two pins in `pipeline/tests/prose.bats` change with the sentences
they pin; no test is added or removed. The contract,
[contracts/doc-sites.md](contracts/doc-sites.md), lists every site, its
verdict and what the new text must say.

## Technical Context

**Language/Version**: Markdown documents; one agent-read skill (`pipeline/skills/status/SKILL.md`) and one sentence of the orchestrator
**Primary Dependencies**: none new; the house suite's link checker and vocabulary scans (`tests/portability.bats`), and the configuration-page pins in `pipeline/tests/prose.bats`
**Storage**: n/a
**Testing**: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests` from the repository root; the per-claim greps in [quickstart.md](quickstart.md), each with a positive control
**Target Platform**: GitHub's Markdown rendering; the CI matrix (ubuntu, macOS, Windows Git Bash) for the suite
**Project Type**: documentation truth-pass inside a plugin repository
**Performance Goals**: n/a
**Constraints**: released `pipeline/CHANGELOG.md` sections byte-identical; no orchestrator sentence other than item 9 changes; no manifest changes (owner, at C); suite count `1..240` unchanged; STRICT-surface vocabulary (FR-013); the orchestrator's pinned spans are not touched (item 9 lies in none of them — research R3)
**Scale/Scope**: six files and two changelog lines, plus two pins

## Constitution Check

*Checked before research and again after design; both pass.*

| Principle | How this plan meets it |
|---|---|
| I. Silence is the failure | Every grep in the acceptance list is fired first against a known hit, so a grep that matches nothing cannot pass as "no stale claim". The same-file anchor at `README.md:14`, which the link checker skips, is checked by hand (research R4). |
| II. Measure; never assert | Every site was found by grep at `db2875d` and is listed with its line; the suite count is measured before (F.5) and after (J, N). "No released changelog byte changed" is a `git diff` against `db2875d`, not a claim. |
| III. A gate must be shown able to go red | The two pins that change are each run red under an inverted mutant of their new sentence before the change is kept. Each claim grep has its positive control. |
| IV. One implementation | The orchestrator's Gates section is the one statement of the floor; every document's floor text is checked against it, not against another document. |
| V. Derive coverage | The site list is derived by grep over `git ls-files`, not taken from the seed (the seed says not to trust its list); the final greps re-run over the same derived file set. No count is written into a shipped document. |

Surface rules: `pipeline/README.md`, `pipeline/docs/`, `README.md` and
`pipeline/CHANGELOG.md` are STRICT; `pipeline/skills/` is RELAXED. Changelog:
two Unreleased lines, under FR-008 (research R5).

## Project Structure

### Documentation (this feature)

```text
specs/021-docs-say-pieces/
├── spec.md
├── plan.md               # this file
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── doc-sites.md      # every site: verdict and what the new text must say
├── checklists/
│   └── requirements.md
└── tasks.md              # made by the tasks phase
```

### Source (repository root)

```text
README.md                          # root summary: heading, gate table, floor, rows, one new sentence
pipeline/README.md                 # gate table, floor, Build/Ship rows, flag row, new review section
pipeline/docs/phases.md            # G, H, H.5, H.7, I, L rows; the note under the table
pipeline/docs/configuration.md     # implementer row and section; :150 plural
pipeline/skills/status/SKILL.md    # step 4
pipeline/skills/pipeline/SKILL.md  # pre-flight item 9, one word
pipeline/tests/prose.bats          # two pins follow their sentences
pipeline/CHANGELOG.md              # two Unreleased lines (research R5)
```

**Structure Decision**: edit in place; no new file outside `specs/`.

## Complexity Tracking

None.
