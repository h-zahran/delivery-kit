# Research: release pipeline 1.1.0

Four questions. Each records the decision, why, and what else was weighed.

## R1 — Rewrite the heading in place, and prove the content beneath it did not move

- **Decision**: replace the single line `## [Unreleased]` with `## [1.1.0] - 2026-08-24`. One line in, one line out. Do NOT insert a new heading, do NOT re-serialise the file, do NOT reflow anything.
- **Measured, before deciding** (`sed -n`, `cat -A`, `wc -c`, `sha256sum`):
  - Line 5 is exactly `## [Unreleased]` — no trailing whitespace.
  - Lines 6–55 are the four accumulated entries: **3104 bytes**, sha256 beginning `09bf16d6f4a4b59d`.
  - Line 56 is blank; line 57 is `## [1.0.1] - 2026-08-22`.
- **Why a one-line replacement is the right shape**: it makes FR-004's "byte-identical beneath" trivially checkable rather than argued. Because exactly one line is replaced by exactly one line, the entries do not even shift line numbers — so hashing lines 6–55 before and after and comparing is a complete proof, not a sample.
- **Precedent, checked rather than assumed**: the commit that stamped `1.0.1` (`a009fb9`) left NO `[Unreleased]` heading behind — that file's headings ran straight `1.0.1`, `1.0.0`. The `handoff` plugin's changelog is the same shape at `2.1.0`. So "rewrite in place, leave nothing open" is this repository's established practice, not an interpretation of the seed.
- **Alternatives considered**:
  - *Insert a fresh `1.1.0` heading and keep `[Unreleased]` above it for future work* — REJECTED. It is a common keep-a-changelog habit, but here it would strand all four accumulated entries under `[Unreleased]` and ship an empty `1.1.0`, the exact inverse of the intent. The precedent above also shows this project does not do it.
  - *Rewrite the file with a markdown tool* — REJECTED. Any re-serialiser may normalise whitespace, list markers or blank lines somewhere in the other 60 lines, which would violate FR-008 invisibly.

## R2 — One command, three sites, one verdict

- **Decision**: the agreement check reads all three sites and prints a single verdict. The two JSON sites are read exactly as P1's acceptance reads them; the changelog heading is read by extracting the version from the newest `## [` line.
- **Why the seed's named command is not enough on its own**: the seed says "Version agreement proven with the jq line from P1's acceptance". That line is `jq -r '.plugins[] | "\(.name) \(.version)"' .claude-plugin/marketplace.json`, plus `jq -r .version pipeline/.claude-plugin/plugin.json` — both documented in `specs/001-pipeline-101-polish/quickstart.md`. **`jq` reads JSON. The third site is a markdown heading.** A check built only from those two commands PASSES a tree whose changelog still says `[Unreleased]`, which is precisely the half-done release this phase exists to prevent. Run against the pre-change tree it prints `plugin=1.0.1 market=1.0.1 changelog=Unreleased` — two agree, one does not, and a two-command check would have reported success.
- **This was surfaced to the owner rather than decided quietly**, because it means doing slightly more than the seed's letter. The owner ruled: one command, all three, one verdict. Recorded in the spec's Clarifications and in FR-005.
- **Alternatives considered**:
  - *Follow the seed literally and check the changelog separately* — REJECTED by the owner. It matches precedent exactly, but nothing then proves the acceptance criterion ("three stamp sites agree") in one place, and a separate check is a check someone can forget.
  - *Add a bats test asserting agreement* — REJECTED. It would move the suite count that FR-007 freezes, and it re-opens debt the plan explicitly marks PAID (see R3).

## R3 — No test is added, and that is a ruling, not a deferral

- **Decision**: this phase adds no test and records no new test debt.
- **Why this is different from every previous phase's "record the debt" outcome**: the plan's Global Constraints were AMENDED on 2026-08-23 and name this phase directly — *"P5 and P6: this debt is PAID — do not re-queue or re-spend it."* P4 spent the prose-pin debt in full, mutation-verified, taking the suite to `1..121` and prose to `1..11`. Re-queuing it here would contradict a standing instruction, and spending it again would move a count FR-007 freezes.
- **Nor is there anything here to pin — and DISCOVERED AT H.7, it is already pinned.** `tests/portability.bats:307`, *"every plugin's manifest, marketplace entry and changelog agree"*, asserts `plugin == marketplace` AND `plugin == changelog` on every suite run, and `.github/workflows/ci.yml`'s `version` job is a hand-maintained twin of it running on every push and pull request. A cleanup reviewer mutation-proved the gate bites: revert the changelog heading to `[Unreleased]` with the JSON sites at `1.1.0`, and the anchored `-m1` grep reads the older `1.0.1` heading instead, turning the gate red with `pipeline: plugin=1.1.0 changelog=1.0.1`.
  **The heading pattern this feature wrote into FR-006a is byte-identical to the one that suite already uses** (`tests/portability.bats:380`), which was not known when FR-006a was written. Two documents reaching the same pin independently is the good outcome, but the suite got there first and the record says so.
  Two limits, recorded as limits: a WHOLLY forgotten release — all three sites unbumped, `[Unreleased]` open — is green, and correctly so, because that is the normal in-development state; and the date is checked for SHAPE only, never against the real release date.
- **Alternatives considered**: *pin the three sites in `prose.bats`* — REJECTED for the reasons above; and *hide the assertion inside an existing test to keep the count* — REJECTED outright, not weighed: a P4 reviewer caught exactly that shape once and the project corrected it, which is why P4's spend created honestly-named tests instead.

## R4 — "Nothing else moved" is proven from the diff, not asserted

- **Decision**: the final check reads `git diff` and confirms every changed line on the shipped surface is one of the THREE expected lines (six diff lines — three removed, three added). Expected diffstat: **3 files changed, 3 insertions(+), 3 deletions(-)** — one line replaced in each of the three files.
- **Why the diff and not just the suite**: the suite proves nothing BROKE. It does not prove nothing else CHANGED — most edits to prose, docs or comments would leave `1..121` perfectly green. FR-008 and SC-005 are about a reviewer being able to see at a glance that a release commit contains no behaviour change, and only the diff shows that.
- **What the check must tolerate**: `specs/006-release-1-1-0/` is untracked and is NOT a shipped surface — it is absent from the `SHIPPED_*` lists in `tests/portability.bats`, which is what makes this feature's own artefacts exempt under FR-008. The private `docs/` archive is likewise untracked and never staged.
- **Alternatives considered**: *trust the diffstat line count alone* — REJECTED as insufficient; three changed lines could still be the WRONG three. The check reads the changed lines themselves.

## Standing facts carried into this run

- **`gh` is reported ABSENT by `preflight.sh` and that is a FALSE NEGATIVE.** The script runs under bash, which cannot see the Scoop shim; PowerShell finds `gh 2.92.0`, logged in. Phase M is NOT skipped. Measured again this run, as in every previous run.
- **The plugin cache is refreshed from a git CLONE of this repository**, and updating the plugin is a THREE-step dance: update the marketplace, then uninstall and reinstall, then probe with a grep. Measured 2026-08-24, immediately before this run: uninstall+reinstall alone re-copied a clone that was three commits behind and reported success. Only the probe proves a refresh landed.
- **The suite exceeds a 120-second timeout** and must be run with that in mind; a run that appears to hang is usually just slow.
