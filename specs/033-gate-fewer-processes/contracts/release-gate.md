# Contract: the release gate and its walk

## `scripts/check-versions.sh` (unchanged interface)

- Called as `bash scripts/check-versions.sh` and `bash
  scripts/check-versions.sh --released <plugin>`, from the repository
  root, by CI's version job, its release-tag job, and the suite.
- Standard output, standard error and exit status: byte-identical to
  `2b38f74` on every tree, except the Windows divergence (research R5).
- New, both only in the release form, both reached only through a broken
  installation of the gate itself:
  - `<plugin>: the heading walk check-versions-walk.awk beside the gate could not be read — this tree is NOT released`, exit 1:
    the walk file is missing, not a regular file, cannot be opened, or
    the gate was run from standard input and has no path to find it by
  - `<plugin>: the heading walk did not run to the end — this tree is NOT released`, exit 1:
    awk exited non-zero, or the walk's output does not end with its end
    token (an empty walk file, or one of comments alone)
- `jq` processes per run: one, plus one per plugin directory holding a
  `plugin.json`.

## `scripts/check-versions-walk.awk` (new)

- Run only by the gate, as `awk -f <file> <changelog>`; by tests as `awk
  -f <file>` on standard input.
- Environment: `DATED_RE` (the dated heading pattern), `LINE_LIMIT`
  (bytes), `QUOTE_CUT` (bytes), `LC_ALL=C`.
- Output: one refusal text for a changelog it refuses, nothing for one it
  accepts, and then, always as the last line, `WALK-END`. The refusal is
  masked by its own `show()`, without the gate's `<plugin>: ` prefix, its
  `##[` step, or its ` — this tree is NOT released` suffix. The gate, and
  the tests' `walk_on`, take the token off and refuse an output without it.
- Text: a header of `#` comments, the old program byte for byte, then one
  line, `END { print "WALK-END" }`.
- Exit status 0 whatever it judges.
