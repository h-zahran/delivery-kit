# Research: the documentation says pieces

All measurements at `main` = `db2875d`, 2026-10-01.

## R1 — The site list is derived, not taken from the seed

- **Decision**: the sites are the hits of one grep per claim over
  `git ls-files` Markdown and JSON outside `specs/`, `main-plan.md`,
  `.specify/` and `docs/`, plus a read of every row of the phase table and
  every paragraph under the gate headings. The result is the spec's Context
  table and [contracts/doc-sites.md](contracts/doc-sites.md).
- **Rationale**: the seed says its list is not complete, and it was not: it
  misses `configuration.md:150`, the two `--implementer` flag rows, the
  Build and Ship rows, and the `README.md:411` configuration row.
- **Alternatives considered**: working from the seed's list plus the P20/P21
  records only — rejected (Principle V).

## R2 — Two pins change; none is added

- **Decision**: `pipeline/tests/prose.bats` pins, in the test "the
  implementer key's consent surface is pinned outside the G slice", the
  configuration page's `implementer` table row whole and the sentence "Cap
  breaches, a missing required tool, hard failures and a failed runtime check
  still stop it, but the gates do not." Both sentences change, so both pins
  change to the new sentences, in the same test, and each new pin is run red
  under an inverted mutant before it is kept. The row keeps being pinned
  whole; the "still stop it" sentence keeps its role (the list of what stops a
  run besides the gates). The test's other configuration-page pins ("With
  `ask` the gate simply asks, as it does when the key is unset", "An illegal
  value stops pre-flight by name: never coerced, never treated as unset.",
  "Layers merge by silence, not by erasure", the `## The implementer key`
  heading) stay true and are kept byte-for-byte in the rewrite. The changelog
  pins in that test are on released 1.1.0 text and stay. The comment above the
  docs pin ("the two shipped surfaces agree verbatim rather than
  approximately") becomes false once the docs sentence changes and the
  changelog's stays; it is rewritten to say the docs page now states the 1.3.0
  range and the changelog pin keeps 1.1.0's (found at F).
- **Rationale**: the seed says "this phase adds no tests" and keeps the count;
  the P20 record calls this "an edited pin, not a new test".
- **Alternatives considered**: adding pins for the new README and phase-table
  text — rejected by the seed. Dropping the two pins — rejected: it would
  unpin a STRICT surface the suite pins today.

## R3 — Pre-flight item 9 is outside every pinned span

- **Decision**: change "the feature's commit" to "the feature's commits" in
  item 9 (`SKILL.md:249`) and nothing else in the orchestrator.
- **Rationale**: measured — no pin in `pipeline/tests/prose.bats` contains
  that sentence, and item 9 lies in none of `span_redflags`, `span_seed`,
  `span_fail`, `span_j`, `span_k`, `span_l`, `span_g`, `span_r`. K's own
  sentence already says "commits" and is pinned (`prose.bats:1271`). Test 10
  slices the decision walk but pins items 10 and 11 only.
- **Alternatives considered**: leaving it (true of the governance rule, as
  P21 argued) — rejected: the owner assigned it here, and "commit" now reads
  as if the run makes one.

## R4 — Renaming the root README's pipeline heading breaks a same-file link

- **Decision**: the heading `### pipeline — one feature, twenty phases, five
  stops` becomes `### pipeline — one feature, twenty phases, five gates`, and
  the table-of-contents link at `README.md:14`
  (`#pipeline--one-feature-twenty-phases-five-stops`) changes with it to
  `#pipeline--one-feature-twenty-phases-five-gates`.
- **Rationale**: "five stops" is false (a pause, and K's and L's conditional
  stops, are stops too); "five gates" is true. The link checker skips links
  that start with `#`, so a same-file anchor that breaks stays green — it must
  be checked by hand (quickstart step 5).
- **Alternatives considered**: dropping the number ("twenty phases, human
  gates") — rejected: "five gates" is true and matches the gate headings.

## R5 — The changelog gains two lines under Unreleased

- **Decision**: add two bullets under `## [Unreleased]` → `### Changed`: (1)
  `pipeline:status` now reports a run waiting at G's review question, at K,
  parked at H for a handoff report, or in pause mode left at H; (2) L, like
  K, stops even under `--auto` for a commit it cannot show or for a
  state-file record of a commit that is not on the branch. Released sections
  stay byte-identical.
- **Rationale**: FR-008 allows an Unreleased change where a P20/P21 entry is
  incomplete about a user-visible behaviour. P20's entries introduce the
  review question and pause mode but ship a status skill that misreports
  both; the fix is a user-visible behaviour of a shipped skill, and a release
  note that omits it lies by omission. The Unreleased entry for K says K
  stops under `--auto` for a path outside the feature or a commit it cannot
  show, but says nothing of L's matching stops, which the orchestrator's L and
  Gates sections add (found at F; the first draft of this decision called the
  section complete, which was false). The rest was read against the
  orchestrator and is complete for a user.
- **Alternatives considered**: no changelog line (the seed's default) —
  rejected: the status skill's behaviour changes. A line for every document
  edit — rejected: documents describing existing behaviour are not a change a
  user acts on.

## R6 — What the floor sentences must say

- **Decision**: every floor statement is checked against the orchestrator's
  Gates section: up to five gates stop a fresh run; a pre-answered
  `implementer` removes the implementer question, never the review question;
  no fresh run reaches DONE without a stop (a Claude run stops at G for the
  review question, a handoff run parks at H); a re-entry past G can reach
  DONE with no gate stopping it; nothing outside the gate table is silenced
  by `--auto`; `--auto-release` is still required before anything publishes
  unasked. The `implementer` key's source stays disclosed at pre-flight.
- **Rationale**: FR-012 — the orchestrator wins.
- **Alternatives considered**: deleting the floor warnings — rejected: the
  re-entry case and the disclosure line still deserve the warning.

## R7 — The status skill says what the state file can show

- **Decision**: step 4 keeps its rule for C, L and O, and adds: G is
  waiting for its implementer answer when `gates.G` holds none, and for its
  review answer when `gates.G.answer` is `claude` and `gates.G.reviewMode` is
  absent (a plain-string `gates.G` counts as the implementer answer alone); K
  is waiting when `gates.K.answer` is absent — K now writes `gates.K.list`
  and any paths outside the feature before its answer, so "`gates` records
  no answer for K" no longer reads right — and a plain-string `gates.K` is
  the answer; L likewise is waiting unless `gates.L` holds the push answer,
  since a removal of stale `commits` entries is recorded there first; H,
  when G's implementer answer is `handoff` (object or plain string), is most
  likely parked for the implementer's report, and the skill says the file
  cannot show whether the report was already consumed; H with `gates.G.reviewMode` `pauses` stops before
  each piece's commit, so it is most likely waiting at a pause — the skill
  says so, names the pause answers under `gates.H.pauses`, and says it cannot
  tell from the file whether a pause is showing now; and a failure entry
  recorded under `gates.H` or a late phase's letter (a rejected commit) is
  reported as the stop it is. The description line says "gate or pause"
  (found at F: K, the handoff park and failure entries were missing in
  round 1; L and the handoff ambiguity in round 2).
- **Rationale**: the orchestrator records pause answers, not a pause that is
  showing; a status skill that guessed would be the silent failure Principle
  I forbids.
- **Alternatives considered**: reading the tree to detect a built,
  uncommitted piece — rejected: the skill is read-only and reports from the
  state file; a dirty tree has other causes.
