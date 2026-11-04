# Changelog — pipeline

All notable changes to the `pipeline` plugin.

## [1.11.0] - 2026-11-04

### Added

- **`progress.sh branch-cut <feature>`.** A resume into phase B ran `git
  checkout -b` a second time, which exits 128, and no text said what to do.
  The new subcommand reads the branch and the base from the state file. It
  cuts an absent branch, says so when HEAD is on it, and switches to it from
  elsewhere only when the base is its ancestor. It never deletes a branch,
  moves a branch's commit or discards work. It replaces phase B's sentence.
- **A `Test command` line in the probe block.** A tracked `testCommand` starts
  in the background in phase B, before the first human stop, and nothing showed
  it. The line shows the command, JSON-quoted, and the layer that set it, on
  every fresh run and every re-entry. Phase B records the layer as
  `config.testCommandFrom`, and the base suite's `started` line names it.
- **`state-set --json-file <path>` and `preflight.sh --values-file <path>`.**
  A value a tracked file set no longer goes through a shell, where a quote broke
  the command and `'$(...)` ran code. Each value gets the same checks as the
  inline form or the flag. The refusal of a quote, a dollar sign or a backtick
  in a trailer stays, because a person may still type `--trailer`.

### Changed

- **`suite-base <feature> start` exits 3 when the run's own record cannot serve
  it:** no usable `config.testCommand`, or no spec file at `artifacts.spec`. It
  used to exit 0, the status of a legal "not started", so a run could pass over
  it. Phase B stops on exit 3: the owner gives a command, or goes on with none,
  and then phases F.5, J and N say that no suite ran. `--auto` does not collapse
  this stop. Every other "not started" line keeps exit 0. See "No test command"
  in `docs/rare-paths.md`.

### Notes

- The test helper `prose_slice` gained forms that leave out the closing line, so
  text on the next section's first line cannot satisfy a test that claims to
  read one section. It is test code and does not ship in this plugin.

## [1.10.0] - 2026-11-04

### Added

- **One fault harness per run.** To check that a test can go red, a run breaks
  the code on purpose in a throwaway copy. Up to three actors in one run each
  built their own script for it, and rediscovered the same facts. The tests
  reviewer finished last in each of four measured runs. `pipeline:spec-review`
  now defines one harness, `.delivery-kit/runs/<feature>/fault-harness.sh`: the
  first actor that needs it saves it, and later actors reuse and extend it. The
  tests reviewer writes its own faults first, so its judgement stays
  independent. `pipeline:spec-review` holds the rules, and `docs/phases.md`
  explains them.

### Notes

- This repository's `testCommand` now runs the suite's files side by side
  through `scripts/run-suite.sh`. That script is the repository's own and does
  not ship in this plugin. It changes no behaviour of the plugin.

## [1.9.1] - 2026-11-04

### Fixed

- **Phase B says when to record `config`.** `progress.sh suite-base
  <feature> start` reads `config.testCommand` from the state file. The skill
  said to record `config`, but not when, so a run could reach the start
  first. The command then prints "base suite not started" and exits 0,
  nothing stops, and F.5 runs the full suite again (about 6 minutes) instead
  of citing the base commit's result. B now records `config` with `init`'s
  first writes, before the branch cut and the start, if it is still empty,
  so a resume keeps what is recorded. Configuration says that B records it,
  with `testCommand` as resolved.
  `docs/phases.md` states the same order, and `docs/configuration.md` puts
  the trailer write after B's, because a write of the whole key replaces it.
  A new test goes red if the sentence leaves its place in B, and another
  holds the command's "not started" line and its exit 0. `progress.sh` does
  not change.

## [1.9.0] - 2026-11-04

### Highlights

- K and L are one stop when the branch holds commits and K has nothing
  left to commit: one question shows the commit list and the branch, title
  and full body of the pull request, and one answer covers both. Run 054
  waited at K and then at L, one straight after the other.
- J commits before its last full-suite run, so N can cite that run instead
  of running the suite again under `suiteReuse: commit`. Run 054's N ran
  the suite again (about 9 minutes) because J's commit came after J's run.

### Changed

- **K and L as one stop**, a new section of `docs/rare-paths.md`, with a
  pointer from K and L. Before the question, K runs L's checks that can
  stop the run. A yes records in `gates.L` the branch name, the title, the
  full HEAD commit id and the hash of the body (and of each `--parts`
  comment file); just before the push they are recomputed, and any
  difference asks L again as a stop of its own. K and L stay apart under
  `--auto`, with no remote, a non-GitHub remote or no `gh`, and for a run
  whose `commits` holds an old-style string entry. A re-entered K that asks
  again clears the joint fields first, keeping what `drop-stale` recorded.
- **J commits first.** When J changes files it makes its late commit, then
  runs its last full suite on that commit, and writes nothing after that
  run but the record commit. A new failure is fixed, committed and run
  again, within `maxVerifyIters`, so J may make one late commit per fixing
  iteration.
- **J's record commit is always its own empty `Late: J` commit**, made once
  for each red waved through: while a record is still the newest commit,
  `late-commit J --record` prints its id; any commit after it means a new
  record. The record never rides in a commit with files, which would come
  after J's last suite run: `--record` with an uncommitted change now
  refuses and says to commit it and run the suite on that commit first.
  In the single-commit flow, K makes the record with `--record`.
- **`late-commit J` after a crash.** It records every unrecorded `Late: J`
  commit, then commits what is left. A path a recorded J commit made since
  the list was saved (`measurements.lateBefore.head`, new) is never set
  aside by the saved list, so a path put back to its starting content is
  still committed after a crash. `snapshot late J --fresh` that recovers a
  commit still saves its list afresh. `late-commit --list` recovers and
  writes nothing.

### Fixed

- A failed read of the unrecorded commits, or a commit that could not be
  recorded, now stops `recover_late` and `recover_piece` instead of reading
  as nothing to recover; their callers run inside `if`, where `set -e`
  does nothing. The `mv` that replaces the state file now stops on failure.

## [1.8.0] - 2026-11-03

### Highlights

- F.5 can cite a green suite result for the base commit instead of running
  the whole suite again. The run records that result itself: B starts the
  suite in the background on a separate checkout of the base commit, and by
  F.5 it has usually finished. Closes issue #110.

### Added

- **`progress.sh suite-base <feature> start`.** On a fresh run whose base
  commit has no green suite result, it makes a detached `git worktree` of
  HEAD's commit in a temporary folder outside the working tree, and runs
  the test command there in the background, in a process group of its own.
  The result is recorded with the same key and the same writer as
  `suite-record`, so `suite-lookup <feature> --base` at F.5 finds it like
  any other record, and red is still never reused. It never merges, pushes,
  fetches, makes or deletes a branch, changes the main tree's HEAD, index
  or files, takes the lock or writes the state file. It prints one line:
  started (with the command, JSON-quoted, since the command now runs from
  inside the script), already started, or not started and why. It starts
  nothing under `suiteReuse: off` or any value but `commit` and `files`,
  when a green record for the base files already exists, when `TMPDIR` lies
  inside the work tree, on an abandoned run, or when the checkout's key is
  not these files' `--base` key, so it never runs a suite whose record
  could not be cited. The runner stops itself after 3,600 seconds. It
  removes its checkout through git, and only that checkout's record, never
  with a repository-wide `git worktree prune`. Before this, a repository
  that merges by rebase gave the base branch commits no run had tested, so
  the lookup always missed and F.5 ran the full suite, about 6 to 9 minutes
  on this repository.
- **`progress.sh suite-base <feature> wait [--slice <s>] [--limit <s>]`.**
  Waits for that run in slices of 540 seconds (exit 2: call again), so one
  call fits a 600-second tool limit, up to 900 seconds counted from the
  first call; at the limit it stops the runner. A runner whose heartbeat is
  more than 60 seconds old is never signalled, since its process id may
  belong to another program by then (a live one gets 15 seconds to beat
  again), and a dead runner's checkout is removed. The wait never decides
  reuse.
- **What it costs, and what it cannot see.** A second full run of the suite
  during C to F, and at worst a 900-second wait before F.5 runs the suite
  itself. The checkout holds no file git ignores, so a suite that needs a
  dependency folder or a build is red there and nothing is cited; a suite
  that an ignored file breaks in the main tree can be green there, which
  makes J blame the feature, never the reverse. For such a suite, set
  `suiteReuse: off`.
- The skill's B starts the base suite run and prints its line; an exit 1
  does not stop the run. F.5 waits, then looks up as before (an exit 1 from
  the wait goes on to the lookup), and records `f5Cited`, a JSON boolean,
  and `baseSuite` in the run's metrics.

### Changed

- **A cited suite result names its commit and its command.**
  `suite-lookup`'s summary line now ends `on commit <sha>, command
  "<command>"` (`on tree <tree>` under `suiteReuse: files`, which keys no
  commit), before the `--base` suffix. The command is quoted as JSON, so a
  quote or a line break in it stays on the one line. A `tree` that is not
  an object id is not printed. The lookup's decision is unchanged.
- `suite_key` is now two halves, the state file's and git's, and the
  record write is one function, so the base suite runner shares both
  rather than copying them. No key changes: measured identical on this
  repository.

## [1.7.6] - 2026-11-03

### Highlights

- Pre-flight checks that the base branch it found can be branched from,
  whatever its source, and its clean-tree check sees work the
  repository's own configuration hides from `git status`.

### Fixed

- **A base branch from the repository is checked to exist.** A base from
  `origin/HEAD`, the `baseBranch` key or the current branch was checked by
  name only, so a key naming a branch that is nowhere, or only a tag, a
  clone whose local `main` was deleted while `origin/HEAD` still named it,
  and a base that is a branch and a tag at once all reached the report,
  and phase B's `git checkout -b` then failed or `<base>..HEAD` read the
  tag. Every source now gets the override's check: a local branch with a
  commit, and no tag of its name. A branch whose name git reads as anything
  else, such as `refs/<name>`, a remote's branch or `ORIG_HEAD`, is refused
  too, since `git checkout -b` cannot tell them apart, and so is a branch
  named as a full commit id; a remote can supply such a name through
  `origin/HEAD`. A base that exists only on `origin` is
  refused with the command that creates it, `git branch --track <name>
  origin/<name>`, and a base that is the current branch before its first
  commit says so. That case changes an override's message: it used to say
  the name is not a branch here or on `origin`. A branch ref that names no
  commit, written by hand to hold a tree, is refused for every source, the
  override included, which the old check accepted.
- **`origin/HEAD` is read as a full ref.** It was read with `--short`, so
  a ref named `origin/main` beside origin's own gave the base
  `remotes/origin/main`, and an `origin/HEAD` pointing at another remote's
  branch was accepted. One outside `refs/remotes/origin/` now stops
  pre-flight.
- **A `HEAD` outside `refs/heads/` no longer names a base branch.** The
  current checkout was read with `git symbolic-ref --short`, so a `HEAD`
  pointing at the tag `v1` or at `origin/main` gave `v1` or `origin/main`
  as the base, and a branch with a tag of its name gave `heads/main`. The
  full ref is read now; one outside `refs/heads/` stops pre-flight.
- **The clean-tree check sees work the repository's configuration
  hides.** `git status` exited 0 and printed nothing for an untracked file
  under `status.showUntrackedFiles=no`, for a changed submodule under
  `submodule.<name>.ignore=all` or `diff.ignoreSubmodules=all`, and for a
  file marked `assume-unchanged`, so `tree.dirty` read `false`. The status
  read now passes `--untracked-files=normal` and
  `--ignore-submodules=none`, and when that shows nothing, a file marked
  `assume-unchanged` counts as a change, with a line on stderr saying how
  many and pointing at `git ls-files -v`; a repository that sets
  `core.ignoreStat` marks every file so, and always reads as dirty. A
  listing that fails stops pre-flight, as a failed `git status` does, and
  `GIT_LITERAL_PATHSPECS` in the environment no longer empties it. A
  `skip-worktree` file and a folder git cannot open are
  still not seen, by choice: a clean sparse checkout marks its files
  `skip-worktree`. `configuration.md` names both, and says that pre-flight,
  like every later phase, runs the programs the repository's own
  configuration names, as git does in a repository the user owns.
- The suite's fixtures are probed from a scratch repository on `main`, so
  a CI pull-request checkout, which is detached with no `main`, does not
  stop them. Closes issue #107.

## [1.7.5] - 2026-11-02

### Highlights

- Pre-flight stops, instead of reporting a guess as fact, when the base
  branch comes from a checkout that names no branch with a commit, or when
  `git status` fails; and a base branch read from the repository gets the
  same name check as an override.

### Fixed

- **A branch with no commit yet, or a detached `HEAD`, no longer reads as
  a base branch called `HEAD`.** With no override, no published
  `origin/HEAD` and no configured base, the base comes from the current
  checkout. The old read, `git rev-parse --abbrev-ref HEAD`, printed `HEAD`
  in both states, and the report kept it, so the probe block printed
  `Base branch : HEAD (from current branch)` and phase B would have cut the
  feature branch from it. The name now comes from `git symbolic-ref`, and
  pre-flight stops: on a detached `HEAD` it asks for a branch to be checked
  out or a base branch to be passed, and on a branch with no commit it
  asks for a first commit, or a base branch that has one.
- **A working tree whose status cannot be read is no longer reported
  clean.** With the index damaged, `git status --porcelain` failed, the
  empty output read as `tree.dirty: false`, and decision 5 passed a tree
  nobody examined. Pre-flight now stops and says `git status` failed.
- **A base branch read from the repository is checked like an override.**
  A name from `origin/HEAD`, which a cloned remote chooses, from the
  `baseBranch` key or from the current branch was never checked, though B
  types it into commands; a name such as `-dash` or one holding `$(`
  reached the report as it was. It now gets the override's name check, and
  a name that fails it stops pre-flight, naming its source. This refuses
  names that ran before: a base whose name git accepts but that holds a
  character other than a letter, a digit, `.`, `_`, `-` or `/` (a `+`, an
  `@`, a non-ASCII letter) now stops pre-flight, as such an override
  already did.
- Each stop needs a usable git, prints no report and none of git's own
  text, and exits 1, as the flag refusals do. With git not usable the
  report is unchanged. Documented in `docs/configuration.md`, "Base
  branch" and "Fields the report did not read". Closes issue #106.

## [1.7.4] - 2026-11-02

### Highlights

- The pre-flight report says which of its fields git never read, instead
  of stating them as fact when git cannot be used.

### Added

- **The report names the fields it did not read.** With git absent or not
  usable, four fields still read as established: `baseBranchSource` said
  `current branch` for a checkout nobody read, `remote.kind` said `none`
  for a remote nobody looked for, `tree.dirty` said `false` for a tree
  nobody examined, and `baseBranch` was empty. The report now carries
  `notRead`, a list naming each such field, plus the `willSkip` entries
  that follow from the remote (`willSkip.L`, `willSkip.M`). It is `[]`
  whenever `capabilities.gitUsable` is `true`; a read that fails under a
  usable git is not covered. A base branch from configuration is named
  too, since `origin/HEAD` ranks above it and was not read; only an
  override is never named. No existing key changes its name, type or
  meaning.
  Documented in `docs/configuration.md`, "Fields the report did not read".
- **The probe block marks exactly what `notRead` names.** The rule in
  `docs/rare-paths.md`, "The probe block without git", reads the list
  instead of working out from `baseBranchSource` which lines are unread,
  so that rule now lives in `preflight.sh` alone. A configured base is
  still printed, marked not confirmed; before, it was printed as
  established. A report without `notRead` is printed as not read. This
  closes the gap feature 013 deferred and issue #36 named.

## [1.7.3] - 2026-11-02

### Highlights

- Pre-flight stops when git is found but will not work on the repository,
  and says why, instead of reporting git as fine and failing in phase B.

### Fixed

- **Pre-flight asks whether git works here, not only whether it is found.**
  A git that refused the repository — most often git's ownership check,
  `detected dubious ownership`, on a checkout another user or process
  owns — reported `capabilities.git: true`, every git read then failed
  silently, and the run died in phase B. Pre-flight now classifies git
  once, from exit codes alone (git's messages are translated, so their
  text is never read), and reports two new keys:
  `capabilities.gitUsable` (a boolean) and `gitReason` — `usable`,
  `absent`, `broken`, `refused-ownership` or `no-repository`.
  `capabilities.git` keeps its meaning: git can be found. The ownership
  check is lifted for one read-only `git rev-parse --git-dir` and never
  written down. With git found but not usable, the name checks that read
  the repository are skipped and the names reported unchecked, as with git
  absent, instead of dying with a wrong cause. A git older than 2.38
  ignores the one-command lift, so there an ownership refusal reads
  `no-repository`, whose advice leads to git's own message.
- **Decision 11 stops for every git that cannot be used.** It fires on
  `capabilities.gitUsable` false and names the reason: the download link
  for an absent or broken git; for a refused repository, how to read
  git's own message and check that the repository it names is the owner's
  checkout, not one planted in a folder above it, before trusting it —
  the pipeline names no path and runs no fix; for no repository, where to
  look. This retires the limit 1.2.0 stated, that a git which is present
  but errors was out of scope.

## [1.7.2] - 2026-11-02

### Highlights

- Pre-flight no longer reads a UTF-16 or UTF-32 constitution as set on a
  busy machine.

### Fixed

- **Pre-flight always finds NUL bytes in a constitution.** A constitution
  saved as UTF-16 or UTF-32 must read as not set, with a warning. The check
  piped `od` into `grep -q` under `pipefail`: `grep -q` leaves at its first
  match, `od` could then die of SIGPIPE, and the failed pipeline read the
  constitution as set — 33 of 400 runs on a loaded machine, none on a quiet
  one. The check now captures `od`'s output and then matches it. A test
  forces the early exit with a fake `od`; two more fake a failed read, one
  after the NUL is seen (still not set) and one before anything is read
  (pre-flight still reaches the parse and exits 0); and a new test
  refuses a pipe into `grep -q` in any shipped script that sets `pipefail`.

## [1.7.1] - 2026-11-01

### Highlights

- The state-file lock holds on Ubuntu's new `mkdir`. Two questions queued at
  the same moment could get the same id, and one could be lost.

### Fixed

- **The state-file lock no longer trusts `mkdir` alone.** uutils coreutils
  0.10.0, the `mkdir` recent Ubuntu ships, lets two racing `mkdir` calls of
  one folder both succeed (75 of 200 tries; GNU `mkdir`: 0). Two writers
  then held the lock together: `ask-later` minted one id twice and dropped
  a question. A writer now also makes `<lock>/owner` under bash's
  noclobber, which only one writer can do; the others wait as before. The
  lock is still a directory, so a lock an older pipeline left is broken the
  same way.

## [1.7.0] - 2026-11-01

### Highlights

- A run is shorter: every review lens runs in one round at phase I, before
  the push, and the fixes are made once. No lens is dropped.
- Phase M reviews nothing again. It reads the pull request's comments from
  people with write access, and its check results, and fixes those.

### Changed

- **Phase I is one review round.** The three `pipeline:spec-review` lenses
  (contract, security, tests), the built-in `code-review` skill at level
  `high` as lens `bugs`, and a `simplify` lens all run at once, in one
  message, and only read until every lens has reported. They are not held
  back by `maxParallelAgents`; the fixes still are. Each finding becomes one
  `SEVERITY | lens | file:line | finding` line, and the fixes fan out once.
  The `bugs` lens is told in words that each untracked file is part of the
  change: a bare path would narrow the skill's target to that one file. It
  runs as a fork on the session's model, and never with `--fix` or
  `--comment`. When the fixes changed a file, the code-review skill reads
  only what they changed, once more, from a mark `git stash create` takes
  before them; its findings are fixed or deferred, and J checks those fixes.
- **Phase H.7 runs no separate pass.** The simplify work is the `simplify`
  lens in I. H.7 says so, changes no file and makes no commit. A run begun
  on an older pipeline keeps a commit its H.7 already made.
- **Phase M reads, and posts nothing.** A round reads the pull request's
  comments, review comments, reviews and check results once. It never waits
  for a pending check. Only a comment whose author has `admin`, `maintain` or
  `write` permission, and is not a bot, is acted on; any other is reported
  and left alone, so a stranger's comment cannot steer the run. Each comment
  read is recorded by id in `gates.M`, as `acted` or `declined` with the
  reason, and is never judged twice.
  `maxReviewRounds` still caps the loop.
- **Phase N records `suiteCited`.** A JSON boolean in the run's metrics says
  whether N cited a green suite result or ran the suite, so the time saved
  can be measured.
- On Windows, a `gh.cmd` alone is now enough: no phase calls plain `gh`.

## [1.6.2] - 2026-10-13

### Highlights

- A sample review guide shows the table a run's pull request carries, and
  how its cells are escaped.
- An annotated run walks this repository's own
  `specs/018-progress-commits-pieces` file by file, naming the phase that
  wrote each.

### Changed

- **A sample review guide.**
  [docs/examples/review-guide.md](docs/examples/review-guide.md) is the table
  `progress.sh guide` printed for a fictional run's branch, unchanged, with
  how to read it and the escaping rules. The README links it under
  "Reviewing a run commit by commit".
- **An annotated run.**
  [docs/examples/018-annotated-run.md](docs/examples/018-annotated-run.md)
  gives one note per file of `specs/018-progress-commits-pieces`: what it is,
  which phase wrote it, what to look at. Its links reach `specs/`, which a
  clone of the repository carries and an installed plugin does not.

## [1.6.1] - 2026-10-13

### Changed

- **`pipeline:device-verify` covers the gaps a real device run hits.** It
  looks for `adb`, then `adb.exe`, and says which name it found: WSL's
  bash cannot run a Windows install under the bare name. It honours
  `ANDROID_SERIAL`, and passes `-s` when more than one device is attached.
  It asks before signing an unsigned release build with the debug key. It
  installs an `.aab` through `bundletool`, signed with the release key, and
  asks before letting bundletool fall back to the debug key. It names the
  screenshot folder: `.delivery-kit/runs/<feature>/screenshots/` in a
  pipeline run.

### Fixed

- **Pre-flight judges the constitution in the shell.** It fed the file to
  grep through `< <(printf ...)`, and on Git Bash that grep said "found"
  for a pattern that is not there in about 2% of calls under load. Then a
  written constitution could read as unset, or a blank one as set. It now
  matches with `[[ ]]`.

## [1.6.0] - 2026-10-12

### Added

- **`board <feature>`** prints the phase board and the repository lock as
  one JSON object, read-only. `board` lists every phase in order but DONE,
  each `done`, `current` or `pending`; the phase a resume re-enters is
  `current`. `lock` is null when no lock exists. Otherwise it gives the
  holder's `feature`, `session` and `taken_at`, `holder_run` (how that
  run stands), `this_run`, and `stale`, by the rule `lock-take` uses to
  take a lock over. A lock that is not one JSON object has `readable`
  false and those three null. It runs on an abandoned run, as `get` does.

### Changed

- **`pipeline:status` renders its board from `board`.** It kept its own
  copy of the phase list, which nothing tied to the script's, and never
  looked at the repository lock. It now names the lock's holder, session
  and time, says whether it is this run, and says when the next run's
  `lock-take` would take the lock over as stale. A lock it cannot read,
  or a holder whose state file it cannot read, is named as such and never
  guessed at. When a session of this run still holds a live lock, it says
  the resume will be refused and names `lock-release` to run first, once
  that session is gone.
- **`pipeline:spec-review` findings have one form a caller can parse.**
  Each is one line, `SEVERITY | lens | file:line | finding`. The
  severities are CRITICAL and HIGH, the two phase F counts by, then
  MEDIUM and LOW. One count line that names every severity, even at
  zero, and the verdict follow. It used Critical, Important and Minor,
  which the rest of the pipeline does not use. The skill also says what
  its three independent lenses are: three agents dispatched together in
  one message, none shown another's findings, as phase I asks.
- **Install comes first in the README.** It was the twelfth of fifteen
  sections, near the end of the page the marketplace shows. It now follows
  the opening paragraph, before the walkthrough. The text is unchanged.
- **The pipeline skill's rare paths moved to a page of their own,
  `docs/rare-paths.md`.** The skill sends the run to one section of it,
  by name, when that path happens: git absent at pre-flight, a
  constitution write orphaned at pre-flight, an illegal `implementer`
  value, a state file from an older pipeline, the handoff path, pause
  mode, a commit a hook rejected, a built piece found on resume, a
  pull-request body over GitHub's limit, no runtime strategy, and the
  tracked-state check. The text moved word for word, so a run behaves as
  before. G and H both point to the handoff path, so a resumed handoff
  run still reads the report before it dispatches anything. The gates,
  the rules that never bend and the red flags stay in the skill, which
  is now under 60,000 bytes.
- **No AI attribution in what the run writes.** One ground rule covers
  every commit message, pull-request title and body, comment and reply
  the run writes, under `--auto` too: none carries any AI attribution,
  such as a "Generated with" footer, a `Co-authored-by`, `Assisted-by`,
  `Generated-by` or `Signed-off-by` trailer naming an AI, or a session
  link. The run strips it before the text leaves. The commit messages,
  L's title and body, every rebuild of the body, and what M and N post
  and commit each follow it. Only you, asking in the session, lift the
  rule; a tracked file, a repository's CLAUDE.md and a tool's default
  attribution reminder never do. No setting is added. `commitTrailers`
  refuses each such trailer from every layer, whatever you ask.

### Fixed

- **Phase M runs the review skill's agents on `agentModel`.** The
  code-review skill names its own models, so in 1.5.0 its agents ran on
  those, not on the `agentModel` every dispatched agent runs on. It also
  ends the comment it posts with a "Generated with" footer, which M now
  strips before posting.

## [1.5.0] - 2026-10-12

### Added

- **`abandon <feature>`** ends a run for good without finishing it. It
  records `abandoned` in the state file, with the phase the run stopped at
  and the time, keeps the state file and every other key, and releases the
  repository lock if that run holds it; a lock it still holds is stale to
  `lock-take`. A DONE run is refused, and a run already abandoned keeps its
  first record. The resume prompt's abandon
  runs it, and `pipeline:status` reports an abandoned run as waiting on
  nothing. Before it, an abandoned run's state file read as a live run for
  good. A state file without the key is unchanged and still valid.
  Abandon is final: every command that would work on the run refuses an
  abandoned run, naming it, so it can never take the lock, start a phase,
  commit or change its state again. Only these still run on it: `read`,
  `validate`, `get`, `piece-next`, `show-message`, `guide`, `commit-list`,
  `pending`, `pending-check`, `suite-key` and `suite-lookup`; `suite-record`,
  which keeps a suite result for the repository, not the run; and `metrics`,
  `abandon` and `lock-release`. A command added later is refused unless it
  joins that list. `tap-check` names no run, so it is never refused.
- **`get <feature> <key|filter>`** prints one value from the state file,
  read-only: a bare key name prints that key, anything else is a jq filter.
  It prints through `-b` where `jq` takes it, so no line it prints ends with
  a CR.
- **Pre-flight names the runs it judges.** `tree.liveRuns` lists every
  live run by name, and `tree.unreadableRuns` every state file that is not
  one JSON object with a string `current_phase`. The resume prompt is
  offered for each live run it names, and each unreadable one is named to
  you and never resumed.
- **`progress.sh tap-check <tap-file> [<expected-count>]`** judges any TAP
  file, keyed or not: the plan line first, one plan line, as many `ok` lines
  as the plan names, numbered 1 to N in any order, no skip, no `not ok` and
  no stray line. It prints one summary line, or the first rule the file
  breaks, and never the file's path. It needs only bash and awk.
  `suite-record` judges with the same rules, and the repository's
  `scripts/check-suite.sh` now hands its file to `tap-check` instead of
  holding a second copy of them — so `check-suite.sh` also refuses a test
  number that is missing, repeated or outside the plan, which its own copy
  did not check. (The repository's CI still reads its shards' TAP with checks
  of its own.)
- **The `suiteReuse` setting** says what a kept suite result must match
  before F.5, J or N cite it. `commit`, the default, covers the files and
  git's state around them: HEAD's commit id and the index. `files` covers
  the files alone. `off` keeps and reuses nothing, and so does any other
  value. A record names its mode and is never reused under another. A
  record kept by 1.4.0 names no mode, so it is never reused.
- **`suite-lookup <feature> --base`**, for F.5: when these files have no
  green result, it also looks up the same files without the run's untracked
  spec directory — the tree before this feature. Only that directory is left
  out, and nothing is ever recorded under that key.

### Changed

- **`init` makes `pipeline-run.json`** when it is absent, on a fresh run
  and on a resume, so the run's metrics no longer depend on the
  orchestrator remembering to start them. One that exists is left for
  `metrics`, which still keeps the keys the orchestrator added, and now
  writes through a temporary file of its own.
- **The docs say what a run will touch before it touches it.** The
  `/pipeline:pipeline` command's description names all three seed forms, not
  only the plan-file heading. The README says that bare `/pipeline` runs the
  pipeline skill directly, and `/pipeline:pipeline` goes through the command;
  how a plan-file seed is read (Claude reads the section; no script fixes its
  heading level); that `--dry-run` still creates the feature branch, the spec
  folder and the run folder, and leaves you on the branch; and that `gh` must
  be logged in as well as installed. The commands it tells you to type carry
  their slash: `/pipeline:status`.
- **A suite result is kept for uncommitted work too.** The key covers every
  tracked path still on disk and every untracked path git does not ignore
  (outside `.delivery-kit/`), each file's bytes on disk and its mode, so a J
  iteration on uncommitted fixes now records its run. A new untracked file,
  a deleted tracked file and a change of line endings alone each change the
  key; an ignored file does not. What else it covers depends on
  `suiteReuse`. Under `commit`, the default, a staged change, a commit, an
  amended message or a moved HEAD is a change too, so a suite that reads
  HEAD's commit message or staged bytes is never told a result that does not
  hold — and N cannot cite J's run once K commits. Under `files`, git's state
  is invisible: N can cite J's run after J commits the same files, including
  a file J deleted or added (but not a new executable file where git records
  modes), while a suite that reads a commit message, the index or a branch
  range can be told a result that does not hold. Neither mode sees the
  branch's name, tags or other branches — the base among them, so a
  branch-range check against a base that moved can be reused — an ignored
  file, an empty directory, or a rename that changes only letter case where
  the file system ignores case. An unmerged path, or an untracked directory that
  holds a repository of its own, means no key, as a submodule and an
  assume-unchanged or skip-worktree entry already did.
- **A skipped test makes a suite result red.** A skip was counted as an ok
  and reported; a test that did not run has not passed, so a run with a skip
  is now recorded red and never reused, and `suite-lookup` refuses a record
  that counts one.
- **Phase F ends early and narrows.** A round that finds no CRITICAL or HIGH
  finding is the last: its findings are fixed and the loop ends. A later
  round checks only the findings still open and the text the last fixes
  changed, never a fresh full pass, still at most `maxAnalyzeIters` rounds.
  `docs/phases.md` explains the loop in its new section "The analyze loop".

### Fixed

- **An unreadable state file is not a live run.** Pre-flight's `runsLive`
  read any state file that was not DONE as a live run, garbage and an empty
  file included, with no warning. One that is not one JSON object with a
  string `current_phase` is now warned about, named in
  `tree.unreadableRuns`, and not counted.
- **An empty or blank state file is not valid JSON on jq 1.6 either.** jq
  1.6 accepts an empty file, so `validate` read its `current_phase` as empty
  and named that instead. Every command now names the file not valid JSON,
  on jq 1.6 as on later versions.
- **Two `lock-take` calls can no longer both win.** A stale lock was
  removed and the new one created in two steps, so a second taker could
  remove the first one's new lock. `lock-take` and `lock-release` now do
  all their work under one guard; a guard left by a process that died is
  broken after a minute, and a stale lock is still taken over.
- **A run of phase names is no longer a phase.** `phase-start`,
  `phase-done`, `from-validate` and `validate` accepted `C C.5` and `A B`;
  each name is now matched whole.
- **`.` and `..` are not feature names.** `init ..` wrote
  `.delivery-kit/progress.json`, and `init .` wrote `runs/progress.json`.
  A name made only of dots is refused, by name, and so is a name ending in a
  dot, which Windows drops from a folder name. Pre-flight reads a run whose
  name starts with a dot too.
- **The state file, the lock and the metrics file are written with LF on
  Windows.** A native Windows `jq` wrote them with CRLF line endings; every
  file `progress.sh` writes with `jq` now passes `-b` when that `jq` takes
  it, and pre-flight reads each run without it.
- **`-b` is no longer passed to a `jq` that refuses it.** `progress.sh`
  passed `-b` to `jq` in every read the commit commands, the question queue,
  `state-set` and the suite commands make, and jq 1.6, the default package
  on Ubuntu 22.04 and Debian 12, refuses it off Windows, where `jq` writes
  LF anyway: `pending` failed, and `state-set` called a valid object not
  one. `-b` is now probed once per command, never assumed. The oldest `jq`
  supported is 1.6.

## [1.4.0] - 2026-10-11

### Added

- **`snapshot <feature> piece` and `snapshot <feature> late <phase>`** save
  what the tree held when a piece or a late phase started, with the piece's
  heading taken from `piece-next`. A list already saved stands on a resume;
  `--fresh` saves a late phase's list afresh for a `--from`. A piece found
  already committed is recorded instead, so it is never built again.
- **`spec-commit <feature>`** commits the spec directory alone as
  `docs(spec): <feature>`, once, and makes no commit for a spec the owner
  already committed.
- **`piece-commit <feature> <message-file>`** commits the paths `git status`
  lists that it did not list when the piece started, plus the tasks file (a
  file already uncommitted when the piece started is left for K), refuses a piece with a task not marked
  `[X]`, never commits from an empty path list (which would commit whatever is
  staged), adds the `Tasks:` and `Piece:` lines, and records the commit. A
  piece committed before a crash is recorded from its commit, not rebuilt.
  `--list` shows the files without committing.
- **`late-commit <feature> <phase> <message-file>`** makes the late commit
  for H.5, H.7, I or J from what changed since the phase started, leaves an
  untracked file outside the feature for K, makes no commit when nothing
  changed, and with `--record` makes J's empty record commit, once.
- **`remainder-commit <feature> <message-file>`** makes K's commit of
  everything still uncommitted, every path named, never a path under
  `.delivery-kit/`, and records it as kind `other`; with
  `--kind constitution` it commits a constitution written by an accepted
  pre-flight offer as its own commit. Nothing left makes no commit.
  `--list` shows the files without committing.
- **`record-branch <feature>`** records every unrecorded commit on the
  branch under its kind, oldest first, and stops on a commit it cannot show.
- **`guide <feature>`** prints the pull request's review guide. With
  `--parts` it prints the file-count form and writes the full guide in parts,
  each under GitHub's limit for a body or comment.
- **`commit-list <feature>`** prints K's list: every commit with its message
  and files, then every uncommitted path, each marked inside or outside the
  feature.
- **`drop-stale <feature>`** removes, on the owner's answer at L, the
  entries for commits that are not on the branch.
- **`metrics <feature>`** creates or refreshes `pipeline-run.json` from the
  state file, keeping the keys the orchestrator added.
- **`state-set <feature> <key> [<sub-key>] <json>`** writes `gates`,
  `artifacts`, `measurements`, `config`, `analyze_changelog`,
  `test_baseline` or `last_task`, validates the result before it replaces
  the state file, and refuses every other key.
- **`suite-key`, `suite-record` and `suite-lookup`** keep each full run of the
  test command on a clean tree, so F.5, J and N, and a later run's F.5, can cite
  a green result instead of running the suite again. A result is reused only
  for a clean working tree with no submodule and no index entry marked
  assume-unchanged or skip-worktree, whose committed tree, tracked files'
  bytes on disk, test command and platform are the ones it was recorded on,
  and only when its TAP is green: exit 0, a plan line first, exactly that many
  `ok` lines numbered 1 to N, no `not ok` and no stray line. A tree that no
  longer has its key when the result is recorded is not recorded, and a red
  result is never reused. Files git ignores, the environment and the tools'
  versions are not in the key: a reuse assumes them unchanged.
- **`ask-later`, `pending`, `answer` and `pending-check`** keep a queue of
  waiting questions in `gates.pending`. A question may wait only when its
  answer changes nothing before the run's next stop; in doubt it stops the
  run at once. Every open question is asked at the next stop, and
  `pending-check` stops the run before L pushes while one is open, under
  `--auto` too; after L nothing waits. An answer stands, and the same
  question from the same phase is never asked again; `state-set` cannot
  write the queue. A question or answer file is refused when it is blank,
  longer than 16,384 bytes, or holds a control character other than tab and
  line feed, or a character from the one list in `scripts/hidden-chars.sh`
  (bidi, invisible and zero-width characters, variation selectors, tag
  characters, the byte-order mark) that trailers are checked against too.
  `pipeline:status` names every open question.
- **A base branch that beats the remote's default: the
  `baseBranchOverride` key and the `--base-branch <name>` flag.** Where
  the remote publishes a default branch, that default has always won over
  the `baseBranch` key, so a team that cuts its feature branches from an
  integration branch had no way to say so. Set `baseBranchOverride` once
  in the repository's `.delivery-kit.json`, or type `--base-branch` for
  one run; the flag beats the key. Pre-flight reports the source as `override`, and the probe line names
  the layer that set it. The override is read on a
  fresh run only: a resume keeps the base the run recorded, and a
  different name on a resume is reported, not applied: on a resume the
  run passes no override to pre-flight. A name that is not a local
  branch, a name that is a tag as well, or a name git would not accept
  as a branch name, stops pre-flight, naming it. So does a name holding
  a character other than a letter, a digit, `.`, `_`, `-` or `/`, since
  pre-flight prints the name in a command a person may run. The
  `baseBranch` key is unchanged.
- **A feature branch and a spec folder named for one run: the
  `--branch <name>` and `--spec-dir <path>` flags.** The spec tool's
  `NNN-slug` used to name the feature branch, the spec folder and the
  run, with no way to choose them. `--branch` names the branch, and may
  hold `/`. `--spec-dir` names the spec folder, nested folders included,
  and its last segment becomes the run's name. Both are flags only: each
  names one feature, so there is no configuration key. Pre-flight stops
  on a bad value, naming it: a branch name git would not accept, the
  base branch's own name in any spelling, a branch that already exists,
  or a spec folder that is absolute, climbs out with `..`, holds an odd
  segment, a segment ending in a dot or a name Windows keeps for a device
  (`nul`, `con`), sits under `.delivery-kit/` or `.git` in any letter case,
  leads out through a symbolic link, already exists, or whose run name
  already has a state file. A branch name holding a character other than
  a letter, a digit, `.`, `_`, `-` or `/`, or one that is a tag as well,
  is refused too. A refusal names the folder as given, never the path a
  link leads to, and every name, folder, segment or unknown argument
  pre-flight refuses is printed masked: cut to 200 bytes and marked
  ` [cut]`, with every byte that is not printable ASCII shown as `?`. Without `--branch`, the folder's last segment
  gets the branch checks. Both are read on a fresh run only. On a
  resume, pre-flight prints the branch and the folder the run recorded.
- **Trailers on every commit the run makes: the `commitTrailers` key and
  the `--trailer <token: value>` flag.** A team that tags its commits
  had to edit every message by hand. Set `commitTrailers` once in the
  repository's `.delivery-kit.json` for the team's fixed trailers, and
  type `--trailer` for one run's own; the flag adds to the key and never
  replaces it. Every commit the run makes carries the list, the spec
  commit and J's empty record included: `spec-commit`, `piece-commit`,
  `late-commit` and `remainder-commit` add it from the state file's
  `config.commitTrailers`, never adding one twice. Pre-flight prints
  each trailer with its layer, and stops on a malformed one or on the
  run's own `Piece`, `Late` and `Tasks` tokens, naming it. It also
  refuses, from every layer, a trailer that would act on GitHub or name
  another author: `skip-checks`, `Co-authored-by`, `Signed-off-by`,
  `On-behalf-of`, a closing keyword (`Close`, `Fix`, `Resolve` and their
  forms) as the token, or anywhere in the trailer before an issue in any
  form GitHub reads (`#1`, `owner/repo#1`, `GH-1`, the
  issue's URL), or a value holding `[skip ci]` or its spellings. It
  refuses a character that can disguise text in a terminal, from the one
  list questions are checked against, `scripts/hidden-chars.sh`, and a
  refusal shows each such character as its `\u` escape.
  It refuses a trailer holding a quote (`'`), a dollar sign or a
  backtick, because the run types the list into a shell command, and one
  holding `##[` anywhere, which a GitHub workflow log reads as a command.
  Pre-flight and the commit subcommands run one file for the rule,
  `scripts/trailer-check.sh`, and the subcommands append the lines
  themselves, so no git `trailer.*` setting touches them. K shows each
  message with the trailers, as the new `progress.sh show-message`
  prints it (`--record` for J's record commit). The list is read on a
  fresh run only.

### Fixed

- **State writes no longer race.** Every write to a run's state file holds
  a lock and a temporary file of its own. Two writes at the same moment
  could lose one another's change, or leave the state file empty. A
  scratch-file name or a `STATE_LOCK` inherited from the environment is
  ignored, so `progress.sh` never removes a file it did not make.

### Changed

- **The handoff package's parts moved to `docs/handoff-package.md`, and
  `git stash` joined the never-bend rules.** Stash hides work as surely as
  `git reset --hard`, `git clean` and `git checkout --` discard it.
- **The README is the pipeline's full guide.** The marketplace's root README
  is now a short start page, so this README gained what only the root page
  held: the sample pre-flight block, stopping and resuming, what a failed
  phase leaves, the `#123` seed that stops without a remote or `gh`, and a
  troubleshooting table. Its flag table, now called Flags, lists `--auto`
  and `--auto-release` too, and a test checks that it lists the same flags
  as the skill's table. It also says that without `gh` the run pushes,
  prints a comparison link and skips the review phase, and that on Windows
  that phase needs `gh` by that name. The root page has a Windows section
  for both plugins.
- **Three configuration rules moved from the skill to
  `docs/configuration.md`, word for word.** How a later layer's `null`
  merges, and when an `implementer` value stops the run, are now in the
  page's "Resolving the layers" section. How the pre-flight `Implementer`
  line is rendered is now in its section "The Implementer line". The
  skill sends the run to both.
  The move keeps `SKILL.md` under 65,536 bytes, the size Git Bash 5.3.9
  can read in a herestring. A test now pins that size.

## [1.3.1] - 2026-10-06

### Fixed

- **Pre-flight no longer hangs on a large constitution.** A constitution of
  about 64 KB (65,536 to about 65,700 bytes) made pre-flight hang under Git
  Bash 5.3.9, which hangs a herestring of that size. The file is now fed
  through process substitution, and a test pins a 65,600-byte constitution
  under a timeout.
- **Pre-flight finds `gh` installed as `gh.exe` or `gh.cmd`.** A Windows
  package manager can install the GitHub CLI as `gh.cmd` alone, which a bare
  `gh` lookup never finds, so pre-flight reported a working `gh` as absent and
  planned to skip the pull-request review (M). It now probes `gh`, `gh.exe`
  and `gh.cmd`, reports the name it found as `remote.ghCommand`, and the
  orchestrator calls `gh` by that name. M's skip now gives one of two reasons:
  the remote is not GitHub, or `gh` is absent.

### Changed

- **The state helper validates with one `jq` process.** `progress.sh
  validate`, which every subcommand calls, ran about nine `jq` processes and
  now runs one on a well-formed state file, with the same messages in the same
  order (a 150-case comparison against the old script). Each call is about four
  times faster on Windows, and the helper's own test file ran in 192 s instead
  of 625 s.
- The plugin's README shows the two spec-kit setup commands a first run needs,
  and its phase diagram groups every phase under the right label. The plugin's
  description says it requires spec-kit in the target repository.

## [1.3.0] - 2026-10-01

### Added

- **The run builds and commits in pieces.** A piece is one `## Phase <N>:`
  section of the run's tasks file. Phase H now commits the spec directory on
  its own first, then builds one piece at a time — asking the state helper for
  the next piece, building only that piece's tasks with the spec tool's
  implement command, and committing exactly the files the piece changed plus
  the tasks file with its marks. Every commit names every path, and each is
  recorded in the state file. A reviewer reads the branch in order: the spec,
  then each piece. A piece that changed nothing but its marks still gets its
  own commit, and says so.
- **Pause mode.** At G the developer now chooses how to review: **commits**
  (the run finishes, with one commit per piece to read afterwards) or
  **pauses** (the run stops after each piece is built, before it is
  committed, and shows the piece, its files and its diff). A pause takes three
  answers: go on, fix this, or stop here. Files the developer edits during a
  pause go into that piece's commit and are named in its message. `--auto`
  never collapses a pause.
- A commit hook that rejects a piece is a hard stop — the piece stays
  uncommitted and is shown first on resume. `--no-verify` is never used.
  Resume never rebuilds a recorded piece, and a piece committed just before a
  crash is recognised from its commit and recorded, not built again.
- **A review guide in the pull request.** L's pull-request body and the DONE
  summary now carry a table of every commit the run made on the branch (a
  merged-in branch shows only as its merge), oldest first —
  commit, kind, piece, task IDs and files — headed with one line telling the
  reviewer to read the branch commit by commit, top to bottom. The body is
  shown in full at L before anything is pushed.

### Changed

- **G now stops on every run whose implementer is `claude`**, even under
  `--auto` and even when `implementer` is pre-answered: it asks the review
  question, which no setting or flag answers in advance. A pre-answered
  `implementer` still removes the implementer question. As a result a fresh
  run no longer reaches the end without a stop. The handoff path is
  unchanged: G does not ask the review question there and says so in one
  line, and that run keeps a single commit. A run started on an earlier
  version that has already passed G keeps the single-commit flow for its
  whole life; one resumed before G finished is asked the review question
  there.
- **The phases after H commit their own work.** In the piece flow, converge
  (H.5), simplify (H.7), deep review (I) and the test phase (J) each end with
  one commit of their own when they changed a file; piece commits are never
  rewritten. A red the owner waved through at J
  rides in J's own commit, or in an empty commit when J changed nothing.
  Simplify and deep review now read the run's whole change, not only the
  working tree.
- **K shows the whole commit list.** Once the branch holds commits, K shows
  every one of them with its message and files, then what is left and the
  message it will use, and commits the remainder only after the answer. K now
  stops even under `--auto` for a path outside the code roots, the feature's
  spec directory and the tasks file, or for a commit it cannot show: an empty
  commit that no phase explains. A merge is shown with the files it brought
  in.
- **A tracked state file stops the run.** When the run's state file is
  tracked in git, a re-entry stops, shows every recorded answer, and waits for
  the developer to confirm them.
- **L stops for what it cannot show, as K does.** Even under `--auto`, L stops
  for a commit it cannot show and for a state-file record of a commit that is
  not on the branch, rather than build a review guide that would mislead.
- **`pipeline:status` reports the new stops.** It now names a run waiting at
  G's review question, a run waiting for K's answer after K recorded its flow, a
  handoff run most likely parked at H for the implementer's report, and a run
  in pause mode left at H, with the pause answers recorded so far. It reports a
  commit a hook rejected as the stop, says when the state file is tracked in git
  (and when that check itself failed), says when it cannot tell why a run
  stopped, and treats every string in the state file as data.

## [1.2.1] - 2026-09-08

### Changed

- `README.md` gains a **What ships** section. Two skills that ship with
  user-facing descriptions — `pipeline:spec-review` and `pipeline:device-verify`
  — were named in no README and in no command reference, so the only way to
  discover them was to list the plugin's directories. Both run inside a phase
  and both stand alone, and the table says which phase and when standing alone
  is the useful case. They are also now rows in the root command reference.

- **New: [`docs/phases.md`](docs/phases.md), a phase reference.** `--until C.5`,
  `--from H.7` and pre-flight's `Will skip: N.5` all speak an alphabet that was
  defined only inside the orchestrator skill, which is not a document a user
  reads. The README already drew the shape and named the gates; the gap was the
  fractional phases and the letters that stop at nothing. Each row says what the
  phase does and what it leaves behind, which is what you need when a run stops
  somewhere and you are choosing a value for `--from`.

- The tested spec-kit range is spelled identically in every place that states
  it — the two READMEs, the configuration page, the orchestrator skill, and
  `scripts/preflight.sh`, which had it as `(0.15.x-0.16.x)` while the others
  said "through". The root README also had it broken across a line, so a search
  for the phrase missed the site most readers meet first.

  The `case` in `preflight.sh` is the authoritative definition and now says so,
  with the command that finds the prose beside it. Widening the pattern without
  rewording the documents would leave the tool accepting a version every
  document still calls untested — the quieter of the two directions, and the
  reason the coupling is written down rather than remembered.

## [1.2.0] - 2026-09-03

### Added

- Pre-flight now probes `git` and reports it beside `jq`, `gh` and `adb`. An
  absent `git` is a STOP, not a degradation: the run names the tool, prints
  `https://git-scm.com/downloads`, and installs nothing. It stops because
  nothing survives the absence — branching, committing and opening a pull
  request are all git operations, and the probe's own base branch and working
  tree reads are git commands that, without it, quietly reported an empty
  branch and a clean tree. Naming a phase to skip would have named a capability
  nobody acts on. The stop fires before every other pre-flight decision,
  including the two that call git themselves, and the base branch, remote and
  skip lines are printed as *not read* rather than as the values those absent
  commands appeared to return.

  The rule is pinned, not merely written: a suite test slices the probe block,
  the not-read rule and the decision walk, and asserts the stop's condition, its
  action, its fires-first ordering, the printed link and the
  capability-not-a-skip rule inside the region each belongs to. Deleting the
  rule, inverting its ordering, or softening the stop to a warning each turn
  that test red.

  Two limits, stated because the alternative is a reader discovering them. The
  answer is recorded where a run has somewhere to record it; on a fresh run the
  stop precedes the state file's creation, so there the stop and the printed
  link stand on their own. And the probe asks whether `git` can be FOUND, not
  whether it will work — a `git` that is present but refuses to operate on the
  repository still reports present, and the stop does not fire for it.

### Changed

- `README.md` rewritten for a first-time reader: the twenty phases drawn as
  one map with the five gates marked, the gate table naming what each one
  shows and what collapses it, and the automation warning stated where a
  reader meets it. No phase, flag, default, or gate changed.
- The plugin manifest's description now says what the plugin does in one
  plain sentence, matching the marketplace entry.

## [1.1.0] - 2026-08-24

### Added

- Pre-flight now probes the project constitution: the probe script
  emits a new boolean for it, the probe block prints a Constitution
  line (`set`, or `not set — plan gates run against an empty
  document`), and when it is not set the run offers the spec-kit
  constitution command once — the principles are the owner's to write,
  declining is fine, and the offer is not repeated within a run.

- The implementer gate's handoff package is now a seven-part contract —
  files to provide, repository state, instructions, the derived
  forbidden list, what will bite this feature, validation before done,
  and the report-back contract — so a cheaper model receives everything
  a good handoff carries, and a new prose test pins the seven names.
  A "handoff" answer now parks the run at the implement phase with the
  lock released, and a later resume consumes the implementer's report
  before dispatching anything the report already claims.

- The `implementer` key and its `--implementer <claude|handoff|ask>`
  flag: set to `claude` or `handoff`, either one pre-answers the
  implementer gate, which records the configured answer and does not stop
  to ask. Set to `ask` the gate asks, as it does when the key is unset —
  the value exists so a later layer, a command line included, can take
  back a stop an earlier layer gave away; writing `null` in a later layer
  overrides nothing, since layers merge by silence rather than erasure —
  which holds for every key, so the command keys, having no `ask` of their
  own, can be replaced by a later layer but never returned to unset.
  With `claude` an `--auto` run then stops at no gate but clarify —
  where `releaseCommand` is unset and the constitution is already set,
  since the release gate and the pre-flight constitution offer each still
  stop a run of their own accord; where clarify also raises no questions,
  no gate stops the run at all. Read that as a claim about gates and
  nothing else. Cap breaches, a missing required tool, hard failures and
  a failed runtime check still stop it, but the gates do not — and this
  release adds a fourth cap, `maxVerifyIters`, so that caveat is wider
  now than when it was written; `docs/configuration.md` states the whole
  range. With `handoff` the run parks for the
  external report, package written and lock released. Unset means the
  gate asks, as before; an illegal value stops pre-flight by name — never
  coerced, never treated as unset. Pre-flight prints an `Implementer`
  line naming the resolved value and the layer it came from, and omits
  the line when unset.

- The `maxVerifyIters` key, default 5: the verification phase's fix loop
  runs at most that many iterations, and a breach is a conditional stop —
  the remaining failures are shown and the run asks whether to continue.
  Verification was the last unbounded loop in the product; it now has the
  shape clarification, analysis and review already had. One difference is
  deliberate: a breach waved through records the surviving failures in the
  state file and carries them outward into the commit message and the pull
  request — into the commit message alone where no pull request exists,
  because a degraded remote can leave the run without one. The state-file
  record is kept either way. Verification is the last full-suite check before
  code leaves the machine. A hard failure still stops the run outright.

## [1.0.1] - 2026-08-22

### Fixed

- Phase O now says what the release gate does when `releaseCommand` is
  unset: record that there is nothing to publish, and move on.
- The N.5 runtime check now covers verification done beyond the
  configured strategy, and how to report it.
- The G implementer gate now covers the handoff package left behind
  when the gate's answer changes.
- The ground rules gain a bullet on tools the machine lacks.
- The README's example invocations use the canonical
  `/pipeline:pipeline` spelling; the short form `/pipeline` resolves to
  the same command.
- Gate descriptions now say "up to five stops": a gate with nothing to
  ask records that and moves on, and the missing-tool rule separates
  tools that stop the run from capabilities that merely degrade a
  phase.

## [1.0.0] - 2026-08-20

### Added

- The scaffold: plugin manifest, marketplace entry, and this changelog.
- State and lock mechanics (`scripts/progress.sh`), with its test suite:
  the run state file under `.delivery-kit/`, the phase alphabet and the
  validation that guards it, and a repository-wide lock. Pure JSON on
  stdout, every diagnostic on stderr.
- Pre-flight detection (`scripts/preflight.sh`), with its test suite:
  project type, base branch, working-tree state, and the capability probe
  that degrades a named phase rather than crashing one. It reports; the
  decisions stay with the skill that reads it. The suite runs against
  fixture repositories covering each project shape it recognises and the
  case where the tooling it drives is absent.
- The `/pipeline` command and the orchestrator skill behind it. The
  command is the only door in — it disables model invocation, so a
  conversation that merely mentions specs, plans or releases cannot start
  a run — and the skill carries a unit of work from its seed through
  specification, planning, implementation, review and release, stopping
  at a human gate for everything that leaves the machine or cannot be
  undone by editing a file.
- The `pipeline:status` skill: reads a run's state through the plugin's
  own mechanics and reports the phase board, the gate the run is parked
  at, and the exact next action.
- The `pipeline:spec-review` skill: audits an implementation against its
  specification through independent lenses — contract compliance,
  security, and tests — run as separate passes, so a finding from one
  lens never dilutes another's.
- The `pipeline:device-verify` skill: builds, installs and drives a
  mobile release build on one attached device, captures each screen it
  touched, and reads every capture back. The description is the
  verification; a screenshot nobody read is not one.
- The configuration reference (`docs/configuration.md`): every key with
  its default or its detection path, and the precedence that runs from
  the two configuration files through `--config` to the individual flags.
  Nothing is required, and there are deliberately no environment-variable
  overrides — the reference says so rather than leaving it to be
  discovered.
- Prose gates (`tests/prose.bats`) over the orchestrator and the command,
  pinning the promises that live only in text: the closed front door, the
  gates named with the phases they guard, the never-bend rules verbatim,
  the release gate that `--auto` never collapses, and the runtime check
  that never claims a verification it did not make.
