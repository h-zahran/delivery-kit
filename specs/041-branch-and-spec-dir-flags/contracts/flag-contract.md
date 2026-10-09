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
| branch holding a character outside `A-Z a-z 0-9 . _ - /`, though git accepts it (`y$(id)`, U+202E); checked after git's check (review 4, blocking 1 and non-blocking 4) | `holds a character other than a letter, a digit, '.', '_', '-' or '/' (--feature-branch)` |
| branch that is also a tag, `refs/tags/<name>` (review 4, non-blocking 5: L's push would fail as ambiguous after every commit) | `is a tag as well as the feature branch's name; git would read the tag (--feature-branch)` |
| branch equal to the resolved base branch, in any letter case, also behind `origin/`, `heads/`, `remotes/origin/` or `refs/heads/` | `is the base branch '<base>'; the feature branch needs its own name (--feature-branch)` |
| branch that exists locally or on `origin`, in any letter case, or that is a folder of one or has one as a folder (`team` beside `team/x`) | `already exists as the branch '<name>', or collides with it as a folder; the feature branch needs a new name (--feature-branch)` |
| folder starting with `/` or a drive letter | `is not relative to the repository root (--spec-dir)` |
| folder holding `\` | `holds a backslash; separate folders with / (--spec-dir)` |
| folder with a `..` segment | `climbs out with .. (--spec-dir)` |
| folder with an empty or `.` segment | `has an empty or . segment; write each path one way (--spec-dir)` |
| any segment starting with `-` | `which starts with a dash (--spec-dir)` |
| any segment outside `[A-Za-z0-9._-]` (so `~`, `:`, a space or a control character) | `a folder name holds letters, digits, dot, dash, underscore only (--spec-dir)` |
| any segment `.git`, any letter case | `is inside git's own directory .git (--spec-dir)` |
| any segment ending in `.`, which Win32 drops (`.git.` is `.git` there) (review 3, item 4) | `which ends with a dot; Windows drops it (--spec-dir)` |
| any segment whose name before its first `.` is `CON`, `PRN`, `AUX`, `NUL`, `COM0`-`COM9` or `LPT0`-`LPT9`, in any letter case (`nul.txt`, `Com0`) (review 3, item 4) | `a name Windows keeps for a device (--spec-dir)` |
| first segment `.delivery-kit`, any letter case | `is inside the state directory .delivery-kit/ (--spec-dir)` |
| folder that exists, as a folder, a file or a link | `already exists (--spec-dir)` |
| an existing part of the path that is not a folder | `which is not a folder (--spec-dir)` |
| existing parent that resolves outside the top level | `'<folder>' leads outside the repository (--spec-dir)` |
| existing parent that resolves into `.git` or `.delivery-kit` | `'<folder>' leads into git's or the run's own directory (--spec-dir)` |
| run name with a state file | `already has a state file, .delivery-kit/runs/<name>/progress.json (--spec-dir)` |

The two "leads" rows name the folder as it was given, never the path it resolves to: an absolute path carries the user name into a log a person may paste (review 4, non-blocking 2). Inside or outside is decided by which folder it is, not by how its path is spelled: an absolute link to a folder inside the repository is accepted when the repository was entered by another spelling (`/c/Users/...` beside `/tmp/...` on Git Bash), and a link into `.git` or `.delivery-kit` gets the second row's reason (review 4, non-blocking 1).

Every message shows the values it names masked (review 4, non-blocking 3): under `LC_ALL=C`, cut to 200 bytes then ` [cut]`, and every byte that is not printable ASCII shown as `?`. The same holds for an unknown argument.

## Pinned strings

| Site | Pinned text |
|---|---|
| SKILL.md Flags table | the whole `--branch` and `--spec-dir` rows |
| SKILL.md probe block | the `Branch` and `Spec folder` lines |
| SKILL.md **Base branch:** pointer | `--branch` and `--spec-dir` in the list of names that send the run to the docs page |
| SKILL.md phase B | the pointer to B's rule, the branch-name clause |
| `pipeline/docs/configuration.md` | the "Two flags change it for one run" sentence, the flags-only sentence, the re-run note, the fresh-run-only clause, the hand-over sentence, the `spec.md` check, the resume sentence |
| `pipeline/CHANGELOG.md` | the bold lead of the entry |
