# Data model: the two merged reads

## Field

`<bytes>:<value>` — `<bytes>` is the value's length in UTF-8 bytes
(`utf8bytelength`), decimal digits only; `<value>` is exactly that many
bytes. A record is fields in a fixed order, then `.`.

Cut by the gate under `LC_ALL=C`. Refused, as "could not be read" for
that file: a length that is not all digits, a length past the end, a
missing `.`, or bytes left over after the last field.

## The marketplace record (one per run)

Written only when `market_shape` holds (else `false`, exit 1; or jq's
error status for text that is not JSON). Not length-prefixed: one field,
the rest of the output.

| Order | Value | Replaces |
|---|---|---|
| 1 | every entry's `[.name, (.source // "")] \| @tsv`, joined by line feeds, then `.` | `:766` (`entries_tsv`) |

## The plugin record (one per `plugin.json`)

Written only when `plugin_shape` holds.

| Order | Field | Value | Replaces |
|---|---|---|---|
| 1 | name | `.name // ""`, trailing line feeds removed | `:326` `pn` |
| 2 | version | `.version // ""`, trailing line feeds removed | `:328` `pv` |
| 3 | entry | one byte, `1` or `0`: an entry's `.name` equals field 1 | `:360` |
| 4 | entry version | matching entries' `.version // empty`, joined by line feeds, trailing line feeds removed | `:362` `mv` |
| 5 | entry source | the same, for `.source` | `:375` `ms` |
| — | `.` | terminator | — |

Field 3 is a field like the others (`1:1` or `1:0`); it was a bare byte
until phase H.7, which made every value of the record cut the same way.

"Trailing line feeds removed" is a recursive step,
`def nl: if endswith("\n") then .[:-1] | nl else . end;` — never
`sub("\n+$"; "")`, whose `$` (Oniguruma) also matches before an inner
line feed. It reproduces what `$( )` did on Linux: strip every trailing
line feed, keep every other byte.

## Walk environment (unchanged)

| Name | Value in the gate | Held copy in the tests |
|---|---|---|
| `DATED_RE` | `dated_re` (`:243`) | hoisted from `:1259` |
| `LINE_LIMIT` | `line_limit=1000` (`:251`) | hoisted from `:2338` |
| `QUOTE_CUT` | `quote_cut=200` (`:202`) | hoisted from `:3234` |
| `LC_ALL` | `C` | `C` |
