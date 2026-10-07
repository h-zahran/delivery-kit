# Quickstart: verify the resume probe lines

| # | File | Mutation | Test that goes red |
|---|---|---|---|
| 1 | `pipeline/skills/pipeline/SKILL.md` | "print the Branch and Spec folder lines from the record" becomes "omit" | the feature-branch and spec-folder flags are pinned where the operator reads them |
| 2 | `pipeline/docs/configuration.md` | the resume note says nothing is printed | same |

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | see Phase 35's record; this phase adds no test, only two pins to an existing one | 2 of 2 landed and went red |
