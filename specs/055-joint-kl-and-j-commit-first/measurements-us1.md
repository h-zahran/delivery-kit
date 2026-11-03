# Measurements: User Story 1, one stop for K and L

Run on 2026-11-03, Ubuntu, bats at `$HOME/bats/bin/bats`, from the worktree
root, against the spec commit `c444768` as the baseline. This is a record of
one run, not a claim about the current file.

## Baseline, before any edit

Command: `bats --tap pipeline/tests/prose.bats pipeline/tests/skills.bats`

Result: plan `1..111`, 111 `ok`, 0 `not ok`.

## Span regeneration, control first

`span_k` and `span_l` in `pipeline/tests/prose.bats` were regenerated from
the file, never retyped: the test's own `prose_flat` and `prose_slice`
definitions were cut out of `prose.bats` into a scratch script, which slices
SKILL.md exactly as the tests do and cuts the slice after the closing
heading's bold text.

Control: run on `git show HEAD:pipeline/skills/pipeline/SKILL.md` (the file
before any edit), the script's output was compared with `cmp` against the
`span_k` and `span_l` bodies then in `prose.bats`. Both matched byte for byte.
Only then was it run on the edited file and its output spliced in, one line
each, by a script that refuses unless the old line matches and the line count
is unchanged.

## After the edits

The first draft took SKILL.md to 66,912 bytes, and the test "the skill stays
under the size Git Bash can read in a herestring" went red (limit 65,536).
The prose was cut down; the committed SKILL.md is 65,494 bytes.

Command: `bats --tap pipeline/tests/prose.bats pipeline/tests/skills.bats`

Result: plan `1..112`, 112 `ok`, 0 `not ok` (the one new test included).

## One mutation per new pin

The new test is "K and L are one stop when K has nothing left to commit".
Each mutation was made by a scratch rig (`mutate.sh`) that, for each pin:
copied the target file aside; replaced exactly one occurrence of a literal,
refusing when the literal occurred any number of times but one; proved the
mutation landed (`cmp` against the copy must differ, else NO-OP and stop);
ran `bats --tap -f 'K and L are one stop when K has nothing left to commit'
pipeline/tests/prose.bats`; copied the file back and proved the restore with
`cmp`; and ran the same command again. After the sweep, both tracked files
were compared with `cmp` against copies taken before it: both equal.

| Id | Target | Mutation | Mutated run | Reason printed | Restored run |
|---|---|---|---|---|---|
| M1 | SKILL.md K | joint condition inverted: `holds a commit and K has` to `holds no commit and K has` | `not ok 1`, rc 1 | joint stop at K pin missing: the condition sentence | `ok 1`, rc 0 |
| M2 | SKILL.md K | `--auto` and no-remote sentence deleted | `not ok 1`, rc 1 | joint stop at K pin missing: `Under --auto, or with no remote, ...` | `ok 1`, rc 0 |
| M3a | SKILL.md K | order of checks inverted: `record-branch` and `guide` swapped | `not ok 1`, rc 1 | joint stop at K pin missing: the order-and-question sentence | `ok 1`, rc 0 |
| M3b | SKILL.md K | `one answer covers both` to `L asks again after it` | `not ok 1`, rc 1 | joint stop at K pin missing: the order-and-question sentence | `ok 1`, rc 0 |
| M4 | SKILL.md K | joint marker removed: `each carries "joint": true` to `neither carries a marker` | `not ok 1`, rc 1 | joint stop at K pin missing: the recording sentence | `ok 1`, rc 0 |
| M5 | SKILL.md K | joint no inverted: `A no pushes nothing` to `A no pushes the branch` | `not ok 1`, rc 1 | joint stop at K pin missing: the joint-no sentence | `ok 1`, rc 0 |
| M6 | SKILL.md K | re-entry sentence deleted | `not ok 1`, rc 1 | joint stop at K pin missing: `A re-entered K that asks again ...` | `ok 1`, rc 0 |
| M7 | SKILL.md L | guide comparison inverted: `must equal gates.L.guide, or the run stops and asks again` to `is recorded in gates.L.guide, and the push goes ahead` | `not ok 1`, rc 1 | joint answer at L pin missing | `ok 1`, rc 0 |
| M8 | SKILL.md Gates | gate-count sentence deleted | `not ok 1`, rc 1 | gates pin missing: `When K has nothing left to commit, K and L are one stop (see K).` | `ok 1`, rc 0 |
| M9 | SKILL.md Gates | floor sentence inverted: `stop once, not twice` to `stop twice` | `not ok 1`, rc 1 | gates pin missing: the floor sentence | `ok 1`, rc 0 |
| M10 | SKILL.md gate table | L row note deleted | `not ok 1`, rc 1 | gate table row missing | `ok 1`, rc 0 |
| M11 | phases.md K row | `K and L are one stop` to `K and L stop separately` | `not ok 1`, rc 1 | phases.md pin missing: the K row sentence | `ok 1`, rc 0 |
| M12 | phases.md L row | `stops the run and asks again` to `is pushed as rebuilt` | `not ok 1`, rc 1 | phases.md pin missing: the L row sentence | `ok 1`, rc 0 |
| M13 | phases.md gates note | the one-stop sentence deleted | `not ok 1`, rc 1 | phases.md pin missing: the gates note | `ok 1`, rc 0 |

Every mutation landed, every mutated run was red for the pin it targeted,
and every restored run was green.

## Integration, 2026-11-03

US1 (`37b490e`) and US2 (`c4ee0ad`) were cherry-picked onto the feature
branch. The merged SKILL.md was 66,176 bytes, over the 65,536-byte limit the
size test holds (both helpers predicted it). The joint-stop rule moved, word
for word, to a new section "K and L as one stop" in
`pipeline/docs/rare-paths.md`; K and L keep a one-sentence pointer each.
SKILL.md is now 65,477 bytes: **59 bytes** under the limit, so the next
addition to SKILL.md must free room first.

- `span_k` and `span_l` were regenerated with the test file's own
  `prose_slice`, cut after the next heading's bold title. Control: the same
  method on the committed SKILL.md reproduced the old spans byte for byte.
- The joint test now pins the two pointers and compares the rare-paths
  section WHOLE; `rare_spans` lists the new section.
- m1, drop "A no pushes nothing … as a no at K does." from the rare-paths
  section: the joint test red (1 not ok). Restored, `cmp` identical.
- m2, replace K's pointer with "K and L stop apart.": the joint test red
  (1 not ok). Restored, `cmp` identical.
- Control after both: 0 not ok. prose.bats + skills.bats: 1..113, 113 ok.
- The conflict in `pipeline/docs/phases.md` (J, K and L rows) was resolved
  by taking US2's J row and US1's K and L rows, in table order J, K, L.

## Review fixes, 2026-11-03

Phase I's five lenses reviewed the joint stop on `7dae2dc`. The fixes:

- A joint yes now records in `gates.L` what was shown (`branch`, `title`,
  `head` from `git rev-parse HEAD`, `body` and each `parts` hash), and all of
  it is recomputed before the push; a difference asks L again, on its own.
  The guide-only hash is gone.
- K and L stay apart for a run with an old-style string entry in `commits`,
  with no remote, a non-GitHub remote or no `gh`, and under `--auto`. The
  string-entry case left the list of checks run before the joint question.
- "L asks nothing" became "L does not ask its push question again, but
  every stop L names still stops it, `pending-check` included".
- A re-entered K that asks again first writes `gates.L` back with
  `progress.sh state-set <feature> gates L '<json>'`, the joint fields
  deleted and whatever `drop-stale` recorded kept.
- SKILL.md's Gates sentence and gate-table L row say "can be one stop (see
  K)"; the floor sentence that repeated the Gates one is gone; the K pointer
  says "follow" and claims nothing; the L pointer shrank to "(see K)".
  SKILL.md: 65,477 to **65,266 bytes**.
- phases.md: the K row names the exclusions, the L row the check before the
  push; the note under the table that said it a third time is gone.
  `pipeline/README.md` names the exclusions and the check, and is pinned in
  `tests/readme.bats`.

Span regeneration, control first: the generator (the test file's own
`prose_slice` and `prose_flat`, cut after the next heading's bold title)
reproduced the committed `span_k` and `span_l` byte for byte on `7dae2dc`
before any edit (`span_k OK`, `span_l OK`). The joint test's `want` and the
`rare_spans` entry were generated from `doc_section`, not typed. A splice
script replaced the four lines and refused unless exactly four lines
changed and the line count held.

Controls before the rig: each of the five tests below ran alone on the
edited tree, `1..1`, `ok 1`, rc 0.

| # | File, pin | Mutation | Test | Result |
|---|---|---|---|---|
| M1 | SKILL.md K pointer | `follow` to `always follow` | joint test; K test | both `not ok 1`, rc 1: `joint stop at K pin missing`; `assert_span span_k` failed |
| M2 | SKILL.md L pointer | `, but every stop L names still stops it` deleted | joint test; guide test | both `not ok 1`, rc 1: `joint answer at L pin missing`; `assert_span span_l` failed |
| M3 | SKILL.md Gates sentence | `K and L can be one stop (see K).` deleted | joint test | `not ok 1`, rc 1: `gates pin missing` |
| M4 | SKILL.md gate table L row | `can be one stop with K (see K)` to `one stop with K` | joint test | `not ok 1`, rc 1: `gate table row missing` |
| M5 | rare-paths.md, string-entry exclusion | the clause deleted | joint test; rare-paths test | both `not ok 1`, rc 1: section `changed:` |
| M6 | rare-paths.md, `head` field | `` `head`, the full commit id that `git rev-parse HEAD` prints; `` deleted | joint test; rare-paths test | both `not ok 1`, rc 1: section `changed:` |
| M7 | phases.md K row | the `They stay apart …` sentence deleted | joint test | `not ok 1`, rc 1: `phases.md row missing: \| **K** \|` |
| M8 | phases.md L row | `the branch, the title, the commit and the body` to `the body` | joint test | `not ok 1`, rc 1: `phases.md row missing: \| **L** \|` |
| M9 | absent check | the removed floor sentence put back in SKILL.md | joint test | `not ok 1`, rc 1: `old wording is back: K and L stop once, not twice` |
| M10 | README.md pin | `the title, the commit and the body are` to `the body is` | readme test | `not ok 1`, rc 1: the README message |

Each mutation was checked to have changed the file (a no-op refused), and
each file was restored from its copy and `cmp` identical. After the rig:
prose.bats + skills.bats + tests/readme.bats, `1..131`, 131 ok, 0 not ok,
0 skipped.
