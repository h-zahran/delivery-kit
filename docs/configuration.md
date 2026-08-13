# Configuration

All settings live in one file, `.delivery-kit.json`, at your repository root.
**It is optional** — with no file present the defaults apply and the guard works.

```json
{
  "contextGuard": { "windowTokens": 200000, "thresholdPct": 45 },
  "handoff":      { "docsDir": "docs/handoffs" }
}
```

Unknown keys are ignored, never rejected — later versions add keys to this same
file, and an old plugin reading a newer file must not break.

## Precedence

Defaults → `.delivery-kit.json` → environment variables. The environment wins,
which is what makes a temporary override possible without editing a committed
file.

| Setting | Default | Environment variable |
|---|---|---|
| `contextGuard.windowTokens` | `200000` | `DELIVERY_KIT_WINDOW_TOKENS` |
| `contextGuard.thresholdPct` | `45` | `DELIVERY_KIT_THRESHOLD_PCT` |
| `contextGuard.maxBytes` | `8000000` | `DELIVERY_KIT_MAX_BYTES` |
| `handoff.docsDir` | `docs/handoffs` | `DELIVERY_KIT_HANDOFF_DIR` |

A value that is not a positive integer is ignored and the previously resolved
value is kept — the default, or the config file's value if an environment
variable is the thing that is wrong. The same applies to a `thresholdPct` above
100. Such a threshold is not unreachable — context above 100% of the configured
window is exactly what the misconfiguration note below reports — but it can only
be reached once context has already overflowed the window, which is far too late
to be useful. In practice the guard would never fire in time, silently, which is
the one thing a settings file must not be able to do. A malformed config file is
ignored entirely. No invalid value can disable the guard. A value that is valid but wrong is a different matter, and
the next section is about the one case that bites.

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
nagged on every tool call.

The mark follows a real drop back down as well: a compaction that takes context
down two or more buckets — ten points or more — re-arms the guard, so a session
that compacts is warned again on the way back up rather than staying silent
until it reaches its old peak. Smaller fluctuations are ignored, so a reading
oscillating across a bucket boundary cannot re-warn on every tool call.

Below roughly 30 the guard interrupts work that has plenty of room left; above
roughly 70 there may not be enough context left to write a good handoff.

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
