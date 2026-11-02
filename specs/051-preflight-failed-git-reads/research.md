# Research: 051-preflight-failed-git-reads

All measurements: 2026-11-02, git 2.53.0, Ubuntu, scratch repositories.

## R1 — Which read tells the current checkout's three states apart

| State | `git rev-parse --abbrev-ref HEAD` | `git symbolic-ref --quiet --short HEAD` | `git rev-parse --verify --quiet HEAD` |
|---|---|---|---|
| a branch with a commit | 0, the name | 0, the name | 0 |
| a branch with no commit yet | 128, prints `HEAD` | 0, the name | 1 |
| detached `HEAD` | 0, prints `HEAD` | 1, prints nothing | 0 |

- **Decision**: `symbolic-ref --quiet --short HEAD` for the name, then
  `rev-parse --verify --quiet HEAD` for "has a commit".
- **Rationale**: the old read cannot tell detached from a branch by its
  exit status, and keeps `HEAD` as output when unborn. The pair answers
  each state with an exit status alone, so no git text is read (git's
  messages are translated; feature 049 reads exit codes only for the same
  reason).
- **Alternatives**: an exit check on the old read (misses detached: exit
  0); comparing its output to the literal `HEAD` (a branch may be named
  `HEAD`-like text in another case, and the unborn output is kept on a
  failure, which is the bug).

## R2 — Why a commit-less branch stops instead of being named

In a commit-less repository `git checkout -b feat master` exits 128
("'master' is not a commit and a branch 'feat' cannot be created from
it"), and so does `git checkout -b feat HEAD`. Phase B runs `git checkout
-b <feature> <base>`, so a named unborn base fails there. Stopping at
pre-flight names the cause and its fix before any phase runs.

## R3 — CI checks out a detached `HEAD`

`actions/checkout` on a pull request checks out the merge commit
detached. A test that probes THIS checkout (the fixtures sit inside it)
with no base flag reaches the current-checkout read and would hit the
detached stop in CI only. Every fixture probe in `pipeline/tests/preflight.bats`
passes `--base-branch main` today (checked by grep: no `probe --dir
"$FIX/…"` without it). To prove it rather than assert it, phase H runs
`pipeline/tests/preflight.bats` once in a detached worktree of the branch.

## R4 — A damaged index leaves git usable

With `.git/index` overwritten, `git rev-parse --git-dir` still exits 0, so
`gitUsable` is `true`; `git status --porcelain` exits 128 with nothing on
stdout; `symbolic-ref` and `rev-parse --verify HEAD` still exit 0. So the
status stop fires alone, and a test for it needs no base flag beyond the
seeded branch.

## R5 — With git not usable, nothing changes

Both new stops are guarded by `git_usable = true`. With git not usable the
current-checkout read is not run (it ran and failed before, printing
nothing, so `baseBranch` was `""`; it stays `""`), and a failed status
read keeps `tree.dirty: false`, named in `notRead`. Feature 050's tests
pin both; a mutant that drops the guard must turn them red.

## R6 — Which existing tests need a first commit

Many `preflight.bats` tests `git init` a scratch repository with no
commit and probe it with no base flag. Those that expect a report would
now hit stop 2. Those that expect a refusal for a flag may still pass,
since argument checks run first. The set is found by running the suite
against the change (Principle V), and each gets `seed`, the file's
existing helper, with its assertions unchanged (FR-008).
