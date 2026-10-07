# Tasks: every commit the run makes can carry trailers

**Input**: Design documents from `/specs/042-commit-trailers/`

**Prerequisites**: plan.md, spec.md, contracts/trailer-contract.md, quickstart.md

**Tests**: test-first. Four pre-flight tests, eight `progress-git.bats` tests and one prose test.

## Phase 1: User Stories 1 and 3 — pre-flight

- [X] T001 [US1] [US3] In `pipeline/tests/preflight.bats`, add the four "trailers" tests. Run them: all four fail.
- [X] T002 [US1] [US3] In `pipeline/scripts/preflight.sh`, add `add_trailer`, accept `--trailer <text>` repeatedly, report `commitTrailers`, and reserve `Piece`, `Late` and `Tasks`. T001's tests pass.

## Phase 2: User Story 2 — the commits

- [X] T003 [US2] In `pipeline/tests/progress-git.bats`, add the eight "trailers:" tests: one per commit subcommand, J's `--record` included; a one-line subject; no list; a bad list. Run them: they fail.
- [X] T004 [US2] In `pipeline/scripts/progress.sh`, add `with_trailers`. Call it from `commit_named` and from J's `--record` commit. T003's tests pass, and every earlier test still passes.

## Phase 3: User Story 2 — the docs

- [X] T005 [US2] In `pipeline/skills/pipeline/SKILL.md`: the Configuration row, the Flags row, the probe line, and two names in the pointer list. The skill stays under 65,536 bytes.
- [X] T006 [US2] `pipeline/docs/configuration.md`: the JSON block, the key table, and the "Commit trailers" section with what the run does. One flag row in `pipeline/README.md` and in `README.md`.
- [X] T007 [US2] `pipeline/CHANGELOG.md`: a third Added entry under the existing `[Unreleased]`. `scripts/check-versions.sh` passes.
- [X] T008 [US2] In `pipeline/tests/prose.bats`, add "the commit trailers are pinned where the operator reads them".

## Phase 4: Verification

- [X] T009 Run the mutations in `quickstart.md` §2 in a throw-away copy. Each must land, then go red.
- [X] T010 Run the full suite from the repository root, naming every suite path, with this feature's new files marked intent-to-add. Record in `quickstart.md` §3.
- [X] T011 Run `shellcheck --norc -f gcc` 0.11.0 on `pipeline/scripts/preflight.sh` and `pipeline/scripts/progress.sh`: no finding.
