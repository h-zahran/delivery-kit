# Contract: threshold validation

**Status**: authoritative for feature 017. This file states the rule **once**.
Everything that describes the rule elsewhere — the hook's own comments, the
user documentation, the changelog entry — restates *this* sentence.

The prose pin required by Principle I does **not** read this file. It bans the
superseded phrasings directly, over `handoff/docs` and `handoff/hooks`, with the
three legitimate observed-percentage constructions exempted by name. Stated
plainly because an earlier draft of this paragraph claimed the pin checks
against this contract "rather than against a list of file paths", and that was
never true of what shipped — the canonical sentence is duplicated into the test,
not read from here. Whoever makes the pin derive from this file should delete
this paragraph; until then it is the honest description.

---

## The rule

> A warning threshold percentage of **100 or above** is refused. Values from
> **1 to 99** are accepted.

The superseded wording, which must not survive anywhere:

> ~~A threshold **above 100** is refused.~~

The difference is exactly one value, and that value is the defect.

---

## Why 100 is refused

The threshold is a percentage of the session's configured capacity. A threshold
of 100 can only be met once observed context has already reached the whole
window — at which point the guard's purpose, interrupting while there is still
room to finish, has already been lost. The guard would never warn in time again,
and it would not say so. That is the one failure the hook's own comments forbid,
and nothing downstream can catch it: the misconfiguration report rides an
emission that has, by then, not happened.

Refusing 100 is therefore not a tightening of an arbitrary bound. It closes the
gap between a rule the code already states and a rule the code actually enforces.

---

## Behaviour on refusal

Refusal follows the existing contract for every invalid value, unchanged:

- The offending value is ignored.
- The previously resolved value stands — whatever the layer beneath had resolved
  to, and the shipped default if no layer had.
- Nothing is announced. A refusal is silent, exactly as it is for a negative
  number or a non-numeric string.
- **The guard is never disabled by an invalid value.** That is the invariant this
  contract serves.

---

## Where the rule is enforced

One place: `is_valid_threshold` in `handoff/hooks/context-guard.sh`.

All three configuration layers reach it —

| Layer | Reaches the validator via |
|---|---|
| user-level settings file | the shared configuration reader |
| repository settings file | the same shared reader |
| environment variable | the environment resolution step |

— so the rule has **one implementation and three callers**, per Principle IV.
An inline copy of the bound at any call site is a contract violation even if it
computes the same answer.

---

## What this contract does NOT cover

The **window size** is out of scope and deliberately unbounded. That was ruled
on 2026-09-04 (spec FR-008, and the Clarifications section). A ceiling or a
notice for the window is a breach of this feature's scope, not an extension of
this contract.

---

## Observable consequences, for tests to assert

| Configured threshold | Accepted? | Effective threshold | Observable in the emission |
|---|---|---|---|
| 99 | yes | 99 | message names `threshold 99%` |
| 100 | **no** | the previously resolved value (the default, 45, where no layer set one) | message names `threshold 45%`; and where it previously stayed **silent**, it now speaks |
| 101 and above | no | the previously resolved value | unchanged from today |

The middle row is the entire behavioural change. Measured against the unchanged
hook on 2026-09-04: with a threshold of 100 and readings at half the window, the
guard emitted **nothing at all**. After this change the same input produces a
warning. Silent to speaking is the contract's proof.
