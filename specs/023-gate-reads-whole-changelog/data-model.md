# Data model: The release gate reads the whole changelog, and one suite check

## Changelog line classes (release form)

| Line | Class | Release form |
|---|---|---|
| `## [X.Y.Z] - YYYY-MM-DD` (exact) | dated version heading | accepted |
| any other line beginning `## ` | undated heading | refused, line named |
| `###` or deeper, text, blank | not a level-2 heading | not judged |

## TAP line classes (suite check)

| Line (after a trailing CR is stripped) | Class |
|---|---|
| `1..N` on line 1 | plan |
| `1..N` on any later line | second plan — refused |
| `ok …` | pass (counted) |
| `ok … # skip …` (any case) | skip — refused |
| `not ok …` | failure — refused |
| `# …` | comment — ignored |
| blank | ignored |
| anything else | non-TAP — refused |

Verdict: pass only when the plan is `1..<expected>`, the pass count is
`<expected>`, and no refused class occurs.
