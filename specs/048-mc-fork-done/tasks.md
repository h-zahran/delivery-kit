# Tasks: A forked skill's robot moves to DONE when its work is over

**Input**: `specs/048-mc-fork-done/` (spec.md, plan.md, research.md, quickstart.md)

**Tests**: test-first; the new tests are run red on the old code before the fix.

## Phase 1: User Stories 1 and 2 — a finished fork is done; other idle helpers are not (Priority: P1) 🎯 MVP

**Goal**: a forked skill reported `idle` is drawn in DONE; spawned idle helpers stay in RUNNING.

**Independent Test**: `claude plugin test mission-control` passes; the new fork tests fail on `f569e9f`'s `register.tsx`.

- [X] T001 [US1] In `mission-control/hooks/forked.test.tsx`, add tests (name each starting `forked:`): (a) a fork whose `turn.complete` marked it done, with the list then reporting it `idle`, is still `done` after the clock passes the 5 s revive point and two reconcile beats, and the pane shows it under DONE, not RUNNING; (b) a fork whose end no `turn.complete` showed, with the list reporting `idle`, becomes `done` with an end time; (c) a fork shown done that the list then reports `running` returns to RUNNING. Use the file's existing `agentList`, `agentWrites`, `mock.clock` and `$.ui.mount(PANE)` patterns. Run them against the unchanged `register.tsx` (copy the mod to a scratch folder and delete the other `*.test.*` files to run one file) and confirm (a) and (b) FAIL; keep the output for T011.
- [X] T002 [US2] In `mission-control/hooks/forked.test.tsx`, add a test: a helper made by `agent.spawn`, with the list reporting it `idle`, stays in RUNNING with "resting…" (status `idle`).
- [X] T003 [US1] In `mission-control/types/index.d.ts`, add `forked?: boolean` to `AgentRun`, documented: joined from the engine's list with no `agent.spawn` (a forked skill); its idle means its task is over; absent on a run an older version stored.
- [X] T004 [US1] In `mission-control/hooks/register.tsx`: `addRun` stores `forked: true` for a join (`isJoin`), and a spawn that replaces a joined run does not carry it; add one top-level function giving the status a listed value means for a run (forked + `idle` → `done`, else `mapStatus`); in `reconcile`, use it in the change check and the write, and do not count a listed `idle` as a revival for a forked run. An end reached this way gets `endedAt` and settled tools like any end. Update the comments around `isLive`/`REVIVE_*` to say a fork's idle is its end.
- [X] T005 [US1] Check batch end (R4): if `reconcile` raises no batch-end toast or sound for an end it settles today (a listed `completed`), leave it so and say so in the comment; if it does, make a fork's idle end raise it too. Add or adjust a test only if behaviour changes.
- [X] T006 Run `claude plugin validate mission-control` and `claude plugin test mission-control`: validate passes, 0 fail.

**Checkpoint**: the bug is fixed and pinned.

---

## Phase 2: A reload keeps the fix (FR-005)

- [ ] T007 In `mission-control/hooks/forked.test.tsx`, add a test that seeds `$.state` `agents` with a run as this version stores it (`forked: true`, status `running`) and one as 0.9.6 stored it (no `forked`), lists both `idle`, ticks reconcile, and checks the first is `done` and the second `idle` (today's behaviour). Run the suite: 0 fail.

---

## Phase 3: Release mission-control 0.9.7

- [ ] T008 In `mission-control/CHANGELOG.md`, add `## [0.9.7] - 2026-11-02` with `### Highlights` and `### Fixed` entries in the file's style (a finished forked skill moves to DONE; why: the engine reports it idle). Set `"version": "0.9.7"` in `mission-control/.claude-plugin/plugin.json` and in the mission-control entry of `.claude-plugin/marketplace.json` (with `sed` on that one line, never `jq`).
- [ ] T009 Run `bash scripts/check-versions.sh` (rc 0, mission-control 0.9.7 released) and `bash "$HOME/bats/bin/bats" -r tests` (green).

---

## Phase 4: Polish — prove it (records only)

- [ ] T010 Write `specs/048-mc-fork-done/measurements.md`: the T001 red output on the old code; the suite count before (133) and after; `claude plugin validate` result.
- [ ] T011 In the same file, record positive controls run in a scratch copy of the mod: the forked-idle → done rule removed (T001 a/b red); the revive exclusion removed (T001 a red); `forked` not stored by `addRun` (T001 a/b and T007 red); the spawned-helper guard broken by treating every idle as done (T002 red).

## Dependencies & Execution Order

Phase 1 (tests first, red, then fix) → Phase 2 → Phase 3 → Phase 4. One file at a time; no parallel work.

SC/FR-007's tag happens after the merge, from `origin/main` after a fetch, on the commit holding the whole fix.
