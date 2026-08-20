---
description: Drive one unit of work from a heading in a plan file to a verified build — specification, plan, tasks, implementation, review and release, with a human gate at every step that leaves the machine or cannot be undone by editing a file.
disable-model-invocation: true
---

Invoke the `pipeline:pipeline` skill now, passing everything after the
command name to it verbatim as the seed: $ARGUMENTS

Do not summarise, reinterpret, or shorten the seed on the way through —
the skill's pre-flight decides what kind of seed it is. If `$ARGUMENTS`
is empty, invoke the skill with an empty seed; the skill's resume prompt
handles a live run, and an empty seed with no live run is the skill's
error to raise, not this command's.
