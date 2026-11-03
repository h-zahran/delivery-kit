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
