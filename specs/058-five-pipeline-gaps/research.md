# Research: Close the five pipeline gaps

No item in the plan was unknown. These are the decisions, with what was read or measured on `126f045` (2026-11-04).

## Status 3 for the start

- **Decision**: `suite-base start` exits 3 when `config.testCommand` is not a non-empty string, and when `artifacts.spec` names no existing file. Both print their existing line on stdout.
- **Rationale**: B records both just before the start, so an absence is an ordering fault, the fault run 056 hid. Exit 1 already means "a check could not be made", and `wait` uses exit 2.
- **Alternatives**: exit 1 keeps a status B's prose says does not stop the run. Status 3 for every reason in `SK_WHY`: the others are documented as legal (`pipeline/docs/phases.md`, "Reusing a suite run"), and each has a test through `runs`, which asserts exit 0.
- **How**: `suite_config` sets a variable, `SK_FAULT=1`, beside `SK_WHY` on the two paths. `base_start` returns 3 when it is set. Only `base_start` reads it. `suite-key`, `suite-record` and `suite-lookup` keep their `die`. Under `set -e` a function's non-zero return ends the script with that status. `on_exit` keeps it: test it.

## The Test command line

- **Decision**: the owner chose the orchestrator (clarify). Same shape as the Implementer line, with the command JSON-quoted because a tracked file can hold terminal escapes.
- **Rationale**: `preflight.sh` documents that it reads no configuration file. A second resolver could disagree with the recorded value.
- **Alternatives**: `preflight.sh` reads the layers; rejected by the owner.

## `branch-cut`

- **Decision**: reads `.branch` and `.baseBranch` from the state file. Three outcomes on stdout, every refusal through `die`.
- **Refs**: full refs in every git call (`refs/heads/<name>`), so a tag of the same name cannot be read in its place. `git check-ref-format --branch` refuses `@{-1}`, a leading dash and a bad name.
- **Ancestor test**: `git merge-base --is-ancestor`, with rc 0 yes, 1 no, and anything else a hard failure. A base that moved after the cut refuses, and names the `git checkout` command for the owner. This is the safe direction.
- **No state write**: it only reads the state file, so it adds no lock step.

## `state-set --json-file`

- **Decision**: `state-set <feature> <key> [<sub-key>] --json-file <path>`.
- **Read**: `jq -c -s` from a redirect, after `-f` and `-r` checks, so a path with a leading dash cannot be a flag and a failed redirect cannot print a raw path (memory: stdin moves a path leak to the shell). `jq`'s stderr is dropped: a parse error can quote the file.
- **Joins the inline path**: the compact JSON goes into `json`, and every check after that is the same code. The refusal text at the validity check must not print the value when it came from a file.
- **Size**: a value past one argument's limit (128 KB on Linux) fails in `exec`, with no value printed, and nothing is written.

## `preflight.sh --values-file`

- **Decision**: one JSON object, keys `commitTrailers` and `baseBranchOverride`. Read before the `cd` at line 116, so a relative path means the caller's folder.
- **Order**: parsed after the flag loop, and the file's trailers go first. So the order holds whatever the command line's order.
- **No value through the shell**: each trailer goes to `trailer-check.sh` as JSON, as `add_trailer` already passes it, taken from jq with a sentinel, so a trailing line feed is not lost to `$( )` and refused as it should be. bash 3.2: no `mapfile`; loop by index.
- **Alternatives**: `preflight.sh` reads the config files itself: the owner chose against that at clarify.

## `prose_slice` opt-in

- **Decision**: two more forms, `raw-inside` and `flat-inside`. The form argument is already validated, and every guard runs on the whole slice first, so the guards' reach cannot change.
- **Drop**: after the last guard, cut the last line by parameter expansion on `$s`. A slice left empty is refused with a message of its own.
- **Bash 3.2**: `${s%"$nl"*}` is safe there. No prose heredoc inside `$( )`.
- **Switch**: a script that rewrites the fourth argument of each call and refuses to write unless the counts match (memory: assert counts, don't read them). Then the 14 audit tests are read one by one, by name.

## Pieces land in this order

The branch piece first, because it frees bytes. `prose_slice` after the B prose is final.
