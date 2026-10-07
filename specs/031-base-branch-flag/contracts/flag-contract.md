# Contract: the base-branch override

## Two spellings, one override

| Spelling | Layer | Where |
|---|---|---|
| `baseBranchOverride` key | 2 or 3 (a configuration file) | `~/.delivery-kit.json` or the repository's `.delivery-kit.json`, key `pipeline` |
| `--base-branch <name>` flag | 5 (individual flags) | the `/pipeline` command line; beats the key |

The orchestrator passes the winner to pre-flight as `--base-branch-override <name>`. It is read on a fresh run only.

## Pre-flight resolution order

| Order | Source | `baseBranchSource` |
|---|---|---|
| 1 | `--base-branch-override` | `override` |
| 2 | `refs/remotes/origin/HEAD` | `origin/HEAD` |
| 3 | `--base-branch` (the `baseBranch` key) | `configured` |
| 4 | the current branch | `current branch` |

`preflight.sh` never reads configuration, so it cannot tell the key from the flag. The orchestrator's probe line names the layer: the flag, or the configuration file by path.

## Refusal

A value `git check-ref-format --branch` refuses exits non-zero with:

```
preflight: '<value>' is not a legal branch name (--base-branch-override)
```

## Pinned strings

| Site | Pinned text |
|---|---|
| SKILL.md Configuration table | the whole `baseBranchOverride` row |
| SKILL.md Flags table | the whole `--base-branch <name>` row |
| SKILL.md **Base branch:** | the resolution-order sentence, the layer-naming sentence, and the resume sentence |
| `pipeline/docs/configuration.md` | the first two sentences of the override paragraph |
| `pipeline/CHANGELOG.md` | the bold lead of the Added entry |
