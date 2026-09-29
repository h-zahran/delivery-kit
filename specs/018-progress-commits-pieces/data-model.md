# Data model: progress.sh learns commits and pieces

## Run state file — the `commits` key

Location: `.delivery-kit/runs/<feature>/progress.json`. `init` creates
`commits` as `[]` (`pipeline/scripts/progress.sh:72`). This feature does not
change `init` or `validate`.

The list may hold two entry shapes, in any order.

### Commit record entry (written by `commit-add`)

| Field | Type | Rule |
|---|---|---|
| `sha` | string | exactly 40 characters, each `0-9` or `a-f` |
| `kind` | string | lowercase letters only, and one of `spec`, `piece`, `converge`, `simplify`, `review`, `tests`, `constitution`, `other` |
| `piece` | string | the piece heading text after `## `; never holds CR, LF or U+001F; required non-empty when `kind` is `piece`; may be empty otherwise |
| `tasks` | array of strings | split from one comma-separated argument; `[]` when the argument is empty; required non-empty when `kind` is `piece` |
| `files` | array of strings | one per remaining argument, in order; may be `[]` only when `kind` is `tests` |

Field order in the written object: `sha`, `kind`, `piece`, `tasks`, `files`.

### Old-style entry (written by earlier runs; never written again)

A bare JSON string. Measured shapes: a 7-, 9- or 40-character id, or an id
followed by a space and a commit subject. Read only by the duplicate check,
through its first space-separated word. Never modified, never removed, never
counted as a piece.

## Identity and uniqueness

- A commit is identified by its full `sha`. At most one object entry per
  `sha`.
- An old-style entry claims every full id that starts with its first word,
  when that word is 7 to 40 lowercase hex characters.

## Transitions

`commit-add` classifies the incoming call, then:

| Classification | Condition | Effect |
|---|---|---|
| `new` | no entry claims the id | append one object; exit 0 |
| `same` | an object entry has this `sha` and equal `kind`, `piece`, `tasks`, `files` | no write; exit 0 |
| `conflict` | an object entry has this `sha` with any field different | no write; exit 1, "with different details" |
| `legacy` | an old-style entry claims the id | no write; exit 1, "by an old-style entry" |

The classification step prints exactly one of these four words. Anything
else — nothing, two lines, another word — is a failure of the step itself,
and stops the command by name rather than falling through to a write.

## Piece (derived, never stored as its own record)

Derived from the tasks file named in `artifacts.tasks`:

- **Heading**: a line starting `## Phase `, whose text matches digits, optional
  lowercase letters, then `:`. The piece's identity is the line after `## `,
  with ONE trailing CR removed.
- **Extent**: from the heading to the next line starting `## ` (not `### `).
- **Task ids**: `T<digits>` from lines starting `- [ ] `, `- [X] ` or `- [x] `
  inside the extent, in file order.
- **Is a piece** only when it has at least one task id.
- **Cannot be offered** when its identity still holds a CR or U+001F: the
  next piece in that state is refused by name (`bad`), never printed.
- **Recorded** when an object entry of kind `piece` or `converge` has `piece`
  equal to the identity, byte for byte.
