# mission-control

A Claude Code mod that adds a side pane with robots: one for the main loop and
one for every subagent. Each robot shows its tools, context, cost, rate limits
and the files it touched. The mod also adds a band above the prompt, a
REQUESTS card, toasts and sounds.

## Install

```
/plugin marketplace add h-zahran/delivery-kit
/plugin install mission-control@delivery-kit
```

## Commands

| Command | What it does |
|---|---|
| `/mission` | Show or hide the pane. |
| `/mission-band` | Show the band above the prompt again. |
| `/mission-talk` | Turn the commentator on or off: one short line after each turn. It uses a little of your plan. |

## What it adds to Claude

The mod changes what the model sees, not only what you see:

- **A short, fixed section in the system prompt.** It says how to tick an
  ask. It appears only when the ask tool below is on offer.
- **Your open asks beside each prompt you type.** The REQUESTS card turns
  the first line of each request into an ask. The current list goes with your
  prompt as text the model reads and you do not see. Each ask is a quote, not
  an instruction.
- **Two tools the model can call.** `ask` ticks an ask done, partial or
  dropped, with a short proof. Its reply lists what is still open. `step`
  lets a subagent report its plan and progress, which the pane draws. Only
  the main conversation may tick asks; a subagent's call is ignored.
- **`/mission-talk` sends a little to Haiku.** When it is on, the start of
  each answer and the names of the files edited go to a Haiku call, which
  writes the one-line comment.

## Sound

- Windows plays the sounds with PowerShell, by its full path. The sound's
  path goes in an environment variable, never inside the script.
- macOS uses the built-in player.
- Linux needs `paplay`, `pw-play` or `aplay`.
- With no player, the mod stays quiet. If a sound fails to play once, the
  mod stays quiet for the rest of the session.

## Changes

See [CHANGELOG.md](CHANGELOG.md).
