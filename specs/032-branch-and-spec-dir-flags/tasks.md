# Tasks: the feature branch and the spec folder can be named for one run

**Input**: Design documents from `/specs/032-branch-and-spec-dir-flags/`

**Prerequisites**: plan.md, spec.md, contracts/flag-contract.md, quickstart.md

**Tests**: test-first. Eight pre-flight tests and one prose test. The full suite grows from `1..280` to `1..289`.

## Phase 1: User Stories 1 and 2 — the script

- [X] T001 [US1] [US2] In `pipeline/tests/preflight.bats`, add the eight "feature branch" and "spec folder" tests. Run them: all eight fail.
- [X] T002 [US1] In `pipeline/scripts/preflight.sh`, accept `--feature-branch <name>`, check it with `git check-ref-format --branch`, refuse the base branch's own name, and report `featureBranch`.
- [X] T003 [US2] In `pipeline/scripts/preflight.sh`, accept `--spec-dir <path>`, run the string checks before `cd`, the existence and state-file checks after it, and report `specDir`. T001's tests pass.

## Phase 2: User Stories 2 and 3 — the orchestrator and the docs

- [X] T004 [US2] [US3] In `pipeline/skills/pipeline/SKILL.md`: the two Flags rows, the pre-flight invocation sentence, the two probe lines, the git-absent marking for `Branch`, the **Feature branch and spec folder:** paragraph with the resume rule, and phase B.
- [X] T005 [US3] `pipeline/docs/configuration.md`: the "Feature branch and spec folder" section. Two flag rows in `pipeline/README.md` and in `README.md`.
- [X] T006 [US3] `pipeline/CHANGELOG.md`: a second Added entry under the existing `[Unreleased]`. `scripts/check-versions.sh` passes.
- [X] T007 [US3] In `pipeline/tests/prose.bats`, add "the feature-branch and spec-folder flags are pinned where the operator reads them".

## Phase 3: Verification

- [X] T008 Run the 26 mutations in `quickstart.md` §2 in a throw-away copy. Each must land, then go red.
- [X] T009 Run the full suite from the repository root, naming every suite path, with this feature's new files marked intent-to-add. Record in `quickstart.md` §3.
- [ ] T010 Shell analysis: run by CI's `shell-analysis` job. Not run locally: no analyser is installed on the machine that made this change.
