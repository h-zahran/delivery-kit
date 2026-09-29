# Tasks: fixture for progress.sh piece-next

Built for pipeline/tests/progress.bats. The two long headings below are copied
byte for byte from specs/017-guard-config-bounds/tasks.md (lines 61 and 99):
real headings carry an em dash, an emoji and parentheses. Every task id from
T900 up is a decoy that must never be printed: each sits where a looser rule
would collect it.

## Format: `[ID] [P?] [Story] Description`

- [ ] T900 decoy under a non-piece heading

## Phase overview

- [ ] T902 decoy under a Phase heading with no number

## Phase 1 Setup

- [ ] T903 decoy under a Phase heading with no colon

## Phase 9B: uppercase suffix

- [ ] T904 decoy under a Phase heading with an uppercase letter

## Phase 1: Setup

- [X] T001 first setup task
  - [ ] T905 decoy indented, so the line does not begin with the task marker
- [ ] T002 second setup task

## Phase 2: Foundational

Prose only. A heading with no task line has nothing to build, so it is not a piece.

## Phase 3: User Story 1 — a percentage that can never arrive in time (P1) 🎯 MVP

### The first subheading

- [ ] T003 a task under a subheading
- [ ] T004 another task under the same subheading

### The second subheading

- [ ] T005 a task under the second subheading

## Phase 4: User Story 2 — the window size (P2) — a RULED NON-CHANGE

- [x] T006 a task marked done with a lowercase x

## Phase 9b: M — pull-request review, round 2 of 3 (2026-08-24)

- [ ] T007 a task under a lettered phase

## Dependencies

- [ ] T901 decoy after the last piece
