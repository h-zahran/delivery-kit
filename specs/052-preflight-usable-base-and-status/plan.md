
# Implementation Plan: Pre-flight checks the base it resolved, and reads the whole tree

**Branch**: `052-preflight-usable-base-and-status` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/052-preflight-usable-base-and-status/spec.md`

## Summary

`pipeline/scripts/preflight.sh` changes in three places, each only when
`capabilities.gitUsable` is `true`:

1. **One base check, every source (FR-001 to FR-003, FR-005).** The
   override's existing "is it a local branch, not a tag" block becomes a
   function, `base_usable <name> <label>`. The override block calls it
   where it does today, with the label `--base-branch-override`, so its
   messages stay as they are. After the base is resolved and has passed
   the name check, the same function runs for `origin/HEAD`, the
   `baseBranch` key and the current branch, with the labels the name
   check already uses. It adds two refusals the override did not have: a
   base that is the current branch before its first commit ("has no
   commit yet"), and a ref that names no commit.
2. **The current checkout reads the full ref (FR-004).** `git symbolic-ref
   --quiet --short HEAD` becomes `git symbolic-ref --quiet HEAD`. A ref
   outside `refs/heads/` stops pre-flight; the base is the ref less
   `refs/heads/`. This is what removes `heads/<name>` (item 5) and `v1`,
   `origin/main` (item 4). 051's exit-code handling is kept.
3. **The clean-tree read (FR-006).** `git status --porcelain` gains
   `--untracked-files=normal --ignore-submodules=none`. A second read,
   `git ls-files -v`, counts entries whose tag is a lowercase letter
   (`assume-unchanged`), over the whole tree (`-- ':/'`); any such entry
   sets `tree.dirty: true`. A failed status read stops pre-flight with
   051's message; a failed index listing with its own.
4. **The test fixtures leave the enclosing checkout (research R6).** CI
   probes them from a detached checkout with no `main`, where the new
   base check would stop every fixture probe. `setup_file` copies them
   into a scratch repository on `main`. A rig that clones this
   repository as CI does proves the suite green there.

Item 3 changes no code (FR-007): the documentation says what runs.
`pipeline/docs/configuration.md` gains the sentences FR-009 needs, each
pinned by a prose test. The run ends with the 1.7.6 release piece.

## Technical Context

**Language/Version**: bash (3.2 on the macOS runner, 5.x on Linux and Git Bash)

**Primary Dependencies**: git (`show-ref --verify --quiet`, `rev-parse --verify --quiet <ref>^{commit}`, `symbolic-ref --quiet HEAD`, `status --untracked-files=normal --ignore-submodules=none`, `ls-files -v`), awk, jq

**Storage**: N/A

**Testing**: bats-core; full suite = `testCommand` (four roots); shellcheck = `analyzeCommand`

**Target Platform**: CI on ubuntu, macOS, Windows runners; local Ubuntu, git 2.53.0

**Project Type**: CLI plugin (shell scripts and Markdown skills)

**Performance Goals**: at most four more git processes on a normal run (two `show-ref` and one `rev-parse` for the base; one `ls-files`)

**Constraints**: the 013 stdout contract holds for every printed report; the new stops print no report, as the existing refusals do. No git text is read (exit codes only). No pipeline whose reader exits early under `pipefail` (`tests/pipefail.bats`). A fixture that names a base which does not exist as a local branch now stops pre-flight, so fixtures change (research R4).

**Scale/Scope**: one script, two test files (`preflight.bats`, `prose.bats`), one shipped doc, three release files

## Constitution Check

| Principle | How this plan meets it |
|---|---|
| I. Silence is the failure | Each closed gap is a silence: a base reported as usable that phase B cannot use, and work `git status` did not show reported as a clean tree. Each now stops or reports dirty. The gaps left open (2a, 2c, item 3) are named in the shipped documentation, not left silent. |
| II. Measure; never assert | Every case in the spec's Context table was measured on 2026-11-03 against `4d0b5cd`; the hardening candidates too (research R2, R3). Every mutant's red is recorded with its date in `measurements.md`. |
| III. A gate must go red | Each new refusal and the dirty rules ship with a test, run once against a mutant that removes the rule, in a worktree, with the mutation shown to land. The other direction too: the sparse checkout and the `skip-worktree` case must stay `false`, so a mutant that counts `S` as dirty turns a test red. |
| IV. One implementation | One `base_usable` function serves the override and every other source. One `die` for every stop. |
| V. Derive coverage | Which fixtures need a real base branch is found by running the full suite against the change, not by a hand list (R4). |

Gate: PASS. Re-checked after design: PASS. One named departure from the
spec's first wording: FR-011's override message exception, recorded in
the spec itself and in research R1.

## Project Structure

### Documentation (this feature)

```text
specs/052-preflight-usable-base-and-status/
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
pipeline/scripts/preflight.sh        # base_usable; full-ref HEAD read; status flags; ls-files -v
pipeline/tests/preflight.bats        # new tests; fixtures copied into a scratch repository on main (R6)
pipeline/tests/prose.bats            # configuration.md pins
pipeline/docs/configuration.md       # "Base branch"; "Fields the report did not read"
pipeline/CHANGELOG.md                # [1.7.6]
pipeline/.claude-plugin/plugin.json  # 1.7.6
.claude-plugin/marketplace.json      # pipeline 1.7.6
```

**Structure Decision**: existing layout; no new directory outside the spec folder.

## Complexity Tracking

None.
