# pipeline

Drives one unit of work from an idea to a verified build: specification, plan,
tasks, implementation, review and release — stopping to ask you at every step
that leaves your machine or cannot be undone by editing a file.

## How you start it

Type the command. It never starts on its own. Typed bare, `/pipeline` resolves
to the same command:

```
/pipeline Phase 9: Claim Pack                    # a heading in your plan file
/pipeline #123                                   # a GitHub issue
/pipeline add a CSV export to the report page    # just describe it
```

The seed is read three ways, in that order: text shaped like
`Phase <N>: <title>` is pulled out of your plan file; `#` plus digits fetches
that GitHub issue; anything else is the feature description, verbatim.

## What happens next

Twenty phases, from specification to release:

```
preflight → A  B  C* C.5 D  E  F  F.5 G* H  H.5 H.7 I  J  K* L* M  N  N.5 O* → DONE
            └── specify & plan ──┘ └─ build ─┘ └ review ┘ └── ship ──┘

* = stops and asks you first
```

| | Phases | What happens |
|---|---|---|
| **Specify & plan** | A – F.5 | The seed becomes a specification, you answer the clarifying questions, then a plan, a task list, an analysis pass, and a recorded test baseline. |
| **Build** | G – H.7 | You choose who implements. Independent tasks run in parallel, then a convergence pass and a simplify pass. |
| **Review** | I – J | Three independent reviewers — contract compliance, security, tests — then the analyzer and the full suite, classified against the baseline. |
| **Ship** | K – O | Commit, push, open the pull request, act on its review, re-verify, prove it actually runs, release. |

`pipeline:status` reads a run's state file and reports where it got to, which
gate it is waiting on, and the exact next thing to type.

## What ships

The orchestrator is the thing you invoke. The rest run inside a phase, and two
of them you can also invoke directly when you want that one job without a run.

| Piece | Kind | Does |
|---|---|---|
| `/pipeline` | a command | Starts a run. The only entry — the orchestrator never invokes itself. |
| `pipeline:status` | a skill | Read-only. Where a run got to, which gate it waits on, what to type next. |
| `pipeline:spec-review` | a skill | Audits an implementation against its specification with three independent lenses: contract compliance, security, and tests. Runs at the deep-review phase, and stands alone when a feature claims to be done and you want to know whether the spec agrees. |
| `pipeline:device-verify` | a skill | Builds, installs and drives a mobile release build on one attached device, screenshots what changed, and reads the screenshots back. Runs at the runtime check on an Android project, and stands alone when a change claims to work on a device and nobody has watched it do so. |

[The phase reference](docs/phases.md) names every phase these run in.

## The five gates

A gate shows you the content and waits. These are the only places it asks:

| Gate | Phase | You see | Skippable by |
|---|---|---|---|
| Clarify | C | Every question, one at a time | nothing — only you know the answers |
| Implementer | G | Build it here, or write a package for a cheaper model | the `implementer` setting |
| Commit | K | The exact file list and the exact commit message | `--auto` |
| Push & PR | L | Branch name, PR title, the full body | `--auto` |
| Release | O | The exact command, and where it publishes | `--auto-release` only |

`--auto` collapses only the commit and push gates. Publishing is the least
reversible thing this tool does, so it needs its own flag, typed on purpose —
one flag must not mean both "commit for me" and "publish for me".

Other things still stop a run and no flag collapses them: a loop hitting its
cap, a required tool missing, any hard failure, and a failed runtime check.

> **Worth knowing before you automate.** With `implementer` set in a config
> file, `--auto`, no clarify questions and no release command, a run can reach
> the end without a single gate stopping it. That is why pre-flight prints an
> `Implementer` line naming which file or flag the value came from. Set
> `implementer` to `ask` to take the stop back.

## What it never does

No force-push. No history rewrites. No skipped hooks. No `git add -A` or
wildcard staging — the commit gate names every path. No branch deletion. And it
never merges the pull request it opens: it opens one and stops.

A failed phase rolls nothing back. The working tree is the evidence, and
cleanup is your call.

## Other flags

| Flag | Effect |
|---|---|
| `--resume` | Re-enter a live run at the phase it recorded. |
| `--until <phase>` | Stop cleanly after that phase — state intact, lock released, resumable. |
| `--from <phase>` | Re-enter earlier. Refused unless the artefact that phase consumes exists. |
| `--dry-run` | Run the spec phases for real, then print what the rest would do and stop. |
| `--implementer <claude\|handoff\|ask>` | Pre-answer the implementer gate, or restore it. |
| `--config <path>` | Merge a JSON file over the resolved settings. |

## Requirements

- [spec-kit](https://github.com/github/spec-kit) initialised in the target
  repository. The pipeline drives it; it does not replace it, and it stops with
  instructions when it is absent. Tested against 0.15.x through 0.16.x; other
  versions warn and continue.
- `jq`, on every platform.
- `git`, on every platform. Unlike the optional tools below, an absent `git`
  does not degrade a phase — it stops the run at pre-flight, because branching,
  committing and opening a pull request are all git operations and pre-flight's
  own branch and working-tree reads are git commands. Pre-flight names it and
  points at the download page; nothing is installed for you.
- Optional, each degrading a *named* phase when absent, announced before any
  work starts: `gh` for the pull-request phases; a browser or an attached
  device for the runtime check; the code-review and simplify plugins for their
  phases.

## Configure

Nothing is required. Every setting has a default or a detection path, and
everything detected is printed at pre-flight, so a wrong guess is visible rather
than silent.

Settings go in a `pipeline` block in `.delivery-kit.json`:

```json
{
  "pipeline": {
    "planFile": "main-plan.md",
    "testCommand": "npm test",
    "analyzeCommand": "npm run lint"
  }
}
```

The full key reference is [docs/configuration.md](docs/configuration.md).

Everything the pipeline writes lives under `.delivery-kit/` — one directory per
run, plus a lock file. On the first run it offers to add that one line to your
`.gitignore`, showing exactly what it will write. Declining is fine.

## Install

```
/plugin marketplace add h-zahran/delivery-kit
/plugin install pipeline@delivery-kit
```

Pairs well with [handoff](../handoff/README.md): if the context guard fires
while a run is parked at a gate, the handoff document records the phase and the
resume command alongside everything else.

## Known limits

Runtime verification on mobile is Android-only in this version. Detection runs
at the repository root, so a monorepo resolves as one project. Only the Claude
Code harness is supported. The pipeline opens a pull request; it never merges
one.

## Licence

MIT. See [LICENSE](../LICENSE).
