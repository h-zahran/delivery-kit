# delivery-kit dogfood plan — pipeline 1.0.1 and 1.1.0, driven by the pipeline itself

> **For agentic workers:** this plan is NOT executed with an SDD harness.
> Each `## Phase <N>:` section below is a SEED for one `/pipeline:pipeline`
> run — the pipeline generates its own spec, plan and tasks per phase.
> P0 is the only manual section. Seeds are written so the clarify gate
> has nothing left to ask; the human touches clarify and the implementer
> gate only.

**Goal:** ship `pipeline@delivery-kit` 1.0.1 (five truth/docs fixes) and
1.1.0 (constitution probe, richer implementer handoff package,
`implementer` pre-answer, J-loop cap) — every enhancement agreed on
2026-08-21 — using the pipeline and handoff plugins as the delivery
vehicle.

**Architecture:** six pipeline runs (P1–P6), strictly sequential, each
branching off `main`, each ending at a pull request the owner merges.
P1 ships 1.0.1 alone; P2–P5 accumulate under `## [Unreleased]`; P6
stamps and ships 1.1.0. P0 is a one-time manual setup that makes the
pipeline runnable in this repository.

**Tech Stack:** bash + jq + bats 1.11.0; spec-kit 0.16.5 (pinned);
GitHub Actions matrix unchanged; `gh` (PowerShell-only on this machine).

**Spec:** the agreed enhancement list — recorded in the session review of
the 2026-08-21 playground run and the six-point owner discussion; durable
copy in the agent memory file `r2-release-pr12-pending-merge.md`.

## Decisions (rulings — each one edit to undo)

1. ⚠️ **spec-kit is installed INTO delivery-kit, tracked.** Required: the
   pipeline stops without `.specify/` and has no degraded mode. The
   earlier "keep it out" stance protected the pre-release test moment;
   dogfooding supersedes it. `specs/`, `.specify/`, `.claude/skills/speckit-*`
   and this plan file will reach public `main` through PRs. They are
   this repo's own artifacts; nothing foreign. The release-tag CI suites
   must stay green with them tracked — P0's PR is the cross-platform proof.
2. **`planFile` stays the default** (`main-plan.md`, this file, repo root).
3. **`testCommand` stays null in every committed config.** The house bats
   path contains a machine username; it must never enter the repo's
   `.delivery-kit.json`. Each seed's Constraints block carries the exact
   command instead — seeds travel alone, preambles do not.
4. **`handoff/**` is untouched for this whole plan.** Only the pipeline
   plugin moves: 1.0.0 → 1.0.1 (P1) → 1.1.0 (P6). No handoff release.
5. **Strictly sequential.** One live run at a time; the next phase starts
   only after the previous PR is merged. Expect the cadence: 7 PRs
   (P0 + six runs), two tag pushes (after P1 and P6 merges).
6. **P1 runs WITHOUT `--auto`** — first pipeline run in this repo; watch
   the K and L gates show their content once. P2–P6 run with `--auto`.
7. **The G answer is "claude" for P1–P3 and P5–P6; "handoff" for P4** —
   P4 deliberately field-tests the new package template that P3 ships.
8. `worktree-two-plugins` is historical. Main-based flow supersedes it.
   Its SDD workspace is deleted only after verification checks 5–6 close.

   **AMENDED 2026-08-26 — both worktree registrations are removed; both
   branches are KEPT.** `git worktree remove` was run against
   `.claude/worktrees/two-plugins` and `.claude/worktrees/v1-context-guard`,
   reclaiming 3.2 MB of stale checkout inside the main tree. Verification
   checks 5–6 are closed by that removal: the SDD workspace is gone, the
   lineage is not.

   ⚠️ **The branches must never be pushed, and must never be deleted.**
   `git worktree remove` deletes the checkout, never the branch — that was
   verified before AND after, because these two branches are the ONLY carriers
   of the 221-commit pre-rewrite history. That history has no merge base with
   `main` (the release curation used an orphan root), it is not reachable from
   anything published, and it includes the private handoff commits. Pushing
   either branch would disclose the originating project in one step.
   Measured at removal: `worktree-two-plugins` at `6c823e7` with 221 commits,
   `worktree-v1-context-guard` at `3eeb00d` with 117 and a strict ancestor of
   the first. `archive/local-main-2026-08-16` at `e26723d` is a diverged
   sibling of the same lineage, kept on the same terms.

## Global Constraints (every seed implicitly includes these)

- House test suite (full, from repo root; exceeds 120s — extend timeouts):

  ```
  bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
  ```

  Baseline today: `1..116`, 116 ok, 0 not ok, 0 non-TAP. P2 grows it by
  +2, P3 by +1; every other phase leaves the count unchanged. Any other
  movement is a finding.

  **AMENDED 2026-08-23 — P4 grows it by +2, to `1..121`.** The owner
  overrode P4's review cap with "fix everything, no deferred", which
  spent the prose-pin test debt P2, P3 and P4 had each recorded and
  re-queued. A round-4 reviewer then showed the first shape of that spend
  hid the consent contract inside a test named for something else, so two
  new tests carry the consent contract and the sites outside it. Prose
  goes `1..9` -> `1..11`. **P5 and P6: this debt is PAID — do not
  re-queue or re-spend it.** The spend is
  mutation-verified; see `specs/004-implementer-key/research.md` R3 and
  the phase M round 4 note in that feature's tasks file.
- **Pinned strings — add near, never reword.** These exact strings in
  `pipeline/skills/pipeline/SKILL.md` are grep-pinned by
  `pipeline/tests/prose.bats` and MUST survive byte-for-byte: the five
  gate rows (`| Clarify | C |` … `| Release | O |`), all nine never-bend
  rows, `"Fix everything" is implied, I can skip the small ones`,
  `Every finding is fixed, or explicitly deferred with its reason recorded`,
  `Never write the dot form as the only spelling`, `hyphen-skills`,
  `` `--auto` never collapses O ``,
  `It never reports verification it did not do`, and the namespace names
  `pipeline:status`, `pipeline:spec-review`, `pipeline:device-verify`.
  `pipeline/commands/pipeline.md` keeps `disable-model-invocation: true`.

  **AMENDED 2026-08-23**: read this enumeration as HISTORICAL, complete
  through P3. P4 added roughly thirty more pins and this list was not
  grown, because a second copy of a registry is a second thing to go
  stale. The LIVING registry is `pipeline/tests/prose.bats` itself, plus
  each feature's `contracts/*.md`. Before rewording anything in the
  orchestrator, grep the suite — do not trust this list to be complete.
- **Vocabulary:** STRICT surfaces (`pipeline/README.md`, `pipeline/CHANGELOG.md`,
  `pipeline/docs/`, `pipeline/commands/`, `.claude-plugin/`) ban the whole
  words `flutter|dart|pubspec|supabase|gradle|graphify|speckit|superpowers`
  — write "spec-kit", `.specify/`, `specify init`. RELAXED surfaces
  (`pipeline/skills/`, `pipeline/scripts/`, `pipeline/tests/`) ban only
  `supabase|graphify|superpowers`.
- **Count-free shipped prose:** no shipped file states a count of plugins,
  suites, phases-per-file, or tests that the next change falsifies.
- Changelog headings are `## [X.Y.Z] - YYYY-MM-DD` — two suite gates
  parse that exact shape. New-version content accumulates under
  `## [Unreleased]` until its release phase stamps it.
- Versions must agree in three places per stamp:
  `pipeline/.claude-plugin/plugin.json`, the pipeline entry in
  `.claude-plugin/marketplace.json`, and the changelog heading.
- The pipeline never merges its own PRs; merges and tag pushes are the
  owner's. Tags are `pipeline-v<version>` on `main` after the merge.
- If the context guard fires mid-run: use `handoff:handoff`. A live run
  puts a Pipeline state section in the handoff document and
  `/pipeline --resume` in the resume block — that seam is 2.1.0's
  feature; gates are safe handoff points by construction.

---

## P0 — one-time setup (manual, not a pipeline run)

- [ ] **Step 1: clean start on main**

```
cd "$(git rev-parse --show-toplevel)"
git checkout main && git pull
git status --porcelain        # expect empty
git checkout -b setup-pipeline-dogfood main
```

- [ ] **Step 2: install spec-kit (pinned 0.16.5, non-interactive, sh)**

```
specify --version             # expect 0.16.5
specify init --here --force --non-interactive --integration claude --script sh
```

- [ ] **Step 3: ignore the state directory**

Append one line `.delivery-kit/` to `.gitignore` (so runs do not each
offer it).

- [ ] **Step 4: run `handoff:setup`** — the repo now has `.specify/`, so
  setup OFFERS the pipeline block (this closes install-verification
  check 6's positive half). Answer `planFile` = `main-plan.md` (or skip;
  the default matches). SKIP `testCommand`, `analyzeCommand`,
  `releaseCommand` — machine paths must not enter the committed file.

- [ ] **Step 5: stage by name, then the empirical gate**

```
git add -- .specify .claude .gitignore main-plan.md
git add -- .delivery-kit.json    # only if handoff:setup wrote it
```

Run the full house suite (Global Constraints). Expected: `1..116`,
116 ok, 0 non-TAP — WITH the spec-kit files staged, because the
repo-wide frontmatter gate sweeps every tracked SKILL.md, including
`.claude/skills/speckit-*`. A red here stops P0 — report it, fix
nothing silently.

- [ ] **Step 6: commit and PR**

```
git commit -m "chore: spec-kit scaffold and dogfood plan — the pipeline runs here now"
git push -u origin setup-pipeline-dogfood
```

Open the PR (gh from PowerShell, body via `--body-file` from a scratch
directory, read it back). The PR's CI matrix is the real cross-platform
proof that tracked spec-kit files break no gate. **Owner merges.** Then
`git checkout main && git pull`.

- [ ] **Step 7: start P1**

```
/pipeline:pipeline Phase 1: pipeline 1.0.1 — release-day truth and door polish
```

Seed titles carry em dashes — copy-paste the heading text rather than
retyping it, or the section lookup fails on a near-miss.

---

## Phase 1: pipeline 1.0.1 — release-day truth and door polish

Five agreed fixes from the 2026-08-21 live-run review, plus the 1.0.1
stamp, in one run. All edits are additive prose; no behavior changes.

**Requirements:**

1. In `pipeline/skills/pipeline/SKILL.md`, the **O — release** paragraph
   gains, after its final sentence: "With `releaseCommand` unset there is
   nothing to publish: record that in the state file and move on — the
   gate guards a command, it does not invent one."
2. The **N.5 — runtime check** section gains, after the sentence ending
   "then continue.": "Verification beyond the configured strategy is
   welcome when it is real — run it, then report it as exactly what it
   is: extra evidence, not the configured check." The pinned sentence
   `It never reports verification it did not do` stays byte-identical.
3. The **G — implementer gate** paragraph gains: "If the gate's answer
   later changes, delete the written package file (or stamp it VOID at
   the top) before proceeding — a stale package addressed to another
   model is an instruction nobody should find."
4. The **Ground rules** list gains one bullet: "**A missing tool is its
   own question.** When the run needs a tool the machine lacks, stop:
   name the tool, show the exact install command, and record the answer
   in the state file. Never install anything silently."
5. `pipeline/README.md` "How it runs": FIRST measure, in a live session,
   whether the short form `/pipeline` resolves at all (only
   `/pipeline:pipeline` has been observed in the field). Then make the
   three example invocations use the canonical namespaced spelling
   `/pipeline:pipeline …`, and add a short-form sentence ONLY if the
   measurement proved it resolves — whichever sentence is true, and no
   claim at all if it cannot be determined. (STRICT surface —
   hyphenated forms only.)
6. Stamp 1.0.1: `pipeline/.claude-plugin/plugin.json` → `1.0.1`;
   marketplace pipeline entry → `1.0.1`; `pipeline/CHANGELOG.md` gains
   `## [1.0.1] - <today>` above `## [1.0.0] …` listing these five fixes,
   count-free.

**Acceptance criteria:**

- Each new sentence findable by exact grep in its named file; every
  pinned string still present byte-for-byte (run
  `bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats` — 1..8 ok).
- Full house suite `1..116`, 0 non-TAP.
- `jq -r '.plugins[] | "\(.name) \(.version)"' .claude-plugin/marketplace.json`
  prints `handoff 2.1.0` and `pipeline 1.0.1`; plugin.json agrees.

**Constraints:** Global Constraints apply. Orchestrator and its tests are
RELAXED surfaces; README/CHANGELOG/marketplace are STRICT. Suite count
stays 116 — this phase adds no tests.

**After the merge (owner + assistant):**

```
git checkout main && git pull
git tag pipeline-v1.0.1 && git push origin pipeline-v1.0.1
```

Watch the tag CI. Then start P2 with `--auto`.

---

## Phase 2: constitution — probe it, print it, offer it once

spec-kit's constitution (`.specify/memory/constitution.md`) gates the
plan phase, but a fresh init leaves an unfilled template and the
pipeline never says so. Make its state visible and offer the fix.

**Requirements:**

1. `pipeline/scripts/preflight.sh` emits one new boolean,
   `speckit.constitutionSet`. Contract (the observable is pinned; the
   detection mechanism is the implementer's): a constitution file as
   `specify init` leaves it (unfilled template, or absent) → `false`;
   a constitution a human has actually written → `true`. External
   contract otherwise unchanged — same flags, same keys, stdout still
   pure JSON.
2. Two new bats tests appended to `pipeline/tests/preflight.bats` (no
   new test file): one proving `false` on a fresh-init-shaped fixture,
   one proving `true` once the file carries real principles. Both seen
   red before the script change lands (test-first).
3. `pipeline/skills/pipeline/SKILL.md`: the pre-flight probe block gains
   a `Constitution` line (`set` / `not set — plan gates run against an
   empty document`), and the pre-flight decision list gains: when
   `constitutionSet` is false, OFFER running `/speckit-constitution`
   once — the principles are the owner's to write, declining is fine,
   and the offer is not repeated within a run.
4. `pipeline/CHANGELOG.md` gains `## [Unreleased]` (this phase creates
   it, above `## [1.0.1] …`) with an Added entry for the probe + offer.

**Acceptance criteria:**

- The two new tests pass; full suite `1..118`, 0 non-TAP.
- `preflight.sh` run against a fresh-init fixture prints
  `"constitutionSet": false`; against a written one, `true`.
- All pinned strings intact (prose.bats 1..8 ok).

**Constraints:** Global Constraints apply. `preflight.sh` and its tests
are RELAXED surfaces. Do not create new fixture directory trees with
dependencies — fixtures under `pipeline/tests/fixtures/` are re-included
wholesale by the tracked `.gitignore`.

---

## Phase 3: the implementer handoff package, upgraded

Replace the G phase's one-paragraph package description with a full
package contract, so a cheaper model receives everything a good handoff
carries. Modeled on the owner's field-tested format.

**Requirements:**

1. In `pipeline/skills/pipeline/SKILL.md`, the **G — implementer gate**
   paragraph keeps its existing derived-forbidden-list sentence and the
   P1 VOID sentence, and gains a specification of the package's seven
   parts (as prose or a compact list — the implementer's choice of
   shape, all seven present by name):
   - **Files to provide** — a table of the spec artefacts (spec, plan,
     tasks, research, contracts, quickstart, data-model where present)
     with absolute paths, each verified to exist before the package is
     written; the verification is stated in the package.
   - **Repository state** — branch (checked out), tree state, and the
     verbatim baselines recorded at F.5 (test counts) plus the analyzer
     baseline where one exists — so any new failure is provably the
     implementer's.
   - **Instructions** — task order and phase groupings from the tasks
     file; `[P]`-marked tasks in the same phase may run concurrently;
     mark each completed task `[X]`; never restructure spec.md, plan.md
     or tasks.md; the per-phase verification command.
   - **The forbidden list** — derived, as already specified.
   - **What will bite this feature** — the run's accumulated non-obvious
     knowledge, derived from: clarify answers, research-file decisions,
     and anything discovered mid-run and recorded (each item names its
     source). Empty is allowed but must be stated as empty.
   - **Validation before "done"** — a checklist with the exact commands
     and the baseline numbers.
   - **Report-back contract** — the implementer keeps a visible todo
     board while working, leaves work uncommitted, and reports: status,
     files touched, test output verbatim, and anything it could not do.
2. One new test appended to `pipeline/tests/prose.bats` pinning the
   seven part names in the G section (grep gate, mutation-verified:
   delete one name → red).
3. Changelog Added entry under `## [Unreleased]`.

**Acceptance criteria:** prose.bats `1..9` ok; full suite `1..119`,
0 non-TAP; all previously pinned strings intact.

**Constraints:** Global Constraints apply. Add near, never reword: the
existing G sentences (including `--auto` never collapses this gate: it
spends money) stay byte-identical.

---

## Phase 4: pre-answer the implementer gate — the loop closes

With this key set, a run under `--auto` touches the human at clarify
only. Run THIS phase with the G answer "handoff" to field-test P3's
package: the run parks at H with the package file written — hand that
file to any cheap model ("read this file and do exactly what it says"),
let it finish, then `/pipeline:pipeline --resume` to re-enter at H and
carry on through review and the commit gate.

**Requirements:**

1. New configuration key `implementer` — default unset; legal values
   `claude` and `handoff` *(a third, `ask`, was added at phase M round 4
   on the owner's "fix everything, no deferred" — it restores the stop,
   and it is the only spelling that overrides an inherited pre-answer,
   since a later layer's `null` is silence)*. New flag
   `--implementer <claude|handoff|ask>`,
   which beats the config key (standard precedence). Added to BOTH
   tables: the orchestrator's Configuration table and Flags table, and
   `pipeline/docs/configuration.md`'s JSON block and key table — names
   and defaults character-identical across the two files.
2. Orchestrator **G** paragraph gains the quoted sentences below. *(As
   seeded, and as shipped through phase M round 3. REWORDED at round 4:
   adding `ask` made "When `implementer` is set … does not stop" FALSE,
   because `ask` is set and G does stop on it — freezing the pin would
   have shipped the defect class four rounds were spent hunting. The
   shipped text is four sentences and lives in
   `specs/004-implementer-key/contracts/key-contract.md`; what follows is
   the seed's wording, kept as the record of what was asked for.)*
   "When `implementer` is set
   (config or flag), G records the configured answer in `gates` and does
   not stop — the choice was typed on purpose. Everything else about G
   is unchanged, and a set `implementer` silences nothing else: cap
   breaches, hard failures and every other gate still stop exactly as
   before."
3. `pipeline/docs/configuration.md` explains the key in one paragraph:
   what it pre-answers, that unset means ask, and that it exists so an
   `--auto` run touches the human at clarify only. (STRICT surface.)
4. Changelog Added entry under `## [Unreleased]`.

**Acceptance criteria:**

- Key/flag rows present and identical across both files (compare
  character-for-character); pinned strings intact (prose.bats `1..11` ok —
  `1..9` as first written, +2 by the owner-ordered test-debt spend above);
  full suite `1..121`, 0 non-TAP.
- The G gate row `| Implementer | G |` unchanged.

**Constraints:** Global Constraints apply. `handoff/**` untouched
(Decision 4) — the setup skill does NOT learn this key in this plan.

---

## Phase 5: a cap for the J loop

J ("analyzer and full suite") loops until clean with no numeric cap —
the only unbounded loop in the product. Give it the same shape as F
and M.

**Requirements:**

1. New configuration key `maxVerifyIters`, default 5: the J fix loop
   runs at most that many iterations; a cap breach is a conditional
   stop (show the remaining failures, ask whether to continue). Added to
   the orchestrator's Configuration table, the **J** paragraph
   ("Loop until clean against baseline, at most `maxVerifyIters`
   iterations; a cap breach is a conditional stop; a hard failure still
   stops the run outright"), and `pipeline/docs/configuration.md` (JSON
   block + key table) — character-identical across files.
2. Changelog Added entry under `## [Unreleased]`.

**Acceptance criteria:** rows identical across both files; pinned strings
intact; full suite `1..121`, 0 non-TAP (P4 spent the prose-pin debt: +2).

**Constraints:** Global Constraints apply.

---

## Phase 6: release pipeline 1.1.0

**Requirements:**

1. Stamp 1.1.0: `pipeline/.claude-plugin/plugin.json` → `1.1.0`;
   marketplace pipeline entry → `1.1.0`; `pipeline/CHANGELOG.md`'s
   `## [Unreleased]` heading becomes `## [1.1.0] - <today>` (content
   beneath it — P2, P3, P4, P5 entries — already complete; add nothing,
   remove nothing).
2. Version agreement proven with the jq line from P1's acceptance.
3. Full house suite from the repo root before the commit gate:
   `1..121`, 0 non-TAP (P4 spent the prose-pin debt: +2).

**Acceptance criteria:** three stamp sites agree on `1.1.0`; changelog
heading shape parses; suite green.

**Constraints:** Global Constraints apply. This phase changes versions
and one heading — nothing else.

**After the merge (owner + assistant):**

```
git checkout main && git pull
git tag pipeline-v1.1.0 && git push origin pipeline-v1.1.0
```

Watch the tag CI. The plan is complete when it is green.

---

## Not in this plan (recorded, deliberately excluded)

- The crash-resume lock carve-out (every crash-resume hits a lock
  refusal) — needs an owner design ruling first.
- The unset-`releaseCommand` hint-format pin test; preflight test 14's
  "override" name; the Phase I reviewer-multiplicity sentence; a
  stage-first note for new `.bats` files in CONTRIBUTING — small fable-
  review leftovers, not part of the agreed set.
- Any `handoff` plugin change (Decision 4), including teaching
  `handoff:setup` the `implementer` key — a 2.2.0 candidate.
- iOS runtime verification, monorepos, other harnesses — still Not in v1.

---
---

# Campaign 2 — the verified review, remediated (pipeline 1.2.0, handoff 2.1.1)

> **For agentic workers:** same contract as Campaign 1 above. Each
> `## Phase <N>:` section below is a SEED for one `/pipeline:pipeline`
> run. `## M1` is manual and is not a seed. Seeds are written so the
> clarify gate has nothing left to ask.

**Goal:** close every finding of the 2026-08-25 enhancement review that
survived independent verification, and ship the result as
`pipeline@delivery-kit` 1.2.0 and `handoff@delivery-kit` 2.1.1 — folding
both currently-open `## [Unreleased]` headings into release headings on
the way.

**Architecture:** ten pipeline runs (P7–P16), strictly sequential, each
branching off `main`, each ending at a pull request the owner merges,
plus one manual section (M1) that touches no tracked file. P7–P15
accumulate under each plugin's `## [Unreleased]`; P16 stamps and ships
both plugins.

**Tech Stack:** bash + jq + bats 1.11.0; spec-kit 0.16.x (pinned);
GitHub Actions matrix unchanged; `gh` (PowerShell-only on this machine);
shellcheck (arrives in P12).

**Spec:** `docs/reviews/2026-08-25-enhancement-review.md` — the review —
and `docs/reviews/2026-08-25-enhancement-review-VERIFIED.md`, which
records what five independent read-only verifiers confirmed, corrected
and disproved at `main` = `4c3bcd4`. **The VERIFIED document is
authoritative wherever the two disagree.** Both are per-clone excluded
(`docs/` is in `.git/info/exclude`) and neither is tracked; a clone that
lacks them can still execute this plan, because every number the seeds
depend on is restated in the seed.

## Campaign 2 decisions (rulings — each one edit to undo)

9. **New seeds carry no em dash in the heading.** Campaign 1's P0 step 7
   records the near-miss: an em-dash title has to be copy-pasted or the
   section lookup fails. Campaign 2's headings are dash-free, so the
   invocation line under each phase can be retyped safely.
10. **The username scrub is a token substitution, never a rewrite.**
    Every site below is a dated record of a completed run. Replace the
    username token and nothing else; the surrounding sentence, its
    numbers and its date stay byte-identical. A record that is edited
    for style stops being evidence.
11. **The tree-wide path scan is a NEW test, not a wider `SHIPPED*`
    list.** The vocabulary scans are surface-scoped on purpose
    (`tests/portability.bats:102–114` argues it, and the argument still
    holds: nearly every file under `specs/` matches the banned
    vocabulary by design). A machine path is a different property with a
    different scope — it must appear nowhere tracked. Two properties,
    two scopes, two tests. Widening `SHIPPED*` to reach `specs/` would
    redden the vocabulary scan on contents that are correct.
12. **Every phase runs `--auto --implementer claude`, with the flags
    AFTER the seed text.** `pipeline/README.md` documents the shape as
    `/pipeline <seed> --auto`, and the front-door command passes
    `$ARGUMENTS` through verbatim, so the seed comes first and the flags
    trail it. Each phase's Invocation block below is already in that
    shape — copy the whole line. The work is precise and
    judgement-heavy, with pinned strings on every side; Campaign 1's P4
    already field-tested the `handoff` package and nothing here needs to
    re-prove it. `--auto` collapses only K and L: C and O still stop,
    and O is never collapsed without `--auto-release`, which this
    campaign never types.
13. **Test-only and repo-tooling changes get no changelog entry.** A
    changelog records what a user can observe. P7–P12 therefore write no
    changelog line at all; P13, P14 and P15 do. Each phase states its
    routing explicitly so this is never a judgement call mid-run.
14. **`handoff/**` is IN SCOPE this campaign** (Campaign 1's ruling 4 is
    spent — it was scoped to Campaign 1). Teaching `handoff:setup` the
    `implementer` key remains excluded; see "Not in this plan" below.

## AMENDMENT to Campaign 1 ruling 3 (2026-08-26)

Ruling 3 kept the house bats path out of `.delivery-kit.json` and put it
in each seed's Constraints block instead. **That is the mechanism that
published the username 35 times.** Phase A copies the seed verbatim into
`specs/<feature>/`, and the spec tool then quotes it into `plan.md`,
`tasks.md` and `quickstart.md`. The config file stayed clean and the
repository did not.

**From 2026-08-26, seeds carry the portable form only:**

```
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
```

`$HOME` resolves to the same directory on this machine, and the string
contains no username. `CONTRIBUTING.md:8–9` already documents exactly
this form, so the portable spelling is the documented one and the leaked
spelling never was. `testCommand` still stays null in every committed
config — ruling 3's original half is unchanged.

## Campaign 2 Global Constraints (every Campaign 2 seed includes these)

- **House test suite** (full, from repo root; exceeds 120s — extend
  timeouts):

  ```
  bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
  ```

  **Measured baseline 2026-08-26 at `main` = `4c3bcd4`: `1..121`, 121
  ok, 0 not ok, 0 non-TAP, exit 0.** Each phase below states its
  required delta. Any other movement is a finding.

- **Verify releases and suites from the repo root.** A suite can pass in
  a worktree and fail at the root. Every count in this campaign is a
  root measurement.

- **⚠️ Positive-control every ad-hoc verification grep, before trusting
  a green.** Measured 2026-08-26 while writing this plan: a regex passed
  as a shell argument through the agent harness lost one level of
  backslash escaping. The two Windows drive branches of the ban
  alternation then ended in a bare backslash each, which `grep` read as
  escaping the following pipe. The alternation collapsed, and the scan
  reported **0 hits over a tree holding 36** — with no error and exit 0.
  Moving the regex into a pattern file did NOT fix it; the file needed
  its own escaping and errored with "Trailing backslash".

  **What works:** one `grep -F` per shape, each shape a fixed string,
  never one escaped alternation — and fire a pattern that MUST match
  before believing one that must not. This applies to the implementer's
  own spot-checks, not to the suite: a pattern written inside a `.bats`
  file never crosses an argv boundary and is unaffected.

- **⚠️ This plan file must never contain a joined banned literal, and NO
  TEST WILL CATCH ONE.** It is tracked, and it is the file that defines
  the scan — but it appears in none of the `SHIPPED` lists
  (`tests/portability.bats:169-172`), so no vocabulary scan ever reads
  it. **Measured 2026-09-04 by mutation, and against the WHOLE suite
  rather than against the one test that looked most likely:** a banned
  term was appended to this file, the append was confirmed with `tail`
  rather than assumed, and every test stayed green — `1..167`, 167 ok,
  0 not ok, exit 0. The file was then restored and `cmp` proved it
  byte-identical. The exclusion is deliberate and correct: the working
  record is held outside those lists (`:196`) because a plan that
  specifies a detector has to name what the detector detects (`:198`).
  The tree-wide scan at `:302` DOES read this file, but it looks for
  machine paths, not vocabulary, so it cannot stand in — "some scan
  reads this file" and "the scan this rule needs reads this file" are
  different sentences, and conflating them is how the error below
  lasted. **An earlier form of this constraint claimed the file "sits
  inside the new scan's scope", and that writing a literal "would make
  the plan a hit on its own guard". Both were false, and both survived
  because every check of them was a reading of the lists rather than a
  measurement.** So the rule here is discipline, not a gate: name every
  banned shape descriptively, or assemble it from parts in a command,
  and grep for it yourself — with a positive control, because an
  alternation that loses one level of backslash escaping reports zero
  over a tree holding thirty-six. Measured on the first draft of this
  section: three such literals were written into it and removed on
  review.

- **Pinned strings — add near, never reword.** The LIVING registry is
  `pipeline/tests/prose.bats` plus each feature's `contracts/*.md`.
  Before rewording anything in the orchestrator, grep the suite. Do not
  trust Campaign 1's enumeration to be complete; it is historical
  through P3.

- **Vocabulary:** unchanged from Campaign 1. STRICT surfaces
  (`pipeline/README.md`, `pipeline/CHANGELOG.md`, `pipeline/docs/`,
  `pipeline/commands/`, `.claude-plugin/`, and the root documents) ban
  `flutter|dart|pubspec|supabase|gradle|graphify|speckit|superpowers`.
  RELAXED surfaces (`pipeline/skills/`, `pipeline/scripts/`,
  `pipeline/tests/`) ban only `supabase|graphify|superpowers`.

- **Count-free shipped prose:** no shipped file states a count of
  plugins, suites, phases-per-file, or tests that the next change
  falsifies. This plan file is not shipped prose and does state counts.

- **`git add` by name, never `git add -A`.** `docs/` is ignored only via
  `.git/info/exclude`, which is per-clone. A fresh clone has no guard at
  all until M1's CONTRIBUTING block is followed. Stage named paths.

- Changelog headings are `## [X.Y.Z] - YYYY-MM-DD`; two suite gates
  parse that exact shape.

- Versions must agree in three places per stamp: the plugin's
  `plugin.json`, its entry in `.claude-plugin/marketplace.json`, and its
  changelog heading.

- The pipeline never merges its own PRs. Merges and tag pushes are the
  owner's; the auto-mode classifier blocks the assistant from merging to
  `main`.

## Coverage — every verified finding routed

| Finding | Verdict at verification | Where it lands |
|---|---|---|
| H1 machine path published | Real, and wider: 35 lines / 17 files | **P7** |
| H2 two stale worktrees | Real | **M1** (manual) |
| H3 per-clone exclude is fragile | Real | **M1** (CONTRIBUTING block) |
| H4 stale `docs/specs` comment | Real, half-stale | **P7** |
| D1 `spec-review`/`device-verify` undiscoverable | Real | **P15** |
| D2 no phase-letter reference | Headline overstated; narrow gap real | **P15** |
| D3 setup description drifted | Real | **P15** |
| D4 sample omits `Implementer` line | Real | **P15** |
| D5 env vars never named in root README | Real | **P15** |
| D6 root `docs/` omitted | **NOT a defect** — `docs/` is untracked and deliberately excluded | Excluded, deliberately |
| D7a upgrade section byte-identical twin | Real (31 lines, `cmp`-identical) | **P15** |
| D7b window-asymmetry prose ×6 | Real, count was 4 | **P15** |
| D7c spec-kit range ×5 | Real, count was 4 | **P15** |
| D8 changelog vs README spelling | Historical; changelogs are immutable | Excluded, no action |
| T1 untested paths | Real, except the multi-line `<!--` claim | **P8, P9, P10, P11** |
| T2 `BATS_TEST_TIMEOUT` in one suite | Real | **P8** |
| T3 fixture duplication | Real (24 / 5 / 27 confirmed) | **P9, P10** |
| T4 CI version job is a hand twin | Real, self-acknowledged | **P12** |
| T5 `.leakwords` test re-implements folding | Real | **P8** |
| T6 prose-pin brittleness | Acknowledged in-file as deliberate | Guidance only, in **P11** |
| C1 no shellcheck | Real (one vendored suppression exists) | **P12** |
| C2 bats cloned per job | Real; pin is a mutable ref | **P12** |
| C3 no release artifact step | Real, but recorded as a security invariant | Excluded, see below |
| P1 guard spawns 13 jq processes | Real (5/9/13 for 0/1/2 config files) | **P14** |
| P2 pre-flight never probes git | Real | **P13** |
| P3 lock has no age staleness | Recorded by its author as a considered non-change | Excluded, no action |
| P4 guard only sees PostToolUse | Real, but changes the consent profile | Excluded, needs owner ruling |
| P5 SessionStart nudge | Real, but a new feature | Excluded, needs owner ruling |
| P6 manifest/marketplace version twin | Superseded by T4's extraction | Folded into **P12** |
| Review's "125 tests" | **FALSE** — the real count is 121 | No action; baseline above is measured |
| Review's "multi-line `<!--` unpinned" | **FALSE** — pinned by the `constitution-set` fixture | Excluded from P9 by name |

---

## M1 (manual, not a pipeline run): retire the worktrees, arm a fresh clone

Run this before P7. It touches no tracked file, so it produces no PR.

- [ ] **Step 1: prove what the branches carry, before touching anything**

```
cd "$(git rev-parse --show-toplevel)"
git worktree list
git branch --list 'worktree-*' 'archive/*'
git rev-list --count worktree-two-plugins
git rev-list --count worktree-v1-context-guard
```

Expect two worktrees (`two-plugins` @ `6c823e7`, `v1-context-guard` @
`3eeb00d`), both clean, and counts of 221 and 117.

- [ ] **Step 2: remove the two REGISTRATIONS — never the branches**

```
git worktree remove .claude/worktrees/two-plugins
git worktree remove .claude/worktrees/v1-context-guard
git worktree list
git branch --list 'worktree-*'
```

⚠️ **`git worktree remove` deletes the checkout, not the branch. Verify
the second command still lists BOTH branches before going further.**
These branches have no merge base with `main` (the release curation used
an orphan root) and they are the only carriers of the 221-commit
pre-rewrite history, including the private `docs/handoffs` commits.
**Never push either branch.** If `git branch --list` comes back short,
stop and restore from reflog before doing anything else.

- [ ] **Step 3: DRAFT the decision line — do not write it yet**

⚠️ **Do not edit this file during M1.** An uncommitted edit leaves the
tree dirty, and P7's pre-flight aborts on a dirty tree that no state
file or handoff document claims (`pipeline/skills/pipeline/SKILL.md`
pre-flight decision item 5). P7 requirement 8 writes this line inside
its own run.

Draft, for P7 to paste verbatim under Campaign 1 ruling 8:

```
**AMENDED 2026-08-26:** both worktree registrations under
`.claude/worktrees/` were removed. The BRANCHES are kept and remain
unpushed — they are the only carriers of the 221-commit pre-rewrite
history, which has no merge base with `main` and includes the private
`docs/handoffs` commits. Verification checks 5-6 are closed by the
removal; the SDD workspace is gone, the lineage is not.
```

- [ ] **Step 4: write the fresh-clone block for CONTRIBUTING**

This is the H3 fix and it is drafted here so P15 can paste it verbatim
into `CONTRIBUTING.md` under a new `## After cloning` heading:

```
git clone <url> delivery-kit && cd delivery-kit
printf '%s\n' '.claude/' 'docs/' '.delivery-kit/' >> .git/info/exclude
git check-ignore -v docs/ .claude/ .delivery-kit/
```

The third command must name `.git/info/exclude` for all three paths. A
fresh clone carries `.gitignore` but NOT `.git/info/exclude`, so until
those lines exist, `docs/` — the private handoff archive — is ignored by
nothing in a public repository. That is a measured near-miss, recorded
in the exclude file itself on 2026-08-25.

- [ ] **Step 5: commit this plan and open its PR — P7 cannot start until
      it is merged**

Campaign 2 was appended to `main-plan.md` on 2026-08-26 and is
UNCOMMITTED. P7's pre-flight aborts on a dirty tree, so the plan has to
be on `main` before the first run.

```
cd "$(git rev-parse --show-toplevel)"
git checkout main && git pull
git checkout -b plan-campaign-2 main
git add -- main-plan.md
git status --porcelain
```

⚠️ **Stage by name.** `git add -A` would sweep `docs/`, which holds the
private review documents this campaign was written from and is ignored
only by the per-clone `.git/info/exclude`. `git status --porcelain` must
show exactly one staged file and nothing else.

```
git commit -m "docs(plan): campaign 2 — remediate the verified 2026-08-25 review"
git push -u origin plan-campaign-2
```

Open the PR with `gh` **from PowerShell** — it is a Scoop shim the Bash
tool cannot see — and pass the body with `--body-file` from the
scratchpad, then read it back to confirm it landed; an inline body is
silently truncated. **Owner merges.** Then:

```
git checkout main && git pull
git status --porcelain        # expect empty
```

Now start P7.

---

## Phase 7: the machine path leaves the repository

The repository publishes its author's Windows username 35 times across
17 tracked files, plus one absolute Windows repo-root path in an
eighteenth — 36 lines in all, on `origin/main`.
`tests/portability.bats:28` bans every one of these shapes already, but
scans only the `SHIPPED*` lists, which do not reach `specs/` or this
plan file. Scrub the sites, then add the guard that would have caught
them, then correct the comment that describes a tree which no longer
exists.

**Requirements:**

1. **Scrub 32 lines carrying the house bats path.** In all 17 files
   listed below, rewrite the leaked absolute form — `bash`, then the
   machine's Git-Bash home directory spelled out literally, then
   `/bats/bin/bats` — to `bash "$HOME/bats/bin/bats"`. Substitute the
   token only; leave every surrounding word, number and date
   byte-identical (ruling 10).

   ⚠️ **This plan file deliberately never writes the username.** Writing
   it here would add an eighteenth leak site to the file that defines
   the scan. Locate every site with the acceptance-criteria grep below,
   not by typing the name; the token is the value of
   `$(basename "$HOME")` on this machine.

   The files and their line counts:

   ```
   main-plan.md                                  2
   specs/001-pipeline-101-polish/plan.md         1
   specs/001-pipeline-101-polish/quickstart.md   2
   specs/001-pipeline-101-polish/spec.md         1
   specs/001-pipeline-101-polish/tasks.md        1
   specs/002-constitution-probe/plan.md          1
   specs/002-constitution-probe/quickstart.md    3
   specs/002-constitution-probe/tasks.md         2
   specs/003-implementer-handoff/plan.md         1
   specs/003-implementer-handoff/quickstart.md   2
   specs/003-implementer-handoff/tasks.md        1
   specs/004-implementer-key/plan.md             1
   specs/004-implementer-key/quickstart.md       2
   specs/005-verify-iters-cap/plan.md            1
   specs/005-verify-iters-cap/quickstart.md      2
   specs/006-release-1-1-0/quickstart.md         1
   specs/006-release-1-1-0/tasks.md              8
   ```

   Note `specs/001-pipeline-101-polish/plan.md:19` carries TWO
   invocations on one line — 32 lines, 33 occurrences.

   Where a site already resolves through `$BATS` then `PATH` and falls
   back to the literal path — `specs/006-release-1-1-0/quickstart.md:232`
   is the shape — keep the resolution order and replace only the
   fallback arm, so the line becomes
   `"${BATS:-$(command -v bats || echo "$HOME/bats/bin/bats")}"`.

2. **Scrub the three remaining username sites.**
   `specs/006-release-1-1-0/tasks.md:1132` and `:1220` carry the
   username inside an `AppData/Local/Temp` path;
   `specs/006-release-1-1-0/quickstart.md:14` carries it inside an
   already-elided `bash …/...` form. These have no portable equivalent —
   they are prose describing a measured path. Replace the username token
   with the literal four characters `<user>` and change nothing else.

   **Plus one site the review missed entirely.**
   `specs/001-pipeline-101-polish/quickstart.md:3` writes the absolute
   Windows repo root — drive letter, colon, backslash, then the two path
   segments — as a "Prerequisites: repo root …" line. Measured
   2026-08-26 with `grep -F`; the review's greps never reached it
   because its own combined pattern silently collapsed. This shape is
   already banned by `tests/portability.bats:28` and the file is simply
   outside the scanned surface. Replace the absolute path with
   `<repo root>` and change nothing else. That makes **36 lines across
   18 files** in total for this phase.

3. **Do NOT touch the three elided prose lines.**
   `specs/003-implementer-handoff/tasks.md:103`,
   `specs/006-release-1-1-0/quickstart.md:127` and
   `specs/006-release-1-1-0/tasks.md:1219` write `/c/Users/...` with no
   username. `specs/003-implementer-handoff/tasks.md:103` is the recorded
   deferral of this exact sweep; erasing it erases the debt's paper
   trail. The new scan's pattern is narrowed so these do not match.

4. **Reword Campaign 1's Spec line, `main-plan.md:27`.** It carries an
   absolute per-machine memory path — the `~/.claude/projects/` prefix
   followed by a project slug — which matches the existing
   `BANNED_PATHS` shape `~/\.claude/projects/[A-Za-z0-9-]`. Replace the
   path with a pathless pointer naming the memory file by its basename
   only. This is preamble, not a dated log, so ruling 10 does not bind
   it. It is the only hit of this shape in the tree; measured
   2026-08-26.

5. **Add the tree-wide machine-path scan** as a new test in
   `tests/portability.bats`. The observable is pinned; the mechanism is
   the implementer's. Contract:
   - It scans **every tracked file except root `tests/`** — the
     exclusion is the same construction reason `tests/portability.bats:84–86`
     already gives for the vocabulary scans: this tree holds the
     denylist and the fixtures, so a scan covering it fails on its own
     contents.
   - **Four shapes**, matching the four already in `BANNED_PATHS` at
     `tests/portability.bats:28`, with one narrowing:
     1. `[/]c/Users/[A-Za-z0-9_]` — the Git-Bash home prefix followed by
        a name character. The `[A-Za-z0-9_]` tail is the narrowing, and
        it is what lets requirement 3's elided prose survive: verified
        2026-08-26, the prefix followed by a letter matches and the
        prefix followed by an ellipsis does not.
     2. The Windows `C:` Users prefix (drive letter, colon, backslash,
        `Users`, backslash).
     3. The Windows `D:` drive root (drive letter, colon, backslash).
     4. `~/\.claude/projects/[A-Za-z0-9-]`.

     Shapes 2 and 3 are spelled descriptively here on purpose — see the
     Global Constraint above. Inside the `.bats` file they are written
     literally, which is safe because root `tests/` is outside the scan.
   - ⚠️ **The scan must not fire on this plan file.** Every literal in
     the test — the positive control's fixture especially — has to be
     assembled from parts rather than written joined, or the fixture
     becomes a hit. Root `tests/` is outside the scan, so a joined
     literal there is harmless; anywhere else it is not.
   - The pattern is **assembled once into a variable**, and the scan and
     its positive control run that identical variable — the rule
     `tests/portability.bats:30–35` already states for the vocabulary
     alternation. A control that tests a different expression proves
     nothing about the scan.
   - Exit status is the assertion: `-eq 1` (no match), never `-ne 0`, so
     a rename or an unreadable path exits 2 and reddens rather than
     silently switching the scan off. This is the same reasoning as
     `tests/portability.bats:116–122`.
   - Word boundaries, if any are needed, come from `-w`, not `\b` — CI
     runs macos-latest with BSD grep.

6. **Add its positive control** as a second new test: a fixture line
   carrying a real username shape, scanned with the same assembled
   variable, asserted to MATCH. A positive control proves only that the
   scan CAN go red; state that in a comment so nobody later reads it as
   proof the scan goes red only when it should.

7. **Correct the stale comment** at `tests/portability.bats:102–114`.
   `docs/specs` no longer exists — the specs moved to root `specs/`,
   which IS tracked. `docs/handoffs` does still exist, untracked. Keep
   the design rationale, which is still valid; fix only the factual
   claims, and name the new tree-wide scan as the thing that now covers
   `specs/` for paths while the vocabulary scans still do not.

8. **Record the worktree decision.** M1 removed both worktree
   registrations under `.claude/worktrees/` before this run started, and
   deliberately left this file untouched so the tree stayed clean. Add
   this block under Campaign 1 ruling 8, verbatim:

   ```
   **AMENDED 2026-08-26:** both worktree registrations under
   `.claude/worktrees/` were removed. The BRANCHES are kept and remain
   unpushed — they are the only carriers of the 221-commit pre-rewrite
   history, which has no merge base with `main` and includes the private
   `docs/handoffs` commits. Verification checks 5-6 are closed by the
   removal; the SDD workspace is gone, the lineage is not.
   ```

**Acceptance criteria:**

- **All four shapes scan clean, each with its positive control fired and
  shown FIRST.** Run exactly this, from the repo root, and paste the
  output into the phase record:

  ```
  d=$(printf 'D:%s' '\'); c=$(printf 'C:%sUsers%s' '\' '\')
  printf 'built d=[%s] c=[%s]\n' "$d" "$c"

  # positive controls — every one MUST print 1
  printf '%s%s\n' '/c/Users/' 'alice' | grep -cE '[/]c/Users/[A-Za-z0-9_]'
  printf 'x %sGithub y\n' "$d" | grep -cF "$d"
  printf 'x %sbob y\n'    "$c" | grep -cF "$c"
  printf '%s%s\n' '~/.claude/projects/' 'x' | grep -cE '~/\.claude/projects/[A-Za-z0-9-]'

  # negative control — MUST print 0, or the narrowing is broken
  printf '%s%s\n' '/c/Users/' '...'   | grep -cE '[/]c/Users/[A-Za-z0-9_]'

  # the real scans — every one MUST print 0
  git grep -nE '[/]c/Users/[A-Za-z0-9_]' -- . ':(exclude)tests/' | wc -l
  git grep -nF "$d" -- . ':(exclude)tests/' | wc -l
  git grep -nF "$c" -- . ':(exclude)tests/' | wc -l
  git grep -nE '~/\.claude/projects/[A-Za-z0-9-]' -- . ':(exclude)tests/' | wc -l
  ```

  The two Windows shapes are built from parts and matched with `grep -F`
  for two reasons, both measured 2026-08-26: an escaped ERE alternation
  loses a backslash level crossing the harness argv boundary and reports
  a silent false zero, and a joined literal in this file would make the
  plan a hit on the scan it defines.

- Measured before the scrub, for comparison: the four shapes returned
  35, 1, 0 and 1 tracked hits respectively (the single
  `~/.claude/projects/` hit being `main-plan.md:27`, requirement 4).
- The two new tests pass; the positive control is seen RED against the
  un-scrubbed tree before the scrub lands, and green after.
- Full house suite from the repo root: **`1..123`**, 0 not ok, 0 non-TAP
  (+2 from the measured 121).
- Every scrubbed line's surrounding text is unchanged: `git diff` shows
  only the token substitution on each of the 35 lines.

**Constraints:** Campaign 2 Global Constraints apply — including the full house suite, restated here because seeds travel alone: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`, run from the repo root. `tests/` is a
RELAXED surface for vocabulary but this change adds no vocabulary. Do
NOT widen `SHIPPED_ROOT`, `SHIPPED_HANDOFF` or `SHIPPED_PIPELINE`
(ruling 11). **Editing this plan file mid-run is safe:** phase A copies
the seed into `seed.md` before anything else runs, so the run does not
re-read `main-plan.md` after A. **Changelog routing: none** (ruling 13).

**Invocation:**

```
/pipeline:pipeline Phase 7: the machine path leaves the repository --auto --implementer claude
```

---

## Phase 8: progress.sh coverage and a timeout for every suite

`progress.sh read` is entirely untested, and two shipped surfaces sit on
its contract. Nine of its die-paths are unreached. Five of the six
suites have no per-test timeout, so a hung hook runs toward GitHub's
360-minute job cap — the exact hazard `tests/layout.bats:7` documents
and guards against for itself alone.

**Requirements:**

1. **Move the timeout to the shared helper.** `tests/helper.bash` is
   loaded by all six suites (`load helper` in the two root suites,
   `load ../../tests/helper` in the four plugin suites). Set
   `BATS_TEST_TIMEOUT` there. Keep `tests/layout.bats:7`'s own
   assignment or remove it, whichever leaves one obvious owner; state
   which in the commit message. The value must exceed the slowest
   existing test — measure, do not guess.

2. **Two tests for `progress.sh read`**, appended to
   `pipeline/tests/progress.bats`: one proving stdout is pure JSON that
   `jq` accepts, one proving the CRLF contract that
   `pipeline/skills/pipeline/SKILL.md:19–23` and
   `pipeline/skills/status/SKILL.md:13–15` both depend on.

3. **Nine die-path tests** for `progress.sh`, appended to the same file,
   one per path, each asserting the message names the thing that was
   wrong: `phase-done` with an unknown phase; `from-validate`'s E/`plan`
   branch; `from-validate`'s F/F.5/G/H/`tasks` branch; `from-validate`'s
   final refusal; `lock-take` with no session id; the lost-lock race;
   bare `usage`; `completed_phases must be an array`; an unknown
   `current_phase`. Only the D branch of `from-validate` is covered
   today (`pipeline/tests/progress.bats:87–98`).

4. **Fix the `.leakwords` test** at `tests/portability.bats:500–523`. It
   rebuilds the `grep -v | paste` alternation instead of exercising the
   suite's own folding at `:25–26`, so a mutation in the real folding
   code is not covered by the test that claims to prove it. Exercise the
   real code path. Test count unchanged.

**Acceptance criteria:**

- Full house suite from the repo root: **`1..134`**, 0 not ok, 0 non-TAP
  (+11 from P7's 123: 2 read + 9 die-paths).
- Each of the eleven new tests is seen RED before its fix lands, by
  inverting the assertion or breaking the operative clause — not by
  deleting the test. Echo the mutated line before trusting the red.
- The reworked `.leakwords` test is mutation-verified: break the folding
  at `:25–26` and it goes red.
- `BATS_TEST_TIMEOUT` is in effect in all six suites; prove it by
  showing one suite's run honouring it.

**Constraints:** Campaign 2 Global Constraints apply — including the full house suite, restated here because seeds travel alone: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`, run from the repo root. `pipeline/tests/`
and `tests/` are RELAXED surfaces. Do not restructure existing tests;
append. **Changelog routing: none** (ruling 13).

**Invocation:**

```
/pipeline:pipeline Phase 8: progress.sh coverage and a timeout for every suite --auto --implementer claude
```

---

## Phase 9: preflight.sh coverage and a probe helper

Ten die, warn and skip branches of `preflight.sh` are unreached, and
three constitution-parser edges are documented but unpinned. The suite
also spawns 24 near-identical probes that a helper would collapse.

**Requirements:**

1. **Ten new tests** appended to `pipeline/tests/preflight.bats`, one
   per branch: unknown argument; `--dir` with no value; `cannot enter`;
   the jq-missing `die`; the empty-version warn; the empty-flavour warn;
   `invocationForm: none` together with the `.agents/skills`
   foreign-agent warning; the `current branch` base fallback (only
   `configured` and `origin/HEAD` are pinned today, at
   `pipeline/tests/preflight.bats:115–126`); the N.5 skip on absent
   `adb`; the M skip on absent `gh` or a non-GitHub remote. Only the
   no-remote L+M case is covered today
   (`pipeline/tests/preflight.bats:141–148`).

2. **Three constitution-parser tests**: the NUL-byte / UTF-16 branch
   (`pipeline/scripts/preflight.sh:109–110`), the BOM strip (`:113`),
   and an unclosed `<!--` (`:112–141`).

   ⚠️ **The multi-line `<!--` case is ALREADY PINNED — do not add a test
   for it.** `pipeline/tests/fixtures/constitution-set/.specify/memory/constitution.md`
   opens with a six-line comment carrying `[PRINCIPLE_1_NAME]`, and
   `pipeline/tests/preflight.bats:170–174` goes red without multi-line
   stripping. The review claimed otherwise and was wrong.

3. **Extract a `probe` helper** into `tests/helper.bash` for the 24
   `run --separate-stderr bash "$PF" --dir …` call sites in
   `pipeline/tests/preflight.bats` (the `web` fixture alone is probed
   five times, at `:21, :41, :55, :93, :135`). Fewer spawns, same
   assertions. Converting the existing 24 call sites changes no test
   count.

**Acceptance criteria:**

- Full house suite from the repo root: **`1..147`**, 0 not ok, 0 non-TAP
  (+13 from P8's 134: 10 branches + 3 parser edges).
- Every new test seen RED first, by inverting its operative assertion.
- The 24 converted call sites assert exactly what they asserted before;
  show the diff is mechanical.
- New fixtures, if any, live under `pipeline/tests/fixtures/` and add no
  dependency tree — that directory is re-included wholesale by the
  tracked `.gitignore`.

**Constraints:** Campaign 2 Global Constraints apply — including the full house suite, restated here because seeds travel alone: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`, run from the repo root. `pipeline/tests/`
and `pipeline/scripts/` are RELAXED surfaces. `preflight.sh`'s external
contract does not change in this phase: same flags, same keys, stdout
still pure JSON. **Changelog routing: none** (ruling 13).

**Invocation:**

```
/pipeline:pipeline Phase 9: preflight.sh coverage and a probe helper --auto --implementer claude
```

---

## Phase 10: context-guard.sh coverage and a config fixture helper

Seven paths through the hook have never executed under test, including
two that only fire on a real user's machine, and the suite repeats one
config fixture 27 times.

**Requirements:**

1. **Seven new tests** appended to `handoff/tests/context-guard.bats`:
   - the `cwd="$PWD"` fallback and the subdirectory →
     `git rev-parse --show-toplevel` config discovery
     (`handoff/hooks/context-guard.sh:105–111`). Neither has ever run:
     `tests/helper.bash:98–99`'s `hook_input` always injects `cwd`, and
     the only payloads without it exit at `:96` first. A test must build
     a payload that reaches `:105` without `cwd`, and one that runs from
     a subdirectory of a repo.
   - the `-mtime +7` flag sweep (`:344`) — age a flag file and prove the
     sweep removes it.
   - the empty-readings path (`:260–262`) — an existing transcript
     containing zero readings.
   - a missing `session_id`.
   - the `DELIVERY_KIT_THRESHOLD_PCT` override and the
     `DELIVERY_KIT_THRESHOLD_TOKENS` override, behaviourally. Only
     `DELIVERY_KIT_WINDOW_TOKENS` and `DELIVERY_KIT_MAX_BYTES` are
     behaviourally tested today; the four-variable loop at
     `handoff/tests/context-guard.bats:877–878` exercises the setup
     skill's extracted snippet, not the hook.

2. **Extract `write_config` and `bytes_of` helpers** into
   `tests/helper.bash` for the 27 `printf '{"contextGuard":…}' >
   .delivery-kit.json` repetitions in `handoff/tests/context-guard.bats`.
   Note `:791` writes `patch.json`, not `.delivery-kit.json` — the
   helper must take the target path, or leave that one site alone.

**Acceptance criteria:**

- Full house suite from the repo root: **`1..154`**, 0 not ok, 0 non-TAP
  (+7 from P9's 147).
- Every new test seen RED first. For the two config-discovery tests,
  prove the payload actually reaches `:105` — a test that exits at `:96`
  passes for the wrong reason and proves nothing.
- The hook's behaviour is unchanged: this phase adds tests only, and the
  26 converted fixture sites assert exactly what they asserted before.

**Constraints:** Campaign 2 Global Constraints apply — including the full house suite, restated here because seeds travel alone: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`, run from the repo root. `handoff/tests/`
IS a registered STRICT-vocabulary surface (`SHIPPED_HANDOFF` includes
it) — a banned term pasted into a fixture reaches every install. Do not
change `handoff/hooks/context-guard.sh` in this phase; P14 owns it.
**Changelog routing: none** (ruling 13).

**Invocation:**

```
/pipeline:pipeline Phase 10: context-guard.sh coverage and a config fixture helper --auto --implementer claude
```

---

## Phase 11: pin the orchestrator's safety prose

Five pieces of the orchestrator's text are load-bearing for safety and
none is pinned. A reflow could delete any of them with the suite green.

**Requirements:**

1. **Five new tests** appended to `pipeline/tests/prose.bats`, pinning:
   - the `#123` never-fall-through rule
     (`pipeline/skills/pipeline/SKILL.md:266–268`);
   - "ROLL NOTHING BACK" (`:659–661`);
   - phase J's cap-breach carry duty (`:476–491`);
   - phase N's "DEGRADED, NEVER SKIPPED" (`:519–522`);
   - the seven unpinned red-flag rows. The table at `:642–651` has eight
     rows and only row 1 is pinned today
     (`pipeline/tests/prose.bats:44–47`). The review said six unpinned;
     it is seven.

2. **Pin operative clauses, not whole sentences.** `pipeline/tests/prose.bats`
   already pins about 31 whole sentences and acknowledges in-file
   (`:5–8`, `:110–117`) that this is deliberate. It is also brittle: an
   innocent reflow reddens a wall of tests with no signal separating
   "dangerous reword" from "reflow". For these five, anchor through the
   operative clause and slice the region, as the file already does for
   the flattened-G slices. Do not convert the existing pins.

**Acceptance criteria:**

- Full house suite from the repo root: **`1..159`**, 0 not ok, 0 non-TAP
  (+5 from P10's 154).
- Each new pin is mutation-verified by INVERTING the clause, not by
  deleting it: rewrite the pinned text to assert the opposite and prove
  the test goes red. Echo the mutated line before trusting the red — a
  no-op edit makes a false green.
- Every previously pinned string is still present byte-for-byte.

**Constraints:** Campaign 2 Global Constraints apply — including the full house suite, restated here because seeds travel alone: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`, run from the repo root. `pipeline/skills/`
and `pipeline/tests/` are RELAXED surfaces. **`SKILL.md` is not edited
in this phase** — this is pinning existing text, not writing new text.
**Changelog routing: none** (ruling 13).

**Invocation:**

```
/pipeline:pipeline Phase 11: pin the orchestrator's safety prose --auto --implementer claude
```

---

## Phase 12: shellcheck, and one version gate instead of two

Ten tracked shell files and six bats suites have no static analysis. The
version agreement is policed twice, by a bats test and a CI job that the
workflow itself calls "a hand-maintained twin … kept in step BY HAND and
have drifted once already" (`.github/workflows/ci.yml:68–71`).

**Requirements:**

1. **Add a shellcheck job** to `.github/workflows/ci.yml`, ubuntu-only.
   Scope it explicitly and say so in a comment: the four first-party
   files are `handoff/hooks/context-guard.sh` (457 lines),
   `pipeline/scripts/preflight.sh` (215), `pipeline/scripts/progress.sh`
   (186) and `tests/helper.bash` (107). The six files under
   `.specify/scripts/bash/` are vendored spec-kit scaffold (1,791 lines)
   and carry the repository's only existing shellcheck directive
   (`.specify/scripts/bash/create-new-feature.sh:107`,
   `# shellcheck disable=SC2071`) — decide in or out and write the
   reason into the workflow. Keep any disable list short and explicit.

2. **Fix what it finds**, or suppress with a reason on the line. A
   suppression with no reason is not a fix.

3. **Extract the version check into one script** both gates call — the
   T4/P6 fix. The bats gate is `tests/portability.bats:307` (parity
   assertion at `:387`); the CI job is `.github/workflows/ci.yml:60–61`
   (parity at `:88`). Both loop over every top-level directory holding a
   `.claude-plugin/plugin.json` and pick the marketplace entry by name.
   One script, two callers, one behaviour. If extraction proves wrong,
   the documented fallback is to drop the CI copy — the bats gate
   already runs on all three OSes and polices everything the job
   re-checks — but extraction is preferred because it keeps the CI
   signal.

4. **Cache bats and pin it by commit.** `.github/workflows/ci.yml:44–45`
   clones bats-core on all three `test` matrix OSes. Add
   `actions/cache` keyed on the pin. Separately: `--branch v1.11.0` is a
   MUTABLE ref — an upstream retag silently changes the third-party code
   CI executes. Pin the commit SHA alongside the tag, keeping the tag in
   a comment so the pin's meaning stays readable.

**Acceptance criteria:**

- The shellcheck job passes on a clean tree, and is proven able to fail:
  introduce one real SC2086 locally, watch it go red, revert.
- One version-check script exists; both gates call it; deleting a
  version from any manifest reddens BOTH.
- Full house suite from the repo root: **`1..160`**, 0 not ok, 0 non-TAP
  (+1 from P11's 159 — a test asserting the two gates call the same
  script, so the twin cannot silently return).
- The CI matrix is green on ubuntu, macos and windows.

**Constraints:** Campaign 2 Global Constraints apply — including the full house suite, restated here because seeds travel alone: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`, run from the repo root. `.github` is a
registered STRICT-vocabulary surface (`SHIPPED_ROOT` includes it) —
`shellcheck` is not a banned word, but check the alternation before
writing any new tool name. Do not change any plugin's behaviour in this
phase. **Changelog routing: none** (ruling 13 — this is repo tooling,
and the root `CHANGELOG.md` is an index of plugin releases, not a place
for CI notes).

**Invocation:**

```
/pipeline:pipeline Phase 12: shellcheck, and one version gate instead of two --auto --implementer claude
```

---

## Phase 13: pre-flight names git

`preflight.sh` probes `jq`, `gh` and `adb` and reports
`capabilities: { jq, gh, adb }` — while itself running four `git`
commands (`:154`, `:159`, `:163`, `:170`) and while phases B, K and L
are git operations. On a machine without git, pre-flight reports a happy
`base: ""` and a clean tree, and the failure surfaces mid-run. That
contradicts the plugin's own contract that every missing capability is
named at pre-flight.

**Requirements:**

1. **Probe git.** Add `command -v git` beside the three existing probes
   (`pipeline/scripts/preflight.sh:25`, `:166`, `:167`) and add `git` to
   the `capabilities` object emitted at `:212`. The key is additive; no
   existing key changes name, type or meaning, and stdout stays pure
   JSON.

2. **Decide and implement the consequence.** git absent is not a
   degradation — the run cannot branch, commit or push without it, so a
   `Missing: git` line alone would be a named capability nobody acts on.
   Make it a hard stop at pre-flight, under the orchestrator's existing
   "A missing tool is its own question" rule
   (`pipeline/skills/pipeline/SKILL.md:46–54`): name the tool, show the
   install command, record the answer, install nothing.

3. **Two new tests** appended to `pipeline/tests/preflight.bats`: git
   present → `capabilities.git` is `true`; git absent → the capability
   is `false` and git is named in `Missing`.

4. **Update the orchestrator's pre-flight decision walk** in
   `pipeline/skills/pipeline/SKILL.md` so the probe block and the
   ordered decision list both account for git. Add near, never reword:
   the existing decision items keep their numbering and their text.

5. **Update `pipeline/docs/configuration.md`** if it enumerates
   capabilities. (STRICT surface.)

**Acceptance criteria:**

- Full house suite from the repo root: **`1..162`**, 0 not ok, 0 non-TAP
  (+2 from P12's 160).
- `preflight.sh` stdout still parses as pure JSON in every existing
  test; no existing key changed.
- Both new tests seen RED before the probe lands.
- All pinned strings intact.

**Constraints:** Campaign 2 Global Constraints apply — including the full house suite, restated here because seeds travel alone: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`, run from the repo root.
`pipeline/scripts/` and `pipeline/tests/` are RELAXED;
`pipeline/docs/` is STRICT. **Changelog routing: `pipeline/CHANGELOG.md`
under the existing `## [Unreleased]`, an `### Added` entry** naming the
git probe and the stop. Count-free.

**Invocation:**

```
/pipeline:pipeline Phase 13: pre-flight names git --auto --implementer claude
```

---

## Phase 14: the guard stops counting jq

`context-guard.sh` runs on PostToolUse after EVERY tool call. Before it
reads the transcript it spawns five jq processes (`:55` `jq --version`,
then `:89`, `:93`, `:94`, `:104`), and `read_config` (`:134–137`) spawns
four more per config file it finds, at `:163` and `:164`. Measured
2026-08-26: **5, 9 or 13 jq processes for 0, 1 or 2 config files
present**; on this machine both exist, so 13 is the live number. The
full non-firing path reaches about 14 processes per tool call. Process
spawn dominates on Windows under Git Bash, which is a supported
platform.

**Requirements:**

1. **One jq call for the payload.** Replace the four separate
   extractions with a single
   `jq -r '[.agent_id, .transcript_path, .session_id, .cwd] | @tsv'` and
   split in shell. Three fewer spawns.

2. **One jq call per config file.** Replace `read_config`'s four
   per-file extractions with a single
   `jq -r '.contextGuard // {} | [.windowTokens, .thresholdPct, .thresholdTokens, .maxBytes] | @tsv'`
   consumed by shell. Three fewer spawns per file, six across both.

3. **Validation semantics stay in shell, unchanged.** `is_positive_int`
   and every other check keep their current behaviour — including the
   octal-rejection rationale the comment block at
   `handoff/hooks/context-guard.sh:23–29` records. A value that is
   rejected today is rejected after.

4. **Carry the comments, do not compress them.** The measurement history
   in this file — the 2026-08-07 incident, the 15-versus-5 median
   window, the byte-cap fallback — is why the arithmetic is trustworthy.
   The refactor moves code, not the record.

5. **The early-return on a missing config file stays.** `read_config`
   returns at `:133` before spawning anything when the file is absent;
   that is why the count is 5/9/13 rather than always 13.

**Acceptance criteria:**

- Full house suite from the repo root: **`1..162`**, 0 not ok, 0 non-TAP
  — UNCHANGED from P13. This phase adds no tests and must break none.
  Run the suite green BEFORE the refactor and after, and show both.
- The jq spawn count is measured, not asserted: count invocations on the
  three paths (0, 1 and 2 config files present) before and after, and
  record both numbers in the commit message. Target 5/9/13 → 2/3/4.
- Behaviour is identical: same threshold arithmetic, same messages, same
  exit codes, same octal rejection.
- `handoff/tests/context-guard.bats` is not edited in this phase. If a
  test needs changing to pass, the refactor changed behaviour — stop.

**Constraints:** Campaign 2 Global Constraints apply — including the full house suite, restated here because seeds travel alone: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`, run from the repo root. `handoff/hooks/`
is a registered STRICT-vocabulary surface. Any "simplification" that
turns a named failure into silence is a regression even with tests green
— the jq hint, the WINDOW MISCONFIGURED note and its lower bound all
stay loud. **Changelog routing: `handoff/CHANGELOG.md` under the
existing `## [Unreleased]`, a `### Changed` entry** naming the spawn
reduction and stating that behaviour is unchanged.

**Invocation:**

```
/pipeline:pipeline Phase 14: the guard stops counting jq --auto --implementer claude
```

---

## Phase 15: the documentation truth-pass

Two shipped skills are named in no README. The phase alphabet the flags
speak is defined only inside a 683-line skill. Three README sentences
describe a setup contract that changed at 2.1.0. Four smaller drifts and
one byte-identical 31-line twin.

**Requirements:**

1. **D1 — make `spec-review` and `device-verify` discoverable.**
   `pipeline/skills/spec-review/` and `pipeline/skills/device-verify/`
   ship with user-facing descriptions and are named in no README, and
   are absent from the root Command reference (`README.md:325`, table at
   `:327–331`). Add a "What ships" table to `pipeline/README.md` —
   `handoff/README.md` already has one to model — and two rows to the
   root Command reference.

2. **D2 — write the phase reference.** Create
   `pipeline/docs/phases.md`: one line per phase, letter to name to
   one-sentence purpose. This closes `--until C.5`, `--from H.7` and
   pre-flight's `Will skip: N.5`, which today speak an alphabet defined
   only in `pipeline/skills/pipeline/SKILL.md`. **Scope it accurately:**
   the READMEs already define five letters (`README.md:272–278`,
   `pipeline/README.md:47–53` give C, G, K, L, O) and
   `pipeline/README.md:33–38` already maps four ranges. The real gap is
   the fractional phases — C.5, F.5, H.5, H.7, N.5 — and the unstarred
   letters. Do not write a preamble claiming no reference existed. A new
   file under `pipeline/docs/` is covered by `SHIPPED_PIPELINE`
   automatically, because that list registers the directory.

3. **D3 — correct the setup contract in three places.** Since 2.1.0,
   `handoff:setup` DOES write the repository's `.delivery-kit.json`
   pipeline block when the user accepts the offer in a repo with
   `.specify/` (`handoff/skills/setup/SKILL.md:217–241`). Reword to the
   actual contract — machine keys to `~/.delivery-kit.json`; pipeline
   keys offered as a write to the repository file, only where
   `.specify/` exists, and only when asked:
   - `README.md:399` ("it will not edit a shared repository file for
     you" — true only for guard keys, and only unasked);
   - `README.md:329` and `handoff/README.md:63` (both say "once per
     machine").

4. **D4 — add the `Implementer` line to the sample.** `README.md:255–263`
   renders a pre-flight probe block without it, while `README.md:296`
   and `:403` both send the reader to go find it.

5. **D5 — name the environment variables.** `README.md:360` says "an
   environment variable beats both" and the root README names none. The
   five are `DELIVERY_KIT_WINDOW_TOKENS`, `_THRESHOLD_PCT`,
   `_THRESHOLD_TOKENS`, `_MAX_BYTES`, `_HANDOFF_DIR`
   (`handoff/docs/configuration.md:34–40`). One row or one pointer.
   Say in the same breath that pipeline keys have NO environment
   overrides — `pipeline/skills/pipeline/SKILL.md:66` states it and the
   root README does not.

6. **D7a — canonicalize the 31-line twin.** The "Upgrading from
   `delivery-kit@delivery-kit`" section is byte-identical (`cmp` clean)
   in `handoff/README.md:77–107` and `handoff/docs/install.md:37–67`.
   Keep the canonical copy in `handoff/docs/install.md` and link from
   `handoff/README.md`. **Each plugin README must still stand alone for
   the marketplace page** — so leave a one-sentence summary at the
   README site, not a bare link.

7. **D7c — reconcile the spec-kit tested range.** "0.15.x through
   0.16.x" appears in FIVE places, not the four the review listed:
   `README.md:118–119`, `pipeline/README.md:92`,
   `pipeline/docs/configuration.md:136`,
   `pipeline/scripts/preflight.sh:65` (spelled `(0.15.x-0.16.x)`, and
   the authoritative match pattern is separately at `:63`), and
   `pipeline/skills/pipeline/SKILL.md:165` — the copy the orchestrator
   actually reads, which the review missed. Make all five agree, and
   note in a comment at `:63` that the pattern and the prose must move
   together.

8. **H3 — add a fresh-clone block to `CONTRIBUTING.md`** under a new
   `## After cloning` heading, containing exactly this:

   ```
   git clone <url> delivery-kit && cd delivery-kit
   printf '%s\n' '.claude/' 'docs/' '.delivery-kit/' >> .git/info/exclude
   git check-ignore -v docs/ .claude/ .delivery-kit/
   ```

   Say beneath it that the third command must name `.git/info/exclude`
   for all three paths, and why: a fresh clone carries `.gitignore` but
   NOT `.git/info/exclude`, so until those lines exist `docs/` is
   ignored by nothing in a public repository. That is a measured
   near-miss recorded in the exclude file itself on 2026-08-25.
   `docs/` and `.claude/` are generic directory names, not private tool
   names, so publishing them in CONTRIBUTING does not defeat the reason
   the patterns live in `.git/info/exclude` rather than `.gitignore`.

9. **Do NOT add `docs/` to "What is in this repository"**
   (`README.md:416–421`). The review's D6 asked for it. `docs/` is
   untracked and deliberately excluded as the private handoff archive; a
   repository-contents list that omits it is correct.

**Acceptance criteria:**

- Full house suite from the repo root: **`1..167`**, 0 not ok, 0 non-TAP
  — UNCHANGED from P14, unless the implementer adds prose pins for the
  new documents, in which case state the new number and why.
- Every relative link in every edited file resolves, path and anchor.
  Fire a positive control on the link checker first: a deliberately
  broken path and a broken anchor must both be reported.
- The five spec-kit range sites agree character-for-character.
- `cmp` on the old twin line ranges no longer reports two identical
  copies.
- All pinned strings intact; `pipeline/tests/prose.bats` green.

**Constraints:** Campaign 2 Global Constraints apply — including the full house suite, restated here because seeds travel alone: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`, run from the repo root. `README.md`,
`CONTRIBUTING.md`, `pipeline/README.md`, `pipeline/docs/`,
`handoff/README.md` and `handoff/docs/` are ALL STRICT surfaces — write
"spec-kit", `.specify/`, `specify init`, and hyphenated skill spellings
only. Count-free prose: do not write how many skills, phases or suites
ship. **Changelog routing: BOTH plugins, `### Changed` under each
existing `## [Unreleased]`** — `pipeline/CHANGELOG.md` for D1, D2 and
D7c; `handoff/CHANGELOG.md` for D3 and D7a.

**Invocation:**

```
/pipeline:pipeline Phase 15: the documentation truth-pass --auto --implementer claude
```

---

## Phase 16: release pipeline 1.2.0 and handoff 2.1.1

**RUN PHASE 17 FIRST.** It changes `handoff/hooks/context-guard.sh` and
therefore belongs inside the handoff 2.1.1 this phase stamps. Released
after, it needs a release of its own. Phase 15 may run in either order.

Both plugins have carried an open `## [Unreleased]` heading since the
2026-08-25 documentation PRs. This phase folds both, in one run.

**Requirements:**

1. **Stamp pipeline 1.2.0.** `pipeline/.claude-plugin/plugin.json` →
   `1.2.0`; the pipeline entry in `.claude-plugin/marketplace.json` →
   `1.2.0`; `pipeline/CHANGELOG.md`'s `## [Unreleased]` heading becomes
   `## [1.2.0] - <today>`. Minor, not patch: P13 adds a key to
   `preflight.sh`'s JSON output and a new pre-flight stop.

2. **Stamp handoff 2.1.1.** `handoff/.claude-plugin/plugin.json` →
   `2.1.1`; the handoff entry in `.claude-plugin/marketplace.json` →
   `2.1.1`; `handoff/CHANGELOG.md`'s `## [Unreleased]` heading becomes
   `## [2.1.1] - <today>`. Patch, not minor — and the reason is **not**
   that nothing moved. P14 was measured behaviour-preserving; P17 is
   not. P17 changes what the guard answers on three measured transcript
   shapes, each one a correction to a pre-existing fault in the old
   code, and the differential ASSERTS each difference rather than
   hiding it. Corrections are fixes. P15 is documentation. Nothing was
   Added under either heading, so the bump is patch. Do not restate
   this as "identical behaviour": that wording predates P17 and is
   false.

3. **Content beneath both headings is already complete.** Add nothing,
   remove nothing, reorder nothing.

4. **Both `## [Unreleased]` headings must be GONE** when this phase
   ends. Nothing in the suite checks for a dangling one — that is
   precisely why it dangled for a release cycle.

**Acceptance criteria:**

- `jq -r '.plugins[] | "\(.name) \(.version)"' .claude-plugin/marketplace.json`
  prints `handoff 2.1.1` and `pipeline 1.2.0`; both `plugin.json` files
  agree; both changelog headings agree.
- `grep -c '^## \[Unreleased\]' pipeline/CHANGELOG.md handoff/CHANGELOG.md`
  returns `0` for both.
- Both changelog headings parse as `## [X.Y.Z] - YYYY-MM-DD`.
- Full house suite from the repo root: **`1..163`**, 0 not ok, 0 non-TAP
  (or P15's stated number, if it moved).
- The CI matrix is green on all three OSes.

**Constraints:** Campaign 2 Global Constraints apply — including the full house suite, restated here because seeds travel alone: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`, run from the repo root. This phase changes
six version strings and two headings. Nothing else.

**Invocation:**

```
/pipeline:pipeline Phase 16: release pipeline 1.2.0 and handoff 2.1.1 --auto --implementer claude
```

**After the merge (owner + assistant):**

```
git checkout main && git pull
git tag pipeline-v1.2.0 && git push origin pipeline-v1.2.0
git tag handoff-v2.1.1 && git push origin handoff-v2.1.1
```

Watch both tag CI runs. Campaign 2 is complete when both are green.

## Not in this plan (recorded, deliberately excluded)

- **D6 — listing `docs/` in the root README.** Not a defect. `docs/` is
  untracked and deliberately excluded as a private handoff archive in a
  public repository; a repository-contents section that omits it is
  correct. Acting on this finding would be a regression.
- **C3 — a GitHub Release step on tag push.** Real absence, but
  `specs/006-release-1-1-0/tasks.md:366` records that absence as a
  security property to preserve: the workflow has zero references to
  secrets, `GITHUB_TOKEN`, publish, registry, `gh release`, artifact
  upload, `id-token` or `packages`. Adding a publish step is an owner
  decision about that invariant, not a defect fix.
- **P3 — age-based lock staleness.** Recorded by the reviewer as a
  considered non-change. `taken_at` is already written
  (`pipeline/scripts/progress.sh:160`) and used only for display, and
  the conservative choice avoids the worse failure of taking a lock from
  a live run. Revisit only if it bites; the fix is one condition.
- **P4 — a `UserPromptSubmit` matcher for the context guard.** Cheap and
  probably right, but it changes WHEN the guard fires, which is a
  consent decision the owner makes. Needs a ruling first. Best done
  after P14, so the added invocations land on the reduced spawn count.
- **P5 — a `SessionStart` nudge naming the newest handoff document.**
  A new feature, not remediation. A handoff 2.2.0 candidate alongside
  teaching `handoff:setup` the `implementer` key.
- **D8 — `pipeline/CHANGELOG.md:84–86` versus the current README
  spelling.** Historically true when written. Changelogs are immutable
  history and are not edited to match a later state.
- **T6 beyond P11's five new pins.** Converting the existing ~31
  whole-sentence pins to anchored clauses is a large mechanical change
  to the file that protects everything else. Do it only with a separate
  ruling.
- **The crash-resume lock carve-out** — carried forward from Campaign 1.
  Still needs an owner design ruling.
- iOS runtime verification, monorepos, other harnesses — still Not in v1.

---

## Phase 17: the guard stops counting jq, part two

**RUN THIS BEFORE PHASE 16.** It changes `handoff/hooks/context-guard.sh`,
so it belongs in the handoff 2.1.1 that Phase 16 releases. Released after,
it needs a release of its own.

Phase 14 closed the extraction half and left two findings on the table,
both raised by review and both deferred by the owner on 2026-09-01.
Phase 14's own record is in `specs/014-guard-jq-spawn-count/tasks.md`,
Phase 9.

Measured 2026-09-01 at `main` = `168edc1`, jq invocations per NON-FIRING
run, for 0 / 1 / 2 configuration files present:

| Transcript | jq spawns |
|---|---|
| 20 readings — an ordinary session | **4 / 5 / 6** |
| 6 readings — the under-fifteen fallback fires | **5 / 6 / 7** |

A firing run spends one more, on the emission. The calls are
`:55` the availability probe, `:108` the payload, `:200` the
configuration (once per file), `:289` the readings, `:324` the readings
re-read when the capped slice holds fewer than fifteen, and `:327` the
median. `:323` spends a `grep -c` besides, and `:47` and `:108` spend a
`cat` and a `printf`.

**Requirements:**

1. **F7 — stop the two-process detour on stdin.** `input=$(cat)` at
   `:47` is consumed once, at `:108`, by `printf '%s' "$input" | jq`.
   That is a `cat` and a `printf` for a value with one consumer. Let jq
   read stdin directly instead. **This saves no jq call — say so; it
   removes two other processes.** The hazard is named rather than
   discovered: the availability probe at `:55` runs BETWEEN the two, and
   on the jq-missing path the payload is never parsed, so today stdin is
   drained by `cat` and after this change it may not be. Prove what the
   caller does with an undrained stdin before landing it, and record the
   measurement. If it cannot be proven safe, **land F8 alone and say
   why** — a broken hook costs more than two processes.

2. **F8 — one jq for the transcript, not three plus a grep.** `:289`
   reads the capped slice, `:323` counts the readings with `grep -c`,
   `:324` re-reads uncapped when that count is under fifteen, and `:327`
   takes the median. One jq program can emit the count and the median
   together, which removes `:327` and the `grep` outright and leaves the
   re-read as the only conditional second call.

3. **THE FALLBACK ARITHMETIC MAY NOT CHANGE, AND THIS IS THE WHOLE
   RISK.** The floor of fifteen, the median-of-last-fifteen window and
   the uncapped re-read exist because of the 2026-08-07 and 2026-08-15
   incidents, both recorded in the comments at `:283–325`. A cap that
   can answer from a starved window buys latency with the exact failure
   this arithmetic prevents. Same inputs must give the same median, the
   same fallback decision, and the same answer.

4. **Carry the comments, do not compress them.** `handoff/hooks/` is a
   registered STRICT-vocabulary surface. The refactor moves code, not
   the record, and any "simplification" that turns a named failure into
   silence is a regression even with tests green.

**Acceptance criteria:**

- Full house suite from the repo root: **`1..163`**, 0 not ok, 0
  non-TAP — UNCHANGED. This phase adds no tests and must break none.
  Run it green before and after, and show both.
- `handoff/tests/context-guard.bats` is not edited. Prove it with
  `git diff --stat 168edc1 -- handoff/tests/context-guard.bats`, which
  must be empty. **Pin the baseline to that commit id, never to `main`:**
  this repository rebase-merges, so once the branch lands, a bare
  `git diff` compares an empty range and the check reports zero having
  scanned nothing.
- The spawn count is MEASURED on both transcript shapes and both
  columns recorded in the commit message. Target, to be confirmed rather
  than assumed: ordinary **4/5/6 → 3/4/5**, fallback **5/6/7 → 4/5/6**,
  plus the `grep` and both `printf`/`cat` processes gone.
- Behaviour is proven identical by DIFFERENTIAL, not asserted: run the
  pre-change hook against the new one over the payload and configuration
  shapes, comparing stdout and exit code. **The harness is committed at
  `scripts/context-guard/differential.sh`** — read
  `scripts/context-guard/README.md` first; it records the traps, chiefly
  that HOME, TMPDIR, TEMP and TMP must all be isolated per side per
  shape, or the old hook's once-per-bucket flag silences the new one and
  the harness reports false differences on a correct hook. Pass the
  baseline as a commit id, never a branch. Run its `NEWHOOK` positive
  control before believing a zero. Extend it with the transcript shapes
  this phase actually touches: empty, one reading, fourteen, fifteen,
  sixteen, a malformed line among good ones, and sidechain entries —
  fourteen and sixteen matter most, because they sit either side of the
  fallback's floor.
- The counting shim's directory must have **no drive letter**. A
  `C:/...` entry in `PATH` splits on its own colon under Git Bash, the
  shim is never found, and the count file prints `0` — indistinguishable
  from a real zero.

**Constraints:** Campaign 2 Global Constraints apply — including the full
house suite, restated here because seeds travel alone:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
run from the repo root. **Changelog routing: `handoff/CHANGELOG.md` under
the existing `## [Unreleased]`, a `### Changed` entry** naming the
reduction and stating what was measured rather than asserting behaviour
is unchanged — Phase 14 shipped that flat claim and review falsified it.

**Invocation:**

```
/pipeline Phase 17: the guard stops counting jq, part two --auto --implementer claude
```

---

## Phase 18: the guard's own configuration cannot silence it

Phase 17 closed the jq half and left T045 on the table: two ways a
configuration file can stop the context guard firing in time, silently.
Both are pre-existing, and both are behaviour changes, so neither belonged
in a phase whose entire proof was that behaviour did not change. The
deferral and its reason are recorded at
`specs/015-guard-jq-spawn-two/tasks.md:220-226`.

Both were re-verified against `main` = `63eab9a` while this seed was
written. **They are not symmetric.** G1 has a correct answer and a
one-character fix. G2 has no obviously correct answer, reverses a
documented position, and is an owner ruling — see requirement 2, which
deliberately does not pre-answer it.

**Requirements:**

1. **G1 — a threshold of exactly 100 must be rejected.**
   `handoff/hooks/context-guard.sh:43-45`:

   ```sh
   is_valid_threshold() {
     is_positive_int "$1" && [ "$1" -le 100 ]
   }
   ```

   The comment directly above it, at `:37-42`, states the rule the
   function does not enforce: a threshold reachable only once context has
   already exceeded the window is "far too late to be useful", so in
   practice the guard never fires again, silently, "which is the one thing
   configuration must not be able to do" — and nothing downstream can
   catch it, because the window-misconfiguration report runs only once the
   guard has already decided to fire. **100 has exactly that property and
   `-le` admits it.** The change is `-le` to `-lt`, and it covers all three
   layers at once — repository file, user-level file (`:237`) and
   environment (`:265`) — because every layer calls this one function.

   Three things move with it, and none of them is optional:

   - **The invariant comment at `:620-623` goes stale.** It reads "The
     threshold gate cannot block that, because `is_valid_threshold` caps
     `THRESHOLD_PCT` at 100." The cap becomes 99, and the invariant
     STRENGTHENS: `pct >= 100` now exceeds every admissible threshold
     rather than merely equalling the maximum. Say that. `handoff/hooks/`
     is a STRICT surface and the reasoning is the record — carry it, do
     not compress it.
   - **`handoff/tests/context-guard.bats:484-493` currently DEPENDS on 100
     being accepted, and after the fix it stays green while its comment
     becomes false.** "The absolute tripwire fires with the relative one
     unreachable" sets `thresholdPct` to 100 at `:487` on purpose, so that
     only the absolute tripwire can be responsible for the emission. Once
     100 is rejected, `THRESHOLD_PCT` reverts to the default 45, and
     405000 of a 1000000 window is 40% — still under 45, so the assertion
     still holds and the stated mechanism no longer exists. **That silent
     green is the class of failure this phase exists to prevent, not
     housekeeping to do afterwards.** Rewrite it to the highest still-valid
     threshold and prove the rewrite is load-bearing.
   - **The boundary itself is untested in both directions.**
     `:459` exercises 450 only. (That test was later renamed to "a threshold FAR
     above 100 is rejected...", so its old title no longer resolves in the
     suite — the boundary is now covered by two neighbouring tests.)
     Add 100 rejected and 99 accepted.

2. **G2 — decide what a too-large `windowTokens` should mean. THIS SEED
   DOES NOT ANSWER IT, AND THAT IS DELIBERATE.**

   Two sites read the window and neither bounds it:

   ```sh
   :236  is_positive_int "$cfg_window" && WINDOW=$cfg_window
   :264  is_positive_int "$DELIVERY_KIT_WINDOW_TOKENS" && WINDOW=$DELIVERY_KIT_WINDOW_TOKENS
   ```

   The comment at `:238-244` explains why `thresholdTokens` has no
   ceiling — it is a number about the user's model, and any positive value
   is one somebody could legitimately mean. That reasoning is sound for a
   threshold and is never applied to `windowTokens` itself. A large enough
   window puts every real reading under the threshold for ever, and the
   misconfiguration report cannot catch it for the same reason as G1.

   **Route this to the clarify gate.** What the gate needs in front of it,
   all verified while writing this seed:

   - **The hazard is already documented, with a measurement, and the
     current stance is education rather than a cap.**
     `handoff/docs/configuration.md:133-139` records it: against a
     100,000,000-token window with `thresholdTokens` at 400,000, the guard
     fires at 400,000 and then stays silent at 900,000 and at 4,000,000,
     because all three are under 5% of that window. **A cap therefore
     REVERSES a documented position.** That is a ruling, not a fix.
   - **Issue #1 forecloses two neighbouring answers and not this one.** It
     is closed, and it records as explicitly out of scope both raising the
     default and any model-ID-based detection, with the evidence: a live
     1M-context transcript records `.message.model` with no variant marker,
     so a lookup table would return 200000 for a 1M session confidently and
     with no signal that it had guessed. **Bounding a value the user typed
     is a different question and is not foreclosed.** Put that distinction
     in front of the gate so it does not re-decide the closed one.
   - **The two sites carry different risk.** `:264` is the user's own
     environment on their own machine. `:236` reads the repository's
     `.delivery-kit.json`, which is shared — a value one person commits
     disarms the guard for everyone who clones. Bounding the shared layer
     alone is a legitimate option, and it is not the same as bounding all
     three.
   - **Candidate shapes, none endorsed here:** a hard cap with a documented
     figure; a warning on an implausible value that is still applied; a
     report that fires independently of an emission, which is the only
     shape that also fixes the "nothing downstream can catch it" property
     G1 and G2 share; or a ruling that the documented education at
     `configuration.md:133-139` is already the right answer and G2 closes
     as a considered non-change.
   - **If the gate rules G2 a non-change, land G1 alone and record the
     ruling** under the phase's `specs/` directory. A phase that ships one
     of two findings and says why is a complete phase, not a partial one.

3. **The documentation moves with the code, and the suite will not catch
   it.** After G1 the rule is "100 or above", not "above 100". Two sites
   say the old thing: `handoff/docs/configuration.md:46-53`, whose
   paragraph restates the whole reasoning, and the hook comment at
   `:37-42`. Both are STRICT surfaces. **Nothing in
   `pipeline/tests/prose.bats` pins either wording — checked — so a green
   suite proves nothing here.** Grep every copy of the claim.

4. **Prove the behaviour change by differential, and assert WHICH shapes
   differ.** Phase 17 already used this mechanism — its shipped run recorded
   46 shapes, 0 unexpected, **3 of them asserted to differ**
   (`scripts/context-guard/README.md:102`) — but there the differing shapes
   were incidental to a refactor whose whole proof was "identical". **Here
   the differing shapes ARE the deliverable**, which inverts what a zero
   means. The harness
   already supports that: `scripts/context-guard/differential.sh` takes an
   expectation as its fifth argument, defaulting to `same`, and its summary
   prints AS EXPECTED and UNEXPECTED with the asserted-to-differ count
   (`:231`, `:275`, `:388`). Read `scripts/context-guard/README.md` first;
   it records the traps, chiefly that HOME, TMPDIR, TEMP and TMP must all
   be isolated per side per shape, or the old hook's once-per-bucket flag
   silences the new one and the harness reports false differences on a
   correct hook. Pass the baseline as a commit id, never a branch — this
   repository rebase-merges, so a bare branch name compares an empty range
   once the work lands. Run the `NEWHOOK` positive control before believing
   any zero. **Add `thresholdPct` 99, 100 and 101 as shapes, each asserted
   deliberately: 100 is the only one that must differ.**

**Acceptance criteria:**

- Full house suite from the repo root: **`1..167` before, `1..167+N`
  after**, 0 not ok, 0 non-TAP. State N and name every added test in the
  commit message. Do not write "unchanged" — this phase adds tests by
  design, and a count that did not move is a finding.
- The differential reports **0 unexpected**, with the shapes asserted to
  differ named in the commit message. **A run reporting no differences at
  all is a FAILED run here, not a clean one** — G1 changes behaviour, and a
  harness that cannot see the change is not evidence.
- `handoff/tests/context-guard.bats:484-493` no longer passes for a reason
  its own comment does not state. Prove the rewrite is load-bearing: put
  the old threshold value back on its own and show the test goes red.
- The boundary is pinned in both directions — 100 rejected, 99 accepted —
  and each new test is shown failing against the unchanged hook before it
  is shown passing against the changed one.
- `shellcheck --norc -f gcc` clean over the discovered files, as CI runs
  it. CI's shellcheck is OLDER than a typical local one and reports MORE;
  a local green does not predict CI.
- Every documentation site for the threshold rule agrees with the code,
  verified by grep over each copy of the claim rather than by the suite.
- G2's outcome is recorded either way: if it lands, the option chosen and
  the ones rejected; if it does not, the ruling and its reason.
- **Flag at the release gate that G1 changes what an existing
  configuration does** — a `thresholdPct` of exactly 100 was accepted
  before and now reverts to the default 45. Whether that makes the next
  `handoff` stamp a patch or a minor is the release phase's call, not this
  one's, but it must not be discovered there.

**Constraints:** Campaign 2 Global Constraints apply — including the full
house suite, restated here because seeds travel alone:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
run from the repo root. `handoff/hooks/` and `handoff/docs/` are STRICT
surfaces. **Changelog routing: `handoff/CHANGELOG.md` ONLY, under the
existing `## [Unreleased]`, a `### Fixed` entry for G1** naming the
boundary and what a threshold of 100 used to do; G2's heading follows its
ruling. This phase touches no file under `pipeline/`, so nothing routes to
`pipeline/CHANGELOG.md` — **both plugins currently have an open
`## [Unreleased]` heading, which makes filing under the wrong one easy and
silent.**

**Invocation:**

```
/pipeline Phase 18: the guard's own configuration cannot silence it --auto --implementer claude
```

---

# Campaign 3 — review in pieces (pipeline 1.3.0)

> **For agentic workers:** same contract as Campaigns 1 and 2 above. Each
> `## Phase <N>:` section below is a SEED for one `/pipeline` run. Seeds
> are written so the clarify gate has nothing left to ask.

**Goal:** a developer can review what a pipeline run built in small,
ordered pieces instead of one diff. Developers reported that after phase
H every task lands at once, K makes one commit, and the change is too
large to open and read by hand.

**The cause, read at `main` = `dacf58e`:** H implements every task in one
pass (`pipeline/skills/pipeline/SKILL.md:497-501`); H.5, H.7, I and J then
edit across all of it; K commits the whole tree as one commit
(`:546-551`). Nothing records which task produced which change, so no
reviewer can walk the work in order.

**Architecture:** five pipeline runs (P19–P23), strictly sequential, each
branching off `main`, each ending at a pull request the owner merges.
P19 gives `progress.sh` the two commands the orchestrator needs; P20
and P21 change the orchestrator, front half then back half; P22 is the
documentation truth-pass for both; P23 stamps and ships pipeline 1.3.0.
Only P20 and P21 write changelog entries: P20 opens `## [Unreleased]` in
`pipeline/CHANGELOG.md`, P21 adds to it, and P23 folds it. P19 and P22
route none. The handoff plugin does not change.

**Tech Stack:** unchanged from Campaign 2 — bash + jq + bats 1.11.0;
spec-kit 0.16.x (pinned); `gh` (PowerShell-only on this machine);
shellcheck as CI runs it.

**Spec:** this section. The design was agreed with the owner on
2026-09-29, in conversation, one decision at a time; every ruling below
records one of those answers. Nothing here depends on an untracked file.

## Campaign 3 decisions (rulings — each one edit to undo)

15. **The developer picks the review mode at G, on every run.** Two
    modes: **commits** (the run finishes as today, but the branch holds
    one commit per piece, read after the run) and **pauses** (the run
    stops after each piece, the developer reviews it, then answers).
    The question is never pre-answered: no configuration key and no flag
    in this campaign, and `--auto` never collapses it. **Consequence,
    stated on purpose:** G now stops on every run whose implementer is
    `claude`, so the documented floor — "a run CAN reach DONE without a
    single gate stopping it" — is no longer true and must be rewritten
    everywhere it is stated. A `reviewMode` key is recorded under "Not in
    this plan".
16. **One piece is one `## Phase <N>:` section of `tasks.md`.** Setup,
    Foundational, each user story, Polish. Not one task: that is 20–50
    pieces, and in pause mode 20–50 stops. Headings that are not
    `## Phase <N>:` (Format, Dependencies, Parallel opportunities,
    Implementation strategy, rule blocks) are not pieces. Every piece
    commits, because every piece at least marks its tasks `[X]` in
    `tasks.md`. A piece whose only change is those marks — a ruled
    non-change, for example — still gets its own commit, and the message
    says it changed no other file. One commit per piece, always, so the
    review guide has no gaps.
17. **The spec commits first, alone.** The spec artefacts are
    uncommitted from B through F. Before piece 1, H commits them as one
    commit (`docs(spec): <feature>`). It is the first thing a reviewer
    reads, and without it piece 1 would sweep them in.
18. **Late phases get their own commits; nothing is folded back.** H.5,
    H.7, I and J each end with one commit of their own, when they changed
    a file: converge, simplify, review fixes, test fixes. Piece commits
    stay exactly as built. No rebase, no fixup, no history rewrite — a
    rewrite would also be impossible for a piece already reviewed in
    pause mode.
19. **Piece commits are local and ungated.** In commits mode a piece
    commits without a stop; in pauses mode the pause IS the yes. Nothing
    leaves the machine before the L gate, exactly as today. K stops once
    and shows the whole commit list. Precedent: N already commits without
    a gate (`SKILL.md:564-569`).
20. **Every commit names every path.** The never-bend rule against
    `git add -A` and wildcards now binds each commit, not only K's.
21. **A commit hook that rejects a piece is a hard stop.** A project
    whose pre-commit hook runs its tests can reject a Setup or
    Foundational piece that is not green on its own. `--no-verify` stays
    forbidden. The piece stays uncommitted, the run parks per "When a
    phase fails", and the failure entry in the state file names the piece
    and the hook's output (redacted like every other carried failure).
    A parked piece has no sha, so `commit-add` never records it — which is
    exactly why `piece-next` returns it again, and `--resume` shows that
    piece first.
22. **The handoff implementer path is out of scope.** The package's
    forbidden list says no commit, so a cheaper model cannot make piece
    commits. When G's answer is `handoff`, G does not ask the review
    question, says in one line that review pieces are not available on
    that path, and the run keeps today's single-commit flow. Recorded
    under "Not in this plan".
23. **A J red the owner waved through, with no file J changed, is carried
    by an empty commit.** J's carry duty names "the commit message". J's
    own test-fixes commit carries it; where J changed nothing, J makes a
    `git commit --allow-empty` whose message is the record — hooks run,
    `--no-verify` is never used. An empty commit is visible in the commit
    list and in the review guide, which is the point of the duty.
24. **A state file from before this change runs the old way.** No
    `reviewMode` under `gates.G` means the run started on an older
    pipeline. It continues with one commit at K, and says so. It is never
    migrated mid-run.

## Campaign 3 Global Constraints (every Campaign 3 seed includes these)

- **Campaign 2's Global Constraints all still bind** — the house suite
  from the repo root, positive controls for every ad-hoc grep, no joined
  banned literal in this file, pinned strings (add near, never reword
  silently), the vocabulary surfaces, count-free shipped prose,
  `git add` by name, the changelog heading shape, three-place version
  agreement, and the owner merges. Seeds travel alone, so each restates
  the house suite.

- **House test suite baseline, measured 2026-09-29 at `main` =
  `dacf58e`: `1..170`, 170 ok, 0 not ok, 0 non-TAP, exit 0.** Each phase states its required delta.

- **A pin changed on purpose is proven twice.** Several sentences this
  campaign must change are pinned word for word in
  `pipeline/tests/prose.bats` (the G pre-answer contract at `:205`, the
  phase J span at `:609`, the gate rows at `:21`, the never-bend rows at
  `:27`). Change the pin in the same commit as the prose. Then prove the
  new pin with an INVERTED mutant — a sentence asserting the opposite —
  not only a deleted one, and confirm the mutation landed before
  trusting the red.

- **The pipeline running these seeds is the RELEASED one.** P19–P22 run
  on the installed pipeline 1.2.1, which has none of this campaign's
  behaviour. Do not expect a review question at G during this campaign.

## Phase 19: progress.sh learns commits and pieces

The orchestrator needs two things the state helper cannot do today:
record each commit a run makes, and name the next piece to build.

The state file already carries a top-level `commits: []`, created by
`init` at `pipeline/scripts/progress.sh:72` and read by nothing. This
phase gives it a shape and a writer. `validate` (`:41-55`) does not
reject unknown keys and needs no change for that reason.

**Requirements:**

1. **`progress.sh commit-add <feature> <kind> <sha> <piece> <tasks> <files...>`**
   appends one entry to `commits`: `sha`, `kind`, `piece`, `tasks` (an
   array of task IDs, passed as one comma-separated argument) and
   `files` (an array of paths, the remaining arguments). Legal kinds:
   `spec`, `piece`, `converge`, `simplify`, `review`, `tests`,
   `constitution`, `other`. It refuses, by name and with a non-zero
   exit: an unknown kind; an empty sha; a sha that is not 7–40
   lowercase hex digits; a sha already recorded; an unknown feature.
   `piece` and `tasks` may be empty for kinds other than `piece`; for
   `piece` both are required. `files` may be empty only for `tests`
   (ruling 23's empty commit). Written through a temp file and `mv`,
   like every other writer here.

2. **`progress.sh piece-next <feature>`** reads the tasks file named in
   `artifacts.tasks`, lists its `## Phase <N>:` headings in file order,
   and prints the first one with no `piece` or `converge` entry in
   `commits` (a converge-appended phase is committed by H.5, and must not
   come back as a piece). It prints the heading text after `## `,
   verbatim, on the first line, and the task IDs under it on the second,
   comma-separated (`T` followed by digits, on `- [ ]` and `- [X]` lines
   up to the next `## ` heading). When every piece is recorded it prints
   nothing and exits 0. It refuses, by name: no `artifacts.tasks`; a
   tasks file that does not exist; a tasks file with no `## Phase <N>:`
   heading at all.

3. **Match headings as fixed strings, not one clever regex.** Real
   headings carry an em dash, emoji and parentheses — e.g.
   `specs/017-guard-config-bounds/tasks.md:61` and `:99`. Use them as
   fixtures. Compare a recorded `piece` to a heading byte for byte.

4. **Update the usage line at `:23`** to name both new commands.

**Acceptance criteria:**

- Every refusal in requirements 1 and 2 has its own bats test in
  `pipeline/tests/progress.bats`, plus a test for each good case: one
  entry written with the right JSON types (`tasks` and `files` are
  arrays, asserted with `type == "array"`, never by value alone); an
  entry appended, not replacing; `piece-next` skipping a recorded piece;
  `piece-next` skipping a converge-recorded phase; `piece-next` printing
  nothing when all are done; the heading shapes of requirement 3.
- Each new test is shown RED against the unchanged script before it is
  shown green.
- Full house suite from the repo root: **the baseline before, baseline
  + N after**, 0 not ok, 0 non-TAP, and the plan line equals the ok
  count. Name every added test in the commit message.
- `shellcheck --norc -f gcc` clean, as CI runs it.

**Constraints:** Campaign 3 Global Constraints apply — including the
full house suite, restated here because seeds travel alone:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
run from the repo root. `pipeline/scripts/` is a RELAXED surface.
**Changelog routing: none.** These commands are called only by the
orchestrator; P20 and P21 write the user-visible entries. The orchestrator prose
does not change in this phase.

**Invocation:**

```
/pipeline Phase 19: progress.sh learns commits and pieces --auto --implementer claude
```

---

## Phase 20: the orchestrator builds in pieces

**RUN PHASE 19 FIRST.** This phase calls `commit-add` and `piece-next`.

Campaign 3 splits the orchestrator change in two, on the owner's ruling
of 2026-09-29: a campaign about changes too large to review should not
ship one. This phase is the front half: G, H, pauses, resume. Phase 21
is the back half: the late commits, K and the review guide.

All line numbers below are `pipeline/skills/pipeline/SKILL.md` at
`main` = `dacf58e`. Rulings 15–24 are the design; this phase writes
rulings 15–17, 19–22 and 24 into the orchestrator.

**Between this phase and the next, K keeps working unchanged.** H.5, H.7,
I and J do not commit yet, so their changes are still uncommitted when K
runs, and K's existing "show the exact file list and commit it" handles
them as it does today. Do not touch K, L, DONE or the late phases here.

**Requirements:**

1. **G asks the review question** (ruling 15). After the implementer
   answer resolves to `claude` — asked or pre-answered — G asks:
   commits or pauses. Record it as `gates.G.reviewMode`. It is asked on
   every run, never pre-answered, and `--auto` never collapses it. When
   the implementer answer is `handoff`, G does not ask it and says so in
   one line (ruling 22). **The pinned sentence "When `implementer`
   resolves to `claude` or `handoff` (config or flag), G records that
   answer in `gates` and does not stop — the choice was typed on
   purpose." (`:396-398`, pinned at `prose.bats:205`) becomes false for
   `claude`.** Rewrite it so the implementer question is still not
   re-asked but G still stops for the review question, and change the
   pin with it (Global Constraints: proven twice).

2. **H commits the spec, then builds piece by piece** (rulings 16, 17,
   19, 20). Rewrite H (`:497-501`): first the spec commit; then loop
   `piece-next` → implement that piece's tasks (the existing fan-out
   rules apply within the piece) → take the exact list of files the
   piece changed, from `git status` before and after → commit exactly
   those paths plus `tasks.md` with the piece's `[X]` marks →
   `commit-add`. Commit message in `commitStyle`, naming the piece and
   its task range, e.g. `feat(<feature>): User Story 1 (T005–T012)`.
   `last_task` keeps its current meaning.

3. **Pause mode** (ruling 15). After a piece is built and before it is
   committed, stop and show: the piece name, its task IDs, the exact
   file list, `git diff --stat` for those files, and the piece's
   checkpoint result where the tasks file names one. Three answers:
   **go on** (commit, continue); **fix this** (the developer says what;
   the run changes it and shows the piece again); **stop here** (the
   `--until` rule binds: state intact, lock released, resumable). Files
   the developer edited during the pause go into that piece's commit and
   are listed in the message as edited by the owner. A pause is a safe
   handoff point, like every gate. `--auto` never collapses a pause.

4. **Hook failure** (ruling 21). Name it where commits are made: a hook
   that rejects a piece commit is a hard stop; never `--no-verify`.

5. **Resume and `--from H`** (ruling 24). Resume enters the piece
   `piece-next` names; a recorded piece is never rebuilt; a parked or
   rejected piece is shown again first. A state file without
   `gates.G.reviewMode` continues the old single-commit flow and says so.
   A re-entry — `--resume` or `--from G` — that finds
   `gates.G.reviewMode` already recorded never re-asks it: the recorded
   answer stands, the same rule the implementer answer follows at
   `:412-421`. There is no flag to replace it in this campaign, so it
   holds for the life of the run.

6. **Every copy of the gate floor and of piece commits, in this file.**
   The "Up to five stops" paragraph (`:611-617`) and the floor paragraph
   (`:619-624`), both false once G always stops for `claude`; the
   never-bend row's reason for `git add -A` (`:672`, "Phase K names every
   path it stages" — the left column is pinned at `prose.bats:27`, the
   reason column is free to change), which now binds every commit
   (ruling 20); the MAY-do paragraph (`:678-683`), which must now list
   local piece commits; and the Parallel agents paragraph (`:651-659`),
   which must say fan-out stays within one piece. The five gates stay
   five: the review question lives inside G, and a pause is a stop the
   developer chose, listed beside the conditional stops.

**Acceptance criteria:**

- New pins in `pipeline/tests/prose.bats` for: the review question is
  asked every run and never collapsed by `--auto`; a recorded review
  answer is never re-asked on re-entry; a pause is never collapsed by
  `--auto`; the handoff path's one-line notice; the hook hard stop with
  `--no-verify` forbidden; every commit names every path; the legacy
  state-file rule. Each new pin is proven by an INVERTED mutant, with the
  mutated line echoed before the red is trusted.
- The G sentence changed on purpose (requirement 1) is named in the
  commit message, old sentence and new.
- Full house suite from the repo root: P19's count before, that + N
  after, 0 not ok, 0 non-TAP, plan line equal to ok count.
- A dry read of the new H against a real tasks file
  (`specs/017-guard-config-bounds/tasks.md`) is written into the run's
  `specs/` directory: which pieces `piece-next` yields, in order, and
  which of them would change only `tasks.md`. Measured with
  `piece-next`, not predicted.

**Constraints:** Campaign 3 Global Constraints apply — including the
full house suite, restated here because seeds travel alone:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
run from the repo root. `pipeline/skills/` is a RELAXED surface.
**Changelog routing: `pipeline/CHANGELOG.md` has no `## [Unreleased]`
heading at `dacf58e`; open one above `## [1.2.1]`**, with an `### Added`
entry for piece commits and pause mode, and a `### Changed` entry
stating plainly that G now stops on every run whose implementer is
`claude`. The documents outside the orchestrator are P22's; do not
touch them here.

**Invocation:**

```
/pipeline Phase 20: the orchestrator builds in pieces --auto --implementer claude
```

---

## Phase 21: the orchestrator commits late fixes and guides the reviewer

**RUN PHASE 20 FIRST.** This phase builds on its piece commits.

The back half of the orchestrator change: every phase after H commits
its own work, K shows the whole commit list, and the pull request tells
the reviewer how to read it. Line numbers are `SKILL.md` at `main` =
`dacf58e`; P20 will have moved them, so find each section by its bold
heading, not by the number. This phase writes ruling 18, K's half of
ruling 19, and ruling 23 into the orchestrator.

**Requirements:**

1. **Late commits** (ruling 18). H.5 (`:503-505`), H.7 (`:507-509`),
   I (`:511-513`) and J (`:515-521`) each end with one commit of their
   own when they changed a file, recorded with `commit-add` under kinds
   `converge`, `simplify`, `review`, `tests`. H.5 records the heading
   of the phase converge appended to the tasks file as the entry's
   `piece`, so `piece-next` never offers it as a piece. **J's carry duty
   (`:523-538`, span-pinned at `prose.bats:609`) names "the commit
   message"; say which commit — J's own — and apply ruling 23 when J
   changed nothing.** The span pin will go red on any insertion into
   that region: change it on purpose, in the same commit.

2. **K reviews the commit list** (ruling 19). Rewrite K (`:546-551`):
   show `git log --reverse <base>..HEAD` with each commit's files, plus
   any file still uncommitted with its exact proposed message; commit
   the remainder only after the answer. The constitution's separate
   commit is unchanged. K's gate-table row keeps the name `Commit`
   (pinned at `prose.bats:21`); its "Shown before you answer" column
   changes.

3. **The review guide** — the actual fix for the complaint. L's pull
   request body (`:553-557`) and the DONE summary (`:605-607`) carry a
   table built from `commits`, in commit order: commit, kind, piece,
   task IDs, files — headed with one line telling the reviewer to read
   commit by commit, top to bottom. It is shown in full at L, like the
   rest of the body.

4. **The K row of the gate table** (`:637-643`) shows the commit list,
   not one file list. The row name stays `Commit`.

**Acceptance criteria:**

- New pins in `pipeline/tests/prose.bats` for: each late phase commits
  its own work; J's carry lands in J's own commit, or in an empty commit
  when J changed nothing; K shows the commit list; the review guide in
  both the PR body and the DONE summary. Each new pin is proven by an
  INVERTED mutant, with the mutated line echoed before the red is
  trusted.
- The phase J span pin changed on purpose (requirement 1) is named in
  the commit message, old text and new.
- Full house suite from the repo root: P20's count before, that + N
  after, 0 not ok, 0 non-TAP, plan line equal to ok count.
- A dry read of the new K and L against
  `specs/017-guard-config-bounds/tasks.md` is written into the run's
  `specs/` directory: the review guide table the run would print for
  it, built from `piece-next` output and the late phases, not predicted.

**Constraints:** Campaign 3 Global Constraints apply — including the
full house suite, restated here because seeds travel alone:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
run from the repo root. `pipeline/skills/` is a RELAXED surface.
**Changelog routing: `pipeline/CHANGELOG.md`, under the `## [Unreleased]`
heading P20 opened** — add to its `### Added` (the review guide) and its
`### Changed` (late phases commit their own work; K shows the commit
list). The documents outside the orchestrator are P22's.

**Invocation:**

```
/pipeline Phase 21: the orchestrator commits late fixes and guides the reviewer --auto --implementer claude
```

---

## Phase 22: the documentation says pieces

**RUN PHASES 20 AND 21 FIRST.** This phase documents what they shipped.

Every site below states a claim P20 or P21 made false, verified at `main` =
`dacf58e`. Records go stale one shape at a time: grep for every copy of
each claim, do not trust this list to be complete.

**Requirements:**

1. `pipeline/docs/phases.md` — G's row (the review question), H's row
   (spec commit, piece commits, pause mode), H.5/H.7/I/J rows (own
   commits), K's row (the commit list, not one commit), L's row (the
   review guide in the body).
2. `pipeline/docs/configuration.md:79-115` — the paragraphs on what
   `implementer` pre-answers and on a run that "reaches the end with no
   gate stopping it". Both are now false for `claude`.
3. `pipeline/README.md` — "The five gates" (`:57`) and anything under it
   describing G, K or the floor. Add a short section on reviewing a run
   commit by commit.
4. `README.md:56` and `:288` — the root summary and its gate list.
5. `pipeline/CHANGELOG.md` — nothing new unless P20's and P21's entries are now
   incomplete; history already stamped is never edited.

**Acceptance criteria:**

- For each claim — "five stops", "no gate stopping", "K commits",
  "one commit", "pre-answers the implementer gate" — the grep command
  and its hit list are in the commit message, each grep fired first
  against a known hit as a positive control.
- The link checker is green.
- Full house suite from the repo root: P21's count, UNCHANGED — this
  phase adds no tests — 0 not ok, 0 non-TAP.

**Constraints:** Campaign 3 Global Constraints apply — including the
full house suite, restated here because seeds travel alone:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
run from the repo root. `pipeline/README.md`, `pipeline/docs/` and the
root documents are STRICT surfaces. **Changelog routing: none**, unless
requirement 5 applies.

**Invocation:**

```
/pipeline Phase 22: the documentation says pieces --auto --implementer claude
```

---

## Phase 23: release pipeline 1.3.0

**RUN PHASES 19, 20, 21 AND 22 FIRST.** Campaign 2 released before its last
phases landed, and the fix sat unreleased for a cycle.

**Requirements:**

1. **Stamp pipeline 1.3.0.** `pipeline/.claude-plugin/plugin.json` →
   `1.3.0`; the pipeline entry in `.claude-plugin/marketplace.json` →
   `1.3.0` (edit with `sed`, not `jq` — `jq` reformats the file);
   `pipeline/CHANGELOG.md`'s `## [Unreleased]` heading becomes
   `## [1.3.0] - <today>`. Minor, not patch: G gains a question and a
   stop, and H, K and L change what they commit and show.
2. **Content beneath the heading is already complete.** Add nothing,
   remove nothing, reorder nothing.
3. **The `## [Unreleased]` heading must be GONE** when this phase ends.
4. **The handoff plugin is not stamped.** Nothing under `handoff/`
   changed this campaign.

**Acceptance criteria:**

- `jq -r '.plugins[] | "\(.name) \(.version)"' .claude-plugin/marketplace.json`
  prints `handoff 2.2.0` and `pipeline 1.3.0`; `plugin.json` and the
  changelog heading agree.
- `grep -c '^## \[Unreleased\]' pipeline/CHANGELOG.md` returns `0`.
- Full house suite from the repo root: P22's count, 0 not ok, 0 non-TAP.
- The CI matrix is green on all three OSes, read as a STEP conclusion,
  and a run is confirmed to EXIST before green is believed.

**Constraints:** Campaign 3 Global Constraints apply — including the
full house suite, restated here because seeds travel alone:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
run from the repo root. This phase changes three version strings and
one heading. Nothing else.

**Invocation:**

```
/pipeline Phase 23: release pipeline 1.3.0 --auto --implementer claude
```

**After the merge (owner + assistant):**

```
git checkout main && git pull
git tag pipeline-v1.3.0 && git push origin pipeline-v1.3.0
```

Watch the tag CI run. Then refresh the installed plugin (marketplace
first, qualified id, local scope) and restart, or the next run still
uses 1.2.1.

## Campaign 3: not in this plan (recorded, deliberately excluded)

- **A `reviewMode` configuration key or flag.** The owner asked for the
  choice on every run. A pre-answer mirroring `implementer` is the
  natural follow-up if the stop proves tiresome.
- **Review pieces on the handoff implementer path** (ruling 22). The
  shape that works is one package per piece, which makes the owner relay
  every piece by hand. Revisit if people ask.
- **Folding late fixes back into their piece** (ruling 18). Cleanest
  history, but it rewrites commits and cannot apply to a piece already
  reviewed in pause mode.
- **Stacked pull requests, one per piece.** Easiest to read on GitHub,
  hardest to build and to merge. The ordered commit list and the review
  guide deliver most of the value first.
- **Running simplify, review and the suite once per piece.** Each piece
  would be complete and green alone, at several times the cost.

---

## Phase 24: the release gate reads the whole changelog, and one suite check

**Campaign 3 is closed** (pipeline 1.3.0, tagged at `3f4f795`). This phase
takes the three follow-ups the 1.3.0 release recorded and could not close
inside its own three lines: `specs/022-release-pipeline-1-3-0/research.md`,
R7. Nothing here is inside a plugin — `scripts/`, `tests/` and `specs/` are
the repository's own — so **no plugin release follows this phase**.

Measured 2026-10-01 at `main` = `52a40be`:

- `scripts/check-versions.sh:198` reads only the FIRST `## ` heading
  (`grep -m1`) and compares it with the version heading. An
  `## [Unreleased]` heading lower in the file passes the default run AND
  `--released` (proved by mutation at the 1.3.0 deep review). The 1.3.0
  release caught that shape only with its own quickstart check, S4, which
  CI never runs.
- Eleven feature quickstarts under `specs/` carry a hand-written copy of
  the house-suite result check (plan line, ok count, not ok, non-TAP).
  The copies already differ: only `021` and `022` count skipped tests.
- Clause C4 of `specs/016-release-two-plugins/contracts/version-agreement.md`
  still reads "**Enforced by**: **NOTHING.**" Since 1.2.0 a tag run's
  agreement step passes `--released`, and `tests/portability.bats:1216`
  tests it on a fixture. The clause is dated history and stays as
  written.

**Requirements:**

1. **`--released` refuses an `## [Unreleased]` heading anywhere** in the
   named plugin's changelog, not only above the version heading. The
   refusal names the line. The default run (no argument) keeps its
   behaviour: it reports, and fails only on disagreement. One
   implementation: CI's call and the suite's call stay the single script
   they are today, and the "one version-agreement script" test at
   `tests/portability.bats:652` stays green unchanged.
2. **One suite-result check, `scripts/check-suite.sh <expected> <tap-file>`.**
   It passes only when the plan line is `1..<expected>`, the `ok` count is
   `<expected>`, and there are 0 skipped, 0 `not ok` and 0 non-TAP lines; it
   fails, naming the reason, on each other shape, and on an empty or
   missing file. `CONTRIBUTING.md` says that a feature quickstart calls it
   instead of writing its own copy. The eleven existing quickstarts are
   dated records and are NOT edited.
3. **A forward note on clause C4.** Append — below the clause, never in it
   — one dated note: since 1.2.0 a tag run's agreement step enforces C4
   for the plugin being tagged, and since this phase `--released` also
   refuses a lower heading. Every existing line of that file stays
   byte-identical.

**Acceptance criteria:**

- Requirement 1's test plants `## [Unreleased]` BELOW a released heading in
  a fixture: `--released` refuses it with its named reason, and the default
  run still exits 0. Then a mutant that restores the first-heading-only
  comparison makes that test go red — the mutation confirmed to have landed
  before the red is believed.
- Requirement 2's test drives every failure shape (a wrong plan line, an
  ok count short of the plan, one skipped test, one `not ok`, one non-TAP
  line, an empty file, a missing file) and one passing control; each shape
  is shown to fail for its own named reason, not merely to exit non-zero.
- `git diff 52a40be -- specs/016-release-two-plugins/` shows only added
  lines.
- Full house suite from the repo root: `1..242` (240 at `52a40be`, plus one
  test per requirement 1 and 2), 242 ok, 0 skipped, 0 not ok, 0 non-TAP.
- CI green on all three operating systems, a run confirmed to EXIST before
  its result is read.

**Constraints:** Campaign 3 Global Constraints apply — including the full
house suite, restated here because seeds travel alone:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
run from the repo root. `scripts/` and `CONTRIBUTING.md` are on the
shipped root surface: STRICT vocabulary, no machine path, no count in
prose. **Changelog routing: none** — no plugin changes, and the root
`CHANGELOG.md` is an index. This run uses the INSTALLED pipeline 1.3.0, so
G asks the review question (commits or pauses).

**Invocation:**

```
/pipeline Phase 24: the release gate reads the whole changelog, and one suite check --auto --implementer claude
```

**Correction, 2026-10-02.** "Since 1.2.0" above, twice (the C4 measurement
and requirement 3), is one release early. The tag run's `--released` call is
commit `f5e4090`, first shipped in pipeline 1.2.1 and handoff 2.2.0. The
run found this in its piece 3, and the feature's own files say 1.2.1 / 2.2.0.
The seed above is left as written. **Outcome:** merged as PR #53, `main` =
`8bc9b5a`. Two follow-ups were left: this correction, and Phase 25.

## Phase 25: the release gate reads every level-2 heading form

Phase 24 made `--released` judge every line beginning `## `. Its deep review
found the other ways Markdown writes a level-2 heading, and left them for a
later decision (`specs/023-gate-reads-whole-changelog/research.md`, R7).
The owner's ruling (2026-10-02): **judge every Markdown form.** Like Phase 24,
this phase changes nothing inside a plugin, so **no plugin release follows
it**.

Measured 2026-10-02 at `main` = `8bc9b5a`:

- `scripts/check-versions.sh:243`, the whole-file rule, matches `/^## /`
  only. CommonMark also renders each of these as a level-2 heading, and each
  passes `--released`. Measured by appending each one below the release in
  a scratch copy of `handoff/CHANGELOG.md`: each exits 0, while a plain
  `## Notes` control exits 1.
  - `##` followed by a tab;
  - `##` indented by one to three spaces;
  - `##` with nothing after it (an empty heading);
  - a setext heading: a paragraph line, then a line of `-` characters.
- A `## ` line inside a fenced code block is not a heading, but today's rule
  would refuse it. `handoff/CHANGELOG.md` holds one fenced block (lines
  316-319) with no `## ` line in it, so nothing is refused wrongly today.
- Neither changelog holds a tab, indented or empty `##` heading, or any line
  made only of `-` or `=` characters.

**Requirements:**

1. **`--released <plugin>` refuses every level-2 heading that is not a
   dated version heading, in every Markdown form.** That means ATX (`##`
   then a space, a tab or the end of the line, indented zero to three
   spaces, with an optional closing run of `#`) and setext (a paragraph
   line followed by an underline of `-` characters, indented zero to three
   spaces). Only the canonical dated form the gate reads today counts as
   dated. Any other form is refused, even one carrying a version and a date.
   The refusal names the line and its text, with non-printable characters
   shown as `?`, as today.
2. **What is not a heading is never judged:** a line inside a fenced code
   block (backticks or tildes, indented zero to three spaces); a line
   indented four or more spaces; and a `-` line with no paragraph line
   directly above it (a thematic break, e.g. after a blank line). The
   owner's ruling on doubt: a wrong refusal is acceptable, because it fails
   closed and the owner fixes the changelog. A wrong pass is not.
3. **Nothing else moves.** The default run (no argument) keeps its output
   and status. The first-heading message (Phase 24 contract G3) stays. CI
   and the suite still call the one script, and the "one version-agreement
   script" test stays green unchanged.
4. **The test fixtures keep their own baseline.** `normalise_to_released`
   in `tests/portability.bats` removes undated `## ` lines only. It must
   remove every heading form requirement 1 refuses, or a live changelog
   holding one would turn the `--released` tests red on a correct tree. The
   fixture keeps its own copy of any pattern: it never reads one from the
   gate.

**Acceptance criteria:**

- A test plants each new shape BELOW the release in a fixture: `##` plus a
  tab; `##` indented one space and three spaces; an empty `##`; `## Notes ##`;
  a setext heading; and a dated heading indented one space. `--released`
  refuses each one, naming its line, and the default run still exits 0.
- The same test's negative controls are NOT refused: a `## ` line inside a
  fenced block below the release; a `---` line after a blank line; and a
  `## ` line indented four spaces.
- A mutant that puts back the gate of `8bc9b5a` turns that test red, naming
  its clause. Confirm the mutation landed before believing the red.
- The feature quickstart, run as one script, ends ALL OK.
- Full house suite from the repo root: `1..243` (242 at `8bc9b5a`, plus one
  test), 243 ok, judged by `bash scripts/check-suite.sh 243`.
- CI green on all three operating systems. Confirm a run EXISTS before
  reading its result.

**Constraints:** the Campaign 3 Global Constraints apply, including the
full house suite, restated here because seeds travel alone:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
run from the repo root. `scripts/` is on the shipped root surface: STRICT
vocabulary, no machine path, no count in prose. Bash 3.2 and every awk
(gawk, mawk, the BSD awk on macOS); no interval expressions in awk
patterns. **Changelog routing: none.** This run uses the INSTALLED pipeline
1.3.0, so G asks the review question (commits or pauses).

**Invocation:**

```
/pipeline Phase 25: the release gate reads every level-2 heading form --auto --implementer claude
```

## Phase 26: the release gate closes the gaps Phase 25 left

Phase 25 (PR #55, merged as `ceff931`) made `--released` judge every
level-2 heading form. Its reviews left three gaps, a few test weaknesses,
and four wrong refusals the strict rules accept; all are listed in the
PR #55 body and in `specs/024-gate-every-heading-form/`. The owner's ruling
(2026-10-03): **close all of them.** The ruling on doubt still binds: a
wrong refusal is acceptable, a wrong pass is not. Like Phases 24 and 25,
this phase changes nothing inside a plugin, so **no plugin release follows
it**.

Measured 2026-10-03 at `main` = `ceff931` on a one-plugin fixture built
from `handoff/`:

- **A lone CR inside a line passes.** Markdown reads a CR as a line end,
  so `Notes`, a CR, then `## x` holds a level-2 heading. With the walk's
  awk reading bytes as the Linux and macOS awks do (`-v BINMODE=3` here),
  `--released` exits 0 on it, while a plain `## x` control exits 1.
  `.gitattributes` forces LF, so a CRLF cannot reach a commit; only a lone
  CR can. Neither changelog holds a CR byte.
- **The first-heading text is printed raw.** `scripts/check-versions.sh:212`
  strips only CR and LF before the default form prints
  `state=UNRELEASED-ABOVE:<text>`, and `:225` quotes the same line raw in
  the `--released` refusal. With an escape sequence in the first heading,
  both print it into the log. Every other quoted line already goes through
  the walk's `show()`, which prints a non-printable character as `?`.
- **A long nested-quote line is slow.** One line of `> ` repeated:
  50,000 markers take 0.9 s, 100,000 take 1.4 s, 200,000 (400 KB) take
  22 s, and 400,000 take 123 s. The time grows much faster than the line.
  The longest line in either changelog is 107 characters. A refusal also
  quotes its whole line, so a 400 KB line puts 400 KB into the log.
- **A changelog holding a NUL byte** makes `grep` print `Binary file …
  matches`, and the gate exits 1 with no message of its own. It fails
  closed, but the owner cannot tell why.
- **Four wrong refusals** (each refused today; CommonMark reads none of
  them as a level-2 heading):
  - `1. a` then `2. ` + a fence, a normal numbered list (the walk refuses
    any fence on an ordered marker other than `1`);
  - a fence anywhere below `<details>` … `</details>` (any `<` line refuses
    every later fence);
  - `### Notes` then `---` (a thematic break under a heading);
  - `> Notes`, `>`, `> ---` (a thematic break after an empty quote line).
- **The test helpers have weak spots** (`tests/portability.bats`):
  - the new helpers build `run bash -c "…"` strings from `marketplace.json`
    data (`:1330`, `:1586`, `:1616`, `:1649`, `:1658` and the older
    `--released` tests), so a `"` or `$` in a plugin source would run as
    shell;
  - the absolute-path check (`:1630`) matches one spelling of each path and
    reads only refusal output, never `forms_passes`, `forms_default` or
    the two-plugin run;
  - `forms_default` (`:1657`) runs once per test on a combined copy, not on
    each plant's copy;
  - `forms_passes` (`:1648`) never proves its plant landed;
  - in `normalise_to_released`, the second half of the self-check (`:1290`)
    counts what the same program already dropped, so it can never fail,
    and the `mv` before it is unguarded;
  - `forms_at` aborts with no message when its count is 0, because
    `grep -c` exits 1 under errexit.

**Requirements:**

1. **A CR is a line end.** `--released <plugin>` refuses any line of the
   changelog that holds a CR byte, naming the line, with the CR shown as
   `?`. (Splitting lines at a CR as Markdown does is the alternative; the
   spec picks one and records why. Refusing is the strict default.)
2. **Every quoted text is masked.** The first-heading state field and the
   first-heading refusal show every non-printable character as `?`, the
   same way `show()` does. The default run's output on the real tree is
   byte-identical before and after (neither first heading holds one).
3. **A line too long to judge is refused.** The walk refuses any line
   longer than a fixed limit, naming its line and its length, before
   judging it. The spec sets the limit with room above 107. Every quoted
   text in every refusal is cut to a fixed length, with a marker saying it
   was cut.
4. **A NUL byte is named.** A changelog holding a NUL byte is refused with
   a message of the gate's own, naming the plugin.
5. **Each wrong refusal is narrowed only where proven safe.** For each of
   the four, the walk may stop refusing that shape only if a reference
   CommonMark parser (Phase 25's review used markdown-it-py in CommonMark
   mode), run over a systematic enumeration of the shape in
   every container, finds that the narrowed walk passes no level-2
   heading it renders, AND the same enumeration, run against a walk with
   the narrowing done wrongly, finds at least one (a positive control).
   Where that proof cannot be made, the refusal stays, and the spec
   records why. The enumeration and its results are kept in the run
   directory and summed up in the PR body.
6. **The test helpers are strong.**
   - Every `run bash -c` in the `--released` tests passes data as
     arguments (`bash -c '…' _ "$d" "$ROOT" "$copied"`), never inside the
     command string.
   - The absolute-path check reads every output the tests capture, in
     every spelling the platform prints.
   - `forms_default` runs on every refused plant's own copy, or the
     contract's H8 wording is changed to say what is checked; the spec
     picks.
   - `forms_passes` proves its plant landed, as `forms_refused` does.
   - The fixture helper's self-check can fail: it checks the dropped
     file against an independent test, and the `mv` is guarded.
   - `forms_at` prints its own message when the line is missing.
7. **Nothing else moves.** The default run (no argument) keeps its output
   and status on the real tree. The first-heading check (Phase 24 G3) still
   reads the first line beginning `## `. CI and the suite still call the
   one script, and the "one version-agreement script" test stays green
   unchanged. The fixture helper never reads a pattern from the gate.

**Acceptance criteria:**

- Tests plant: a lone CR before `## x`; an escape sequence in the first
  heading (both forms); a line over the limit; a NUL byte. Each is refused
  with its message, and the default run still exits 0 where it did. A
  mutant that removes each new rule turns its test red, naming its clause.
  Confirm each mutation landed before believing the red.
- Each wrong refusal narrowed under requirement 5 has a passing plant, and
  its enumeration proof is in the run directory. Each one kept has a line
  in the spec saying why.
- The test-helper changes are each shown able to fail: a mutant per change
  (for example a path printed in a passing run's output) turns a test red.
- The feature quickstart, run as one script, ends ALL OK.
- Full house suite from the repo root: `1..248` at `ceff931`, plus the
  tests this phase adds. Prefer adding plants to the existing `--released`
  tests: the per-test timeout is 60 s and the slowest of them takes about
  18 s. The spec fixes the exact count, and the suite is judged by
  `bash scripts/check-suite.sh <that count>`.
- CI green on all three operating systems. Confirm a run EXISTS before
  reading its result, and read every job's steps.

**Constraints:** the Campaign 3 Global Constraints apply, including the
full house suite, restated here because seeds travel alone:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
run from the repo root. `scripts/` is on the shipped root surface: STRICT
vocabulary, no machine path, no count in prose. Bash 3.2 and every awk
CI runs (gawk, and the BSD awk on macOS); no interval expressions in awk
patterns. A CR test must plant a LONE CR: Windows gawk strips a CR that
comes before a line feed. **Changelog routing: none.** This run uses the
INSTALLED pipeline 1.3.0, so G asks the review question (commits or
pauses).

**Invocation:**

```
/pipeline Phase 26: the release gate closes the gaps Phase 25 left --auto --implementer claude
```

## Phase 27: the release gate reads only what it can judge, and prints only what is safe

Phase 26 (PR #57, merged as `6fd91f3`) closed every gap Phase 25 left.
Its reviews found three older problems and deferred each, with its
reason, in `specs/025-gate-closes-phase25-gaps/research.md` R14 and in the
PR #57 body. The owner's ruling (2026-10-04): **close all three.** The
ruling on doubt still binds: a wrong refusal is acceptable, a wrong pass
is not. Like Phases 24 to 26, this phase changes nothing inside a
plugin, so **no plugin release follows it**.

Measured 2026-10-04 at `main` = `6fd91f3` on a one-plugin fixture built
from `handoff/`:

- **A changelog that is a symbolic link is read wherever it points.**
  With `handoff/CHANGELOG.md` a link to `/dev/urandom`, the default form
  ran until it was killed at 20 s. A link to `/dev/zero` failed on
  grep's own error, then the gate's "no changelog heading" message. The
  NUL check skips the file because it is not a regular file. On Linux
  and macOS, `actions/checkout` makes a committed link a real link. This
  machine can make one too (`core.symlinks` is true); whether the
  windows-latest runner can is not measured.
- **Values read from tracked files are printed raw.** A `plugin.json`
  version of `1.0.0`, a line feed, `::error title=forged::all checks
  passed` and an escape sequence printed, in the default form:
  - on the report line, `plugin=1.0.0::error title=forged::all checks
    passed` with the escape byte raw (the line strips only CR and LF);
  - in the `die` message, a second log line that STARTS with `::error`,
    which a workflow log reads as a command.

  The output held 2 raw escape bytes. The same holds for the marketplace
  `name` and `source`, the plugin directory name, and the changelog's
  version, wherever a message quotes them.
- **Nothing bounds a changelog's size.** The line limit bounds the cost of
  one line, not of the file. Lines of 499 list markers, each one passing
  the walk: 1 MB took `--released` 4.1 s, 2 MB 9.2 s and 4 MB 14.6 s. The
  real changelogs are 38 KB (`handoff`) and 15 KB (`pipeline`). The suite
  runs the gate dozens of times on copies of the live changelogs.

**Requirements:**

1. **A changelog must be a regular file.** Before any tool reads it, in
   both forms, the gate refuses a `CHANGELOG.md` that is a symbolic link,
   or that exists but is not a regular file, with a message of its own
   naming the plugin. A missing changelog keeps its present diagnostic.
2. **One masking point.** Every value the gate prints that it read from a
   tracked file or a directory name is shown through one function that
   masks every byte outside printable ASCII as `?` and cuts at the quote
   cut, as `quoted()` does: the report line's fields and every `die`
   message's quoted values. The gate's own message text is never masked
   (it holds an em dash). The spec lists every print site, derived from
   the script, not from memory.
3. **A changelog too large to judge is refused.** The gate refuses a
   changelog larger than a fixed byte limit before reading it, naming
   the plugin and the size. The spec sets the limit with room above
   38 KB, decides whether the default form refuses too, and records why.
   The size is read without reading the file.
4. **Nothing else moves.** On the real tree, both forms print and exit
   exactly as at `6fd91f3`. The four narrowings and their proof are not
   touched: if the walk's text changes, the proof
   (`specs/025-gate-closes-phase25-gaps/proof/enumerate.py`) is rerun
   and must report 0 wrong passes and each control at least 1. CI and the
   suite still call the one script, and the "one version-agreement
   script" test stays green unchanged.

**Acceptance criteria:**

- Tests plant: a changelog that is a symbolic link; a version with a line
  feed, `::error` and an escape sequence (both forms, and the report
  line); a changelog one byte over the size limit. Each is refused or
  masked with its message, and no output line starts with `::`. A mutant
  that removes each new rule turns its test red, naming its clause.
  Confirm each mutation landed before believing the red.
- The link test runs on all three operating systems. A skipped test
  fails `scripts/check-suite.sh`, so where a system cannot make a link,
  the spec chooses another way to reach the same rule (measure the
  windows-latest runner first), and says so.
- Every byte tool the gate or the tests run on a file or an output that
  may hold a byte which is not valid text runs under `LC_ALL=C`: macOS
  `tr` under a UTF-8 locale stops at such a byte.
- The feature quickstart, run as one script, ends ALL OK.
- Full house suite from the repo root: `1..249` at `6fd91f3`, plus the
  tests this phase adds. Prefer adding plants to the existing tests: the
  per-test timeout is 60 s and the slowest test takes about 23 to 34 s
  on this machine. The spec fixes the exact count, and the suite is
  judged by `bash scripts/check-suite.sh <that count>`.
- CI green on all three operating systems. Confirm a run EXISTS before
  reading its result, and read every job's steps.

**Not in this phase** (each recorded in R14, each a wrong refusal the
ruling accepts or a cleanup): Windows gawk reading a CRLF line end
differently; a one-line `<!-- ... -->` keeping later fences refused; a
tag that only starts with `pre`, `script`, `style` or `textarea`; the
1,000-byte line limit on prose; a mechanical check for U1; bats printing
a failed test's raw `$output`; the quote cut written in both bash and
awk; a job time limit in `.github/workflows/ci.yml`.

**Constraints:** the Campaign 3 Global Constraints apply, including the
full house suite, restated here because seeds travel alone:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
run from the repo root. `scripts/` is on the shipped root surface: STRICT
vocabulary, no machine path, no count in prose. Bash 3.2 and every awk
CI runs (gawk, and the BSD awk on macOS); no interval expressions in awk
patterns. Test a locale-dependent rule with `LANG` set to a UTF-8 locale
and `LC_ALL` unset, as CI runners set them. **Changelog routing: none.**
This run uses the INSTALLED pipeline 1.3.0, so G asks the review question
(commits or pauses).

**Invocation:**

```
/pipeline Phase 27: the release gate reads only what it can judge, and prints only what is safe --auto --implementer claude
```

## Phase 28: the release gate closes what Phase 27 deferred

Phase 27 (PR #59, merged as `5a78ea4`) closed the three problems Phase 26
deferred, and several older ones its reviews found. It deferred the rest,
each with its reason, in `specs/026-gate-reads-safe-prints-safe/research.md`
R10, in its spec's Assumptions (the `##[` form) and in the PR #59 body.
The owner's ruling (2026-10-05): **close everything Phase 27 deferred.**
The ruling on doubt still binds: a wrong refusal is acceptable, a wrong
pass is not. Like Phases 24 to 27, this phase changes nothing inside a
plugin, so **no plugin release follows it**.

Measured 2026-10-05 at `main` = `5a78ea4` on a one-plugin fixture built
from `handoff/`:

- **A link is still followed everywhere but the changelog.**
  - `handoff/.claude-plugin/plugin.json` as a symbolic link to a JSON
    file outside the tree: the gate read it and printed that file's
    name, `plugin.json name 'SECRET-NAME-OUTSIDE' does not match its
    directory`, exit 1.
  - `.claude-plugin/marketplace.json` as a link to a copy outside the
    tree: the gate passed, exit 0, saying nothing of the link.
  - The plugin directory `handoff` as a link to a directory outside the
    tree: the gate passed, exit 0.

  All three runners can make a link (Phase 27's L1 printed
  `# links: made` on ubuntu, windows and macos).
- **`jq`'s own errors quote fork-written text.** A trailing marketplace
  entry whose `name` is an object holding `::error title=x::y` printed
  `jq: error (at .claude-plugin/marketplace.json:28): object
  ({"::error t...) is not valid in a csv row`, exit 5 (jq's status, not
  the gate's). A `.plugins` that is a string printed `Cannot iterate
  over string ("::error ti...)`, then the gate's own line. Neither line
  starts with `::`; the quoted text never passes through `shown`, and
  FR-014 of Phase 27 says no other program may print a value.
- **The runner's older command form, `##[...]`, is not masked.** `#`,
  `[` and `]` are printable. Where in a line the runner acts on `##[`
  was never measured (Phase 27 spec, Assumptions).
- **The caller's shell options reach the gate.** With
  `SHELLOPTS=xtrace` in the environment, the gate traced 120 lines to
  standard error, among them `+ pv=$'1.0.0\E[2K'`: every value read
  from a file, uncut. Bash escaped the control bytes (0 raw escape
  bytes reached the output) and every trace line starts with `+ `.
  `BASH_ENV` names a file bash runs before the gate's first line
  (measured: it ran).
- **Each marketplace entry costs a process.** A fixture with 100 extra
  entries took 2.8 s, with 400 took 9.1 s, against 0.9 s with none:
  about 20 ms an entry. Each entry runs `norm_source` in a `$( )`
  subshell (the share of the cost is not measured).
- **Three test weaknesses** (`tests/portability.bats`):
  - the P0 scan does not see a name ending `_s` set by `printf -v`,
    `read` or `for`, a `$(…)` with no `$` inside, or a `die` message
    continued onto a second line;
  - K3's quote-marker plant requires 50,000 pairs under the size limit,
    so it fails on a correct tree once the copied changelog passes
    153,950 bytes (`handoff`'s is 38,028);
  - `gate_safe` removes every em dash before it checks, not only the
    gate's own text, so a raw em dash in a value passes it.

**Requirements:**

1. **No link is followed.** In both forms the gate refuses, with a
   message of its own naming what it refused, a `plugin.json`, a
   `marketplace.json` and a plugin directory that is a symbolic link,
   before any tool reads through it. The changelog rule stays as it is.
2. **No other program prints a value.** A `jq` read that fails stops
   the gate with its own message, exit 1, and no `jq:` line reaches the
   output. The spec decides how, and keeps a malformed file
   distinguishable from one that cannot be read.
3. **`##[` is measured, then closed.** The spec first measures on a
   runner where in a line the runner acts on `##[`, and records the run.
   Every printed value is then shown so that the runner cannot act on
   it: masked wherever the runner acts, or, if it acts only at the start
   of a line, by the report line's first-field rule extended to `##[`.
4. **No inherited shell option changes what the gate prints.** The gate
   turns off, at its first line, every option the caller can set
   through `SHELLOPTS` that prints or changes behaviour (at least
   `xtrace` and `verbose`); the spec lists them. `BASH_ENV` runs before
   any line of the gate, so no line of it can stop that: the spec either
   chooses a way the callers run the gate without it (CI and the suite),
   or records it as a limit, and says why.
5. **No process per marketplace entry.** `norm_source` sets a variable,
   as `shown` does, instead of printing into `$( )`. The spec records
   the cost per entry before and after, on the fixture above.
6. **The tests check what they claim.**
   - P0 also sees `printf -v`, `read` and `for` into a name ending `_s`,
     a `$( )` with no `$` inside, and a `die` message continued with
     `\`; or the spec replaces the scan with a check that cannot miss a
     print site, and says which.
   - K3's plant is sized from the room under the limit, with no fixed
     floor a longer changelog can break.
   - `gate_safe` removes only the gate's own text, never every em dash.
7. **Nothing else moves.** On the real tree, both forms print and exit
   exactly as at `5a78ea4`. The walk's text is not changed; if it must
   be, the proof (`specs/025-gate-closes-phase25-gaps/proof/enumerate.py`)
   is rerun and must report 0 wrong passes and each control at least 1.
   CI and the suite still call the one script, and the "one
   version-agreement script" test stays green unchanged.

**Acceptance criteria:**

- Tests plant: each of the three links; a marketplace entry whose name
  is an object, and a `.plugins` that is a string; a value holding
  `##[` where the measurement says the runner acts; `SHELLOPTS=xtrace`;
  a marketplace with many entries, timed against a bound. Each is
  refused or masked with its message. A mutant that removes each new
  rule turns its test red, naming its clause. Confirm each mutation
  landed before believing the red.
- The link tests run on all three operating systems, and print which
  way they took, as Phase 27's L1 does.
- Every byte tool the gate or the tests run on a file or an output that
  may hold a byte which is not valid text runs under `LC_ALL=C`.
- The feature quickstart, run as one script, ends ALL OK.
- Full house suite from the repo root: `1..251` at `5a78ea4`, plus the
  tests this phase adds. Prefer adding plants to the existing tests: the
  per-test timeout is 60 s, and the two Phase 27 tests take about 21 s
  (L) and 24 s (P) on this machine. The spec fixes the exact count, and
  the suite is judged by `bash scripts/check-suite.sh <that count>`.
- CI green on all three operating systems. Confirm a run EXISTS before
  reading its result, and read every job's steps.

**Not in this phase:** Phase 26's R14 list stays out (Windows gawk
reading a CRLF line end differently; a one-line `<!-- ... -->` keeping
later fences refused; a tag that only starts with `pre`, `script`,
`style` or `textarea`; the 1,000-byte line limit on prose; a mechanical
check for U1; bats printing a failed test's raw `$output`; the quote cut
written in both bash and awk; a job time limit in
`.github/workflows/ci.yml`).

**Constraints:** the Campaign 3 Global Constraints apply, including the
full house suite, restated here because seeds travel alone:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
run from the repo root. `scripts/` is on the shipped root surface: STRICT
vocabulary, no machine path, no count in prose. Bash 3.2 and every awk
CI runs (gawk, and the BSD awk on macOS); no interval expressions in awk
patterns; never `\/` inside a pattern substitution (macOS bash 3.2
collapsed nothing with it, Phase 27 N). Test a locale-dependent rule
with `LANG` set to a UTF-8 locale and `LC_ALL` unset, as CI runners set
them. **Changelog routing: none.** This run uses the INSTALLED pipeline
1.3.0, so G asks the review question (commits or pauses).

**Invocation:**

```
/pipeline Phase 28: the release gate closes what Phase 27 deferred --auto --implementer claude
```

## Phase 31: the base branch can be set once, or named for one run

Where the remote publishes a default branch, `preflight.sh` resolves the
base branch to it, and the `baseBranch` key cannot override it: the
order is `origin/HEAD`, then the key, then the current branch, and the
orchestrator says so "by design". That is right for most repositories.
It leaves no way for a team that cuts feature branches from an
integration branch, while the remote's default is another branch: every
run cuts from the wrong base.

Measured 2026-10-07 at `main` = `67db081`: a scratch repository with
`origin/HEAD` -> `origin/main` and `--base-branch trunk` reports
`baseBranch: main`, `baseBranchSource: origin/HEAD` (the existing test
`base branch: origin/HEAD first, then the override, each with its
source` pins exactly that).

The change: an override that beats `origin/HEAD`, with two spellings.
The `baseBranchOverride` key is set once in a repository's
`.delivery-kit.json`, so a team needs no per-run typing; the
`--base-branch <name>` flag is for one run, and beats the key. The
`baseBranch` key keeps its meaning; changing a shipped key's precedence
would change every current user's runs. `preflight.sh` gains
`--base-branch-override <name>`, reports `baseBranchSource: override`,
and refuses a name `git check-ref-format --branch` refuses; the
orchestrator names the layer that set the override. The override is read
on a fresh run only: B records the base, and a resume keeps the record.

Not in this phase: naming the feature branch, the spec directory, and
commit trailers. Each is its own phase.

**Invocation:**

```
/pipeline Phase 31: the base branch can be set once, or named for one run
```

## Phase 32: the feature branch and the spec folder can be named for one run

Phase B lets the spec tool name the feature `NNN-slug`, and that one name
becomes the feature branch, the spec folder under `specs/`, and the run's
name under `.delivery-kit/runs/`. A team that names branches by owner
(`<owner>/<area>/NNN-slug`) or keeps specs in nested folders
(`specs/<area>/<owner>/NNN-slug`) has no way to say so.

Measured 2026-10-07 at `031-base-branch-flag` = `7a658c0`: the spec tool
takes a spec folder as given through `SPECIFY_FEATURE_DIRECTORY` and
numbers nothing; its specify command describes that variable in both
0.15.2 and 0.16.5, the two ends of the tested range. `progress.sh` already
keeps the run's name and the branch as separate values, and refuses `/`
in the run's name only.

The change: two orchestrator flags, `--branch <name>` and
`--spec-dir <path>`. B hands the folder to the spec tool, checks the spec
landed there, takes the run's name from its last segment, and cuts the
branch under the typed name. `preflight.sh` gains `--feature-branch` and
`--spec-dir`, reports `featureBranch` and `specDir`, and stops on a bad
value, naming it. Both are read on a fresh run only. They are flags with
no configuration key: each names one feature, so a value set once would
name the same feature on every run. A caller that builds names from its
own settings passes them as flags.

Phase 31 listed the feature branch and the spec directory as separate
phases. They ship together here: both are names B chooses, at the same
moment, from the same default.

Not in this phase: commit trailers.

**Invocation:**

```
/pipeline Phase 32: the feature branch and the spec folder can be named for one run
```
