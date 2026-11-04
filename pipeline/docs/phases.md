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
| F | analyze | Runs the spec-kit analyze command and fixes what it finds, in a capped loop that ends after a round with no critical or high finding — see [the analyze loop](#the-analyze-loop). |
| F.5 | test baseline | Runs the test command and records the result verbatim. Failures that exist *before* the feature are not the feature's, and phase J classifies against this record. May reuse a green result on identical files instead, or on the files as they were before the feature, or a result the run's own background run recorded on the base commit — see [reusing a suite run](#reusing-a-suite-run). |
| **G** | implementer | **Stops and asks** up to two questions. First, who builds: here, or a package for a cheaper model — the `implementer` setting can answer this one. Then, for a build here, how you review it: **commits** (one commit per piece, read afterwards) or **pauses** (a stop before each piece's commit). The second question is asked on every fresh run that builds here; nothing answers it in advance, and `--auto` does not collapse it. Choosing the package parks the run and hands you a brief. |
| H | implement | Runs the spec-kit implement command. On a run that builds here, it commits the spec first, then builds one phase of the tasks file — a *piece* — at a time and commits each piece on its own; in pause mode it stops before each piece's commit (go on, fix this, or stop here). A handoff run, or one begun on an older pipeline, builds in one pass and leaves the commit to K. Independent tasks in the same group run in parallel; two agents never edit one file. |
| H.5 | converge | Re-reads the tree against the spec and appends whatever is still missing as new tasks. Skipped, and said so, where the spec tool does not ship it. In the piece flow, commits what it changed. |
| H.7 | simplify | No separate pass: the simplify work is the `simplify` lens of I's round. Says so, changes no file and makes no commit. A run begun before pipeline 1.7.0 keeps the commit its H.7 already made. |
| I | deep review | One round, every lens at once, all read-only until all have reported: spec-review's three (contract compliance, security, tests), the code-review skill as `bugs`, and a `simplify` lens, over the run's whole change. One fix fan-out for every lens's findings; then, when the fixes changed a file, the code-review skill reads only what they changed, once. In the piece flow, the phase commits what it changed. |
| J | analyzer and full suite | Runs both commands (or reuses a green suite result on identical files) and classifies every failure against the F.5 baseline. Pre-existing failures are reported, not owned. A failure waved through at a cap is recorded and carried into J's own empty record commit, made once for each red waved through, and not again while it is the newest commit (in the single-commit flow, into K's commit, or into an empty record commit K makes when nothing is left to commit) and the pull request. In the piece flow, commits what it changed before its last full-suite run, one late commit per fixing iteration, and runs that run on the commit it leaves, so N can cite it. |
| **K** | commit | **Stops and asks.** Once the branch holds commits, shows every one of them with its message and files, then what is left — every path named, never a wildcard — and the exact message. Collapsed by `--auto`; once the branch holds commits, it still stops for a path outside the code roots, the spec directory and the tasks file, or for a commit it cannot show. When the branch holds commits and nothing is left to commit, K and L are one stop: one question shows the commit list and the branch, title and whole body, and one answer covers both; L's own checks run before it. They stay apart under `--auto`, with no remote, a remote that is not on GitHub or no `gh`, and on a run whose commit records an older pipeline wrote. |
| **L** | push and pull request | **Stops and asks.** Shows the branch, the title and the whole body before anything leaves your machine. The body carries a review guide, one row per commit, oldest first — see [reviewing a run commit by commit](../README.md#reviewing-a-run-commit-by-commit). Collapsed by `--auto`, except for the stops L names itself, such as a commit it cannot show or a state-file record of a commit that is not on the branch. Degrades where there is no remote, or no GitHub. Asked together with K when K's row says so; after that joint answer, L does not ask its push question again, but every stop it names still stops it. Before the push, L checks the branch, the title, the commit and the body again, and any difference from what was shown stops the run and asks L on its own. |
| M | pull request comments | Runs no review of its own. Reads, once per round, the pull request's comments from people with write access and its check results, and fixes those, in a capped loop. Posts nothing; never waits for a pending check. Skipped, and said so, when there is no pull request. |
| N | re-verify | Runs the analyzer and the suite again (or reuses a green suite result on identical files), classifies, commits fixes, pushes. **Degraded, never skipped** — the last thing a run does with code must not be "change it and not check it". |
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
- **H.5** and **H.7** follow implementation: H.5 asks what is still missing.
  H.7 used to ask what is now redundant; from pipeline 1.7.0 that question is
  the `simplify` lens of I's one review round.
- **N.5** follows re-verification, because a green suite is not the same claim
  as "it runs".

## The analyze loop

Phase F runs the analyze command, fixes what it finds, and runs it again, at
most `maxAnalyzeIters` rounds. Each round after the first used to be a fresh
full pass, and a fresh pass always finds something: one run's rounds found
29, 20, 16, 14 and 5 findings, every one fixed, and hit the cap. So the loop
is narrowed two ways:

- **It ends early.** A round that finds no CRITICAL or HIGH finding is the
  last: its findings are fixed — every finding is still fixed or deferred
  with its reason, never dropped — and no further round runs.
- **Later rounds are narrow.** A round after the first checks only the
  findings still open and the text the last round's fixes changed. A finding
  outside both was there for an earlier round to find, so a later round does
  not go looking for one.

The cap still binds: a loop that reaches `maxAnalyzeIters` without such a
round is a conditional stop, as it always was.

## Reusing a suite run

The full test command can take a long time, and a phase often runs it on
files it has already passed on. Each full run is therefore recorded, and
F.5, J and N may cite a recorded result instead of running the command
again. The `suiteReuse` setting says what a recorded result must match:

- **`commit`**, the default: the files below **and** git's state around
  them — HEAD's commit id, and every tracked path's index mode and object
  id. A staged change, a commit, an amended message or HEAD moved to
  another commit is a change, so a suite that reads HEAD's commit or the
  index — a trailer in the last commit message, staged bytes through
  `git show :<path>` — is never told a result that does not hold. Other refs
  are not in the key: the branch's name, tags, and other branches, the base
  among them. A check over a range such as `main...HEAD` is safe from a new
  commit on HEAD, but not from `main` moving while HEAD stays. J commits
  before its last full-suite run, so N can cite that run under `commit`
  too when nothing came after it. The price: once K commits, N cannot
  cite the run J made before it.
- **`files`**: the files alone. A change committed, staged or only in the
  working tree counts the same, so N can cite J's run after K commits the
  files it ran on, even when J's fixes deleted a file or added one —
  except a new executable file where git records modes: untracked it reads
  `100644`, and committed `100755`, so that reuse is lost. Choose it only
  for a suite that reads no git state: under `files`, a commit message, the
  index, HEAD and the branch's history are all invisible, and a check over
  a branch range that was vacuous when J ran is reused as green after K
  gives it commits to read.
- **`off`**: nothing is kept and nothing is reused. Any other value keeps
  and reuses nothing either.

A result is reused only when all of these hold:

- the **files** are **identical** to the ones the result was recorded on:
  every tracked path still on disk and every untracked path git does not
  ignore, except an untracked file under `.delivery-kit/`; every such
  file's **bytes** as they sit on disk, read with no filter and no
  line-ending conversion — a file `git status` calls unchanged still counts
  when its bytes differ, and a change of line endings alone is a change;
  and each file's mode — a tracked file's mode on disk where git sees
  modes, else its index mode, and `100644` for an untracked file;
- under `commit`, git's state is identical too, as above;
- there is no file hidden from `git status` by `assume-unchanged` or
  `skip-worktree`, no unmerged path, no submodule, and no untracked
  directory that holds a repository of its own;
- the **test command** is the same string, the **platform** (`uname -s` and
  `uname -m`) is the same, and so is the `suiteReuse` mode: a result recorded
  under one mode is never reused under another;
- the result is **green**: exit code 0, a plan line `1..N` first, exactly N
  `ok` lines numbered 1 to N in any order, none of them a skip, no
  `not ok`, and no other line but a `#` comment or a blank one.

The green rule reads TAP as bats prints it. Other TAP shapes — a
`TAP version` header, a plan line at the end, a `# TODO` test, a subtest —
are red by this rule, and so is any output that is not TAP. Red only means
the suite runs again: a red result is never reused, because F.5 needs its
failures verbatim, and J and N need to see them. A skip is red too: a test
that did not run has not passed. The analyzer is never cited; it always runs.

What the key cannot see, a reuse assumes unchanged: git's refs other than
HEAD's commit — the branch's name, tags, and other branches, the base among
them, so a branch-range check against a base that moved can be reused —
files git ignores (a
dependency directory, a `.env` file), an empty directory (git lists no
directory, only files), a rename that changes only a name's letter case on
a file system that ignores case (Windows and macOS by default), the
environment, the tools' versions, an untracked file's own mode, and a
tracked file's mode where git ignores it (`core.fileMode` false). Under
`files`, git's own records too, as above. A suite that reads any of these
can be told a result that does not hold. Records have no age limit and are
shared by every run in the repository, so after a change to any of these,
delete `.delivery-kit/suite-results/` and the next phase runs the suite.

The state helper does the keeping. `progress.sh suite-key <feature>` prints
the key before a run, or exits 1 and says why there is none.
`progress.sh suite-record <feature> <key> <tap-file> <rc>` records the run and
prints `green` or `red`. It refuses when what the key covers is no longer
what it was before the run — a file changed meanwhile, or a file a test left
behind outside `.delivery-kit/`, and under `commit` a commit made meanwhile —
so the run's output belongs under `.delivery-kit/runs/<feature>/`. A file a
test changed and then restored, or wrote where git ignores it, is not seen.
`progress.sh suite-lookup <feature>` exits 0, printing the record's path and
counts, only for a green result on the current key. A phase that cites
quotes those two lines verbatim; at F.5 they are the `test_baseline`. Records
live in `.delivery-kit/suite-results/`, so a later run's F.5 can reuse an
earlier one.

F.5 asks with `suite-lookup <feature> --base`; J and N never do. At F.5 the
run's own spec directory is new and untracked, so the files never match a
result an earlier run recorded. `--base` first looks up these files, then
the same files without the untracked files under the run's spec directory —
the files as they were before this feature, which is what a baseline
describes. Only the untracked spec directory is left out: any other change,
and a spec directory already tracked, still counts. A result is never
recorded under that narrower key; the run F.5 makes is recorded for the
files it ran on. A spec file at the top level, under `.delivery-kit/`, or
outside the repository has no spec directory to leave out.

The record `--base` looks up is made by the run itself. In B, once the
state file, its `config` and the feature branch exist, `progress.sh
suite-base <feature> start` runs the test command in the background on a
detached `git worktree` of HEAD's commit — the base commit, since the branch has no
commit yet — in a temporary folder outside the working tree. A worktree
shares the repository's configuration, so its files hold the same bytes
and its key is the one F.5 computes; a checkout inside the tree would put a
second copy of the repository where a test walking the file system would
read it. The run records its result as an ordinary record, with the same
key and the same writer as `suite-record`, and it never merges, pushes,
fetches, makes or deletes a branch, changes the main tree, takes the lock
or writes the state file, and its `started` line shows the command it
runs. Before it starts anything, it compares the checkout's key with these
files' `--base` key, and starts nothing when they differ — an accepted
`.gitignore` line, say, makes a record that could never be cited. It
starts nothing when a green record for the base files already exists, and
nothing under `suiteReuse: off` or any value that is not `commit` or
`files`. At F.5,
`progress.sh suite-base <feature> wait` waits for it: exit 2 means still
running after one slice of 540 seconds, so each call fits inside a
600-second tool limit and is made again; the limit is 900 seconds, counted
from F.5's first wait, and at the limit the runner is stopped. A runner
whose heartbeat is more than 60 seconds old is never signalled: its
process id may belong to another program by then; a live id whose
heartbeat is stale gets 15 seconds to beat again. The runner stops itself
after 3,600 seconds, so a suite that hangs on a run that never reaches F.5
still ends. The wait never decides reuse; `suite-lookup <feature> --base`
does, as above. A cited line names the record's commit (its tree under
`files`, which keys no commit) and its command.

It costs a second full run of the suite during C to F, and at worst F.5
waits the whole 900 seconds and then runs the suite itself. The checkout
holds no file git ignores — no dependency folder, no build output, no
`.env` — so a suite that needs one is red there and nothing is cited, and a
suite that an ignored file breaks in the main tree can be green there: a
green the main tree would not pass makes J blame the feature for a failure
it did not cause, never the reverse. For such a suite, set `suiteReuse:
off`.

`progress.sh tap-check <tap-file> [<expected-count>]` applies the green rule
to any TAP file, keyed or not, and prints one summary line or the first rule
the file breaks; `suite-record` judges with the same rules, and the
repository's own quickstart check calls it. It needs only bash and awk.
Reuse fires when nothing the key covers changed since a green run: a phase
re-entered on the same files; a later run's F.5 on a tree an earlier run
passed; and N citing J's last full-suite run, made on the commit J leaves,
when nothing changed after it — under `files`, also when all that changed
is a commit of the same files.

## Questions that wait

A run asks the owner things at many points, and stopping for each one is
costly. A question may wait only when its answer changes nothing the run does
before its next stop — "record this as a known limit?", "say this in the
pull request?". When the run cannot tell, the question stops the run at once:
a doubt never makes a question wait.

A waiting question is queued with `progress.sh ask-later <feature> <phase>
<question-file>`, which prints its id (`P1`, `P2`, …); the same question from
the same phase is queued once. After L nothing waits: a question raised at
M, N, N.5 or O stops the run, and `ask-later` refuses it. At every stop — a
gate, a cap, a failure, a pause, the resume prompt — `progress.sh pending
<feature>` prints the open questions, and they are asked with the stop's
own, and a run that stops for good — `--until`, the park at H, a run with no
remote — shows them before it stops. `progress.sh answer <feature> <id>
<answer-file>` records each reply: an answered question is never asked
again, and its answer is never replaced. The answer is the owner's own
words, never the run's, and on a re-entry the run reads the recorded
answers before the phase they affect. A question the owner leaves
unanswered stays open.

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
