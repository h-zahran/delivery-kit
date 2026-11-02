# Measurements: 050-preflight-unread-git-fields

A record of runs made on 2026-11-02, on Ubuntu with git 2.53.0 and jq 1.8.1,
against branch `050-preflight-unread-git-fields` at `14ae94d` (the spec
commit) plus the uncommitted piece 1. Exact figures here are this run's;
they are not claims about the current file.

## T006: the new assertions, red against the unchanged script

`bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats`: plan `1..112`,
104 ok. The eight red were exactly the eight tests T002-T005 touched, each
failing at `not_read_is` with `got null`:

- the capability report names git absent, and the report survives it
- the capability report names a git that refuses the repository for ownership
- the ownership refusal is found from exit codes, with git's messages gone
- the capability report names a git that opens no repository here
- the capability report names a git that is found but cannot run
- an unusable git with no base flag names the base fields as not read
- an override is established without git, so an unusable git does not name it
- a usable git names nothing, even with no remote

## T008: green, and the differential SC-002 needs

With the change: plan `1..112`, 112 ok, no skip. Quickstart steps 1-3
printed `[]`, the six-name list and the four-name list, as written.

Differential (Principle II): the script from `main` and the changed one,
each report compared as `jq -S 'del(.notRead)'`, on four usable-git cases:
this checkout; a fresh `git init` with no remote; the same with
`--base-branch main`; this checkout with `--base-branch-override main`.
All four identical, and `notRead` was `[]` in each. Control: compared
WITHOUT `del(.notRead)`, the first case differs, so the comparison can
see a difference.

## T009: mutants

Run in a detached worktree in the session scratch folder, never the main
checkout. Each mutant is a new copy of the script, made by a replacement
that must match exactly once and must change the text (else NOT APPLIED or
NO-OP), syntax-checked with `bash -n`, and the suite pointed at it with
`PREFLIGHT_UNDER_TEST`. For the three deletion mutants (a, f, g) the rig's
"landed" line, which printed only added lines, was empty; that they landed
is shown by the replacement check and by the reds.

| Mutant | Change | ok of 112 | Tests that went red |
|---|---|---|---|
| a | drop `notRead` from the output | 104 | all eight above |
| b | never mark the base fields | 111 | no base flag |
| c | mark the base fields for every source, `configured` and `override` included | 106 | the five `--base-branch` reason tests; override |
| d | `add_git_skip` marks whatever `git_usable` says | 111 | usable git, no remote |
| e | `--argjson not_read` to `--arg` | 104 | all eight |
| f | never mark `tree.dirty` | 105 | all but usable git, no remote |
| g | never mark `remote.kind` | 105 | all but usable git, no remote |

Every new or extended test went red under at least one mutant. Mutant d,
the over-marking direction, is caught only by "a usable git names nothing,
even with no remote": that test is the one positive control for the
direction a red-only sweep would miss.
