# Changelog — pipeline

All notable changes to the `pipeline` plugin.

## [Unreleased]

### Added

- **`snapshot <feature> piece` and `snapshot <feature> late <phase>`** save
  what the tree held when a piece or a late phase started, with the piece's
  heading taken from `piece-next`. A list already saved stands on a resume;
  `--fresh` saves a late phase's list afresh for a `--from`. A piece found
  already committed is recorded instead, so it is never built again.
- **`spec-commit <feature>`** commits the spec directory alone as
  `docs(spec): <feature>`, once, and makes no commit for a spec the owner
  already committed.
- **`piece-commit <feature> <message-file>`** commits exactly the files the
  piece changed plus the tasks file, refuses a piece with a task not marked
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
  test command on a clean tree, so J, N and a later run's F.5 can cite a green
  result instead of running the suite again. A result is reused only for a
  clean working tree with no submodule whose committed tree, tracked files'
  bytes on disk, test command and platform are the ones it was recorded on,
  and only when its TAP is green: exit 0, a plan line first, exactly that many
  `ok` lines numbered 1 to N, no `not ok` and no stray line. A tree that no
  longer has its key when the result is recorded is not recorded, and a red
  result is never reused. Files git ignores, the environment and the tools'
  versions are not in the key: a reuse assumes them unchanged.

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
