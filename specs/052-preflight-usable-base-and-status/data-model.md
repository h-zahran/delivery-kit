# Data model: 052-preflight-usable-base-and-status

No new report key. Two keys change meaning; every other key is as today.

| Key | Before | After |
|---|---|---|
| `baseBranch` | a name from the source that won, checked by name only (override: checked as a local branch, not a tag) | the same name, now only ever a usable base when git is usable: `refs/heads/<name>` exists, names a commit, and no `refs/tags/<name>`; otherwise pre-flight stops and prints no report |
| `tree.dirty` | `true` when `git status --porcelain` printed anything | `true` when `git status --porcelain --untracked-files=normal --ignore-submodules=none` printed anything, or when `git ls-files -v` lists an `assume-unchanged` entry |

Unchanged: `baseBranchSource` values; `notRead` (`[]` whenever
`capabilities.gitUsable` is `true`); every key with git not usable.

## A usable base

| Field | Rule |
|---|---|
| local branch | `git show-ref --verify --quiet refs/heads/<name>` exits 0 |
| has a commit | `git rev-parse --verify --quiet refs/heads/<name>^{commit}` exits 0 |
| not a tag | `git show-ref --verify --quiet refs/tags/<name>` exits non-zero |

## The labels a refusal names

| Source | Label |
|---|---|
| override | `--base-branch-override` |
| `origin/HEAD` | `origin/HEAD; pass a base branch with the run's --base-branch flag` |
| configured | `the baseBranch key` |
| current branch | `the current branch; check out another branch, or pass a base branch` |
