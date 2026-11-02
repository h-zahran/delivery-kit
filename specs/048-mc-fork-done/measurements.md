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
