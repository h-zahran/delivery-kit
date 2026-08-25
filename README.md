# delivery-kit

A Claude Code plugin marketplace. Two plugins live here. Each installs on its
own, and neither needs the other.

Both came out of the same exercise: 1,410 prompts across 67 sessions of real
work were sorted by what the human was actually asking for. The two biggest
piles were *"continue"* and *"now commit, push, open a PR, check it ran"*. Each
pile became a plugin.

## Which one do I want?

| Plugin | Install as | Use it when |
|---|---|---|
| **[handoff](handoff/README.md)** | `handoff@delivery-kit` | Long sessions run out of room, and you keep typing *continue*. |
| **[pipeline](pipeline/README.md)** | `pipeline@delivery-kit` | You want one feature taken from an idea to a reviewed pull request, stopping to ask you at every step that leaves your machine. |

Install both if you want both. They share one settings file and otherwise stay
out of each other's way.

## handoff — stop before the wall, not at it

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

Three pieces ship: the guard (a hook), `handoff:handoff` (writes the document),
and `handoff:setup` (asks for your real context window, once per machine).

## pipeline — one feature, twenty phases, five stops

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

A run can stop cleanly at any phase and resume later. `pipeline:status` tells
you where it got to and what to type next.

## Install

```
/plugin marketplace add h-zahran/delivery-kit
/plugin install handoff@delivery-kit
/plugin install pipeline@delivery-kit
```

If an install command cannot see its plugin, run `/reload-plugins` after the
marketplace add.

**Coming from 1.x?** This was one plugin called `delivery-kit` until 2.0.0. Run
`/plugin uninstall delivery-kit@delivery-kit` **first** — two installed copies
register the same hook and race for one flag. Why, and what to check instead of
the warning count, is in
[handoff/README.md](handoff/README.md#upgrading-from-delivery-kitdelivery-kit).

## What you need

| | `handoff` | `pipeline` |
|---|---|---|
| Claude Code | required | required |
| `jq` on PATH | required | required |
| A spec tool in the repository | — | required ([spec-kit](https://github.com/github/spec-kit)) |
| `gh`, a browser, an attached device | — | optional; each one's absence skips a named phase and says so |

## Configure

Nothing is required. Every setting has a default, and anything the tools work
out for themselves is printed, so a wrong guess is visible rather than silent.

When you do want to set something, it goes in one file called
`.delivery-kit.json` — in your repository root for project facts, or at
`~/.delivery-kit.json` for facts about your machine. The repository file wins.

```json
{
  "contextGuard": { "windowTokens": 1000000, "thresholdPct": 45 },
  "handoff":      { "docsDir": "docs/handoffs" },
  "pipeline":     { "planFile": "main-plan.md" }
}
```

**The one setting worth getting right** is `contextGuard.windowTokens`. It
defaults to 200,000. If your model has a bigger window, say so — otherwise the
guard fires far too early. Run `handoff:setup` and it will measure your session
and write the file for you.

Full key reference: [handoff](handoff/docs/configuration.md) ·
[pipeline](pipeline/docs/configuration.md).

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
actually leaves behind.

## Contributing

Tests are [bats](https://github.com/bats-core/bats-core) and need `jq`. Name
every suite path: passing only `tests` silently skips both plugins' suites and
still reports green.

```bash
git clone --depth 1 --branch v1.11.0 https://github.com/bats-core/bats-core.git "$HOME/bats"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
```

More in [CONTRIBUTING.md](CONTRIBUTING.md). Please also read the
[Code of Conduct](CODE_OF_CONDUCT.md).

Each plugin keeps its own changelog — see [CHANGELOG.md](CHANGELOG.md).

## Licence

MIT. See [LICENSE](LICENSE).
