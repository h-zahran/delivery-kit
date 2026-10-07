# Quickstart: verify the feature-branch and spec-folder flags

Run from the repository root.

## 1. The suites

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
bash scripts/check-versions.sh
```

Record of one run, 2026-10-07, Linux, at `031-base-branch-flag` = `7a658c0`: before the change `1..280`, all `ok`. After it, see the table in §3.

## 2. The positive controls

Each mutation runs in a throw-away copy of the tree, never in the checkout. Each one is first checked to have landed: the original text must be present exactly once before it is replaced, or the result is not counted. The file is restored after each run.

| # | Mutation | File | Test that goes red |
|---|---|---|---|
| 1 | Shorten the `--branch` Flags row | `pipeline/skills/pipeline/SKILL.md` | the feature-branch and spec-folder flags are pinned where the operator reads them |
| 2 | Shorten the `--spec-dir` Flags row | `pipeline/skills/pipeline/SKILL.md` | same |
| 3 | Delete the `Branch` probe line | `pipeline/skills/pipeline/SKILL.md` | same |
| 4 | Pass the two arguments "on every run" | `pipeline/skills/pipeline/SKILL.md` | same |
| 5 | Take the run's name from the slug | `pipeline/skills/pipeline/SKILL.md` | same |
| 6 | Drop "only" from the flags-only sentence | `pipeline/skills/pipeline/SKILL.md` | same |
| 7 | Replace "is never applied" with "is applied" | `pipeline/skills/pipeline/SKILL.md` | same |
| 8 | Reword B's hand-over sentence | `pipeline/skills/pipeline/SKILL.md` | same |
| 9 | Drop B's `spec.md` check | `pipeline/skills/pipeline/SKILL.md` | same |
| 10 | Stop naming the branch from `--branch` in B | `pipeline/skills/pipeline/SKILL.md` | same |
| 11 | Reword the section's flags sentence | `pipeline/docs/configuration.md` | same |
| 12 | Reword the entry's bold lead | `pipeline/CHANGELOG.md` | same |
| 13 | Reword the re-run note | `pipeline/skills/pipeline/SKILL.md` | the feature-branch and spec-folder flags are pinned where the operator reads them |
| 14 | Reword the re-run note | `pipeline/docs/configuration.md` | same |
| 15 | Skip the branch-name check | `pipeline/scripts/preflight.sh` | feature branch: a name git would not accept as a branch name is refused, naming it |
| 16 | Skip the base-name check | `pipeline/scripts/preflight.sh` | feature branch: the base branch's own name is refused, naming both |
| 17 | Drop the drive-letter pattern | `pipeline/scripts/preflight.sh` | spec folder: a path outside the repository, or one with no legal run name, is refused, naming it |
| 18 | Skip the backslash check | `pipeline/scripts/preflight.sh` | same |
| 19 | Skip the `..` check | `pipeline/scripts/preflight.sh` | same |
| 20 | Skip the empty-or-`.` segment check | `pipeline/scripts/preflight.sh` | same |
| 21 | Skip the `.delivery-kit/` check | `pipeline/scripts/preflight.sh` | same |
| 22 | Let a space into the run name | `pipeline/scripts/preflight.sh` | same |
| 23 | Skip the folder-exists check | `pipeline/scripts/preflight.sh` | spec folder: a folder that is already there is refused, naming it |
| 24 | Skip the state-file check | `pipeline/scripts/preflight.sh` | spec folder: a run name that already has a state file is refused, naming it |
| 25 | Report `featureBranch` empty | `pipeline/scripts/preflight.sh` | feature branch: a typed name is reported, slashes and all |
| 26 | Report `specDir` empty | `pipeline/scripts/preflight.sh` | spec folder: a nested folder relative to the repository is reported |

## 3. Record

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | `1..289`, all `ok` | 26 of 26 landed and went red |

The first round did not count two mutations. Mutation 6 first quoted text across a line break, did not land, and was refused by the landing check. Mutation 18 first stayed green: its case put the backslash in the last segment, where the run-name check also caught it. The case now puts the backslash in a middle folder, so only the backslash check catches it. Both were rerun.
