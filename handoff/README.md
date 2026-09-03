# handoff

A Claude Code plugin that notices when a session is running out of context and
ends it cleanly enough that the next session resumes from a single file read.

## What happens

You are deep in a long session. After every tool call, a hook quietly works out
how full the context window is. Once you cross a line, it stops you:

```
CONTEXT GUARD: session context is at 45% of the 200000-token window (threshold 45%).
Finish ONLY the current atomic step — do NOT start the next batch or task.
Then invoke the handoff skill (handoff:handoff) ...
```

You finish the step you are on. You run `handoff:handoff`. It writes one
document and prints this:

```
Resume with:
Read docs/handoffs/2026-08-25-csv-export-SESSION-HANDOFF.md and continue from it.
Follow the Resume protocol.
```

Paste that into a fresh session and the work carries on. Nothing has to be
rediscovered.

If you keep working past the warning, the guard nudges you again every 5% —
not on every tool call.

## What is in the document

A fixed set of sections, so the next session always knows where to look:

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

**It never writes to git.** No commit, no push, no `git add`, no stash. The hook
fired on its own, so nothing here was asked for — a commit message would be the
machine's, not yours. Instead it records the uncommitted work in full and prints
the commands, and the choice stays with you.

## What ships

Three pieces. The first two work together and are useful apart; the third exists
to configure the first.

| Piece | Kind | Does |
|---|---|---|
| The context guard | a `PostToolUse` hook | Measures context after each tool call, warns past a threshold, re-warns once per 5%. |
| `handoff:handoff` | a skill | Writes the document above, prints the resume prompt, stops. |
| `handoff:setup` | a skill | Measures your session, asks for your real window and stopping point, and writes those to `~/.delivery-kit.json` — machine facts, so once is enough. Where a repository has `.specify/`, it also offers to write the pipeline block into that repository's file. It asks first. |

## Install

```
/plugin marketplace add h-zahran/delivery-kit
/plugin install handoff@delivery-kit
```

If the second command does not see the plugin, run `/reload-plugins` between
them. Requires `jq` on PATH — the hook parses a JSONL transcript, and without
`jq` it says so once rather than failing silently. Full steps, including
Windows, are in [docs/install.md](docs/install.md).

### Upgrading from `delivery-kit@delivery-kit`

This plugin used to be called `delivery-kit`. Version 2.0.0 renamed it to
`handoff`, because the marketplace is called `delivery-kit` and one name
cannot mean both. A rename is a new plugin as far as the installer is
concerned, so it takes two commands, and the order matters:

```
/plugin uninstall delivery-kit@delivery-kit
/plugin install handoff@delivery-kit
```

**Uninstall first.** Both register the same `PostToolUse` hook and race for one
shared flag, so with both installed the warning you get may name the plugin you
are removing. No configuration moves: `.delivery-kit.json` keeps its name, its
location and every setting.

[The install page](docs/install.md#upgrading-from-delivery-kitdelivery-kit)
carries the rest — why the race happens, and why counting warnings cannot tell
you whether the old copy is gone.

## Configure

Nothing is required. The defaults assume a 200,000-token context window and
warn at 45%.

**If your model has a larger window, say so.** This is the one setting worth
getting right, and the two ways of being wrong are not the same:

- **Set too small** — the guard fires early. Annoying, and instantly visible:
  the warning names the window it used, and once observed context passes that
  window the guard reports it outright with a `WINDOW MISCONFIGURED` note.
- **Set too large** — the guard never fires at all. Silent, total, and
  discovered when a session dies mid-task. Nothing can detect it.

That is why the default is conservative. On a 1M-token model the defaults do not
merely fire early: the first warning reports a percentage well over 100. One
line fixes it.

The easy way is `handoff:setup`. It measures the session, proposes a window when
the measurement supports one, asks where you want it to stop, and writes the
answers for you. Or set it by hand:

```json
{
  "contextGuard": { "windowTokens": 1000000, "thresholdPct": 45 },
  "handoff":      { "docsDir": "docs/handoffs" }
}
```

Save that as `.delivery-kit.json` in your repository root, or at
`~/.delivery-kit.json` for facts about your machine rather than a project — the
repository file wins. Every setting is documented in
[docs/configuration.md](docs/configuration.md).

## Why this exists

This tooling was not designed up front. It was derived from measuring 1,410
prompts across 67 sessions of real work, which showed where the human effort was
actually going:

| Pattern | Count |
|---|---:|
| Continuation nudges (`continue`, `keep going`, `/resume`) | 121 |
| "How do I hand off / make you remember?" | 30 |

121 prompts — 8.5% of everything typed — were a human saying *continue*. That is
the problem this plugin addresses. The longer version, including why the guard
takes a median rather than the latest reading, is in [docs/why.md](docs/why.md).

## What this plugin does not own

So there is no ambiguity — the marketplace splits the work across its
plugins, and this one deliberately owns the smaller share:

- The pipeline orchestrator, runtime verification and finding
  remediation live in the [pipeline](../pipeline/README.md) plugin,
  installed separately as `pipeline@delivery-kit`. Someone who wants
  only a context guard never acquires a spec-tool dependency.
- No support for harnesses other than Claude Code. The guard reads a
  Claude Code transcript through a Claude Code hook; the handoff skill
  is portable markdown and could be adapted later.

## Licence

MIT. See [LICENSE](../LICENSE).
