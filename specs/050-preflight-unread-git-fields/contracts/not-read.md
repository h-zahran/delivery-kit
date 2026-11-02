# Contract: the pre-flight report's `notRead` list

This contract adds to `specs/013-preflight-git-probe/contracts/capabilities.md`
and `specs/049-preflight-git-usable/contracts/`. Every guarantee of those
contracts still holds — pure JSON stdout, exit 0 when a tool is missing,
existing keys immutable, the document always complete. This feature adds one
key and changes none.

## The key

```json
{ "notRead": ["remote.kind", "tree.dirty", "willSkip.L", "willSkip.M"] }
```

`notRead` names each field of the same report whose value came from a git
read that did not run, or ran and failed. A field it names holds a
placeholder, not a fact: `baseBranch` `""`, `baseBranchSource`
`current branch`, `remote.kind` `none`, `tree.dirty` `false`, and the
`willSkip` entries that follow from `remote.kind`.

## What the probe promises

- `notRead` is present in every report and is always a list.
- It is `[]` exactly when `capabilities.gitUsable` is `true`.
- With `capabilities.gitUsable` `false`, it names `remote.kind`, `tree.dirty`
  and each `willSkip.<phase>` entry added because of `remote.kind`; and it
  names `baseBranch` and `baseBranchSource` unless the base came from an
  override or from configuration, which are established without git.
- It names nothing else: `remote.ghPresent`, `remote.ghCommand`, every
  `capabilities` key, `gitReason`, the `tree` run keys and every other
  `willSkip` entry come from reads that do not need git.
- Names are dotted paths from the report's root. A `willSkip` entry is
  named by its phase, `willSkip.<phase>`, never by its index.
- The order is the order the script produces the fields. A consumer should
  test membership, not position.

## What it does not promise

- A field `notRead` does not name is not thereby checked against the
  repository: a base branch from configuration is reported as given, and
  with git not usable it was not compared with any branch.
- `notRead` does not cover `capabilities.jq`, which is hardcoded `true`
  because the report could not be written without jq.

## Consumers

| Consumer | Reads | Effect |
|---|---|---|
| `pipeline/docs/rare-paths.md`, "The probe block without git" | `notRead` | marks exactly the probe-block lines whose fields it names |
| `pipeline/docs/configuration.md` | — | documents the key for a reader of the report |
| `pipeline/tests/preflight.bats` | `notRead` | exact list per reason and per base source |
