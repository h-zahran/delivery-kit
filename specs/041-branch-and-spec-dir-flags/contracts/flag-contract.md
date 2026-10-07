# Contract: the feature-branch and spec-folder flags

## Spellings

| Orchestrator flag | Pre-flight argument | Output key | Default (empty) |
|---|---|---|---|
| `--branch <name>` | `--feature-branch <name>` | `featureBranch` | the run's name |
| `--spec-dir <path>` | `--spec-dir <path>` | `specDir` | the spec tool's `specs/NNN-slug` |

The orchestrator passes them to pre-flight on a fresh run only. There is no configuration key.

## Names in the run

| Value | With neither flag | With `--spec-dir` | With `--branch` |
|---|---|---|---|
| Run name (`.delivery-kit/runs/<name>/`) | `NNN-slug` | the folder's last segment | unchanged |
| Spec folder | `specs/NNN-slug` | the folder | unchanged |
| Feature branch | the run name | the run name | the typed name |

## Refusals

Each exits non-zero. Each message names the value and the argument. The branch checks apply to `--feature-branch`, and without it to the spec folder's last segment, under `(--spec-dir)` (review 2, item 8). Every check that asks git runs after the cd into `--dir`.

| Value | Message part |
|---|---|
| branch refused by `git check-ref-format --branch`, or printed back changed (`@{-1}`) | `is not a legal branch name (--feature-branch)` |
| a lone `@` | `is not a legal branch name here: git reads it as HEAD (--feature-branch)` |
| branch equal to the resolved base branch, in any letter case, also behind `origin/`, `heads/`, `remotes/origin/` or `refs/heads/` | `is the base branch '<base>'; the feature branch needs its own name (--feature-branch)` |
| branch that exists locally or on `origin`, in any letter case, or that is a folder of one or has one as a folder (`team` beside `team/x`) | `already exists as the branch '<name>', or collides with it as a folder; the feature branch needs a new name (--feature-branch)` |
| folder starting with `/` or a drive letter | `is not relative to the repository root (--spec-dir)` |
| folder holding `\` | `holds a backslash; separate folders with / (--spec-dir)` |
| folder with a `..` segment | `climbs out with .. (--spec-dir)` |
| folder with an empty or `.` segment | `has an empty or . segment; write each path one way (--spec-dir)` |
| any segment starting with `-` | `which starts with a dash (--spec-dir)` |
| any segment outside `[A-Za-z0-9._-]` (so `~`, `:`, a space or a control character) | `a folder name holds letters, digits, dot, dash, underscore only (--spec-dir)` |
| any segment `.git`, any letter case | `is inside git's own directory .git (--spec-dir)` |
| first segment `.delivery-kit`, any letter case | `is inside the state directory .delivery-kit/ (--spec-dir)` |
| folder that exists, as a folder, a file or a link | `already exists (--spec-dir)` |
| an existing part of the path that is not a folder | `which is not a folder (--spec-dir)` |
| existing parent that resolves outside the top level | `leads outside the repository (--spec-dir)` |
| existing parent that resolves into `.git` or `.delivery-kit` | `git's or the run's own directory (--spec-dir)` |
| run name with a state file | `already has a state file, .delivery-kit/runs/<name>/progress.json (--spec-dir)` |

## Pinned strings

| Site | Pinned text |
|---|---|
| SKILL.md Flags table | the whole `--branch` and `--spec-dir` rows |
| SKILL.md probe block | the `Branch` and `Spec folder` lines |
| SKILL.md **Base branch:** pointer | `--branch` and `--spec-dir` in the list of names that send the run to the docs page |
| SKILL.md phase B | the pointer to B's rule, the branch-name clause |
| `pipeline/docs/configuration.md` | the "Two flags change it for one run" sentence, the flags-only sentence, the re-run note, the fresh-run-only clause, the hand-over sentence, the `spec.md` check, the resume sentence |
| `pipeline/CHANGELOG.md` | the bold lead of the entry |
