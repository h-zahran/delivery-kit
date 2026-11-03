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
| another ref of that name (phase I) | `git rev-parse --symbolic-full-name <b>` prints anything but `refs/heads/<b>` | `'<b>' is the name of another ref as well as a branch; git cannot tell them apart (<label>)` |
| a commit id's spelling (phase I) | `<b>` is 40 or 64 lowercase hex digits | `'<b>' is spelled as a full commit id; git would read the commit, not the branch (<label>)` |
| origin/HEAD outside origin (phase I) | `git symbolic-ref --quiet refs/remotes/origin/HEAD` gives a ref outside `refs/remotes/origin/` | `origin/HEAD points to a ref that is not one of origin's branches, so the remote names no base branch; pass a base branch with the run's --base-branch flag` |
| HEAD outside `refs/heads/` | base from the current checkout; `symbolic-ref --quiet HEAD` exits 0 with a ref outside `refs/heads/` | `HEAD points to a ref that is not a local branch, so the current checkout names no base branch; check out a branch, or pass a base branch (the run's --base-branch flag, or the baseBranch key)` |

The first, third and fifth texts are the override's today, so the
override keeps them. The HEAD stop prints no ref: the ref comes from the
repository (FR-008).

## Order

1. The override: `base_usable`, which runs the name check first (as
   today, plus the new rows).
2. The feature branch checks (unchanged).
3. Base resolution. Current checkout: 051's detached and unreadable
   stops, then the HEAD-outside stop, then 051's no-commit stop.
4. For a non-override source, `base_usable`: the name check (unchanged),
   then the rows above. origin/HEAD's own stop comes in step 3, where it
   is read.

## The tree

| Case | `tree.dirty` |
|---|---|
| `git status --porcelain --untracked-files=normal --ignore-submodules=none` prints anything | `true` |
| `git ls-files -v` lists a line whose tag is a lowercase letter | `true` |
| neither | `false` |
| the status read exits non-zero | stop: 051's status message, unchanged |
| the status read is clean and `git --no-literal-pathspecs ls-files -v -- ':/' \| awk …` exits non-zero | stop: `the index could not be read: git ls-files failed, so pre-flight cannot tell whether the tree is clean; run git ls-files -v to see why` |
| the listing counts N > 0 `assume-unchanged` entries | `true`, and stderr: `tracked files marked assume-unchanged: N; git does not look at them, so the tree is read as dirty (git ls-files -v shows each with a lowercase tag; core.ignoreStat marks every file so)` |

The index listing uses the `:/` pathspec, so it covers the whole tree
from any folder, as `git status` does.

Unchanged: the 013 stdout contract for every printed report; 050's
`notRead` contract; with git not usable, no rule here runs.
