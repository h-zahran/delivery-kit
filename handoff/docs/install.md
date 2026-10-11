# Install

## Prerequisites

- Claude Code.
- `jq` on PATH. The guard parses the stdin payload and a JSONL transcript, and
  without `jq` the guard cannot run. It says so once if it is missing, rather
  than failing silently — once per machine, not once per session, because
  without `jq` it cannot read which session it is in.
- `git`, optionally. The guard uses it only to find `.delivery-kit.json` when
  Claude Code's working directory sits below your repository root; without it,
  the guard falls back to defaults rather than failing. The handoff's reconcile
  record and the session-start hook need it: without git the record refuses and
  the hook stays silent.

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
/plugin install handoff@delivery-kit
```

If the install command does not see the plugin, run `/reload-plugins` between
the two and try again.

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

## Tell it your context window

Nothing is required: the defaults assume a 200,000-token window and warn at 45%,
and the guard works with no configuration at all. But if your model's window is
larger than that, the defaults are wrong in the direction you meet immediately —
the first warning reports a percentage well over 100 and adds a
`WINDOW MISCONFIGURED` note.

The quickest way to fix it is to run `handoff:setup` in a session. It
measures the context that session has actually accumulated, proposes a window
when the measurement supports one, asks where you want the guard to stop, and
merges the answers into `~/.delivery-kit.json`. That is the user-level file, so
the question is answered once per machine rather than once per repository.

There are two configuration files and both are optional: `~/.delivery-kit.json`
for facts about your machine and your model, and `.delivery-kit.json` in a
repository root for anything that project wants to override. The repository one
wins. Every setting is in [configuration.md](configuration.md).

## Confirm it is working

The guard is deliberately quiet until it has something to say, so lower its
threshold for one session to see it fire. Do it with an environment variable,
not a configuration file: `DELIVERY_KIT_THRESHOLD_PCT` beats both
`.delivery-kit.json` files, so the check works whatever they hold, and it
changes neither of them. A repository may already have a `.delivery-kit.json`
(`handoff:setup` offers to write one for the pipeline's settings), and a test
file saved over it would replace it.

The variable has to be in the environment of the shell that starts Claude
Code, because the hook inherits Claude Code's environment. Setting it inside a
running session, through Claude's Bash tool, does not reach the hook.

In Git Bash, or a macOS or Linux shell, put it in front of the command. It
applies to that one `claude` process and nothing else:

```bash
DELIVERY_KIT_THRESHOLD_PCT=1 claude
```

In PowerShell, set it for the window, then start Claude Code:

```powershell
$env:DELIVERY_KIT_THRESHOLD_PCT = '1'
claude
```

In that session, ask Claude to do anything that runs a tool, such as listing
the files in the current directory. Expect a `CONTEXT GUARD` message naming
your context percentage after that first tool call, once: it warns again only
when context crosses into the next 5% band. The message tells Claude to finish its step
and run `handoff:handoff`; for this check, tell Claude not to, and end the
session.

To undo it: in Git Bash there is nothing to undo, because the variable ended
with that `claude` process. In PowerShell, run
`Remove-Item Env:\DELIVERY_KIT_THRESHOLD_PCT`, or close the window. If you are
unsure whether it is still set, `handoff:setup` reports any `DELIVERY_KIT_*`
variable it finds, with its value.

## Uninstall

```
/plugin uninstall handoff@delivery-kit
```

The guard can leave three kinds of small state file in your temp directory:
`ctx-warned-<session-id>`, `dk-window-warned-<session-id>`, and `dk-jq-hint`.
Each is a few bytes. They are swept once they are eight days old — the sweep
counts whole days, so a flag seven and a half days old is not yet due — and only
while the plugin is installed and firing, since the sweep runs on the same path
that emits a warning. After uninstalling you can delete them yourself if you
would rather not wait for your system's own temp cleanup. Nothing else is left
behind.
