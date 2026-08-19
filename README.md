# delivery-kit

A Claude Code plugin marketplace. Each plugin in it stands on its own, and the
table below is everything it ships today.

| Plugin | What it does |
|---|---|
| [handoff](handoff/README.md) | Notices when a session is running out of context and ends it cleanly enough that the next one resumes from a single file read. |

## Install

```
/plugin marketplace add h-zahran/delivery-kit
/plugin install handoff@delivery-kit
```

If the second command does not see the plugin, run `/reload-plugins` between
them.

**Coming from 1.x?** This plugin was called `delivery-kit` until 2.0.0, and you
must run `/plugin uninstall delivery-kit@delivery-kit` first — two installed
copies register the same hook and race for one flag. Why, in
[handoff/README.md](handoff/README.md#upgrading-from-delivery-kitdelivery-kit).

Each plugin documents its own requirements and configuration. Start with
[handoff/README.md](handoff/README.md).

## Licence

MIT. See [LICENSE](LICENSE).
