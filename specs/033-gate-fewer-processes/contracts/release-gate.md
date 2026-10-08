# Contract: the release gate and its walk

## `scripts/check-versions.sh` (unchanged interface)

- Called as `bash scripts/check-versions.sh` and `bash
  scripts/check-versions.sh --released <plugin>`, from the repository
  root, by CI's version job, its release-tag job, and the suite.
- Standard output, standard error and exit status: byte-identical to
  `2b38f74` on every tree, except the Windows divergence (research R5).
- New, both only in the release form, both reached only through a broken
  installation of the gate itself:
  - `<plugin>: the heading walk check-versions-walk.awk beside the gate could not be read — this tree is NOT released`, exit 1
  - `<plugin>: the heading walk did not run to the end — this tree is NOT released`, exit 1
- `jq` processes per run: one, plus one per plugin directory holding a
  `plugin.json`.

## `scripts/check-versions-walk.awk` (new)

- Run only by the gate, as `awk -f <file> <changelog>`; by tests as `awk
  -f <file>` on standard input.
- Environment: `DATED_RE` (the dated heading pattern), `LINE_LIMIT`
  (bytes), `QUOTE_CUT` (bytes), `LC_ALL=C`.
- Output: nothing for a changelog it accepts; otherwise one refusal text,
  masked by its own `show()`, without the gate's `<plugin>: ` prefix, its
  `##[` step, or its ` — this tree is NOT released` suffix.
- Exit status 0 whatever it judges.
