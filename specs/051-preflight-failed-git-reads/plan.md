# Implementation Plan: Pre-flight stops stating a failed git read as fact

**Branch**: `051-preflight-failed-git-reads` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/051-preflight-failed-git-reads/spec.md`

## Summary

`pipeline/scripts/preflight.sh` gains three stops, each taken only when
`capabilities.gitUsable` is `true`, each through the script's existing
`die` (stderr, exit 1, no report on stdout), and none printing git's own
text or a value read from the repository:

1. **Detached `HEAD`** — the base branch comes from the current checkout
   and `git symbolic-ref --quiet --short HEAD` fails.
2. **No commit yet** — the base branch comes from the current checkout,
   `symbolic-ref` named a branch, and `git rev-parse --verify --quiet HEAD`
   fails.
3. **Status read failed** — `git status --porcelain` exits non-zero.

The current-checkout read moves from `git rev-parse --abbrev-ref HEAD`
(exit 0 and `HEAD` when detached; exit 128 and `HEAD` when unborn) to
`symbolic-ref`, which tells all three states apart. With git not usable
neither read changes what the report says: `baseBranch` stays `""`,
`tree.dirty` stays `false`, and `notRead` names them as feature 050 made
it. `notRead`'s contract does not change.

`pipeline/docs/configuration.md`, "Fields the report did not read",
replaces its "does not cover … reads `HEAD`" sentence with the stops; the
section's whole-text pin in `pipeline/tests/prose.bats` follows. Existing
tests that probe a commit-less repository with no base flag and expect a
report gain a `seed` (FR-008). The same pull request releases pipeline
1.7.5.

## Technical Context

**Language/Version**: bash (3.2 on the macOS runner, 5.x on Linux and Git Bash)

**Primary Dependencies**: git (`symbolic-ref --quiet --short`, `rev-parse --verify --quiet`: both in every git CI runs), jq

**Storage**: N/A

**Testing**: bats-core; full suite = `testCommand` (four roots); shellcheck = `analyzeCommand`

**Target Platform**: CI on ubuntu, macOS, Windows runners; local Ubuntu, git 2.53.0

**Project Type**: CLI plugin (shell scripts and Markdown skills)

**Performance Goals**: one more git process on the current-checkout path only (`rev-parse --verify`); none on the others

**Constraints**: the 013 stdout contract holds for every report printed; the new stops print no report, as the flag refusals already do. CI checks out a pull request as a detached `HEAD`, so any test that probes this checkout without a base flag would hit stop 1 in CI only (research R3).

**Scale/Scope**: one script, two test files, one shipped doc, three release files

## Constitution Check

| Principle | How this plan meets it |
|---|---|
| I. Silence is the failure | The gap closed is a silence: a failed read reported as a clean tree and as a branch called `HEAD`. Each now stops and names itself. |
| II. Measure; never assert | The three cases were measured on 2026-11-02 against `68dc597` (spec Context). Every mutant's red is recorded with its date in `measurements.md`. |
| III. A gate must go red | Each stop ships with a test, and each test is run against a mutant that removes its stop, in a worktree, with the mutation shown to have landed. The other direction too: a mutant that stops with git NOT usable must turn the 050 not-read tests red, and the old `rev-parse` read put back must turn the detached test red. |
| IV. One implementation | The stops use the script's one `die`; no second refusal path. |
| V. Derive coverage | Which tests need a `seed` is found by running the suite against the change, not by a hand list; the suite is also run in a detached worktree, as CI runs it. |

Gate: PASS. Re-checked after design: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/051-preflight-failed-git-reads/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── measurements.md      # written in phase H (mutant reds)
├── contracts/
│   └── stops.md
└── tasks.md
```

### Source Code (repository root)

```text
pipeline/scripts/preflight.sh        # the base read via symbolic-ref; three stops
pipeline/tests/preflight.bats        # three new tests; seed added where a test needs a commit
pipeline/tests/prose.bats            # configuration.md section pin updated
pipeline/docs/configuration.md       # "Fields the report did not read": the stops
pipeline/CHANGELOG.md                # [1.7.5]
pipeline/.claude-plugin/plugin.json  # 1.7.5
.claude-plugin/marketplace.json      # pipeline 1.7.5
```

**Structure Decision**: existing layout; no new directory outside the spec folder.

## Complexity Tracking

None.
