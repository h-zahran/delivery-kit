# Command contract: `progress.sh i-measure`

```text
progress.sh i-measure <feature> dispatch
progress.sh i-measure <feature> start <part>
progress.sh i-measure <feature> done <part> [--seconds <n>]
progress.sh i-measure <feature> skip <part> <reason>
progress.sh i-measure <feature> unmeasured <part>
progress.sh i-measure <feature> unmeasured findings
progress.sh i-measure <feature> findings
```

`<part>` is one of `contract`, `security`, `tests`, `bugs`, `simplify`, `fixes`, `recheck`. Any other word is refused, and the refusal lists them, shown so that no raw control byte reaches a terminal.

| Form | Effect | stdout | Exit |
|---|---|---|---|
| `dispatch` | In one write: each part holding a result moves to `earlier`, and so does a findings read; the fixes, the recheck and the findings are cleared; the five lenses start. A link at `findings-I.txt` is refused. | One line per moved record, then `dispatched`. | 0 or 1 |
| `start <part>` | Starts one part. A part holding a result moves to `earlier`. | One line per moved record, then `<part>: started`. | 0 |
| `done <part>` | Records `seconds` from the part's start, or the `--seconds` value, which may not pass that time. | `<part>: <n> s` | 0 or 1 |
| `done <part>`, no start recorded | Refused. It names `start` and `unmeasured`. | nothing | 1 |
| `done <part>`, already done | Refused. It prints the recorded seconds. Nothing changes. | nothing | 1 |
| `done <part>`, the clock moved back | Refused. It names `unmeasured`. | nothing | 1 |
| `skip <part> <reason>` | Records `skipped`, for `bugs`, `simplify`, `fixes` or `recheck`. A result it replaces moves to `earlier`. Another part or a bad reason is refused. | One line per moved record, then one line. | 0 or 1 |
| `unmeasured <part>` | Records `missing`. A result it replaces moves to `earlier`. A `missing` or `started` record holds no result, and is simply replaced. | One line per moved record, then one line. | 0 |
| `unmeasured findings` | Records the findings as `missing`. A read it replaces moves to `earlier`. | One line per moved record, then one line. | 0 |
| `findings` | Reads `findings-I.txt` in the run directory and records the counts. A read it replaces moves to `earlier`. | One line per moved record, `findings: <n> lines read, <m> unreadable`, and each named line's number. | 0, or 1 when the file is absent, a link, not a file, or over 262,144 bytes |

Messages never print a finding's text or a machine path. The state write goes through the same lock and temporary file as every state write.

# Gate: `progress.sh phase-done <feature> I`

- When every part has `done`, `skipped` or `missing`, and `findings.status` is `missing`, or `read` with no unreadable line: as today.
- Otherwise: refused, exit 1, the state file unchanged. The message names each part or the findings record that is absent, and names `i-measure`.
- A run with `measurements.i` absent **and** I recorded in `completed_phases` is past the gate already: a re-done `phase-done I` stands as today. Any other run that re-enters I is gated. A run on an older pipeline that re-enters I records its parts and its findings with `unmeasured`, and that reads as missing.

# `state-set`, changed behaviour

`state-set <feature> measurements i ...` is refused, and so is a whole `measurements` write that changes `.i`. Other keys of `measurements` are written as before.

# `suite-base start`, changed behaviour

- The runner and the command each lead a process group of their own, on every system, by job control.
- The command starts with `SIGINT` in the state the caller had. `base_start` and `base_run` add no ignore of their own.
- The printed lines, the files in the bookkeeping folder, and the exit statuses do not change. One limit is new: started by hand from a terminal, a command that reads that terminal stops until the wait's limit, as it always has where `setsid` is absent. A pipeline run has no controlling terminal, measured in the Bash tool.
- A stop ends the command and everything in its group: TERM, then KILL 8 seconds later, and `base_stop`'s KILL at 10 s if the runner itself is stuck.

# `pipeline-run.json`

New derived key `phaseI`. See [data-model.md](../data-model.md).
