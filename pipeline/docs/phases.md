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
| pre-flight | probe and decide | Reports the project type, the spec tool, the constitution, the base branch, the implementer setting and its source, the remote, and what it will skip. Stops if the spec tool is missing, if the tree is dirty with work no run claims, or if `implementer` holds a value that is not `claude`, `handoff` or `ask`. |
| A | extract the seed | Turns your argument into a feature description — a section of the plan file, a GitHub issue, or the text verbatim. |
| B | specify | Runs the spec-kit specify command. The spec tool names the feature; the state file and the feature branch are created here. |
| **C** | clarify | **Stops and asks.** One question at a time, until the tool has none left or the pass cap is reached. Only you know these answers, so no flag collapses this. |
| C.5 | spec quality gate | Audits the spec itself: every requirement testable, none contradicting another, every term defined, nothing from the seed silently dropped. |
| D | plan | Runs the spec-kit plan command, and checks the plan against the constitution. |
| E | tasks | Runs the spec-kit tasks command, then audits each task for a named file, independent verifiability, and ordering. |
| F | analyze | Runs the spec-kit analyze command and fixes what it finds, in a capped loop. |
| F.5 | test baseline | Runs the test command and records the result verbatim. Failures that exist *before* the feature are not the feature's, and phase J classifies against this record. |
| **G** | implementer | **Stops and asks**, unless `implementer` already answered it. Build here, or write a package for a cheaper model. Choosing the package parks the run and hands you a brief. |
| H | implement | Runs the spec-kit implement command. Independent tasks in the same group run in parallel; two agents never edit one file. |
| H.5 | converge | Re-reads the tree against the spec and appends whatever is still missing as new tasks. Skipped, and said so, where the spec tool does not ship it. |
| H.7 | simplify | Runs the simplify skill over the configured code roots. Skipped, and said so, when there is no code to simplify. |
| I | deep review | Three reviewers at once — contract compliance, security, tests. Fixes fan out. |
| J | analyzer and full suite | Runs both commands and classifies every failure against the F.5 baseline. Pre-existing failures are reported, not owned. A failure waved through at a cap is recorded and carried into the commit and the pull request. |
| **K** | commit | **Stops and asks.** Shows the exact file list — every path named, never a wildcard — and the exact message. Collapsed by `--auto`. |
| **L** | push and pull request | **Stops and asks.** Shows the branch, the title and the whole body before anything leaves your machine. Collapsed by `--auto`. Degrades where there is no remote, or no GitHub. |
| M | pull request review | Runs the review skill against the pull request and fixes what it raises, in a capped loop. Skipped, and said so, when there is no pull request to review. |
| N | re-verify | Runs the analyzer and the suite again, classifies, commits fixes, pushes. **Degraded, never skipped** — the last thing a run does with code must not be "change it and not check it". |
| N.5 | runtime check | Proves the change actually runs: a browser for a web project, a device for Android, otherwise the configured verify command. Reports honestly when no strategy applies rather than inventing one. |
| **O** | release | **Stops and asks.** Shows the exact release command and where it publishes. `--auto` does *not* collapse this; `--auto-release` does, typed on purpose. Records and moves on when no release command is set. |
| DONE | | Releases the lock and summarises what shipped, what was skipped and why, and where the artefacts are. |

Phases in bold are the gates. A gate with nothing to ask records that and moves
on — no clarify questions, an `implementer` already set, no release command.

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

## Using them with the flags

`--until <phase>` stops cleanly after that phase, with the state file intact and
the lock released, and the run is resumable. `--from <phase>` re-enters at one,
and is validated against which artefacts actually exist — re-entering a phase
without the thing it consumes re-runs work that has nothing to work on.

Both take the names in the first column exactly as written, fractional ones
included.
