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
| token `Piece`, `Late` or `Tasks`, any letter case | `reserved for the run's own markers` |

## Commits that carry the list

Every commit a `progress.sh` subcommand makes: `spec-commit` (subject unchanged), `piece-commit`, `late-commit` (J's `--record` included) and `remainder-commit` (kinds `other` and `constitution`). Not the handoff path's external commits.

## Recorded shape

`config.commitTrailers`: an array of `<token>: <value>` strings, the list pre-flight reports, in order. `config.commitTrailersFrom`: each entry's layer, in the same order, for the probe line. Missing, `null` or `[]` means no trailers.

## Mechanism

`with_trailers <message file>` in `progress.sh`, called by `commit_named` and by J's `--record` commit:

1. Read `config.commitTrailers`. Anything but an array of one-line strings stops, naming the state file. No commit is made.
2. Check each entry as pre-flight does. A bad one stops, naming it.
3. Copy the message to `<run dir>/trailers-msg.txt`, and commit the copy. The caller's file is never rewritten.
4. Add every trailer in one call:

```
git -c trailer.separators=: interpret-trailers --in-place --no-divider --where end \
  --if-exists addIfDifferent --if-missing add --trailer <t1> --trailer <t2> ... <copy>
```

Each placement is named on the command line, so no `trailer.*` setting in the owner's git configuration changes the result.

## Pinned strings

| Site | Pinned text |
|---|---|
| SKILL.md Configuration table | the whole `commitTrailers` row |
| SKILL.md Flags table | the whole `--trailer` row |
| SKILL.md probe block | the `Trailers` line |
| SKILL.md **Base branch:** pointer | `commitTrailers` and `--trailer` in the list of names that send the run to the docs page |
| `pipeline/docs/configuration.md` | the bold add rule and its sentence, the reserved-token rule, the pre-flight argument, the recorded shape, the list of commits, the no-hand-trailer rule, the resume rule |
| `pipeline/CHANGELOG.md` | the bold lead of the entry |
