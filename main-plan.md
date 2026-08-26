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
copy in `~/.claude/projects/D--Github-delivery-kit/memory/r2-release-pr12-pending-merge.md`.

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

## Global Constraints (every seed implicitly includes these)

- House test suite (full, from repo root; exceeds 120s — extend timeouts):

  ```
  bash /c/Users/h_zah/bats/bin/bats -r --print-output-on-failure tests handoff/tests pipeline/tests
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
cd /d/Github/delivery-kit
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
  `bash /c/Users/h_zah/bats/bin/bats pipeline/tests/prose.bats` — 1..8 ok).
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

- **⚠️ This plan file must never contain a joined banned literal.**
  It is tracked, it sits inside the new scan's scope, and it is the file
  that defines the scan. Every banned shape is named descriptively here,
  or assembled from parts in a command. Writing one joined would make
  the plan a hit on its own guard — measured: three such literals were
  written into this section on the first draft and removed on review.

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
cd /d/Github/delivery-kit
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
cd /d/Github/delivery-kit
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

- Full house suite from the repo root: **`1..162`**, 0 not ok, 0 non-TAP
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
   `## [2.1.1] - <today>`. Patch, not minor: P14 is an internal
   refactor with identical behaviour and P15 is documentation. Nothing
   was Added.

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
- Full house suite from the repo root: **`1..162`**, 0 not ok, 0 non-TAP
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
