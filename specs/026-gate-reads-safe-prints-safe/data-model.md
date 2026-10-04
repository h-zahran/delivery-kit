# Data model: what the gate reads, and what it prints

No stored data. The entities are the inputs the gate reads and the values
it prints.

## A plugin's changelog, before it is read

| Shape | Default form | Release form, for the named plugin | Message |
|---|---|---|---|
| a symbolic link (any target, or none) | refused | refused | `<plugin>: CHANGELOG.md is a symbolic link, which the gate does not follow` (+ ` — this tree is NOT released` for the named plugin) |
| exists, not a regular file | refused | refused | `<plugin>: CHANGELOG.md is not a regular file` (+ the same suffix) |
| missing | the gate's own diagnostic only | the gate's own diagnostic only | `<plugin>: no changelog heading in the pinned '## [X.Y.Z] - YYYY-MM-DD' format`, with no `grep:` line before it (research R11) |
| regular, over 262,144 bytes | read as today | refused, before the NUL check | `<plugin>: CHANGELOG.md is <n> bytes, more than the release form reads (<limit>) — this tree is NOT released` |
| regular, at most the limit | read as today | read as today | — |

Order inside the loop: link, then not-regular, then size (release form,
named plugin, read inside the existing `[ -f ]` block), then NUL, then
everything as at `4016666`.

## A plugin's `plugin.json`

Read with `jq` through standard input (`jq … < "./$p/.claude-plugin/plugin.json"`),
never as a path argument: `jq`'s own errors then say `<stdin>` and never
print the directory name, and native Windows `jq` does not have to open a
path it cannot open (research R4, R11).

## A printed value

Every value of the spec's print-site table passes once through
`shown <name> <value>` into a `_s` copy, where it is read:

1. cut at the quote cut (200 bytes, under the C locale), followed by the
   cut marker ` [cut]` when it was longer;
2. every byte outside space to `~` shown as `?`.

The report line's first field also has its leading spaces, and a `:` that
directly follows them (or starts the field), shown as `?`.
Comparisons always use the raw value; only output uses the copy. The
gate's own message text never passes through `shown`.
