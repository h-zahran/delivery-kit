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

## Quick start

**1. Check the tools.** On Windows, run these in Git Bash, not PowerShell
([why](#windows)).

```bash
jq --version     # both plugins
git --version    # pipeline needs it; handoff uses it if present
```

If `jq` prints nothing, the install commands are in
[handoff/docs/install.md](handoff/docs/install.md). For `pipeline`, the target
repository also needs [spec-kit](https://github.com/github/spec-kit). Run these
yourself, the second one from the target repository's root (the first needs
[uv](https://docs.astral.sh/uv/)):

```
uv tool install specify-cli
specify init --here --integration claude
```

**2. Add the marketplace and install what you want.**

```
/plugin marketplace add h-zahran/delivery-kit
/plugin install handoff@delivery-kit
/plugin install pipeline@delivery-kit
```

If an install command cannot see its plugin, run `/reload-plugins` after the
marketplace add and try again.

**3. With handoff: tell the guard your real context window.** Do this first.

```
handoff:setup
```

The guard assumes a 200,000-token window. Set too small, it fires early, and
you see it at once. Set too large, it **never fires at all**, and you find out
when a session dies mid-task. `handoff:setup` measures your session and writes
the answer to `~/.delivery-kit.json`, once per machine.

**4. With pipeline: give it a seed.**

```
/pipeline add a CSV export to the report page
```

A seed can also be a heading from your plan file (`Phase 9: Claim Pack`) or a
GitHub issue (`#123`). The [pipeline page](pipeline/README.md) covers the
twenty phases, the five gates, and the flags.

## What each plugin does

**[handoff](handoff/README.md)** watches how full the context window is after
every tool call. Past a threshold it interrupts, and `handoff:handoff` writes
one document: branch, commit, what is done, what is next, what is uncommitted,
what will bite you. It prints the exact prompt for a fresh session, which then
resumes from **one file read** and first checks that the branch, the commit and
the changed files still match. It never touches git: no commit, no push, no
stash.

**[pipeline](pipeline/README.md)** drives one feature through twenty phases,
from specification to release, and stops at five gates: **clarify**, **who
implements and how you review**, **commit**, **push and open the PR**, and
**release**. Each gate shows you the exact content before anything happens.
Some things never happen at all: no force-push, no history rewrites, no
`git add -A`, no skipped hooks, no branch deletion, and it never merges the
pull request it opens.

## Settings

Nothing is required. Every setting has a default, and anything the tools work
out for themselves is printed, so a wrong guess is visible rather than silent.

Both plugins read one file, `.delivery-kit.json`: in your repository root for
project facts, or at `~/.delivery-kit.json` for facts about your machine. **The
repository file wins**, and for the guard's keys an environment variable beats
both. The pipeline's keys have no environment overrides at all, by design: a
value that answers a gate's question in advance must not arrive from a shell you
did not read.

```json
{
  "contextGuard": { "windowTokens": 1000000, "thresholdPct": 45 },
  "handoff":      { "docsDir": "docs/handoffs" },
  "pipeline":     { "planFile": "main-plan.md", "testCommand": "npm test" }
}
```

A repository you clone can carry this file, and some pipeline keys answer a
question for you. Pre-flight prints an `Implementer` line naming which file or
flag the `implementer` value came from. `baseBranchOverride` and
`commitTrailers` can arrive the same way: pre-flight names the file each came
from, on its `Base branch` and `Trailers` lines.

Every key: [handoff](handoff/docs/configuration.md) ·
[pipeline](pipeline/docs/configuration.md).

## Windows

Claude Code runs both plugins' hooks and scripts in **Git Bash**, so Git for
Windows is required, and Git Bash is where a tool must be visible.

| What you see | Why | What to do |
|---|---|---|
| `jq --version` works in PowerShell, but the guard says `jq` is missing | PowerShell and Git Bash can see different programs | Check from Git Bash. Install with `winget install jqlang.jq`, then open a new Git Bash and the session again. |
| `gh` works in PowerShell, but Git Bash says `gh: command not found` | Some package managers, Scoop among them, install `gh` as `gh.cmd` only | Nothing, for `pipeline`: pre-flight looks for `gh`, `gh.exe` and `gh.cmd`, and uses the one it finds. In your own Git Bash, type `gh.cmd`. |
| You cannot find `~/.delivery-kit.json` | `~` is Git Bash's home folder | It is in your Windows user folder: `%USERPROFILE%\.delivery-kit.json`. |

Each plugin's own troubleshooting table: [handoff](handoff/README.md#troubleshooting)
· [pipeline](pipeline/README.md#troubleshooting).

## What is in this repository

```
handoff/     the handoff plugin — hooks, skills, scripts, docs, tests
pipeline/    the pipeline plugin — command, skills, scripts, docs, tests
tests/       repo-wide tests: layout, and what may appear in shipped files
specs/       the specifications real pipeline runs produced, kept as examples
main-plan.md the plan file this repository reads its own seeds from
```

This repository builds itself with its own pipeline. The directories under
`specs/` are the output of real runs — open one to see what a finished phase
actually leaves behind, including the clarifying questions a human answered.

Upgrading from the 1.x plugin called `delivery-kit`? Uninstall it **first**:
see [handoff/README.md](handoff/README.md#upgrading-from-delivery-kitdelivery-kit).

## Contributing

Tests are [bats](https://github.com/bats-core/bats-core) and need `jq`. Name
every suite path: passing only `tests` silently skips both plugins' suites and
still reports green.

```bash
git clone --depth 1 --branch v1.11.0 https://github.com/bats-core/bats-core.git "$HOME/bats"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
```

Expect green on Linux, macOS and Windows under Git Bash. CI runs all three.
More in [CONTRIBUTING.md](CONTRIBUTING.md). Please also read the
[Code of Conduct](CODE_OF_CONDUCT.md). Each plugin keeps its own changelog —
see [CHANGELOG.md](CHANGELOG.md).

## Licence

MIT. See [LICENSE](LICENSE).
