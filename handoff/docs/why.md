# Why this exists

## The measurement

1,410 prompts across 67 sessions of real work on a production codebase were
categorised by what the human was actually asking for. The distribution was
lopsided in a way that was not obvious from inside any single session:

| Pattern | Count | What it became |
|---|---:|---|
| Continuation nudges (`continue`, `keep going`, `/resume`) | 121 | The context guard + handoff |
| Device test → screenshot → paste → describe | 107 | Runtime verification (not in v1) |
| Commit → push → PR → CI choreography | 85 | Shipping automation (not in v1) |
| "Fix all findings, carefully and completely" | 62 | Finding remediation (not in v1) |
| "How do I hand off / make you remember?" | 30 | The handoff skill |
| "You said done but it isn't on the device" | 13 + 4 interrupts | The verification gate (not in v1) |

121 continuation nudges is 8.5% of everything typed. That is not a preference
about workflow; it is a measurable tax.

## Why a session ending is expensive

A session that runs out of context does not stop at a clean boundary. It stops
wherever it happened to be, which routinely means uncommitted edits, a test run
whose result nobody recorded, and a decision taken for a reason that now exists
only in a transcript nobody will re-read. The next session then spends its first
several thousand tokens rediscovering the state of the work rather than doing
the work.

The fix is not a bigger context window. It is noticing early enough to stop on
purpose.

## Why the median, not the last reading

The guard computes context as `input_tokens + cache_read_input_tokens +
cache_creation_input_tokens` over main-chain assistant messages, and takes the
**median of the last five** such readings rather than the most recent one.

This is not caution for its own sake. A single request that re-sends the full
raw history — a review or advisory tool that forwards the transcript — inflates
one reading far above the live context. On 2026-08-07 a last-reading
implementation fired the guard at "45%" while the session was genuinely at 24%,
and ended a session that had more than half its context left. The median makes
one anomalous reading harmless. It is the highest-value test in the repository.

## Why the window default is 200,000 and not larger

Being wrong in the two directions is not symmetric. A window set too small fires
the guard early: annoying, and instantly visible — the warning names the window
it used, and if context ever exceeds that window it is reported outright. A
window set too large never fires it at all: silent, total, discovered only when
the session dies, and detectable by nothing the guard can observe. That
asymmetry is the whole argument for a conservative default: it puts the error
where you will notice it. See [configuration.md](configuration.md).

## Why `jq` is a dependency rather than a fallback

The hook parses a JSONL transcript. Reimplementing that in POSIX shell would be
fragile in exactly the place correctness matters, and a guard that quietly
mis-parses is worse than no guard. So `jq` is required, its absence is detected,
and the detection is tested — including on Windows, where Git Bash does not ship
it.
