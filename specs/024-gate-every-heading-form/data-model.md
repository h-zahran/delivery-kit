# Data model: the release form's walk over a changelog

The gate holds no stored data. This file names the state the walk keeps
from line to line (research R2) and the kinds of line it decides.

## Walk state

| Field | Meaning | Set | Cleared |
|---|---|---|---|
| fence character | `` ` `` or `~` of the open fence | a fence opener | its clean closer (research R2 step 3); an unclear line refuses instead |
| fence length | a closer must be at least this long | a fence opener | as above |
| continuation prefix | the opener's text before its fence characters, every character but `>` turned into a space; a skipped line must start with it | a fence opener | as above |
| fence blank | the continuation prefix with trailing spaces removed; a blank line inside must equal it exactly | a fence opener | as above |
| fence line | the opener's line number and text, for the unclosed and unclear refusals | a fence opener | as above |
| list can be open | a deeply indented line may continue a list item | any line where a list marker was removed | an unindented non-marker, non-quote line after a blank line, or an unindented ATX heading or fence (R2 step 4) |
| previous kind | `blank` or `text`, for the setext test | every line | — |
| previous line | the raw previous line and its number, quoted by a setext refusal | every line | — |
| refused | a refusal was printed; END reports no open fence | the first refusal | — |

## Line kinds

| Kind | How it is recognised (after tab expansion and quote removal) | Judged? | Sets previous kind |
|---|---|---|---|
| in-fence | a fence is open and this line neither closes it nor is unclear | no | — (unchanged) |
| unclear | inside a fence, a line research R2 step 3 cannot place | refused | — |
| fence line | an opener or a closer | no; an opener left open at the end is refused | text (the closer) |
| underline | one or more `-`, then only spaces | refuses the previous line when that was `text` | text |
| indented code | `ind` of four or more, no marker removed, no list can be open | no | text |
| ATX level 2 | after list-marker removal, `##` then a space or the end | refused unless the raw line is canonical | text |
| other heading | `#`, `###` or deeper | no | text |
| blank | only spaces (a line of `>` markers alone is not blank) | no | blank |
| text | any other non-blank line | no, but it can become a setext heading's text | text |

The test fixture keeps no walk state: it applies its own wider line rule
(research R5).
