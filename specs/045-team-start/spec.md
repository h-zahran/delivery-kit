# Feature Specification: a member starts the next task, and anyone sees where the work stands

**Feature Branch**: `045-team-start`

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "Phase 45 — team:start asks the member once who they are, picks the next task, fills the pipeline's flags and runs it; team:status shows progress."

## Decision recorded first

Two facts found while designing changed the input:

| Fact | Where | Consequence |
|---|---|---|
| The pipeline skill is started by the `/pipeline` command "and by nothing else". | `pipeline/skills/pipeline/SKILL.md`, frontmatter | `team:start` prints the line; the member pastes it. |
| Pre-flight aborts on a changed tree. | `pipeline/skills/pipeline/SKILL.md`, decision item 5 | No progress file is written before a run. Status is read from git and the pull requests. |

Options shown to the owner before the overnight mandate: A (print the line; read status from git), B (members commit progress files in each PR), C (ask the maintainer to relax both pipeline rules). The agent chose A under that mandate: it changes no pipeline rule and cannot drift from git. The owner can reverse it.

## Changed on 2026-10-13, on top of the new upstream main

Two changes, approved by the owner ("make sure we don't use this manually"):

| Change | Why |
|---|---|
| **One answer per team.** `.delivery-kit/team.json` holds `{"members": {<team>: <member>}}`. `iam` adds or replaces one team and keeps the rest. `whoami` lists answers the settings or roster no longer hold as `stale`. A new command, `team.sh mine`, reads every team: the saved member and its next task, or the ids git's email suggests, and any fault. `team:start` asks once per team, shows each team's next task when two or more have one, and `team:start <team>` goes straight to one team. | A member in two teams (for example `madar` and `fe`) had to run `team.sh iam` by hand to switch. The two teams may give the member two different ids. |
| **How a run ended is the pipeline's rule.** A run `abandoned` by the pipeline reads as `abandoned`. A run at `DONE` with no pull request reads as `finished`. `next` passes over both. The rule is `RUN_END_JQ` in `pipeline/scripts/progress.sh`, copied, and a test runs the pipeline's script on real runs to check the copy agrees. | An abandoned run read as "in progress" and was offered for resume, which the pipeline refuses. A `DONE` run with no pull request read as "in progress". |

The first form of `.delivery-kit/team.json`, one `{team, member}` pair, is read as one answer. The plugin is unreleased, so that form exists only on the machines that tried it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A member starts the next task (Priority: P1)

A member runs `team:start`. The first time, it asks their team and id, suggesting the id that matches their git email, and keeps the answer in `.delivery-kit/team.json`. It checks the tree is clean, finds the next task, and prints the `/pipeline` line.

**Independent Test**: `team.sh next` returns `start` with the first task not started; `team.sh command` prints the line.

**Acceptance Scenarios**:

1. **Given** a task in progress with its run on this machine, **When** `next` runs, **Then** it returns `resume` for that task before any new one.
2. **Given** a task in progress with only a branch, **When** `next` runs, **Then** it returns `elsewhere`, never `start`.
3. **Given** every task in review, done or blocked, **When** `next` runs, **Then** it returns `none`.
4. **Given** a seed with a quote and a backslash, and a trailer with a space, **When** `command` runs, **Then** each is double-quoted and escaped.
5. **Given** a run the pipeline abandoned, or a run at `DONE` with no pull request, **When** `next` runs, **Then** it passes over that task.
6. **Given** answers saved for two teams, each with a task, **When** `team:start` runs, **Then** it shows each team's next task and asks which.

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

`team.sh iam` writes the answer only where git ignores it, one per team. `team.sh whoami` checks each against today's settings and roster. `team.sh suggest` only suggests. `team.sh mine` reads every team, and one team that cannot be read does not hide the others.

## Requirements *(mandatory)*

- **FR-001**: `team:start` MUST NOT start the pipeline. It MUST print the `/pipeline` line for the member to paste.
- **FR-002**: `team:start` MUST stop on a changed tree and MUST NOT stash, reset, check out or pull.
- **FR-003**: Status MUST NOT be stored. `team.sh status` MUST read the sources in the documented order and name the source and what was not read.
- **FR-004**: The `progress` key MUST be refused as unknown. `progressView` MUST be written only by `team.sh render`, when asked.
- **FR-005**: The task file MAY carry `blocked`, a string. Its seed MUST be one line.
- **FR-006**: `.delivery-kit/team.json` MUST be written only where git ignores it.
- **FR-007**: Each rule MUST be shown able to go red.
- **FR-008**: `.delivery-kit/team.json` MUST hold one answer per team, and `iam` MUST keep the other teams' answers.
- **FR-009**: An answer whose team or id is gone MUST NOT be used. `team:start` MUST ask again.
- **FR-010**: `team:start` MUST NOT choose between two teams for the member. It MUST NOT ask about a team that has no saved answer and no email match.
- **FR-011**: How a run ended MUST follow `RUN_END_JQ` in `pipeline/scripts/progress.sh`, and a test MUST check the copy against the pipeline's script.
- **FR-012** (final review, 2026-10-13): A fault in any read MUST stop the command with one `team.sh:` line and no answer on stdout. An empty file MUST be refused as not JSON.
- **FR-013**: A team key and a member id MUST start with a letter or a digit, so no path climbs out of the repository.
- **FR-014**: A pull request closed without a merge MUST NOT read as `in review`, even when the run recorded it.
- **FR-015**: `next` MUST return a task in progress before a new one, and MUST carry `originRead` and `prRead`.
- **FR-016**: `team:start` MUST NOT refuse a changed tree for `resume`.
- **FR-017**: The suite MUST NOT read the developer's git configuration or call a real `gh`.

## Success Criteria *(mandatory)*

- **SC-001**: The full suite passes from the repository root, naming every suite path.
- **SC-002**: Each mutation in `quickstart.md` turns its test red, or is shown to change no output, verified to have landed first.
- **SC-003**: `scripts/check-versions.sh` passes; `team` stays 0.1.0 (unreleased).

## Assumptions

- `team` is unreleased, so its 0.1.0 changelog entry is edited, not followed by a second heading.
- `gh pr list --state all --limit 1000` covers a team's pull requests. A repository with more is read partly, and the oldest are missed.
- `origin` is the remote's name, as the pipeline assumes.
