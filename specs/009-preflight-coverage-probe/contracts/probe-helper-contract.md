# Contract — the probe helper

**Feature**: `009-preflight-coverage-probe` · **Phase**: D

This is the interface `pipeline/tests/preflight.bats` calls, and the one any
future suite that drives the pre-flight probe will call. It is small on purpose:
FR-020 requires that a reader of any converted test still sees the fixture named
at the call site, so the helper must not absorb arguments.

**Every clause below was driven and observed before it was written here.** The
eight shapes in "Conformance" were run against the real script.

---

## Where it lives

`tests/helper.bash` — the file every suite loads (FR-017).

It is placed there rather than in `pipeline/tests/preflight.bats` for two
reasons: FR-017 names that file, and the repository-root resolution the helper
needs (`ROOT`) is already established there at load time. The file's own comment
already anticipates a `PIPELINE` variable beside the existing `HANDOFF` and
`HOOK`.

## What it adds to that file

Three values resolved once at load time, beside the existing `HANDOFF` and
`HOOK`, and one function.

| Name | Value | Why it is needed |
|---|---|---|
| `PIPELINE` | the `pipeline` directory under `ROOT` | the convention `HANDOFF` already sets; anticipated by that file's own comment |
| `PROBE` | `preflight.sh` under `PIPELINE/scripts` | the one path the helper invokes |
| `BASH_ABS` | the absolute path of `bash`, resolved at load time | stripping the search path also removes `bash`; the interpreter must be named absolutely or the probe cannot start |

`BASH_ABS` **must be resolved at load time, not inside a test**, because a test
that has already narrowed its own search path cannot find `bash` to resolve.

### What it removes: the suite's own `PF`

`pipeline/tests/preflight.bats` resolves the probe's path into `PF` in its
`setup()`. After the conversion **nothing reads it** — `PROBE` supersedes it —
so that assignment is removed as dead.

This is the **only** line the conversion removes that is not a probe invocation,
and it is stated here because a check that allows an unnamed exception is not a
check. It is an assignment, not an assertion, so removing it does not breach
FR-019. The quickstart's mechanical-conversion block exempts exactly that one
line and nothing else; without the exemption it would go red on a correct diff.

`FIX` stays — every call site still names its own fixture, which is FR-020. The
suite's header comment stays, because what it explains is still true after the
conversion.

## The function

```
probe [--path <dir>] [probe arguments...]
```

### Behaviour

- Runs the pre-flight probe once, capturing both streams **separately**.
- Leaves the exit status in `status`, the data stream in `output`, and the
  diagnostic stream in `stderr` — **for the calling test**, not for the helper.
- Passes every remaining argument to the probe **verbatim and in order**. It
  adds no argument, removes none, and reorders none.
- With `--path <dir>`, the probe process sees a search path of exactly `<dir>`
  and nothing else. Without it, the probe inherits the caller's search path
  unchanged.

### `--path` cannot collide with a probe flag

The probe's legal flags are the directory, the project-type and the base-branch;
it refuses anything else **by name**. There is no `--path` among them and adding
one would be a change to the probed script, which FR-021 forbids. The option is
recognised only in first position, and only when an argument follows it.

### It is a pass-through, not a wrapper

The helper supplies the `run` invocation and the script path. **It supplies no
probe flag.** In particular it does not supply a base-branch, because FR-013
needs that flag omitted entirely and a helper that supplied it could not express
that call.

This is what makes FR-019's conversion a straight substitution and FR-020 true by
construction: the fixture is still written by the caller, at the call site.

## Two invariants that are not obvious

### `run` must stay at the caller's level inside the function

`bats` does not declare `status`, `output` or `stderr` local, so a `run`
executed inside a function sets them for the calling test. **Measured**, not
assumed.

The corollary is the trap: `run` executed inside a **subshell** sets them in the
subshell, and the calling test sees nothing. The search-path technique recorded
by the previous session wrapped the probe in a subshell that exported the path.
**That shape must not be used here.** The environment is changed for the child
process instead, which achieves the same thing and leaves `run` where it can be
seen.

### A temporary assignment prefix would not work, but this is not one

An earlier trap in this campaign was that a temporary assignment prefix does not
affect a shell builtin's own lookup. That trap is about a builtin in the
*current* shell. The probe is a separate `bash` process, so its own lookup
honours the environment it was born with. Verified: with the path narrowed to an
empty directory, the probe refuses by name.

## Conformance

The helper must satisfy all eight shapes. Each was run against the real script
and passed.

| # | Shape | Why it is in this list |
|---|---|---|
| 1 | a fixture and a base-branch of `main` | 21 of the 24 existing call sites |
| 2 | a fixture, a base-branch, **and** a project-type override | the one existing call site with an extra argument |
| 3 | a fixture whose probe warns | proves the two streams stay separate and the data stream still parses whole |
| 4 | a fixture with the **base-branch omitted entirely** | FR-013; no existing call site has this shape |
| 5 | `--path` at an **empty** directory | FR-004; the probe must refuse by name |
| 6 | `--path` at a directory of shims | FR-011 and FR-012; the probe runs normally while a named tool reads absent |
| 7 | the three refusal shapes — unknown flag, flag without its value, unenterable directory | FR-001 to FR-003; proves a refusal reaches the caller intact |
| 8 | a call made after the test has changed directory | four existing call sites do this; the helper must not depend on the working directory |

The six commands a shim directory must carry for shape 6 are `awk`, `git`,
`grep`, `head`, `jq` and `od` — derived from the probed script's own text, not
guessed. A shim is a two-line script that executes the real tool; a tool whose
mere presence is being tested (the command-line client) needs only to exit zero.

**The shim directory must be a path with no drive letter.** A drive-letter path
used as a search-path entry splits on its own colon into two broken entries, and
then *every* tool reads as absent — including the data tool, so the probe dies
for the wrong reason and the test passes for the wrong cause. The per-test
temporary directory `bats` provides is already in the right form and is cleaned
up for free; use it.

## What the contract does not cover

- **The probed script's own interface is unchanged.** Same flags, same keys, and
  the data stream still parses whole. This feature reads the script (FR-021).
- **No assertion changes.** The conversion of the 24 existing call sites adds,
  removes and alters no assertion, and the test count does not move (FR-019,
  SC-005).
- **The invocation line appears exactly once** after the conversion, as this
  helper's body (SC-004).

## Rejected alternatives

| Alternative | Rejected because |
|---|---|
| Two functions, one plain and one for the narrowed path | The invocation line would then appear twice, which SC-004 forbids. One function with an optional leading option keeps it to one. |
| A helper that supplies the base-branch flag | It could not express FR-013's call, which needs that flag absent. |
| A helper that takes the fixture as a named parameter | It would move the fixture off the call site, which FR-020 forbids. |
| Wrapping the probe in a subshell that exports the path | `run` inside a subshell sets nothing the calling test can read. |
| Reading a global for the narrowed path | Invisible at the call site, and order-dependent between tests. |
| Putting the helper in `pipeline/tests/preflight.bats` | FR-017 names the file every suite loads. |
