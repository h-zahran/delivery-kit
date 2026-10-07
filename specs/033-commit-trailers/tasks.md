# Tasks: every commit the run makes can carry trailers

**Input**: Design documents from `/specs/033-commit-trailers/`

**Prerequisites**: plan.md, spec.md, contracts/trailer-contract.md, quickstart.md

**Tests**: test-first. Four pre-flight tests and one prose test. The full suite grows from `1..289` to `1..294`.

## Phase 1: User Stories 1 and 3 — the script

- [X] T001 [US1] [US3] In `pipeline/tests/preflight.bats`, add the four "trailers" tests. Run them: all four fail.
- [X] T002 [US1] [US3] In `pipeline/scripts/preflight.sh`, add `add_trailer`, accept `--trailer <text>` repeatedly, and report `commitTrailers`. T001's tests pass.

## Phase 2: User Story 2 — the orchestrator and the docs

- [X] T003 [US2] In `pipeline/skills/pipeline/SKILL.md`: the Configuration row, the Flags row, the pre-flight invocation, the probe line, the git-absent marking and the **Trailers:** paragraph. Leave the six commit sites' pinned text unchanged.
- [X] T004 [US2] In `pipeline/tests/prose.bats`, end the Phase 32 test's slice at **Trailers:**, the new paragraph after it.
- [X] T005 [US2] `pipeline/docs/configuration.md`: the JSON block, the key table and the "Commit trailers" section. One flag row in `pipeline/README.md` and in `README.md`.
- [X] T006 [US2] `pipeline/CHANGELOG.md`: a third Added entry under the existing `[Unreleased]`. `scripts/check-versions.sh` passes.
- [X] T007 [US2] In `pipeline/tests/prose.bats`, add "the commit trailers are pinned where the operator reads them".

## Phase 3: Verification

- [X] T008 Run the 20 mutations in `quickstart.md` §2 in a throw-away copy. Each must land, then go red.
- [X] T009 Run the full suite from the repository root, naming every suite path, with this feature's new files marked intent-to-add. Record in `quickstart.md` §3.
- [ ] T010 Shell analysis: run by CI's `shell-analysis` job. Not run locally: no analyser is installed on the machine that made this change.
