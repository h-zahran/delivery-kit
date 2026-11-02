# Research: 050-preflight-unread-git-fields

## R1. The key's name and place

- **Decision**: a top-level `notRead`, a list of strings.
- **Rationale**: it sits beside `gitReason`, which explains it. A name for
  what it covers (fields not read), not for git, so a later probe that skips
  a read for another cause can name its field in the same list.
- **Alternatives**: `gitRead: false` (the issue's example) — redundant with
  `capabilities.gitUsable` since 049, and it does not say which fields.
  A `notRead: true` inside each affected object — `baseBranch` is a string,
  not an object, so it has no place to carry one.

## R2. How a field is named

- **Decision**: a dotted path from the report's root: `baseBranch`,
  `baseBranchSource`, `remote.kind`, `tree.dirty`. A `willSkip` entry is
  named `willSkip.<phase>`, e.g. `willSkip.L`.
- **Rationale**: dotted paths are what the issue, the spec and the probe
  block already use. `willSkip` is a list, so an index would change when an
  entry is added before it; the phase is the entry's identity.
- **Alternatives**: jq paths (`.willSkip[0]`) — index-fragile, as above.

## R3. Order

- **Decision**: the order the script produces the fields: `baseBranch`,
  `baseBranchSource`, `remote.kind`, `tree.dirty`, then the skips in the
  order they are added.
- **Rationale**: deterministic without a sort, and tests can compare the
  whole list exactly.

## R4. Which base sources are unread

- **Decision** (revised at phase I, by the owner): `baseBranch` and
  `baseBranchSource` are named when git is not usable and the source is
  not `override`.
- **Rationale**: the resolution order is override, `origin/HEAD`,
  configured, current branch. Only the override outranks `origin/HEAD`, so
  only it is established without git; a configured base is what wins when
  no `origin/HEAD` is published, and with git not usable nobody looked.
  The first decision exempted `configured` too, and phase I's `bugs` lens
  found the gap. The rule is written as "not override", not as a list of
  git sources, so a later source added from git is unread by default — the
  fail-closed direction.

## R5. The skip entries

- **Decision**: every skip of the remote branch — the no-remote `L` and
  `M`, the non-GitHub `M`, and (since phase I) the `gh`-absent `M` — is
  added through `add_git_skip`, which calls `add_skip` and then
  `mark_not_read "willSkip.<phase>"`; `mark_not_read` does nothing with a
  usable git. The `N.5` skip uses `add_skip` directly.
- **Rationale**: the marking happens where the dependency on git is
  visible: in the remote branch, every arm of which is reached only through
  `remote.kind`. An unusable git always reads `none`, so in practice the two
  marked entries are `L` and `M`, and the other two arms cannot be reached
  with git not usable; routing them through the helper is the fail-closed
  choice should a later change read the remote another way.

## R6. Whether to stop running the git reads when git is unusable

- **Decision**: no change. Out of scope; the spec's edge case says why.

## R7. The probe block rule

- **Decision**: rewrite "The probe block without git" to mark exactly what
  `notRead` names, keeping its explanations (why the block must be exact,
  why `ghPresent` stands, why `no git remote` is unestablished).
- **Rationale**: Principle IV. Today the rule that `origin/HEAD` and
  `current branch` are git-derived is written in the prose and implied in
  the script; after this change the script is the one place.
- **Cost**: `rare_spans` in `pipeline/tests/prose.bats` holds that section
  verbatim and must be updated in the same piece.
