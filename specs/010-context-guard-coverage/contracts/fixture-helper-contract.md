# Contract — the two fixture helpers

**Feature**: `010-context-guard-coverage` · **Phase**: D

Both live in `tests/helper.bash`, the file every suite loads (FR-010). Both were
driven against real call shapes before this contract was written; the
Conformance section lists what was run.

---

## `write_config <path> <body>`

Writes `{"contextGuard":<body>}` and a newline to `<path>`.

### Both parameters are required by measurement, not by taste

**The path**, because the convertible sites do **not** all write the same file:

| Target | Sites |
|---|---|
| the repository configuration file, guard key only | 22 |
| the **user** configuration file, under the home directory | **4** |

Those four are what prove the precedence order between user and repository
configuration. A helper that hardcoded the repository path could not express
them at all — it would have to leave four sites unconverted, or silently write
the wrong file and break the very test that checks precedence.

**The body**, because there are **eighteen distinct bodies** across the sites
the helper converts — nineteen exist in the suite, and the nineteenth belongs
to the patch-file site that is deliberately not converted. What repeats is the
wrapper, not the setting. Several bodies
are deliberately *invalid* — a leading-zero number, a zero window, an
out-of-range threshold — because they test the validator. A helper that
normalised or reconstructed the body would quietly repair exactly the inputs
those tests exist to reject.

So the helper does the one thing that is genuinely common — the wrapper — and
nothing else.

### It is byte-identical to what it replaces

Verified with `cmp`, not by eye: the helper's output and the literal `printf` it
replaces produce identical files. That is what makes FR-013's conversion
mechanical rather than merely equivalent-looking.

### The format-substitution site needs no exception

One convertible site builds its body with a substitution rather than a
literal. Because the body is a string parameter, the caller interpolates before
calling and the helper is unchanged:

```
cap="$(bytes_of "$t" 1)"
write_config "$TEST_DIR/.delivery-kit.json" \
  "$(printf '{"windowTokens":100000,"thresholdPct":1,"maxBytes":%s}' "$cap")"
```

The example above is the shape actually shipped. An earlier draft showed the
same body written with escaped inner quotes; both interpolate before calling,
which is the property this section asserts, but the document and the code
should not disagree about the one site the document singles out — and a
`printf` template reads better than a line of backslash-escaped quotes.

Measured: this site converts cleanly and needs no exception. (FR-012a first
guessed this would be the third exception. It is not — the third is a site whose
object also carries a `profile` key, and only running the conversion found it.)

### It does not hide the target

The caller writes the path, so a reader of any converted site still sees which
file that site writes (FR-014). That is the same reason the Phase 9 helper was a
pass-through, and it is why the four user-configuration sites remain visibly
different from the twenty-two repository ones.

---

## `bytes_of <file> <lines>`

Returns the byte count of the last `<lines>` lines of `<file>`.

**Four call sites.** This document says four rather than implying volume,
because a requirement justified by a false number is one nobody can check
(FR-012). It earns its place on two other grounds:

- **Naming.** `bytes_of "$t" 8` says what it means; the idiom it replaces —
  three commands piped, the last one stripping whitespace — does not.
- **One definition.** The trailing whitespace strip is load-bearing on this
  platform and easy to drop when copying. One copy cannot be copied wrongly.

Verified to match the idiom **exactly**, across several line counts, rather
than assumed.

---

## What neither helper does

- **Neither is applied to the THREE exception sites.** Each carries a top-level
  key the guard does not own, or writes to a file that is not a configuration
  file. Two were found by reading the targets; the third only by **running** the
  conversion and asserting its counts. FR-011a pins this.
- **Neither changes an assertion.** The conversion is a substitution; the test
  count does not move (FR-013, SC-006).
- **Neither touches the hook.** `handoff/hooks/context-guard.sh` is out of scope
  for this phase (FR-015).

## Conformance

Six shapes, all run and passing:

| # | Shape | Why it is in this list |
|---|---|---|
| 1 | the common repository-configuration write | 22 of the 26 convertible sites |
| 2 | a write to the **user** configuration file | the 4 sites a hardcoded path could not express |
| 3 | a body that is deliberately **invalid** | proves the helper does not repair what the validator must reject |
| 4 | a body built by interpolation | the one format-substitution site, FR-012a |
| 5 | `bytes_of` against the idiom it replaces, several line counts | proves equivalence rather than assuming it |
| 6 | `cmp` against the literal `printf` | proves byte-identity, which is what "mechanical" has to mean |

## Rejected alternatives

| Alternative | Rejected because |
|---|---|
| A helper that hardcodes the repository configuration path | Four sites write the user file; it could not express them, and those four are the precedence test |
| A helper that takes keys and values and builds the body | Nineteen bodies, several deliberately invalid — it would repair the inputs the validator tests exist to reject |
| A helper that also covers the three exception sites | Each writes a key the guard does not own, or writes a non-configuration file; expressing them makes this a JSON writer |
| Leaving `bytes_of` inline because four is a small number | The whitespace strip is load-bearing and easy to drop when copied; one definition cannot be copied wrongly |
