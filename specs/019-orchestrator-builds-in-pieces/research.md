# Research: the orchestrator builds in pieces

All measurements 2026-09-29, branch `019-orchestrator-builds-in-pieces` off
`main` = `b0b3f1b`, Git Bash on Windows, git 2.54.0.windows.1.

## R1 — Which existing pins does this change touch?

**Measured** by grepping every suite (`tests/`, `handoff/tests/`,
`pipeline/tests/`) for a fragment of each paragraph the seed names.

| Paragraph | Pinned where | What this feature does |
|---|---|---|
| `--auto` flags row (`SKILL.md:119`) | whole row, `prose.bats:66` | changed on purpose (FR-020), pin changed with it |
| G pre-answer sentence (`:396-398`) | whole sentence, `prose.bats:218` | changed on purpose (FR-005), pin changed with it |
| G lead (`:388-390`) | whole sentence, `prose.bats:216` | kept byte-identical; a sentence is added after the paragraph (R3) |
| G slice shape | `prose.bats:81-87`: no line inside G may start with `**` or `#` | the new G paragraph starts with plain text |
| H (`:497-501`) | nothing | rewritten |
| "Up to five stops" / floor (`:611-624`) | nothing | rewritten (FR-019) |
| Gates table (`:637-643`) | `prose.bats:21`, the first two cells of each row | third cell of the Implementer row extended; first two cells unchanged |
| Conditional stops (`:645-649`) | nothing | the pause added beside them |
| Parallel agents (`:653-659`) | nothing | H unit reworded (FR-023) |
| never-bend `git add -A` row (`:672`) | left cell only, `prose.bats:27` | right cell rewritten (FR-021) |
| MAY-do (`:678-683`) | nothing | extended (FR-022) |
| Resume (`:712-724`) | nothing | a piece paragraph added |
| "When a phase fails" (`:700-710`) | **whole-region span**, `prose.bats:587` | **NOT edited.** The hook rule lives in H and points at it |
| Red flags, J, N, seed forms | whole-region spans | not edited |

**Decision:** the hook hard stop (FR-015) is written in H, not in "When a
phase fails", because that region carries a byte-exact span and an insertion
there is exactly what the span exists to catch. H names the section and
follows it.

## R2 — The FR-005 rewrite

Old (pinned at `prose.bats:218`):

> When `implementer` resolves to `claude` or `handoff` (config or flag), G
> records that answer in `gates` and does not stop — the choice was typed on
> purpose.

New:

> When `implementer` resolves to `claude` or `handoff` (config or flag), G
> records that answer in `gates` and does not ask it — the choice was typed
> on purpose. With `claude`, G still stops for the review question below; with
> `handoff`, G does not stop.

**Rationale:** the old sentence's "does not stop" is false for `claude` once
the review question exists. The new one keeps both halves of the old
contract that are still true (recorded, not re-asked) and states the stop
for each answer. The pin is replaced by the two new sentences, whole.

## R3 — The G lead sentence

"STOP AND ASK, unless `implementer` pre-answered it" still describes the
implementer question correctly, and is pinned whole. Left alone it would read
as "G never stops when pre-answered", which SC-004 forbids. **Decision:** keep
the lead byte-identical and add, at the end of that same paragraph, one
sentence: when the implementer answer is `claude`, G then asks the review
question, which nothing pre-answers. The SC-004 grep checks that no sentence
claims G stops *only* when not pre-answered.

## R4 — How H takes a piece's file list (FR-008)

**Decision:** `git status --porcelain=v1 -z --untracked-files=all --no-renames`,
before and after the piece. Measured on this branch: it prints one entry per
file (untracked files inside a new directory listed one by one, not as the
directory), NUL-separated, so a path with a space or a quote is never
re-quoted; ignored paths (`.delivery-kit/`) do not appear at all.
`--no-renames` keeps a moved file as a delete plus an add, so both paths are
named in the commit.

- **before list** = every path in that output when the piece starts.
- **piece paths** = paths in the after output that are not in the before list,
  plus `tasks.md` always. A path in the before list is never swept in, even if
  the piece also changed it — that is FR-008's rule, and the only such path in
  practice is a constitution written at pre-flight, which K commits.

**Alternatives rejected:** `git diff --name-only` (misses untracked files);
porcelain without `-z` (quotes unusual paths, so a path would have to be
unquoted before it could be named to `git add`).

## R5 — Where the before list is saved (clarify answer)

**Decision:** `measurements.pieceBefore = {piece: <heading>, paths: [...]}`,
written whole-file with `jq` and checked with `validate`, as the ground rules
require for keys no subcommand covers. `measurements` is one of the four keys
the ground rules name for exactly this; it is not created by `init`, and
`validate` does not reject unknown keys (P19, measured). It is overwritten at
each piece start. On resume, a piece whose heading equals
`measurements.pieceBefore.piece` takes its before list from there, never from
the tree.

**Alternative rejected:** `gates.H` — `gates` is where answers live, and a
before list is not an answer.

## R6 — Carrying the heading as data (FR-010)

`piece-next` prints the heading on line 1 and the task IDs on line 2
(spec 018). **Decision:** capture the whole output once with command
substitution and split it with parameter expansion — never with `read`, which
keeps a trailing CR on this platform (memory: *read is not command
substitution*):

```
out="$(bash "$PROGRESS" piece-next "$feature")"
piece="${out%%$'\n'*}"
tasks="${out#*$'\n'}"
```

`"$piece"` is then passed, quoted, to `commit-add`. The commit message, which
also names the heading, is written to a file with the file-writing tool and
committed with `git commit -F <file>`, never `-m` with the heading typed into
the command. Real headings hold double quotes (`specs/011-pin-safety-prose/`)
and em dashes and emoji (`specs/017-guard-config-bounds/tasks.md:61`, `:99`).

## R7 — Recognising a committed-but-unrecorded piece (FR-017)

**Decision:** every piece commit's message carries a last line
`Piece: <heading>`, exactly as `piece-next` printed it; the spec commit's
subject is `docs(spec): <feature>`. On entering a piece, H lists the commits
on the branch that `commits` does not record
(`git rev-list <base>..HEAD`, minus recorded shas) and, for each, reads its
message (`git log -1 --format=%B <sha>`) and asks whether one line equals
`Piece: <heading>` as a fixed, whole line (`grep -qxF -- "Piece: $piece"`).
A match is recorded with `commit-add` — sha from that commit, files from
`git diff-tree --no-commit-id --name-only -r --no-renames <sha>`, tasks from
`piece-next`'s second line — and the piece is not rebuilt. The spec commit is
recovered the same way by its subject.

**Alternative rejected:** matching by the `[X]` marks in `tasks.md` — a crash
can leave marks written but not committed, so marks do not prove a commit.

## R8 — A piece already built when the run resumes

A pause answered **stop here**, a hook rejection, or a crash after the build
leaves a built piece uncommitted. **Decision:** a piece is *built* when every
task ID on `piece-next`'s second line is marked `[X]` in `tasks.md`. A built
piece is not rebuilt: in pause mode it is shown again; in commits mode it is
committed. A partly marked piece continues from `last_task`, as H does today.

## R9 — Where H's stops are recorded

**Decision:** pause answers and a hook failure go under `gates.H` — a pause
is a stop the developer chose, and "Record every gate's answer in the state
file's `gates` key" already covers conditional stops. The failure entry names
the piece and carries the hook's output, redacted as J's carry is (the fact
and its location, never a credential's value).

## R10 — The owner's edits during a pause (FR-013)

**Decision:** when the pause is shown, H records `git hash-object` of every
listed path (or `deleted`). On **go on**, a path is *edited by the owner* when
it is new to the list (and not in the before list), or its hash changed. Those
paths join the commit and are named in its message under
`Edited by the owner during the pause:`.

## R11 — The dry read (SC-003)

Measured now, with the repository's `progress.sh piece-next`, against a scratch
state file whose `artifacts.tasks` is `specs/017-guard-config-bounds/tasks.md`
— to be re-measured and saved at implementation. That file has six
`## Phase <N>:` headings before `## Dependencies`, of which five have tasks
(Phase 2 says "None." and `piece-next` skips it — measured at F round 2), a
seventh appended at H.5, and non-piece headings (`## Format`, `## ⚠️ Four rules`,
`## Dependencies`, `## Parallel opportunities`, `## Implementation strategy`).
Which pieces would change only `tasks.md` is read from each task's text: a
task that names no file to edit, and a ruled non-change (Phase 4 is headed
"a RULED NON-CHANGE"), changes nothing but its marks.

**Corrected by the measurement (T025, 2026-09-29):** the prediction above
was wrong for Phase 4. Its heading rules the HOOK unchanged, but T013 and T014
write the ruling into `specs/015-guard-jq-spawn-two/tasks.md`, and commit
`5ff33c6` changes that file. Only Phase 1 would change nothing tracked but
`tasks.md`. See `dry-read-017.md`; the prediction is kept here as written.

## R12 — Test shape

**Decision:** the new pins search SLICES with the suite's own `prose_slice`
(flattened), never the whole file: G for the review question, H for the piece
rules, `## Gates` to `## Parallel agents` for the floor, the never-bend section
for the row reason and MAY-do, and `## Resume` to `## Not in v1` for resume.
Whole sentences, per the suite's recorded reasoning (a fragment pin leaves the
words between its fragments free). Each new pin is proven by an INVERTED
mutant in a worktree (memory: *a mutation rig belongs in a worktree*), the
mutated line echoed before its red is believed, the rig exiting non-zero on a
mutant that changed nothing.

A whole-region span for H was considered and not added: the seed does not ask
for it, and Phase 21 rewrites H's neighbours; P21 can add it once H settles.

## R13 — Decisions taken at F (analysis, 2026-09-29)

An independent analysis of spec, plan and tasks found 0 critical, 5 high,
12 medium and 6 low findings. The decisions it forced:

- **A piece is built by a scoped implement call** (contract H3). Invoked
  unscoped, the implement command builds every phase at once and the loop
  collapses into one piece.
- **A legacy run is recognised at G, not only at H** (contract G7). A state
  file that lists G as completed without `gates.G.reviewMode` is never asked
  the review question on re-entry: ruling 24 says such a run "is never
  migrated mid-run". A run that crashed inside G (G not completed) is asked.
  This also covers a run parked on the handoff path and resumed with
  `--implementer claude`: it keeps the single-commit flow, and H2 names both
  causes rather than claiming an older pipeline.
- **Stage and commit by pathspec** (contract H8): `git add -- <paths>` then
  `git commit -F <message file> -- <paths>`, so nothing else already staged
  rides along. `git commit -- <path>` alone refuses an untracked path, hence
  the add first.
- **The flow is chosen from implementer AND review answer** (contract H1), so
  a claude→handoff flip never makes piece commits on the handoff path.
- **Every other sentence the change falsifies is rewritten** (FR-019
  extended): pre-flight item 9, the `implementer`, `--implementer` and
  `commitStyle` rows, the floor's tail, the paragraph after it, the
  Implementer row, and MAY-do's closing sentence. Each old wording is pinned
  ABSENT with a positive control.
- **Pause answers go under `gates.H.pauses`**, and the generic never-re-ask
  rule does not stop a built, uncommitted piece from being shown again
  (contract H21).
- **The mutation rig matches with whitespace normalised**, because contract
  sentences wrap freely in the file (tasks T003).

## R14 — H.7 (simplify), 2026-09-30

Four cleanup reviews (reuse, simplification, efficiency, altitude) ran over
the diff. **Applied:** the pin loop pasted once per slice became three helpers
in `prose.bats` (`pins_in`, `rows_in`, `absent_in`) that match with a bash
pattern instead of one `grep` per pin; the two new G slices go through
`prose_slice`, which also guards the close; the walk guard is a builtin; the
paragraphs rewrapped for a one-clause change were restored to their original
lines around the change (the `SKILL.md` diff fell from 198/83 to 157/39
lines); an over-long pause line was rewrapped; and the "Up to five" paragraph
lost a closing sentence that said again what C2, GT1 and GT2 say.

**Skipped, for a later phase:**

- **Pinned duplicates** (G1 and C2b against G2–G4; H2 against H1 and G7; H11's
  "never rebuild it" against H12, H19 and R1; H20 against the kept "same
  phase" sentence and P1; N3's tail against N2). Each is a contract sentence,
  pinned and mutation-proven; removing one is a contract change. Phase 22's
  truth-pass is the place to decide which copy each section keeps.
- **Piece mechanics belong in `progress.sh`** (the before list, the file-list
  difference, "built", the `Piece:` scan, one `piece-commit` that stages,
  commits and records). `pipeline/scripts/` is out of this phase's scope; the
  prose would then say what happens, not how.
- **The `Piece:` scan runs before every piece** as written (H11); scope it to
  the first piece after a re-entry, bounded to `<base>..HEAD`. A contract
  sentence; Phase 21 touches the same recovery rule for its late commits.
- **`prose_slice` could take a fifth argument** listing permitted inner lines,
  so the pre-flight walk (three callers) could use it; that changes a shared,
  heavily guarded helper.
- **The H slice is computed four times** (about 0.5 s each on Windows); a
  `setup_file` or merged tests would cut it, at the cost of test names that
  map one to one to the user stories.

## R15 — Deep review (I), 2026-09-30

Three independent reviewers (contract, security, tests). Contract: COMPLIANT,
one Important. Security: no Critical, three Important. Tests: no Critical,
three Important, 10 of 12 novel mutants MISSED. **Applied:**

- **Literal pathspecs from a NUL file** (H8). git reads a named path as a
  glob and honours `:` magic: `git commit -- 'src/[ab].js'` also committed
  `src/a.js`, and a file named `*` staged a directory (measured by the
  security reviewer). `git --literal-pathspecs add|commit
  --pathspec-from-file=<f> --pathspec-file-nul` was probed in a scratch
  repository: only the listed paths were committed (a glob-shaped name and
  a deletion among them), an unrelated staged file stayed out, and no path
  is typed into a command.
- **How to read the `-z` status** (H7b): `$( )` drops NUL bytes and fuses
  the paths; read records NUL-separated (for example `mapfile -d ''`), take
  the path after the three-character prefix, refuse a CR or LF in a path.
- **Recovery bounded to `<base>..HEAD`, whole-line** (H4b, H11): headings
  like `Phase 1: Setup` head ten of this repository's tasks files, so an
  unbounded scan would find another feature's merged `Piece:` line and skip
  building the piece.
- **The heading recipe survives tool-call boundaries** (H10): shell state
  does not persist between calls, so the commit's call re-runs `piece-next`.
- **Redaction named** (H17); **what commits mode does after a rejection**
  and clearing the failure entry (H19); **the pause records what it
  showed** (H21); **a changed list is shown again** (H15b); the flag row
  conditional on `claude` (CF2); G can have nothing to ask on the handoff
  path ("Up to five"); GT2b no longer reads as a closed list.
- **Tests:** the single-commit flow's definition pinned (H0); P1, N2 and PF1
  extended through their punctuation; four more ABSENT strings (the old C2
  sentence and three FR-019 rewrites); the new G pins close before the
  handoff package; rows pinned in their own table's section and C1 whole-
  line; the helpers refuse to pass having checked nothing.

**Recorded, not fixed** (spec Edge Cases, for Phase 21): the consent gap in
commits mode (a release blocker for 1.3.0), `--from H` after H.5, a tracked
state file, and an already-committed spec directory. **Known open**
mutation classes (stated in the suite's comment): a reversal appended after
a pin that ends in a full stop, and an old wording restored in another
letter case.
