# Quickstart: verify the resume probe lines

| # | File | Mutation | Test that goes red |
|---|---|---|---|
| 1 | `pipeline/docs/configuration.md` | the run's resume rule says the two lines are "unmarked" | the feature-branch and spec-folder flags are pinned where the operator reads them |
| 2 | `pipeline/docs/configuration.md` | the resume note says pre-flight "skips" the two names | same |

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | first version (old Phase 36): no separate suite run | 2 of 2 landed and went red |
| 2026-10-07 | Linux | `1..369`, all `ok` | 2 of 2 landed and went red (rebuilt on Phase 42) |

This phase adds no test, only two pins to an existing one.
