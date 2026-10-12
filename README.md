# delivery-kit

A Claude Code plugin marketplace. Three plugins live here. Each installs on its
own, and none needs the others.

The first two came out of the same exercise: 1,410 prompts across 67 sessions of real
work were sorted by what the human was actually asking for. The two biggest
piles were *"continue"* and *"now commit, push, open a PR, check it ran"*. Each
pile became a plugin.

## Which one do I want?

| Plugin | Install as | Use it when |
|---|---|---|
| **[handoff](handoff/README.md)** | `handoff@delivery-kit` | Long sessions run out of room, and you keep typing *continue*. |
| **[pipeline](pipeline/README.md)** | `pipeline@delivery-kit` | You want one feature taken from an idea to a reviewed pull request, stopping to ask you at every step that leaves your machine. |
| **[mission-control](mission-control/README.md)** | `mission-control@delivery-kit` | You want to watch the main loop and every subagent at work: tools, context, cost, rate limits and files touched. |

Install any of them. handoff and pipeline share one settings file and otherwise
stay out of each other's way. mission-control needs no settings.

## Quick start

**1. Check the tools.** On Windows, run these in Git Bash, not PowerShell
([why](#windows)).

```bash
jq --version     # both plugins
git --version    # pipeline needs it; handoff's resume check needs it
```

If `jq` is not found, the install commands are in
[handoff/docs/install.md](handoff/docs/install.md). For `pipeline`, the target
repository also needs [spec-kit](https://github.com/github/spec-kit). Run these
yourself, the second one from the target repository's root (the first needs
[uv](https://docs.astral.sh/uv/)):

```
uv tool install specify-cli
specify init --here --integration claude
```

To pin a version in a script, see
[pipeline's requirements](pipeline/README.md#requirements).

**2. Add the marketplace and install what you want.**

```
/plugin marketplace add h-zahran/delivery-kit
/plugin install handoff@delivery-kit
/plugin install pipeline@delivery-kit
/plugin install mission-control@delivery-kit
```

If an install command cannot see its plugin, run `/reload-plugins` after the
marketplace add and try again. Upgrading from the 1.x plugin called
`delivery-kit`? Uninstall it **first**:
[handoff/README.md](handoff/README.md#upgrading-from-delivery-kitdelivery-kit)
says why.

**3. With handoff: tell the guard your real context window.** Do this first.

```
/handoff:setup
```

Type it as shown, slash included: Claude Code lists each plugin skill as
`/<plugin>:<skill>`. Asking in words, such as *set up handoff*, works too,
because Claude can load a skill by itself when your request matches it.

The guard assumes a 200,000-token window. Set too small, it fires early, and
you see it at once. Set too large, it **never fires at all**, and you find out
when a session dies mid-task. `handoff:setup` measures your session and writes
the answer to `~/.delivery-kit.json`, once per machine. Setting
`contextGuard.thresholdTokens` as well protects you from a wrong window: it
fires on the transcript alone.

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
the changed files still match. It never writes to git: no commit, no push, no
stash.

**[pipeline](pipeline/README.md)** drives one feature through twenty phases,
from specification to release, and stops at five gates: **clarify**, **who
implements and how you review**, **commit**, **push and open the PR**, and
**release**. Each gate shows you the exact content before anything happens.
Some things never happen at all: no force-push, no history rewrites, no
`git add -A`, no skipped hooks, no branch deletion, and it never merges the
pull request it opens.

**[mission-control](mission-control/README.md)** adds a side pane with robots:
one for the main loop and one for every subagent, each with its tools, context,
cost, rate limits and the files it touched. It also adds a band above the
prompt, a REQUESTS card, toasts and sounds. `/mission` shows or hides the pane.
`/mission-band` shows the band again. Sound: Windows uses PowerShell, macOS uses
the built-in player, and Linux needs `paplay`, `pw-play` or `aplay`. With no
player, it stays quiet.

## Settings

Nothing is required. Every setting has a default, and anything the tools work
out for themselves is printed, so a wrong guess is visible rather than silent.

Both plugins read one file, `.delivery-kit.json`: in your repository root for
project facts, or at `~/.delivery-kit.json` for facts about your machine. **The
repository file wins**, and for the guard's keys an environment variable beats
both: `DELIVERY_KIT_WINDOW_TOKENS`, `DELIVERY_KIT_THRESHOLD_PCT`,
`DELIVERY_KIT_THRESHOLD_TOKENS`, `DELIVERY_KIT_MAX_BYTES` and
`DELIVERY_KIT_HANDOFF_DIR`. Which key each one overrides is in
[the guard's configuration page](handoff/docs/configuration.md). The pipeline's keys have no environment overrides at all, by design: a
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
question for you. When `implementer` is set, pre-flight prints an `Implementer`
line naming the file or flag it came from. `baseBranchOverride` and
`commitTrailers` can arrive the same way: pre-flight names the file each came
from, on its `Base branch` and `Trailers` lines.

Every key: [handoff](handoff/docs/configuration.md) ·
[pipeline](pipeline/docs/configuration.md).

## Windows

handoff's hooks run in bash, and both plugins' skills run their scripts with
`bash` through Claude's Bash tool. On Windows that bash is **Git Bash**, so Git
for Windows is required, and Git Bash is where a tool must be visible.

| What you see | Why | What to do |
|---|---|---|
| `jq --version` works in PowerShell, but the guard says `jq` is missing | PowerShell and Git Bash can see different programs | Check from Git Bash. Install with `winget install jqlang.jq`, then open a new Git Bash and the session again. |
| `gh` works in PowerShell, but Git Bash says `gh: command not found` | Some package managers, Scoop among them, install `gh` as `gh.cmd` only | Pre-flight looks for `gh`, `gh.exe` and `gh.cmd`, and the run's own calls use the one it finds. But the review phase (M) runs the separate code-review plugin, which calls plain `gh`. Install a `gh` that Git Bash finds by that name, for example `winget install GitHub.cli`, which gives `gh.exe`. |
| A value your own script reads from `jq` ends in a stray carriage return, so a comparison or a path fails | The Windows build of `jq` ends each line with CRLF. Linux and macOS get LF. | In your own scripts, use `jq -b`: it writes LF only. The plugins' scripts already cope. They never read `jq` line by line without `-b`, and they strip a trailing CR where one could stay. |
| You cannot find `~/.delivery-kit.json` | `~` is Git Bash's home folder | It is in your Windows user folder: `%USERPROFILE%\.delivery-kit.json`, or under `%HOME%` if you set that variable. |

Each plugin's own troubleshooting table: [handoff](handoff/README.md#troubleshooting)
· [pipeline](pipeline/README.md#troubleshooting).

## What is in this repository

```
handoff/     the handoff plugin — hooks, skills, scripts, docs, tests
pipeline/    the pipeline plugin — command, skills, scripts, docs, tests
mission-control/ the mission-control mod — hook modules, sounds, types, its test
tests/       repo-wide tests: layout, and what may appear in shipped files
specs/       the specifications real pipeline runs produced, kept as examples
main-plan.md the plan file this repository reads its own seeds from
```

This repository builds itself with its own pipeline. The directories under
`specs/` are the output of real runs. Start with
[`specs/018-progress-commits-pieces`](specs/018-progress-commits-pieces/spec.md):
one small feature with everything a finished run leaves behind — the spec,
with the two clarifying questions a human answered, then the research, plan,
data model, contract, quickstart and task list beside it.

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
