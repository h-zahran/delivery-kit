# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2026-08-15

### Fixed

- The guard read roughly double the real context whenever a tool that forwards
  the whole conversation ran, and kept reporting the doubled figure for several
  tool calls afterwards. The median was taken over the last 5 readings so that
  one inflated entry could not decide it — but such a tool does not inflate
  one. The assistant messages that follow it read the same oversized cache, so
  four to six CONSECUTIVE readings are inflated, and they fill a 5-wide window
  outright. Measured 2026-08-15: the hook reported 37% where Claude Code's own
  status line read 19%, which hands a session off at half its usable window.
  The median is now taken over the last 15 readings, which outvotes a run of 7.
- The starvation floor now equals the median window: 15, previously 3. Three
  was correct while the window was 5. Against a 15-wide window it is no floor
  at all — a `maxBytes` cap yielding eight readings clears it without
  triggering the uncapped re-read, and six inflated entries among those eight
  are the median again. With the floor equal to the window, `maxBytes` is for
  the first time provably unable to change the answer, which is what 1.0.0
  already claimed for it.

### Changed

- Two tests proved the byte cap worked by asserting that it CHANGED the median.
  That observation no longer exists, by construction: `.[-15:]` of a transcript
  suffix that still holds 15 readings is the last 15 of the whole file, and a
  shorter suffix is discarded by the fallback. Both now assert that no cap size
  changes the answer. Neither can still prove the cap is applied — nothing
  observable can — and the latency the cap buys stays covered by the existing
  hook-timeout test.

## [1.0.1] - 2026-08-13

### Changed

- The window-misconfiguration note now names the real window instead of asking
  the user to find it. A reading that exceeds the configured window is a lower
  bound on the correct one, so the note reports that bound and the two values a
  user is realistically choosing between. Closes #1.

### Notes

- The default `windowTokens` remains 200,000, deliberately. The two ways of
  being wrong are not symmetric: a window set too small fires the guard early —
  annoying, immediately visible, and self-diagnosing through the note above —
  while a window set too large never fires it at all, silently, and is
  discovered only when a session dies mid-task. Detecting the window from the
  transcript was re-tested against a live 1M-context session and remains
  impossible: the base model id is recorded with no context-variant marker and
  no other field carries the window.

## [1.0.0] - 2026-08-13

### Added

- Context guard: a PostToolUse hook that computes session context usage from
  the transcript and, past a configurable threshold, instructs Claude to finish
  the current atomic step and hand off. Re-warns once per 5% bucket.
- `contextGuard.maxBytes` (default 8,000,000): a cap on how much of the
  transcript tail is read per tool call. A long session's transcript reaches
  tens of megabytes and the hook runs after every tool call; the cap takes a
  48MB case from 7.2s to 2.0s. If a capped read holds too few readings to take
  an honest median, the guard re-reads without the cap rather than answering
  from a starved window, so the cap can never change the answer.
- Handoff skill: writes a standardised handoff document, makes the work
  durable, and prints the exact resume prompt.
- `.delivery-kit.json` configuration with environment-variable overrides.
  Zero-config works.
- Detection and reporting of a missing `jq` and of a window configured smaller
  than observed context — two ways this hook could otherwise fail silently.

### Changed

- Hook timeout raised from 10s to 30s. The slowest path the design admits — a
  capped read that starves and falls back to an uncapped one — measured 8.2s,
  and a hook killed by its own timeout emits nothing, which is a guard that is
  silently off.
