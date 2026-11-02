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

## T012: the doc pins, and their mutants

`bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats`: plan `1..96`, 96 ok.
The first draft of the rare-paths rewrite merged the override clause into
the configuration clause; "the trailer rules the operator reads are pinned
whole" went red on it, since it pins that clause verbatim. The old wording
of that clause was kept, and the existing carve-out pin is unchanged.

Run in the same worktree; each mutant edits the worktree's copy, the line
count shows it landed, and the copy is restored and compared byte for byte.

| Mutant | Change | Tests that went red |
|---|---|---|
| P1 | delete `## Fields the report did not read` from configuration.md | the report's notRead list is documented where a reader of the report finds it |
| P2 | rare-paths: drop the `notRead` sentence and restore the `baseBranchSource`-keyed base rule | the git stop is pinned in both surfaces a reader meets it in ("no longer marks exactly what notRead names"); each rare-paths section is exactly the skill's text, moved word for word |
| P3 | rare-paths: restore only the `baseBranchSource`-keyed base rule | the git stop is pinned in both surfaces a reader meets it in ("derives unread fields from baseBranchSource again") |

A first P2 run passed `--filter` patterns that matched no test and printed
`1..0`: zero tests, not a pass. It was rerun with the tests' real names.

## T015: the root suite, and one timeout

`bash scripts/check-versions.sh`: rc 0, `pipeline: plugin=1.7.4
marketplace=1.7.4 changelog=1.7.4 state=released`.

`bash "$HOME/bats/bin/bats" tests`: plan `1..140`, 139 ok. The one red was
"--released refuses a byte or a line it cannot judge" in `tests/gate.bats`,
`# timeout after 60s`. Run alone it passed in 53 s. Timed alternately, the
tree before this piece (the worktree, CHANGELOG unchanged) and this tree:

| Run | Tree | rc | Seconds |
|---|---|---|---|
| 1 | before | 1 (timeout) | 62.3 |
| 2 | this | 0 | 61.1 |
| 3 | before | 0 | 59.5 |
| 4 | this | 0 | 50.5 |

The tree before the change times out as well, so the timeout is the
test's own margin under load, not this release: the test plants about
600 KB into the changelog copy, and this entry adds 26 lines. Not fixed
here; the full suite in phase J is the verdict.

## Phase I: the review round's fixes, and their mutants

The owner answered the round's one question: a configured base is named
too, since `origin/HEAD` ranks above it and was not read; only an override
is exempt. With that and the round's other fixes — the guard moved inside
`mark_not_read`, the list kept as a string and split once by the final jq
(no process per name), every remote-branch skip through `add_git_skip` —
`preflight.bats` is plan `1..111`, 111 ok (the separate override test was
folded into "an unusable git reports names unchecked") and `prose.bats`
plan `1..96`, 96 ok. Quickstart steps 1-3 print `[]`, the six-name list
(no base flag), and the four-name list (`--base-branch-override`).

Script mutants, in the worktree as before (mutants a, b, d, e and f of the
first table target code that no longer exists in that form):

| Mutant | Change | ok of 111 | Tests that went red |
|---|---|---|---|
| a2 | `mark_not_read` loses its guard | 108 | remote classification; tree reports dirty; usable git names nothing |
| e2 | the final jq emits the string, not the split list | 101 | every test that reads `notRead` |
| c2 | `configured` exempt again | 106 | the five `--base-branch` reason tests |
| m8 | `remote.kind` marked under a usable git when a remote exists | 110 | remote classification |
| m11 | `tree.dirty` marked under a usable git when the tree is dirty | 110 | tree reports dirty |
| m9 | the base marked except for `broken` and `no-repository` | 109 | no repository; found but cannot run |
| n5 | the `N.5` skip routed through `add_git_skip` | 110 | no base flag, and never a device skip |

m8, m11, m9 and n5 are the tests lens's survivors (its M8, M11, M9 and the
N.5 gap the contract lens named); each now goes red.

Prose mutants, in a second worktree; each edit is checked to match once,
and both pages are restored and compared byte for byte afterwards:

| Mutant | Change | Red, with its message |
|---|---|---|
| P1b | configuration.md: a reversal appended to a sentence | the notRead list is documented ("section changed") |
| P5 | configuration.md: "holds a placeholder, not a fact" reworded | the same |
| P7 | configuration.md: `willSkip.<phase>` to `willSkip[<n>]` | the same |
| P8 | rare-paths: the configured "not confirmed" sentence deleted | the git stop is pinned ("no longer marks a configured base as not confirmed"); the rare-paths section span |
| P9 | rare-paths: the no-`notRead` sentence deleted | the git stop is pinned ("no longer fails closed"); the span |
| P10 | rare-paths: a reworded `baseBranchSource` rule added | the git stop is pinned ("derives unread fields from baseBranchSource again") |
| P11 | rare-paths: "IS established" weakened for the override | the git stop is pinned ("override carve-out was removed"); the trailer rules pin |

Each pin was shown red on its own: the message names the pin that failed.

## Phase I: the recheck of the fixes

The `bugs` lens read the diff from `1078930` to the tree once more and
named eight things. Fixed: the configured-base rule in rare-paths gave two
instructions at once (it now keys on whether this run passed `--base-branch`,
which the orchestrator knows without reading a placeholder); the
configuration.md opening still said "ran and failed" before narrowing it;
the absent reason had lost its no-base-flag probe; the contract did not
say why the `gh`-absent skip is named; two over-long lines. Deferred: an
unborn branch under a usable git reports `baseBranch: "HEAD"` with an empty
`notRead` — the base read prints `HEAD` and fails, and `|| true` keeps the
output. It predates this feature and is outside a list scoped to an
unusable git; configuration.md now names it, and it goes to the pull
request as a follow-up. Declined: copying the configuration.md section into
the test whole costs an edit per wording change; that is the price of
catching an appended reversal, which the tests lens showed the phrase pins
missed (P4).

After the fixes: `preflight.bats` and `prose.bats` together, plan
`1..207`, 207 ok. The new absent probe, under a mutant that marks the base
for `configured` only (`  configured) mark_not_read baseBranch; …`), went
red at its own `not_read_is`, printing `missing ["baseBranch",
"baseBranchSource"], extra []`.
