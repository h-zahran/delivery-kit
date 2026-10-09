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
| 17 | Accept a name git prints back changed | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | base branch: an override that is not an existing branch's plain name is refused |
| 18 | Accept a lone `@` | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 19 | Skip the existing-branch check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 20 | Drop the `origin` lookup | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 21 | `--allow-onelevel` in place of `--branch` | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | feature branch: the base from origin/HEAD is refused too, with no override |
| 22 | Allow the word `override` on the Base branch line | `pipeline/skills/pipeline/SKILL.md` | pre-flight gets every argument, and each probe line names a layer, never override |
| 23 | Pass the `--base-branch` flag as `--base-branch` | `pipeline/skills/pipeline/SKILL.md` | same |
| 24 | Let a name git expands pass | `pipeline/docs/configuration.md` | the base-branch override is pinned where the operator reads it |
| 25 | Accept a base that exists only on `origin` | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | base branch: an override that exists only on origin is refused, naming the command that fixes it |
| 26 | Drop the `git branch --track` message | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 27 | Check the override only when git is present: drop `have_git` from its guard (review 4, R4a) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | without git, the override and the feature branch are reported unchecked |
| 28 | Drop the check for an override that is a tag as well (review 4, G1) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | base branch: an override that is a tag as well as a branch is refused |
| 29 | Check for the tag before the branch (review 4, G2) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | base branch: an override that is not an existing branch's plain name is refused |
| 30 | A local branch that is a tag as well is "accepted" (review 4, Q3) | `pipeline/docs/configuration.md` | review 4's refusals are pinned where the operator reads them |
| 31 | `$` joins the override's safe set (review 4, Q4) | `pipeline/docs/configuration.md` | review 4's refusals are pinned where the operator reads them |
| 32 | The override's safe-set sentence says "So does not" (review 4, Q13) | `pipeline/CHANGELOG.md` | review 4's refusals are pinned where the operator reads them |
| 33 | TODO(implementer A): the mutation of the override holds a character outside the safe set (rule B1) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | TODO(implementer A): the test's name |
| 34 | TODO(implementer A): the mutation of a refused override is printed masked and cut (rule S) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | TODO(implementer A): the test's name |

## 3. Record

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | `1..280`, all `ok` | 9 of 9 landed and went red (first version, on `67db081`) |
| 2026-10-07 | Linux | `1..347`, all `ok` | 16 of 16 landed and went red (rebuilt on `33bd148`) |
| 2026-10-08 | Linux | `1..436`, all `ok`, before review 3 | After review 2, on `main` `4076ecf`: rows 7, 8 and 17-24 landed and went red. Row 8 first survived: the new existing-branch check also refused `two..dots`, for another reason. The test now checks the reason, and row 8 goes red. |
| 2026-10-08 | Linux | `1..439`, all `ok`, review 3 | Rows 25 and 26 landed and went red. |
| 2026-10-09 | Windows (Git Bash) | review 4's tests lens, at `3fec620` (the tree `8a75039` holds outside `main-plan.md`); `preflight.bats` alone `1..80`, all `ok` | Rows 27-29 landed and went red. |
| 2026-10-10 | Windows (Git Bash) | the review-4 fix, at `d4c0a67`; each row's test alone | Rows 30-32 landed and went red. Rows 33-34: TODO(implementer A). |

The ids in brackets name review 4's mutants: R, G, W, S, L, H, D, C, J, M and X are its tests lens's; Q are the review-4 fix's own. Each was first checked to have landed (the old text exactly once before, gone after), and the file was restored byte for byte after its run.

Before the move, the size test went red on its own: `SKILL.md` was 65,771 bytes.

An earlier draft of this feature (a flag only) also ran seven mutations; two of them first quoted text across a line break, did not land, were refused by the landing check, and were rerun with single-line text.
