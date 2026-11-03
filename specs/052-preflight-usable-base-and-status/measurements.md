# Measurements: 052-preflight-usable-base-and-status

Machine: Ubuntu, git 2.53.0, bash 5.x, bats from `$HOME/bats`. Base commit
`4d0b5cd`. Every run below went to its own file in the run directory, in
the foreground, with its exit status captured on the next line.

## Phase 1 — the fixtures leave the enclosing checkout (T001, T002)

- 2026-11-03: `pipeline/tests/preflight.bats` before T001 held 115
  `@test` lines (`git show HEAD:pipeline/tests/preflight.bats | grep -c
  '^@test'`).
- 2026-11-03, after T001, against the UNCHANGED script: rc 0, plan line
  `1..115`, 115 `ok`, no `not ok`, no `# skip`.
- Tests changed by T002: none. No test wrote into `$FIX` or needed the
  fixtures inside this checkout.
