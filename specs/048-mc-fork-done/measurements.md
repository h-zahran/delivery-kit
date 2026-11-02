# Measurements — 048-mc-fork-done

Measured on 2026-11-02, Linux, Claude Code 2.1.316. Every mutant run below
is a scratch copy of `mission-control/` with every test file deleted except
`hooks/forked.test.tsx` (`claude plugin test` has no filter). Each source edit
had to match exactly once, and its `diff` against the tracked file was printed
before the run, so no mutant is a no-op.

The unchanged scratch copy, run the same way: **14 pass, 0 fail**.

## T010 — red on the old code, and the suite before and after

### Red on the old code

`hooks/register.tsx` and `types/index.d.ts` taken from `f569e9f` (main before
this run), with this run's tests: **10 pass, 4 fail**.

| Test | Expected | Received |
|---|---|---|
| a fork that ended stays done when the list then calls it idle | `done` | `running` |
| a fork whose end no turn.complete showed is done once the list calls it idle | `done` | `idle` |
| a fork shown done goes back to RUNNING when the list says it runs again | `done` | `running` |
| a fork stored before a reload is still a fork; a run 0.9.6 stored keeps idle | `done` | `idle` |

The first row is the bug the owner saw: the fork's `turn.complete` made it
done, and five seconds later the list's `idle` revived it to `running`. The
guard for spawned helpers ("a helper made by agent.spawn that the list calls
idle stays in RUNNING, resting") passed on the old code, as it must: it pins
behaviour the fix keeps.

### Suite counts

| | mission-control suite |
|---|---|
| Before (F.5 baseline, `f569e9f`) | 133 pass, 0 fail |
| After (this branch, piece 3) | 138 pass, 0 fail, 8 files |

The 5 new tests: the four of piece 1 (T001-T002) and the reload test of
piece 2 (T007).

`claude plugin validate mission-control`: **Validation passed**, rc 0.

## T011 — positive controls

Each control removes one part of the fix. Each one must turn a named test red.

| Mutant | Edit | Result | Failed tests |
|---|---|---|---|
| m1 | `statusOf` returns `mapStatus(s)`: no forked idle → done | 12 pass, 2 fail | fork with no turn.complete is done once idle; reload test |
| m2 | the revive rule counts every `idle`, forks too | 12 pass, 2 fail | fork that ended stays done; fork shown done goes back to RUNNING |
| m3 | `addRun` does not store `forked: true` | 11 pass, 3 fail | fork that ended stays done; fork with no turn.complete is done once idle; fork shown done goes back to RUNNING |
| m4 | `statusOf` maps every `idle` to done, spawned helpers too | 12 pass, 2 fail | helper made by agent.spawn stays in RUNNING, resting; reload test (its 0.9.6 record must keep idle) |

Every control went red. Two results differ from what `tasks.md` T011
predicted, and both are correct behaviour of the tests:

- **m3 does not turn the reload test red.** The plan expected it to. The
  reload test seeds a stored record that already carries `forked: true`, so it
  tests that a stored flag is READ after a reload, not that `addRun` WRITES it.
  The write is pinned by the three tests m3 does turn red.
- **m2 also turns "goes back to RUNNING" red.** That test first checks that
  the fork is done after the list says `idle`; with the exclusion removed, the
  fork is revived there, so its first check fails.

## Phase I — the review round's fixes, measured

The review found one regression in piece 1: every run that joined from the
list was marked a fork. A teammate or a spawned helper whose spawn record was
gone would then show DONE on its next idle. The record goes two ways:

- `trimAgents` dropped every run that was not `running`, resting ones
  included. It now drops only runs that are over (`done`, `failed`), so a
  resting helper keeps its record.
- When the pane's state is lost, nothing is left to read. A run is now marked
  a fork only when its list entry has no `teammateId`, so a teammate is never
  taken for a fork.

The review also found test gaps that survived mutants (FR-002 `waiting` and
`pending`, a listed `completed`, `failed` or `killed`, the join/spawn race), and
`isRevived` restated the fork rule by hand; it is now `isLive(statusOf(a, s))`.

Red before the fix, on the code before each fix: the teammate test got
`forked: true`; the trim test found the resting helper trimmed away.

Suite after the fixes: mission-control **147 pass, 0 fail** (8 files; the fork
file holds 23 tests). `claude plugin validate mission-control`: passed.

Every control below ran on the fork tests alone, as above, against the final
code; unchanged, all 23 pass (in the full suite run above).

| Mutant | Edit | Result | Failed tests |
|---|---|---|---|
| m0 | `register.tsx` and `types/index.d.ts` from `f569e9f` | 15 pass, 8 fail | fork stays done; fork with no turn.complete; back to RUNNING on running, waiting, pending; trim keeps a resting helper; spawn drops the fork mark; reload |
| m1 | `statusOf` returns `mapStatus(s)` | 17 pass, 6 fail | fork stays done; fork with no turn.complete; back to RUNNING ×3; reload |
| m2 | `isRevived` reads `mapStatus`, not `statusOf` | 19 pass, 4 fail | fork stays done; back to RUNNING ×3 |
| m3 | `addRun` does not store `forked` | 17 pass, 6 fail | fork stays done; fork with no turn.complete; back to RUNNING ×3; spawn drops the fork mark |
| m4 | every listed `idle` is done | 18 pass, 5 fail | spawned helper rests; spawned helper comes back; teammate rests; spawn drops the fork mark; reload |
| m5 | no revive on `waiting` or `pending` | 21 pass, 2 fail | back to RUNNING on waiting, pending |
| m6 | a fork listed `failed` or `killed` is done | 21 pass, 2 fail | listed failed; listed killed |
| m7 | `isRevived` never revives | 19 pass, 4 fail | back to RUNNING ×3 (at the RUNNING check itself); spawned helper comes back |
| m8 | every join is a fork (no teammate guard) | 22 pass, 1 fail | teammate rests |
| m9 | a spawn that replaces a joined run keeps `forked` | 22 pass, 1 fail | spawn drops the fork mark |
| m10 | a late join marks the spawned run it keeps | 22 pass, 1 fail | spawn that lands while a join looks |
| m11 | trim drops every run not `running` again | 22 pass, 1 fail | trim keeps a resting helper |

m0 runs the old code, which has no fork mark at all: the teammate test passes
there, as it must, since the regression it pins came with piece 1.

Deferred, with the reason:

- A spawned helper that outlives a loss of the pane's state (such as
  `/clear`) and later rests is taken for a fork and shown DONE. The list gives
  no field that marks a forked skill, and a list of spawned ids would be lost
  with the same state.
- A fork whose turn failed with no `turn.complete` is shown done once the list
  says `idle`: the list carries no failure for an idle fork. A failed model
  step and a listed `failed` or `killed` are shown failed (tested).
- An end the list settles runs no `markAnswered`, toast or chime: FR-004 chose
  "as any other end the list settles"; the gap predates 048.
- `isRevived` now revives on a status `mapStatus` does not know, as the write
  path already reads one as running: the engine's status union is closed, and
  the two rules now agree.
- `addRun` takes `forked` beside `isJoin`: it has one caller, `join`.
- Event payloads in the tests are cast `as never`, as the file's older tests
  do.
- The revive window (5 s to 30 min) predates 048.
- Counts and toasts: their code is unchanged and reads the stored status.
