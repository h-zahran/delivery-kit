# Contract: the base-branch override

## Two spellings, one override

| Spelling | Layer | Where |
|---|---|---|
| `baseBranchOverride` key | 2, 3 or 4 (a configuration file) | `~/.delivery-kit.json` or the repository's `.delivery-kit.json`, key `pipeline`; or the file `--config <path>` names |
| `--base-branch <name>` flag | 5 (individual flags) | the `/pipeline` command line; beats the key |

The orchestrator passes the winner to pre-flight as `--base-branch-override <name>`. It is read on a fresh run only.

## Pre-flight resolution order

| Order | Source | `baseBranchSource` |
|---|---|---|
| 1 | `--base-branch-override` | `override` |
| 2 | `refs/remotes/origin/HEAD` | `origin/HEAD` |
| 3 | `--base-branch` (the `baseBranch` key) | `configured` |
| 4 | the current branch | `current branch` |

`preflight.sh` never reads configuration, so it cannot tell the key from the flag. The orchestrator's probe line names the layer: the flag, `~/.delivery-kit.json`, the repository's `.delivery-kit.json`, or `--config`. It never prints the word `override` (review 2, item 11).

## Refusal

Checked inside the repository, after the cd into `--dir` (review 2, item 7). Each exits non-zero. Each message shows the value masked (review 4, non-blocking 3): under `LC_ALL=C`, cut to 200 bytes then ` [cut]`, and every byte that is not printable ASCII shown as `?`. No message prints an absolute path.

| Value | Message part |
|---|---|
| a lone `@`, which git 2.43.0 accepts and creates, but reads as `HEAD` in a revision | `is not a legal branch name here: git reads it as HEAD (--base-branch-override)` |
| refused by `git check-ref-format --branch`, or printed back changed (`@{-1}`) | `is not a legal branch name (--base-branch-override)` |
| a character outside `A-Z a-z 0-9 . _ - /`, though git accepts it (`x$(id)`, U+202E); checked after git's check (review 4, blocking 1) | `holds a character other than a letter, a digit, '.', '_', '-' or '/' (--base-branch-override)` |
| `refs/remotes/origin/<value>` exists but `refs/heads/<value>` does not (a fresh clone) | `exists only on origin; create the local branch first: git branch --track <value> origin/<value> (--base-branch-override)` |
| neither exists (a tag, a commit id, `origin/main`, `refs/heads/main`, a missing branch) | `is not a branch here or on origin (--base-branch-override)` |
| `refs/heads/<value>` and `refs/tags/<value>` both exist (review 3, item 5) | `is a tag as well as a branch; git would read the tag (--base-branch-override)` |

The safe set is why the printed `git branch --track` command can be run as printed: it holds no character a shell reads as code (review 4, blocking 1).

## Pinned strings

| Site | Pinned text |
|---|---|
| SKILL.md Configuration table | the whole `baseBranchOverride` row |
| SKILL.md Flags table | the whole `--base-branch <name>` row |
| SKILL.md **Base branch:** | the resolution-order sentence, and the sentence that sends the run to `pipeline/docs/configuration.md` |
| `pipeline/docs/configuration.md` | the first two sentences of the override paragraph, the pre-flight argument, the layer-naming sentence, and the resume sentence |
| SKILL.md as a whole | under 65,536 bytes |
| `pipeline/CHANGELOG.md` | the bold lead of the Added entry |
