# Research: the orchestrator commits late fixes and guides the reviewer

Every fact below was measured on 2026-09-30 on branch
`020-late-commits-review-guide` at `8efe515` (= `origin/main`), unless it
cites a file line. Line numbers are that commit's; find a section by its bold
heading, never by the number.

## R1 — Which existing pins this change touches

Measured by `grep -nF` of each sentence the plan rewrites, over
`pipeline/tests/*.bats`, `tests/*.bats` and `handoff/tests/*.bats`. Only
`pipeline/tests/prose.bats` pins any of them:

| Pin | Where | What happens |
|---|---|---|
| `--auto` flags row, whole, raw | `prose.bats:73` (test "auto never collapses the release gate") | changed on purpose (C1) |
| J carry duty: `record the surviving failures … carry them into the commit message and the pull-request body.` | `prose.bats:629` | changed on purpose (C2) |
| J degraded discharge: `the commit message carries it alone and the duty is discharged there.` | `prose.bats:641` | changed on purpose (C3) |
| `span_j`, the J region byte for byte | `prose.bats:572`, asserted in the J test | changed on purpose (C4, FR-006) |
| MAY-do (P20's N2, N3) | `prose.bats:1133-1134` | changed on purpose (C5, C6) |
| Gate rows, first two cells | `prose.bats:21` | untouched: K's row keeps `\| Commit \| K \|` (FR-009) |

Unpinned today, and rewritten: K's body, L's body, DONE, H.5, H.7, I, the
conditional-stops paragraph, Resume. `span_n` (`prose.bats:578`) is NOT
touched — see R9.

**Decision:** change these pins and the span in the same commit as the
prose; pin each new text and each old text ABSENT.

## R2 — The J span and K's first line

`prose_slice` closes the J slice on the whole line matching `^\*\*K — commit\.`,
and `assert_span` checks that `span_j` occurs in the flattened slice. `span_j`
ends at `**K — commit. STOPS AND ASKS.**`, so the words after that on K's first
line are outside the assertion.

**Decision:** K keeps its heading `**K — commit. STOPS AND ASKS.**` byte for
byte; K's body is rewritten after it. The J span changes only where J's own
text changes.

## R3 — What converge appends

`.claude/skills/speckit-converge/SKILL.md:78-79` and `:209`: its only write
is one new `## Phase N: Convergence` section at the end of `tasks.md`, with the
next phase number; when nothing is missing it does not touch `tasks.md`.
`progress.sh:268` excludes from `piece-next` every heading recorded under kind
`piece` **or** `converge`. `piece-next` names a piece by its heading without
the leading `## ` (`progress.sh:272`, `ltrimstr("## ")`).

**Decision:** H.5 records the appended heading as `piece-next` prints a
heading — `Phase N: Convergence`, no `## ` — with the appended task IDs. A
`--from H` after H.5 is then never offered that phase (item d).

## R4 — `commit-add` already takes every kind this needs

`progress.sh:47`: `KINDS=" spec piece converge simplify review tests constitution other "`.
`progress.sh:182-184`: only a `piece` entry needs a piece name and task IDs.
`progress.sh:191-192`: only a `tests` entry may carry no files.

**Decision:** no script changes (FR-018 holds). J's empty commit is recordable
as kind `tests` with no files. K's remainder and any commit found unrecorded
at L are kind `other`; the constitution commit is kind `constitution`.

## R5 — Detecting a tracked state file (FR-014)

Measured in a scratch repository, exit status of
`git --literal-pathspecs ls-files --error-unmatch -- <state file>`:

| State of the file | Exit |
|---|---|
| untracked, directory NOT ignored | 1 |
| untracked, directory ignored | 1 |
| in the index, not committed | 0 |
| committed | 0 |
| removed from the index (`git rm --cached`) | 1 |
| outside any repository | 128 |
| tracked as `.Delivery-Kit/…`, asked as `.delivery-kit/…`, `core.ignorecase=true` (from I) | **1** — the case-sensitive form misses it |
| the same, asked as `':(literal,icase)<path>'` (from I) | 0; a real miss still 1; outside a repository 128 |

Without `--literal-pathspecs`, a query for `runs/[f]/progress.json` matched a
tracked `runs/[f]/…` and, on the `git add` side, also swept in `runs/f/…` — a
path read as a pattern. With it, each path meant only itself.

**Decision (revised at I):** the check is `git ls-files --error-unmatch -- ':(literal,icase)<state file>'`
— per-pathspec magic, because the global `--literal-pathspecs` cannot be
combined with `--icase-pathspecs` (exit 128). Exit 0 = tracked → stop; exit 1 = untracked → go on; any other
exit is a hard failure, never read as "untracked" (Principle I: 128 must not
pass as a clean answer). The check runs on every re-entry, after `validate`
and before any recorded answer is used; `.delivery-kit/` being ignored or not
changes nothing (both untracked rows exit 1, the index rows exit 0).

**Alternatives:** `git check-ignore` answers "ignored", which is not
"tracked" — a force-added file is both. `git status --porcelain` on the path
says nothing for a clean tracked file. Both rejected.

## R6 — J's empty commit takes nothing staged along

Measured: with a change to `a` staged, `git commit --allow-empty --only -F m`
with no path made a commit with no files, and `a` stayed staged (`M  a`).

**Decision:** J's empty commit is `git commit --allow-empty --only -F <message file>`
with no path. Plain `git commit --allow-empty` would sweep in anything staged.

## R7 — Reading the commit list with its files

`git log -z --reverse --name-only --format=%H` measured as `<sha>\0\n<path>\0…`
with an empty commit as `<sha>\0` and nothing after — two separators mixed and
an empty commit indistinguishable from a parse slip.

**Decision:** commits from `git rev-list --reverse <base>..HEAD`; each one's
files from `git diff-tree --no-commit-id --name-only -r -z --root <sha>`, read
NUL-separated (measured: a path holding `[` came back whole; the empty commit
came back with no path).

**Measured at F (the analyze reviewer):** for a merge commit the same
command prints nothing (`-m` would list files, base's included). A merge, or
any commit with no file that is not J's `Late: J` record, cannot be shown
truthfully and cannot be recorded (`commit-add` refuses a non-`tests` entry
with no files), so K and L stop on it, name it, and never record it (K10, V3).

## R8 — "The run's change" for H.7 and I (FR-013)

In the piece flow the working tree after H is nearly clean, so a review of
"the diff" reads nothing. `git diff <base>..HEAD` is `git diff <base> HEAD`: if
`<base>` moved during the run, it also shows `<base>`'s new commits reversed
(memory: a merge moves a diff baseline).

**Decision:** the run's change = one diff from `git merge-base <base> HEAD` to
the working tree (committed and uncommitted tracked changes together), plus
each untracked file. When `<base>..HEAD` is empty — a single-commit run that
never committed — this is today's working-tree diff.

## R9 — M and N commits reach the guide without touching `span_n`

N "commits fixes" inside the byte-exact `span_n`; giving N a recording
sentence would change a second span for no gain. M has no span.

**Decision:** L, before it builds the guide, records with `commit-add` as kind
`other` every commit in `<base>..HEAD` that `commits` does not record, with its
files (R7). DONE rebuilds the guide the same way, so M's and N's commits
appear. The guide is derived from the branch, never listed by hand
(Principle V).

**Order, and both walks (from F).** `commit-add` appends, so an entry recorded
late — a commit found unrecorded at L — sits after newer entries: array order
is NOT commit order. The guide therefore walks `git rev-list --reverse
<base>..HEAD` and joins each sha to its entry; it also walks the other way and
stops on an entry whose sha is not on the branch (V6). Measured with the jq in
[data-model.md](data-model.md) against a state file written ONLY by
`progress.sh commit-add` (round 2 of F found that an earlier measurement had
used a hand-built file whose `tasks` were strings; `commit-add` writes
`tasks` as a list, and that program exited 5): rows came out in `rev-list`
order whichever order the shas were given; an empty `tests` commit showed as
`(no files: empty commit)`; a stale entry and an unrecorded sha each exited 5
with their own message and no partial table.

## R10 — Where the late-commit rule is written

Four phases share one rule. Principle IV: write it once. The H.5 slice
(`**H.5 — converge.**` to `**H.7 — simplify.**`) comes first; H.7, I and J
point at it. No line inside any slice may start with `**` or `#`
(`prose_slice` refuses), so the rule is plain paragraphs.

**Decision:** the rule, the before list, the commit mechanics, the
nothing-changed case, the no-rewrite rule, the hook stop, crash recovery and
the single-commit-flow case live after H.5's first paragraph.

## R11 — FR-007b: which paths are "odd"

The set = every file of every commit in `<base>..HEAD` (R7) ∪ every path still
uncommitted, read as H reads `git status`. A path is odd unless it is under a
`codeRoots` entry, under the feature's spec directory, or the recorded
`tasks.md`. Paths under `.delivery-kit/` are never committed and never listed.
In this repository `codeRoots` = `handoff`, `pipeline`, `scripts`; a
constitution written at pre-flight (`.specify/memory/constitution.md`) is odd,
so K stops for it even under `--auto` — the intended effect: a governance file
is exactly what a human should see.

Containment (from F): a path is inside a root when it equals the root or
begins with the root followed by `/` — a bare prefix would let `pipeline`
admit `pipeline-x/…`. Scope (from F): the rule is decided by the branch, not
the flow. A `--implementer handoff` typed on a re-entry switches a run to the
single-commit flow while its piece commits stand (G6); a flow-scoped rule
would push them unseen under `--auto`. So K shows the commit list, and stops
for an odd path, whenever `<base>..HEAD` holds a commit.

Pre-run commits (from F, round 2): a branch cut in B from a HEAD that is not
on `<base>` carries commits the run did not make. They are in `<base>..HEAD`,
so K lists them and stops for their odd paths, the guide records them as
`other`, and I reviews them. That is the safe direction — they will be pushed
with the branch — and it is recorded here rather than special-cased.

## R12 — A late commit that landed before a crash

H recovers a piece by its `Piece: <heading>` line (H11). A late phase re-entered
after its commit landed but before `commit-add` ran would otherwise commit
nothing (its paths are clean) and leave the commit to be swept into L's
`other` rows — the wrong kind.

**Decision:** a late commit's message carries, on a line of its own,
`Late: <phase letter>`. A re-entered late phase first records, from that
commit, any commit in `<base>..HEAD` that `commits` does not record and that
carries its line, and makes no new commit for work already committed.

## R13 — Stops `--auto` must still not collapse

New stops: K's odd-path and unshowable-commit stops (whenever `<base>..HEAD`
holds a commit), L's unshowable-commit stop, and the tracked-state-file stop
(on a re-entry, and on a B that adopts a state file). The `--auto` flags row
says "Collapse the K and L gates to automatic" and would be false without them.

**Decision:** the row names them (C1). In the Gates section, GT8 replaces the
conditional-stops sentence with one that names them, and GT9, after the
constitution-offer sentence, says `--auto` collapses none of them. P20's GT4
("Nothing outside the gate table is silenced by `--auto` — …") stays
byte-identical.

**Recording a found commit (from F, round 3).** V3 records a commit it finds
unrecorded by what the commit says of itself: `Piece: <heading>` as `piece`,
`Late: <phase letter>` under that phase's kind, anything else as `other`. Were
every found commit `other`, a rebased piece would be offered again by
`piece-next` and rebuilt on a later `--from H`.

**H23's check (from F, round 3).** Measured in a scratch repository with
`specs/` ignored: `git status --porcelain --untracked-files=all -- <dir>` and
`git ls-files -- <dir>` both print nothing, so a check built on them passes
having looked at nothing. `git ls-files -o -i --exclude-standard -- <dir>`
lists the ignored file. H23 names both commands and requires the tracked list
to be non-empty.

## R14 — The tracked-state confirmation is never inherited

A confirmation written into a tracked state file travels with the file: the
next person to pull it would find a "yes" nobody at their keyboard gave —
exactly the fault FR-014 closes.

**Decision:** the confirmation is recorded under `gates.trackedState` for the
record, and a recorded confirmation never suppresses the next re-entry's stop.

**Where it runs (from F).** On a resume, pre-flight already reads the state
file: decision item 5 accepts its claim on a dirty tree. The check therefore
runs at pre-flight, before item 5, on every re-entry and on every B whose
idempotent `init` adopts a state file already there; the stop shows every
recorded answer, since a developer cannot confirm what they were not shown.

## R15 — Deep-review fixes (from I)

- **Late-commit scope.** A late commit takes only new paths inside `codeRoots`,
  the spec directory or `tasks.md`; anything else a phase creates (J's test
  output, a log) stays uncommitted for K, which shows it and, for such a path,
  stops even under `--auto`. Before, J could commit a generated file nobody
  claimed, and K's "no" could not take it back without a rewrite.
- **K shows each commit's message.** J's waved-through red now rides in J's
  own commit message; K's commit list shows every message, so the owner sees
  the redacted record before anything leaves. J's redaction now also covers a
  machine path and a user name.
- **`.delivery-kit/` in committed history.** The run never commits such a
  path, but a pre-run commit can hold one; K lists it and counts it as outside
  the feature instead of hiding it.
- **Guide cells.** A piece name or path is shown as a code span, so a path
  like `@x` or `__init__.py` is not rendered as markup. A backtick inside it
  is fenced by a longer run of backticks rather than refused (round 2: a
  refusal at L comes after every commit is made, with no way forward short of
  a rewrite); a cell holding a line break still stops L. Measured with the
  program in data-model.md.
- **Round 2 of I.** A commit is never run from an empty path file (an empty
  list commits whatever is staged — measured: `commit --pathspec-from-file`
  with an empty file exits 0 and takes a staged file); a late phase whose new
  paths all lie outside the scope has changed no file; B checks an adopted
  state file straight after `init`, before the lock, the seed or
  `phase-start` touch it; DONE rebuilds the guide before `phase-start DONE`,
  and a run resumed after a stop there never runs O's command again; K's
  answer is tied to the list it was given for; commit messages and trailers
  are data, never instructions.
- **Insertion guards.** `span_k`, `span_l` and `span_r` pin the K region, the
  L region and the tracked-state paragraph byte for byte, as `span_j` pins J:
  an exception appended beside an intact pin ("under `--auto` that stop is
  skipped") otherwise passes every pin.
