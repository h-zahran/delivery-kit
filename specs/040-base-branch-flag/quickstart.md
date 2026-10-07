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
| 1 | Change the `--base-branch` Flags row | `pipeline/skills/pipeline/SKILL.md` | the base-branch override is pinned where the operator reads it |
| 2 | Change the `baseBranchOverride` row | `pipeline/skills/pipeline/SKILL.md` | same |
| 3 | Change "read" to "skim" in the pointer to the docs page | `pipeline/skills/pipeline/SKILL.md` | same |
| 4 | Drop "the flag's value when both" | `pipeline/docs/configuration.md` | same |
| 5 | Stop naming the override's layer | `pipeline/docs/configuration.md` | same |
| 6 | Let a new base win on a resume | `pipeline/docs/configuration.md` | same |
| 7 | Make the override branch never taken | `pipeline/scripts/preflight.sh` | base branch: an override beats origin/HEAD, and is reported as an override |
| 8 | Skip the name check | `pipeline/scripts/preflight.sh` | base branch: an override git would not accept as a branch name is refused, naming it |
| 9 | Change "follow" in the pointer to "Resolving the layers" | `pipeline/skills/pipeline/SKILL.md` | the implementer key's consent surface is pinned outside the G slice |
| 10 | Make `null` an override | `pipeline/docs/configuration.md` | same |
| 11 | Move the stop "later" | `pipeline/docs/configuration.md` | same |
| 12 | Make `ask` "one spelling" | `pipeline/docs/configuration.md` | same |
| 13 | Change "REPLACED" to "changed" | `pipeline/docs/configuration.md` | same |
| 14 | Reword the override paragraph's lead | `pipeline/docs/configuration.md` | the base-branch override is pinned where the operator reads it |
| 15 | Reword the entry's bold lead | `pipeline/CHANGELOG.md` | same |
| 16 | Lower the size limit to 60,000 | `pipeline/tests/prose.bats` | the skill stays under the size Git Bash can read in a herestring |

## 3. Record

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | `1..280`, all `ok` | 9 of 9 landed and went red (first version, on `67db081`) |
| 2026-10-07 | Linux | `1..347`, all `ok` | 16 of 16 landed and went red (rebuilt on `33bd148`) |

Before the move, the size test went red on its own: `SKILL.md` was 65,771 bytes.

An earlier draft of this feature (a flag only) also ran seven mutations; two of them first quoted text across a line break, did not land, were refused by the landing check, and were rerun with single-line text.
