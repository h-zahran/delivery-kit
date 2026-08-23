# Key contract — `implementer`, its flag, and the quoted G sentences

## The documentation sites (exact strings)

> **FIVE since phase M round 4**: `pipeline/README.md` gained a sentence
> naming the key and `ask`, because the plugin's front door describes the
> consent model and was silent on a key that removes one of its five stops.
> It is pinned by `quickstart.md` §1, not by a string here — the README
> sentence is prose that may be reworded, unlike the four table rows below.

1. Orchestrator Configuration table (`pipeline/skills/pipeline/SKILL.md`), appended row:

   ```
   | `implementer` | unset | Pre-answers the G gate: `claude` or `handoff`; `ask` restores the stop |
   ```

2. Orchestrator Flags table (same file), appended row:

   ```
   | `--implementer <claude\|handoff\|ask>` | Pre-answers the G gate, or restores it with `ask`; beats the config key. |
   ```

3. `pipeline/docs/configuration.md` JSON block, appended entry (before the closing brace):

   ```
   "implementer": null
   ```

4. `pipeline/docs/configuration.md` key table, appended row:

   ```
   | `implementer` | Pre-answers the implementer gate: `claude` or `handoff`; `ask` restores the stop; unset means ask. |
   ```

Identity binds the key name, the value set (`claude`, `handoff`, `ask`), and
the default (unset — rendered `unset` in the orchestrator's default
column and `null` in the JSON block, the files' existing convention for
`verifyCommand`/`releaseCommand`). Description prose follows each
table's own style (research R1).

## The quoted G sentences (verbatim, from the plan of record)

> Called a "pair" throughout this run; it is FOUR sentences since round 4.

> When `implementer` resolves to `claude` or `handoff` (config or flag), G
> records that answer in `gates` and does not stop — the choice was typed
> on purpose. `ask` pre-answers nothing: G stops, asks, and records the
> owner's answer in `gates` like any asked gate. It is how a command line
> takes back a stop a configuration file gave away. Everything else about G
> is unchanged, and a pre-answered `implementer` silences nothing else: cap
> breaches, hard failures and every other gate still stop exactly as
> before.

Placed directly after "`--auto` never collapses this gate: it spends
money." (research R2). No existing sentence reworded; the Gates-table

> **OVERRIDDEN at phase M round 1 (2026-08-23)**: SEVEN pre-existing regions WERE reworded — the `--auto` flags row, the G section's "STOP AND ASK" lead, pre-flight item 9's "like C and G" clause and the probe block's render instruction at phase M rounds 1-2; the Gates paragraph at phase I; and, at round 4, the Configuration section's "`null` means *work it out*" line and the H-park paragraph's "the answer stands, on this path and every other" sentence. The count read "four", then "five", before reviewers found the sixth and seventh — which is itself the annotate-one-instance asymmetry this run kept repeating. Each had been made FALSE by this diff, and two independent reviewers measured that none of them is pinned by any test or by this contract. A sentence this change made false is not protected churn — the same ground on which H.7 reworded the docs section. Recorded as a deliberate override, not an oversight; see `tasks.md`, phase M round 1.
row `| Implementer | G |` byte-identical.

## The docs paragraph (FR-004, STRICT surface)

One paragraph in `pipeline/docs/configuration.md`, its own section:
what the key pre-answers (the implementer gate's Claude-or-handoff
question), that unset means ask, and that it exists so an `--auto` run
touches the human at clarify only. No banned spellings.

> **SUPERSEDED at phase M rounds 1-2 (2026-08-23)**: the section shipped as THREE paragraphs, not one, and "touches the human at clarify only" is a point on a range, not a promise — the release gate stops when `releaseCommand` is set, the pre-flight constitution offer stops when the constitution is unset, and with `--auto` plus neither of those a run reaches the end with no gate stopping it. The shipped page states the whole range and the pre-flight disclosure line. Same scoping as `spec.md` FR-004 already carries.

> **RE-PINNED at phase M round 4, on the owner's instruction (2026-08-23)**:
> the owner overrode the review cap with "fix everything, no deferred", which
> spent two deferrals that reach these pins. (1) The value set gains `ask`,
> the command-line re-arm the phase I security lens asked for (Important 3):
> without it an operator inheriting a tracked `implementer` had no route back
> to a stopping gate. Sites 1, 2 and 4 and the identity clause move with it;
> site 3 (`"implementer": null`) does not. (2) Site 2 gains `\|` escapes: a
> raw pipe splits a table cell even inside a code span, so the row's Effect
> text was discarded when rendered — found by all three round-1 reviewers and
> deferred then precisely because it is pinned here. **The quoted G pair is
> re-pinned too, and that is the load-bearing part**: adding `ask` made the
> old first sentence FALSE (`ask` IS a set value, and G does stop on it), so
> leaving the pair frozen would have shipped the exact defect class this run
> spent three rounds hunting. (3) RE-PINNED A SECOND TIME later in round 4:
> the `ask` sentence first read "it records nothing", which a round-4
> reviewer showed reads as "writes nothing to `gates`" — against the rule
> that every gate records its answer. It now says `ask` pre-answers nothing
> and G records the owner's answer like any asked gate. The block above is
> the shipped text, and it is FOUR sentences, not the "pair" the headings
> below still call it.

## What must NOT move

- Suite counts: **house `1..121`, prose `1..11`** — AMENDED at phase M
  round 4, owner-ordered ("fix everything, no deferred"), which spent the
  prose-pin test debt. It read "house `1..119`, prose `1..9` — growth
  exactly zero" until then, and that is what P4 shipped through round 3.
  The +2 is one test for the G pre-answer contract and one for the consent
  sites outside the G slice. Any OTHER movement is still a finding.
- `handoff/**` — untouched (plan Decision 4).
- Every pinned string test 9 and the portability gates already guard.
