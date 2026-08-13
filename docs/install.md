# Install

## Prerequisites

- Claude Code.
- `jq` on PATH. The hook parses the stdin payload and a JSONL transcript, and
  without `jq` the guard cannot run. It says so once if it is missing, rather
  than failing silently — once per machine, not once per session, because
  without `jq` it cannot read which session it is in.
- `git`, optionally. It is used only to find `.delivery-kit.json` when Claude
  Code's working directory sits below your repository root. Without it, the
  guard falls back to defaults rather than failing.

| Platform | Install `jq` |
|---|---|
| macOS | `brew install jq` |
| Debian / Ubuntu | `sudo apt-get install jq` |
| Windows | `winget install jqlang.jq` |

On Windows, confirm `jq` is visible from Git Bash specifically — that is the
shell the hook runs in:

```bash
jq --version
```

## Install the plugin

```
/plugin marketplace add h-zahran/delivery-kit
/plugin install delivery-kit@delivery-kit
```

If the install command does not see the plugin, run `/reload-plugins` between
the two and try again.

## Confirm it is working

The guard is deliberately quiet until it has something to say, so lower the
threshold temporarily to see it fire. Set `windowTokens` to your model's real
window at the same time — otherwise this check reports a percentage over 100
and a `WINDOW MISCONFIGURED` note, which is correct behaviour but a confusing
thing to meet first:

```json
{ "contextGuard": { "thresholdPct": 1, "windowTokens": 1000000 } }
```

Save that as `.delivery-kit.json`, run any tool call in a session, and expect a
`CONTEXT GUARD` message naming your context percentage. Then remove it.

## Uninstall

```
/plugin uninstall delivery-kit@delivery-kit
```

The guard can leave three kinds of small state file in your temp directory:
`ctx-warned-<session-id>`, `dk-window-warned-<session-id>`, and `dk-jq-hint`.
Each is a few bytes. They are swept once they are eight days old — the sweep
counts whole days, so a flag seven and a half days old is not yet due — and only
while the plugin is installed and firing, since the sweep runs on the same path
that emits a warning. After uninstalling you can delete them yourself if you
would rather not wait for your system's own temp cleanup. Nothing else is left
behind.
