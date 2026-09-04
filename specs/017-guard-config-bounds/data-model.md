# Data model

No storage, no schema migration, no persisted entity. What follows is the
validation model for four configuration values, because the feature is entirely
about which values one of them accepts.

## Configuration values

| Value | Meaning | Valid | Change here |
|---|---|---|---|
| window size | the session's total capacity | any positive integer | **none** — deliberately unbounded, ruled 2026-09-04 |
| threshold percentage | share of the window at which the first warning fires | positive integer, **1–99** | **was 1–100; 100 is now refused** |
| absolute threshold | a token count at which to warn regardless of the window | any positive integer | none |
| read limit | how much of the transcript tail to read | any positive integer | none |

Only one cell in that table moves. Every other cell is a requirement to leave
alone (spec SC-008), not merely an absence of work.

## Resolution

Three layers, each overriding the one before:

```
shipped default  →  user-level settings  →  repository settings  →  environment
```

**The rule that makes this feature small**: an invalid value is *ignored*, and
the previously resolved value stands. It does not reset to the default, and it
does not abort the resolution. So refusing 100 at any layer hands back whatever
the layer beneath had — which is the shipped default when no layer set one.

**The rule that makes this feature correct**: all three layers validate the
threshold through one function. There is no per-layer bound to keep in step.

## State transitions

The threshold has no lifecycle. It is resolved once per invocation and read
twice — once to decide whether to warn, once to name the threshold in the
message. The second read is why the effective value is *observable*, and that
observability is what lets a test discriminate "99 was accepted" from "99 was
refused and the default stood".

## Validation rules, as assertions

| # | Rule | Source |
|---|---|---|
| V1 | threshold ≥ 100 → refused | contracts/threshold-validation.md |
| V2 | 1 ≤ threshold ≤ 99 → accepted | contracts/threshold-validation.md |
| V3 | refusal is silent and non-fatal | pre-existing contract, unchanged |
| V4 | refusal never disables the guard | pre-existing invariant, unchanged |
| V5 | V1 and V2 hold identically at all three layers | Principle IV |
| V6 | window size has no upper bound at any layer | spec FR-008, ruled non-change |

V6 is a requirement, not a gap. An implementation that adds a bound fails it.

## The one derived invariant that moves

Elsewhere the hook argues that a certain report can ride an existing warning
rather than needing an emission of its own, because observed context exceeding
the window forces the percentage to at least 100, which no admissible threshold
can block.

That argument is currently justified by "the maximum admissible threshold is
100" — equality. After V1 the maximum is 99, so the percentage *strictly
exceeds* every admissible threshold. **The invariant holds more strongly, and
its stated justification becomes wrong about the number.** The text moves with
the rule; the code beneath it does not.
