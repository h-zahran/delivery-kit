# Contract: commit trailers

## Spellings

| Spelling | Layer | Effect |
|---|---|---|
| `commitTrailers` key | a configuration file | The team's list. A later file's list replaces an earlier one's. |
| `--trailer <token: value>` flag | the command line, repeatable | Adds one trailer after the key's. Never replaces the key. |

The orchestrator passes the resolved list to pre-flight as `--trailer <text>`, once per trailer, the key's first, on a fresh run only. Pre-flight reports `commitTrailers`, an array in the same order.

## Refusals

Each exits non-zero. Each message names the trailer and `--trailer`.

| Trailer | Message part |
|---|---|
| holds CR or LF | `holds a line break; a trailer is one line` |
| no `:` | `has no ':'; write <token>: <value>` |
| token empty or outside `[A-Za-z0-9-]` | `a token holds letters, digits and dash only` |
| value empty or only spaces | `has an empty value` |
| token `Piece` or `Late`, any letter case | `reserved for the run's own markers` |

## Commits that carry the list

The spec commit (subject unchanged), each piece, each late commit, J's empty record, K's commits, the constitution's commit. Not the handoff path's external commits.

## Mechanism

For each trailer, before the message is shown or used:

```
git interpret-trailers --in-place --if-exists addIfDifferent --trailer <trailer> <message file>
```

## Pinned strings

| Site | Pinned text |
|---|---|
| SKILL.md Configuration table | the whole `commitTrailers` row |
| SKILL.md Flags table | the whole `--trailer` row |
| SKILL.md probe block | the `Trailers` line |
| SKILL.md **Trailers:** | the add rule, the reserved-token rule, the list of commits, the before-shown rule, the command, the resume rule, the resume probe-line rule |
| `pipeline/docs/configuration.md` | the bold add rule and its sentence |
| `pipeline/CHANGELOG.md` | the bold lead of the entry |
