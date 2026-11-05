# Command contract: `progress.sh i-measure`

```text
progress.sh i-measure <feature> dispatch
progress.sh i-measure <feature> start <part>
progress.sh i-measure <feature> done <part>
progress.sh i-measure <feature> skip <part> <reason>
progress.sh i-measure <feature> unmeasured <part>
progress.sh i-measure <feature> findings
```

`<part>` is one of `contract`, `security`, `tests`, `bugs`, `simplify`, `fixes`, `recheck`. Any other word is refused, and the refusal lists them.

| Form | Effect | stdout | Exit |
|---|---|---|---|
| `dispatch` | Starts the five lens parts at one time. A part already recorded moves to `earlier`. | One line per moved part, then `dispatched`. | 0 |
| `start <part>` | Starts one part. A part already recorded moves to `earlier`. | One line. | 0 |
| `done <part>` | Records `seconds` from the part's start. | `<part>: <n> s` | 0 |
| `done <part>`, no start recorded | Refused. It names `start` and `unmeasured`. | nothing | 1 |
| `done <part>`, already done | Refused. It prints the recorded seconds. Nothing changes. | nothing | 1 |
| `skip <part> <reason>` | Records `skipped`. A bad reason is refused. | One line. | 0 |
| `unmeasured <part>` | Records `missing`. | One line. | 0 |
| `findings` | Reads `findings-I.txt` in the run directory and records the counts. It may run again; the last read stands. | `findings: <n> lines read, <m> unreadable`, and each unreadable line's number. | 0, or 1 when the file is absent |

Messages never print a finding's text or a machine path. The state write goes through the same lock and temporary file as every state write.

# Gate: `progress.sh phase-done <feature> I`

- When `timestamps.I.started` was stamped and every part has `done`, `skipped` or `missing`, and `findings.status` is `read`: as today.
- Otherwise: refused, exit 1, the state file unchanged. The message names each part or the findings record that is absent, and names `i-measure`.
- A run with `measurements.i` absent **and** I recorded in `completed_phases` is past the gate already: a re-done `phase-done I` stands as today. A run on an older pipeline that re-enters I records its parts with `unmeasured`, and that reads as missing.

# `suite-base start`, changed behaviour

- The runner and the command each lead a process group of their own, on every system, by job control.
- The command starts with `SIGINT` in the state the caller had. `base_start` and `base_run` add no ignore of their own.
- The printed lines, the files in the bookkeeping folder, and the exit statuses do not change.
- A stop still ends the command and everything in its group, with TERM and then KILL at 10 s.

# `pipeline-run.json`

New derived key `phaseI`. See [data-model.md](../data-model.md).
