# Measurements: 051-preflight-failed-git-reads

A record of one run, 2026-11-02, Ubuntu, git 2.53.0, GNU bash 5.3.9,
jq 1.8.1. Base: `fe28701` (the spec commit on `main` at `68dc597`), with
the Phase 1 changes to `pipeline/scripts/preflight.sh` and
`pipeline/tests/preflight.bats` uncommitted.

## T005: the new tests against the unchanged script

`bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats`: plan `1..114`,
111 ok. Red, and only these:

- `base branch: a branch with no commit yet stops pre-flight, naming the fix`
- `base branch: a detached HEAD stops pre-flight, naming the fix`
- `a working tree whose status cannot be read stops pre-flight`

T004's added line (`.baseBranch == ""` for an unusable git) was green
against the unchanged script, as it must be: it pins behaviour that does
not change.

## T007: the tests that got a first commit

With the stops in place, these nine probed a commit-less repository with no
base flag and expected a report (two also check refusals first); each got
`seed` after its `git init`, nothing else changed (FR-008):

- `feature branch and spec folder: without the arguments both are reported empty`
- `feature branch: a typed name is reported, slashes and all`
- `spec folder: a nested folder relative to the repository is reported`
- `trailers: without the argument the list is reported empty`
- `trailers: each one is reported, in the order given`
- `trailers: dashed tokens and tokens holding a marker's letters are accepted, in order`
- `trailers: a value holding a colon is reported whole`
- `trailers: a quote, a dollar sign or a backtick is refused, since a trailer is typed into a shell command`
- `trailers: ##[ anywhere is refused, since a workflow log reads it as a command`

Then: plan `1..114`, 114 ok, no skip.

## T008: as CI runs it, and the differential

- **Detached worktree** of `fe28701` with the two changed files copied in
  (`git rev-parse --abbrev-ref HEAD` printed `HEAD`):
  `pipeline/tests/preflight.bats` plan `1..114`, 114 ok.
- **quickstart.md** steps 1 to 4, run as extracted from the file: the
  no-commit, detached and status stops each printed one `preflight:` line
  and exited 1; step 4 printed
  `{"baseBranch":"main","baseBranchSource":"configured","notRead":[]}`.
- **Differential** (FR-004, SC-002): the script from `main` against the
  changed one, each run's stdout compared as `jq -S .`, its stderr required
  empty, its exit status compared.

  | Repository | Arguments | Result |
  |---|---|---|
  | this checkout | `--base-branch main` | same, exit 0/0 |
  | a seeded repository, no remote | none | same, exit 0/0 |
  | the same with an untracked file | none | same, exit 0/0 |
  | a commit-less repository | `--base-branch main` | same, exit 0/0 |
  | a commit-less repository (the control) | none | differs, exit 0/1 |

  The last row is the control: the harness can report a difference.

## T009: mutants

Run in a detached worktree, never the main checkout. Each mutant is a copy
of the changed script beside its siblings, made by a script that refuses a
mutation with no single site or one that changes nothing, prints the
mutated line, and is syntax-checked with `bash -n`. The suite was pointed
at each copy with `PREFLIGHT_UNDER_TEST`.

| Mutant | Mutated line | Red |
|---|---|---|
| a. drop the detached stop | `\|\| : "HEAD is detached, …"` | `a detached HEAD stops pre-flight` |
| b. drop the no-commit stop | `\|\| : "the current branch has no commit yet, …"` | `a branch with no commit yet stops pre-flight` |
| c. drop the status stop | `: "the working tree's status could not be read, …"` | `a working tree whose status cannot be read stops pre-flight` |
| d. the old read put back (without its `\|\| true`; the phase I review ran the exact old line, with the same reds) | `base="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"` | both base-branch stop tests |
| e. the base read without its `gitUsable` guard | `if true; then` | `the capability report names git absent, …`; `an unusable git with no base flag names the base fields, …` |
| f. the status stop without its `gitUsable` guard | `elif true; then` | eight: the seven unusable-git report tests, from `the capability report names git absent, …` to `an unusable git with no base flag names the base fields, …`, and `without git, the override and the feature branch are reported unchecked` |

Every new test went red under at least one mutant: the no-commit test
under b and d, the detached test under a and d, the status test under c.
No mutant was NO-OP.

## T011: the documentation pin

`pipeline/tests/prose.bats` with T010's text: plan `1..96`, 96 ok. In a
detached worktree with the changed page and suite copied in, T010's
sentence deleted from `configuration.md` (the line after the cut shown to
read `whenever \`capabilities.gitUsable\` is \`true\`. The placeholders
are …`): `the report's notRead list is documented where a reader of the
report finds it` went red.

## Phase I: the review round's fixes

Same machine and versions, base `18c4cd6`, the fixes uncommitted. What
changed, from the first pass and from the bugs lens's re-read of the fixes:

- the no-commit stop asks for a first commit, or a base branch that has
  one (an override works there only when another branch has a commit);
- a `HEAD` naming a branch git cannot read (`symbolic-ref` exits 128, not
  1) stops with its own message, not the detached one;
- the status stop says `git status` failed and no longer guesses at work
  in the tree, and its read runs only with a usable git;
- a base from `origin/HEAD`, the `baseBranch` key or the current branch
  (any source but the override, by a `*)` arm) gets the override's name
  check, and the refusal names the source and the fix (FR-010);
- the stop tests compare the whole message; the detached test gains a
  base-flag probe, `not_read_is '[]'` and the unreadable-branch case; a
  test pins FR-010; a prose test pins the "Base branch" sentences.

Results: `pipeline/tests/preflight.bats` plan `1..115`, 115 ok, in the
main checkout and in a detached worktree; `pipeline/tests/prose.bats` plan
`1..97`, 97 ok.

Mutants on the final shape, in a detached worktree (`mutate3.py`: one
site each, NO-OP refused, exits non-zero if any mutant cannot be made,
mutated line printed, every copy checked to exist and pass `bash -n`
before the suite runs). An earlier rig run is not counted: its edit
failed, no mutant file existed, and every test went red for that reason
alone ("no script at"); this run's outputs hold no such line.

| Mutant | Mutated line | Red |
|---|---|---|
| a. drop the detached stop | `1) : "HEAD is detached, …"` | the detached test |
| b. drop the no-commit stop | `\|\| : "the current branch has no commit yet, …"` | the no-commit test |
| c. drop the status stop | `\|\| : "the working tree's status could not be read: …"` | the status test |
| d. the exact old read put back | `base="$(git rev-parse --abbrev-ref HEAD 2>/dev/null \|\| true)"` | the detached test (on a branch with no commit the `rev-parse --verify` stop still fires, with its own message) |
| e. the base read without its `gitUsable` guard | `if true; then` | `the capability report names git absent, …`; `an unusable git with no base flag …` |
| f. the status read without its `gitUsable` guard | `if true; then` | the seven unusable-git report tests and `without git, the override and the feature branch are reported unchecked` |
| g. no name check for `origin/HEAD` | `origin/HEAD) : "$base" …` | `a name from the repository gets the override's check, from every source` |
| h. no name check for the `baseBranch` key | `configured) : "$base" …` | the same test |
| i. no name check for the current branch (the `*)` arm) | `*) : "$base" …` | the same test |
| j. the name check without its `gitUsable` guard | `if true; then` | `the capability report names git absent, …`; `… a git that is found but cannot run`; `an unusable git with no base flag …` |
| k. git's text let out of the detached read | `base="$(git symbolic-ref --short HEAD)"` | the detached test |
| l. git's text let out of the no-commit read | `git rev-parse --verify HEAD >/dev/null` | the no-commit test |
| m. drop the unreadable-branch stop | `*) : "HEAD names a branch git cannot read, …"` | the detached test |

k and l survived the T009 tests; the whole-message compares now kill them.
No mutant was NO-OP.

Prose, in a detached worktree with the final page and suite: the "Base
branch" test passed unmutated; deleting the "A base branch read from the
repository …" sentence, and dropping ", or a base branch that has one",
each turned it red.
