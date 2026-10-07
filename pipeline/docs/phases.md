# Phase reference

`--until C.5`, `--from H.7` and pre-flight's `Will skip: N.5` all speak an
alphabet. [The README](../README.md) draws the shape of it and names the phases
that stop and ask you. This page is the rest: every letter, including the
fractional ones, with what it does and what it leaves behind.

You need this when a run stops somewhere and you want to know what it had
already finished, or when you are choosing a value for `--until` or `--from`.

## The letters

| Phase | Name | What it does |
|---|---|---|
| pre-flight | probe and decide | Reports the project type, the spec tool, the constitution, the base branch, the implementer setting and its source, the remote, and what it will skip. Stops if the spec tool is missing, if the tree is dirty with work no run claims, or if `implementer` holds a value that is not `claude`, `handoff` or `ask`; and on a re-entry whose state file is tracked in git, it stops until you confirm the answers recorded in it. |
| A | extract the seed | Turns your argument into a feature description — a section of the plan file, a GitHub issue, or the text verbatim. |
| B | specify | Runs the spec-kit specify command. The spec tool names the feature; the state file and the feature branch are created here. |
| **C** | clarify | **Stops and asks.** One question at a time, until the tool has none left or the pass cap is reached. Only you know these answers, so no flag collapses this. |
| C.5 | spec quality gate | Audits the spec itself: every requirement testable, none contradicting another, every term defined, nothing from the seed silently dropped. |
| D | plan | Runs the spec-kit plan command, and checks the plan against the constitution. |
| E | tasks | Runs the spec-kit tasks command, then audits each task for a named file, independent verifiability, and ordering. |
| F | analyze | Runs the spec-kit analyze command and fixes what it finds, in a capped loop. |
| F.5 | test baseline | Runs the test command and records the result verbatim. Failures that exist *before* the feature are not the feature's, and phase J classifies against this record. May reuse a green result on the identical tree instead — see [reusing a suite run](#reusing-a-suite-run). |
| **G** | implementer | **Stops and asks** up to two questions. First, who builds: here, or a package for a cheaper model — the `implementer` setting can answer this one. Then, for a build here, how you review it: **commits** (one commit per piece, read afterwards) or **pauses** (a stop before each piece's commit). The second question is asked on every fresh run that builds here; nothing answers it in advance, and `--auto` does not collapse it. Choosing the package parks the run and hands you a brief. |
| H | implement | Runs the spec-kit implement command. On a run that builds here, it commits the spec first, then builds one phase of the tasks file — a *piece* — at a time and commits each piece on its own; in pause mode it stops before each piece's commit (go on, fix this, or stop here). A handoff run, or one begun on an older pipeline, builds in one pass and leaves the commit to K. Independent tasks in the same group run in parallel; two agents never edit one file. |
| H.5 | converge | Re-reads the tree against the spec and appends whatever is still missing as new tasks. Skipped, and said so, where the spec tool does not ship it. In the piece flow, commits what it changed. |
| H.7 | simplify | Runs the simplify skill over the run's whole change within the configured code roots. Skipped, and said so, when there is no code to simplify. In the piece flow, commits what it changed. |
| I | deep review | Three reviewers at once — contract compliance, security, tests — over the run's whole change. Fixes fan out; in the piece flow, the phase commits what it changed. |
| J | analyzer and full suite | Runs both commands (or reuses a green suite result on the identical tree) and classifies every failure against the F.5 baseline. Pre-existing failures are reported, not owned. A failure waved through at a cap is recorded and carried into J's own commit (or an empty one when J changed nothing; in the single-commit flow, into K's commit, or into an empty record commit K makes when nothing is left to commit) and the pull request. In the piece flow, commits what it changed. |
| **K** | commit | **Stops and asks.** Once the branch holds commits, shows every one of them with its message and files, then what is left — every path named, never a wildcard — and the exact message. Collapsed by `--auto`; once the branch holds commits, it still stops for a path outside the code roots, the spec directory and the tasks file, or for a commit it cannot show. |
| **L** | push and pull request | **Stops and asks.** Shows the branch, the title and the whole body before anything leaves your machine. The body carries a review guide, one row per commit, oldest first — see [reviewing a run commit by commit](../README.md#reviewing-a-run-commit-by-commit). Collapsed by `--auto`, except for the stops L names itself, such as a commit it cannot show or a state-file record of a commit that is not on the branch. Degrades where there is no remote, or no GitHub. |
| M | pull request review | Runs the review skill against the pull request and fixes what it raises, in a capped loop. Skipped, and said so, when there is no pull request to review. |
| N | re-verify | Runs the analyzer and the suite again (or reuses a green suite result on the identical tree), classifies, commits fixes, pushes. **Degraded, never skipped** — the last thing a run does with code must not be "change it and not check it". |
| N.5 | runtime check | Proves the change actually runs: a browser for a web project, a device for Android, otherwise the configured verify command. Reports honestly when no strategy applies rather than inventing one. |
| **O** | release | **Stops and asks.** Shows the exact release command and where it publishes. `--auto` does *not* collapse this; `--auto-release` does, typed on purpose. Records and moves on when no release command is set. |
| DONE | | Releases the lock and summarises what shipped, what was skipped and why, and where the artefacts are. The summary carries the review guide, rebuilt to include the review and re-verify commits. |

Phases in bold are the gates. A gate with nothing to ask records that and moves
on — no clarify questions, a pre-answered `handoff`, no release command. A fresh
run that builds here always has G's review question to ask.

## The fractional phases

These are the ones the letters alone do not suggest, and they are the reason
this page exists:

- **C.5** follows clarify, because a spec can be unambiguous and still
  untestable.
- **F.5** must run *before* any code changes, or there is nothing to classify
  against.
- **H.5** and **H.7** follow implementation: one asks what is still missing, the
  other asks what is now redundant.
- **N.5** follows re-verification, because a green suite is not the same claim
  as "it runs".

## Reusing a suite run

The full test command can take a long time, and a phase often runs it on a
tree it has already passed on. Each full run on a clean tree is therefore
recorded, and F.5, J and N may cite a recorded result instead of running the
command again — only when all of these hold:

- the working tree is **clean**: no change, tracked, staged or untracked,
  except an untracked file under `.delivery-kit/` (ignored files are not
  seen, as git does not see them); no file hidden from `git status` by
  `assume-unchanged` or `skip-worktree`; and no submodule;
- the committed tree is **identical** to the one the result was recorded on,
  and so are the **bytes** of every tracked file as they sit on disk, read
  with no filter and no line-ending conversion — a file `git status` calls
  unchanged still counts when its bytes differ;
- the **test command** is the same string, and the **platform** (`uname -s` and
  `uname -m`) is the same;
- the result is **green**: exit code 0, a plan line `1..N` first, exactly N
  `ok` lines numbered 1 to N in any order (a skip counts and is reported), no
  `not ok`, and no other line but a `#` comment or a blank one.

The green rule reads TAP as bats prints it. Other TAP shapes — a
`TAP version` header, a plan line at the end, a `# TODO` test, a subtest —
are red by this rule, and so is any output that is not TAP. Red only means
the suite runs again: a red result is never reused, because F.5 needs its
failures verbatim, and J and N need to see them. The analyzer is never
cited; it always runs.

What the key cannot see, a reuse assumes unchanged: files git ignores (a
dependency directory, a `.env` file), the environment, the tools' versions,
and a file's mode where git ignores it (`core.fileMode` false). Records have
no age limit and are shared by every run in the repository, so after a change
to any of these, delete `.delivery-kit/suite-results/` and the next phase
runs the suite.

The state helper does the keeping. `progress.sh suite-key <feature>` prints
the key before a run, or exits 1 and says why there is none.
`progress.sh suite-record <feature> <key> <tap-file> <rc>` records the run and
prints `green` or `red`. It refuses when the tree no longer has the key it had
before the run — a commit made meanwhile, or a file a test left behind outside
`.delivery-kit/` — so the run's output belongs under
`.delivery-kit/runs/<feature>/`. A file a test changed and then restored, or
wrote where git ignores it, is not seen. `progress.sh suite-lookup <feature>`
exits 0, printing the record's path and counts, only for a green result on the
current key. A phase that cites quotes those two lines verbatim; at F.5 they
are the `test_baseline`. Records live in `.delivery-kit/suite-results/`, so a
later run's F.5 can reuse an earlier one.

A tree with uncommitted work has no key, so a phase that runs on one always
runs the suite and records nothing. That rules out most F.5 runs — the
feature's spec directory is not committed until H — and every J iteration
that runs on a fix not yet committed. Reuse fires when nothing changed since a
green run on a clean, committed tree: N citing J when J's run was clean and
green and nothing was committed after it, a phase re-entered on the same
tree, or a later run's F.5 on a tree an earlier run passed.

## Questions that wait

A run asks the owner things at many points, and stopping for each one is
costly. A question may wait only when its answer changes nothing the run does
before its next stop — "record this as a known limit?", "say this in the
pull request?". When the run cannot tell, the question stops the run at once:
a doubt never makes a question wait.

A waiting question is queued with `progress.sh ask-later <feature> <phase>
<question-file>`, which prints its id (`P1`, `P2`, …); the same question from
the same phase is queued once. At every stop — a gate, a cap, a failure, a
pause, the resume prompt — `progress.sh pending <feature>` prints the open
questions, and they are asked with the stop's own. `progress.sh answer
<feature> <id> <answer-file>` records each reply: an answered question is
never asked again, and its answer is never replaced. A question the owner
leaves unanswered stays open.

Before L pushes, `pending-check` must pass, under `--auto` too: it exits 1,
naming the open ids, while any question waits, so no unanswered question
reaches a pull request. The queue lives in the state file under
`gates.pending`, so it survives a handoff and a resume; only these commands
write it, and `state-set` refuses to.

## Using them with the flags

`--until <phase>` stops cleanly after that phase, with the state file intact and
the lock released, and the run is resumable. `--from <phase>` re-enters at one,
and is validated against which artefacts actually exist — re-entering a phase
without the thing it consumes re-runs work that has nothing to work on.

Both take the names in the first column exactly as written, fractional ones
included.
