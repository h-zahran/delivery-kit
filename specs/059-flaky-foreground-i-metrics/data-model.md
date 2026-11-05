# Data model: 059

## In the state file: `measurements.i`

```json
{
  "parts": {
    "contract": {"status": "done", "started": 1762340000, "seconds": 812},
    "bugs": {"status": "skipped", "reason": "no-code-review-skill"},
    "fixes": {"status": "started", "started": 1762341000},
    "recheck": {"status": "missing"}
  },
  "findings": {
    "status": "read",
    "byLens": {
      "contract": {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 0, "fixed": 3, "deferred": 0, "declined": 0}
    },
    "lines": 3,
    "unreadableLines": 1,
    "unreadable": [7]
  },
  "earlier": [
    {"part": "contract", "status": "done", "started": 1762330000, "seconds": 700}
  ]
}
```

**Parts**, one list in the script: `contract`, `security`, `tests`, `bugs`, `simplify`, `fixes`, `recheck`.

**A part's states**:

| State | Written by | Meaning |
|---|---|---|
| `started` | `dispatch` or `start` | Clock running. The gate does not accept it. |
| `done` | `done` | `seconds` holds whole wall seconds. |
| `skipped` | `skip <reason>` | It did not run, by rule. No seconds. Only `bugs`, `simplify`, `fixes` and `recheck` can be skipped. |
| `missing` | `unmeasured` | It ran or may have run, and nobody has a number. No seconds. |
| no entry | nothing | Not recorded. The gate refuses. |

**Validation**: a reason matches `[a-z0-9-]+`, 1 to 40 bytes. Severities are the four words of `pipeline:spec-review`. Lenses in a finding line are the five review lenses; the `recheck` pass's findings are lens `bugs`.

## In `pipeline-run.json`: `phaseI`, derived on every `metrics`

```json
{
  "status": "measured",
  "parts": {
    "contract": {"status": "done", "seconds": 812},
    "bugs": {"status": "skipped", "reason": "no-code-review-skill", "seconds": null},
    "recheck": {"status": "missing", "seconds": null}
  },
  "findings": {
    "status": "read",
    "byLens": {"contract": {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 0, "fixed": 3, "deferred": 0, "declined": 0}, "bugs": null},
    "unreadableLines": 0,
    "unreadable": []
  },
  "accountedSeconds": 2100,
  "earlier": []
}
```

- With no `measurements.i`: `{"status": "missing"}`. So a run from an older pipeline stays valid and reads as missing.
- Every part of the list appears. A part with no record reads `{"status": "missing", "seconds": null}`.
- `findings.status` is `read` or `missing`. The state file holds counts only for a lens with a line. In `phaseI`, a lens with status `done` and no line has zeros. Any other lens with no line has `null`, never zeros. A lens with a line keeps its counts, so a lens with no clock keeps what it found.
- `accountedSeconds`: the longest of the five lenses, because they run at once, plus `fixes`, plus `recheck`. A skipped part adds nothing. It is `null` when any part is not `done` or `skipped`. Read it against `phases.I.seconds`.

## In the run directory: `findings-I.txt`

One line per finding: `SEVERITY | lens | file:line | finding | outcome`. Blank lines and lines that start with `#` are allowed. An empty file is a real zero. The file may not be a link, and may not pass 262,144 bytes. `unreadable` names at most the first 100 bad lines, and `unreadableLines` counts them all.
