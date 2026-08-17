# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-08-17

### Changed

- **`delivery-kit:handoff` no longer writes to git.** No commit, no push, no
  `git add`, no stash. Reported by developers using it, and they were right: the
  skill is normally invoked by a hook firing, so neither the commit nor the push
  had been asked for — the commit message was the agent's rather than the
  developer's, and a push is outward-facing and hard to undo. On a project whose
  working branch must not leave the machine, the old rule could not be obeyed at
  all.
- **The work is now durable because it is recorded, not because it was
  committed.** The handoff document gains a required **Uncommitted work** section
  carrying `git status --porcelain` and `git diff --stat`, with each path marked as
  this run's work or as pre-existing. The skill states that the work is
  uncommitted, that `git clean` / `git checkout` / `git stash` will discard it, and
  prints the `git add` / `git commit` / `git push` commands for the developer to
  run if they want them. `git add -A` is explicitly not printed.
- **The guard's own instruction changed with it**, from "commit and push the work"
  to "record the work", plus an explicit "Do NOT commit or push — the skill leaves
  git alone". An unprompted hook does not get to order a write to shared history.
- **The resume protocol's expected git state is inverted.** It previously told the
  next session to expect HEAD one commit ahead of the recorded SHA, which was true
  only because the old skill committed the document. HEAD must now **match
  exactly**; a HEAD ahead of it means someone else committed and is worth
  reporting rather than waving through. A clean tree where the document describes
  a dirty one is now a question to ask, not an assumption to make.

### Notes

- The trade is stated in the skill rather than hidden: committing protected work
  from loss, and recording it does not. What recording buys is that the next
  session can find every affected path, which a commit alone never guaranteed.
- No behavioural change to the context guard's firing, thresholds, precedence or
  message shape beyond the sentence above. The suite is unchanged at 59 tests.

## [1.1.0] - 2026-08-16

### Added

- `delivery-kit:setup` — a skill that measures the session's observed context,
  proposes a window, asks where you want the guard to stop, and writes the
  answers to `~/.delivery-kit.json`. A hook cannot ask a human anything; a skill
  can, because a skill is instructions to Claude and Claude holds a
  conversation. It merges rather than overwrites, so keys it does not know —
  including keys a later version adds — survive.
- `contextGuard.thresholdTokens` / `DELIVERY_KIT_THRESHOLD_TOKENS`: an absolute
  stopping point in tokens, unset by default. When set, the guard fires when
  either tripwire is crossed. This is a safety property: an absolute threshold
  is decided from the transcript alone so it survives a wrong `windowTokens`,
  and the percentage survives a `thresholdTokens` set too high. One wrong value
  used to be enough to silence the guard; now it takes two. When the absolute
  tripwire is the one that fires, the message changes SHAPE rather than just its
  numbers — `session context is at N tokens, past the M-token limit (P% of the
  W-token window)` replaces the percentage wording — so anything parsing `reason`
  sees a string it has not seen before.
- A user-level `~/.delivery-kit.json`, read before the repository file. The
  context window is a fact about a machine and a model, not about a project, so
  requiring it per repository guaranteed that most repositories ran on defaults.

### Changed

- When the window is provably wrong, the guard now suggests running
  `delivery-kit:setup`, placed after the handoff instruction and phrased as
  deferred. The note only ever rides an emission that is already telling Claude
  to hand off, so a bare suggestion there would be a second competing
  instruction at the worst possible moment. It rides the once-per-session
  misconfiguration note, so the suggestion appears once in a session and not
  again — that is the design and not a bug. The same warning is also emitted as
  a `systemMessage`, as an unverified hedge that nothing depends on — whether
  that field is displayed is not observable from a test.
- The banned-path scan in `tests/portability.bats` now requires a path character
  after `~/.claude/projects/`, so a prose reference is not treated as a leak
  while an encoded project directory still is. Measured: 3/3 leaks caught, 0/3
  false positives, against 3/3 and 3/3 before. A positive control pins that
  detection is retained.

### Notes

- The default window remains 200,000, and window detection remains rejected.
  Neither is reopened by this release; see issue #1.
- Set `windowTokens` and `thresholdTokens` together. If you set
  `thresholdTokens` alone and leave a wrong `windowTokens`, the percentage
  tripwire can fire well before the token one you chose — the safety property
  working, and the reason `delivery-kit:setup` asks about both in one go.

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
