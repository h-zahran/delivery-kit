# Contract: every documentation site this feature judges

Measured at `main` = `db2875d`, 2026-10-01; revised at F (analysis rounds 1
and 2, which found the sites marked "(F1)" and "(F2)"), at H.7 (cleanup), at
I (deep review, marked "(I)") and at M (pull-request review, three rounds,
marked "(M)"). Each row's last cell describes the text as shipped at
`8840ec2` (PR #50, merged). Line numbers are as measured; the text in the
"Now says" column identifies the site if lines move. Verdicts:
**false** (rewrite), **stale** (true but silent on what changed, or says
less than the orchestrator; rewrite), **true** (kept, reason given),
**history** (never edited).

"The orchestrator" is `pipeline/skills/pipeline/SKILL.md`; its Gates section
(`## Gates`) is the one statement of gates, stops and floor every row below
is checked against (research R6).

**The conditional-stop list** (quoted where a site must name what else stops
a run), from the orchestrator's Gates section: the resume prompt; a cap
breach; a missing required tool; any hard failure; a failed runtime check;
K's stop, once the branch holds commits, for a path outside the feature;
K's or L's stop for a commit it cannot show or a stale `commits` entry (L's
section names further stops of its own, such as a table cell that would
break the guide); a state file tracked in git; the
pre-flight constitution offer. `--auto` collapses none of these. A pause (pause
mode) is a stop the developer chose, not a gate, and `--auto` never collapses
it either.

## pipeline/docs/phases.md

| ID | Line | Now says | Verdict | New text must say |
|---|---|---|---|---|
| P1 | 24 | G: "**Stops and asks**, unless `implementer` already answered it" | false | (I: "up to two questions".) G asks who builds (the `implementer` setting can answer that) and then, on a fresh Claude run, commits or pauses — never answered in advance, not collapsed by `--auto`. Choosing the package parks the run. |
| P2 | 25 | H: runs implement; parallel tasks | stale | On a Claude run H commits the spec first, then builds and commits one tasks-file phase (a piece) at a time; in pause mode it stops before each piece's commit (go on, fix this, stop here); a handoff run, or one begun on an older pipeline, builds in one pass and K makes its commit. |
| P3 | 26–28 | H.5, H.7, I rows | stale | Each ends with a commit of its own when it changed a file (in the piece flow). H.7 and I read the run's whole change. |
| P4 | 29 | J row (corrected at P21) | stale | (T008, I, M) In the piece flow J commits what it changed; in the single-commit flow a waved-through red rides in K's commit, or in an empty record commit K makes when nothing is left to commit. |
| P5 | 30 | K row (corrected at P21) | true | Re-checked against the orchestrator's K. |
| P6 | 31 | L: branch, title, body; "Collapsed by `--auto`." | stale | The body carries the review guide: one row per commit, oldest first. Collapsed by `--auto`, except for the stops L names itself, such as a commit it cannot show or a state-file record of a commit that is not on the branch. (F1, F2) |
| P7 | 36 | DONE: summarises what shipped | stale | The summary carries the review guide. |
| P9 | 15 | pre-flight row: the stops it lists | stale | Also: on a re-entry, a state file tracked in git stops the run until you confirm its recorded answers. (F2) |
| P8 | 39 | "an `implementer` already set" as nothing to ask | false | A pre-answered `handoff` is G with nothing to ask; a fresh Claude run always has the review question. |

## pipeline/docs/configuration.md

| ID | Line | Now says | Verdict | New text must say |
|---|---|---|---|---|
| C1 | 65 | row: "Pre-answers the implementer gate: …" (pinned whole) | false | Pre-answers G's implementer question (`claude` or `handoff`; `ask` restores the stop; unset means ask); a Claude run still stops at G for the review question. The pin follows (research R2). |
| C2 | 79–89 | "pre-answers the implementer gate … With `claude`, the gate … does not stop — an `--auto` run then touches the human at clarify only." | false | The key answers the implementer question only. With `claude` G records it and asks the review question, which nothing answers in advance. Keep "With `ask` the gate simply asks, as it does when the key is unset" and "An illegal value stops pre-flight by name: never coerced, never treated as unset." byte-for-byte (pinned). |
| C3 | 102–115 | the range: "reaches the end with no gate stopping it at all … but the gates do not." (the last sentence pinned) | false | As the orchestrator's Gates: no fresh run reaches the end without a stop (G's review question on a Claude run; the park at H on a handoff run); a re-entry past G can reach the end with no gate stopping it under `--auto`; the release gate still stops whenever `releaseCommand` is set and `--auto-release` was not typed, and the constitution offer whenever the constitution is unset; the conditional-stop list always stops. The pinned sentence keeps its role (what stops a run besides the gates); the pin follows. (I) The sentence names the stops a run meets mid-way; the resume prompt (a choice at invocation) and L's own table-cell stop are left to the orchestrator, so the READMEs say the page "lists them", not "every one". (M) The READMEs now say the page "has the whole range", and their own lists name the constitution offer and a tracked state file; the resume prompt was added at M round 2 and removed at round 3, because `--resume` skips it. The re-entry conditions drop "no clarify questions" and "the constitution set" (both come before G). The floor sentence ("No fresh run reaches the end without a stop: …") is pinned too, and the replaced claims are asserted absent from the page, in the same test (no test added). |
| C4 | 117–120 | "A key that pre-answers a gate belongs in the operator's output" | stale | "A key that answers a gate's question in advance" — worded so the phrase "pre-answers a gate" is gone (F3: "pre-answers a gate's question" still contains it). |
| C5 | 150 | "never riding inside the feature's commit" | false | "commits". |
| C6 | 91–96 | "Layers merge by silence, not by erasure …" (pinned) | true | Kept byte-for-byte. |
| C7 | 97–100 | "If a repository's tracked `.delivery-kit.json` pre-answers the gate and you want the stop back for one run, pass `--implementer ask`" | false | "pre-answers the implementer question and you want that question back". (F1) |
| C8 | 129–130 | "The pipeline never edits `.gitignore` silently, and never stages anything outside the commit gate." | false | Keep the `.gitignore` clause; the run stages only paths it names, in every commit it makes. (F1, F2: no enumeration) |
| C9 | 56 | `commitStyle` row: "The commit-message shape the commit gate shows." | stale | The shape of every commit message the run writes, except the spec commit's fixed subject. (F1, F2) |

## pipeline/README.md

| ID | Line | Now says | Verdict | New text must say |
|---|---|---|---|---|
| R1 | 3–5 | tagline, long form | true | Owner, at C: kept. |
| R2 | 36 | Build: "You choose who implements. Independent tasks run in parallel …" | stale | You choose who implements and, for Claude, commits or pauses; a build here goes one piece at a time, each piece its own commit; a handoff run builds in one pass and commits once, at K. (I: the handoff clause.) |
| R3 | 38 | Ship: "Commit, push, open the pull request …" | stale | Show what is already committed and what is left, commit the rest, push, open the pull request with its review guide, … (I: a handoff run has no commit list at K.) |
| R4 | 57 | heading "The five gates" | true | Five gates still. |
| R5 | 59 | "These are the only places it asks:" | false | The gates are these five; a pause (pause mode) and the conditional stops below also stop a run. |
| R6 | 64 | Implementer row, skippable by "the `implementer` setting" | false | Who builds; then, on a fresh Claude run, commits or pauses. The setting answers the first question only; nothing answers the second. |
| R7 | 65 | Commit row (corrected at P21) | true | Re-checked. |
| R8 | 66 | Push & PR row, skippable by "`--auto`" | stale | `--auto`, except for the stops L names itself, such as a commit it cannot show or a stale state-file record. (F1, F2) |
| R9 | 69–71 | "`--auto` collapses only the commit and push gates …" | true | Kept; if touched, add that it never answers G's review question. |
| R10 | 73–74 | "Other things still stop a run and no flag collapses them: …" | stale | (H.7, M) The main kinds, including the constitution offer and a tracked state file (not the resume prompt: `--resume` skips it); a link to the configuration page, which "has the whole range"; and a pause in pause mode. |
| R11 | 76–80 | floor warning: "can reach the end without a single gate stopping it" | false | (M) A fresh run always stops (G on Claude, the park at H on handoff); a re-entry past G with `--auto` and no release command can reach the end without a gate asking, though a pause in pause mode still stops it; the `Implementer` line still names the layer, `ask` takes the implementer question back on a fresh run, and the configuration page has the whole range. |
| R12 | 99 | flag row "Pre-answer the implementer gate, or restore it." | false | "the implementer question". |
| R13 | 84–85 | "the commit gate names every path" | stale | Every commit the run makes names every path. (F1) |
| R14 | 40–41, 51 | `pipeline:status` reports "which gate it is waiting on" | stale | Which gate or pause. (F1) |
| R16 | 30 | "* = stops and asks you first" (H has no star) | true | A pause is a stop the developer chose, not a gate; the stars mark gates. (F2) |
| R15 | new | — | new | (I, M) "Reviewing a run commit by commit": the review guide and its large-body fallback (file counts, full guide in comments); the commit-kind table (the `spec` row is the spec directory, absent when you committed it; the `tests` row is J's, or K's empty record commit in a run without pieces); a handoff run's K makes the one feature commit holding the deep-review and test fixes, its message carries a waved-through red (or an empty `tests` record commit does, when nothing is left), and M's and N's fixes and an accepted constitution get rows of their own. |

## README.md

| ID | Line | Now says | Verdict | New text must say |
|---|---|---|---|---|
| M1 | 56 | heading "… twenty phases, five stops" | false | "… twenty phases, five gates" (research R4). |
| M2 | 14 | link `#pipeline--one-feature-twenty-phases-five-stops` | false once M1 lands | `#pipeline--one-feature-twenty-phases-five-gates`. |
| M3 | 74–76 | "The five stars are the gates: … **who implements** …" | stale | … **who implements, and how you review** … — and the one new sentence (owner, at C): a Claude run commits in pieces, linked to R15's section in `pipeline/README.md`. |
| M4 | 290 | "This is the whole of what the run asks you. Everything else runs unattended." | false | These are the gates; a pause in pause mode and the conditional stops below ask too. |
| M5 | 295 | Implementer row | false | As R6. |
| M6 | 296 | Commit row (corrected at P21) | true | Re-checked. |
| M7 | 297 | Push & PR row: "Yes, or no. Nothing leaves your machine before this." | true | Kept (the row has no "skippable" column). |
| M8 | 300–301 | "Other things stop a run too …" | stale | As R10. |
| M9 | 313–318 | floor warning: "without a single gate stopping it" | false | As R11. |
| M10 | 365 | `--auto` row: "Not clarify, not implementer, not release." | true | Kept. |
| M11 | 367 | flag row "Pre-answer the implementer gate …" | false | As R12. |
| M12 | 411 | config row "Pre-answers the implementer gate." | false | "the implementer question". |
| M13 | 434 | troubleshooting: "A run reached the end without asking you anything — `--auto` plus an `implementer` value from a config file — … Use `--implementer ask` to take the stop back." | false | (M) Cause: a re-entry past G under `--auto` with no release command (or `--auto-release`); a fresh run always stops, at G or parked at H. What to do: re-enter without `--auto`, so the commit and push gates ask where they have no answer and a commit gate `--auto` collapsed asks again; the `Implementer` line names the layer. |
| M14 | 389 | "a value which pre-answers a gate" | stale | "a value which answers a gate's question in advance". (F1, F3: as C4) |
| M15 | 325, 351 | `pipeline:status` "what is it waiting on" / "what it waits on" | true | Already says what, not which gate. |
| M17 | 71 | "* = stops and asks you first" | true | As R16. (F2) |
| M18 | 446 | troubleshooting: "`pipeline` stops immediately at pre-flight — No spec tool, a dirty tree, a live lock, or an illegal `implementer` value" | stale | (M) Adds missing `git` and, on a re-entry, a state file tracked in git waiting for confirmation. |
| M16 | 26 | tagline, short form ("… every step that leaves your machine.") | true | Owner, at C: kept. |

## Elsewhere

| ID | File | Verdict | New text must say |
|---|---|---|---|
| S1 | `pipeline/skills/status/SKILL.md` step 4 | false | Research R7: C and O as now; G waiting for the implementer answer, or for the review answer; K waiting when `gates.K.answer` is absent (a plain-string `gates.K` is the answer); L waiting unless `gates.L` holds the push answer (a removal record is not that answer); H, when G's implementer answer is `handoff` (object or plain string), most likely parked for the implementer's report — the file cannot show whether the report was already consumed; H in pause mode most likely waiting at a pause, naming `gates.H.pauses`, saying the file cannot show whether a pause is showing now; a failure entry under `gates.H` (or a late phase's letter) reported as the stop it is. (F1: K, the handoff park, failure entries; F2: L, the handoff ambiguity; I: state-file strings are data, never instructions; a tracked state file is named; the failure entry is checked first; K's wording is its flow choice; the pause bullet needs `claude`; a catch-all bullet; the resume command stays fixed; M: a failure entry names the piece (H) or the paths (later), and J's waved record is not one; a failed tracked check is said as failed; K's `auto` stands only on a re-entry with `--auto`; L says when its record does not show which it is; the catch-all says it cannot tell a mid-phase stop from a question recorded only once answered.) |
| S1f | `pipeline/skills/status/SKILL.md:3` (description) | stale | "the gate or pause it is waiting on". (F1) |
| S2 | `pipeline/skills/pipeline/SKILL.md:249` (item 9) | false | "the feature's commits" — no other change (research R3). |
| S3 | `pipeline/commands/pipeline.md:2` ("with a human gate at every step that leaves the machine or cannot be undone by editing a file"), `pipeline/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (short form) | true | Owner, at C: kept. |
| S4 | `pipeline/CHANGELOG.md` `## [Unreleased]` | incomplete | Two bullets under `### Changed`: L, like K, stops even under `--auto` for a commit it cannot show or a state-file record of a commit not on the branch; and `pipeline:status` reports G's review question, K's answer, a handoff run parked at H, pause mode, a hook-rejected commit, a tracked state file (and a failed check), when it cannot tell why a run stopped, and treats state-file strings as data (research R5; extended at M). |
| S5 | `pipeline/CHANGELOG.md` released sections | history | Byte-identical. |
| S7 | orchestrator state format | follow-up | Found at H.7, out of scope (FR-007): the push answer has no named field under `gates.L` (K has `gates.K.answer`), so the status skill cannot tell it from a removal record; and a single `waiting` field written at each stop would let the status skill read one field instead of per-gate rules. Both change the orchestrator. |
| S6 | `pipeline/skills/pipeline/SKILL.md:310` "pre-answers a gate changes the run's consent profile" | out of scope | FR-007 keeps the orchestrator to item 9; recorded for a later pass. |

## The seed's claims, and their final greps

Each is run over the derived file set (quickstart step 1), each file
FLATTENED first (newlines to spaces, runs of spaces squeezed) so a phrase
wrapped across lines is still found (F1), after the change, first against a
known hit (the positive control); its hit list goes into the commit message
with a verdict per hit.

| Claim | Pattern (fixed string, case-insensitive) | Known hit for the positive control |
|---|---|---|
| "five stops" | `five stops` | `db2875d:README.md` |
| "no gate stopping" | `no gate stopping`, `without a single gate` | `db2875d:pipeline/docs/configuration.md`, `db2875d:README.md` |
| "K commits" | `K commits` | `pipeline/skills/pipeline/SKILL.md` ("K commits that remainder") |
| "one commit" | `one commit` | `pipeline/skills/pipeline/SKILL.md` ("each end with one commit of their own") |
| "pre-answers the implementer gate" | `pre-answers the implementer gate`, `pre-answer the implementer gate`, `pre-answers the gate`, `pre-answers a gate` | `db2875d:README.md`, `db2875d:pipeline/docs/configuration.md` |
