# delivery-kit

A Claude Code plugin marketplace. Each plugin in it stands on its own, and the
table below is everything it ships today.

| Plugin | What it does |
|---|---|
| [handoff](handoff/README.md) | Notices when a session is running out of context and ends it cleanly enough that the next one resumes from a single file read. |
| [pipeline](pipeline/README.md) | Drives a unit of work from a heading in a plan file to a verified build — spec, plan, tasks, implementation, review and release — with a human gate at every step that leaves the machine. |

## Install

```
/plugin marketplace add h-zahran/delivery-kit
/plugin install handoff@delivery-kit
/plugin install pipeline@delivery-kit
```

If an install command does not see its plugin, run `/reload-plugins`
after the marketplace add.

**Coming from 1.x?** This plugin was called `delivery-kit` until 2.0.0, and you
must run `/plugin uninstall delivery-kit@delivery-kit` first — two installed
copies register the same hook and race for one flag. Why, in
[handoff/README.md](handoff/README.md#upgrading-from-delivery-kitdelivery-kit).

Each plugin documents its own requirements and configuration. Start with
[handoff/README.md](handoff/README.md).

## Licence

MIT. See [LICENSE](LICENSE).
