# Quickstart: verify the commit trailers

Run from the repository root.

## 1. The suites

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
bash scripts/check-versions.sh
```

Record of one run, 2026-10-07, Linux, at `032-branch-and-spec-dir-flags` = `8c48ddf` (the first version of Phase 41): before the change `1..289`, all `ok`. After it, see the table in §3.

## 2. The positive controls

Each mutation runs in a throw-away copy of the tree, never in the checkout. Each one is first checked to have landed: the original text must be present exactly once before it is replaced, or the result is not counted. The file is restored after each run.

| # | Mutation | File | Test that goes red |
|---|---|---|---|
| 1 | `with_trailers` returns before adding anything | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | every "trailers:" test that commits with a list |
| 2 | J's `--record` sets `MF` without `with_trailers` | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: J's empty record commit carries them, and is still read as J's record (alone) |
| 3 | `commit_named` sets `MF` without `with_trailers` | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | the spec, piece, late and remainder "trailers:" tests, not J's |
| 4 | Drop the same-line check (`[ "$l" != "$t" ] \|\| continue 2` → `:`) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: another value under the same token is added; the same line is not |
| 5 | Always add a blank line before the trailers (force `block=0`) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: piece-commit joins them to its Tasks and Piece lines, the body kept byte for byte |
| 6 | Drop `Tasks` from the reserved tokens | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a run marker is refused, naming it |
| 7 | Drop `Piece` from the reserved tokens | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 8 | Accept any recorded list | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a recorded list that is not an array is refused<br>trailers: a recorded list holding a number or an empty string is refused |
| 9 | Skip the `:` check | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: no colon or an empty value is refused, naming it |
| 10 | Skip the token check | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a token git would read differently is refused |
| 11 | Skip the empty-value check | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: no colon or an empty value is refused, naming it |
| 12 | Commit the caller's file in place | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: remainder-commit carries them, never adds one twice, and leaves the caller's file alone |
| 13 | `show-message` prints the caller's file, not the copy | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | show-message prints the exact message the commit then carries, and leaves the file alone |
| 14 | Drop `Tasks` from the reserved tokens | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: the run's own markers Piece, Late and Tasks are refused, in any letter case |
| 15 | Skip the line-break check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: a malformed trailer is refused, naming it, one case per check |
| 16 | Skip the `:` check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 17 | Skip the token check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 18 | Skip the empty-value check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 19 | Skip the reserved-token check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: the run's own markers Piece, Late and Tasks are refused, in any letter case |
| 20 | Reserve `Piece` only | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 21 | Never add a trailer to the list | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: each one is reported, in the order given |
| 22 | Add each trailer to the front | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 23 | Change the `commitTrailers` row | `pipeline/skills/pipeline/SKILL.md` | the commit trailers are pinned where the operator reads them |
| 24 | Change the `--trailer` row | `pipeline/skills/pipeline/SKILL.md` | same |
| 25 | Delete the `Trailers` probe line | `pipeline/skills/pipeline/SKILL.md` | same |
| 26 | Drop `commitTrailers` from the pointer list | `pipeline/skills/pipeline/SKILL.md` | same |
| 27 | Make the add rule a replace rule | `pipeline/docs/configuration.md` | same |
| 28 | Drop `Tasks` from the reserved tokens | `pipeline/docs/configuration.md` | same |
| 29 | Pass the flags' trailers first | `pipeline/docs/configuration.md` | same |
| 30 | Rename `config.commitTrailersFrom` | `pipeline/docs/configuration.md` | same |
| 31 | Drop J's `--record` from the list of commits | `pipeline/docs/configuration.md` | same |
| 32 | Allow a trailer by hand | `pipeline/docs/configuration.md` | same |
| 33 | Drop the recorded layer from the resume rule | `pipeline/docs/configuration.md` | same |
| 34 | Reword the entry's bold lead | `pipeline/CHANGELOG.md` | same |
| 35 | Accept an empty recorded trailer | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a recorded list holding a number or an empty string is refused |
| 36 | Let the record hold the key's list alone | `pipeline/docs/configuration.md` | the commit trailers are pinned where the operator reads them |
| 37 | Allow `skip-checks` as a token | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a trailer that skips GitHub's checks is refused, in any letter case |
| 38 | Drop `[ci skip]` from the skip-ci values | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | same |
| 39 | Allow `Co-authored-by` as a token | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a trailer that names another author is refused |
| 40 | Break the closing-keyword pattern in the value | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a trailer that closes an issue is refused |
| 41 | Allow a token ending in a non-alphanumeric | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a token git would read differently is refused (its first and last characters, and its length) |
| 42 | Allow an empty token | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a token git would read differently is refused |
| 43 | Allow a one-character token | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a token git would read differently is refused (its first and last characters, and its length) |
| 44 | Allow `_` in a token | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a token git would read differently is refused |
| 45 | Allow a token starting with a non-letter | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a token git would read differently is refused (its first and last characters, and its length) |
| 46 | Refuse only CR and LF, not every control character | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a tab, NEL or NUL in a recorded trailer is refused<br>trailers: a line break or an escape sequence in a recorded trailer is refused |
| 47 | Reserve `Piece` by substring | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a token that only holds a run marker's letters commits exactly |
| 48 | `show-message` skips `need_git_top` | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | show-message refuses a run marker in the message, a bad recorded trailer, and a subdirectory |
| 49 | Skip the control-character check | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: a malformed trailer is refused, naming it, one case per check |
| 50 | Allow `_` in a token | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 51 | Allow a one-character token | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 52 | Allow a token starting with a non-letter | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 53 | Name `(--trailer)` in an error again | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 54 | Allow `skip-checks` as a token | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: one that skips GitHub's checks, names another author or closes an issue is refused |
| 55 | Drop `[no ci]` from the skip-ci values | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | same |
| 56 | Take the token up to the last colon | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: a value holding a colon is reported whole |
| 57 | Reserve `Piece` by substring | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: dashed tokens and tokens holding a marker's letters are accepted, in order |
| 58 | Drop the `owner/repo` part of the closing pattern | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a trailer that closes an issue is refused |
| 59 | Count a one-word last paragraph as a trailer block | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a one-word last paragraph is not a trailer block, and a spaces-only line splits paragraphs |
| 60 | Forget the trailers already added from the list | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: the same trailer twice in the list is added once |
| 61 | Count a spaces-only line as text | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a one-word last paragraph is not a trailer block, and a spaces-only line splits paragraphs |
| 62 | Drop the `:?` from the closing pattern | `pipeline/scripts/preflight.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: one that skips GitHub's checks, names another author or closes an issue is refused |
| 63 | Refuse C0 only, not the C1 range | `pipeline/scripts/trailer-check.sh` (through both hooks) | the control-character test in `progress-git.bats`, and the malformed test in `preflight.bats` (U+0085) |
| 64 | Allow `skip-checks` | `pipeline/scripts/trailer-check.sh` (through both hooks) | the skip-checks test in each suite |
| 65 | Allow `Co-authored-by` | `pipeline/scripts/trailer-check.sh` (through both hooks) | the another-author test in each suite |
| 66 | Drop `[no ci]` | `pipeline/scripts/trailer-check.sh` (through both hooks) | the skip-checks test in each suite |
| 67 | Drop the `owner/repo` part of the closing pattern | `pipeline/scripts/trailer-check.sh` (through both hooks) | the closes-an-issue test in each suite |
| 68 | Allow a one-character token | `pipeline/scripts/trailer-check.sh` (through both hooks) | the token test in each suite |
| 69 | Drop `Tasks` from the reserved tokens | `pipeline/scripts/trailer-check.sh` (through both hooks) | the run-marker test in each suite |
| 70 | Allow an empty value | `pipeline/scripts/trailer-check.sh` (through both hooks) | the run-marker test in `progress-git.bats`, the malformed test in `preflight.bats` |
| 71 | Show a refused trailer raw, not as JSON | `pipeline/scripts/trailer-check.sh` (through both hooks) | the control-character test in each suite |
| 72 | `show-message --record` leaves out `Late: J` | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | show-message --record prints J's record commit exactly as late-commit J --record makes it |
| 73 | Drop `close` from the closing tokens (review 4, R1a) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every closing keyword is refused as the token |
| 74 | Drop `fixed` from the closing tokens (review 4, R1b) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every closing keyword is refused as the token |
| 75 | Drop `resolved` from the closing tokens (review 4, R1c) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every closing keyword is refused as the token |
| 76 | Scan the trailer without lower-casing it (review 4, R2a) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every closing keyword before an issue number is refused, in any letter case |
| 77 | Drop `resolve[sd]?` from the closing pattern (review 4, R2b) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every closing keyword before an issue number is refused, in any letter case |
| 78 | Narrow `fix(e[sd])?` to `fix(es)?` (review 4, R2c) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every closing keyword before an issue number is refused, in any letter case |
| 79 | Narrow `close[sd]?` to `closes?` (review 4, R2d) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every closing keyword before an issue number is refused, in any letter case |
| 80 | `[[:cntrl:]]` becomes C0 and C1 only, so DEL passes (review 4, R3) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: DEL is refused as a control character, and never printed raw |
| 81 | Check a trailer only against the block's last line (review 4, R8) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a line already in the block, though not its last, is not added twice |
| 82 | A trailer block may hold a space in a token (review 4, R9a) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a prose last paragraph gets a blank line, even holding ': ' or the same line |
| 83 | Read a prose last paragraph as the block (review 4, R9b) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: a prose last paragraph gets a blank line, even holding ': ' or the same line |
| 84 | "never added twice" becomes "may be added twice" (review 4, R10a) | `pipeline/docs/configuration.md` | the trailer rules the operator reads are pinned whole |
| 85 | "with its layer named" becomes "with no layer named" (review 4, R10b) | `pipeline/skills/pipeline/SKILL.md` | the trailer rules the operator reads are pinned whole |
| 86 | Drop U+2028-U+202E from the shared list (review 4, H1) | `pipeline/scripts/hidden-chars.sh` (through both hooks) | trailers: the hidden-character ranges' lower edges are refused and shown escaped<br>trailers: the hidden-character ranges' upper edges are refused and shown escaped<br>every edge of every refused range is refused, and the characters beside them are not |
| 87 | Drop the C1 range from the shared list (the trailer side refuses C1 as a control character first, as designed) (review 4, H2) | `pipeline/scripts/hidden-chars.sh` (through both hooks) | text that can disguise itself in a terminal, or is too long, is refused<br>every edge of every refused range is refused, and the characters beside them are not |
| 88 | Drop the tag plane U+E0000-U+E007F (review 4, H3) | `pipeline/scripts/hidden-chars.sh` (through both hooks) | trailers: the hidden-character ranges' lower edges are refused and shown escaped<br>trailers: the hidden-character ranges' upper edges are refused and shown escaped<br>every edge of every refused range is refused, and the characters beside them are not |
| 89 | Widen U+E01EF to U+E01F0 (review 4, H4a) | `pipeline/scripts/hidden-chars.sh` (through both hooks) | trailers: the characters just past the tag-plane ranges are accepted |
| 90 | Widen U+E0000 down to U+DFFFF (review 4, H4b) | `pipeline/scripts/hidden-chars.sh` (through both hooks) | trailers: the characters just past the tag-plane ranges are accepted |
| 91 | Widen U+2028 down to U+2027 (review 4, H4c) | `pipeline/scripts/hidden-chars.sh` (through both hooks) | trailers: the review's hidden characters are refused, and the characters beside the ranges are not<br>every edge of every refused range is refused, and the characters beside them are not |
| 92 | `text_file` uses a list of its own (review 4, H5) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | every edge of every refused range is refused, and the characters beside them are not<br>the hidden-character list lives in one file, which both checks read |
| 93 | `progress.sh` does not source `hidden-chars.sh` (review 4, H6) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | every edge of every refused range is refused, and the characters beside them are not<br>the hidden-character list lives in one file, which both checks read |
| 94 | `trailer-check.sh` uses a list of its own (review 4, H7) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: the hidden-character ranges' lower edges are refused and shown escaped<br>trailers: the hidden-character ranges' upper edges are refused and shown escaped<br>the hidden-character list lives in one file, which both checks read |
| 95 | Drop the `hidden` verdict (review 4, H8) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: the hidden-character ranges' lower edges are refused and shown escaped<br>trailers: the hidden-character ranges' upper edges are refused and shown escaped |
| 96 | Check `hidden` before `cntrl` (review 4, H9) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: the hidden-character ranges' lower edges are refused and shown escaped<br>trailers: the hidden-character ranges' upper edges are refused and shown escaped<br>trailers: a tab, NEL or NUL in a recorded trailer is refused |
| 97 | Show a hidden character raw (review 4, D1) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: the hidden-character ranges' lower edges are refused and shown escaped<br>trailers: the hidden-character ranges' upper edges are refused and shown escaped |
| 98 | `. >= 128` becomes `>= 129`: U+0080 shown raw (review 4, D3) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: the hidden-character ranges' lower edges are refused and shown escaped |
| 99 | A wrong low surrogate (review 4, D4) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: the hidden-character ranges' lower edges are refused and shown escaped<br>trailers: the hidden-character ranges' upper edges are refused and shown escaped |
| 100 | No surrogate pair above U+FFFF (review 4, D5) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: the hidden-character ranges' lower edges are refused and shown escaped<br>trailers: the hidden-character ranges' upper edges are refused and shown escaped |
| 101 | Upper-case hex in the escape (review 4, D6) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: the hidden-character ranges' lower edges are refused and shown escaped<br>trailers: the hidden-character ranges' upper edges are refused and shown escaped |
| 102 | `[[:space:]]*` becomes `+` (review 4, C1) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every form that closes an issue, and On-behalf-of, is refused |
| 103 | Drop the `gh-[0-9]` form (review 4, C2) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every form that closes an issue, and On-behalf-of, is refused |
| 104 | Drop the issue-URL form (review 4, C3) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every form that closes an issue, and On-behalf-of, is refused |
| 105 | Scan the value only (`${lc#*:}`) (review 4, C4) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every form that closes an issue, and On-behalf-of, is refused |
| 106 | A dash is not a word boundary (review 4, C5) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every form that closes an issue, and On-behalf-of, is refused |
| 107 | No word boundary (review 4, C6) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every form that closes an issue, and On-behalf-of, is refused |
| 108 | `https?` becomes `https` (review 4, C7) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every form that closes an issue, and On-behalf-of, is refused |
| 109 | Drop the `owner/repo` part (review 4, C8) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every form that closes an issue, and On-behalf-of, is refused |
| 110 | Drop the `:?` (review 4, C9) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every form that closes an issue, and On-behalf-of, is refused |
| 111 | The URL host only (`[^[:space:]/]*`) (review 4, C10) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every form that closes an issue, and On-behalf-of, is refused |
| 112 | The issue number optional (review 4, C11) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every form that closes an issue, and On-behalf-of, is refused |
| 113 | Drop `on-behalf-of` from the tokens (review 4, C12) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: every form that closes an issue, and On-behalf-of, is refused<br>trailers: a trailer that names another author is refused |
| 114 | A second jq call for the lower-case form (review 4, J1) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: trailer-check.sh runs jq once, and needs nothing else on the search path |
| 115 | Bring back the grep closing scan (review 4, J2) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: trailer-check.sh runs jq once, and needs nothing else on the search path |
| 116 | Drop `ascii_downcase` (review 4, J3) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: the run's own markers Piece, Late and Tasks are refused, in any letter case<br>trailers: every closing keyword is refused as the token<br>trailers: every closing keyword before an issue number is refused, in any letter case |
| 117 | `lc="$rest"`: a wrong tab split (review 4, J4) | `pipeline/scripts/trailer-check.sh` (through both hooks) | trailers: the run's own markers Piece, Late and Tasks are refused, in any letter case<br>trailers: every closing keyword is refused as the token |
| 118 | The check's error file back to a fixed name (review 4, M1) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: the message copies are each call's own, and none is left behind |
| 119 | The message copy back to a fixed name (review 4, M2) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: the message copies are each call's own, and none is left behind |
| 120 | `show-message --record`'s message back to a fixed name (review 4, M3) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: the message copies are each call's own, and none is left behind |
| 121 | `on_exit` keeps the message copy (review 4, M4) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: the message copies are each call's own, and none is left behind |
| 122 | `on_exit` keeps the check's error file (review 4, M5) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: the message copies are each call's own, and none is left behind |
| 123 | `on_exit` keeps `show-message`'s message (review 4, M6) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | trailers: the message copies are each call's own, and none is left behind |
| 124 | The message copy at a new fixed name, `$RD/trailers-msg.tmp` (review 4, M7) | `pipeline/scripts/progress.sh` (through `PROGRESS_SH_UNDER_TEST`) | the trailer path's scratch files are each made by mktemp in the run folder |
| 125 | Drop `On-behalf-of` from the trailers entry (review 4, X1) | `pipeline/CHANGELOG.md` | the CHANGELOG states review 3's new refusals whole |
| 126 | Drop "a name that is a tag as well" from the override entry (review 4, X2) | `pipeline/CHANGELOG.md` | the CHANGELOG states review 3's new refusals whole |
| 127 | Drop the trailing-dot and device clause from the spec-folder entry (review 4, X3) | `pipeline/CHANGELOG.md` | the CHANGELOG states review 3's new refusals whole |
| 128 | `##[` refused only "at its start" (review 4, Q9) | `pipeline/docs/configuration.md` | review 4's refusals are pinned where the operator reads them |
| 129 | Drop the backtick from the quote rule (review 4, Q10) | `pipeline/CHANGELOG.md` | review 4's refusals are pinned where the operator reads them |
| 130 | Reword the Fixed entry's bold lead (review 4, Q12) | `pipeline/CHANGELOG.md` | review 4's refusals are pinned where the operator reads them |
| 131 | `TR_MSG` no longer starts empty (review 4, Q14) | `pipeline/scripts/progress.sh` | a scratch-file name inherited from the environment is never removed on exit |
| 132 | Drop the check that `hidden-chars.sh` is readable (review 4, Q15) | `pipeline/scripts/progress.sh` | a copy of progress.sh without hidden-chars.sh beside it stops, saying so and naming no path |
| 133 | The missing-file refusal names the script's folder (review 4, Q16) | `pipeline/scripts/progress.sh` | a copy of progress.sh without hidden-chars.sh beside it stops, saying so and naming no path |
| 134 | the quote rule removed, then each of `'`, `$` and the backtick taken out of it (rule N6): `O'Brien` is accepted | `pipeline/scripts/trailer-check.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: a quote, a dollar sign or a backtick is refused, since a trailer is typed into a shell command |
| 135 | the `##[` rule removed (rule M-##): `Note: ##[error]injected` is accepted | `pipeline/scripts/trailer-check.sh` (through `PREFLIGHT_UNDER_TEST`) | trailers: ##[ anywhere is refused, since a workflow log reads it as a command |

Two `progress.sh` mutations (rows 2 and 3) first left `MF` empty. They went red because the commit failed, not because a trailer was missing. They were rerun in the form above, and went red for the right reason.

After review 3 the rule is one file, `pipeline/scripts/trailer-check.sh`. Rows 6-11, 14-20, 35, 37-47, 49-58 and 62 named the copies in `progress.sh` and `preflight.sh`; their strings now live in `trailer-check.sh`. A mutation of that file must turn BOTH suites red, so rows 63-71 copy the whole `pipeline/scripts/` folder, mutate `trailer-check.sh` in the copy, and point `PROGRESS_SH_UNDER_TEST` and `PREFLIGHT_UNDER_TEST` at the copies of the two callers. Pointing a hook at a lone copied script no longer works: its sibling `trailer-check.sh` would be missing, and the test would go red for that reason.

## 3. Record

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | `1..294`, all `ok` | 20 of 20 landed and went red (first version) |
| 2026-10-07 | Linux | `1..369`, all `ok` | 36 of 36 landed and went red (rebuilt on Phase 41) |
| 2026-10-08 | Linux | `1..425`, all `ok`, at `30344a8` | After review 2, on `main` `4076ecf`: rows 1-22, 35 and 37-57 (the script rows) landed and went red. Row 15 first survived: the new control-character check also catches a line break. The test now checks the line-break reason, and row 15 goes red. Row 9 goes red on the message: without the `:` check, the token check refuses the value with another reason. Rows 23-34 and 36 test text this change did not touch. |
| 2026-10-08 | Linux | `1..439`, all `ok`, review 3 | Rows 58-62 landed and went red. Each had survived review 3's fresh mutants; each now has a case. |
| 2026-10-08 | Linux | `1..442`, all `ok`, review 3, commit B | Rows 63-72 landed. Rows 63-71 went red in both suites, row 72 in `progress-git.bats`. |
| 2026-10-09 | Windows (Git Bash) | review 4's tests lens, at `3fec620` (the tree `8a75039` holds outside `main-plan.md`); `preflight.bats` alone `1..80`, all `ok` | Rows 73-127 landed. Rows 73-88, 91-113 and 116-123 went red. Rows 89-90, 114-115, 124 and 125-127 survived every test then; each went red on the test the review proposed for it (T2, T4, T6 and T5), now in `preflight.bats` and `prose.bats`. A 56th mutant, `. < 160` → `. < 128` in the escape display, survived and has no row: it is equivalent while the shared list holds the C1 range, which `hidden` escapes too. |
| 2026-10-10 | Windows (Git Bash) | the review-4 fix (the commits after review 4 on this branch); each row's test alone | Rows 128-133 landed and went red. Rows 134-135 landed and went red (implementer A's rig, each mutant on a scratch copy). |

The ids in brackets name review 4's mutants: R, H, D, C, J, M and X are its tests lens's; Q are the review-4 fix's own. Each was first checked to have landed (the old text exactly once before, gone after), and the file was restored byte for byte after its run. Rows 131-133 mutate `progress.sh` itself, in a scratch worktree: `progress.bats` has no `PROGRESS_SH_UNDER_TEST` hook. Under load on Windows, the `pending.bats` test "every edge of every refused range…" can pass its 60-second limit on `main` as well (review 4, tests note 1); rows 86-88 and 91-93 name it, and the lens gave it a longer limit for its runs.
