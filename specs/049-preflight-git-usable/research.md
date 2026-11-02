# Research: 049-preflight-git-usable

All facts below were measured on 2026-11-02, git 2.53.0, local Ubuntu, in a
scratch folder, with `GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1`.

## R1. Can exit codes alone tell the five states apart?

**Decision**: yes, with three git calls after `command -v git`:
`git --version`, `git rev-parse --git-dir`, and
`git -c safe.directory='*' rev-parse --git-dir`.

Measured:

| Case | plain `rev-parse --git-dir` | with `-c safe.directory='*'` |
|---|---|---|
| own repository | 0 (`.git`) | — |
| repository, `GIT_TEST_ASSUME_DIFFERENT_OWNER=1` | 128 (dubious ownership) | 0 |
| subfolder of that repository | 128 | 0 (absolute git dir) |
| inside `.git` of that repository | 128 | — |
| inside `.git` of an own repository | 0 (`.`) | — |
| no repository (`GIT_CEILING_DIRECTORIES` above it) | 128 | 128 |
| `git --version` with the env var set | 0 | — |
| same refusal under `LANG=de_DE.UTF-8` | 128 | — |

**Rationale**: `safe.directory` given with `-c` is protected configuration,
so git honours it from the command line. The refusal and the no-repository
case both exit 128, so text is the only other way to split them, and text is
translated (FR-004).

**Alternatives rejected**:
- Reading `detected dubious ownership` from stderr: translated, and the
  wording changes between git versions.
- Comparing the folder's owner with the current user ourselves: no portable
  way on Windows (git compares SIDs there).
- `rev-parse --show-toplevel`: fails inside `.git`; `--git-dir` does not.

**Limits, stated in the contract**:
- Any refusal other than ownership reads `no-repository`.
- A git with the ownership check but without `*` support (2.35.2 to 2.35.x)
  reads a refusal as `no-repository`.
- A git that runs `--version` but fails every other command reads
  `no-repository`.

## R2. Does lifting the check for one command reopen what it protects?

**Decision**: no, for `rev-parse --git-dir`.

**Rationale**: the ownership check exists so an untrusted repository's
configuration cannot make git run a program (`core.fsmonitor`, `core.pager`,
`core.sshCommand`, hooks, filters). `rev-parse --git-dir` reads
configuration but runs none of those: it refreshes no index (no fsmonitor),
starts no pager (stdout is not a terminal, and rev-parse is plumbing), runs
no hook, and touches no remote or work-tree file. The lifted call is the only
one; every later git read in the script runs without the lift and fails as
it did before. The classifier writes no configuration (FR-005).

## R3. How does a test make git refuse a repository for ownership, on all three runners?

**Decision**: `GIT_TEST_ASSUME_DIFFERENT_OWNER=1`, plus an isolated config
(`GIT_CONFIG_GLOBAL` pointing at an empty file in `$BATS_TEST_TMPDIR`, and
`GIT_CONFIG_NOSYSTEM=1`).

**Rationale**: the variable is git's own test switch, read in the common
setup code, not in a platform file, so it is expected to act the same on the
Windows and macOS runners; CI is the measurement. The config isolation
matters: a runner whose global config holds `safe.directory=*` (or entries
added by the checkout step) would make the fixture pass for the wrong reason.
An empty file, not `/dev/null`, because `/dev/null` is not a path on Windows
git.

**Positive control**: each fixture test first asserts its own precondition
with plain git — the refused fixture asserts `git rev-parse --git-dir` exits
non-zero and the lifted one exits 0 — so a git that ignores the variable
fails the test by name instead of giving a vacuous green.

**Alternatives rejected**: `chown` to another user (needs root; not on
Windows); `sudo` (not on CI by default).

## R4. The other three reasons' fixtures

- `absent`: the existing test's shim directory without git (unchanged).
- `broken`: a shim directory whose `git` is a script that exits 1 for
  every command.
- `no-repository`: an empty folder under `$BATS_TEST_TMPDIR` with
  `GIT_CEILING_DIRECTORIES=$BATS_TEST_TMPDIR`, so git does not climb into
  the checkout that holds the temp folder.

## R5. What an unusable git does to the name checks

**Decision**: `have_git` becomes "git is usable". With git found but not
usable, `--base-branch-override`, `--feature-branch` and `--spec-dir` are
reported unchecked, exactly as with git absent today.

**Rationale**: with a refused git, `git show-ref` fails, and the override
check died with "is not a branch here or on origin" — a wrong cause, and
exit 1 before any report (FR-006). `git check-ref-format` itself needs no
repository, but keeping one gate keeps the unusable cases identical to the
absent case the suite already pins; the orchestrator stops at decision 11
before any name is used.

**`willSkip`**: unchanged shape. With an unusable git, `git remote get-url`
fails as it does with git absent, so `remote.kind` is `none` and the L and M
entries appear as today. The rare-paths "not read" rule marks them as not
established for every unusable reason, as it does for absent.

## R6. Decision 11's text per reason

- `absent`: today's text and link.
- `refused-ownership`: name the refusal and print, for the owner to run,
  `git config --global --add safe.directory <the repository's path>`. Run
  nothing. The path is shown on the owner's screen only.
- `broken`: git was found but did not run; repair or reinstall it; the link.
- `no-repository`: git runs but opened no repository at the probed folder;
  start the run inside the repository, or run `git rev-parse --git-dir`
  there to see git's own reason.
