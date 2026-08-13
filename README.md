# delivery-kit

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

Two components that work together and are useful apart.

**The context guard** — a `PostToolUse` hook. After each tool call it reads the
session transcript, computes how much of the context window is in use, and once
past a threshold tells Claude to finish only the current atomic step and hand
off. It re-warns once per 5% thereafter.

**The handoff skill** — makes the work durable, writes a standardised handoff
document with a fixed set of sections, and prints the exact prompt that resumes
the work in a fresh session.

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
/plugin install delivery-kit@delivery-kit
```

If the second command does not see the plugin, run `/reload-plugins` between
them. Requires `jq` on PATH. Full steps, including Windows, are in
[docs/install.md](docs/install.md).

## Configure

Nothing is required. The defaults assume a 200,000-token context window and
warn at 45%.

**If your model has a larger window, say so.** On a 1M-token model the defaults
do not merely fire early — the first warning reports a percentage well over 100
and adds a `WINDOW MISCONFIGURED` note, because the guard is measuring against a
window five times smaller than the real one. That is the guard telling you the
configuration is provably wrong, and it is the most likely thing to surprise you
on a first run. One line fixes it:

```json
{
  "contextGuard": { "windowTokens": 1000000, "thresholdPct": 45 },
  "handoff":      { "docsDir": "docs/handoffs" }
}
```

Save that as `.delivery-kit.json` in your repository root. Every setting is
documented in [docs/configuration.md](docs/configuration.md).

## Licence

MIT. See [LICENSE](LICENSE).
