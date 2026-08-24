# Tasks: release pipeline 1.1.0

**Input**: Design documents from `specs/006-release-1-1-0/`
**Prerequisites**: plan.md, research.md, contracts/version-contract.md, quickstart.md

**Tests**: NO test changes this phase, and this is a RULING rather than a deferral. The
plan's Global Constraints were amended on 2026-08-23 and name this phase directly —
*"P5 and P6: this debt is PAID — do not re-queue or re-spend it."* P4 spent the
prose-pin debt in full, mutation-verified. A new test here would also move the suite
count that FR-007 freezes. Nothing is owed and nothing is queued (FR-010).

**Organisation**: one task per file, because each of the three sites lives in a
different file and no two tasks share a region. T002, T003 and T004 are therefore `[P]`
with each other. T001 checks the pre-state, T005 verifies, T006 audits the diff.

**Fan-out**: the cap is 3, and the largest legal batch here is exactly
{T002, T003, T004} — three files, three tasks, no shared region.

## Phase 1: Setup

- [X] T001 Verify the pre-state before touching anything: the branch is
      `006-release-1-1-0` off `main` at `220bf0d`; the shipped surface is clean apart
      from this run's own untracked spec tree and the private `docs/` archive; and phase
      F.5 has recorded the pre-change suite baseline. F.5 PRODUCES that baseline — this
      task only confirms it is there. No file is edited here.
      Checkpoint: `git rev-parse --abbrev-ref HEAD` prints `006-release-1-1-0`, and the
      state file's `test_baseline` is non-empty.

## Phase 2: User Story 1 — the version sites (Priority: P1)

- [X] T002 [P] Set `version` to `1.1.0` in `pipeline/.claude-plugin/plugin.json`,
      character-exact per `contracts/version-contract.md` site 1. It is a JSON STRING,
      matching how `1.0.1` is carried today. Change that one field and nothing else —
      do not reformat the file.
      Checkpoint: `jq -r '.version' pipeline/.claude-plugin/plugin.json` prints
      `1.1.0`, and `git diff --stat -- pipeline/.claude-plugin/plugin.json` shows
      exactly `1 insertion(+), 1 deletion(-)`.

- [X] T003 [P] Set `version` to `1.1.0` for the entry whose `name` is `pipeline` in
      `.claude-plugin/marketplace.json` — the REPOSITORY-ROOT file, not the one inside
      the plugin directory. Per contract site 2.
      The `handoff` entry in the same file keeps `2.1.0`; it is a fixture of this task,
      and if it moves that is a finding.
      Checkpoint: `jq -r '.plugins[]|select(.name=="pipeline").version'` prints `1.1.0`
      AND `jq -r '.plugins[]|select(.name=="handoff").version'` still prints `2.1.0`;
      the file still parses under `jq`.

## Phase 3: User Story 2 — the changelog heading (Priority: P2)

- [X] T004 [P] Replace the single line `## [Unreleased]` at `pipeline/CHANGELOG.md`
      line 5 with `## [1.1.0] - 2026-08-24`, per contract site 3. ONE line in, ONE line
      out — a REWRITE IN PLACE, never an insert above the existing section. Add nothing
      beneath it, remove nothing, reorder nothing, reword nothing (FR-004).
      STRICT vocabulary surface.
      Checkpoint: `grep -c '^## \[Unreleased\]'` prints `0`; `grep -c '^## \[1\.1\.0\]'`
      prints `1`; and — the one that matters — `sed -n '6,55p' | sha256sum` still begins
      `09bf16d6f4a4b59d` and `wc -c` still prints `3104`, proving the four accumulated
      entries did not move.

## Phase 4: Polish & validation

- [X] T005 Run quickstart §1-§5 in full, by EXTRACTING the bash blocks and EXECUTING
      them as one script — not by reading them. §1 must print `AGREE 1.1.0`; §2 must
      print `SHAPE OK` and `CONTROL OK`; §3 must reproduce the pre-change hash and byte
      count; §4 must show `2.1.0`, `0`, `1` and the descending heading order; §5 must
      report the full suite identical to the F.5 baseline. Record every output verbatim
      in Completion notes — measured, never predicted.

- [X] T006 Run quickstart §6, the diff audit. Read the changed LINES, not just the
      count: `git diff` over `pipeline/` and `.claude-plugin/` must show exactly six
      changed lines — three removed, three added — and `git diff --name-only --
      pipeline/skills/` must be EMPTY, proving the grep-pinned orchestrator prose was
      not touched at all. Three changed lines could still be the wrong three, which is
      why this task reads them.
      ALSO verify FR-009 here, because a prohibition with no check is a promise:
      `git tag --list 'pipeline-v1.1.0'` must print NOTHING. This run creates no tag —
      the seed prints the tag commands, which is exactly what invites a helpful run to
      execute them, so the absence is checked rather than assumed. The check is proven
      to bite: the same command against `pipeline-v1.0.1` finds the existing tag.

## Dependencies & Execution Order

T001 first — it only confirms the pre-state and F.5's baseline. Then T002, T003 and
T004 may run concurrently: three different files, no shared region, cap 3. T005 after
all three have landed. T006 last, because it audits the finished diff.

## Implementation Strategy

**Echo every mutated line back after writing it.** No test guards these three lines, and
this project has already proved that a no-op edit can otherwise read as success.

**The whole difficulty of this phase is not doing more than it says.** Three lines change.
Every task above carries a checkpoint that fails if a fifth line moves, and T006 exists
solely to catch the case where the count is right and the lines are wrong.

**Do not create a tag.** The seed prints the tag commands, which invites a helpful run
to execute them. They follow the merge and belong to the owner (FR-009).

## Completion notes (evidence)

### T001–T006 (2026-08-24, implemented by Claude in-session per the G answer)

All six tasks complete. Every output below was measured and pasted, never predicted.

**T001** — pre-state confirmed before anything was touched: branch
`006-release-1-1-0`, cut from `main` at `220bf0d`; shipped surface
(`pipeline/`, `.claude-plugin/`, `handoff/`) verified CLEAN; F.5's
`test_baseline` present in the state file.

**T002** — `pipeline/.claude-plugin/plugin.json`. Mutated line echoed back:
`  "version": "1.1.0",` at line 4. Checkpoint: `jq -r '.version'` -> `1.1.0`;
diffstat `1 insertion(+), 1 deletion(-)`.

**T003** — `.claude-plugin/marketplace.json`, the `pipeline` entry only. The
replacement was ANCHORED on the preceding `"source": "./pipeline",` line rather
than matching `"version": "1.0.1",` alone, because that string is not unique in
a multi-plugin file and an unanchored replace is how the wrong entry gets hit.
Mutated line echoed back: `      "version": "1.1.0",` at line 21.
Checkpoint: pipeline entry -> `1.1.0`; **`handoff` entry still `2.1.0`** — the
fixture held; file still parses under `jq`; diffstat `1 insertion(+), 1 deletion(-)`.

**T004** — `pipeline/CHANGELOG.md` line 5, ONE line replaced by ONE line.
Mutated line echoed back: `## [1.1.0] - 2026-08-24`.
Checkpoint: `[Unreleased]` count **`0`**; `1.1.0` heading count **`1`**; and the
one that matters — lines 6-55 hash **`09bf16d6f4a4b59d`** and **`3104`** bytes,
BOTH IDENTICAL to the values measured before the edit. The four accumulated
entries provably did not move: not reordered, not reworded, not shifted.
Diffstat `1 insertion(+), 1 deletion(-)`.

**T005 + T006 — the quickstart, EXTRACTED AND EXECUTED as one script, exit 0**

Not read. The bash blocks were pulled out with `awk`, syntax-checked, and run:
`extracted 47 lines / SYNTAX OK / EXIT=0`.

- §1 agreement, one command over all three sites: **`AGREE 1.1.0`**
- §2 shape: **`SHAPE OK`**, and the positive control **`CONTROL OK`** — the
  pattern accepts the pre-existing `1.0.1` heading too, so it is a real check
  and not one that passes on anything.
- §3 content identity: **`09bf16d6f4a4b59d`**, **`3104`** — unchanged.
- §4 nothing else moved: handoff **`2.1.0`**; `[Unreleased]` **`0`**; `1.1.0`
  heading **`1`**; headings `5:## [1.1.0] - 2026-08-24`,
  `57:## [1.0.1] - 2026-08-22`, `76:## [1.0.0] - 2026-08-20` — descending.
- §5 full house suite from the repository root: **`1..121`, ok=121 notok=0,
  non-TAP 0, exit 0** — byte-for-byte the F.5 baseline. Growth exactly zero.
- §6 diff audit: `3 files changed, 3 insertions(+), 3 deletions(-)`, and the
  six changed lines READ rather than counted —
  `-      "version": "1.0.1",` / `+      "version": "1.1.0",` /
  `-  "version": "1.0.1",` / `+  "version": "1.1.0",` /
  `-## [Unreleased]` / `+## [1.1.0] - 2026-08-24`.
  `git diff --name-only -- pipeline/skills/` printed **nothing** — the
  grep-pinned orchestrator prose was not touched at all, so the plan's
  "add near, never reword" constraint is satisfied by having nothing to reword,
  verified rather than assumed.
  **FR-009**: `git tag --list 'pipeline-v1.1.0'` printed **nothing** — no tag was
  created. Positive control `git tag --list 'pipeline-v1.0.1' | wc -l` -> **`1`**,
  proving the check can actually see a tag.

**What the difficulty of this phase actually was.** Not the three lines — not
doing a fifth. Two places invited it and both were declined on purpose: the seed
prints the `git tag` commands in full, and the marketplace file holds a second
plugin whose version sits three lines from the one being changed. The tag check
and the handoff fixture exist precisely because those are the two ways this
phase goes wrong.

All work left uncommitted — the commit gate has not run.

## Phase 5: H.7 — simplify (2026-08-24)

Two cleanup reviewers on opus covering four angles — reuse and simplification in
one, efficiency and altitude in the other — against the uncommitted diff, scoped
to `codeRoots` (`pipeline`, `.claude-plugin`). Four angles rather than four
agents because the diff is three lines; the interesting question was never
"is this prose tidy" but "is the ritual at the right altitude".

**Result: BOTH CLEAN. Zero in-scope findings, nothing to fix.** What the pass
produced instead was evidence, and one correction to this run's own premise.

### The correction — the brief I wrote was wrong, in the repo's favour

I briefed the altitude reviewer that keeping three files in agreement is "a
human's job checked by a hand-run command". **That is false**, and the reviewer
said so. Agreement is machine-enforced TWICE on every push and pull request:

- `tests/portability.bats:307` — *"every plugin's manifest, marketplace entry and
  changelog agree"*, asserting `plugin == marketplace` AND `plugin == changelog`
  at lines 387-388, walking `for dir in */` and resolving the marketplace entry
  BY NAME rather than by position.
- the `version` job in `.github/workflows/ci.yml`, a hand-maintained twin of it.

Verified independently rather than taken on the reviewer's word: the test was
read at source, and run against the stamped tree — `1..1, ok 1`.

**And the heading pattern I wrote into FR-006a is byte-identical to the one the
suite already uses**, which was not known when it was written:

```
^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$
```

`tests/portability.bats:380` carries that exact string. Two documents arriving
at the same pin independently is the good outcome, but the record should say the
suite got there first.

**The reviewer MUTATION-PROVED the gate bites**, on a scratch copy with the
working tree untouched: revert the changelog heading to `## [Unreleased]` while
the two JSON sites stay at `1.1.0`, and the `-m1` grep skips the unmatched
`[Unreleased]`, reads the OLDER `## [1.0.1]`, and the gate goes red with
`pipeline: plugin=1.1.0 changelog=1.0.1`. So a release shipped with
`[Unreleased]` still open IS caught — surfacing as a version disagreement rather
than as a format complaint. The bats comment at line 369 documents that
behaviour as "Measured, not assumed", which is how it was found.

Two honest LIMITS of that gate, recorded as limits and not as findings: a wholly
forgotten release — all three sites unbumped, `[Unreleased]` open — is green, and
correctly so, because that is the normal in-development state; and the date is
checked for SHAPE only, never against the real release date.

### The site survey — exhaustive, and there is no fourth site

The reuse reviewer swept the formal shipped surface (the `SHIPPED_*` lists at
`tests/portability.bats:79-82`) plus `pipeline/skills`, `pipeline/scripts` and
`pipeline/tests`, and tabulated EVERY version-shaped string in the repository
with a verdict on each. Three real sites, all three in the diff. Everything else
is a historical heading, a different plugin, a third-party version (bats, speckit,
Contributor Covenant), a test fixture, or a doc example of tag shape. **No badge
anywhere. No version-pinned install command.** The only version PARSERS in the
repository are the twin gates above, so there is no consumer that went unchecked.

One entry worth naming because it looks like a hit and is not:
`pipeline/scripts/preflight.sh:91` reads *"The observable is the 1.1.0
contract:"* — a code comment written in `70ebb80` while 1.1.0 was still
unreleased, naming the release its behaviour ships in. Nothing parses it, and the
stamp makes it ACCURATE rather than stale. Read at source and confirmed.

### The CI ordering is correct, and load-bearing

`.github/workflows/ci.yml:121` — the *"tag matches the manifest version"* step is
gated `if: startsWith(github.ref, 'refs/tags/')`, so merging to `main` skips it
and the owner's later `pipeline-v1.1.0` tag fires it, strips to
plugin=`pipeline` tag=`1.1.0`, and reads the manifest. Verified at source.

**Tagging BEFORE the merge would FAIL**, because `HEAD:pipeline/.claude-plugin/plugin.json`
on `main` still says `1.0.1` until the merge lands. So FR-009's prohibition is not
merely procedural tidiness — the seed's own ordering is what CI requires.

### Out-of-scope, recorded for the owner

1. **The hand-maintained twin is the real altitude debt.** `.github/workflows/ci.yml`
   and `tests/portability.bats:307` carry roughly forty near-identical lines of
   shell, and ci.yml's own comment admits they *"have drifted once already — an
   unanchored regex here read a heading the bats copy rejected."* One shared
   script invoked by both would end that class of drift. They agree TODAY —
   the reviewer ran ci.yml's version job verbatim and got `checked=2 PASS`.
   Both files are outside `codeRoots`.
2. **Site 2 could be deleted outright.** The platform schema makes the
   marketplace `version` OPTIONAL — only `name` and `source` are required, and
   `plugin.json` wins the resolution waterfall. Three sites could be two. Two
   blockers: both of this repository's own gates hard-require the field, so
   deleting it goes red until they change, and they sit outside `codeRoots`.
   Also worth knowing: no Claude Code tool warns when the two disagree, which is
   precisely why this repository built its own gates rather than trusting the
   platform.
3. **No release-summary line.** A reader must consume roughly fifty dense lines
   to learn what 1.1.0 IS. Foreclosed here by FR-004's byte-freeze on the content
   beneath the heading, so it is an observation, not a deferral.
4. **A sibling formatting difference**: `handoff/CHANGELOG.md` carries a
   Keep-a-Changelog/SemVer preamble that `pipeline/CHANGELOG.md` does not.
   Pre-existing, neither introduced nor exposed by this stamp.

### Evidence the reviewers produced

- `git diff --numstat` is `1 1` for all three files; `git diff -w --stat` shows
  the SAME three lines, so no whitespace-only churn is hiding; `git diff --check`
  clean; and `jq keys_unsorted` is byte-identical before and after in both JSON
  files — one FIELD changed, not a file reformatted.
- Content beneath the heading: 3104 bytes, sha256
  `09bf16d6f4a4b59da8c040fd3a5ccec567d01e938fac1dd1f2117779cbf4da66` — the
  contract's pinned value, independently reproduced.
- Zero hits across `pipeline/` and `.claude-plugin/` for the stale-wording class
  (`unreleased|not yet|coming in|next release|forthcoming|upcoming|will ship|to
  be released|in a future|soon`). The four entries are written in settled
  changelog voice, which is correct under a released heading.
- Full suite from the repository root: `1..121`, exit 0, zero `not ok`; prose 11.
  No test file in the diff.

## Phase 6: I — deep review (2026-08-24)

`pipeline:spec-review`, three lenses on opus — contract compliance in one agent,
security and tests as independent passes in a second. Both were told the settled
facts so no round was spent re-litigating a decision already made.

**Verdicts: contract COMPLIANT. Security no Critical, no Important, one Minor.
Tests PASS with the freeze held. Three fixes applied, all to THIS RUN'S OWN
DOCUMENTS — the shipped three lines were never in question.**

### T007 FIXED — the quickstart exited 0 even when a check FAILED

The sharpest finding of the phase, and it was in the verification document
itself. The script's exit status was simply that of its last command — a
`git tag --list ... | wc -l` that always succeeds — so a run could print
`DISAGREE` two screens above and still exit `0`. The tests lens caught it by
mutating a copy and observing `SCRIPT_EXIT=0` on a broken release.

Verified independently before fixing, with a three-line simulation: a `DISAGREE`
branch followed by a `wc -l` exits `0`. Confirmed.

Fixed by making every section self-judging: each check now sets `fail=1` and a
new §7 exits non-zero if any did. Twelve checks that previously only PRINTED a
value now emit a verdict — `CONTENT OK`, `BYTES OK`, `HANDOFF FIXTURE OK`,
`NO UNRELEASED OK`, `ONE 1.1.0 HEADING OK`, `HANDOFF CLEAN OK`, `SUITE OK`,
`SIX CHANGED LINES OK`, `SKILLS UNTOUCHED OK`, `NO TAG OK`, `TAG CONTROL OK`.

**Proven, not asserted.** On a mutated copy the script now prints
`DATE WRONG: 1999-01-01` then `QUICKSTART FAIL` and exits **1**. On the real
tree it prints `QUICKSTART PASS` and exits **0**. A check whose exit code cannot
fail is not a check.

### T008 FIXED — a hole that NOTHING anywhere caught

The tests lens ran eight mutations on an isolated copy and found four holes in
the durable guard set. Three of them the quickstart already caught. **One was
caught by nothing at all**: setting the changelog date to `1999-01-01` passed
the bats suite, passed the `ci.yml` version twin, and passed every check in the
quickstart — because both gates test the date for SHAPE and never for VALUE.
The lens ran the entire quickstart against that mutation and the output was
identical to a clean run except for one printed line a human had to notice.

Fixed: §2 now reads the date out of the heading and compares it to the value
`contracts/version-contract.md` pins. Shape is still checked; the value is now
checked too. This is the check that fired in T007's positive control.

### T009 FIXED — the pinned contract contradicted itself, and overclaimed a proof

The contract lens found the authoritative document holding two opposite
acceptance criteria: it opened *"Four lines change. This file pins all four"*
and closed *"A fourth changed line anywhere on the shipped surface is a
finding."* Measured: `git diff --numstat` is `1 1` for each of three files, so
**three lines change**. The origin is real and worth keeping rather than merely
correcting — there ARE four pinned STRINGS, because the heading is one changed
line but two strings, the old text and the new.

Corrected in six places (`contracts/version-contract.md`, `plan.md` ×3,
`tasks.md` ×3, `research.md`), each now saying "three lines, four pinned
strings", and the contract carries a note explaining why the two numbers differ
so the next reader does not re-introduce it.

The same lens caught an OVERCLAIM in the same file: hashing lines 6-55 was
called *"a COMPLETE proof of FR-004, not a sample"*. It is not complete alone.
Content APPENDED at line 56 — below the range, above the next heading — leaves
lines 6-55 byte-identical and passes, which is exactly the "add nothing"
violation FR-004 forbids. The §6 diff audit closes it, because such an entry
appears there as a seventh changed line. Both the contract and the quickstart
now say the hash and the diff audit prove FR-004 TOGETHER, and neither alone.

A related sharpening from the same analysis, recorded because it is the more
dangerous failure mode: a SHIFTED hash window fails loudly, but a MIS-PINNED
one — say 6-54 — would pass silently forever, because the expected value was
measured over that same wrong range. The range's correctness rests entirely on
the independent boundary measurement recorded in research R1, which the lens
reproduced.

### Security — no Critical, no Important

Measured rather than reasoned. `.github/workflows/ci.yml` is the only workflow;
`permissions: contents: read`; **zero** references to secrets, `GITHUB_TOKEN`,
publish, registry, `gh release`, artifact upload, `id-token` or `packages`.
**Merging this can cause nothing to be published and nothing to leave the
machine.** The owner's later tag triggers the same read-only workflow plus a
string comparison; there is no release-creation step behind it.

A user receives byte-identical behaviour before and after: the four features are
already on `main`, and this diff ships no skill, script, command or hook change.
There is **no window** in which the marketplace advertises a version the source
tree lacks — all three sites move in one commit.

The four accumulated entries were scanned as a now-public release note for URLs,
hosts, absolute paths, usernames, email and token-shaped strings: **nothing
found**, and both changed files are inside the leak scanners' registered surface
(`SHIPPED_PIPELINE` at `tests/portability.bats:81`), whose four leak tests pass.

**Security Minor, recorded not fixed**: the CI tag gate binds a tag to the
manifest version AT THE TAGGED COMMIT, not to `main`. A `pipeline-v1.1.0` tag
pushed on the feature branch BEFORE the merge would pass every check while
advertising a release `main` does not carry — and a tag is much harder to
retract than a branch. Tagging a pre-merge `main` fails safe with a named error,
which is the case the workflow comment was written for. Nothing publishes either
way, so this is a truthfulness gap rather than a supply-chain one. The fix is
the ordering the seed already specifies — merge, then tag — and FR-009 forbids
this run from tagging at all. An ancestry check
(`git merge-base --is-ancestor "$GITHUB_SHA" origin/main`) would enforce it;
`.github/` is outside `codeRoots`.

### Tests — the freeze held, and the mutation table

Counted independently: layout 4, portability 21, context-guard 51, preflight 20,
progress 14, prose 11 — **total 121**, prose **11**. Zero test files in the diff.
Live run `1..121`, `ok=121 notok=0`.

Eight mutations on an isolated copy, every one echoed back before running, every
one restored and verified. **Two attempts were caught as NO-OPS by echoing back**
— one pattern missed a clause wrapping across a line break, another used the
wrong em-dash encoding — and were re-done until an occurrence count proved the
edit landed. That is the house "prove a mutation landed" rule doing its job
inside a review.

| Mutation | Suite | Quickstart | Verdict |
|---|---|---|---|
| heading -> `[Unreleased]` | FAIL | catches | guard bites, obliquely |
| marketplace -> `1.0.1` | FAIL | catches | guard bites |
| plugin.json -> `1.0.1` | FAIL | catches | guard bites |
| all three -> `9.9.9` | **PASS** | catches | suite HOLE |
| date -> `1999-01-01` | **PASS** | **PASSED TOO** | **caught by nothing — now fixed, T008** |
| reword an unpinned entry | **PASS** | catches (hash) | suite HOLE |
| second `[Unreleased]` above | **PASS** | catches 4x | suite HOLE |
| invert a prose-PINNED clause | FAIL | catches | guard bites |

### Recorded debt for the owner — mutation-proved, no test proposed

The suite's holes below are real and were proved, not inferred. The quickstart
catches three of them, but it is a one-shot artefact of this run and does NOT
run in CI, so after this feature closes these are unguarded. No test is proposed:
the standing instruction names this phase and records the prose-pin debt as PAID.

1. **The changelog date is never checked against reality** by the durable guards.
   `ci.yml` shares the identical anchored regex, so the twin has the same hole by
   construction. Now caught by the quickstart (T008), not by CI.
2. **Three agreeing sites on a WRONG version pass the suite.** Both gates check
   AGREEMENT, never identity against an intended value; nothing in CI knows
   `1.1.0` was the target.
3. **Changelog content beneath the heading is unpinned except for three clauses
   of one entry.** Three of the four released entries can be reworded, or their
   meaning inverted, with the suite green.
4. **An `[Unreleased]` heading left open ABOVE a correct release heading passes
   the suite**, because the anchored `-m1` grep steps over an undated heading.
   This is the most LIKELY of the four to happen by accident on a future
   release, since it is exactly what a partial edit produces — and it surfaces
   as a version DISAGREEMENT naming the wrong file, which sends a maintainer
   diffing version numbers instead of looking at the heading.

### Evidence after all three fixes

The quickstart re-extracted, syntax-checked and EXECUTED on the real tree,
`SCRIPT_EXIT=0`:

`AGREE 1.1.0` / `SHAPE OK` / `CONTROL OK` / `DATE OK` /
`CONTENT OK 09bf16d6f4a4b59d` / `BYTES OK 3104` / `HANDOFF FIXTURE OK 2.1.0` /
`NO UNRELEASED OK` / `ONE 1.1.0 HEADING OK` / headings `5`, `57`, `76` descending /
`HANDOFF CLEAN OK` / `suite: exit=0 plan=1..121 ok=121 notok=0 nonTAP=0` /
`SUITE OK` / `3 files changed, 3 insertions(+), 3 deletions(-)` /
`SIX CHANGED LINES OK` / the six lines read / `SKILLS UNTOUCHED OK` /
`NO TAG OK` / `TAG CONTROL OK` / **`QUICKSTART PASS`**
