---
name: device-verify
description: Build, install and drive a mobile release build on one attached device over adb, screenshot what changed, and read the screenshots back. Use when a change claims to work on a device and nobody has watched it do so, or when the pipeline's runtime-check phase runs on a mobile project.
---

# pipeline:device-verify

Verifies by looking, not by compiling. The build succeeding is not the
claim; the screen showing the feature is.

## Preconditions — check, and stop loudly on failure

1. `adb` on PATH. Without it, report the missing tool and stop — the
   caller decides what a skipped verification means.
2. Exactly one device attached: `adb devices` lists one device in state
   `device`. Zero devices: say so and stop. More than one: say so and
   stop — guessing which device the human means is how a wrong phone
   gets a debug build.
3. A mobile project at the working directory (the pipeline's detector
   calls this `mobile-android`). If the project's own build tooling is
   not obvious from its manifest, ask rather than guessing a build
   command.

## The pass

1. **Build a release build** with the project's own build command —
   never a debug build; debug builds hide release-only failures. Show
   the command before running it.
2. **Install** the artefact: `adb install -r <artefact>`. A failed
   install is a finding, not an obstacle — report it verbatim.
3. **Navigate** to every screen the change touches. Map changed files
   to screens by the project's own structure where possible; where the
   mapping is unclear, say so and verify the entry screen plus whatever
   the change's description names.
4. **Screenshot** each screen: `adb exec-out screencap -p >
   <name>.png`, saved under the run's artefact directory.
5. **Read every screenshot back** and describe what it actually shows.
   The description is the verification: a screenshot nobody read is a
   file, not evidence.

## Honesty rules

- Never report verification that did not happen. A screen you could not
  reach is reported as unreached, with the reason.
- Never call a build "working" from the build log alone.
- If the device disconnects mid-pass, report which screens were
  verified before the disconnect and which were not.
