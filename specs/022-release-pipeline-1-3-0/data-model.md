# Data model: Release pipeline 1.3.0

## Version site

| Site | Before (`d9a085e`) | After |
|---|---|---|
| `pipeline/.claude-plugin/plugin.json` `version` | `1.2.1` | `1.3.0` |
| `.claude-plugin/marketplace.json` pipeline entry `version` | `1.2.1` | `1.3.0` |
| `.claude-plugin/marketplace.json` handoff entry `version` | `2.2.0` | `2.2.0` (unchanged) |
| `pipeline/CHANGELOG.md` first heading | `## [Unreleased]` | `## [1.3.0] - 2026-10-01` |

Rule: the three pipeline sites agree (`scripts/check-versions.sh`).

## Changelog block — state transition

```text
open  (## [Unreleased])  --stamp-->  released (## [1.3.0] - 2026-10-01)
```

A released block is immutable: its text never changes again; a later change
gets a later entry. The text moves across the transition unchanged (FR-004).
