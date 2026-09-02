# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- The context guard reads the transcript in **one** `jq` call instead of two
  plus a `grep` — that count is the transcript block alone, not the whole hook,
  whose per-run totals are in the table below — and lets `jq` read the payload
  from standard input instead of copying it through a shell variable. The reading count and the median come
  from the same pass, because they always came from the same list of numbers.

  **Measured, on one non-firing run — the case that follows almost every tool
  call — for zero, one and two configuration files present.** `jq` processes
  fall from 4, 5 and 6 to **3, 4 and 5** on an ordinary transcript, and from
  5, 6 and 7 to **4, 5 and 6** on one starved enough to need the uncapped
  re-read. The `grep` falls from 1 to **0**. Processes of the input-copying
  kind fall from 2 to **1**: this change removes the copy of standard input,
  and the one that remains reads the warning flag further down, which is out
  of scope and is reported rather than rounded away. A run that fires still
  spends one more `jq`, on the emission that writes the instruction.

  **What was measured, rather than a claim that behaviour is unchanged.** The
  differential harness ran the pre-change hook against this one over the whole
  shape set and reported every shape as expected, with two of them ASSERTED to
  differ (below). Fifteen shapes are new and vary the transcript itself: empty,
  one reading, fourteen, fifteen and sixteen readings, an unparseable line among
  good ones, a non-numeric token value, a non-numeric cache field, a record whose
  three token fields are all strings, another whose three strings concatenate
  into numeric text, sidechain entries, a negative reading, a median-window
  shape, and two that starve the byte cap to force the uncapped re-read. Fourteen
  and sixteen sit either side of the floor of fifteen, though only the byte-cap
  variants actually exercise the fallback — without a cap the capped read already
  holds the whole file. Three deliberately broken controls were run first: the
  fallback floor set to zero, caught by three shapes; the median taken over the
  first fifteen readings, caught by one; and the counting rule replaced by a
  plain `length`, caught by NONE, which is itself the finding — see below. A
  pre-existing shape that had been silent on both sides, and was the only one
  touching the fallback, was corrected. The full suite reports the same 163
  tests, zero failures, before and after.

  Exact figures are deliberately left to `scripts/context-guard/README.md`, whose
  dated table records one run rather than making a claim about the current file.
  A total written into prose here went stale twice in a single session, and both
  times the shape it omitted was one asserted to differ.

  **Two things are load bearing and are commented as such in the hook.** The
  per-line pipeline is wrapped in jq's error-tolerant form: streaming jq
  reports a bad line and carries on, while an error inside an array escapes it
  and kills the whole program — no readings at all, and a guard that says
  nothing. And the count is not `length`: the `grep` it replaces counted
  entries beginning with a digit, so a negative reading is excluded from the
  count and included in the median. Measured on readings 100, -5 and 300, the
  old count says 2 and `length` says 3. That moves the fallback decision and
  nothing else: the count decides whether the uncapped re-read RUNS, never what
  the guard answers, because the capped read is a byte suffix whose last fifteen
  readings are the file's last fifteen whenever it holds fifteen at all. The
  differential reports every shape identical for that mutation, so the rule is
  pinned by process count instead: on a straddle of fourteen positive readings
  and one negative, the shipped guard spends five `jq` processes and a `length`
  mutant spends four, while both emit an identical 556 bytes.

  **TWO behaviours change, both measured, neither repaired.** `jq`'s `+`
  concatenates strings rather than erroring, so a usage record whose three token
  fields are all strings produces a string reading. What happened next depended
  on whether that string parsed as a number, and the two cases fail in opposite
  directions:

  - **Not parseable** (`"abc"`): the old code emitted it as a reading, its
    separate median call then failed to parse the whole stream, and the read
    collapsed — the guard said **nothing**. The new code drops the junk and
    answers from the readings around it. Measured: 0 bytes against 556.
  - **Parseable** (`"180000"` from three string fields): the old code re-parsed
    it into a genuine reading and **inflated the median**; the new code drops
    it. Measured, on two readings of 80000 and three such records: the old guard
    fires at 90% on a median of 180000, the new one stays silent at the true
    40%.

  Both are corrections, and the second is the more important one: an inflated
  median driven by junk is the 2026-08-07 fault itself. Restoring either
  byte-for-byte means restoring a defect. The differential carries both shapes
  and ASSERTS each difference, so quietly removing one goes red.

  The claim above said **one** behaviour for one commit. It was written from the
  first case before the second was found, which is the argument for a harness
  that asserts a divergence rather than a sentence that describes it.

  The per-line rule gained a `select(type == "number")` for the same reason.
  Without it such a string sorts after every number, lands inside the
  fifteen-wide window and pushes the middle index onto a larger reading:
  measured, readings 100, 200 and 300 plus two such entries report a median of
  300 where the true one is 200. An inflated median is the 2026-08-07 failure,
  reached from a new direction.

  **Standard input is consumed on every path out of the hook, which took two
  goes.** The copy this change removes was also what drained stdin, so both
  paths that skip the parse had to take that up for themselves. The obvious one
  is `jq` being unavailable. The other, found by review after the first version
  shipped, is `jq` running and FAILING: it reads to end of input only while the
  input keeps parsing, so a payload malformed at its first token makes it abort
  after one buffer and the caller writing the rest is killed by the broken pipe.
  Measured on a 300KB payload beginning `{not json`: writer exit 141 with the
  first version, 0 with the pre-change hook, 0 now. Closed with a fallback drain
  that fires only when `jq` exits non-zero, so the ordinary path still spends
  the two processes this change removes and no more — confirmed by counting.

  On the path where `jq` cannot run, the hook now consumes standard input
  before exiting. It used to do so by accident, through the copy this change
  removes. Measured with a payload of roughly 200KB: a reader that exits
  without reading leaves the writer killed by a broken pipe at exit 141, while
  one that consumes it leaves the writer at 0.

  `handoff/skills/setup/SKILL.md` measures context by the same rule and now
  uses the same one-pass form, so the number it proposes a window from is
  still derived the way the guard derives its own.

- The context guard reads the payload and each configuration file in **one**
  `jq` call instead of one per field. It runs after every tool call, and process
  spawn dominates on Windows under Git Bash, so the cost was paid constantly.
  Measured on one non-firing run — the case that follows almost every tool
  call — for zero, one and two configuration files present: the whole run falls
  from 8, 12 and 16 `jq` processes to 5, 6 and 7, and the part before the
  transcript is read, which is what the reduction actually touches, from 5, 9
  and 13 to 2, 3 and 4. Both figures are given because quoting only the second
  would flatter the change. A run that fires spends one more, on the emission
  that writes the instruction; that one is the output itself.

  **Behaviour was measured, not asserted.** A differential harness ran the
  pre-change hook against this one over 26 payload and configuration shapes —
  present, absent, null, empty-string and wrong-type fields, leading zeros,
  out-of-range values, string numbers, an object where a string was expected, a
  missing transcript, an empty payload, and a value containing an embedded
  newline — comparing stdout and exit code on each. All 26 matched, and the
  guard's own test suite passes unedited.

  That harness is why this entry reports a measurement instead of the flat
  claim it first carried. The first draft of this change was **not**
  behaviour-preserving, in two ways the suite could not see: splitting the
  joined fields with `read` truncated any value containing a newline and
  silently dropped every field after it, and the payload program was missing
  the `map(tostring)` its twin already had, so a field of an unexpected type
  aborted the extraction and left the guard silent. Both were found by the
  differential and fixed before this shipped.

  The fields are joined with the ASCII unit separator rather than a tab, and
  that choice is load-bearing rather than cosmetic. A tab is treated as
  whitespace when splitting, so an empty leading field collapses — and the
  agent identifier is empty in every main-session payload. Measured: with a tab,
  the guard reads every main session as a subagent and stops firing, silently.
  The same collapse in the configuration reader is quieter still, because every
  setting is a positive integer, so a value landing in the wrong slot passes
  validation and is installed.

- `README.md` rewritten for a first-time reader: what the guard actually
  prints, the resume prompt it hands back, and the document's sections as a
  table, with the measurement that motivated the plugin moved below them.
  No behaviour, setting name, or default changed.
- The plugin manifest's description now says what the plugin does in one
  plain sentence, matching the marketplace entry.

## [2.1.0] - 2026-08-20

### Added

- The handoff document gains a **Pipeline state** section, written only
  when a pipeline run is live in the repository, and the printed resume
  block gains a `/pipeline --resume` line under the same condition — so
  a session interrupted at a pipeline gate resumes the run, not just the
  conversation.
- `handoff:setup` offers the `pipeline` configuration block when the
  repository contains `.specify/`, writing answered keys to the
  repository's `.delivery-kit.json`. One setup in front of the user
  instead of two; repositories without specs are never asked.

### Fixed

- The handoff skill now resolves `handoff.docsDir` with the documented
  precedence. 2.0.0 read only the repository's `.delivery-kit.json`, so a
  value set in `~/.delivery-kit.json` — the file `docs/configuration.md`
  recommends for machine-wide answers — was silently ignored.
- `docs/why.md` said the guard takes the median of the last **five** readings;
  the hook has taken the median of the last **fifteen** since 1.0.2. The page
  now matches the shipped arithmetic.

## [2.0.0] - 2026-08-19

### Changed

- **This plugin is now called `handoff`, and it lives in `handoff/` rather than
  at the repository root.** The marketplace keeps the name `delivery-kit`,
  which is what it always described: a family, not a plugin. Having both share
  one name was tolerable while there was one of each and stops being tolerable
  the moment a second plugin exists.

  **This breaks existing installs.** There is no upgrade path a manifest can
  express — a renamed plugin is a different plugin as far as the installer is
  concerned. Two commands migrate it:

  ```
  /plugin uninstall delivery-kit@delivery-kit
  /plugin install handoff@delivery-kit
  ```

  Uninstall first. Both plugins register the same `PostToolUse` hook, and the
  flag that stops the guard repeating itself is keyed by temporary directory and
  session id with nothing in it naming a plugin — so the two copies share one
  flag and race for it. The winner decides which advice you are given: the old
  copy says `delivery-kit:handoff`, the new one says `handoff:handoff`, and
  while both are installed both resolve. At the moment a session is running out
  of room you would be handed an instruction that may name the plugin you are
  removing.

- **The guard's behaviour is unchanged. Its wording is not.** Same measurement,
  same thresholds, same precedence. The message changed only in the names it
  uses: it introduces itself as `handoff` and tells you to run `handoff:handoff`
  and `handoff:setup`, because a skill's namespace is its plugin's name and the
  plugin has been renamed. `.delivery-kit.json` keeps its name and its location,
  so no configuration file moves and no setting is renamed. The suite asserts
  the same properties it always did, now against the new strings.

### Notes

- Release tags are now `<plugin>-v<version>`. A bare `v2.0.0` no longer says
  which plugin it belongs to, and the workflow that checks a tag against a
  manifest needs to know.
- Each plugin now keeps its own `CHANGELOG.md`. Both version gates locate a
  version by taking the first pinned heading, so a single interleaved file
  would make "the current version" a question about release order rather than
  about agreement.
- **Released and verified on 2026-08-19.** `main` `5ba7678`, tag
  `handoff-v2.0.0`. CI ran for the first time on all three runners and passed on
  each — ubuntu, macos and windows — and the tag-gated `tag matches the manifest
  version` step passed on the tag run. The suite was green from the repository
  root before the push: 69 of 69, TAP plan `1..69`, exit 0.
- **The install was verified by hand, and the two checks that could have lied
  were made to discriminate.** The old plugin's absence was read off the enabled
  plugin list rather than inferred from a warning count, because one warning
  proves nothing when the two copies race for a shared flag.
  `.delivery-kit.json` was proven readable by running the guard twice against
  two different `windowTokens` values and confirming the reported window
  followed the file — 1000000 and then 200000 — rather than by observing a
  single run that any always-passing check would also produce. The message it
  emitted named `handoff:handoff`, which is the string 1.3.0 would have got
  wrong.

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
