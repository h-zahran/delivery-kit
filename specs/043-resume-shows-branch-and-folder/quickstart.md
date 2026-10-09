# Quickstart: verify the resume probe lines

| # | File | Mutation | Test that goes red |
|---|---|---|---|
| 1 | `pipeline/docs/configuration.md` | the run's resume rule says the two lines are "unmarked" | the feature-branch and spec-folder flags are pinned where the operator reads them |
| 2 | `pipeline/docs/configuration.md` | the resume note says pre-flight "skips" the two names | same |
| 3 | `pipeline/skills/pipeline/SKILL.md` | the pointer says "When all of" | the base-branch override is pinned where the operator reads it |
| 4 | `pipeline/skills/pipeline/SKILL.md` | the pointer loses "or a resumed run's state file records one" | same |
| 5 | `pipeline/skills/pipeline/SKILL.md` | the probe lines print "only when set" | pre-flight gets every argument, and each probe line names a layer, never override |
| 6 | `pipeline/skills/pipeline/SKILL.md` | The re-entry sentence drops `--from` (review 4, Q1) | review 3's rules are pinned where the operator and the run read them |
| 7 | `pipeline/skills/pipeline/SKILL.md` | The block is rendered "before" decision item 7's lock (review 4, Q2) | review 3's rules are pinned where the operator and the run read them |

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | first version (old Phase 36): no separate suite run | 2 of 2 landed and went red |
| 2026-10-07 | Linux | `1..369`, all `ok` | 2 of 2 landed and went red (rebuilt on Phase 42) |
| 2026-10-08 | Linux | `1..436`, all `ok` | After review 2: rows 3-5 landed and went red. |
| 2026-10-10 | Windows (Git Bash) | the review-4 fix, at `d4c0a67`; the row's test alone | Rows 6 and 7 landed and went red. |

This phase first added no test, only two pins to an existing one. After review 2 the pointer is pinned whole in three tests, and one new test pins the probe lines.
