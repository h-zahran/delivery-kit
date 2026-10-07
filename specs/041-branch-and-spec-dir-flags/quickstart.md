# Quickstart: verify the feature-branch and spec-folder flags

Run from the repository root.

## 1. The suites

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
bash scripts/check-versions.sh
```

Record of one run, 2026-10-07, Linux, at `031-base-branch-flag` = `7a658c0` (the first version of Phase 40): before the change `1..280`, all `ok`. After it, see the table in §3.

## 2. The positive controls

Each mutation runs in a throw-away copy of the tree, never in the checkout. Each one is first checked to have landed: the original text must be present exactly once before it is replaced, or the result is not counted. The file is restored after each run.

| # | Mutation | File | Test that goes red |
|---|---|---|---|
| 1 | Change the `--branch` Flags row | `pipeline/skills/pipeline/SKILL.md` | the feature-branch and spec-folder flags are pinned where the operator reads them |
| 2 | Change the `--spec-dir` Flags row | `pipeline/skills/pipeline/SKILL.md` | same |
| 3 | Delete the `Branch` probe line | `pipeline/skills/pipeline/SKILL.md` | same |
| 4 | Delete the `Spec folder` probe line | `pipeline/skills/pipeline/SKILL.md` | same |
| 5 | Drop `--spec-dir` from the pointer list | `pipeline/skills/pipeline/SKILL.md` | same |
| 6 | Change "follow" to "skip" in B's pointer | `pipeline/skills/pipeline/SKILL.md` | same |
| 7 | Stop naming the branch from `--branch` in B | `pipeline/skills/pipeline/SKILL.md` | same |
| 8 | Reword the section's flags sentence | `pipeline/docs/configuration.md` | same |
| 9 | Drop "only" from the flags-only sentence | `pipeline/docs/configuration.md` | same |
| 10 | Reword the re-run note | `pipeline/docs/configuration.md` | same |
| 11 | Pass the two arguments "on every run" | `pipeline/docs/configuration.md` | same |
| 12 | Rename `SPECIFY_FEATURE_DIRECTORY` | `pipeline/docs/configuration.md` | same |
| 13 | Drop B's `spec.md` check | `pipeline/docs/configuration.md` | same |
| 14 | Replace "is never applied" with "is applied" | `pipeline/docs/configuration.md` | same |
| 15 | Reword the entry's bold lead | `pipeline/CHANGELOG.md` | same |
| 16 | Skip the branch-name check | `pipeline/scripts/preflight.sh` | feature branch: a name git would not accept as a branch name is refused, naming it |
| 17 | Skip the base-name check | `pipeline/scripts/preflight.sh` | feature branch: the base branch's own name is refused, naming both |
| 18 | Drop the drive-letter pattern | `pipeline/scripts/preflight.sh` | spec folder: a path outside the repository, or one with no legal run name, is refused, naming it |
| 19 | Skip the backslash check | `pipeline/scripts/preflight.sh` | same |
| 20 | Skip the `..` check | `pipeline/scripts/preflight.sh` | same |
| 21 | Skip the empty-or-`.` segment check | `pipeline/scripts/preflight.sh` | same |
| 22 | Skip the `.delivery-kit/` check | `pipeline/scripts/preflight.sh` | same |
| 23 | Let a space into the run name | `pipeline/scripts/preflight.sh` | same |
| 24 | Skip the folder-exists check | `pipeline/scripts/preflight.sh` | spec folder: a folder that is already there is refused, naming it |
| 25 | Skip the state-file check | `pipeline/scripts/preflight.sh` | spec folder: a run name that already has a state file is refused, naming it |
| 26 | Report `featureBranch` empty | `pipeline/scripts/preflight.sh` | feature branch: a typed name is reported, slashes and all |
| 27 | Report `specDir` empty | `pipeline/scripts/preflight.sh` | spec folder: a nested folder relative to the repository is reported |
| 28 | Skip the spec folder's branch checks | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: without --feature-branch, its last segment gets the branch checks |
| 29 | Compare the base name case-sensitively | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | feature branch: the base in another letter case or behind a prefix is refused |
| 30 | Do not strip `origin/` | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 31 | Skip the existing-branch check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | feature branch: a name that exists here or on origin, in any letter case, is refused |
| 32 | Compare existing branches case-sensitively | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 33 | Skip the leading-dash check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: .git, the state directory in any case, a leading dash and odd characters are refused |
| 34 | Refuse `.git` in lower case only | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 35 | Refuse `.delivery-kit` in lower case only | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 36 | Let `:`, `~`, a tab and ESC into a segment | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 37 | Skip the symbolic-link escape check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a symbolic link out of the repository, or into .git, is refused |
| 38 | Skip the link-into-.git check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 39 | Allow a file in the path | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a trailing slash is dropped; a file in its place is refused |
| 40 | Accept a name git prints back changed | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | feature branch: HEAD, and a name git expands to another, are refused |
| 41 | Accept a lone `@` | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 42 | The folder is `artifacts.spec` itself | `pipeline/docs/configuration.md` | the feature-branch and spec-folder flags are pinned where the operator reads them |
| 43 | The folder's segment skips the branch checks | `pipeline/docs/configuration.md` | same |
| 44 | Drop `.git` from the folder's place rules | `pipeline/docs/configuration.md` | same |
| 45 | Accept a dangling link in the folder's place | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a symbolic link out of the repository, into .git or the state directory, or dangling, is refused |
| 46 | Match `<top>*` in place of `<top>/*` | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 47 | Drop `.delivery-kit` from the resolved-path check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 48 | Drop the folder-clash check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | feature branch: a name that exists here or on origin, in any letter case, or clashes as a folder, is refused |

## 3. Record

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | `1..289`, all `ok` | 26 of 26 landed and went red (first version) |
| 2026-10-07 | Linux | `1..356`, all `ok` | 27 of 27 landed and went red (rebuilt on Phase 40) |
| 2026-10-08 | Linux | `1..436`, all `ok`, before review 3 | After review 2, on `main` `4076ecf`: rows 16-44 landed and went red. Rows 18 and 19 first survived: the new segment check also refused `C:` and the backslash, for another reason. The test now checks each case's reason, and both go red. |
| 2026-10-08 | Linux | `1..439`, all `ok`, review 3 | Rows 45-48 landed and went red. Rows 45-47 had survived review 3's fresh mutants; each now has a case. |

The first round did not count two mutations. Mutation 6 first quoted text across a line break, did not land, and was refused by the landing check. Mutation 18 first stayed green: its case put the backslash in the last segment, where the run-name check also caught it. The case now puts the backslash in a middle folder, so only the backslash check catches it. Both were rerun. In the rebuild, mutation 8 first quoted text across a line break, did not land, and was rerun.
