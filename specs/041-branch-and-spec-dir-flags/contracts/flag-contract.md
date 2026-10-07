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

Each exits non-zero. Each message names the value and the argument.

| Value | Message part |
|---|---|
| branch refused by `git check-ref-format --branch` | `is not a legal branch name (--feature-branch)` |
| branch equal to the resolved base branch | `is the base branch; the feature branch needs its own name (--feature-branch)` |
| folder starting with `/` or a drive letter | `is not relative to the repository root (--spec-dir)` |
| folder holding `\` | `holds a backslash; separate folders with / (--spec-dir)` |
| folder with a `..` segment | `climbs out with .. (--spec-dir)` |
| folder with an empty or `.` segment | `has an empty or . segment; write each path one way (--spec-dir)` |
| folder under `.delivery-kit/` | `is inside the state directory .delivery-kit/ (--spec-dir)` |
| last segment outside `[A-Za-z0-9._-]` | `a run name holds letters, digits, dot, dash, underscore only (--spec-dir)` |
| folder that exists | `already exists (--spec-dir)` |
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
