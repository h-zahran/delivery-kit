# Configuration — the `pipeline` plugin

One `pipeline` block in `.delivery-kit.json`. Every key is optional:
every one has a default or a detection path, and everything detected is
printed at pre-flight so a wrong guess is visible rather than silent.

## Precedence

Later beats earlier: defaults, then `~/.delivery-kit.json`, then the
repository's `.delivery-kit.json`, then `--config <path>`, then the
individual flags. **There are no environment-variable overrides for
`pipeline` keys.** That is a deliberate choice, not an omission: the
context-guard keys need environment overrides because a hook cannot ask
a question, and the pipeline can always ask.

## Resolving the layers

The run reads this section at every resolution, as the skill says.

A later layer's `null` is silence, not an override: it leaves the earlier
layer's value standing, exactly as an absent key would. To take an
inherited `implementer` back to a stopping gate, set the later layer to
`ask` — that is what the value is for, and it is the only spelling that
overrides toward the stop. Note the consequence for the keys that have no
such value: `verifyCommand`, `releaseCommand` and `devCommand` can be
REPLACED by a later layer but never returned to unset, because `null`
there is silence too. Say so when it bites; never pretend a `null`
cleared one.

Resolution validates as it goes. An `implementer` that resolves to a
value which is none of `claude`, `handoff` or `ask` — unset is not a
value and never stops anything — stops the run HERE,
before pre-flight's decision walk begins, and so before either of its
offered writes can leave dirt no artefact claims. Pre-flight decision
item 10 anchors that rule; this is where it fires.

## Keys

```json
{
  "pipeline": {
    "planFile": "main-plan.md",
    "testCommand": null,
    "analyzeCommand": null,
    "codeRoots": null,
    "baseBranch": null,
    "baseBranchOverride": null,
    "projectType": null,
    "commitStyle": "conventional",
    "commitTrailers": null,
    "maxClarifyPasses": 3,
    "maxAnalyzeIters": 5,
    "maxReviewRounds": 3,
    "maxParallelAgents": 3,
    "agentModel": null,
    "verifyCommand": null,
    "releaseCommand": null,
    "devCommand": null,
    "implementer": null,
    "maxVerifyIters": 5
  }
}
```

`null` means *work it out*. `projectType` comes from detection;
`testCommand`, `analyzeCommand` and `codeRoots` default from the
detected project type; `agentModel` defaults to the strongest available
model, named here so what the pipeline spends is visible and changeable
before it spends it.

| Key | What it does |
|---|---|
| `planFile` | Where `Phase <N>: <title>` seeds are read from. |
| `testCommand` | The full test suite; phases F.5, J and N run it. |
| `analyzeCommand` | Static analysis; phases J and N run it. |
| `codeRoots` | Where implementation lives: the simplify phase's scope, where a late phase may add a new file, and the boundary the commit gate stops at under `--auto`. |
| `baseBranch` | See "Base branch" below. |
| `baseBranchOverride` | A base branch that beats the remote's default. See "Base branch" below. |
| `projectType` | Overrides detection; the detector's source is reported either way. |
| `commitStyle` | The shape of every commit message the run writes, except the spec commit's fixed subject. |
| `commitTrailers` | Trailers on every commit the run makes, as a list of `<token>: <value>` lines. See "Commit trailers" below. |
| `maxClarifyPasses` | Clarification loop cap; a breach stops and asks. |
| `maxAnalyzeIters` | Analysis auto-fix loop cap; a breach stops and asks. |
| `maxReviewRounds` | Pull-request review loop cap; a breach stops and asks. |
| `maxParallelAgents` | Fan-out cap for dispatched agents, every phase. |
| `agentModel` | The model dispatched agents run on. |
| `verifyCommand` | The runtime check's fallback strategy; it must produce an artefact. |
| `releaseCommand` | What the release gate runs, shown exactly before it runs. Unset means there is nothing to publish — the release gate records that and moves on; no command is ever detected or invented for this key. |
| `devCommand` | The web runtime check's server command; without it the project manifest's script table is tried: `dev`, then `start`, then `serve`. |
| `implementer` | Pre-answers G's implementer question: `claude` or `handoff`; `ask` restores the stop; unset means ask. A `claude` run still stops at G for the review question. |
| `maxVerifyIters` | Verification fix-loop cap; a breach stops and asks, and a breach waved through is recorded in the commit message and the pull request. |

## Base branch

The resolution order is: the remote's default branch (`origin/HEAD`),
then this key, then the current branch when there is no remote. The
pre-flight report names which source won. Note the consequence plainly:
**in a repository whose remote publishes a default branch, that default
wins over this key.** Set the key for repositories without a remote
default; everywhere else it is documentation of intent, not an override.

The override beats the remote's default and this key. It has two
spellings: the `baseBranchOverride` key, and the `--base-branch <name>`
flag, which beats the key. Pre-flight reports the override's source as
`override` and names the layer that set it. Set the key once, in the
repository's `.delivery-kit.json`, when a team cuts feature branches
from an integration branch while the remote publishes another default;
type the flag for a single run. The override is read on a fresh run
only. The run records the base it used, and a resume keeps that record;
a different name on a resume is reported, never applied silently. A
name git would not accept as a branch name stops pre-flight, naming it.
Like `verifyCommand`, the key can be replaced by a later layer but not
returned to unset, because `null` is silence: remove it from the file
that set it.

What the run does with the override:

- It passes `--base-branch-override <name>` to `preflight.sh` only when
  `--base-branch` was typed or `baseBranchOverride` resolves to a value,
  the flag's value when both.
- `preflight.sh` reports the source as `override` and cannot tell which
  layer set it, so the probe line names the layer that set it — the
  flag, or the configuration file by path, never a guess.
- B records the base in the state file, and the feature branch is cut
  from it. A resume uses the recorded base. An override on a resume that
  names a different branch is never applied silently — say that the
  recorded base stands, and name both.

## Feature branch and spec folder

By default the spec tool names each feature `NNN-slug`, and the feature
branch, the spec folder and the run's name all follow that name. Two
flags change it for one run: `--branch <name>` names the feature branch,
and `--spec-dir <path>` names the spec folder, relative to the
repository root. The spec folder's last segment becomes the run's name,
so it holds letters, digits, dot, dash and underscore only; the branch
name may hold `/`. They are flags only, with no configuration key: each
names one feature, so a value set once would name the same feature on
every run. A caller that builds the names from its own settings passes
them as flags. Pre-flight stops on a bad value, naming it: a branch name
git would not accept, or the base branch's own name; a spec folder that
is absolute, climbs out with `..`, sits under `.delivery-kit/`, already
exists, or whose run name already has a state file. Both are read on a
fresh run only. A resume keeps the branch and the folder the run
recorded, and a different value on a resume is reported, never applied
silently. A second fresh run with the same `--spec-dir` stops at
pre-flight, because the folder exists: to continue a run, type
`--resume`.

What the run does with the two flags:

- It passes `--feature-branch <name>` and `--spec-dir <path>` to
  `preflight.sh` only on a fresh run where `--branch` and `--spec-dir`
  were typed.
- The probe block prints a `Branch` line and a `Spec folder` line, each
  only when its value (`featureBranch`, `specDir`) is not empty. When git
  is absent, the `Branch` line is typed and IS established, but git did
  not check that it is a legal branch name: print it, and add that it was
  not checked. `Spec folder` needs no mark: its checks never ask git.
- The run name and the branch are separate values in the state file, so
  a branch name may hold `/` where a run name may not.
- In B, with `--spec-dir`, hand the folder to the spec tool with the
  seed, as `SPECIFY_FEATURE_DIRECTORY`: the tool then uses it as given
  and numbers nothing, and the feature's name is the folder's last
  segment. Before going on, check that `<folder>/spec.md` exists; a spec
  written anywhere else stops the run, naming both paths.
- B runs `progress.sh init` with the branch name about to be created:
  `--branch` when it was typed, else the feature's name. B cuts the
  feature branch with that name.
- B records the branch in the state file and the folder in
  `artifacts.spec`, and a resume uses the record. A `--branch` or
  `--spec-dir` on a resume that differs from the record is never applied
  silently — say that the record stands, and name both.

## Commit trailers

A trailer is one `<token>: <value>` line at the end of a commit
message, such as `Task: <id>` or `Reviewed-by: <name>`. The
`commitTrailers` key lists the trailers every commit the run makes
carries. Set it once in the repository's `.delivery-kit.json` for a
team's fixed trailers. The `--trailer <token: value>` flag adds one
trailer for one run, and can be repeated. **The flag adds to the key
and never replaces it**: the list is the key's trailers, then the
flags', in order. Between configuration files the key behaves as every
key does: a later file's list replaces an earlier one's. Pre-flight
prints each trailer and the layer that set it, and stops on a bad one,
naming it: no `:`, a token with characters outside letters, digits and
dash, an empty value, a line break, or the token `Piece`, `Late` or
`Tasks` in any letter case, which the run uses as its own markers. Every
commit the run makes carries the list, the spec commit included, and
the same trailer is never added twice. The list is read on a fresh run
only. A resume keeps the list the run recorded, and a different list on
a resume is reported, never applied silently.

What the run does with trailers:

- On a fresh run it passes `--trailer <text>` to `preflight.sh` once per
  trailer: the key's first, then the flags', in order.
- The probe block prints a `Trailers` line only when `commitTrailers` is
  not empty. It names each trailer's layer: the configuration file by
  path, or `--trailer`.
- It records the list pre-flight reports with `progress.sh state-set
  <feature> config commitTrailers '<json array>'`, and each entry's layer,
  in the same order, as `config.commitTrailersFrom`. This record replaces
  the key's own list in `config`: it holds the key's trailers and the
  flags', never the key's alone.
- The commit subcommands add the list themselves: `spec-commit`,
  `piece-commit`, `late-commit` (J's `--record` included) and
  `remainder-commit`. They read it from the state file as data. The run
  never adds a trailer by hand. A message shown at a gate before its
  commit does not show the trailers; the commit carries them. A trailer
  joins the `Tasks:`, `Piece:` or `Late:` lines when the message ends
  with them, so each stays a whole line.
- Commits an external implementer makes on the handoff path are its own,
  and are not touched.
- On a resume, pre-flight gets no `--trailer`, so print the Trailers
  line from the recorded list, each entry with its recorded layer. A
  different list on a resume is never applied silently — say that the
  record stands, and name both.

## The implementer key

`implementer` answers the first of the implementer gate's two questions
in advance — the choice between implementing here and writing a
handoff package for a cheaper model. Unset means the gate asks it. With
`claude`, the gate records the typed answer and goes on to its second
question, commits or pauses — how you want to review the build. No key
or flag answers that question in advance, and `--auto` does not collapse
it, so a fresh `claude` run always stops there. With `handoff`, the gate
stops asking and the run parks at the implement phase with the package
written, waiting for the external implementer's report. With `ask` the
gate simply asks, as it does when the key is unset — the difference is
that `ask` can be written in a later layer to take back a stop an
earlier one gave away. An illegal value stops pre-flight by name: never
coerced, never treated as unset.

Layers merge by silence, not by erasure, and that holds for every key on
this page: writing `null` in a later layer leaves the earlier layer's
value standing, exactly as leaving the key out would. `implementer` is
the one key with a value that overrides the other way. For
`verifyCommand`, `releaseCommand` and `devCommand` there is no such
value, so a command an earlier layer set can be replaced by a later one
but never returned to unset. If a repository's tracked
`.delivery-kit.json` answers the implementer question and you want that
question back for one run, pass `--implementer ask`; if you want it back
for good, write `"implementer": "ask"` in the layer that should win.

What stops a run is a range, and both ends of it are worth knowing. No
fresh run reaches the end without a stop: a `claude` run stops at the
implementer gate for the review question, and a `handoff` run parks at
the implement phase. Above that floor, the clarify gate stops whenever
the spec tool has a question, the release gate whenever `releaseCommand`
is set and `--auto-release` was not also typed, and the pre-flight
constitution offer whenever the constitution is unset. Without `--auto`
the commit and push gates stop as they always do — or fewer of them,
where pre-flight has already named a degradation: a repository with no
remote stops after the commit gate and never reaches a push gate at all.
Below the floor sits a re-entry: a run resumed or re-entered past the
implementer gate asks nothing there, and the clarify gate and the
constitution offer are already behind it, so with `--auto` and
`releaseCommand` unset it can reach the end without any gate asking. Cap
breaches, a missing required tool, hard failures, a failed runtime
check, a state file tracked in git, a pause, and the commit and push
phases' own stops — a path outside the feature once the branch holds
commits, a commit they cannot show, a record of a commit that is not on
the branch — still stop a run, whatever `--auto` collapsed. Set this key
knowing the whole range.

Pre-flight discloses the resolved key: where it holds a value, the probe
block prints an `Implementer` line naming the value and the layer it
came from, and where it is unset that line is omitted. A key that
answers a gate's question in advance belongs in the operator's output,
not only in a file.

## The state directory

Everything the pipeline writes lives under `.delivery-kit/` — one run
directory per feature, plus a lock file. On the first run in a
repository, pre-flight checks whether `.delivery-kit/` is ignored and,
if not, offers to append the one line to `.gitignore`, showing exactly
what it will write. Declining is fine; the files show up as untracked.
The pipeline never edits `.gitignore` silently, and stages only paths it
names, in every commit it makes.

## The spec tool

The pipeline drives [spec-kit](https://github.com/github/spec-kit); it
does not replace it, and it stops with setup instructions when
`.specify/` is absent. Tested against 0.15.x through 0.16.x; other
versions warn and continue, because untested is not known-broken.

Pre-flight also probes the project constitution. When the file is
absent or still the unfilled template, the probe block says so and the
run offers — once — to run the spec-kit constitution command. That is
the second and larger of pre-flight's two offered writes: accepting
writes the constitution file — rewriting it where it exists, creating
it as an untracked file where it does not. The principles are the owner's
to write; declining is fine, and the offer is not repeated within the
run.

Accepting has a consequence past the write. The commit phase stages
that constitution as its own separate commit, named like every other
path and never riding inside the feature's commits — and wherever the run
goes on to push, that commit travels with the branch, and into the pull
request wherever the run opens one. How far it travels depends on the
run: the commit and push gates can be declined; a repository with no
remote stops after the commit gate by design; and a remote this tooling
cannot open a pull request against gets the branch and a comparison link
instead. What the offer settles is narrower than any of that — a
governance file this run writes is a file the run puts in front of you
at the commit gate, by name. Accept the offer knowing that, or decline
and write the principles yourself.

When scripting an initialisation, pin the version —
`uv tool install "specify-cli==<version>"` — and note that
`--non-interactive` exists only from 0.16.x: a 0.15.x scripted init
needs an explicit `--script sh|ps` or the interactive picker fires.
