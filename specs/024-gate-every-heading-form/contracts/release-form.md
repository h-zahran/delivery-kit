# Contract: the release form reads every level-2 heading form

`bash scripts/check-versions.sh --released <plugin>`, run from the repository
root. Everything the default form does still happens first, unchanged, and
the first-heading check (`specs/023-gate-reads-whole-changelog/contracts/release-form.md`,
G3) still runs before the clauses below.

"Canonical" means the raw line is exactly `## [X.Y.Z] - YYYY-MM-DD`, with no
indent and nothing after the date. "Refuses" means: exits non-zero, and the
output contains the line number, the quoted text with every non-printable
character (a tab included) shown as `?`, and `is NOT released`.

| ID | Clause | Spec |
|---|---|---|
| H1 | ATX: a line whose text is `##` then a space, a tab or the end of the line (a closing run of `#` allowed), indented zero to three columns, is refused unless canonical: `##` + tab (quoted `##?Notes`), one and three spaces of indent, an empty `##`, `## Notes ##`. | FR-001, FR-008 |
| H2 | A version heading in any non-canonical form (indented one space) is refused. | FR-003 |
| H3 | Setext: a text line directly followed by a line of one or more `-`, then only spaces, is refused, naming the TEXT line and its underline's line. Any non-blank line that is not inside a fence is a text line: an indented line, an ATX heading of any level, a fence closer and a `-` run included. Only a line of spaces is blank. | FR-002 |
| H4 | Containers: after removing, repeatedly and in any order, block-quote markers (any indent, `>`, one optional space) and list markers (any indent, `-` `*` `+` or digits then `.` or `)`, then a space, a tab or the end), H1–H3 apply: `> ## Notes`, `>## Notes`, `- ## Notes`, `* ## Notes`, `+ ## Notes`, `1. ## Notes`, `1) ## Notes`, `- > ## Notes`, `1. > ## Notes`, `> Notes` then `> ---`, and `- Notes` then `  ---` are refused. | FR-005 |
| H5 | Lists: while a list item can be open, a line indented four or more columns is judged. `- item`, a blank line, `    ## Notes`; `- item` then `    ## Notes` with no blank line; and `- a`, `  - b`, a blank line, `  c`, a blank line, `    ## Notes` are each refused; so are `- item`, a backtick line holding a further backtick, `    ## Notes` (not a fence, so the item stays open) and `- item`, six spaces + `>`, `lazy`, `    ## Notes` (a deep `>` is not blank). | FR-006 |
| H6 | An unclosed fence (backticks or tildes) is refused, naming its line and text. With a heading refused earlier, only the heading is reported, once. A fence is followed only while every line inside starts with the opener's container prefix; the first line that does not, or a closer shape at another indent, is refused, saying `may already have ended` and naming the opener's line and the unclear line. Refused that way: `- ` + three backticks, then `## Notes`; two spaces + three backticks, then three backticks at column 0; `> ` + three backticks, then `x` with no `>`; `- ` + three backticks, then three spaces + three backticks; four spaces + three backticks, then `## Notes`; `- item`, then two spaces + `> ` + three backticks, then `> ## Notes`; `- > ` + three backticks, then `>` alone; `>` + three backticks, then `>` + four spaces + three backticks. A fence opener Markdown might not open is refused, naming its line: `Para`, `2. ` + three backticks, `   ## x`, three spaces + three backticks, and `- a`, two spaces + `2) ` + three backticks, … (`on an ordered list marker other than 1`); `<div>`, three backticks, a blank line, `## x`, a blank line, three backticks, and `<!--`, three backticks, `-->`, `## x`, three backticks (`that the HTML at line <m> may hold`). And a fence never hides a heading after its clean close: three backticks, `> ` + three backticks (content), three backticks, `## Notes` is refused at `## Notes` as H1. | FR-004, FR-007, FR-009 |
| H7 | Not judged: a line inside a cleanly closed fence (backticks or tildes) and the fence lines, a fence inside a list item included (`- item`, a blank line, two spaces + three backticks, two spaces + `## x`, two spaces + three backticks, the real tree's shape); `    ## Notes` or a tab and `## Notes` with no list item able to be open; `---` after a blank line. A changelog holding all of these passes. | FR-007 |
| H8 | The real tree passes the release form for both plugins, and the default form prints the same lines and exits with the same status as at `8bc9b5a` on the real tree; on every fixture the new tests build, it exits 0 with `state=released`. | FR-011 |
| H9 | Only the plugin named by `--released` is judged; another plugin's refused shape does not fail the run. No message prints an absolute path. | FR-010 |

## Unchanged from Phase 24

G3 (a heading above the version heading keeps its own message) and G5 (the
default form is unchanged) hold as written there. G1's "line beginning `## `"
is widened by H1–H6; G2's message shape is kept by every clause above.
