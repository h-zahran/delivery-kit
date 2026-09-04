# Configuration

Settings live in `.delivery-kit.json`. There are two: one at your repository
root, and one at `~/.delivery-kit.json` for facts about your machine rather
than about a project. **Both are optional** — with neither present the defaults
apply and the guard works.

Run `handoff:setup` and it will measure your session, propose a window when
the measurement supports one — in a fresh session there is little to propose, so
it asks instead — and write the user-level file for you. The rest of this page is
for setting it by hand.

```json
{
  "contextGuard": { "windowTokens": 200000, "thresholdPct": 45 },
  "handoff":      { "docsDir": "docs/handoffs" }
}
```

Unknown keys are ignored, never rejected — later versions add keys to this same
file, and an old plugin reading a newer file must not break.

## Precedence

Defaults → `~/.delivery-kit.json` → `<repo>/.delivery-kit.json` → environment
variables. The environment wins, which is what makes a temporary override
possible without editing a committed file. The repository file beats the
user-level one, so a project can override for its own reasons.

Your context window is a fact about your machine and your model, not about a
repository, which is why it belongs in the user-level file — answered once
rather than in every repository you work in.

| Setting | Default | Environment variable |
|---|---|---|
| `contextGuard.windowTokens` | `200000` | `DELIVERY_KIT_WINDOW_TOKENS` |
| `contextGuard.thresholdPct` | `45` | `DELIVERY_KIT_THRESHOLD_PCT` |
| `contextGuard.thresholdTokens` | `unset` | `DELIVERY_KIT_THRESHOLD_TOKENS` |
| `contextGuard.maxBytes` | `8000000` | `DELIVERY_KIT_MAX_BYTES` |
| `handoff.docsDir` | `docs/handoffs` | `DELIVERY_KIT_HANDOFF_DIR` |

A value that is not a positive integer is ignored and the previously resolved
value is kept — whatever the layer beneath it in that order had already
resolved to. A bad environment variable leaves the repository file's value
standing; a bad value in the repository file leaves the user-level file's; a bad
value in the user-level file leaves the default. The same applies to a
`thresholdPct` of **100 or above**. Such a threshold is not unreachable —
context at or above 100% of the configured window is exactly what the
misconfiguration note below reports — but it can only be reached once context
has already filled the window, which is far too late to be useful. In practice
the guard would never fire in time, silently, which is the one thing a settings
file must not be able to do. **100 is included in that rule and is the value it
exists for**: 450 is plainly a typo for 45, while "warn me at 100%" reads like a
deliberate choice and disarms the guard just as completely. The highest
threshold accepted is therefore 99. A malformed config file is ignored entirely.
No invalid value can disable the guard. A value that is valid but wrong is a
different matter, and the next section is about the one case that bites.

## Setting the window correctly

This is the one setting worth getting right.

`windowTokens` must match your model's real context window. The default of
200,000 is deliberately conservative, because the two ways of being wrong are
not equally bad:

- **Set too small** — the guard fires earlier than necessary. Mildly annoying,
  immediately obvious.
- **Set too large** — the guard never fires at all. The failure is silent and
  total, and you find out when the session dies mid-task.

Two things make a value set **too small** visible. The warning always names the
window it used, so *"45% of the 200000-token window"* on a 1,000,000-token model
tells you immediately. And if observed context ever exceeds the configured
window, the value is provably wrong, and the guard says so once per session.

Nothing detects a window set too large — there is no reading the guard could
take that would reveal it, which is exactly why the default is the conservative
direction rather than the generous one.

If your model has a 1M-token window:

```json
{ "contextGuard": { "windowTokens": 1000000 } }
```

## Threshold

`thresholdPct` is where the first warning fires, as a percentage of the window.
The default is 45. After the first warning the guard re-warns once per 5%
bucket — 45, 50, 55 — so working past a warning is nudged again rather than
nagged on every tool call. Those buckets are always measured against
`windowTokens`, including when the absolute tripwire below fired the first
warning; the `thresholdTokens` section covers what that implies.

The mark follows a real drop back down as well: a compaction that takes context
down two or more buckets — ten points or more — re-arms the guard, so a session
that compacts is warned again on the way back up rather than staying silent
until it reaches its old peak. Smaller fluctuations are ignored, so a reading
oscillating across a bucket boundary cannot re-warn on every tool call.

Below roughly 30 the guard interrupts work that has plenty of room left; above
roughly 70 there may not be enough context left to write a good handoff.

## Stopping at a token count instead of a percentage

`thresholdTokens` is an absolute stopping point. It is unset by default. When
set, the guard fires when **either** tripwire is crossed:

```
ctx >= thresholdTokens          or          ctx * 100 / window >= thresholdPct
```

This is a safety property, not a convenience. An absolute threshold is decided
from the transcript alone, so it still fires when `windowTokens` is wrong — and
the percentage still fires when `thresholdTokens` is set too high. One wrong
value used to be enough to silence the guard. Now it takes two.

When both are crossed, the message names the absolute one and carries the
percentage in the same sentence:

```
session context is at 500000 tokens, past the 400000-token limit (50% of the 1000000-token window).
```

**Set the window and the stopping point together.** If you set
`thresholdTokens` alone and leave a wrong `windowTokens`, the percentage
tripwire can fire well before the token one you chose — *"I said stop at
450,000 and it stopped at 90,000."* That is the safety property working, and the
shape of the message tells you which tripwire fired: the absolute one reports
*"past the 400000-token limit"*, while the percentage one reports *"at 45% of
the 200000-token window (threshold 45%)"* and does not mention
`thresholdTokens` at all. Both name the window they measured against, so the
cause is legible either way.

**Re-warning is still measured against the window.** The 5% buckets described
under Threshold come from the percentage, so a `windowTokens` set far too large
can leave the first absolute warning as the only one you get. Measured against a
100,000,000-token window with `thresholdTokens` at 400,000: the guard fires at
400,000, then stays silent at 900,000 and again at 4,000,000, because all three
are under 5% of that window — the next warning waits until 5,000,000. At a
window that matches the model, the same setting re-warns normally.

`handoff:setup` asks about both together for these reasons.

## Read size

`maxBytes` is how much of the tail of the transcript the guard reads on each
tool call. The default of 8,000,000 is there because the hook runs after *every*
tool call and a long session's transcript reaches tens of megabytes: reading
48MB measured 7.2 seconds, against a hook timeout of 30. Capping it brings the
ordinary case to about 2 seconds.

Lowering it is safe in the sense that matters — if the capped read does not
contain enough readings to take an honest median, the guard re-reads without the
cap rather than answering from a starved window. That fallback costs a second
read, so a value low enough to trigger it routinely is slower than no cap at
all. There is no reason to change this setting unless you have measured a
problem.

## Handoff directory

`handoff.docsDir` is where the handoff document is written. One live handoff per
run — each handoff overwrites the previous one for that run — so it is normally
unambiguous which one to read.
