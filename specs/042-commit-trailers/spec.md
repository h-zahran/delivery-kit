# Feature Specification: every commit the run makes can carry trailers

**Feature Branch**: `042-commit-trailers`

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "Phase 42 — every commit the run makes can carry trailers. A team that tags its commits has no way to make the run add the tags."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A team's fixed trailers are set once (Priority: P1)

A team leader sets `commitTrailers` once in the repository's `.delivery-kit.json`, for example `["Team: <name>"]`, and commits it. Every commit every developer's run makes then carries those trailers. Pre-flight prints them, naming the file.

**Why this priority**: Without it, every message must be edited by hand after the run, which rewrites the branch the run recorded.

**Independent Test**: `preflight.sh --trailer 'Team: one'` reports `commitTrailers: ["Team: one"]`.

**Acceptance Scenarios**:

1. **Given** no trailer, **When** pre-flight runs, **Then** it reports `commitTrailers: []`.
2. **Given** two trailers, **When** pre-flight runs, **Then** it reports both, in the order given.

---

### User Story 2 - A run adds its own trailers (Priority: P1)

A developer types `--trailer 'Task: <id>'`. The run's commits carry the team's trailers and the task trailer. The flag adds to the key and never replaces it.

**Why this priority**: A team's fixed trailers must stay on every run, while each run tags its own task.

**Independent Test**: the orchestrator's **Trailers:** paragraph states the add rule, pinned by `pipeline/tests/prose.bats`.

---

### User Story 3 - A bad trailer stops before any commit (Priority: P2)

A developer who types a malformed trailer, or one using the run's own `Piece`, `Late` or `Tasks` token, is stopped at pre-flight, with the trailer named.

**Why this priority**: Principle I. Commits leave the machine. A bad trailer must fail loudly before the first commit, and a `Piece:` or `Late:` trailer would be read as a run marker by the crash scans.

**Independent Test**: `preflight.sh --trailer 'Piece: x'` exits non-zero, naming `'Piece: x'` and "reserved".

**Acceptance Scenarios**:

1. **Given** a trailer with no `:`, a token with characters outside letters, digits and dash, an empty value, or a line break, **When** pre-flight runs, **Then** it exits non-zero and names the trailer and `--trailer`.
2. **Given** the token `Piece`, `Late` or `Tasks` in any letter case, **When** pre-flight runs, **Then** it exits non-zero and says the token is reserved.

## Edge Cases

- **A message that already ends in trailers** (`Piece:`, `Late:`). The new trailer joins that paragraph. The `Piece:` or `Late:` line stays whole. Measured.
- **The same trailer twice.** It is added once (`--if-exists addIfDifferent`). Measured.
- **The handoff path.** Commits an external implementer makes are not touched.
- **git absent.** Decision 11 stops the run. The trailer checks never ask git.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The pipeline MUST accept a `commitTrailers` key and a repeatable `--trailer <token: value>` flag, documented in the orchestrator's Configuration and Flags tables, `pipeline/docs/configuration.md`, `pipeline/README.md` and the repository `README.md`.
- **FR-002**: The list MUST be the key's trailers, then each flag's, in order. The flag MUST NOT replace the key.
- **FR-003**: `preflight.sh` MUST accept `--trailer <text>` repeatedly, report `commitTrailers` in order, and refuse a malformed or reserved trailer, naming it and `--trailer`.
- **FR-004**: Every commit the run makes MUST carry the list: the spec commit, each piece, each late commit, J's empty record, K's commits and the constitution's commit.
- **FR-005**: The `progress.sh` commit subcommands MUST add the list, read from the state file's `config.commitTrailers` as data, through one shared helper. They MUST refuse an entry that is not a one-line string, is malformed, or uses a reserved token, naming it, with no commit made. They MUST NOT rewrite a message file the caller owns.
- **FR-006**: The list MUST be recorded with each entry's layer, read on a fresh run only, and a different list on a resume MUST be reported, never applied. On a resume the probe line MUST print the recorded list.
- **FR-007**: Each documentation site that states the rule MUST be pinned by a test, and each pin and each script check MUST be shown able to go red (Principle III).

## Success Criteria *(mandatory)*

- **SC-001**: The full suite passes from the repository root, naming every suite path.
- **SC-002**: Each mutation in `quickstart.md` turns its test red, and each is verified to have landed first.
- **SC-003**: `scripts/check-versions.sh` passes with the `[Unreleased]` entry above `[1.3.1]`.

## Assumptions

- The flag ADDS. This is the opposite of Phase 40's "flag beats key". A team's fixed trailers would be lost on every run that tags a task if the flag replaced the key.
- Between configuration files the key behaves as every key does: a later file's list replaces an earlier one's.
- The mechanism is `git interpret-trailers`, run by `progress.sh` on a copy of the message file, not `git commit --trailer`. Since `main` = `33bd148` every run commit goes through a `progress.sh` subcommand, and the run never re-creates one by hand.
- A message shown at a gate before its commit does not show the trailers. The commit carries them. The gate wording is not changed: the CTO plans work there.

### Changed after review 2 (2026-10-08)

- A message shown at K is shown WITH the trailers, through `progress.sh show-message`. The bullet above no longer holds. Reason: K's contract is "commits only what was shown", and a tracked `.delivery-kit.json` could add lines nobody saw.
- `git interpret-trailers` is replaced by lines the script appends itself. The same trailer is still added once.
- Refused from every layer, in any letter case: `skip-checks`, `Co-authored-by`, `Signed-off-by`, closing keywords as a token or before an issue number, the `[skip ci]` family, control characters, and tokens outside `^[A-Za-z][A-Za-z0-9-]*[A-Za-z0-9]$`. The full table is in `contracts/trailer-contract.md`.
- Pre-flight's errors end `(a commit trailer)`, not `(--trailer)`: the value may come from the key. Acceptance scenario 1 reads that way now.
- `Tasks` is reserved too. `piece-commit` and `late-commit H.5` write a `Tasks:` line, and `msg_body` already refuses one in a message.
