# Data model: 051-preflight-failed-git-reads

No report key is added, removed or retyped. The change is three new exit
paths.

## The pre-flight outcome, with a usable git

| Base source | Checkout | Status read | Outcome |
|---|---|---|---|
| override, `origin/HEAD` or configured | any | succeeds | report, as today |
| current branch | a branch with a commit | succeeds | report, as today |
| current branch | detached `HEAD` | (not reached) | stop: detached |
| current branch | a branch with no commit yet | (not reached) | stop: no commit yet |
| any that reached the status read | — | fails | stop: status not read |

A stop prints one `preflight: …` line on stderr, exits 1, and prints
nothing on stdout.

## With git not usable

Unchanged from feature 050: a report, `baseBranch` `""` when the base
came from the current checkout, `tree.dirty` `false`, both named in
`notRead`.
