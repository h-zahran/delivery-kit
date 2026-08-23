# pipeline

Drives a unit of work from a heading in a plan file to a verified build:
specification, plan, tasks, implementation, review and release, with a
human gate at every step that leaves the machine or cannot be undone by
editing a file.

## How it runs

Type the command; it never starts on its own — typed bare, the short
form `/pipeline` resolves to the same command:

```
/pipeline:pipeline Phase 9: Claim Pack
/pipeline:pipeline #123
/pipeline:pipeline add a CSV export to the report page
```

The seed is read three ways: a `Phase <N>: <title>` heading is read out
of your plan file; `#` plus digits fetches that GitHub issue; anything
else is the feature description, verbatim.

Twenty phases run from specification to release. Up to five of them
stop and ask — clarification, implementer choice, commit, push and
pull request, release — and everything that leaves the machine sits
behind one of those gates. `--auto` collapses the commit and push
gates; the release gate needs `--auto-release`, typed on purpose; and
the `implementer` key, or `--implementer`, pre-answers the implementer
choice so that gate does not stop either — `ask` puts the stop back. A
run can stop cleanly at any phase (`--until <phase>`) and resume later
(`--resume`).

`pipeline:status` reads a run's state file and reports the phase board,
the gate the run is waiting on, and the exact next action.

## What it never does

No force-push, no history rewrites, no hook skipping, no wildcard
staging, no branch deletion — and it never merges the pull request it
opens. A failed phase rolls nothing back: the working tree is the
evidence, and cleanup is the owner's call.

## Requirements

- [spec-kit](https://github.com/github/spec-kit) initialised in the
  target repository. The pipeline drives spec-kit; it does not replace
  it, and it stops with instructions when spec-kit is absent. Tested
  against 0.15.x through 0.16.x; other versions warn and continue.
- `jq`, on every platform.
- Optional, each degrading a named phase when absent: `gh` for the
  pull-request phases; a browser or an attached device for the runtime
  check; the code-review and simplify plugins for their phases.

## Configure

Nothing is required — every setting has a default or a detection path,
and everything detected is printed so a wrong guess is visible. The full
key reference is [docs/configuration.md](docs/configuration.md).

## Install

```
/plugin marketplace add h-zahran/delivery-kit
/plugin install pipeline@delivery-kit
```

## Known limits

Runtime verification on mobile is Android-only in this version.
Detection runs at the repository root, so a monorepo resolves as one
project. Only the Claude Code harness is supported.

## Licence

MIT. See [LICENSE](../LICENSE).
