# Research: 052-preflight-usable-base-and-status

All measurements: 2026-11-03, git 2.53.0, Ubuntu, scratch repositories,
`GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM=1`. The rigs are in
the run directory's scratch notes; the results are in the spec's Context.

## R1 — One check for every base source

- **Decision**: turn the override's existing block into
  `base_usable <name> <label>` and call it twice: for the override where
  it is checked today, and after resolution for every other source, once
  the name check passed. Checks, in order:
  1. `git show-ref --verify --quiet refs/heads/<name>` fails →
     - `refs/remotes/origin/<name>` exists → "exists only on origin;
       create the local branch first: git branch --track …" (today's
       override text);
     - `git symbolic-ref --quiet HEAD` prints `refs/heads/<name>` (the
       current branch, unborn) → "has no commit yet; make a first commit,
       or pass a base branch that has one";
     - else → "is not a branch here or on origin" (today's text).
  2. `git rev-parse --verify --quiet refs/heads/<name>^{commit}` fails →
     "does not name a commit".
  3. `git show-ref --verify --quiet refs/tags/<name>` succeeds → "is a tag
     as well as a branch; git would read the tag" (today's text).
- **Rationale**: Principle IV; the override already had the right rule
  (spec Context, 1a to 1d). The labels are the name check's labels, so a
  refusal names its source the same way in both checks.
- **Departure, named**: the unborn branch case changes the override's
  message in that one case (FR-011 records it). No test pins the old
  text for it (`grep` of `pipeline/tests`, 2026-11-03).
- **Alternatives**: a second, separate check for non-override sources
  (two implementations of one rule); leaving the unborn case to read "is
  not a branch here or on origin" (true to git, misleading to a person,
  and the spec's story 1 scenario 3 asks for "no commit").

## R2 — The current checkout's full ref

| `HEAD` → | `symbolic-ref --quiet --short HEAD` | `symbolic-ref --quiet HEAD` |
|---|---|---|
| `refs/heads/main` | 0, `main` | 0, `refs/heads/main` |
| `refs/heads/main`, tag `main` too | 0, `heads/main` | 0, `refs/heads/main` |
| `refs/tags/v1` | 0, `v1` | 0, `refs/tags/v1` |
| `refs/remotes/origin/main` | 0, `origin/main` | 0, `refs/remotes/origin/main` |
| detached | 1 | 1 |

- **Decision**: read the full ref; stop when it does not start with
  `refs/heads/`; strip that prefix for the base. The exit-code handling
  of 051 (1 = detached, other = unreadable) is unchanged.
- **Rationale**: `--short` makes git choose an unambiguous short name,
  which is not the branch's name when a tag shares it, and it hides
  where the ref lives. The full ref answers both with no text parsing
  beyond a fixed prefix.
- **Alternatives**: keep `--short` and look the name up afterwards (cannot
  tell `v1` the tag from a branch `v1` that does not exist).

## R3 — The clean-tree read

| Case | `status --porcelain` | `+ --untracked-files=normal --ignore-submodules=none` | `ls-files -v` |
|---|---|---|---|
| 2a mode-000 folder with new work | empty, rc 0 | empty, rc 0, a stderr warning | — |
| 2b `showUntrackedFiles=no` + untracked | empty | `?? u` | — |
| 2c `skip-worktree`, changed | empty | empty | `S f` |
| 2d `assume-unchanged`, changed | empty | empty | `h f` |
| clean sparse checkout | empty | empty | `H a/1`, `S b/2` |
| submodule moved, `submodule.s.ignore=all` | empty | ` M s` | — |
| submodule moved, `diff.ignoreSubmodules=all` | empty | ` M s` | — |

- **Decision** (owner's answers, Clarifications): the two flags; and
  `tree.dirty: true` when `ls-files -v` lists any entry with a lowercase
  tag. The count runs as `git ls-files -v -- ':/' | awk …` with awk
  reading every line, so no early exit can kill git under `pipefail`. The
  `:/` pathspec makes the listing cover the whole tree from any folder,
  as `git status` does: without it, run from a subfolder (`--dir`), it
  lists only that subtree (measured: from `sub/`, plain `-v` printed
  `H g`; with `:/` it printed `h ../f` and `H g`). A non-zero status of
  the pipeline stops pre-flight with its own message: the index listing
  could not be read (not 051's "git status failed", which would name the
  wrong command).
- **Rationale**: `-v` lowercases only `assume-unchanged` entries (`-f`,
  not `-v`, is the fsmonitor flag). A file name holding a line feed is
  quoted by `ls-files`, so every line starts with its tag.
- **Not done, named in the docs**: 2a (git only warns on stderr, and the
  script never reads git's text; on Windows stderr carries ordinary
  line-ending warnings), 2c (`S` marks a clean sparse checkout too).
- **Alternatives**: `grep -q '^[a-z]'` (early exit under `pipefail`, the
  shape `tests/pipefail.bats` refuses); reading the whole listing into a
  shell variable (memory and time grow with the index).

## R4 — Fixtures that name a base that is not there

Many tests probe with `--base-branch main` in a repository made with
`git init -q -b work`, where `main` does not exist and no `origin/HEAD`
is published; today the configured name is reported unchecked. After
R1 these stop. Which ones is found by running the full suite against the
change (Principle V); each is given a base that exists (the branch the
fixture already has, or a `main` branch made from its commit), and its
assertions do not change (FR-011). The list and the count are recorded
in `measurements.md`.

## R5 — Item 3 changes no code

The owner chose to document the limit. Recorded for the docs sentence:
`core.fsmonitor`, a `post-index-change` hook through `core.hooksPath`,
and a `filter.<x>.clean` program each ran under pre-flight's status read
(spec Context 3a to 3c); `-c core.fsmonitor=false -c
core.hooksPath=<empty>` stops the first two and not the filter; phases
B, H, K and L run ordinary git in the same repository, hooks included on
purpose.

## R6 — CI probes the fixtures from a detached checkout with no `main`

`actions/checkout@v7` (`.github/workflows/ci.yml`, default depth 1) on a
pull request checks out the merge commit detached: no `refs/heads/main`,
no `refs/remotes/origin/main`, no `origin/HEAD`. The fixture tests probe
`$FIX/<name>` INSIDE this checkout with `--base-branch main` (33 probes in
`pipeline/tests/preflight.bats`). Today the configured name is reported
unchecked, so they pass in CI. After R1 every one of them would stop in
CI with "is not a branch here or on origin", while the local suite stays
green (local `main` and `origin/HEAD` exist).

- **Decision**: the fixtures leave the enclosing checkout. `setup_file`
  copies `pipeline/tests/fixtures` once into `$BATS_FILE_TMPDIR`, makes
  it a repository on branch `main` with one commit holding every fixture
  file, and points `FIX` at the copy. Each fixture probe then reads its
  own repository, where `main` exists, whatever the CI checkout looks
  like. A test that writes into `$FIX` (found by running the suite)
  gets its own copy.
- **Proof, not assertion**: phase H runs `pipeline/tests/preflight.bats`
  once in a clone made as CI makes one: depth 1, `HEAD` detached, no
  local branch, no `origin/HEAD`, no `origin/main`. It must be green
  there; before the fixture change, the same rig must show the fixture
  probes red (the positive control).
- **Alternatives**: a workflow step that makes a local `main` (fixes CI
  only, leaves a contributor's detached worktree red, and moves a test
  premise into CI configuration); passing the enclosing checkout's
  current branch (there is none when detached).

## R7 — Two "no commit yet" texts

051's stop for the current checkout ("the current branch has no commit
yet, …") is pinned word for word by a test, and stays. `base_usable`'s
"'<b>' has no commit yet; …" serves a base named by the key or an
override that is the unborn current branch. The two texts are accepted
duplication: they name different sources, and merging them would break
051's pinned message.
