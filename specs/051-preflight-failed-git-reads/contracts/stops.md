# Contract: the three pre-flight stops under a usable git

Each stop holds only when `capabilities.gitUsable` would be `true`.

| Stop | When | stderr says | exit | stdout |
|---|---|---|---|---|
| detached | no override, no `origin/HEAD`, no configured base; `HEAD` names no branch | `HEAD` is detached; check out a branch, or pass a base branch | 1 | empty |
| no commit yet | the same base source; `HEAD` names a branch with no commit | the current branch has no commit yet; make a first commit, or pass a base branch | 1 | empty |
| status not read | `git status --porcelain` exits non-zero | the working tree's status could not be read; run `git status` to see why | 1 | empty |

"Pass a base branch" names both ways a run gives one: the run's
`--base-branch` flag and the `baseBranch` configuration key.

No stop message prints git's own error text, a path, or a value read from
the repository (FR-002b). Each message starts `preflight: `, as every
refusal of the script does.

Unchanged: the 013 stdout contract for every report that is printed, and
050's `notRead` contract (`[]` whenever `gitUsable` is `true`).
