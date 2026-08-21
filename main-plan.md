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
   `claude` and `handoff`. New flag `--implementer <claude|handoff>`,
   which beats the config key (standard precedence). Added to BOTH
   tables: the orchestrator's Configuration table and Flags table, and
   `pipeline/docs/configuration.md`'s JSON block and key table — names
   and defaults character-identical across the two files.
2. Orchestrator **G** paragraph gains: "When `implementer` is set
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
  character-for-character); pinned strings intact (prose.bats 1..9 ok);
  full suite `1..119`, 0 non-TAP.
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
intact; full suite `1..119`, 0 non-TAP.

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
   `1..119`, 0 non-TAP.

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
