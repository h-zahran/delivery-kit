---

description: "Task list for the pipeline 1.3.0 stamp"
---

# Tasks: Release pipeline 1.3.0

**Input**: Design documents from `specs/022-release-pipeline-1-3-0/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/release-stamp.md, quickstart.md

**Tests**: no test is added — the spec asks for none, and the suite's count
must stay at the P22 figure (FR-007). Verification is `quickstart.md`, run as
one extracted script, plus the house suite inside it.

**Run directory**: `$RUN` = `.delivery-kit/runs/022-release-pipeline-1-3-0/`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency)
- **[Story]**: the user story the task serves

## Phase 1: Setup

**Purpose**: prove each edit's pattern matches exactly once before any file
is written (research R2).

- [X] T001 Count the edit patterns at the branch head and save the counts to `$RUN/t001-patterns.txt`: `grep -c '"version": "1.2.1"'` in `pipeline/.claude-plugin/plugin.json` and in `.claude-plugin/marketplace.json` must each be `1`, and `grep -c '^## \[Unreleased\]$'` in `pipeline/CHANGELOG.md` must be `1`. Any other count stops the run; no file is written by this task.

**Checkpoint**: three counts of 1, saved.

---

## Phase 2: User Story 1 — an installed user gets Campaign 3 (Priority: P1)

**Goal**: the three version sites read 1.3.0 and the changelog text is
unchanged beneath the new heading.

**Independent Test**: `quickstart.md` blocks 1–4 (clauses S1–S7, S10) print
`ok` each.

- [X] T002 [P] [US1] In `pipeline/.claude-plugin/plugin.json`, change the line `"version": "1.2.1",` to `"version": "1.3.0",` with `sed`, then confirm `git diff --numstat` for that file reads `1	1`.
- [X] T003 [P] [US1] In `.claude-plugin/marketplace.json`, change the pipeline entry's line `"version": "1.2.1",` to `"version": "1.3.0",` with `sed` (never `jq`, which reflows the file), then confirm `git diff --numstat` for that file reads `1	1` and the handoff entry still reads `2.2.0`.
- [X] T004 [P] [US1] In `pipeline/CHANGELOG.md`, change the line `## [Unreleased]` to `## [1.3.0] - 2026-10-01` with `sed` anchored to the whole line; change nothing else in the file, then confirm `git diff --numstat` for that file reads `1	1`.
- [X] T005 [US1] Run `quickstart.md` blocks 1–4 as one extracted script over `pipeline/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` and `pipeline/CHANGELOG.md`; save the output to `$RUN/us1-quickstart.txt`. Every clause prints `ok`; the S5 control goes red.

**Checkpoint**: User Story 1 is complete and independently checked.

---

## Phase 3: User Story 2 — the maintainer can tag with confidence (Priority: P2)

**Goal**: the agreement gate passes on the branch in both its forms, and its
tag form is shown to fail on the unreleased base.

**Independent Test**: `quickstart.md` block 5 (S8, S9) prints `ok`.

- [X] T006 [US2] Run `quickstart.md` blocks 1 and 5 (calling `scripts/check-versions.sh` with no argument and with `--released pipeline`, the latter also in a temporary worktree at `d9a085e`); save the output to `$RUN/us2-quickstart.txt`. S8 prints both plugins `state=released`, rc 0; S9 prints branch rc 0 and a non-zero base rc whose output carries the gate's own refusal, "this tree is NOT released".

**Checkpoint**: both stories complete.

---

## Phase 4: Polish

- [X] T007 Run the whole of `quickstart.md` (blocks 1–6 at T007; block 7, S12, was added at the PR review and is run from then on — including the house suite from the repository root over `tests`, `handoff/tests` and `pipeline/tests`) as one extracted script with `bash`, in the background or with a timeout of at least 15 minutes (the suite takes eight to ten); save the output to `$RUN/final-quickstart.txt`. It ends with `ALL OK`, and S11 reads plan `1..240`, 240 ok, 0 skipped, 0 not ok, 0 non-TAP.

---

## Dependencies & Execution Order

- T001 before T002–T004 (the counts are taken on the unedited files).
- T002, T003 and T004 touch three different files and may run in parallel.
- T005 after T002–T004. T006 after T005 (S8 reads all three sites). T007 last.
- Nothing here tags, pushes or publishes: the tag is pushed after the
  owner's merge, outside this run.
- SC-005 (CI on three systems, a run confirmed to exist, steps read one by
  one) has no task here, because CI runs only once the branch is pushed, and
  pushing is the orchestrator's phase L. The orchestrator itself reads no CI
  run, so this is a check the operator makes by hand after L's push and after
  any later push: in PowerShell (`gh` is not visible to bash on this machine),
  `gh run list --branch 022-release-pipeline-1-3-0` until a run for the head
  commit EXISTS, then `gh run view <id> --json jobs`, reading each job's step
  conclusions against SC-005's list. The result is saved in the run directory
  and stated in the pull-request body.

## Parallel Example: User Story 1

```text
T002 pipeline/.claude-plugin/plugin.json
T003 .claude-plugin/marketplace.json
T004 pipeline/CHANGELOG.md
```

Three one-line edits; serial execution is as fast, and is what this run does.

## Implementation Strategy

User Story 1 is the release; User Story 2 proves the gate the tag will run.
Both are needed before K. MVP = the whole list.
