# Key contract — `implementer`, its flag, and the quoted G sentences

## The four documentation sites (exact strings)

1. Orchestrator Configuration table (`pipeline/skills/pipeline/SKILL.md`), appended row:

   ```
   | `implementer` | unset | Pre-answers the G gate: `claude` or `handoff` |
   ```

2. Orchestrator Flags table (same file), appended row:

   ```
   | `--implementer <claude|handoff>` | Pre-answers the G gate; beats the config key. |
   ```

3. `pipeline/docs/configuration.md` JSON block, appended entry (before the closing brace):

   ```
   "implementer": null
   ```

4. `pipeline/docs/configuration.md` key table, appended row:

   ```
   | `implementer` | Pre-answers the implementer gate: `claude` or `handoff`; unset means ask. |
   ```

Identity binds the key name, the value set (`claude`, `handoff`), and
the default (unset — rendered `unset` in the orchestrator's default
column and `null` in the JSON block, the files' existing convention for
`verifyCommand`/`releaseCommand`). Description prose follows each
table's own style (research R1).

## The quoted G sentences (verbatim, from the plan of record)

> When `implementer` is set (config or flag), G records the configured
> answer in `gates` and does not stop — the choice was typed on
> purpose. Everything else about G is unchanged, and a set
> `implementer` silences nothing else: cap breaches, hard failures and
> every other gate still stop exactly as before.

Placed directly after "`--auto` never collapses this gate: it spends
money." (research R2). No existing sentence reworded; the Gates-table
row `| Implementer | G |` byte-identical.

## The docs paragraph (FR-004, STRICT surface)

One paragraph in `pipeline/docs/configuration.md`, its own section:
what the key pre-answers (the implementer gate's Claude-or-handoff
question), that unset means ask, and that it exists so an `--auto` run
touches the human at clarify only. No banned spellings.

## What must NOT move

- Suite counts: house `1..119`, prose `1..9` — growth exactly zero.
- `handoff/**` — untouched (plan Decision 4).
- Every pinned string test 9 and the portability gates already guard.
