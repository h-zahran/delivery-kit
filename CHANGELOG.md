# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-08-18

### Fixed

- **The guard no longer fires inside subagents, where it reported the parent
  session's percentage and could swallow the parent's next warning.** The
  mechanism was measured rather than assumed: the hook's stdin was logged and one
  throwaway subagent was driven through it. Both of that subagent's tool calls
  arrived carrying the **parent's** `transcript_path` and the **parent's**
  `session_id`, indistinguishable from the main-chain calls around them except
  for an `agent_id` field present only inside the subagent.
- That answers the open question the issue recorded, and the answer is the worse
  one. Because `session_id` is the parent's, the once-per-bucket flag is
  **shared** — so a subagent's firing marked the bucket and could suppress a
  warning the parent was owed. A missing warning is the failure this project
  exists to prevent, so that, not the wrong percentage, is why this is a fix
  rather than a cosmetic tidy-up.
- Silence was chosen over "measure the subagent instead" because the payload does
  not carry the subagent's own transcript path — there is nothing to measure. The
  advice would be wrong regardless: a subagent cannot hand off, and telling it to
  stop mid-task damages the parent's work for no benefit. The check keys on the
  **presence** of `agent_id`, deliberately: if a future Claude Code renames that
  field the check goes inert and the guard returns to today's behaviour, noisy in
  subagents but correct in the main session. The opposite polarity would fail
  toward silence in the main session, which is the one direction this hook must
  never fail in. (#5)

### Changed

- **The warning now travels two channels on every firing, not one.** Everything
  the guard says reached Claude through `decision`, and the hooks reference states
  plainly that PostToolUse has no decision control. It works anyway — but a plugin
  whose entire payload rides a path the documentation says does not exist is fine
  until it isn't, and the failure mode if it were withdrawn is the worst available
  here: the guard emits into a void, silently, and nobody learns it stopped.
- `systemMessage` is documented as shown to the user, and **it was measured
  arriving**. On 2026-08-18 a firing carrying both fields was watched from the
  user's own terminal: the reason rendered as `PostToolUse:Bash hook returned
  blocking error …` and the systemMessage as a separate `PostToolUse:Bash says:
  delivery-kit: …` line. Both arrived, with a decision present in the same
  emission. Earlier notes in this repository called that unresolvable from inside
  an agent session and were right — it took a human watching the screen.
- So `systemMessage` is no longer an unverified hedge riding only the rare
  misconfiguration note; it accompanies every emission, deliberately shorter than
  `reason` because a human reads it mid-task. `decision` and `reason` are
  unchanged. **This replaces the previous contract** that kept the common path
  byte-shaped as 1.0.x emitted it; that reasoning was sound while `systemMessage`
  was unverified, and it is superseded by the measurement. (#2)

### Notes

- The firing arithmetic, the thresholds and the 200000 default are untouched by
  both changes.

## [1.2.2] - 2026-08-18

### Fixed

- **`delivery-kit:setup` reported success while an environment variable silently
  overrode everything it had just written.** `DELIVERY_KIT_WINDOW_TOKENS`,
  `DELIVERY_KIT_THRESHOLD_PCT`, `DELIVERY_KIT_THRESHOLD_TOKENS` and
  `DELIVERY_KIT_MAX_BYTES` beat both configuration files, but the skill's shadow
  check read only the repository file. A user with one of them exported answered two
  questions, saw the right numbers printed back, and had nothing change — the very
  "reported success, nothing changed" outcome that the repository-file half of that
  same check exists to prevent, missing one of the three layers. The check now
  covers the environment as well, naming the variable and the value it is imposing,
  and saying plainly that it comes from a shell profile this skill can neither see
  nor edit. It reports what is **set**, not what is valid — the same standard the
  repository check already uses, since a rejected value is one correction away from
  taking effect. (#6)

### Added

- **A test coupling the hook's measurement to the setup skill's copy of it.** The
  reading program, the `tail -n` line budget and the median program are each written
  twice — once in `hooks/context-guard.sh`, once in `skills/setup/SKILL.md` — with
  nothing holding them together. Editing any one of those six sites left the entire
  suite green while the skill went on claiming it measures "the same way the guard
  does"; the window it recommends is only meaningful for as long as that is true.
  All three quantities are now extracted from the shipped files and compared.
  Verified by mutation rather than asserted: four edits, on both sides of the pair,
  each confirmed to redden this test and nothing else. (#7)
- That test is anchored so it cannot pass on nothing. Two failed extractions compare
  equal, so agreement about a pair of empty strings would have looked identical to
  agreement about the real program. Its first draft also matched a `tail -n 300`
  inside the comment describing the 2026-08-07 incident, and reported a drift
  between a live budget and a historical one named in prose — found by running it,
  which is the only thing that finds that.

## [1.2.1] - 2026-08-17

### Added

- A test pinning 1.2.0's promise that `delivery-kit:handoff` writes nothing to git.
  The promise lived entirely in prose, so nothing stopped a later edit from quietly
  restoring the instruction a user complained about. The test asserts the three
  explicit prohibitions are present, that the exact instructions 1.2.0 removed have
  not returned, and that the guard's emitted `reason` still says not to commit or
  push. It is a regression guard, not a proof — a newly worded instruction to commit
  would sail past it — and it says so, along with the stricter alternative that was
  considered and rejected for reddening on legitimate text like "last commit SHA".

### Fixed

- **Three of that test's own negative assertions could never fire.** POSIX exempts
  a `!`-negated command from `errexit`, so `! grep -q pattern file` does **not** fail
  a bats test when the pattern *is* found. Written the obvious way, the assertions
  were inert and the test passed on a tree that violated it — while the positive
  `grep -qF` assertions beside them reddened correctly, which is exactly what made
  the inert ones look like they worked. Now written as `run grep …` followed by
  `[ "$status" -ne 0 ]`, which is a plain command and therefore does fail.
- Found by mutating the promise away and observing which mutations reddened: two of
  six did not. This is the third instance in this project of a guard that could not
  fire, after an unreachable emptiness check in the setup skill's merge test and a
  release gate whose alternation had been destroyed by argv conversion. The suite is
  now free of the pattern — no line in `tests/` begins with `!`.

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
