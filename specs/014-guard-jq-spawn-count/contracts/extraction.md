# Contract: what each extraction must yield

This is a refactor. The contract is therefore not "what the new code should do"
but "what the old code already does, which the new code must reproduce byte for
byte". Everything below was measured against the current `main`.

## The payload extraction

**Given** the object on stdin, **produce** four values.

| Input shape | agent | transcript | session | cwd |
|---|---|---|---|---|
| all four present | the value | the value | the value | the value |
| `agent_id` absent (**the ordinary main-session case**) | *(empty)* | the value | the value | the value |
| `agent_id` present (subagent) | the value | the value | the value | the value |
| `session_id` absent | — | — | `unknown` | — |
| any field `null` | *(empty)* | *(empty)* | `unknown` | *(empty)* |
| any field `""` | *(empty)* | *(empty)* | *(empty)* | *(empty)* |

Note the last two rows differ, and both must be preserved. `// ` in jq treats
`null` **and** `false` as absent, so a `null` session identifier becomes
`unknown`; an explicit empty string is a value and stays empty.

### Downstream consequences, which is why this matters

| Value | What reads it | What a wrong value does |
|---|---|---|
| agent | `if [ -n … ]; then exit 0` | a false non-empty **disables the guard for every main session, silently** |
| transcript | `[ -n … ] && [ -f … ] \|\| exit 0` | a wrong path exits early — guard silent |
| session | the once-per-bucket flag | a wrong value can swallow a warning that was owed |
| cwd | locating the repository configuration | a wrong value reads the wrong configuration, or none |

Every one of those failures is **silent**. None produces an error, and only the
first is caught by the existing suite.

## The configuration extraction

**Given** a file that exists, **produce** four values; **given** a file that does
not, **produce nothing and start no process.**

| Input shape | window | pct | tokens | maxBytes |
|---|---|---|---|---|
| file absent | *(function returns before doing anything)* | | | |
| all keys present | the value | the value | the value | the value |
| one key absent | *(that slot empty; the others unmoved)* | | | |
| `contextGuard` absent entirely | *(all four empty)* | | | |
| a value that is not a positive integer | *(rejected by the shell, default kept)* | | | |
| a value written with a leading zero | *(rejected — see the file's own reasoning)* | | | |

**The rule the naive design breaks** is row three, and it breaks it invisibly:
every value here is a positive integer, so a value that lands in the wrong slot
passes validation and is installed. Measured with `thresholdPct` absent, the
naive split installs the byte cap as the token threshold.

## Invariants that survive this change

1. **Reporting failures stays loud.** The missing-tool hint, the misconfigured-
   window note and its lower bound are all still reported. A refactor that turns
   any of them into silence is a regression even with a green suite.
2. **Validation lives in the shell.** Nothing but extraction and the empty
   default moves into the jq program.
3. **The comments stay.** The dated incident, the median-window reasoning, the
   byte-cap fallback and the leading-zero rationale are the reason the
   arithmetic can be trusted. Code moves; the record does not shrink.
4. **The existing hook suite is not edited.** It is the tripwire. A test that
   needs changing is proof the behaviour changed, and the answer is to stop, not
   to change the test.

## One behaviour difference, named rather than hidden

Joining fields and splitting them again introduces a constraint the per-field
extraction did not have: **a value that itself contains the separator byte would
split into two fields.** Today, each field is fetched by its own invocation and
no value can corrupt another.

The separator chosen is the ASCII **unit separator** — a control character with
no printable form, which exists for exactly this purpose. For it to bite, a
transcript path, session identifier, working directory or configuration number
would have to contain a raw control byte. That is not reachable through any
normal path, and a payload carrying one is already malformed.

It is still a difference, and it is written here because a reviewer will find it
and should find it already acknowledged rather than argued about. Tab, the
seed's suggestion, has the same theoretical exposure and a far larger practical
one — tabs occur in real paths — on top of the empty-field defect that rules it
out anyway.

## What this contract does NOT promise

- **It does not promise a faster hook in wall-clock terms.** It promises fewer
  processes started, which is the thing measured. On a platform where spawning
  is cheap the difference may not be observable, and no claim is made that it
  is.
- **It does not change what the guard decides.** If the guard fires today at a
  given context level, it fires after at the same level.
