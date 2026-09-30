# Contract: the orchestrator's new sentences, and their pins

The orchestrator is prose. Its contract is the set of sentences that carry
each obligation, in the section that governs it. Every sentence below MUST
appear in `pipeline/skills/pipeline/SKILL.md` word for word (line breaks are
free: pins search the FLATTENED slice, except table rows, which are one line
and are pinned raw), inside the slice named, and MUST be pinned in
`pipeline/tests/prose.bats`. Surrounding prose is free to vary.

Slices use the suite's `prose_slice <open> <close> flat <name>` (raw for the
table slices), except the pre-flight walk, which keeps the awk range the suite
already uses for it (the walk holds a `**`-led line that `prose_slice` would
refuse) and asserts its own close:

| Slice | Open | Close |
|---|---|---|
| G | `^\*\*G — implementer gate\.\*\*` | `^The package carries seven parts` (the new pins; `prose_slice`, so the handoff package's bullets, addressed to another model, are outside it) |
| Walk | `^The script only reports; the decisions are yours` | `^\*\*Base branch:\*\*` (awk, as at `prose.bats:123`) |
| H | `^\*\*H — implement\.\*\*` | `^\*\*H\.5 — converge\.\*\*` |
| Gates | `^## Gates$` | `^## Parallel agents$` |
| Parallel | `^## Parallel agents$` | `^## The rules that never bend$` |
| Never-bend | `^## The rules that never bend$` | `^## Red flags` |
| Resume | `^## Resume$` | `^## Not in v1$` |
| Configuration | `^## Configuration$` | `^## Flags$` (rows CF1, CF3) |
| Flags | `^## Flags$` | `^## Pre-flight$` (rows C1, CF2) |

Measured at F (2026-09-29), on the seven slices the table held then (G to
Resume): each opened and closed on the file, each opener was unique, and no line inside Gates or Never-bend starts
with `**`. Backticks, dashes and quotes below are exact: `—` is U+2014.

## Changed on purpose (two existing pins)

**C1 — the `--auto` flags row** (`prose.bats:66`, whole row, raw, inside the Flags slice).

Old:
```
| `--auto` | Collapse the K and L gates to automatic. It collapses neither C, G nor O: C and O stop when they have something to ask, and G stops unless `implementer` pre-answered it. |
```
New:
```
| `--auto` | Collapse the K and L gates to automatic. It collapses neither C, G nor O: C and O stop when they have something to ask, and G stops for the review question on every fresh `claude` run, and for the implementer question unless `implementer` pre-answered it. It never collapses a pause. |
```

**C2 — the G pre-answer sentence** (`prose.bats:218`, G slice, flat).

Old: `When `implementer` resolves to `claude` or `handoff` (config or flag), G records that answer in `gates` and does not stop — the choice was typed on purpose.`

New (two sentences, both pinned):
- `When `implementer` resolves to `claude` or `handoff` (config or flag), G records that answer in `gates` and does not ask it — the choice was typed on purpose.`
- `With `claude`, G still stops for the review question below; with `handoff`, G does not stop.`

## New — G slice

- G1: `When the implementer answer is `claude`, G then asks the review question below, which nothing pre-answers.` (closes the lead paragraph; the lead's first sentence stays byte-identical)
- G2: `Once the implementer answer is `claude`, asked or pre-answered, G asks the review question — commits or pauses — and records the answer as `gates.G.reviewMode`, `commits` or `pauses`.`
- G3: `The review question is asked on every fresh `claude` run: no configuration key or flag pre-answers it, and `--auto` never collapses it.`
- G4: `When the implementer answer is `handoff`, G does not ask the review question and says so in one line: review pieces are not available on the handoff path, and the run keeps the single-commit flow.`
- G5: `A re-entry that finds `gates.G.reviewMode` recorded never asks it again, and no flag replaces it.`
- G6: `If a `--implementer handoff` typed on a re-entry replaces a recorded `claude`, the recorded review answer stays in the state file unused, commits already made stand, and the rest of the run follows the single-commit flow, saying so in that one line.`
- G7: `A re-entry into G whose state file already lists G as completed without `gates.G.reviewMode` does not ask it: that run started before the review question existed, or on the handoff path, and it keeps the single-commit flow for its life — it is never migrated mid-run.`
- G8: ``gates.G` is an object: `answer` holds the implementer answer and `reviewMode` the review answer. A state file whose `gates.G` is a plain string holds the implementer answer alone and has no review answer; read it that way, never as an error.`

No line of the G slice may start with `**` or `#` (`prose.bats:86`).

## New — H slice

- H0 (today's first H sentence, kept and now pinned): `The single-commit flow: invoke `/speckit-implement`.`
- H1: `Which flow H runs is read from `gates.G`: with `claude` recorded as G's answer and a review answer recorded beside it, H builds in pieces as below; otherwise H runs the single-commit flow, and says which flow it runs and why.`
- H2: `A run that enters H with implementer `claude` and no `gates.G.reviewMode` — it started on an older pipeline, or it began on the handoff path — keeps the single-commit flow and says so.`
- H3: `H builds a piece by invoking `/speckit-implement` limited to that piece's task IDs — never unscoped, which would build every piece at once.`
- H4: `Before the first piece, H commits the feature's spec directory alone, every path named, as `docs(spec): <feature>`, and records it with `commit-add` as kind `spec`.`
- H4b: `A spec commit already recorded is never made again; one already in `<base>..HEAD` with that subject but not recorded is recorded from that commit, not made again.`
- H5: `Then H loops: `piece-next` names the next piece; H builds that piece's tasks; H commits exactly the paths the piece changed, plus `tasks.md` with the piece's `[X]` marks; and H records the commit with `commit-add` as kind `piece`, with the piece's name, task IDs and files. The loop ends when `piece-next` prints nothing.`
- H6: `A `piece-next` refusal is a hard failure: H stops per "When a phase fails" and never falls back to the single-commit flow.`
- H7: `When a piece starts — unless `measurements.pieceBefore` already names that piece, whose saved list then stands — H saves every path `git status --porcelain=v1 -z --untracked-files=all --no-renames` lists under `measurements.pieceBefore`, with the piece's heading; the piece's paths are the ones that command lists after the piece and that are absent from the saved list, plus `tasks.md`, and a resumed piece is compared against the saved list, never against the tree as it stands. A path under `.delivery-kit/` is never a piece's path, even where that directory is not ignored.`
- H7b: `Read that output as NUL-separated records, never through `$( )`, which drops NUL bytes and runs the paths together: take each path after its three-character status prefix, and refuse a path that holds a carriage return or a line feed.`
- H8: `Every commit H makes names every path it stages — no `git add -A`, no wildcards, no directory: write the paths NUL-separated to a file under `.delivery-kit/runs/<feature>/`, stage with `git --literal-pathspecs add --pathspec-from-file=<file> --pathspec-file-nul` and commit with `git --literal-pathspecs commit -F <message file> --pathspec-from-file=<file> --pathspec-file-nul`, so git reads no path as a pattern, no path is typed into a command, and nothing else staged rides along.`
- H9: `The message follows `commitStyle`, names the piece and its task range, says so where the piece changed no file but `tasks.md`, and carries, on a line of its own, `Piece: <heading>`.`
- H10: `The heading travels as data: in the same shell call that commits and records, run `piece-next` again, split its output with parameter expansion, write the `Piece:` line into the message file with `printf '%s'`, and pass the heading quoted to `commit-add` — never retype it into a command, since shell state does not survive from one call to the next.`
- H11: `If a commit in `<base>..HEAD` that `commits` does not record carries, as a whole line, `Piece: <heading>` for the piece `piece-next` names, the piece was committed before a crash: record it from that commit with `commit-add` and move on — never rebuild it.`
- H12: `A recorded piece is never rebuilt.`
- H13: `In pause mode, after a piece is built and before it is committed, H stops and shows the piece name, its task IDs, the exact file list, `git diff --stat` for those files with each untracked file listed as new, and the piece's checkpoint result where the tasks file names one.`
- H14: `Three answers: go on (commit it and continue); fix this (the developer says what, the run changes it and shows the piece again); stop here (the `--until` rule binds: state file intact, lock released, resumable).`
- H15: `Files the developer edited during the pause go into that piece's commit, and its message lists them as edited by the owner: a path new to the list, or one whose content changed since the pause showed it — never a path in the saved list, which stays for K.`
- H15b: `When the list has changed since the pause showed it, the piece is shown again before it is committed.`
- H16: `A pause is a safe handoff point, like every gate, and `--auto` never collapses a pause.`
- H17: `A commit hook that rejects a piece commit is a hard stop: the piece stays uncommitted, `gates.H` records a failure entry naming the piece and the hook's output, redacted as J's carry is — the fact and its location, never the value — and the run stops per "When a phase fails".`
- H18: ``--no-verify` is never used, for a piece commit or any other.`
- H19: `A piece is built when every task ID `piece-next` names for it is marked `[X]` in `tasks.md`. On resume, a built piece that is not yet committed is handled first and never rebuilt: a piece a hook rejected is shown first with its failure entry, in either mode, and then committed again (commits mode) or paused (pause mode), its failure entry cleared once the commit lands; any other built piece is shown again in pause mode and committed in commits mode.`
- H20: `In the piece flow, fan-out stays within one piece: it never crosses a piece boundary.`
- H21: `Each pause answer is recorded under `gates.H.pauses`, with the `git hash-object` of each listed path (or `deleted`) as the pause showed it; a recorded answer never stops a built, uncommitted piece from being shown again.`
- H22 (today's sentence, kept and now pinned): `Record `last_task` after each completion so resume re-enters mid-phase.`

The existing fan-out, board and `last_task` sentences ("Fan independent
tasks of the same phase … so resume re-enters mid-phase.") appear ONCE in H,
after both flows, shared by them; H20 qualifies them for the piece flow.

## New — Gates slice

The "Up to five stops" paragraph becomes:

> Up to five gates stop a fresh run — a gate with nothing to ask (no clarify
> questions at C; a pre-answered `handoff` at G; `releaseCommand` unset at O)
> records that and moves on. C, G and O can each have nothing to ask; K and L always have content, and stop
> unless `--auto` collapsed them or a degradation named at pre-flight (no
> remote, no `gh`) already reduced them. [GT1]

(H.7 removed a closing sentence here, "G's pre-answer is the configured
answer recorded rather than asked — and with `handoff` the run still parks
at H per the G text": C2 and GT1 already say the first half, GT2 the second.)

The floor paragraph becomes `State the floor honestly. [GT2] [GT4]`, and the
"That combination" paragraph begins with GT5 and keeps its last two
sentences ("That gap is exactly why … `--auto-release` is still required
before anything publishes unasked.").

- GT1: `A pre-answered `implementer` removes the implementer question, never the review question, so G stops on every fresh `claude` run.`
- GT2: `No fresh run reaches DONE without a stop: on a `claude` run G stops for the review question, and on a `handoff` run the run parks at H.`
- GT2b: `A re-entry past G asks nothing there and so can reach DONE with no gate stopping it — for example a run resumed from an older pipeline that had completed G (see G), or a run re-entered with `--from H` or later.`
- GT3: `A pause (H, pause mode) is a stop the developer chose, not a sixth gate, and `--auto` never collapses it.` (after the conditional-stops paragraph)
- GT4: `Nothing outside the gate table is silenced by `--auto` — the pre-flight constitution offer, every cap breach, a missing required tool, any hard failure and a failed runtime check all still stop.`
- GT5: `The `implementer` key can arrive from a tracked `.delivery-kit.json` somebody else wrote, in a repository just cloned, and it removes the implementer question without anyone at the keyboard choosing that.`
- GT6 (row, raw): `| Implementer | G | Claude, or a handoff package for a cheaper model; then, for Claude, commits or pauses |`

## New — other slices

- P1 (Parallel): `grouped by target artefact; H — independent tasks within one piece; fan-out never crosses a piece boundary; H.5`
- N1 (row, raw, Never-bend; its left cell unchanged): `| `git add -A`, or staging by wildcard | Every commit names every path it stages, not only K's. A wildcard is how an unrelated file, a secret, or another session's work gets committed. |`
- N2 (Never-bend, MAY-do): `read as paralysis: create and check out the feature branch, make the local spec and piece commits H makes once G's review question is answered, every path named and nothing pushed, write`
- N3 (Never-bend, MAY-do's closing sentence, replacing "Everything that leaves the machine, or that cannot be undone by editing a file, is behind a gate."): `Everything that leaves the machine, or that cannot be undone by editing a file, is behind a gate — H's local commits included: the review question at G is their consent, and in pause mode each pause is the yes.`
- R1 (Resume): `Re-entering H in the piece flow — `--resume` or `--from H` — enters the piece `piece-next` names, under H's rules: a recorded piece is never rebuilt, and a built piece not yet committed is handled first.`
- PF1 (Walk, pre-flight item 9): `The offer is a conditional stop that `--auto` does not collapse — like C, and like G, which asks its review question on every fresh `claude` run and its implementer question whenever `implementer` is unset or `ask`, it needs an answer only the owner can give, and no answer is ever invented for it.`
- CF1 (row, raw, Configuration): `| `implementer` | unset | Pre-answers G's implementer question: `claude` or `handoff`; `ask` restores the stop. It never pre-answers the review question |`
- CF2 (row, raw, Flags): `| `--implementer <claude\|handoff\|ask>` | Pre-answers G's implementer question, or restores it with `ask`; beats the config key. On a fresh run that resolves to `claude`, the review question is still asked. |`
- CF3 (row, raw, Configuration): `| `commitStyle` | `conventional` | The message shape of every commit the run makes |`

## Absent (SC-004, negative pins)

Each string below is in the file at `b0b3f1b` and MUST be absent after
(`grep -cF` = 0 on the flattened file), with a positive control proving the
same grep finds it in `$RUN/SKILL.md.orig`:

- `a run CAN reach DONE without a single gate stopping it`
- `a pre-answered `implementer` at G;`
- `but no gate does`
- `like G whenever `implementer` is unset or `ask``
- `Pre-answers the G gate`
- `Phase K's message shape`
- `G stops unless `implementer` pre-answered it` (the old `--auto` row's clause; C1's row pin alone would not catch it moved elsewhere)
- `G records that answer in `gates` and does not stop` (the old C2 sentence, for the same reason)
- `That combination is never a default` (the old paragraph after the floor)
- `| Implementer | G | Claude, or a handoff package for a cheaper model |` (the old gate-table row)
- `cannot be undone by editing a file, is behind a gate.` (MAY-do's old closing sentence)

## Test blocks

| Test | Pins | FR |
|---|---|---|
| G asks the review question on every run and never lets --auto collapse it | C2 (in the existing G test), G1–G6, G8 | 001–005 |
| H commits the spec, then one commit per piece, every path named | H1, H3–H12 (with H4b), H20, H22 | 006–011, 017 |
| a pause shows the piece, takes three answers, and --auto never collapses it | H13–H16, H19, H21 | 012–014, 016 |
| a hook that rejects a piece commit is a hard stop, never --no-verify | H17, H18 | 015 |
| a state file without a review answer keeps the single-commit flow | H2 (H), G7 (G), R1 (Resume) | 016, 018 |
| the gate floor counts the review question, and every commit names every path | C1 (in its existing test), GT1–GT6 (with GT2b), P1, N1–N3, PF1, CF1–CF3, the absent strings | 019–023 |

The pin IDs in this file are the mutant list: the rig (tasks T003, T027) reads every ID from the bullets above, and fails unless mutants = IDs = new pins in `prose.bats`.

Each pin is proven by an INVERTED mutant: the sentence rewritten to assert the
opposite (for example G3 → "`--auto` collapses it"), the mutated line echoed,
the test red. Each absent string is proven by a mutant that restores it. A
no-op mutant fails the rig.

## Recorded departures

- **G5/G6 vs the seed** (seed requirement 5: the review answer "holds for the
  life of the run"). A `--implementer handoff` flag on a re-entry wins under
  the existing G rule, and the handoff path cannot make commits, so the answer
  cannot keep governing that run. It is kept, unused, and the notice says so.
  No flag replaces the review answer itself.
