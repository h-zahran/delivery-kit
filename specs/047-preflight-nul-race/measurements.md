# Measurements: the constitution NUL check answers the same way under any load

A record of runs on 2026-11-02, on Ubuntu (bash 5, uutils coreutils 0.10.0,
mawk 1.3.4, bats 1.11.0). "Old" is a scratch worktree at `e255029` (before this
feature) with this feature's `preflight.bats` copied in; "new" is a scratch
worktree at `a90a9dd` (the release piece). Every mutation ran in a scratch
worktree, never the main checkout, and was shown to have landed.

## SC-001: the deterministic test

The test "a NUL in the constitution is found even when the reader stops at its
first match" puts a fake `od` first on `PATH`: it drains its input, prints
` ff fe 23 00`, then about 1 MB of non-NUL lines.

| Side | Runs | Passed |
|---|---|---|
| old | 10 | 0 |
| new | 10 | 10 |

Its first run, on the unchanged script, failed with no `NUL bytes` warning: the
old check had taken the "no NUL" branch.

## SC-002: the load reproduction

The constitution-nul fixture, 400 runs of each check, with eight busy loops
running:

| Check | Wrong answers |
|---|---|
| old: `head -c 4096 | od -An -tx1 | grep -q ' 00'` under `pipefail` | 33 of 400 |
| new: capture `od`'s output, then `case … *' 00'*` | 0 of 400 |

(The spec's context recorded 30 of 400 for the old check on an earlier run.)

## SC-003: every constitution fixture, old script against new

`preflight.sh --dir <fixture> --base-branch main`, stdout and stderr together,
the checkout path masked:

| Fixture | Exit (old/new) | Bytes (old/new) | Result |
|---|---|---|---|
| constitution-bom | 0/0 | 712/712 | identical |
| constitution-nul | 0/0 | 792/792 | identical |
| constitution-set | 0/0 | 702/702 | identical |
| constitution-unclosed | 0/0 | 711/711 | identical |
| constitution-unset | 0/0 | 703/703 | identical |

## Positive controls (FR-003, FR-004, SC-004)

| Mutation | Landed | Expected red |
|---|---|---|
| the old NUL-check line put back in `pipeline/scripts/preflight.sh` | yes (1 match) | "no shipped script that sets pipefail pipes into grep -q" — red, naming `pipeline/scripts/preflight.sh:322` |
| the walk's `-q` rule narrowed to a bare `-q` (flag groups no longer match) | yes | "the walk names a planted pipe into grep -q, -qE or --quiet by its line" — red |
| the walk's zero-file check removed | yes | "the walk fails when it walked no file" — red |

The new worktree was restored and `git diff --quiet` confirmed it clean.

## Full suite at the baseline (F.5)

`1..897`, 897 ok, at `e255029` with the spec folder untracked.

## After the phase I review round (2026-11-02)

The review round (contract, security, tests, bugs and simplify lenses) found
no CRITICAL finding. Its one HIGH: the first fix cleared the capture with
`|| hex=''` when the pipeline failed late, throwing away a NUL already seen.
It is now `|| true`. The other fixes widened the walk and hardened the tests.
Every mutation below ran in a scratch worktree, its changed line printed
before the result was read.

`pipeline/tests/preflight.bats` (now 102 tests):

| Mutation | Result |
|---|---|
| `\|\| true` removed | "a failed read of the constitution's head still reaches the parse and exits 0" red; "a NUL captured before the reading pipeline fails still reads as not set" red |
| `\|\| hex=''` (the reviewed first fix) | "a NUL captured before …" red |
| the old `head … \| od -An -tx1 \| grep -q ' 00'` line | the fake-`od` test red 5 of 5, and 5 of 5 with SIGPIPE ignored (the fake `od` now ends in `yes … \| head -n 4000`, about 196 KB, and fails on a write error either way) |
| the fixed code | the three tests green, 5 of 5, with and without SIGPIPE ignored |

Pre-flight output on the five constitution fixtures, the reviewed commit against
the fixed script: identical on all five.

`tests/pipefail.bats` (now 12 tests). The walk now joins a pipe continued on the
next line, sees a quiet grep behind `VAR=value`, `command`, `env`, a backslash
or quotes, and `|&`, `egrep`, `fgrep`, `--silent` and digit flag groups; it
skips `||`, whole-line comments, and a `-q` that belongs to a later command;
it follows libraries a walked script sources (it now walks six files,
`hidden-chars.sh` among them); it prints every path it walked, and the real
test asserts `pipeline/scripts/preflight.sh` and
`pipeline/scripts/hidden-chars.sh` are among them; a file it cannot read, or a
failed awk, fails it.

| Mutation | Test red |
|---|---|
| the old bug line put back in `preflight.sh` | the real-repository walk, naming that line in `pipeline/scripts/preflight.sh` |
| `printf x \| grep -q x` planted in `hidden-chars.sh` | the real-repository walk, naming `pipeline/scripts/hidden-chars.sh:2` |
| backslash joining dropped; trailing-pipe joining dropped | the continued-pipe test (each) |
| the `VAR=value`/`command`/`env` allowance dropped; the backslash/quote allowance dropped | the prefix test (each) |
| the sourced-file walk dropped; one pass instead of repeating | the real walk and the library tests |
| the walk no longer printing walked paths; `pipeline/` left out of the listing | the real walk |
| `\|\|` counted as a pipe; comments scanned; the flag scan not stopping at `;`/`&&` | the false-positive test |
| egrep/fgrep, `--silent`, digit flag groups, `\|&` dropped (each) | the other-spellings test |
| grep status 2 skipped; awk status ignored | the unreadable-file test; the awk-failure test |

Known limits, recorded rather than closed: a trailing comment holding
`| grep -q` is still scanned (a false red, the safe side); `-eq` and `-fq` are
flagged although there `q` is an argument; a sourced path with spaces is not
followed. Other early-exit readers (`head -c`, `grep -m`) are outside the
spec's scope; the one such site, `progress.sh` reading one character, uses only
the output and is correct.

The last review pass (the bugs lens reading only the fixes) found the scan's own
awk status check unreached by any test (the awk-failure test tripped the
source finder first), and the walk missing a grouped grep (`{ grep -q; }`,
`( grep -q )`), a grep by path or behind `timeout`, `nice`, `exec` or `env -i`,
a trailing pipe followed by a comment, and a library sourced through
`$(dirname "$0")`; its basename-only matching could also pull in a same-named
script from another directory. Fixed: the finder now joins the sourced name to
the caller's directory, and two tests were added (14 tests in
`tests/pipefail.bats`). Controls, each in a scratch worktree:

| Mutation | Landed | Expected test | Result |
|---|---|---|---|
| grouping allowance dropped | yes | the walk names a grouped grep, a grep by path or behind a wrapper, and a pipe before a comment | RED |
| path-before-grep allowance dropped | yes | the walk names a grouped grep, a grep by path or behind a wrapper, and a pipe before a comment | RED |
| wrapper words dropped | yes | the walk names a grouped grep, a grep by path or behind a wrapper, and a pipe before a comment | RED |
| comment strip before the trailing-pipe join dropped | yes | the walk names a grouped grep, a grep by path or behind a wrapper, and a pipe before a comment | RED |
| caller-directory join dropped (bare names) | yes | the walk follows a library sourced through dirname, and only from the caller's directory | RED |
| scan awk status ignored | yes | the walk fails when awk fails | RED |

6 mutations, 0 not caught.

## Full suite after the fixes (phase J)

`1..914`, 914 ok, 0 skipped, 0 not ok, at `66cf2f8` (the phase I commit); shellcheck clean.
