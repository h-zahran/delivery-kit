# Research: F.5 cites a green suite result for main's commit

## R1. Does a separate checkout give the key F.5 looks up? (measured)

- **Decision**: a detached `git worktree` of HEAD's commit, in a temporary
  directory outside the working tree.
- **Measured 2026-11-03** on this repository, `main` = `065ab80`, the run's
  spec directory untracked in the main tree: in a detached worktree of
  `065ab80`, a throwaway run `x` with the real `testCommand` recorded a RED
  fake TAP (`1..1`, `not ok 1`, rc 1) as key `62b4305…`. With that record
  copied into the main tree's `.delivery-kit/suite-results/`,
  `suite-lookup 053-f5-cites-main-suite --base` answered "…without the
  untracked specs/053-f5-cites-main-suite/, the result recorded for these
  files is red" — the key matched (a mismatch says "none is recorded").
  The record was then removed and the lookup went back to "none" twice.
  Red is never cited, so the probe could not leak into this run's F.5.
- **Rationale**: a worktree shares the repository's configuration
  (`core.autocrlf`, filters, `info/exclude`) so the bytes on disk match; its
  index is built from the same commit; HEAD is the same commit.
- **Alternatives**: a local `git clone` — rejected: it carries no
  repository-local configuration and no `info/exclude`, so bytes and the
  untracked list can differ. `git archive` — rejected: no `.git`, and the
  suite reads git. A checkout under `.delivery-kit/` — rejected: a test that
  walks the file system rather than git would meet a second copy of the
  repository inside the first.

## R2. Where the background run starts

- **Decision**: in B, right after `init`, the lock, the seed and the branch
  — the first moment the run has a state file holding `testCommand` and
  `suiteReuse`.
- **Rationale**: the owner chose "at pre-flight"; on a fresh run pre-flight
  has no feature name and no state file, and every suite record names a run
  (`by run <feature>` in the lookup's summary). B follows within minutes,
  so the suite still has C to F (about 30 minutes here) to finish. Recorded
  here as a named departure from the wording of the answer, not from its
  intent: no human step, started by the run itself.
- **Alternatives**: a feature-less record made at pre-flight — rejected: it
  needs a second key path that reads its configuration from somewhere other
  than the state file, which Principle IV forbids.

## R3. One key implementation, two callers

- **Decision**: split `suite_key` into the configuration read (`testCommand`,
  `suiteReuse`, the spec directory for `base`) and the git part (file list,
  bytes, index, HEAD, platform, hash), which runs in the current directory
  and writes its scratch file to an absolute path. `suite-record` and the
  background runner both call it; the record writer is one function both
  call. `suite-lookup`'s decision is unchanged; only its summary text grows.
- **Rationale**: Principle IV; FR-005 — no new way for a lookup to say yes.

## R4. Process control

- **Decision**: `suite-base start` launches the runner detached, with every
  file descriptor closed or redirected, in a new process group: `setsid`
  where it exists, else a `set -m` subshell. The runner runs `testCommand`
  as its own child, records the child's id, and on TERM stops the child and
  then its group. A heartbeat file holds the epoch seconds of the runner's
  last sign of life, rewritten every 5 seconds.
- **Rationale**: the Bash tool's foreground limit is 600 s and the wait
  limit is 900 s, so the wait is a loop of calls; a resumed run can find a
  process id that has been reused, so the wait stops a process only when
  its heartbeat is fresh (written in the last 60 s). The memory
  "subagents must kill only their own PIDs" and "a stopped run keeps writing
  its file" both bound this: stop exactly the ids the runner recorded.
- **Alternatives**: the harness's background-task feature — rejected: it is
  not part of the script, so tests cannot reach it, and a stopped wrapper
  leaves the suite running.

## R5. The wait

- **Decision**: `suite-base <feature> wait [--slice <s>] [--limit <s>]`,
  defaults 540 and 900. Exit 2 means still running after this call's slice:
  call it again. Exit 0 means no background run is going any longer, with
  one line saying how it ended (or that none was started); F.5 then calls
  `suite-lookup --base` exactly as today. The limit counts from the first
  wait call, kept in the bookkeeping, so a loop of calls cannot wait longer.
- **Rationale**: the lookup stays the only judge of reuse; the wait only
  decides when to ask it.

## R6. The cited text (FR-004)

- **Decision**: the lookup's summary line gains the record's commit (or, in
  `files` mode where no commit is keyed, its tree) and its command as a JSON
  string: `… — recorded <time> by run <feature> on commit <sha>, command
  "<command>"`. The `--base` suffix stays last.
- **Rationale**: the issue's second rule. JSON quoting keeps a command with
  a quote or a line break on one line, so the cited block stays two lines.

## R7. Metrics (FR-008)

- **Decision**: F.5 adds `f5Cited` (a JSON boolean) and `baseSuite` (the
  wait's last line) to `pipeline-run.json` with `jq`, as N adds
  `suiteCited`.

## R8. Release

- **Decision**: pipeline 1.8.0, a MINOR: a run now starts a background
  suite by default. Files: `pipeline/.claude-plugin/plugin.json`,
  `.claude-plugin/marketplace.json`, `pipeline/CHANGELOG.md`.
