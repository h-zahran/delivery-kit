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
