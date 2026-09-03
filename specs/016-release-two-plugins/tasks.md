---

description: "Task list for feature 016-release-two-plugins"
---

# Tasks: release pipeline 1.2.0 and handoff 2.1.1

**Input**: Design documents from `/specs/016-release-two-plugins/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/version-agreement.md](./contracts/version-agreement.md), [quickstart.md](./quickstart.md)

**Tests**: **NO test tasks.** The question was put to the owner at the clarify
gate on 2026-09-03 — the suite has no check for a dangling `## [Unreleased]`
heading and that is why one survived a release cycle — and the answer was to keep
the seed's scope: five files, nothing else. The gap is recorded in
`contracts/version-agreement.md` C4 for a later phase. Adding a test here would
override an answered decision.

**Organization**: grouped by user story. Note the unusual shape below: the six
edits are **Foundational**, not story work, because the transition is not atomic
and every intermediate state is invalid. See the Phase 2 purpose note.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel — different files, no dependency on incomplete work
- **[Story]**: US1, US2, US3 from spec.md
- Exact file paths in every description

## Path Conventions

This feature edits no source code. Its five target files are named in full,
every time, because the whole feature is "these five files and nothing else".

---

## Phase 1: Setup (preconditions)

**Purpose**: assert the ground truth before anything is written. A `sed` that
matches nothing exits 0 and changes nothing — success and total failure print the
same thing.

- [X] T001 Confirm the working tree is clean and HEAD is on branch `016-release-two-plugins` with `git status --porcelain` and `git branch --show-current`; the only expected untracked path is `specs/016-release-two-plugins/`  (covers: setup, no requirement)
- [X] T002 Run section 1 of `specs/016-release-two-plugins/quickstart.md` and require all six `expect_count` assertions to pass — two spaces of indent in each `plugin.json`, six in `.claude-plugin/marketplace.json`  (covers: precondition for FR-001 through FR-006)
- [X] T003 Run section 2 of `specs/016-release-two-plugins/quickstart.md` to record the derived `## [Unreleased]` line numbers in `pipeline/CHANGELOG.md` and `handoff/CHANGELOG.md`; do not hardcode them anywhere  (covers: precondition for FR-003, FR-006)

---

## Phase 2: Foundational (the six edits — BLOCKING)

**Purpose**: apply every version write. **No user story can be verified until all
six land**, because `tests/portability.bats` invokes
`scripts/check-versions.sh`, so any partial state is a genuine disagreement and a
suite run there goes red meaning "halfway", not "wrong".

**Tooling constraint, from research.md D1**: use `sed` on the exact line. **Never
`jq`.** Measured on 2026-09-03, a `jq '.'` round trip with no change rewrites all
three JSON files end to end — `.claude-plugin/marketplace.json` goes from 26
lines to 34 — because the tracked files keep an array inline and `jq` expands it.

- [X] T004 [P] Change `"version": "1.1.0",` to `"version": "1.2.0",` in `pipeline/.claude-plugin/plugin.json`, anchored to the two-space-indented line  (covers: FR-001)
- [X] T005 [P] Change `"version": "2.1.0",` to `"version": "2.1.1",` in `handoff/.claude-plugin/plugin.json`, anchored to the two-space-indented line  (covers: FR-004)
- [X] T006 [P] Change `## [Unreleased]` to `## [1.2.0] - 2026-09-03` in `pipeline/CHANGELOG.md`, matching the whole line and nothing else  (covers: FR-003)
- [X] T007 [P] Change `## [Unreleased]` to `## [2.1.1] - 2026-09-03` in `handoff/CHANGELOG.md`, matching the whole line and nothing else  (covers: FR-006)
- [X] T008 Change the pipeline entry's `"version": "1.1.0",` to `"version": "1.2.0",` in `.claude-plugin/marketplace.json`, anchored to the six-space-indented line  (covers: FR-002)
- [X] T009 Change the handoff entry's `"version": "2.1.0",` to `"version": "2.1.1",` in `.claude-plugin/marketplace.json`, anchored to the six-space-indented line  (covers: FR-005)

**T008 and T009 are deliberately NOT marked `[P]`.** They edit the same file, and
two agents never touch one file in the same batch. T004–T007 are `[P]` because
they are four different files.

- [X] T010 Run section 4 of `specs/016-release-two-plugins/quickstart.md` and require `git diff --numstat` to report exactly `1 1` for each of the four single-entry files and `2 2` for `.claude-plugin/marketplace.json`; anything larger means a reformat happened and the edits must be reverted and redone  (covers: FR-010, SC-004)

---

## Phase 3: User Story 1 — someone installing gets a named version (P1) 🎯 MVP

**Goal**: the three records of a version agree, for both plugins, on the intended
numbers.

**Independent test**: `bash scripts/check-versions.sh` from the repository root
exits 0 and prints two triples of three equal values — and the values are the new
ones, not merely equal to each other.

- [X] T011 [US1] Run section 6 of `specs/016-release-two-plugins/quickstart.md` — `bash scripts/check-versions.sh` from the repository root — and require exit 0  (covers: FR-011)
- [X] T012 [US1] Read back the two triples printed by `bash scripts/check-versions.sh` and require them to be exactly `handoff: plugin=2.1.1 marketplace=2.1.1 changelog=2.1.1` and `pipeline: plugin=1.2.0 marketplace=1.2.0 changelog=1.2.0`; exit 0 alone only proves the three agree, not that they agree on the right number  (covers: FR-011, SC-002)
- [X] T013 [US1] Require `jq -r '.plugins[] | "\(.name) \(.version)"' .claude-plugin/marketplace.json` to print `handoff 2.1.1` and `pipeline 1.2.0` — `jq` is safe here because this READS the file and never writes it  (covers: SC-003)

**Checkpoint**: US1 is complete and deliverable on its own.

---

## Phase 4: User Story 2 — a reader can tell which release contains a change (P2)

**Goal**: neither changelog carries an `## [Unreleased]` heading, and nothing
beneath either changed heading moved.

**Independent test**: a direct search finds no `## [Unreleased]` in either file,
and the range below each heading is byte-identical to `HEAD`.

**Why this cannot lean on Phase 3**: `scripts/check-versions.sh` is
**structurally blind** to a dangling heading. It reads the changelog with
`grep -m1` against a date-anchored pattern; `## [Unreleased]` does not match, so
it is skipped rather than rejected and an older heading is read instead. Measured
before any edit, the gate passed on the broken tree. See
`contracts/version-agreement.md` C4.

- [X] T014 [US2] Run section 7 of `specs/016-release-two-plugins/quickstart.md` and require `no_unreleased .` to report no dangling heading in `pipeline/CHANGELOG.md` or `handoff/CHANGELOG.md`  (covers: FR-008, SC-001)
- [X] T015 [US2] Run section 7b of `specs/016-release-two-plugins/quickstart.md` — the positive control — in the same shell as T014: rebuild the pre-fold changelogs from `HEAD` into a temporary directory, assert the control input really does carry `## [Unreleased]`, then require `no_unreleased` to REPORT A FINDING against it. If the control passes, T014 proves nothing and the release stops here  (covers: FR-008 positive control, Constitution III)
- [X] T016 [US2] Run section 5 of `specs/016-release-two-plugins/quickstart.md` against `pipeline/CHANGELOG.md` and `handoff/CHANGELOG.md`, and require both changelogs byte-identical below their heading line, with the line position derived from `HEAD` rather than assumed  (covers: FR-007)
- [X] T017 [US2] Require both new headings to match `^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$` including the trailing anchor — the exact pattern `scripts/check-versions.sh` parses, so a heading it silently skips is caught here instead  (covers: FR-009)

**Checkpoint**: US2 is complete. T015 is the task that makes T014 worth anything.

---

## Phase 5: User Story 3 — the release can be tagged (P3)

**Goal**: the versions just stamped are ones CI's tag gate will accept. **No tag
is created or pushed** — FR-015; tagging follows the merge and is the owner's.

**Independent test**: for each intended tag, strip the `-v` suffix and compare
the remainder against that plugin's manifest — the same three lines the workflow
runs.

- [X] T018 [P] [US3] Require the version half of `pipeline-v1.2.0` to equal `.version` in `pipeline/.claude-plugin/plugin.json`  (covers: US3 acceptance 1)
- [X] T019 [P] [US3] Require the version half of `handoff-v2.1.1` to equal `.version` in `handoff/.claude-plugin/plugin.json`  (covers: US3 acceptance 2)
- [X] T020 [US3] Confirm no tag was created by this feature with `git tag --list 'pipeline-v*' 'handoff-v*'`, and record the two commands the owner runs after the merge without running them  (covers: FR-015)

**Checkpoint**: US3 is complete. The tags themselves are out of scope.

---

## Phase 6: Polish & cross-cutting

- [X] T021 Run section 8 of `specs/016-release-two-plugins/quickstart.md` and require `git diff --name-only` to list exactly five paths: `.claude-plugin/marketplace.json`, `handoff/.claude-plugin/plugin.json`, `handoff/CHANGELOG.md`, `pipeline/.claude-plugin/plugin.json`, `pipeline/CHANGELOG.md`  (covers: FR-010, SC-004)
- [X] T022 Confirm `pipeline/scripts/preflight.sh` and `pipeline/tests/prose.bats` are unchanged — both carry comments naming the 1.1.0 release and are history, not version records  (covers: FR-010)
- [X] T023 Run section 9 of `specs/016-release-two-plugins/quickstart.md` — the full house suite over `tests`, `handoff/tests` and `pipeline/tests` from the repository root, naming all three suite paths — and require `1..163`, 163 ok, 0 not ok, exit 0. Do not pipe it into `head` or `tail`: a pipe hands the block the last command's status, always 0, and cuts the plan line bats prints first  (covers: FR-012, SC-005)
- [X] T024 Run the shell analyser as CI runs it — discovery by `git ls-files -z -- '*.sh' '*.bash' ':(exclude).specify/'`, then `shellcheck --norc -f gcc` over the result — and require it clean, remembering the runner ships an OLDER shellcheck that reports more  (covers: SC-005)
- [X] T025 Confirm `.specify/memory/constitution.md` is NOT among the five changed paths at commit time; it is staged as its own separate commit, because a governance file never rides inside a feature's commit  (covers: orchestrator rule, no requirement)
- [X] T026 Re-verify the MINOR bump justification: require the section under `## [1.2.0] - 2026-09-03` in `pipeline/CHANGELOG.md` to still contain an `### Added` heading. Added capability is what makes 1.2.0 a minor rather than a patch, and that evidence was last measured at the spec-quality gate, not at implementation time  (covers: FR-013)
- [X] T027 Re-verify the PATCH bump justification: require the section under `## [2.1.1] - 2026-09-03` in `handoff/CHANGELOG.md` to contain `### Changed` and NO `### Added` heading, and require the phrase `identical behaviour` to appear in neither changelog and in no commit or pull-request text this feature writes. That wording predates Phase 17 and is false; FR-014 forbids using it to justify the bump  (covers: FR-014)

---

## Dependencies

```text
Phase 1 (T001-T003)  preconditions
        |
        v
Phase 2 (T004-T010)  ALL SIX EDITS — blocking, no story verifiable before T010
        |
        +----------------+----------------+
        v                v                v
   Phase 3 (US1)    Phase 4 (US2)    Phase 5 (US3)
   T011-T013        T014-T017        T018-T020
        |                |                |
        +----------------+----------------+
                         v
                 Phase 6 (T021-T027)
```

- **US1, US2 and US3 are independent of each other** and may be verified in any
  order once Phase 2 is complete.
- **Nothing in Phase 2 may be verified in isolation.** The intermediate states
  are invalid by construction.
- T015 depends on T014 having defined `no_unreleased` in the same shell.

## Parallel execution

- **Phase 2**: T004, T005, T006, T007 are four different files and run together.
  T008 and T009 share `.claude-plugin/marketplace.json` and are serialised.
- **Phase 5**: T018 and T019 read two different manifests and run together.
- **Across phases 3–5**: the three stories are independent and their verification
  can be interleaved, capped at three parallel agents.

## Implementation strategy

**MVP is US1** — three records agreeing on the right numbers. That alone makes
both plugins installable at a named version.

**US2 is the reason the feature exists at all**, even though it is P2. US1 was
already "passing" before this feature began, on a broken tree, because the gate
cannot see what US2 checks.

**Increments**: Phase 2 is indivisible. After it, US1, US2 and US3 each stand
alone.

## Out of scope, recorded rather than dropped

- **A test for the dangling heading.** Asked at the clarify gate, answered no.
  `contracts/version-agreement.md` C4 carries the gap.
- **Creating or pushing the two tags.** FR-015. After the merge, the owner runs
  `git tag pipeline-v1.2.0 && git push origin pipeline-v1.2.0` and the same for
  `handoff-v2.1.1`, then watches both tag CI runs.
- **Merging the pull request.** The pipeline opens one and stops.
