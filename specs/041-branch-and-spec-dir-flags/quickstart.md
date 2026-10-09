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
| 31 | Skip the existing-branch check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | feature branch: a name that exists here or on origin, in any letter case, or clashes as a folder, is refused |
| 32 | Compare existing branches case-sensitively | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 33 | Skip the leading-dash check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: .git, the state directory in any case, a leading dash and odd characters are refused |
| 34 | Refuse `.git` in lower case only | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 35 | Refuse `.delivery-kit` in lower case only | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 36 | Let `:`, `~`, a tab and ESC into a segment | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 37 | Skip the symbolic-link escape check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a symbolic link out of the repository, into .git or the state directory, or dangling, is refused |
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
| 49 | Drop `have_git` from `branch_ok`'s guard (review 4, R4b) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | without git, the override and the feature branch are reported unchecked |
| 50 | Drop `have_git` from `branch_like`'s guard (review 4, R4c) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | without git, the override and the feature branch are reported unchecked |
| 51 | Look the branch up in the caller's repository (`git -C "$OLDPWD"`) (review 4, R5a) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | feature branch and spec folder are checked in the repository, not in the caller's |
| 52 | Test the spec folder in the caller's folder (`$OLDPWD/$spec_dir`) (review 4, R5b) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | feature branch and spec folder are checked in the repository, not in the caller's |
| 53 | Compare an existing branch in its own letter case (`l = r`) (review 4, R6) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | feature branch: an existing branch with capitals is matched in any letter case |
| 54 | Refuse `.delivery-kit` at any depth (`if :`) (review 4, R7) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: .delivery-kit below the top level is an ordinary folder |
| 55 | Drop the trailing-dot rule (review 4, W1) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a segment ending in a dot, or a Windows device name, is refused |
| 56 | Drop the device-name rule (review 4, W2) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a segment ending in a dot, or a Windows device name, is refused |
| 57 | Match the device name on the whole segment, extension included (review 4, W3) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a segment ending in a dot, or a Windows device name, is refused |
| 58 | `COM[0-9]` becomes `COM[1-9]` (review 4, W4) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a device name is refused in any letter case, COM0 and LPT0 included |
| 59 | `LPT[0-9]` becomes `LPT[1-9]` (review 4, W5) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a device name is refused in any letter case, COM0 and LPT0 included |
| 60 | `PRN` in lower case only (review 4, W6) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a device name is refused in any letter case, COM0 and LPT0 included |
| 61 | `AUX` in lower case only (review 4, W7) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a device name is refused in any letter case, COM0 and LPT0 included |
| 62 | `NUL` in lower case only (review 4, W8) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a device name is refused in any letter case, COM0 and LPT0 included |
| 63 | `COM0`-`COM9` in lower case only (review 4, W9) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a device name is refused in any letter case, COM0 and LPT0 included |
| 64 | `CON` in lower case only (review 4, W10) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a segment ending in a dot, or a Windows device name, is refused |
| 65 | `LPT0`-`LPT9` in lower case only (review 4, W11) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a segment ending in a dot, or a Windows device name, is refused |
| 66 | The dot rule only for a segment that starts with a dot (review 4, W12) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a segment ending in a dot, or a Windows device name, is refused |
| 67 | Match a device name as a prefix (`CON*`) (review 4, W13) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a segment ending in a dot, or a Windows device name, is refused |
| 68 | Take the top from `git rev-parse --show-toplevel` again (review 3, item 6) (review 4, S1) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a repository reached through a second spelling of its path is not outside itself |
| 69 | Follow the path logically (`cd`, `pwd`), not through links (review 4, L1) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a symbolic link out of the repository, into .git or the state directory, or dangling, is refused |
| 70 | Drop the into-`.git`-or-state-directory check (review 4, L2) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a symbolic link out of the repository, into .git or the state directory, or dangling, is refused |
| 71 | Accept a dangling link (review 4, L3) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | spec folder: a symbolic link out of the repository, into .git or the state directory, or dangling, is refused |
| 72 | Drop the feature branch's tag-as-well clause (review 4, Q5) | `pipeline/docs/configuration.md` | review 4's refusals are pinned where the operator reads them |
| 73 | `COM0` and `LPT0` dropped from the device names (review 4, Q6) | `pipeline/docs/configuration.md` | review 4's refusals are pinned where the operator reads them |
| 74 | A refusal names "and the path a link leads to" (review 4, Q7) | `pipeline/docs/configuration.md` | review 4's refusals are pinned where the operator reads them |
| 75 | A masked value is cut at 2000 bytes (review 4, Q8) | `pipeline/docs/configuration.md` | review 4's refusals are pinned where the operator reads them |
| 76 | Drop the feature branch's tag-as-well clause (review 4, Q11) | `pipeline/CHANGELOG.md` | review 4's refusals are pinned where the operator reads them |
| 77 | TODO(implementer A): the mutation of the feature branch holds a character outside the safe set (rule B1) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | TODO(implementer A): the test's name |
| 78 | TODO(implementer A): the mutation of the feature branch is a tag as well (rule N5) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | TODO(implementer A): the test's name |
| 79 | TODO(implementer A): the mutation of a link refusal prints no absolute path (rule N2) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | TODO(implementer A): the test's name |
| 80 | TODO(implementer A): the mutation of inside or outside decided in one spelling, through a link (rule N1) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | TODO(implementer A): the test's name |
| 81 | TODO(implementer A): the mutation of a refused folder, segment or argument is printed masked and cut (rule S) | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | TODO(implementer A): the test's name |

## 3. Record

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | `1..289`, all `ok` | 26 of 26 landed and went red (first version) |
| 2026-10-07 | Linux | `1..356`, all `ok` | 27 of 27 landed and went red (rebuilt on Phase 40) |
| 2026-10-08 | Linux | `1..436`, all `ok`, before review 3 | After review 2, on `main` `4076ecf`: rows 16-44 landed and went red. Rows 18 and 19 first survived: the new segment check also refused `C:` and the backslash, for another reason. The test now checks each case's reason, and both go red. |
| 2026-10-08 | Linux | `1..439`, all `ok`, review 3 | Rows 45-48 landed and went red. Rows 45-47 had survived review 3's fresh mutants; each now has a case. |
| 2026-10-09 | Windows (Git Bash) | review 4's tests lens, at `3fec620` (the tree `8a75039` holds outside `main-plan.md`); `preflight.bats` alone `1..80`, all `ok` | Rows 49-71 landed. Rows 49-57, 64-67 and 69-71 went red. Rows 58-63 and 68 survived every test then; each went red on the test the review proposed for it (T1 for 58-63, T3 for 68), now in `preflight.bats`. |
| 2026-10-10 | Windows (Git Bash) | the review-4 fix, at `d4c0a67`; each row's test alone | Rows 72-76 landed and went red. Rows 77-81: TODO(implementer A). |

The ids in brackets name review 4's mutants: R, W, S and L are its tests lens's; Q are the review-4 fix's own. Each was first checked to have landed (the old text exactly once before, gone after), and the file was restored byte for byte after its run. S1 is caught only where a folder has two spellings, as on Git Bash; elsewhere T3 runs the same check on the one spelling.

The first round did not count two mutations. Mutation 6 first quoted text across a line break, did not land, and was refused by the landing check. Mutation 18 first stayed green: its case put the backslash in the last segment, where the run-name check also caught it. The case now puts the backslash in a middle folder, so only the backslash check catches it. Both were rerun. In the rebuild, mutation 8 first quoted text across a line break, did not land, and was rerun.
