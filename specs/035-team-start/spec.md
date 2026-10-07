# Feature Specification: a member starts the next task, and anyone sees where the work stands

**Feature Branch**: `035-team-start`

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "Phase 35 — team:start asks the member once who they are, picks the next task, fills the pipeline's flags and runs it; team:status shows progress."

## Decision recorded first

Two facts found while designing changed the input:

| Fact | Where | Consequence |
|---|---|---|
| The pipeline skill is started by the `/pipeline` command "and by nothing else". | `pipeline/skills/pipeline/SKILL.md`, frontmatter | `team:start` prints the line; the member pastes it. |
| Pre-flight aborts on a changed tree. | `pipeline/skills/pipeline/SKILL.md`, decision item 5 | No progress file is written before a run. Status is read from git and the pull requests. |

Options shown to the owner before the overnight mandate: A (print the line; read status from git), B (members commit progress files in each PR), C (ask the maintainer to relax both pipeline rules). The agent chose A under that mandate: it changes no pipeline rule and cannot drift from git. The owner can reverse it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A member starts the next task (Priority: P1)

A member runs `team:start`. The first time, it asks their team and id, suggesting the id that matches their git email, and keeps the answer in `.delivery-kit/team.json`. It checks the tree is clean, finds the next task, and prints the `/pipeline` line.

**Independent Test**: `team.sh next` returns `start` with the first task not started; `team.sh command` prints the line.

**Acceptance Scenarios**:

1. **Given** a task in progress with its run on this machine, **When** `next` runs, **Then** it returns `resume` for that task before any new one.
2. **Given** a task in progress with only a branch, **When** `next` runs, **Then** it returns `elsewhere`, never `start`.
3. **Given** every task in review, done or blocked, **When** `next` runs, **Then** it returns `none`.
4. **Given** a seed with a quote and a backslash, and a trailer with a space, **When** `command` runs, **Then** each is double-quoted and escaped.

---

### User Story 2 - Anyone sees where the work stands (Priority: P1)

A team leader runs `team:status`. Each task's status is read from its pull request, the run state, a `blocked` note, or its branch, and the source is named. What could not be read is said.

**Independent Test**: `team.sh status` on a scratch repository with one task per source returns each status with its source.

**Acceptance Scenarios**:

1. **Given** a merged pull request, **Then** done; an open one, in review; a closed one, not done.
2. **Given** no `origin`, **Then** `originRead` is false, and a branch only on another machine is not shown.
3. **Given** a `gh` that fails, **Then** `prRead` is false.

---

### User Story 3 - The member's identity is asked, never guessed (Priority: P2)

`team.sh iam` writes the answer only where git ignores it. `team.sh whoami` checks it against today's roster. `team.sh suggest` only suggests.

## Requirements *(mandatory)*

- **FR-001**: `team:start` MUST NOT start the pipeline. It MUST print the `/pipeline` line for the member to paste.
- **FR-002**: `team:start` MUST stop on a changed tree and MUST NOT stash, reset, check out or pull.
- **FR-003**: Status MUST NOT be stored. `team.sh status` MUST read the sources in the documented order and name the source and what was not read.
- **FR-004**: The `progress` key MUST be refused as unknown. `progressView` MUST be written only by `team.sh render`, when asked.
- **FR-005**: The task file MAY carry `blocked`, a string. Its seed MUST be one line.
- **FR-006**: `.delivery-kit/team.json` MUST be written only where git ignores it.
- **FR-007**: Each rule MUST be shown able to go red.

## Success Criteria *(mandatory)*

- **SC-001**: The full suite passes from the repository root, naming every suite path.
- **SC-002**: Each mutation in `quickstart.md` turns its test red, verified to have landed first.
- **SC-003**: `scripts/check-versions.sh` passes; `team` stays 0.1.0 (unreleased).

## Assumptions

- `team` is unreleased, so its 0.1.0 changelog entry is edited, not followed by a second heading.
- `gh pr list --state all --limit 1000` covers a team's pull requests. A repository with more is read partly, and the oldest are missed.
- `origin` is the remote's name, as the pipeline assumes.
