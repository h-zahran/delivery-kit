# Data model: 049-preflight-git-usable

The probe's stdout gains two keys. Nothing else changes.

| Key | Type | Values | Rule |
|---|---|---|---|
| `capabilities.git` | boolean | `true`, `false` | unchanged: `command -v git` succeeds |
| `capabilities.gitUsable` | boolean | `true`, `false` | `true` exactly when `gitReason` is `usable` |
| `gitReason` | string | `usable`, `absent`, `broken`, `refused-ownership`, `no-repository` | the first matching step of the classifier in plan.md |

Invariants:

- `capabilities.git` is `false` exactly when `gitReason` is `absent`.
- `capabilities.gitUsable` is `true` exactly when `gitReason` is `usable`.
- Both booleans are JSON booleans, never strings.

State of the run: no new state-file key. The orchestrator renders the git
line from `gitReason` and stops at decision 11 when `gitUsable` is `false`.
