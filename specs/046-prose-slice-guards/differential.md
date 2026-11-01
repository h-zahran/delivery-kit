# Differential and controls: every prose slice is guarded

A record of runs made on 2026-11-01, on Ubuntu (bash 5, mawk 1.3.4, uutils coreutils 0.10.0, bats 1.11.0). Base commit `f72276c`; branch commit `1e4292e` (the last code piece). Every mutation ran in a scratch git worktree, never in the main checkout, and each was proved to have landed and to have been restored.

## 1. Byte identity of every converted haystack (FR-004, SC-003)

Made by a script that reads the removed bare ranges from `git diff f72276c HEAD -- pipeline/tests/prose.bats`, runs each old expression and the new `prose_slice` call, and runs every input the file now feeds `prose_flat` (each document it flattens, both blockquote documents, and every slice it takes) through each old spelling of the flatten idiom and through `prose_flat`. The helpers are read from the file under test, not retyped. The script first reported 16 rows DIFFERENT; the cause was in the script (a redirect placed after the old pipeline fed its last command), and fixing it is what made this table. That miss also shows the comparison can go red.

| Kind | Haystack | Old bytes | New bytes | Result |
|---|---|---|---|---|
| slice | `^\*\*G — implementer gate\.\*\*` → `^\*\*H — implement\.\*\*` in `pipeline/skills/pipeline/SKILL.md` (raw) | 4946 | 4946 | identical |
| slice | `^The script only reports; the decisions are yours` → `^\*\*Base branch:\*\*` in `pipeline/skills/pipeline/SKILL.md` (flat) | 6007 | 6007 | identical |
| slice | `^Project type : ` → `^Will skip ` in `pipeline/skills/pipeline/SKILL.md` (raw) | 836 | 836 | identical |
| slice | `^## Resolving the layers$` → `^## Keys$` in `pipeline/docs/configuration.md` (flat) | 1219 | 1219 | identical |
| slice | `^## The Implementer line$` → `^## The state directory$` in `pipeline/docs/configuration.md` (flat) | 1274 | 1274 | identical |
| slice | `^The script only reports; the decisions are yours` → `^\*\*Base branch:\*\*` in `pipeline/skills/pipeline/SKILL.md` (raw) | 6265 | 6265 | identical |
| slice | `^Will skip ` → `^The script only reports; the decisions are yours` in `pipeline/skills/pipeline/SKILL.md` (flat) | 409 | 409 | identical |
| document | `handoff/skills/handoff/SKILL.md` | 12303 | 12303 | identical |
| document (CR-strip spelling) | `handoff/skills/handoff/SKILL.md` | 12303 | 12303 | identical |
| document | `pipeline/CHANGELOG.md` | 43659 | 43659 | identical |
| document (CR-strip spelling) | `pipeline/CHANGELOG.md` | 43659 | 43659 | identical |
| document | `pipeline/README.md` | 18137 | 18137 | identical |
| document (CR-strip spelling) | `pipeline/README.md` | 18137 | 18137 | identical |
| document | `pipeline/docs/configuration.md` | 24545 | 24545 | identical |
| document (CR-strip spelling) | `pipeline/docs/configuration.md` | 24545 | 24545 | identical |
| document | `pipeline/docs/handoff-package.md` | 2994 | 2994 | identical |
| document (CR-strip spelling) | `pipeline/docs/handoff-package.md` | 2994 | 2994 | identical |
| document | `pipeline/docs/phases.md` | 17059 | 17059 | identical |
| document (CR-strip spelling) | `pipeline/docs/phases.md` | 17059 | 17059 | identical |
| document | `pipeline/skills/pipeline/SKILL.md` | 62741 | 62741 | identical |
| document (CR-strip spelling) | `pipeline/skills/pipeline/SKILL.md` | 62741 | 62741 | identical |
| document | `pipeline/skills/status/SKILL.md` | 5804 | 5804 | identical |
| document (CR-strip spelling) | `pipeline/skills/status/SKILL.md` | 5804 | 5804 | identical |
| blockquote document | `README.md` | 10221 | 10221 | identical |
| blockquote document | `pipeline/README.md` | 18111 | 18111 | identical |
| held slice | '^## Configuration$' → '^## Flags$' | 2602 | 2602 | identical |
| held slice | '^## Flags$' → '^## Pre-flight$' | 1877 | 1877 | identical |
| held slice | '^## Gates$' → '^## Parallel agents$' | 3850 | 3850 | identical |
| held slice | '^## Ground rules$' → '^## Configuration$' | 3807 | 3807 | identical |
| held slice | '^## Parallel agents$' → '^## The rules that never bend$' | 627 | 627 | identical |
| held slice | '^## Pre-flight$' → '^\*\*Read item 11 before item 1\.\*\*' | 2167 | 2167 | identical |
| held slice | '^## Red flags' → '^## When a phase fails$' | 1521 | 1521 | identical |
| held slice | '^## Resume$' → '^## Not in v1$' | 1285 | 1285 | identical |
| held slice | '^## Resume$' → '^Before any recorded answer is used' | 836 | 836 | identical |
| held slice | '^## The rules that never bend$' → '^## Red flags' | 2189 | 2189 | identical |
| held slice | '^## When a phase fails$' → '^## Resume$' | 546 | 546 | identical |
| held slice | '^7[.] [*][*]Lock:[*][*]' → '^9[.] [*][*]Constitution not set' | 998 | 998 | identical |
| held slice | '^Project type : ' → '^Will skip ' | 788 | 788 | identical |
| held slice | '^The script only reports; the decisions are yours' → '^\*\*Base branch:\*\*' | 6007 | 6007 | identical |
| held slice | '^Will skip ' → '^The script only reports; the decisions are yours' | 409 | 409 | identical |
| held slice | '^\*\*B — specify\.\*\*' → '^\*\*C — clarify' | 1355 | 1355 | identical |
| held slice | '^\*\*Base branch:\*\*' → '^\*\*Implementer:\*\*' | 569 | 569 | identical |
| held slice | '^\*\*DONE\.\*\*' → '^## Gates$' | 561 | 561 | identical |
| held slice | '^\*\*F — analyze, auto-fix loop\.\*\*' → '^\*\*F\.5 — test baseline\.\*\*' | 579 | 579 | identical |
| held slice | '^\*\*F\.5 — test baseline\.\*\*' → '^\*\*G — implementer gate\.\*\*' | 864 | 864 | identical |
| held slice | '^\*\*G — implementer gate\.\*\*' → '^The package carries seven parts' | 3733 | 3733 | identical |
| held slice | '^\*\*G — implementer gate\.\*\*' → '^\*\*H — implement\.\*\*' | 4939 | 4939 | identical |
| held slice | '^\*\*G — implementer gate\.\*\*' → '^\*\*H — implement\.\*\*' | 4939 | 4939 | identical |
| held slice | '^\*\*H — implement\.\*\*' → '^\*\*H\.5 — converge\.\*\*' | 4578 | 4578 | identical |
| held slice | '^\*\*H\.5 — converge\.\*\*' → '^\*\*H\.7 — simplify\.\*\*' | 2894 | 2894 | identical |
| held slice | '^\*\*H\.7 — simplify\.\*\*' → '^\*\*I — deep review, one round\.\*\*' | 599 | 599 | identical |
| held slice | '^\*\*I — deep review, one round\.\*\*' → '^\*\*J — analyzer and full suite\.\*\*' | 2252 | 2252 | identical |
| held slice | '^\*\*J — analyzer and full suite\.\*\*' → '^\*\*K — commit\.' | 2723 | 2723 | identical |
| held slice | '^\*\*K — commit\. STOPS AND ASKS\.\*\*' → '^\*\*L — push' | 4489 | 4489 | identical |
| held slice | '^\*\*K — commit\.' → '^\*\*L — push and open a pull request\.' | 4489 | 4489 | identical |
| held slice | '^\*\*L — push and open a pull request\. STOPS AND ASKS\.\*\*' → '^\*\*M — ' | 3046 | 3046 | identical |
| held slice | '^\*\*L — push and open a pull request\.' → '^\*\*M — PR comments' | 3046 | 3046 | identical |
| held slice | '^\*\*M — PR comments' → '^\*\*N — re-verify' | 1614 | 1614 | identical |
| held slice | '^\*\*N — re-verify and update the PR\.\*\*' → '^\*\*N\.5 — runtime check\.\*\*' | 1191 | 1191 | identical |
| held slice | '^\*\*N\.5 — runtime check\.\*\*' → '^\*\*O — release\.' | 1142 | 1142 | identical |
| held slice | '^\*\*O — release\.' → '^\*\*DONE\.\*\*' | 492 | 492 | identical |
| held slice | '^\*\*Seed forms\.\*\*' → '^## The twenty phases$' | 549 | 549 | identical |
| held slice | '^## Resolving the layers$' → '^## Keys$' | 1219 | 1219 | identical |
| held slice | '^## Resolving the layers$' → '^## Keys$' | 1219 | 1219 | identical |
| held slice | '^## The Implementer line$' → '^## The state directory$' | 1274 | 1274 | identical |

65 rows: 7 converted slices from the diff, 58 flatten inputs; 0 different or refused.

The pipe sites that follow an awk section walk (`… | prose_flat`) replace text identical to `prose_flat`'s body, or add a CR strip after input that `tr -d '\r'` already stripped; they need no run.

## 2. Boundary-rename sweep (SC-002)

Each distinct boundary in a `prose_slice` call on a real document (49, derived from the calls, not listed by hand) was broken by prefixing every line matching it with `Z`. The rig proved zero lines still matched before running `pipeline/tests/prose.bats`, then restored the document from a byte copy and compared it. "Messages" counts the `prose_slice` diagnostics in the output.

| Document | Boundary | Result | Tests red | Messages |
|---|---|---|---|---|
| `skills/pipeline/SKILL.md` | `^## Flags$` | rc=1 | 8 red | 3 the slice is EMPTY; 4 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*H — implement\.\*\*` | rc=1 | 7 red | 4 the slice is EMPTY; 3 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^Project type : ` | rc=1 | 2 red | 2 the slice is EMPTY |
| `docs/configuration.md` | `^## Keys$` | rc=1 | 2 red | 2 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*Seed forms\.\*\*` | rc=1 | 1 red | 1 the slice is EMPTY |
| `skills/pipeline/SKILL.md` | `^## Resume$` | rc=1 | 5 red | 4 the slice is EMPTY; 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*N — re-verify and update the PR\.\*\*` | rc=1 | 2 red | 1 the slice is EMPTY; 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^## Red flags` | rc=1 | 2 red | 1 the slice is EMPTY; 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^## Not in v1$` | rc=1 | 3 red | 3 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^## The rules that never bend$` | rc=1 | 1 red | 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*I — deep review, one round\.\*\*` | rc=1 | 2 red | 1 the slice is EMPTY; 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*DONE\.\*\*` | rc=1 | 1 red | 1 the slice is EMPTY |
| `skills/pipeline/SKILL.md` | `^\*\*C — clarify` | rc=1 | 2 red | 2 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*L — push and open a pull request\. STOPS AND ASKS\.\*\*` | rc=1 | 6 red | 4 the slice is EMPTY; 2 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*Read item 11 before item 1\.\*\*` | rc=1 | 3 red | 3 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^Before any recorded answer is used` | rc=1 | 2 red | 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*N — re-verify` | rc=1 | 2 red | 1 the slice is EMPTY; 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^## Pre-flight$` | rc=1 | 6 red | 1 the slice is EMPTY; 5 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^The script only reports; the decisions are yours` | rc=1 | 5 red | 4 the slice is EMPTY; 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^Will skip ` | rc=1 | 3 red | 1 the slice is EMPTY; 2 UNTERMINATED |
| `docs/configuration.md` | `^## The Implementer line$` | rc=1 | 1 red | 1 the slice is EMPTY |
| `skills/pipeline/SKILL.md` | `^## The twenty phases$` | rc=1 | 1 red | 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*J — analyzer and full suite\.\*\*` | rc=1 | 4 red | 2 the slice is EMPTY; 2 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*N\.5 — runtime check\.\*\*` | rc=1 | 3 red | 1 the slice is EMPTY; 2 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^The package carries seven parts` | rc=1 | 2 red | 2 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^## Gates$` | rc=1 | 4 red | 3 the slice is EMPTY; 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^## Configuration$` | rc=1 | 7 red | 4 the slice is EMPTY; 3 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*L — push and open a pull request\.` | rc=1 | 6 red | 4 the slice is EMPTY; 2 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*O — release\.` | rc=1 | 2 red | 1 the slice is EMPTY; 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^## Ground rules$` | rc=1 | 3 red | 3 the slice is EMPTY |
| `skills/pipeline/SKILL.md` | `^\*\*M — ` | rc=1 | 4 red | 1 the slice is EMPTY; 3 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*K — commit\. STOPS AND ASKS\.\*\*` | rc=1 | 4 red | 2 the slice is EMPTY; 2 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^7[.] [*][*]Lock:[*][*]` | rc=1 | 1 red | 1 the slice is EMPTY |
| `skills/pipeline/SKILL.md` | `^\*\*G — implementer gate\.\*\*` | rc=1 | 6 red | 5 the slice is EMPTY; 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*Base branch:\*\*` | rc=1 | 9 red | 4 the slice is EMPTY; 5 UNTERMINATED |
| `docs/configuration.md` | `^## Resolving the layers$` | rc=1 | 2 red | 2 the slice is EMPTY |
| `docs/configuration.md` | `^## The state directory$` | rc=1 | 1 red | 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^## When a phase fails$` | rc=1 | 2 red | 1 the slice is EMPTY; 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*K — commit\.` | rc=1 | 4 red | 2 the slice is EMPTY; 2 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*F\.5 — test baseline\.\*\*` | rc=1 | 2 red | 1 the slice is EMPTY; 1 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*H\.5 — converge\.\*\*` | rc=1 | 5 red | 1 the slice is EMPTY; 4 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^## Parallel agents$` | rc=1 | 3 red | 3 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*H\.7 — simplify\.\*\*` | rc=1 | 2 red | 2 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*M — PR comments` | rc=1 | 4 red | 1 the slice is EMPTY; 3 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*B — specify\.\*\*` | rc=1 | 2 red | 2 the slice is EMPTY |
| `skills/pipeline/SKILL.md` | `^\*\*F — analyze, auto-fix loop\.\*\*` | rc=1 | 1 red | 1 the slice is EMPTY |
| `skills/pipeline/SKILL.md` | `^\*\*Implementer:\*\*` | rc=1 | 4 red | 4 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^\*\*L — push` | rc=1 | 6 red | 4 the slice is EMPTY; 2 UNTERMINATED |
| `skills/pipeline/SKILL.md` | `^9[.] [*][*]Constitution not set` | rc=1 | 1 red | 1 UNTERMINATED |

49 of 49 boundaries turned prose.bats red with a boundary message; none was a no-op.

## 3. Positive controls for the guard tests and the refusing test (FR-009)

Each mutation replaced text that matched exactly once in the worktree copy of `pipeline/tests/prose.bats`, checked the new text was there, ran the file, and checked the EXPECTED test by name went red. "Other reds" are further tests the same mutation broke, which is expected where a guard protects real slices too.

| Mutation | Landed | Expected test | Expected test red | Other reds |
|---|---|---|---|---|
| arity guard | yes | prose_slice refuses a call with too few arguments | RED | 0 |
| form guard | yes | prose_slice refuses a form that is neither raw nor flat | RED | 0 |
| readable guard, -f edge | yes | prose_slice refuses a directory in place of the file, and names it | RED | 0 |
| readable guard, whole | yes | prose_slice refuses a file that does not exist, and names it | RED | 1 |
| empty guard | yes | prose_slice says EMPTY when the opening boundary matches nothing | RED | 0 |
| duplicate-opener guard | yes | prose_slice refuses an opening boundary that matches twice | RED | 0 |
| unterminated guard | yes | prose_slice says UNTERMINATED when the closing boundary is not found | RED | 0 |
| inner-heading guard | yes | prose_slice refuses an undeclared heading-shaped line inside the slice, and prints it | RED | 1 |
| declared line: whole-line edge | yes | a declared inner line is admitted, and admits nothing else | RED | 0 |
| prose_flat CR strip | yes | prose_flat strips CR, joins lines with a space and squeezes runs of spaces | RED | 0 |
| refusing test: inline flatten added | yes | no bare awk range slice and no inline flatten outside the two helpers | RED | 0 |
| refusing test: bare range added | yes | no bare awk range slice and no inline flatten outside the two helpers | RED | 0 |
| refusing test: split flatten added | yes | no bare awk range slice and no inline flatten outside the two helpers | RED | 0 |

13 mutations, 0 not caught or not landed.

## 4. Wall time (SC-006)

`pipeline/tests/prose.bats` at `f72276c` (68 tests) and on this branch (79 tests), seven runs each, alternating, the side going first swapping each round. The machine was under load from other programs (one-minute load average 5 to 13 on 16 cores during these runs; 18.6 just before them), and an earlier three-pair attempt varied from 10.6 s to 30.0 s for the same file, so only the seven-pair medians are used.

| Round | Side | Exit | Seconds | Plan line | Load (1, 5, 15 min) |
|---|---|---|---|---|---|
| 1 | old | 0 | 12.884 | `1..68` | 13.47 17.62 17.29 |
| 1 | new | 0 | 15.882 | `1..79` | 11.59 17.00 17.09 |
| 2 | new | 0 | 13.965 | `1..79` | 10.44 16.48 16.92 |
| 2 | old | 0 | 12.298 | `1..68` | 9.45 16.07 16.78 |
| 3 | old | 0 | 12.184 | `1..68` | 8.51 15.54 16.60 |
| 3 | new | 0 | 15.333 | `1..79` | 7.37 14.94 16.38 |
| 4 | new | 0 | 15.253 | `1..79` | 6.52 14.39 16.18 |
| 4 | old | 0 | 13.097 | `1..68` | 6.81 14.19 16.10 |
| 5 | old | 0 | 12.185 | `1..68` | 5.73 13.59 15.87 |
| 5 | new | 0 | 15.602 | `1..79` | 5.90 13.25 15.72 |
| 6 | new | 0 | 15.546 | `1..79` | 5.63 12.83 15.54 |
| 6 | old | 0 | 13.064 | `1..68` | 5.22 12.38 15.35 |
| 7 | old | 0 | 14.355 | `1..68` | 5.54 12.10 15.21 |
| 7 | new | 0 | 20.336 | `1..79` | 6.72 11.93 15.09 |

Median: old 12.884 s, new 15.546 s, growth 20.7%, within the 25% the spec allows. Part of it is the 11 new tests.

## 5. After the phase I review round (2026-11-01)

The review round (contract, security, tests, bugs and simplify lenses) found
no CRITICAL finding; its HIGH findings were in the guards' reach — the refusing
test matched one spelling only and could pass after a helper body that never
closed, a declared line admitted every copy of itself and never noticed going
stale, a grep error was read as "nothing found", and `prose_flat` accepted an
argument it then ignored. The fixes added 14 tests (79 → 93) and moved the
refusing walk into a helper, `prose_refuse_walk`, so it can be tested on
fixtures. Each new test was given a positive control in a scratch worktree,
the mutated line echoed before the result was believed:

| Mutation | Test that went red |
|---|---|
| `prose_flat` arity `-eq 0` → `-ge 0` | prose_flat refuses an argument, because it reads stdin |
| `-r` half of the readable guard dropped | prose_slice refuses a file it cannot read, and names it |
| declared-line count `= 1` → `-le 1` | prose_slice refuses a declared line the slice does not hold |
| declared-line count `= 1` → `-ge 1` | prose_slice refuses a declared line the slice holds twice |
| declared-line count made case-blind (`grep -icxF`) | prose_slice compares a declared line with its letter case |
| heading shape `#{1,6}` → `#{2,6}` | prose_slice refuses an h1 inside the slice |
| range rule's comma requirement dropped | the refusing walk passes a clean file and says how much it walked |
| range rule's comma → semicolon | the refusing walk names a planted bare range by its line |
| flatten rule `(n\|012)` → `(x\|012)` | the refusing walk names a planted inline flatten by its line |
| range rule narrowed to the old single spelling | the refusing walk catches other spellings of a bare range |
| flatten rule narrowed to the old single spelling | the refusing walk catches other spellings of an inline flatten |
| never-closed-at-definition rule removed | the refusing walk fails on a helper body whose closing brace is indented |
| end-of-file check disabled | the same test, its end-of-file case |
| helper-seen-once check disabled | the refusing walk fails when a helper body is missing |
| walked-zero check disabled | the refusing walk fails on an empty file |
| a flatten planted in a real test body | no bare awk range slice and no inline flatten outside the two helpers |
| the walk's helper list cut to two names | the same test |

Byte identity after the fixes: every distinct `prose_slice` call (42) under the
old and the new helper, raw and flat, plus every converted site — 90
comparisons, 0 different. The one-`tr` `prose_flat` was compared with the old
three-step pipeline on ten documents under uutils and busybox `tr`; BSD `tr` is
left to the macOS CI runner.

Re-run independently with the section 1 script on the fixed file, extended
to compare the new `pf_walk` wrapper, raw and flat, against the bare walk range
it replaced: 66 rows — the 7 converted slices, the 2 `pf_walk` rows (6,265 and
6,007 bytes) and 57 flatten inputs — 0 different. (A first re-run had left the
walk out, because its five sites now call `pf_walk`; the last review pass
caught that, and these two rows are the fix.)

The last review pass (the bugs lens reading only the fixes) found a range
split by a plain newline after its comma, the `$0 ~ …, $0 ~ …` range and a
`tr '\r\n' '  '` flatten slipping past the walk; an empty declared line
passing; the awk status check untested; and the widened heading shape flagging
an indented `# comment` in a fenced shell block — so that widening was
reverted to the original column-0 shape (plus `__`). The fixes, each with a
positive control run in a scratch worktree (prose.bats 93 → 95 tests):

| Mutation | Landed | Expected test | Result |
|---|---|---|---|
| range: newline-after-comma alternative removed | yes | the refusing walk catches other spellings of a bare range | RED |
| range: $0 ~ expression rule removed | yes | the refusing walk catches other spellings of a bare range | RED |
| flatten: first set back to \n alone | yes | the refusing walk catches other spellings of an inline flatten | RED |
| empty declared line check removed | yes | prose_slice refuses an empty declared line | RED |
| awk status check removed | yes | prose_slice says awk failed when a pattern is not a valid ERE | RED |

5 mutations, 0 not caught.

## 6. Wall time and full suite after the review fixes (2026-11-02)

The review fixes took `pipeline/tests/prose.bats` from 79 to 95 tests, so SC-006 was measured again: five pairs, alternating, against `f72276c` (68 tests).

| Round | Side | Exit | Seconds | Plan line / ok | Load (1, 5, 15 min) |
|---|---|---|---|---|---|
| 1 | old | 0 | 19.654 | `1..68/68` | 4.75 6.39 7.13 |
| 1 | new | 0 | 22.046 | `1..95/95` | 4.70 6.23 7.06 |
| 2 | new | 0 | 22.062 | `1..95/95` | 5.35 6.28 7.06 |
| 2 | old | 0 | 17.707 | `1..68/68` | 6.01 6.37 7.07 |
| 3 | old | 0 | 17.890 | `1..68/68` | 7.08 6.58 7.12 |
| 3 | new | 0 | 24.165 | `1..95/95` | 9.16 7.10 7.28 |
| 4 | new | 0 | 24.417 | `1..95/95` | 10.36 7.54 7.42 |
| 4 | old | 0 | 19.566 | `1..68/68` | 9.89 7.62 7.45 |
| 5 | old | 0 | 21.085 | `1..68/68` | 10.62 7.94 7.56 |
| 5 | new | 0 | 24.078 | `1..95/95` | 9.87 7.99 7.59 |

Median: old 19.566 s, new 24.078 s, growth 23.1%, within the 25% the spec allows but close to it; 27 of the file's tests are new.

Phase J, full suite (`testCommand`, four roots): first run `1..897`, 895 ok. One failure was the baseline's known timeout in `tests/gate.bats` (test 22). The other, `pipeline/tests/preflight.bats` "a constitution saved in an unreadable encoding warns and reads as not set", is a race in `pipeline/scripts/preflight.sh` that this change does not touch: its NUL check runs `head -c 4096 | od -An -tx1 | grep -q ' 00'` under `set -o pipefail`, `grep -q` exits on the first match, and the writer can take SIGPIPE, so the check sometimes reads "no NUL". Measured with that exact pipeline: 0 misses in 300 runs on a quiet machine, 30 in 400 under extra CPU load. Second run: `1..897`, 897 ok.
