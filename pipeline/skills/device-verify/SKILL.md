---
name: device-verify
description: Build, install and drive a mobile release build on one attached device over adb, screenshot what changed, and read the screenshots back. Use when a change claims to work on a device and nobody has watched it do so, or when the pipeline's runtime-check phase runs on a mobile project.
---

# pipeline:device-verify

Verifies by looking, not by compiling. The build succeeding is not the
claim; the screen showing the feature is.

## Preconditions — check, and stop loudly on failure

1. `adb` on PATH: try `command -v adb`, then `command -v adb.exe`, and
   say which name was found. WSL's bash cannot run a Windows install under
   the bare name; Git Bash can. Use the name found in every command below.
   Neither: report the missing tool and stop — the caller decides what a
   skipped verification means.
2. One device: `adb devices` lists the devices in state `device`. With
   `ANDROID_SERIAL` set, use that device, and when more than one is
   attached pass `-s <serial>` to every adb command; a serial not in the
   list: say so and stop. Unset, exactly one must be listed. Zero: say so
   and stop. More than one: say so and stop — guessing which device the
   human means is how a wrong phone gets a debug build.
3. A mobile project at the working directory (the pipeline's detector
   calls this `mobile-android`). If the project's own build tooling is
   not obvious from its manifest, ask rather than guessing a build
   command.

## The pass

1. **Build a release build** with the project's own build command —
   never a debug build; debug builds hide release-only failures. Show
   the command before running it. An unsigned release build will not
   install: if the project has no release signing set up, say so and ask
   before signing it with the debug key.
2. **Install** the artefact: `adb install -r <artefact>` for an `.apk`.
   An `.aab` does not install as it is: `bundletool build-apks
   --bundle=<aab> --output=<apks> --connected-device --ks=<keystore>
   --ks-key-alias=<alias>` with the project's release key, then
   `bundletool install-apks --apks=<apks>`, each with
   `--device-id=<serial>` when more than one is attached. Without `--ks`,
   bundletool signs with the debug key: ask first, as in step 1. A failed
   install is a finding, not an obstacle — report it verbatim.
3. **Navigate** to every screen the change touches. Map changed files
   to screens by the project's own structure where possible; where the
   mapping is unclear, say so and verify the entry screen plus whatever
   the change's description names.
4. **Screenshot** each screen: `adb exec-out screencap -p >
   <folder>/<name>.png`. The folder is
   `.delivery-kit/runs/<feature>/screenshots/` in a pipeline run, else
   `.delivery-kit/screenshots/`. Name it in the report.
5. **Read every screenshot back** and describe what it actually shows.
   The description is the verification: a screenshot nobody read is a
   file, not evidence.

## Honesty rules

- Never report verification that did not happen. A screen you could not
  reach is reported as unreached, with the reason.
- Never call a build "working" from the build log alone.
- If the device disconnects mid-pass, report which screens were
  verified before the disconnect and which were not.
