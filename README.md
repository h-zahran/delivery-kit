# delivery-kit

A Claude Code plugin marketplace. Two plugins live here. Each installs on its
own, and neither needs the other.

Both came out of the same exercise: 1,410 prompts across 67 sessions of real
work were sorted by what the human was actually asking for. The two biggest
piles were *"continue"* and *"now commit, push, open a PR, check it ran"*. Each
pile became a plugin.

## Contents

- [Which one do I want?](#which-one-do-i-want)
- [What each plugin does](#what-each-plugin-does) — [handoff](#handoff--stop-before-the-wall-not-at-it) · [pipeline](#pipeline--one-feature-twenty-phases-five-stops)
- **Guide** — [Before you start](#before-you-start) · [Your first ten minutes](#your-first-ten-minutes) · [Using handoff](#using-handoff-start-to-finish) · [Using pipeline](#using-pipeline-gate-by-gate)
- [Command reference](#command-reference)
- [Configure](#configure)
- [Troubleshooting](#troubleshooting)
- [What is in this repository](#what-is-in-this-repository) · [Contributing](#contributing) · [Licence](#licence)

## Which one do I want?

| Plugin | Install as | Use it when |
|---|---|---|
| **[handoff](handoff/README.md)** | `handoff@delivery-kit` | Long sessions run out of room, and you keep typing *continue*. |
| **[pipeline](pipeline/README.md)** | `pipeline@delivery-kit` | You want one feature taken from an idea to a reviewed pull request, stopping to ask you at every step that leaves your machine. |

Install both if you want both. They share one settings file and otherwise stay
out of each other's way.

## What each plugin does

### handoff — stop before the wall, not at it

A session that runs out of context does not stop at a clean boundary. It stops
wherever it happened to be: uncommitted edits, a test run nobody wrote down, and
a decision whose reason now exists only in a transcript nobody will re-read.

So `handoff` watches. After every tool call it works out how full the context
window is, and once you cross a line it interrupts with this:

```
CONTEXT GUARD: session context is at 45% of the 200000-token window (threshold 45%).
Finish ONLY the current atomic step — do NOT start the next batch or task.
Then invoke the handoff skill (handoff:handoff) ...
```

Run `handoff:handoff` and you get a written document — branch, SHA, what is
done, what is next, what is uncommitted, what will bite you — plus the exact
prompt to paste into a fresh session. The next session gets back up to speed
from **one file read**.

It never touches git. No commit, no push, no stash. It records the uncommitted
work and prints the commands, and the choice stays yours.

### pipeline — one feature, twenty phases, five stops

Give it a seed — a heading from your plan file, a GitHub issue number, or just a
sentence — and it drives the whole job:

```
/pipeline add a CSV export to the report page
```

Twenty phases run from specification to release:

```
preflight → A  B  C* C.5 D  E  F  F.5 G* H  H.5 H.7 I  J  K* L* M  N  N.5 O* → DONE
            └ specify & plan ┘ └ build ┘ └ review ┘ └ ship ┘

* = stops and asks you first
```

The five stars are the gates: **clarify** (only you know the answer), **who
implements**, **commit**, **push and open the PR**, and **release**. Each one
shows you the exact content before anything happens.

Everything that leaves your machine sits behind one of those gates. And some
things never happen at all: no force-push, no history rewrites, no
`git add -A`, no skipped hooks, no branch deletion — and it never merges the
pull request it opens.

---

# Guide

## Before you start

### Claude Code

Both plugins are Claude Code plugins. Nothing else is supported.

### `jq` — required by both

`jq` is a small program that reads JSON and pulls one piece out of it. Both
plugins read JSON constantly: `handoff` reads your session transcript to count
tokens, and `pipeline` reads its own state files and your project's manifests.

Check whether you already have it:

```bash
jq --version
```

If that prints a version, you are done. If it prints nothing, install it — the
per-platform commands are in
[handoff/docs/install.md](handoff/docs/install.md). **On Windows, run that check
inside Git Bash**, not PowerShell: Git Bash is the shell the hook actually runs
in, and a `jq` that PowerShell can see is not necessarily one the hook can.

Without `jq` the context guard cannot run. It says so once and then stays quiet,
rather than pretending to work.

### A spec tool — required by `pipeline` only

`pipeline` drives [spec-kit](https://github.com/github/spec-kit); it does not
replace it. The target repository needs spec-kit initialised, or the run stops
at pre-flight and prints the two setup commands. Tested against 0.15.x through
0.16.x; other versions warn and continue.

`handoff` has no such dependency. Someone who wants only a context guard never
acquires a spec-tool dependency.

### Optional, and each one's absence is announced

| Tool | Without it |
|---|---|
| `gh` | The pull-request phases degrade: the run pushes and prints a comparison link instead. |
| A browser, or an attached device | The runtime check falls back or is skipped, and says which. |
| The code-review and simplify plugins | Their phases skip, and say so. |
| `git` | Only used to find your settings file from a subdirectory. Without it, defaults apply. |

Nothing here fails silently. Every missing capability is named at pre-flight,
before any work starts.

## Your first ten minutes

**1. Add the marketplace and install what you want.**

```
/plugin marketplace add h-zahran/delivery-kit
/plugin install handoff@delivery-kit
/plugin install pipeline@delivery-kit
```

If an install command cannot see its plugin, run `/reload-plugins` after the
marketplace add and try again.

**2. Tell the guard your real context window. Do this first.**

```
handoff:setup
```

This is the single most important step, and skipping it is the one mistake that
costs you a session. The guard assumes a 200,000-token window by default, and
the two ways of being wrong are not the same:

- **Window set too small** — the guard fires early. Annoying, and instantly
  visible: the warning names the window it used.
- **Window set too large** — the guard **never fires at all**. Silent, total,
  and discovered when a session dies mid-task. Nothing can detect it.

`handoff:setup` measures the context your session has actually accumulated,
proposes a window when the measurement supports one, asks where you want the
guard to stop, and writes the answer to `~/.delivery-kit.json` — once per
machine, not once per repository.

If you are ever unsure between two window sizes, **take the smaller one**.
Guessing high is the answer that fails quietly.

**3. Check it fires.** The guard is deliberately silent until it has something to
say, so lower the threshold on purpose for one check. Full steps are in
[handoff/docs/install.md](handoff/docs/install.md).

**4. If you installed `pipeline`, point it at a plan file.** Optional — by
default it looks for `main-plan.md`. See [Configure](#configure).

## Using handoff, start to finish

**1. Work normally.** Nothing appears until you cross the threshold.

**2. The guard interrupts.** You get the `CONTEXT GUARD` message shown above.
If you keep working past it, you are nudged again every 5% — not on every tool
call.

**3. Finish only the step you are on.** Not the batch. Not the next task. The
message is deliberate about this: the point is to stop at a boundary you chose.

**4. Run the skill.**

```
handoff:handoff
```

It writes one document to `docs/handoffs/` (configurable) with a fixed set of
sections, so the next session always knows where to look:

| Section | What it holds |
|---|---|
| Branch & SHA | Branch, last commit, PR number, CI status |
| Goal & done-condition | What the run is for, and how you know it is finished |
| State | Done, in progress (the exact next action), remaining |
| Uncommitted work | Every changed path, marked as this run's work or pre-existing |
| Verification state | Last test count, analysis baseline, CI, runtime checks |
| Blocked | Each blocked item with its specific blocker |
| Gotchas | What is not recoverable from the code or git history |
| Deployments pending | Migrations and uploads not yet applied |
| Pipeline state | Only when a pipeline run is live: the phase, and how to resume it |
| Resume protocol | Numbered steps, starting with "check these claims against real git state" |

**5. Paste what it prints.** The last thing it does is hand you this, with the
real path filled in:

```
Resume with:
Read docs/handoffs/2026-08-25-csv-export-SESSION-HANDOFF.md and continue from it.
Follow the Resume protocol.
```

Open a fresh session, paste that, and the work carries on.

**Your work is not committed, and that is deliberate.** The hook fired on its
own, so nothing here was asked for by you — a commit message would be the
machine's, not yours. The document records every changed path instead, and
prints the `git add` / `commit` / `push` commands so you can run them if you
want to. Note the corollary: `git clean`, `git checkout` and `git stash` will
discard that work, because it is still only in your working tree.

You can also invoke the skill yourself at any time. Say "hand off", or
"stop after this batch and hand off".

## Using pipeline, gate by gate

### Start a run

```
/pipeline Phase 9: Claim Pack                    # a heading in your plan file
/pipeline #123                                   # a GitHub issue
/pipeline add a CSV export to the report page    # just describe it
```

The seed is read three ways, in that order. Text shaped like
`Phase <N>: <title>` is pulled out of your plan file. `#` plus digits fetches
that GitHub issue — and if you have no GitHub remote or no `gh`, it **stops**
rather than quietly specifying a feature called "#123". Anything else is the
feature description, verbatim.

It never starts on its own. The command is the only way in.

### What you see first

Pre-flight prints what it detected before doing anything:

```
Project type : web  (detected from the project's own manifest)
spec tool    : 0.16.5 at .specify/ — in range
Constitution : set
Base branch  : main  (from origin/HEAD)
Remote       : github  (gh present)
Missing      : adb
Will skip    : N.5 — no device strategy on this project type
```

Read the `Will skip` lines. Every degradation is named here, before work starts,
rather than discovered later.

### The five gates

This is the whole of what the run asks you. Everything else runs unattended.

| Gate | Phase | You are shown | You answer |
|---|---|---|---|
| **Clarify** | C | Every question the spec tool raises, one at a time | Each one, yourself. Never skipped, never answered for you — this is the gate that needs knowledge only you have. |
| **Implementer** | G | Build it here with Claude, or write a package for a cheaper model | One or the other. Choosing the package parks the run and hands you a brief to give the other model. |
| **Commit** | K | The exact file list, every path by name, and the exact commit message | Yes, or no. It commits only what it showed you. |
| **Push & PR** | L | The branch name, the PR title, and the full body | Yes, or no. Nothing leaves your machine before this. |
| **Release** | O | The exact command, and where it publishes | Yes, or no. |

Other things stop a run too, and **no flag collapses them**: a loop hitting its
cap, a required tool missing, any hard failure, and a failed runtime check.

### Running with fewer stops

```
/pipeline <seed> --auto              # collapses the commit and push gates only
/pipeline <seed> --auto-release      # collapses release too — typed on purpose
```

`--auto` never collapses release. Publishing is the least reversible thing this
tool does, and one flag must not mean both "commit for me" and "publish for me".

> **Know the floor before you automate.** With the `implementer` setting written
> in a config file, plus `--auto`, no clarify questions and no release command, a
> run can reach the end **without a single gate stopping it**. That is why
> pre-flight prints an `Implementer` line naming which file or flag the value came
> from — a setting that gives away a stop can arrive in a repository you just
> cloned. Set `implementer` to `ask` to take the stop back.

### Stopping and resuming

```
/pipeline <seed> --until G     # run to that phase, then stop cleanly
/pipeline --resume             # pick up where it left off
pipeline:status                # where am I, what is it waiting on, what do I type
```

`--until` leaves the state file intact and releases the lock, so the run is
resumable. `pipeline:status` is read-only: it never edits anything, never takes
the lock, and never advances a phase.

If the context guard fires while a run is parked at a gate, the handoff document
records the phase and the resume command alongside everything else.

### When a phase fails

It prints the phase, the reason, and the working tree as it stands — then
**rolls nothing back**. The working tree is the evidence you need to decide what
to do, and a tool that tidies up first has destroyed it. The lock is released so
a failed run does not hold your repository, and the next invocation offers to
resume.

## Command reference

### Skills you invoke by name

| Command | Does |
|---|---|
| `handoff:setup` | Measures your session, asks for your real window and stopping point, writes them. Once per machine. |
| `handoff:handoff` | Writes the handoff document, prints the resume prompt, stops. |
| `pipeline:status` | Read-only. Where the run is, what it waits on, what to type next. |

### `/pipeline`

| Form | Meaning |
|---|---|
| `/pipeline Phase <N>: <title>` | Read that section out of your plan file. |
| `/pipeline #123` | Fetch that GitHub issue. Needs a GitHub remote and `gh`. |
| `/pipeline <any text>` | Use the text as the feature description, verbatim. |

| Flag | Effect |
|---|---|
| `--auto` | Collapse the commit and push gates. Not clarify, not implementer, not release. |
| `--auto-release` | Collapse release as well. Never implied by `--auto`. |
| `--implementer <claude\|handoff\|ask>` | Pre-answer the implementer gate, or restore it with `ask`. |
| `--until <phase>` | Stop cleanly after that phase. State intact, lock released, resumable. |
| `--from <phase>` | Re-enter earlier. Refused unless the artefact that phase consumes exists. |
| `--resume` | Re-enter a live run at the phase it recorded. |
| `--dry-run` | Run the spec phases for real, print what the rest would do, stop. |
| `--config <path>` | Merge a JSON file over the resolved settings. |

## Configure

Nothing is required. Every setting has a default, and anything the tools work
out for themselves is printed, so a wrong guess is visible rather than silent.

When you do want to set something, it goes in one file called
`.delivery-kit.json` — in your repository root for project facts, or at
`~/.delivery-kit.json` for facts about your machine. **The repository file
wins**, and for the guard's keys an environment variable beats both.

```json
{
  "contextGuard": { "windowTokens": 1000000, "thresholdPct": 45 },
  "handoff":      { "docsDir": "docs/handoffs" },
  "pipeline":     { "planFile": "main-plan.md", "testCommand": "npm test" }
}
```

The keys worth knowing on day one:

| Key | Default | Why you would set it |
|---|---|---|
| `contextGuard.windowTokens` | `200000` | Your model's real window. **Set this.** |
| `contextGuard.thresholdPct` | `45` | Where the first warning fires. Below ~30 interrupts with room to spare; above ~70 may not leave enough context to write a good handoff. |
| `contextGuard.thresholdTokens` | unset | An absolute stopping point. Setting it is what protects you from a wrong `windowTokens`. |
| `handoff.docsDir` | `docs/handoffs` | Where handoff documents go. |
| `pipeline.planFile` | `main-plan.md` | Where `Phase <N>: <title>` seeds are read from. |
| `pipeline.testCommand` | detected | Your full test suite. |
| `pipeline.implementer` | unset | Pre-answers the implementer gate. Read the warning above before setting it. |

A value that is not a positive integer is ignored and the layer beneath it
stands. **No invalid value can disable the guard.**

Full key reference: [handoff](handoff/docs/configuration.md) ·
[pipeline](pipeline/docs/configuration.md).

Everything `pipeline` writes lives under `.delivery-kit/`. On the first run it
offers to add that one line to your `.gitignore`, showing exactly what it will
write. Declining is fine.

## Troubleshooting

| What you see | Why | What to do |
|---|---|---|
| A percentage over 100, plus `WINDOW MISCONFIGURED` | `windowTokens` is smaller than your real window | Run `handoff:setup`. The note already names the minimum true window. |
| The guard never fires at all | `windowTokens` set too large — nothing can detect this | Set `contextGuard.thresholdTokens` as well. It is decided from the transcript alone, so it still fires when the window is wrong. |
| The guard is silent, and you saw a one-off note about `jq` | `jq` is missing or cannot run | Install it and restart the session. On Windows, check from Git Bash. |
| You ran `handoff:setup` and nothing changed | A repository `.delivery-kit.json`, or an environment variable, is overriding it | The skill names the winner. Change it there — it will not edit a shared repository file for you. |
| Two `CONTEXT GUARD` warnings, or advice naming a plugin you removed | An old `delivery-kit@delivery-kit` install is still present | See [Coming from 1.x](#coming-from-1x). Do not judge by warning count — run `/plugin` and read the list. |
| `pipeline` stops immediately at pre-flight | No spec tool, a dirty tree, a live lock, or an illegal `implementer` value | It names which. There is no degraded mode for a missing spec tool. |
| "The repository is locked by a live run" | Another run holds the lock and still has a state file | It prints the holder, the session and the exact `rm` — run that yourself. Only a lock whose run has no state file, or is already DONE, is taken over automatically. |
| A run reached the end without asking you anything | `--auto` plus an `implementer` value from a config file | Check the `Implementer` line in the pre-flight block: it names the layer. Use `--implementer ask` to take the stop back. |
| A phase was skipped | A capability is missing | Pre-flight named it, and the reason, before work started. Scroll back to the `Will skip` lines. |

### Coming from 1.x

This was one plugin called `delivery-kit` until 2.0.0. Run
`/plugin uninstall delivery-kit@delivery-kit` **first** — two installed copies
register the same hook and race for one flag, so the winner decides which advice
you get. Why, and what to check instead of the warning count, is in
[handoff/README.md](handoff/README.md#upgrading-from-delivery-kitdelivery-kit).

## What is in this repository

```
handoff/     the handoff plugin — hook, skills, docs, tests
pipeline/    the pipeline plugin — command, skills, scripts, docs, tests
tests/       repo-wide tests: layout, and what may appear in shipped files
specs/       the specifications real pipeline runs produced, kept as examples
main-plan.md the plan file this repository reads its own seeds from
```

This repository builds itself with its own pipeline. The directories under
`specs/` are the output of real runs — open one to see what a finished phase
actually leaves behind, including the clarifying questions a human answered.

## Contributing

Tests are [bats](https://github.com/bats-core/bats-core) and need `jq`. Name
every suite path: passing only `tests` silently skips both plugins' suites and
still reports green.

```bash
git clone --depth 1 --branch v1.11.0 https://github.com/bats-core/bats-core.git "$HOME/bats"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
```

Expect green on Linux, macOS and Windows under Git Bash. CI runs all three; a
change that passes on only one is not finished.

More in [CONTRIBUTING.md](CONTRIBUTING.md). Please also read the
[Code of Conduct](CODE_OF_CONDUCT.md).

Each plugin keeps its own changelog — see [CHANGELOG.md](CHANGELOG.md).

## Licence

MIT. See [LICENSE](LICENSE).
