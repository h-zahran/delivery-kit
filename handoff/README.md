# handoff

A Claude Code plugin that notices when a session is running out of context and
ends it cleanly enough that the next session resumes from a single file read.

## Why this exists

This tooling was not designed up front. It was derived from measuring 1,410
prompts across 67 sessions of real work, which showed where the human effort was
actually going:

| Pattern | Count |
|---|---:|
| Continuation nudges (`continue`, `keep going`, `/resume`) | 121 |
| "How do I hand off / make you remember?" | 30 |

121 prompts — 8.5% of everything typed — were a human saying *continue*. That is
the problem this plugin addresses. The longer version is in [docs/why.md](docs/why.md).

## What ships in v1

Three components. The first two work together and are useful apart; the third
exists to configure the first.

**The context guard** — a `PostToolUse` hook. After each tool call it reads the
session transcript, computes how much of the context window is in use, and once
past a threshold tells Claude to finish only the current atomic step and hand
off. It re-warns once per 5% thereafter.

**The handoff skill** — makes the work durable, writes a standardised handoff
document with a fixed set of sections, and prints the exact prompt that resumes
the work in a fresh session.

**The setup skill** — measures the context a session has actually accumulated,
asks for your real window and where you want the guard to stop, and merges the
answers into `~/.delivery-kit.json`, so the question is answered once per
machine rather than once per repository.

## What does not ship in v1

So there is no ambiguity:

- No pipeline orchestrator.
- No `ship` or `fix-findings` commands.
- No device or browser verification.
- No support for harnesses other than Claude Code. The guard reads a Claude Code
  transcript through a Claude Code hook; the handoff skill is portable markdown
  and could be adapted later.

## Install

```
/plugin marketplace add h-zahran/delivery-kit
/plugin install handoff@delivery-kit
```

If the second command does not see the plugin, run `/reload-plugins` between
them. Requires `jq` on PATH. Full steps, including Windows, are in
[docs/install.md](docs/install.md).

### Upgrading from `delivery-kit@delivery-kit`

This plugin used to be called `delivery-kit`. Version 2.0.0 renamed it to
`handoff`, because the marketplace is called `delivery-kit` and one name
cannot mean both. A rename is a new plugin as far as the installer is
concerned, so it takes two commands:

```
/plugin uninstall delivery-kit@delivery-kit
/plugin install handoff@delivery-kit
```

**Uninstall first.** Both register the same `PostToolUse` hook, and the flag
that stops the guard repeating itself is keyed by temporary directory and
session id with nothing in it naming a plugin. The two copies therefore share
one flag and race for it, and the winner decides which advice you get: the old
copy tells you to run `delivery-kit:handoff`, the new one `handoff:handoff`.
While both are installed both resolve, so at the moment a session is running
out of room you would be handed an instruction that may name the plugin you
are removing.

**Do not use the number of warnings to tell whether the old one is gone.**
Because the two copies race, the count is not fixed: two installs usually
produce one warning and sometimes two. Seeing one proves nothing. Run
`/plugin` and read the list instead.

`.delivery-kit.json` keeps its name and its location, and every setting keeps
its name, so no configuration moves. The guard measures, decides and fires
exactly as it did in 1.3.0; the only change is the names inside its message,
which now say `handoff:handoff` and `handoff:setup` because a skill's
namespace is its plugin's name.

## Configure

Nothing is required. The defaults assume a 200,000-token context window and
warn at 45%.

**If your model has a larger window, say so.** On a 1M-token model the defaults
do not merely fire early — the first warning reports a percentage well over 100
and adds a `WINDOW MISCONFIGURED` note, because the guard is measuring against a
window five times smaller than the real one. That is the guard telling you the
configuration is provably wrong, and it is the most likely thing to surprise you
on a first run. One line fixes it.

Run `handoff:setup` and it will measure the session, propose a window when
the measurement supports one — in a fresh session it asks without one — ask where
you want it to stop, and write the answers for you. Or set it by hand:

```json
{
  "contextGuard": { "windowTokens": 1000000, "thresholdPct": 45 },
  "handoff":      { "docsDir": "docs/handoffs" }
}
```

Save that as `.delivery-kit.json` in your repository root. Every setting is
documented in [docs/configuration.md](docs/configuration.md).

## Licence

MIT. See [LICENSE](../LICENSE).
