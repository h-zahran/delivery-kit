# Feature Specification: a team plugin, set up once

**Feature Branch**: `034-team-plugin`

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "Phase 34 — a team plugin, set up once. A team that runs a shared plan through the pipeline repeats the same typing on every task. The setup must be written once, in the repository, and hold no team's own names."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A team leader writes the setup once (Priority: P1)

A team leader runs `team:setup`. It asks for each team's key, roster path, task-file path and progress path, writes them into the `team` block of the repository's `.delivery-kit.json`, keeps every other key, checks the result, and shows the change. The leader commits the file, and every member shares the setup.

**Why this priority**: Every later team skill reads this block. Without it, each member keeps their own paths, and they drift.

**Independent Test**: `team.sh config` on a repository with a well-formed block prints it as JSON.

**Acceptance Scenarios**:

1. **Given** a well-formed block, **When** `team.sh config` runs, **Then** it prints the teams and leaves the pipeline block out.
2. **Given** no block, **When** `team.sh config` runs, **Then** it fails, naming `team:setup`.
3. **Given** a block with an unknown key, a missing or non-string path, a bad team key, a path outside the repository, a roster path holding `{member}`, or a member path without `{member}`, **When** `team.sh config` runs, **Then** it fails, naming the fault.

---

### User Story 2 - The project writes the roster and the task files (Priority: P1)

A project writes, for each team, a roster file, and for each member a task file. Each task carries its ready branch, spec folder, seed, trailers and extra flags. The plugin reads them and builds no names.

**Why this priority**: Every team names its branches and folders its own way. The plugin must hold none of those rules.

**Independent Test**: `team.sh tasks <team> <member>` prints the member's tasks in file order, with `trailers` and `flags` defaulting to empty lists.

**Acceptance Scenarios**:

1. **Given** a roster with a malformed member, **When** `team.sh roster` runs, **Then** it fails, naming the member and the field.
2. **Given** a task with a missing or wrongly typed field, or two tasks with one id, **When** `team.sh tasks` runs, **Then** it fails, naming the task and the field.
3. **Given** a member not in the roster, **When** `team.sh tasks` runs, **Then** it fails, naming the member.

---

### User Story 3 - The plugin is registered like the others (Priority: P2)

The plugin appears in the marketplace, the root README (link and install line), the root changelog index, the suite command in CI and the contributing guide, this repository's `testCommand`, and `SHIPPED_TEAM`.

**Why this priority**: The repository's own gates demand each registration. A plugin missing from one is unscanned or untested.

**Independent Test**: the portability suite's registration tests pass, and each goes red when its registration is removed.

## Edge Cases

- **A team key or member id with a space.** Refused: each becomes a path segment.
- **A misspelt key in a team entry.** Refused by name, never ignored.
- **Missing task files during setup.** Reported, not fatal: the project may not have written them yet.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The repository MUST hold a `team` plugin at version 0.1.0 with `team:setup`, `scripts/team.sh`, a README, a configuration page and a changelog.
- **FR-002**: `team.sh config` MUST read only the repository's `.delivery-kit.json`, check the `team` block's shape and paths, and print it.
- **FR-003**: `team.sh roster <team>` and `team.sh tasks <team> <member>` MUST check shape only, name the first fault, and print the records with defaults filled.
- **FR-004**: `team.sh` MUST NOT check a branch name, a spec folder or a trailer's meaning; the pipeline's pre-flight does.
- **FR-005**: `team:setup` MUST write only the `team` key, pass every answer as data, put the file back when the result fails its check, and never commit.
- **FR-006**: The plugin MUST be registered in every place the repository's gates require.
- **FR-007**: Each rule MUST be shown able to go red (Principle III).

## Success Criteria *(mandatory)*

- **SC-001**: The full suite passes from the repository root, naming every suite path.
- **SC-002**: Each of the 47 mutations in `quickstart.md` turns its test red, and each is verified to have landed first.
- **SC-003**: `scripts/check-versions.sh` passes, reporting `team: plugin=0.1.0 marketplace=0.1.0 changelog=0.1.0`.

## Assumptions

- The project writes the task file. The owner chose this (2026-10-07): a JSON file per member, beside any readable copy, so the plugin never parses a project's markdown.
- Progress is a JSON record the plugin owns, with a readable copy written from it (owner's choice, 2026-10-07). Its format is fixed in Phase 35, which writes it.
- **Changed by Phase 35.** A stored progress record would make the working tree dirty, and the pipeline's pre-flight refuses a dirty tree. Phase 35 removes the `progress` key: status is read from git and the pull requests each time, and `progressView` is written only when asked. See `specs/035-team-start/spec.md`.
- The changelog's first heading is dated 2026-10-07. The release date is the maintainer's to set at release.
