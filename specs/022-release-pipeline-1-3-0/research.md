# Research: Release pipeline 1.3.0

All measurements at `main` = `d9a085e`, 2026-10-01.

## R1 — Which sites carry the current version

- **Decision**: three sites — `pipeline/.claude-plugin/plugin.json` line 4,
  the pipeline entry of `.claude-plugin/marketplace.json` (line 21), and the
  first `## ` version heading of `pipeline/CHANGELOG.md`.
- **Rationale**: `git grep -n -F 1.2.1 d9a085e -- ':!specs/' ':!main-plan.md'`
  finds the two JSON lines plus two released changelog headings (the
  pipeline's 1.2.1 and the handoff plugin's own, older 1.2.1), which are
  history. `scripts/check-versions.sh` reads exactly the three pipeline sites.
- **Alternatives considered**: a root changelog or README version line — none
  exists (the 1.2.1 release measured the root `CHANGELOG.md` as a pure index).

## R2 — How to edit the JSON files

- **Decision**: `sed`, matching the whole `"version": "1.2.1"` line, after
  proving the pattern occurs exactly once in each file.
- **Rationale**: `jq . .claude-plugin/marketplace.json | tr -d '\r' | diff - .claude-plugin/marketplace.json`
  differs at lines 15–19 and 27–31: a `jq` round-trip reflows the two `tags`
  arrays. (Without `tr -d '\r'`, native Windows `jq` adds a CR to every line
  and the diff starts at line 1 — a line-ending artefact, not the reflow.)
  `sed` changes one line.
- **Alternatives considered**: `jq` with a write-back (rejected, above); a
  hand edit (equivalent, but `sed` with a uniqueness guard refuses a
  mismatch instead of trusting the eye).

## R3 — How to show the gates can go red

- **Decision**: run `bash scripts/check-versions.sh --released pipeline` in a
  temporary worktree at `d9a085e`; it must exit non-zero (the open heading
  sits above the version). Then run it on the branch; it must exit 0.
- **Rationale**: the no-argument form reports `state=UNRELEASED-ABOVE` but
  exits 0 on both trees, so its rc proves nothing about the release. The
  `--released` form is what the tag run calls; it is the gate the release
  exists for. A worktree avoids touching the main checkout (no stash, no
  checkout of tracked files).
- **Alternatives considered**: trusting the `state=` text alone (a string
  check, kept as a second assertion, not the only one).

## R4 — The date

- **Decision**: `2026-10-01`, today.
- **Rationale**: the seed says `<today>`; the 1.2.1 release stamped the day
  the release was written, and the merge date is the owner's.

## R5 — No fresh `## [Unreleased]`

- **Decision**: do not open one.
- **Rationale**: the seed requires the heading GONE; the 1.2.1 release did not
  open one either; the next feature that changes the plugin opens it.

## R7 — Gaps found at deep review, left for a later feature

Both change files outside the seed's three lines, so this release records
them and does not close them.

- `scripts/check-versions.sh --released` compares only the first heading
  with the version heading, so an `## [Unreleased]` heading lower in the
  file passes both gate forms (measured by mutation at I). Here only S4
  catches it. A later fix: count `^## \[Unreleased\]` across the whole file
  in `--released` mode.
- Clause C4 of `specs/016-release-two-plugins/contracts/version-agreement.md`
  says a dangling `[Unreleased]` heading is enforced by nothing. Since 1.2.0
  the CI tag step passes `--released`, and `tests/portability.bats` tests it
  on a fixture. That record is dated history; it needs a forward note in a
  later feature, never a rewrite.

## R6 — The tag name

- **Decision**: `pipeline-v1.3.0`, after the merge, from `origin/main` after a
  fetch.
- **Rationale**: CI derives the plugin name from the tag as `<plugin>-v<version>`.
  A bare `v1.3.0` already exists (handoff, 2026-08-18); a new bare tag would
  fail at the agreement step first (`check-versions.sh --released v1.3.0`
  answers that it is not a plugin in this tree), and the tag step behind it
  would then not run. A rebase merge gives the release a new id, so the tag is
  taken from `origin/main`, never from this branch.
