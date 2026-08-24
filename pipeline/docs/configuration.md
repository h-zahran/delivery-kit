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

## Keys

```json
{
  "pipeline": {
    "planFile": "main-plan.md",
    "testCommand": null,
    "analyzeCommand": null,
    "codeRoots": null,
    "baseBranch": null,
    "projectType": null,
    "commitStyle": "conventional",
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
| `codeRoots` | Where implementation lives; the simplify phase's scope. |
| `baseBranch` | See "Base branch" below. |
| `projectType` | Overrides detection; the detector's source is reported either way. |
| `commitStyle` | The commit-message shape the commit gate shows. |
| `maxClarifyPasses` | Clarification loop cap; a breach stops and asks. |
| `maxAnalyzeIters` | Analysis auto-fix loop cap; a breach stops and asks. |
| `maxReviewRounds` | Pull-request review loop cap; a breach stops and asks. |
| `maxParallelAgents` | Fan-out cap for dispatched agents, every phase. |
| `agentModel` | The model dispatched agents run on. |
| `verifyCommand` | The runtime check's fallback strategy; it must produce an artefact. |
| `releaseCommand` | What the release gate runs, shown exactly before it runs. Unset means there is nothing to publish — the release gate records that and moves on; no command is ever detected or invented for this key. |
| `devCommand` | The web runtime check's server command; without it the project manifest's script table is tried: `dev`, then `start`, then `serve`. |
| `implementer` | Pre-answers the implementer gate: `claude` or `handoff`; `ask` restores the stop; unset means ask. |
| `maxVerifyIters` | Verification fix-loop cap; a breach stops and asks, and a breach waved through is recorded in the commit message and the pull request. |

## Base branch

The resolution order is: the remote's default branch (`origin/HEAD`),
then this key, then the current branch when there is no remote. The
pre-flight report names which source won. Note the consequence plainly:
**in a repository whose remote publishes a default branch, that default
wins over this key.** Set the key for repositories without a remote
default; everywhere else it is documentation of intent, not an override.

## The implementer key

`implementer` pre-answers the implementer gate — the choice between
implementing here and writing a handoff package for a cheaper model.
Unset means the gate asks. With `claude`, the gate records the typed
answer and does not stop — an `--auto` run then touches the human at
clarify only. With `handoff`, the gate stops asking and the run parks
at the implement phase with the package written, waiting for the
external implementer's report. With `ask` the gate simply asks, as it
does when the key is unset — the difference is that `ask` can be written
in a later layer to take back a stop an earlier one gave away. An
illegal value stops pre-flight by name: never coerced, never treated as
unset.

Layers merge by silence, not by erasure, and that holds for every key on
this page: writing `null` in a later layer leaves the earlier layer's
value standing, exactly as leaving the key out would. `implementer` is
the one key with a value that overrides the other way. For
`verifyCommand`, `releaseCommand` and `devCommand` there is no such
value, so a command an earlier layer set can be replaced by a later one
but never returned to unset. If a repository's tracked `.delivery-kit.json` pre-answers the
gate and you want the stop back for one run, pass `--implementer ask`;
if you want it back for good, write `"implementer": "ask"` in the layer
that should win.

Read "at clarify only" as neither a floor nor a ceiling — it is one
point on a range, and both ends of that range are worth knowing. Above
it, two things still stop a run: the release gate, whenever
`releaseCommand` is set and `--auto-release` was not also typed, and the
pre-flight constitution offer, whenever the constitution is unset. Below
it, everything can fall away at once: with `--auto`, no clarify
questions, `releaseCommand` unset, the constitution already set and a
remote to push to, such a run reaches the end with no gate stopping it
at all. Cap breaches, a missing required tool, hard failures and a failed
runtime check still stop it, but the gates do not. Without `--auto` the
commit and push gates stop as they always do — or fewer of them, where
pre-flight has already named a degradation: a repository with no remote
stops after the commit gate and never reaches a push gate at all. Set
this key knowing the whole range.

Pre-flight discloses the resolved key: where it holds a value, the probe
block prints an `Implementer` line naming the value and the layer it
came from, and where it is unset that line is omitted. A key that
pre-answers a gate belongs in the operator's output, not only in a file.

## The state directory

Everything the pipeline writes lives under `.delivery-kit/` — one run
directory per feature, plus a lock file. On the first run in a
repository, pre-flight checks whether `.delivery-kit/` is ignored and,
if not, offers to append the one line to `.gitignore`, showing exactly
what it will write. Declining is fine; the files show up as untracked.
The pipeline never edits `.gitignore` silently, and never stages
anything outside the commit gate.

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
path and never riding inside the feature's commit — and wherever the run
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
