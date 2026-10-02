# Contract: `scripts/check-suite.sh`

```text
bash scripts/check-suite.sh <expected> <tap-file>
```

`<tap-file>` is the saved output of the house suite (stdout and stderr). The
script reads it and nothing else; it runs from any directory.

| ID | Input | Exit | Message contains |
|---|---|---|---|
| K1 | plan `1..N` on the first non-blank line, N `ok` lines, only comments and blanks besides — read from the named file, never from stdin | 0 | `suite ok: 1..N, N ok, 0 skipped, 0 not ok, 0 non-TAP` |
| K2 | not exactly two arguments, or `<expected>` not a positive integer | non-zero | `usage` |
| K3 | the file does not exist, cannot be read, or awk fails while reading it (stderr from the read is discarded: the shell's error when it cannot open the file names the path as given, a full path when the caller passes one) | non-zero | `does not exist` or `cannot be read` |
| K4 | the file is empty, or holds only blank lines | non-zero | `empty` |
| K5 | the first non-blank line is not `1..<expected>` | non-zero | `plan line` |
| K6 | a second plan line | non-zero | `plan line` |
| K7 | `ok` count differs from `<expected>` | non-zero | `ok count` |
| K8 | an `ok` line carrying `# skip` (any case) | non-zero | `skipped` |
| K9 | a `not ok` line | non-zero | `not ok` |
| K10 | a non-blank line that is not a plan, `ok`, `not ok` or `#` line | non-zero | `non-TAP` |
| K11 | any of the above with CRLF line ends (a trailing CR is stripped from each line) | the same verdict as with LF | the same |

Every refusal is one line on stderr, prefixed `check-suite.sh: `, and names no
path. The first broken rule in the order K2, K3, K4, K5, K6, K9, K8, K10,
K7 is the one reported: a `not ok`, a skip or a stray line is named before
the `ok` count it also shortens or leaves unchanged.

In the script, each of K2–K11 has exactly one line ending with the comment
`# K<n>`, so the quickstart can remove one rule at a time. A tagged line
holds ONLY its refusal: classifying a line, counting, the reading of the
file and every `next` sit on untagged lines, so deleting a tagged line
still leaves a clean run accepted. There are two exceptions:

- K11 is an exception by nature: its line is the CR strip itself, and
  removing it leaves LF input accepted.
- K3 has a second refusal, the script's last line,
  `die "the TAP file cannot be read"`, for the case where awk itself fails
  and prints no verdict. It carries no tag, so K3 keeps exactly one tagged
  line, and the quickstart's mutant sweep never removes it. The test in
  `tests/check-suite.bats` covers it instead: a stand-in awk that fails.
  With the line deleted the script exits 0 with no output, and the test's
  check for a non-zero status goes red.
