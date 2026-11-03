# Contract: the base and tree rules under a usable git

Each rule holds only when `capabilities.gitUsable` would be `true`. Every
stop prints one line on stderr starting `preflight: `, exits 1, and
prints nothing on stdout, as every refusal of the script does. `<b>` is
the base name through the script's masking copy (cut at 200 bytes, each
byte that is not printable ASCII shown as `?`); `<label>` is the source's
label from `data-model.md`.

## New stops

| Stop | When | stderr says |
|---|---|---|
| not a local branch, on origin | `refs/heads/<b>` absent, `refs/remotes/origin/<b>` present | `'<b>' exists only on origin; create the local branch first: git branch --track <b> origin/<b> (<label>)` |
| no commit yet | `refs/heads/<b>` absent, `HEAD` is `refs/heads/<b>` (unborn) | `'<b>' has no commit yet; make a first commit, or pass a base branch that has one (<label>)` |
| not a branch | `refs/heads/<b>` absent otherwise | `'<b>' is not a branch here or on origin (<label>)` |
| no commit | `refs/heads/<b>` present, `^{commit}` fails | `'<b>' does not name a commit (<label>)` |
| a tag too | `refs/tags/<b>` present | `'<b>' is a tag as well as a branch; git would read the tag (<label>)` |
| HEAD outside `refs/heads/` | base from the current checkout; `symbolic-ref --quiet HEAD` exits 0 with a ref outside `refs/heads/` | `HEAD points to a ref that is not a local branch, so the current checkout names no base branch; check out a branch, or pass a base branch (the run's --base-branch flag, or the baseBranch key)` |

The first, third and fifth texts are the override's today, so the
override keeps them. The HEAD stop prints no ref: the ref comes from the
repository (FR-008).

## Order

1. The override: name check, then `base_usable` (as today, plus the two
   new rows).
2. The feature branch checks (unchanged).
3. Base resolution. Current checkout: 051's detached and unreadable
   stops, then the HEAD-outside stop, then 051's no-commit stop.
4. The name check for a non-override source (unchanged), then
   `base_usable` for it.

## The tree

| Case | `tree.dirty` |
|---|---|
| `git status --porcelain --untracked-files=normal --ignore-submodules=none` prints anything | `true` |
| `git ls-files -v` lists a line whose tag is a lowercase letter | `true` |
| neither | `false` |
| the status read exits non-zero | stop: 051's status message, unchanged |
| `git ls-files -v -- ':/' \| awk …` exits non-zero | stop: `the index could not be read: git ls-files failed, so pre-flight cannot tell whether the tree is clean; run git status to see why` |

The index listing uses the `:/` pathspec, so it covers the whole tree
from any folder, as `git status` does.

Unchanged: the 013 stdout contract for every printed report; 050's
`notRead` contract; with git not usable, no rule here runs.
