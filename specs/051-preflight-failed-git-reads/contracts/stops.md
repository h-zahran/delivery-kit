# Contract: the three pre-flight stops under a usable git

Each stop holds only when `capabilities.gitUsable` would be `true`.

| Stop | When | stderr says | exit | stdout |
|---|---|---|---|---|
| detached | no override, no `origin/HEAD`, no configured base; `HEAD` names no branch (`symbolic-ref` exits 1) | `HEAD` is detached; check out a branch, or pass a base branch | 1 | empty |
| unreadable branch (phase I) | the same base source; `symbolic-ref` exits other than 0 or 1 (`HEAD` names a branch git cannot read) | `HEAD` names a branch git cannot read; run `git status` to see why | 1 | empty |
| no commit yet | the same base source; `HEAD` names a branch with no commit | the current branch has no commit yet; make a first commit, or pass a base branch that has one | 1 | empty |
| status not read | `git status --porcelain` exits non-zero | the working tree's status could not be read: `git status` failed; run `git status` to see why | 1 | empty |
| a name from the repository (phase I, FR-010) | the base came from `origin/HEAD`, the `baseBranch` key or the current branch, and fails the override's name check | the override's refusal, naming the source and, where one exists, the fix: `(origin/HEAD; pass a base branch with the run's --base-branch flag)`, `(the baseBranch key)` or `(the current branch; check out another branch, or pass a base branch)` | 1 | empty |

"Pass a base branch" names both ways a run gives one: the run's
`--base-branch` flag and the `baseBranch` configuration key. For a branch
with no commit it works only when another branch has a commit (an orphan
branch in a repository with history): in a repository with no commit an
override is refused, since it must already be a local branch.

No message of the first three stops prints git's own error text, a path,
or a value read from the repository (FR-002b); the name stop prints the
refused name as the override's refusal does, cut at 200 bytes with each
byte that is not printable ASCII shown as `?`. The report printed that
name in full before. Each message starts `preflight: `, as every
refusal of the script does.

Unchanged: the 013 stdout contract for every report that is printed, and
050's `notRead` contract (`[]` whenever `gitUsable` is `true`).
