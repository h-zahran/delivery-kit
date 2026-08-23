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
    "devCommand": null
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

## Base branch

The resolution order is: the remote's default branch (`origin/HEAD`),
then this key, then the current branch when there is no remote. The
pre-flight report names which source won. Note the consequence plainly:
**in a repository whose remote publishes a default branch, that default
wins over this key.** Set the key for repositories without a remote
default; everywhere else it is documentation of intent, not an override.

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

When scripting an initialisation, pin the version —
`uv tool install "specify-cli==<version>"` — and note that
`--non-interactive` exists only from 0.16.x: a 0.15.x scripted init
needs an explicit `--script sh|ps` or the interactive picker fires.
