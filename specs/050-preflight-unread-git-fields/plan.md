# Implementation Plan: The pre-flight report says which git fields it never read

**Branch**: `050-preflight-unread-git-fields` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/050-preflight-unread-git-fields/spec.md`

## Summary

`pipeline/scripts/preflight.sh` gains one top-level key, `notRead`: a JSON
list of strings naming every git-derived field whose git read did not run
or ran and failed. It is `[]` whenever `capabilities.gitUsable` is `true`.
No existing key changes.

The list is built where each field is produced, never from a second
hand-written list of field names (Principles IV and V):

- `baseBranch` and `baseBranchSource`: named when git is not usable and the
  base did not come from `override` (phase I narrowed this from "neither
  `override` nor `configured`": a configured base ranks below
  `origin/HEAD`, which was not read).
- `remote.kind`: named when git is not usable.
- `tree.dirty`: named when git is not usable.
- `willSkip.L`, `willSkip.M`: the skips added in the remote branch are added
  through one helper that also names them when git is not usable. The `N.5`
  skip and the `gh`-absent skip do not pass through it. (The `gh`-absent `M`
  skip is reached only with a GitHub remote, which an unusable git never
  reports.)

`pipeline/docs/rare-paths.md` ("The probe block without git") is rewritten
to mark exactly what `notRead` names, so the rule of which fields are
unread lives in the script alone. `pipeline/docs/configuration.md` gains a
short section documenting the key. Both shipped passages are pinned in
`pipeline/tests/prose.bats`. The same pull request releases pipeline 1.7.4.

## Technical Context

**Language/Version**: bash (3.2 on the macOS runner, 5.x on Linux and Git Bash)

**Primary Dependencies**: jq (1.6 and later; no `-b`), git (any version)

**Storage**: N/A

**Testing**: bats-core; full suite = `testCommand` (four roots); shellcheck = `analyzeCommand`

**Target Platform**: CI on ubuntu, macOS, Windows runners; local Ubuntu, git 2.53.0

**Project Type**: CLI plugin (shell scripts and Markdown skills)

**Performance Goals**: none new; the change adds no process on the usable path beyond one `jq --argjson`

**Constraints**: the 013 stdout contract: pure JSON, exit 0, no existing key changes name, type or meaning

**Scale/Scope**: one script, two test files, two shipped docs, three release files, records in `specs/`

## Constitution Check

| Principle | How this plan meets it |
|---|---|
| I. Silence is the failure | The gap closed is a silence: four fields that report reads that never ran. The list is present in every report, `[]` included, so its absence is itself a failure a test sees. |
| II. Measure; never assert | The current output per reason was measured on 2026-11-02 (spec Context). Every mutant's red is recorded with its date in `measurements.md`. |
| III. A gate must go red | Each new assertion is run against a mutant that removes what it guards (FR-007), in a worktree, with each mutation shown to have landed. Both directions: a mutant that OVER-marks (names a configured base, or names `L`/`M` for a usable git with no remote) must go red too. |
| IV. One implementation | The unread rule lives in the script; rare-paths reads the list instead of re-deriving it from `baseBranchSource`. |
| V. Derive coverage | `notRead` is built at each field's production site; no field list is written twice. No test or prose carries a count of the list. |

Gate: PASS. Re-checked after design: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/050-preflight-unread-git-fields/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── measurements.md      # written in phase H (mutant reds)
├── contracts/
│   └── not-read.md
└── tasks.md
```

### Source Code (repository root)

```text
pipeline/scripts/preflight.sh        # notRead built and emitted
pipeline/tests/preflight.bats        # not_read_is helper; per-reason assertions; new tests
pipeline/tests/prose.bats            # rare_spans updated; configuration.md pin
pipeline/docs/rare-paths.md          # "The probe block without git" reads notRead
pipeline/docs/configuration.md       # new section: the notRead key
pipeline/CHANGELOG.md                # [1.7.4]
pipeline/.claude-plugin/plugin.json  # 1.7.4
.claude-plugin/marketplace.json      # pipeline 1.7.4
specs/013-preflight-git-probe/spec.md  # known gap marked closed (FR-008)
```

**Structure Decision**: existing layout; no new directory outside the spec folder.

## Complexity Tracking

None.
