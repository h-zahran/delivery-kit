# Contract: what the state script's refusals must name

**Date**: 2026-08-27 · **Feature**: `008-progress-coverage-timeout`

The state script is a command-line tool. Its interface to a human is the pair it
prints when it stops: a non-zero exit, and a message. This document is the
contract for the second half — what each refusal must *name*.

**Why the naming is the contract and the exit is not.** Everyone meeting one of
these messages is already in trouble: a run has stopped, and they are trying to
learn why. A bare non-zero exit tells them only that. The naming is what turns a
stop into a next step. A test that asserts only the exit status passes with the
message emptied, so it protects the half that does not matter.

Every entry below was driven and its message captured on 2026-08-27, before any
test was designed. The "must name" column is the assertion; the "captured"
column is what the script prints today.

---

## C1 — Completing a phase the script does not know

| | |
|---|---|
| **Trigger** | the completion subcommand, with a phase that is not in the known list |
| **Must name** | the offending phase, quoted |
| **Captured** | `unknown phase 'ZZZ'` |
| **Red when** | the quoted phase is replaced by a fixed word |

## C2 — The plan artefact is required and absent

| | |
|---|---|
| **Trigger** | the from-validation subcommand, for the phase whose rule needs the plan |
| **Must name** | the artefact that is missing, quoted, **and** that the record holds none that exists |
| **Captured** | `--from E needs the 'plan' artefact, and the state file records none that exists` |
| **Red when** | the artefact name is changed |

## C3 — The tasks artefact is required and absent

| | |
|---|---|
| **Trigger** | the from-validation subcommand, for any phase in the tasks group |
| **Must name** | the artefact that is missing, quoted |
| **Captured** | `--from F needs the 'tasks' artefact, and the state file records none that exists` |
| **Red when** | the artefact name is changed |
| **Note** | the group holds four phases. The test drives one and states which; the branch is shared, so driving all four would prove nothing more. |

## C4 — No rule admits the requested phase

| | |
|---|---|
| **Trigger** | the from-validation subcommand for a late phase that is neither the current one nor completed |
| **Must name** | the phase, **and all three reasons it was refused** |
| **Captured** | `--from O: not the current phase, not completed, and no artefact rule admits it` |
| **Red when** | any one of the three reasons is dropped |
| **Note** | this is the only refusal that enumerates why. The enumeration is the useful part: it tells the reader which of three things to change. |

## C5 — The lock is taken with no session identifier

| | |
|---|---|
| **Trigger** | the lock-taking subcommand with the identifier argument omitted |
| **Must name** | what was missing |
| **Captured** | `lock-take needs a session id` |
| **Red when** | the message stops naming the missing argument |

## C6 — The protected creation fails

| | |
|---|---|
| **Trigger** | **make the lock path a directory**, then take the lock |
| **Must name** | the race, and the fact that retrying is the remedy |
| **Captured** | `lost the lock race; run lock-take again` |
| **Red when** | the remedy is dropped from the message |
| **⚠ Note** | **the test does not run a race, and must not be "fixed" into one.** The guard above the protected write tests for a regular file, so a directory at that path passes it untouched and then makes the write fail. Same branch, different door, and deterministic. A real race is unreliable to lose on purpose, and a test that passes only sometimes is worse than no test. |

## C7 — Too few arguments

| | |
|---|---|
| **Trigger** | fewer than two arguments |
| **Must name** | every legal subcommand |
| **Captured** | `usage: progress.sh <init\|read\|validate\|phase-start\|phase-done\|from-validate\|lock-take\|lock-release> <feature> [args]` |
| **Red when** | any subcommand disappears from the list |
| **Note** | this is the one refusal whose message is a *complete enumeration*. Asserting one subcommand would let the list rot; the test asserts several, including the first and the last. |

## C8 — The completed-phases value is not a list

| | |
|---|---|
| **Trigger** | craft that key in the state file as a string, then validate |
| **Must name** | the state file **and** the key |
| **Captured** | `<path>: completed_phases must be an array` |
| **Red when** | either the path or the key is dropped |
| **Note** | naming the path matters because a run can hold several state files; naming only the key sends the reader to the wrong one. |

## C9 — The recorded current phase is unknown

| | |
|---|---|
| **Trigger** | craft that key in the state file as a value not in the known list, then validate |
| **Must name** | the state file **and** the offending value, quoted |
| **Captured** | `<path>: current_phase 'ZZZ' is not a phase this pipeline knows` |
| **Red when** | the quoted value is dropped |

---

## Contract for the read path

| | Rule |
|---|---|
| **RC1** | On a valid state, everything on the data stream is accepted whole by a strict parser, with nothing else present. |
| **RC2** | On an invalid state, the data stream is **empty** — measured at 0 bytes — the fault goes to the diagnostic stream, and the exit is non-zero. |
| **RC3** | With the two-character line ending present, a strict parser still accepts the output. |
| **RC4** | With it present, capturing through command substitution yields a clean value. |
| **RC5** | With it present, the line-reading idiom the shipped document forbids **does** retain the stray character. |

**RC3 to RC5 exist because two shipped documents make this promise to their
readers today and nothing tests it.** RC5 in particular is the warning half: if
the trap ever stopped being a trap, the shipped warning would become a lie with
no test to notice. The condition must be **constructed by the test**, never
waited for — it does not arise on every machine, so a test that reads whatever
the file happens to hold would pass everywhere and prove nothing on most of
them.

---

## How this contract is verified

Each entry is one appended test. Each asserts the exit **and** the naming.
Each is watched failing before it is trusted, by changing the naming it asserts
to name something else — never by deleting the test — with the altered line
echoed back before the red is believed. A substitution that silently did nothing
produces a false green, which is the failure this whole campaign exists to
close.
