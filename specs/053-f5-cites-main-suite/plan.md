# Implementation Plan: F.5 cites a green suite result for main's commit

**Branch**: `053-f5-cites-main-suite` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/053-f5-cites-main-suite/spec.md`

## Summary

A fresh run starts, in B, a background full-suite run on a detached worktree
of the base commit and records its result with the same key and writer as
`suite-record`. F.5 waits for it (900 s limit, a loop of calls), then asks
`suite-lookup --base` exactly as today. The lookup's decision is unchanged;
its summary names the record's commit and command. Measured first (research
R1): a record made in a detached worktree of `065ab80` has the key F.5's
`--base` lookup computes in this repository.

## Technical Context

**Language/Version**: bash (3.2 on macOS CI, 5.x on Linux and Git Bash), awk, jq 1.6+

**Primary Dependencies**: git (worktree), jq; `setsid` where present

**Storage**: files under `.delivery-kit/` (records in `suite-results/`, bookkeeping in `runs/<feature>/base-suite/`)

**Testing**: bats 1.11 (`pipeline/tests/base-suite.bats`, `pipeline/tests/suite-cache.bats`, `pipeline/tests/prose.bats`)

**Target Platform**: Linux, macOS, Windows Git Bash (CI runs all three)

**Project Type**: CLI plugin (shell scripts plus skill prose)

**Performance Goals**: F.5 under 1 minute when a base record exists (SC-001); today about 9 minutes

**Constraints**: no new configuration key; the Bash tool's 600 s foreground limit; no process stopped but the runner's own; no skip in CI

**Scale/Scope**: one new subcommand (`suite-base`, with `start` and `wait`) and one internal runner entry; a refactor of `suite_key` and the record writer; prose in SKILL.md B and F.5, docs/phases.md, docs/configuration.md

## Constitution Check

| Principle | How this plan holds it |
|---|---|
| I. Silence is the failure | Every `start` and `wait` outcome prints one line; "nothing recorded" names its reason; a runner that stops reporting is said to have stopped, never read as green. |
| II. Measure; never assert | Key equality was measured before design (R1, dated). Quickstart §3 measures the worktree's suite against this run's own F.5 TAP. |
| III. A gate must be shown able to go red | Each test in base-suite.bats states the mutation that turns it red; the chain test (green record → lookup exits 0) is paired with red, moved-file and mode controls that must exit 1. |
| IV. One implementation | One key function and one record writer, called by `suite-record` and by the runner; a test pins that the runner calls them (no second `hash-object` key path). |
| V. Derive coverage | No list of cases in prose carries a count; tests walk outcomes from the contract table. |

Gate: PASS. No departure, except R2 (start in B, not pre-flight), which is
named in research.md and the spec.

## Project Structure

### Documentation (this feature)

```text
specs/053-f5-cites-main-suite/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/suite-base.md
└── tasks.md
```

### Source Code (repository root)

```text
pipeline/scripts/progress.sh        # suite_key split; record writer; suite-base start|wait; runner
pipeline/skills/pipeline/SKILL.md   # B starts it; F.5 waits, then looks up; metrics f5Cited
pipeline/docs/phases.md             # "Reusing a suite run": the base suite run
pipeline/docs/configuration.md      # suiteReuse row: off also means no base run
pipeline/tests/base-suite.bats      # new
pipeline/tests/suite-cache.bats     # summary-line assertions follow the new text
pipeline/tests/prose.bats           # pins for the skill and docs text
pipeline/CHANGELOG.md, pipeline/.claude-plugin/plugin.json, .claude-plugin/marketplace.json  # release 1.8.0
```

**Structure Decision**: everything lives in the existing pipeline plugin
tree; no new script file (the runner is a `progress.sh` entry, so it shares
the key code by construction).

## Design notes

1. **Key split.** `suite_config <feature> [base]` validates the state file
   and sets `SK_CMD`, `SK_MODE`, `SK_LEAVE`; `suite_key_here <scratch>` runs
   the git part in the current directory and sets `SK_KEY`. `suite_key` is
   the two in sequence, so `suite-key`, `suite-record` and `suite-lookup`
   behave byte-for-byte as before.
2. **Record writer.** `suite_write_record <feature> <tap> <rc>` is the jq
   write + rename now inline in `cmd_suite_record`; `SUITE_DIR` is resolved
   to an absolute path before the runner changes directory.
3. **Runner** (`suite-base-run <feature>`, internal): reads config from the
   main state file, `cd`s into the worktree, takes the key, runs
   `bash -c "$SK_CMD"` with its own `TMPDIR` and output to
   `base-suite/suite.tap`, takes the key again, returns to the main top,
   writes the record, removes the worktree and its temporary directory,
   writes `outcome` last. A TERM trap stops the child, removes the worktree
   and writes `stopped`.
4. **Start** checks the base key in the main tree first (a green record
   already there means no start), then `git worktree add --detach`, then
   launches the runner detached (`</dev/null >/dev/null 2>runner.log`, fd 3
   closed — bats waits on an inherited fd 3).
5. **F.5 prose**: loop `suite-base <feature> wait` while it exits 2; then
   `suite-lookup <feature> --base`; cite on exit 0, else run as today; then
   `jq` `f5Cited` and `baseSuite` into the metrics.
6. **Release**: 1.8.0, MINOR.

## Complexity Tracking

None.
