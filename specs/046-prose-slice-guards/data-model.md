# Data Model: Every prose slice is guarded

No stored data. The entities are the values the two helpers pass around.

| Entity | What it is | Rules |
|---|---|---|
| Document | A prose file the suite reads (the orchestrator skill, `pipeline/docs/configuration.md`, …) | Must be a regular, readable file, else the helper fails naming it |
| Boundary | An ERE for the opening line and one for the closing line | The opener matches exactly one line of the document; the closer matches a line at or after it |
| Slice | Lines from the opener to the first closer, inclusive | Non-empty; first line matches the opener; last line matches the closer; no undeclared heading-shaped line (`^\*\*` or `^#{1,6} `) strictly inside |
| Declared inner line | A whole line the caller names as expected inside its slice | Matched as a fixed string against the whole line; admits only itself |
| Form | `raw` (lines as they are) or `flat` (via `prose_flat`) | Any other value fails |
| Haystack | The text a pin searches | Byte-identical to its pre-change value on the current documents (FR-004) |
