# Data model: 050-preflight-unread-git-fields

## The pre-flight report: one new key

| Key | Type | Values |
|---|---|---|
| `notRead` | list of strings | `[]` when `capabilities.gitUsable` is `true`; otherwise the names below that apply |

## Names `notRead` may hold

| Name | Named when |
|---|---|
| `baseBranch` | git not usable, and `baseBranchSource` is neither `override` nor `configured` |
| `baseBranchSource` | the same condition |
| `remote.kind` | git not usable |
| `tree.dirty` | git not usable |
| `willSkip.<phase>` | git not usable, and the entry was added because of `remote.kind` |

## Expected values, per case

| Case | `notRead` |
|---|---|
| git usable (any remote) | `[]` |
| git not usable, no base flag | `["baseBranch","baseBranchSource","remote.kind","tree.dirty","willSkip.L","willSkip.M"]` |
| git not usable, `--base-branch` or `--base-branch-override` | `["remote.kind","tree.dirty","willSkip.L","willSkip.M"]` |

The second and third rows hold for every unusable `gitReason`: `absent`,
`broken`, `refused-ownership`, `no-repository`.

## Invariants

- `notRead` is always present and always a list (never `null`, never absent).
- Every name in it is a field present in the same report.
- No existing key changes.
