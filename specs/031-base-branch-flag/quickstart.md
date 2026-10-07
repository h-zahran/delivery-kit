# Quickstart: verify the base-branch override

Run from the repository root.

## 1. The suites

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
bash scripts/check-versions.sh
```

Record of one run, 2026-10-07, Linux, at `main` = `67db081`: before the change `1..276`, all `ok`. After it, see the table in §3.

## 2. The positive controls

Each mutation runs in a throw-away copy of the tree, never in the checkout. Each one is first checked to have landed: the original text must be present before it is replaced, or the result is not counted.

| # | Mutation | File | Test that goes red |
|---|---|---|---|
| 1 | Shorten the `--base-branch` Flags row | `pipeline/skills/pipeline/SKILL.md` | the base-branch override is pinned where the operator reads it |
| 2 | Change the `baseBranchOverride` default cell | `pipeline/skills/pipeline/SKILL.md` | same |
| 3 | Put `origin/HEAD` back first in **Base branch:** | `pipeline/skills/pipeline/SKILL.md` | same |
| 4 | Stop naming the override's layer | `pipeline/skills/pipeline/SKILL.md` | same |
| 5 | Replace "is never applied" with "is applied" | `pipeline/skills/pipeline/SKILL.md` | same |
| 6 | Reword the override paragraph's lead | `pipeline/docs/configuration.md` | same |
| 7 | Reword the entry's bold lead | `pipeline/CHANGELOG.md` | same |
| 8 | Make the override branch never taken | `pipeline/scripts/preflight.sh` | base branch: an override beats origin/HEAD, and is reported as an override |
| 9 | Skip the name check | `pipeline/scripts/preflight.sh` | base branch: an override git would not accept as a branch name is refused, naming it |

## 3. Record

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | `1..280`, all `ok` | 9 of 9 landed and went red |

An earlier draft of this feature (a flag only) also ran seven mutations; two of them first quoted text across a line break, did not land, were refused by the landing check, and were rerun with single-line text.
