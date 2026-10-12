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

## Sound

- Windows plays the sounds with PowerShell.
- macOS uses the built-in player.
- Linux needs `paplay`, `pw-play` or `aplay`.
- With no player, the mod stays quiet.

## Changes

See [CHANGELOG.md](CHANGELOG.md).
