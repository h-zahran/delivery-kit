# Data Model: The release gate closes the gaps Phase 25 left

The release form's walk keeps state from line to line. This phase adds the
fields marked NEW and changes the ones marked CHANGED. Everything else is
as in `specs/024-gate-every-heading-form/data-model.md`.

## Walk state

| Field | Meaning | Set by | Cleared by |
|---|---|---|---|
| line limit (NEW) | the longest line the walk judges, in bytes (the walk runs under `LC_ALL=C`) | the script, once; read from the environment | — |
| quote cut (NEW) | the longest text a refusal quotes, shared with the bash first-heading refusal | the script, once; read from the environment | — |
| previous kind (CHANGED) | `blank`, `text`, `heading` (R8) or `qblank` (R9), for the underline test | every line | — |
| html (CHANGED) | an HTML block CommonMark ends at a blank line may be open (R7) | every `<` line of the soft kind, whatever the state | a spaces-only line |
| html sticky (NEW) | an HTML block that only its own end marker closes may be open (R7) | every `<` line of the hard kind, whatever the state | never |
| ordered ok (NEW) | the previous line was an accepted ordered item (one to nine digits, non-empty, not odd): its delimiter and the raw text before its marker (R6) | an accepted ordered item line | any other line |

## Line kinds the walk refuses (in order of the checks)

| Kind | Test | Message |
|---|---|---|
| too long (NEW) | `length` over the line limit, in bytes | `line <n> is <len> bytes long, longer than the release form judges: '<cut>'` |
| CR (NEW) | the raw line holds a CR byte | `line <n> holds a carriage return, which Markdown reads as a line end: '<cut>'` |
| unclear fence | as Phase 25 | as Phase 25 |
| setext | a `-` run under a line whose previous kind is `text` | as Phase 25 |
| odd fence (CHANGED) | a fence on an ordered marker other than `1` that is not an accepted ordered item (R6) | as Phase 25 |
| html fence (CHANGED) | a fence opener while `html` or `html sticky` holds (R7) | as Phase 25 |
| ATX | as Phase 25 | as Phase 25 |
| unclosed fence | as Phase 25 | as Phase 25 |

## Checks outside the walk

| Check | Where | Forms | Message |
|---|---|---|---|
| NUL byte (NEW) | before the dated-heading `grep` | both | `<plugin>: CHANGELOG.md holds a NUL byte, which the gate cannot read — this tree is NOT released` |
| first heading (CHANGED) | as Phase 24 G3 | default: state field; release: refusal | text masked (`?`), and cut in the refusal |

Every quoted text goes through `show()`: non-printable characters become
`?`, then a text longer than the quote cut is cut and ends with ` [cut]`.
