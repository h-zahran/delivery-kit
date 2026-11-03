# Measurements: User Story 2 — J commits before its last suite run

**Date**: 2026-11-03

**Scope**: FR-008 to FR-011, SC-001, and the US2 half of SC-002. Every
number below was measured in this worktree; nothing is estimated.

## 1. What the script did before the change

The five new tests in `pipeline/tests/progress-git.bats` were written first
and run against the unchanged `progress.sh` (spec commit `c444768`):

| Test | Before | What it showed |
|---|---|---|
| J's two late commits in one run are each recorded as kind tests with their own files | ok | A second ordinary `late-commit J` already commits and records a second `tests` entry with only its own files; a second `snapshot late J` prints "the saved list stands". Committed paths are clean, so they drop out of `git status` and are never picked up again. |
| J's next late commit holds a path put back to the content it had before J | **not ok** | A path dirty before J, changed and committed by J's first late commit, then put back to its pre-J content: it hashes as J's starting list saved it, so the second `late-commit` said "J changed no file" and left it uncommitted under J's last suite run. |
| late-commit J --record after J's late commits makes the record once, and a second --record makes none | **not ok** | `--record` took J's ordinary fix commit for the record ("J's record is already made and recorded as <fix>"), so a red waved through after J's last commit never reached a commit. |
| late-commit J --record first records J's unrecorded commits, then makes or finds the record | **not ok** | With an unrecorded J fix commit on the branch, `recover_late` recorded it and `--record` returned its id as if it were the record. |
| record-branch, commit-list and guide read a branch holding two J late commits and J's record | ok | All three already accept several `Late: J` commits; no change was needed there. |

## 2. Script rules changed

- `late_save` (new function): the `snapshot late` save, moved out of
  `cmd_snapshot` unchanged so a second caller uses the same code.
- `cmd_late_commit`, ordinary path: after a J late commit, the list is
  saved afresh from the tree that commit left, BEFORE the commit is
  recorded. J's next late commit therefore holds what changed since its
  last one; a second `snapshot late J` keeps that list and needs no
  `--fresh`. Other late phases are unchanged.
- `cmd_late_commit`, `--record` path: every unrecorded `Late: J` commit is
  recorded first (no early return); the record is the `Late: J` commit
  that touches no file, and J late commits with files are passed over. A
  recorded record prints its id and makes nothing; the "J changed files"
  refusal for an uncommitted change stays, measured against the list J's
  last late commit saved.
- `recover_late`: its `commit-add` now ends in `|| die`. Every caller runs
  it in an `if` or `while` condition, where `set -e` is inert, so a failed
  record was reported as made; the new `while` loop on the `--record` path
  would not have ended.

## 3. Script mutations

Rig: each mutant is a copy of `pipeline/scripts/` with exactly one
replacement (refused unless the old text is found once and the result
differs), checked with `bash -n`, and run through
`PROGRESS_SH_UNDER_TEST`. The unmutated copy ran first as the control:
`1..5`, 5 ok.

| Mutant | Mutated line(s) | Test | Result |
|---|---|---|---|
| m1 | after the recover step: `if [ "$flag" != --record ] && jq -e --arg k "$kind" 'any(.commits[]?; type == "object" and .kind == $k)' "$sf" >/dev/null; then warn "MUTANT: $phase committed once already"; return 0; fi` | J's two late commits in one run | not ok (`[ "$c2" = "$(git rev-parse HEAD)" ]`) |
| m2 | `if false; then` in place of `if [ "$phase" = J ]; then` before `( late_save '' )` | J's next late commit holds a path put back | not ok (`[ "$(cat "$OUT")" = "$(git rev-parse HEAD)" ]`: "J changed no file") |
| m3 | `: MUTANT any Late J commit is the record` in place of `[ "${#CF[@]}" -eq 0 ] \|\| continue` | --record after J's late commits | not ok (the refusal: exit 0, "J's record is already made and recorded as <fix commit>") |
| m4 | `if recover_late; then return 0; fi` in place of `while recover_late > /dev/null; do :; done` | --record first records J's unrecorded commits | not ok (`[ "$rec" != "$fix" ]`) |
| m5a | record-branch: `if [ "$late" = J ] && jq -e 'any(.commits[]?; type == "object" and .kind == "tests")' "$sf" >/dev/null; then die "MUTANT: …"; fi` | record-branch, commit-list and guide | not ok (`runs record-branch`) |
| m5b | commit-list: `if has_line "$msg" 'Late: J'; then JL=$(( ${JL:-0} + 1 )); [ "$JL" -le 1 ] \|\| die "MUTANT: …"; fi` | record-branch, commit-list and guide | not ok (`runs commit-list`) |
| m5c | guide: `[$rows \| unique_by(.e.kind)[] \| .e as $e` | record-branch, commit-list and guide | not ok (the three `tests` rows) |

After the change, all 7 mutants red and the control green. The 26 tests
matching late-commit, snapshot late, --record and record-branch were green
on the changed script.

## 4. Prose pins

`span_j` and `span_n` in `pipeline/tests/prose.bats` were regenerated, not
retyped: `prose_flat` and `prose_slice` were extracted from `prose.bats`
itself and run over SKILL.md, and the span cut after the closing heading's
bold text. Control: the same extraction run on the committed SKILL.md
reproduced the committed `span_j` (2,665 characters) and `span_n` (1,148)
byte for byte. New lengths: `span_j` 3,123, `span_n` 1,306.

Pins updated: the H.5 "one commit of their own" pin, the `snapshot` pin
(now "…and then it stands; each J late commit saves it afresh."), the
re-entry pin ("that commit is made"), the J record pin ("J changed no file
since its last late commit"), and the phases.md `files` bullet. Pins
added: the record's exactly-once sentence, a new test "J commits first,
then runs its last full suite on that commit, so N can cite it" with three
J pins and one N pin, and the phases.md sentence that N can cite J's run
under `commit` too.

Rig: each mutant is applied in place to the worktree's document (prose.bats
has no under-test variable), the pin's test and the region's span test run,
and the document is restored from a byte copy and proved identical with
`cmp`. Control: the six affected tests, `1..6`, 6 ok.

| Mutant | Mutation | Pin test | Span test |
|---|---|---|---|
| p1 | "J commits first, then runs its last full suite on that commit" turned into "J runs its last full suite, then commits" | not ok: pin missing | phase J span: not ok |
| p2 | "J writes nothing after its last full-suite run but the record commit below, so N can cite that run." deleted | not ok: pin missing | phase J span: not ok |
| p3 | "fixed, committed and run again … one late commit (see H.5) per fixing iteration" turned into "fixed and run again … one late commit (see H.5), once, when its loop ends" | not ok: pin missing | phase J span: not ok |
| p4 | N's "By the same lookup, N cites J's last full-suite run …" paragraph deleted | not ok: N pin missing | phase N span: not ok |
| p5 | "and refuses an uncommitted change" turned into "or makes a second one" | J's carry: not ok | phase J span: not ok |
| p6 | H.5 "and J one per fixing iteration" turned into "and J once, when its loop ends" | late phases: not ok | (no span over H.5) |
| p7 | H.5 "; each J late commit saves it afresh" deleted | late phases: not ok | (no span over H.5) |
| p8 | phases.md "J commits before its last full-suite run, so N can cite that run under `commit` too when nothing came after it." deleted | suite reuse rules: not ok | — |

Every document was restored byte for byte after its mutant.

## 5. SKILL.md size

`prose.bats` holds SKILL.md under 65,536 bytes (Git Bash's herestring
limit). The first draft of this prose reached 65,967 bytes and that test
went red; the wording was cut to 64,948 bytes (from 64,266 at `c444768`,
+682). The helper changing K and L in parallel shares the remaining 588
bytes.

## Review fixes, 2026-11-03

Scope: the review of J commit-first and J's record commit, five lenses,
on `7dae2dc`. Every number below was measured in this worktree.

### Script rules changed (`pipeline/scripts/progress.sh`)

| Line | Before | After |
|---|---|---|
| 1199-1200 (`recover_piece`) | `( cmd_commit_add … )` alone | `… \|\| die "commit <c> carries 'Piece: <heading>' but could not be recorded …"`: the caller runs it inside `if`, where `set -e` is inert |
| 1212-1235 (`recover_late`) | records the first unrecorded commit carrying `Late: <phase>`, prints it, returns | for J, records EVERY such commit and prints the last id; any other phase still stops at the first |
| 1310-1332 (`late_paths`) | a path whose hash matches the saved list is skipped | for J, a path any recorded `tests` entry lists is never skipped for the saved list, read from `commits` |
| 1555-1563 (`late-commit`, recovery) | `--record`: `while recover_late; do :; done`; others: `if recover_late; then return 0; fi` | `recover_late` writes to a file, not `$( )`, so its `die` ends the script; non-J prints the id and returns; J goes on |
| 1567-1577 (`--record` search) | a `Late: J` commit with files: `continue`; the empty one, if recorded: print; else `die "… exactly once"` | newest first: the first `Late: J` commit, if empty, is the record (printed); if it has files, `break` and a new record is made. The `die` and the recorded check went: after the recovery every such commit is recorded. The 8-line history comment is now 2 lines of rule |
| 1582 (`--record` refusal) | `J changed files: the record rides in J's own late commit — run without --record` | `J changed files: commit them with late-commit <feature> J <message file> and run the full suite on that commit first — the record is J's empty commit after that run` |
| 1595-1598, 1611-1612 (`late-commit`, J) | — | J with recovered commits and nothing left (or no J list saved) prints the last recovered id |
| removed after `commit_named` | `if [ "$phase" = J ]; then ( late_save '' ) \|\| die …; fi` | gone |
| 1142, 438 (`state_write`, `cmd_commit_add`) | `mv "$tmp" "$f"` | `mv … \|\| { rm -f "$tmp"; die "could not replace …"; }` |

`late_save` is gone and its body is back in `cmd_snapshot`: the function
is byte-identical to its text before 055 (`diff` of the two function
bodies, `d56cc49^` against this tree: no difference). The re-save
after each J commit existed only so a put-back path was not skipped; the
`late_paths` rule above does that from `commits`, which `recover_late`
fills before `late_paths` runs, so it holds after a crash between the
commit and its record. The re-save was itself the crash window (it ran
between the commit and the record), and with one caller left a function
was no longer needed. A second `snapshot late J` still prints "the saved
list stands": the list saved at J's start names J.

`shellcheck --norc -x pipeline/scripts/progress.sh`: clean.

### Script tests and mutations

Rig: as in section 3, each mutant a copy of `pipeline/scripts/` with one
replacement (refused unless the old text is found once and the result
differs; the mutated line echoed), `bash -n`, run through
`PROGRESS_SH_UNDER_TEST` with `-f 'J|--record|recovered commit|put
back|late-commit'`. Control on the unmutated copy: `1..27`, 27 ok.

New tests in `pipeline/tests/progress-git.bats`:

- T1 "late-commit J --record makes one record per waved-through red: a J
  late commit after a record needs a new one" (R1; --record again prints
  R1; a J fix; --record makes R2; --record again prints R2).
- T2 "a J late commit a crash left unrecorded still lets J commit a path
  put back to its pre-J content".
- T3 "one late-commit J records every unrecorded J late commit, then
  commits what is left" (also: `snapshot late J` records both and prints
  the last; with nothing left, `late-commit J` prints the last).
- T4 "a recovered commit that cannot be recorded stops the run, for a late
  phase and for a piece" (an empty `Late: I` commit, then `late-commit I`;
  an empty `Piece: Phase 1: Setup` commit, then `snapshot piece`).

Changed: "late-commit J --record is refused when J changed files: they are
committed and run first" (was "…: the record rides in J's own commit"; now
expects the new message); "J's next late commit holds a path put back…"
(its last assertion now proves the saved list is still J's starting list,
the file in it with its pre-J hash; its comment names the new mutation);
the comments of "J's two late commits…" and "--record first records…".

| Mutant | Mutated line | Red tests |
|---|---|---|
| m1 | `[ "${#CF[@]}" -eq 0 ] \|\| continue` | T1 (`[ "$r2" = "$(git rev-parse HEAD)" ]`: R1 printed) |
| m2 | `mine=''` | "J's next late commit holds a path put back…", T2 |
| m3 | `break` in place of `[ "$phase" = J ] \|\| break` | T3, "--record first records J's unrecorded commits…" |
| m4 | `if true; then printf '%s\n' "$rec"; return 0; fi` | T2, T3, "--record first records…" |
| m5a | recover_late's `( cmd_commit_add … )` without `\|\| die` | T4 (the `Late: I` refusal) |
| m5b | recover_piece's `( cmd_commit_add … )` without `\|\| die` | T4 (the `Piece:` refusal) |
| m6 | `: MUTANT no refusal` in place of the `--record` refusal | "--record is refused when J changed files…", "--record after J's late commits…" |

All seven red, the control green. The `mv` guards have no test: a `mv`
that fails on a temporary file in the state directory is not reachable
without stubbing `mv`.

### Prose and docs

| File | Change |
|---|---|
| SKILL.md, H.5 | "; each J late commit saves it afresh" removed (no longer true); "The phase ends with `progress.sh late-commit …`" became "The phase runs …" (J ends with its last suite run); the paths rule gained "(for J, or that a recorded J late commit touched)" |
| SKILL.md, J | "…made exactly once: `--record` skips J's late commits with files, prints the id of an empty `Late: J` commit already made, and refuses an uncommitted change." cut to "…made exactly once." |
| SKILL.md, K | the single-commit-flow record sentence: "…carried and K has nothing to commit, K makes the empty record commit J describes, with `--record`, after the answer." (no "no commit carries `Late: J` yet" test; `--record`'s rule decides) |
| phases.md, J row | "(or into the late commit for a change J has not yet committed; " removed |
| README.md, `tests` row | "J changed nothing" became "J changed nothing since its last late commit" |
| suite-cache.bats | the commit the comment says K makes is named 'K commit' (the one at line 523 stays) |
| spec.md, US2 scenario 4 | "(J's empty record commit, or riding in a J commit)" became ": J's empty record commit, never a commit with files, which would follow J's last suite run" |

SKILL.md: 65,477 bytes before, 65,257 after (-220). `prose.bats`: 101
tests, 101 ok.

### Spans and pins

Method control: `prose_flat` and `prose_slice` extracted from
`prose.bats` itself, run over the unchanged SKILL.md, cut after the
closing heading's bold text, reproduced the committed `span_j` (3,141
bytes), `span_n` (1,314) and `span_k` (4,651) byte for byte. After the
edits: `span_j` 3,003 bytes, `span_k` 4,560, regenerated the same way;
`span_n` unchanged (N was not touched); a new `span_h5`, 2,924 bytes, over
"**H.5 — converge.**" to "**H.7 — simplify.**", with an `assert_span` in
"late phases commit their own work". `span_k` was regenerated from this
branch's K text: the K and L helper's own regeneration supersedes it on
merge.

Pins changed: H.5's `snapshot` pin (now ends "…and then it stands."),
H.5's `late-commit` pin (now "The phase runs…", with the J clause), J's
record pin ("…made exactly once. J is the last full-suite check"), K's
single-commit record pin. Pins added in "phases.md states the suite reuse
rules…": the reuse paragraph's "and N citing J's last full-suite run, made
on the commit J leaves, …", the J row's record and commit-first sentences,
and configuration.md's "J commits before its last full-suite run, so N can
cite that run when nothing came after it, but N cannot cite J's run once K
commits."

Rig: each document mutated in place, the test run, the document restored
from a byte copy and proved identical with `cmp` (all 9 restored). Control:
the five tests, `1..5`, 5 ok.

| Mutant | Document | Mutation | Result |
|---|---|---|---|
| p1 | SKILL.md | "; each J late commit saves it afresh" put back | late phases: not ok (pin missing) |
| p2 | SKILL.md | "(for J, or that a recorded J late commit touched)" removed | late phases: not ok (pin missing) |
| p3 | SKILL.md | "J commits once, when its loop ends." inserted between two pinned H.5 sentences | late phases: not ok (`span_h5` only) |
| p4 | SKILL.md | the cut `--record` clause put back | phase J span: not ok; J's carry: not ok (pin missing) |
| p5 | SKILL.md | K's old "no commit … carries `Late: J` yet" sentence put back | phase K: not ok (pin missing) |
| p6 | phases.md | the reuse paragraph put back to its pre-055 text | not ok |
| p7 | configuration.md | the suiteReuse clause put back to its pre-055 text | not ok |
| p8 | phases.md | the J row's commit-first sentence put back to "commits what it changed." | not ok |
| p9 | phases.md | the J row's "(or into the late commit for a change J has not yet committed; " put back | not ok |
