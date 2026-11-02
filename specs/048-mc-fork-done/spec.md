# Feature Specification: A forked skill's robot moves to DONE when its work is over

**Feature Branch**: `048-mc-fork-done`

**Created**: 2026-11-02

**Status**: Draft

**Input**: Seed kept verbatim in the run directory as `seed.md`: in mission-control's pane, `/code-review` cards (forked skills) stay in RUNNING as "resting…" for hours after returning their findings.

## Context

mission-control draws one robot per helper loop. A helper started by the
Agent tool announces itself with `agent.spawn`; a skill that runs forked, such
as `/code-review`, does not, and mission-control joins it at its first event
from the engine's `$.agent.list()` (feature of mission-control 0.9.6).

The pane settles each helper's state from that list. The engine's own type
documentation (Claude Code 2.1.316, `AgentStatus`) says `idle` means "between
turns, until a message wakes it", and an ended agent is `completed`, `failed`
or `killed`. An Agent-tool subagent that finishes reports `completed`, and its
robot moves to DONE. A forked skill that has returned its result stays listed
and reports `idle`, because a message could still resume it. mission-control
maps `idle` to an idle robot and draws idle helpers under RUNNING ("their
robots doze"), so the card shows "resting…" until the session ends.

Keeping idle helpers under RUNNING is right for a teammate waiting for a
message or a subagent waiting on its own background job: both will work again
on their own. It is wrong for a forked skill, whose one task is over when it
goes idle.

## Clarifications

### Session 2026-11-02

- Q: Release mission-control 0.9.7 in this run, or fix only? → A: Release 0.9.7 in this run (FR-007).

## User Scenarios & Testing *(mandatory)*

The user is a person watching the mission-control pane while Claude runs
helpers.

### User Story 1 - A finished forked skill shows as done (Priority: P1)

A person runs `/code-review` (or the pipeline runs it). When the review returns
its findings, its robot moves from RUNNING to DONE, as an Agent-tool subagent's
does.

**Why this priority**: today RUNNING fills with cards that are not running,
which hides the helpers that are, and the counts above the prompt say helpers
are idle when none is.

**Independent Test**: an engine test joins a loop with no `agent.spawn`, has the
engine list report it `running` and then `idle`, and checks the robot is in
DONE with a done face and an end time.

**Acceptance Scenarios**:

1. **Given** a forked skill joined from the agent list, **When** the list reports it `idle`, **Then** its robot is drawn in DONE, not RUNNING, with the done face and its end time.
2. **Given** a forked skill shown in DONE, **When** the list reports it `running` again (a message woke it), **Then** its robot returns to RUNNING.
3. **Given** a forked skill the list reports `completed`, `failed` or `killed`, **When** the pane settles it, **Then** it shows done or failed exactly as today.

---

### User Story 2 - Other idle helpers keep today's behaviour (Priority: P1)

A teammate waiting for a message, or an Agent-tool subagent waiting on its own
background job, still shows in RUNNING with the dozing robot.

**Why this priority**: the fix must not hide helpers that will work again by
themselves.

**Independent Test**: an engine test spawns a helper with `agent.spawn`, has the
list report it `idle`, and checks it stays in RUNNING as "resting…".

**Acceptance Scenarios**:

1. **Given** a helper that announced itself with `agent.spawn`, **When** the list reports it `idle`, **Then** it stays in RUNNING with the idle face and "resting…".

### Edge Cases

- **The counts and the "work is over" signal**: a finished forked skill must count as done everywhere the pane counts helpers (the RUNNING header's working/idle numbers, the band above the prompt, the batch-end summary and sound), not as idle.
- **A reload of the mod**: a forked skill joined before a reload must still be known as forked after it, or it falls back to today's behaviour; the plan decides how, and a test covers it.
- **A forked skill that never went idle** (still running when the session ends): unchanged.
- **The engine one day reports a finished fork as `completed`**: already handled — it maps to done.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A helper that joined with no `agent.spawn` (a forked skill) MUST be shown as done — DONE section, done face, done words, end time recorded — when the engine's agent list reports it `idle`.
- **FR-002**: Such a helper MUST return to RUNNING when the list later reports it `running`, `waiting` or `pending`.
- **FR-003**: A helper that announced itself with `agent.spawn` MUST keep today's behaviour when idle: RUNNING, idle face, "resting…".
- **FR-004**: Every count that reads a helper's status (the RUNNING header's numbers, the band, the summary) MUST treat a finished forked skill as done. The batch-end toast and sound, which the fork's own `turn.complete` raises, MUST NOT be undone or raised twice; a fork's end settled only by the agent list behaves as any other end the list settles.
- **FR-005**: The forked/spawned distinction MUST survive a reload of the mod, or the plan MUST show why it need not.
- **FR-006**: mission-control's own test suite (`claude plugin test mission-control`) MUST include tests for FR-001, FR-002 and FR-003, each shown able to go red; `claude plugin validate mission-control` MUST pass.
- **FR-007**: `mission-control/CHANGELOG.md` MUST describe the fix, and this run MUST release it as mission-control 0.9.7: `mission-control/.claude-plugin/plugin.json` and the marketplace entry read `0.9.7`, the changelog section is dated, `scripts/check-versions.sh` agrees, and after the merge a `mission-control-v0.9.7` tag points at a commit holding the whole fix, with CI's tag step green.
- **FR-008**: The full suite — the four bats roots and mission-control's own tests — MUST pass, with no skipped test.

### Key Entities

- **Helper run**: mission-control's record of one helper loop: id, status, whether it joined from the list (forked) or came by `agent.spawn`, start and end times.
- **Listed status**: what `$.agent.list()` reports for an id: `pending`, `running`, `waiting`, `idle`, `completed`, `failed` or `killed`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In an engine test, a forked skill reported `idle` is drawn in DONE 100% of the time; reported `running` again, in RUNNING.
- **SC-002**: In an engine test, a spawned helper reported `idle` stays in RUNNING as "resting…".
- **SC-003**: mission-control's suite passes with the new tests (133 at `f569e9f`, plus the new ones), and each new test goes red when its rule is removed.
- **SC-004**: The full suite (bats roots and mission-control's tests) passes, no test skipped.

## Assumptions

- The engine reports a returned forked skill as `idle` (documented in the
  2.1.316 types; seen in the pane as "resting…", which only `idle` produces). It
  is not observed directly from `$.agent.list()` in this session.
- Whether a fork that went idle mid-task (waiting) can exist: the engine reports
  waiting on background work as `waiting`, not `idle`, so `idle` for a fork means
  its turn is over.
