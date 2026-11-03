# Measurements — 053

Each entry is a record of one run on the date given, not a claim about the
current files.

## T003 — the key split changes nothing (2026-11-03)

- `pipeline/tests/suite-cache.bats` after T001 and T002: `1..70`, 70 ok,
  0 not ok, exit 0 — the same plan line as before the split.
- Differential: `suite-key 053-f5-cites-main-suite` on this checkout (HEAD
  `a5c160c`, the Phase 1 edits uncommitted) printed
  `c01bdd8011184f5db83583f63bd10b543b83fd3d` from `main`'s script and from
  the changed script: identical.
