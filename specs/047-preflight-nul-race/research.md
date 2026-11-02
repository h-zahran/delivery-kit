# Research: The constitution NUL check answers the same way under any load

Measurements are a record of runs on 2026-11-02 at `e255029`, Ubuntu (uutils coreutils 0.10.0, bash 5).

## R1. The fix

- **Decision**: `hex="$(head -c 4096 "$const_file" 2>/dev/null | od -An -tx1)" || hex=''`, then `case "$hex" in *' 00'*) warn …;; *) <the existing parse>;; esac` (or an `if` on the same `case`).
- **Rationale**: the command substitution reads all of `od`'s output, so nothing closes the pipe early and no SIGPIPE can reach `od`. `|| hex=''` keeps `set -e` from ending the script when `head` fails on an unreadable file, matching today's behaviour (no NUL found, go on to the parse). A `case` match on `*' 00'*` finds the same bytes `grep ' 00'` found: `od -An -tx1` writes bytes as space-led pairs, so a NUL is always ` 00`.
- **Alternatives considered**: `grep -c ' 00'` (reads all input, but its exit status 1 on zero matches needs its own handling under `set -e`); `set +o pipefail` around the line (hides other failures, and a toggle is easy to leave off); `tr -d '\000' | cmp` (more processes, less obvious).

## R2. A deterministic reproduction

- **Decision**: a fake `od` first on `PATH` that drains stdin, prints ` ff fe 23 00`, then about 1 MB of non-NUL lines. Real `grep -q` matches the first line and exits; the fake keeps writing past the 64 KB pipe buffer and takes SIGPIPE every time.
- **Measured**: the old pipeline found the NUL 0 of 20 times with the fake `od`; the new capture-then-match found it 20 of 20.
- **Rationale**: the bug depends on scheduling; the fake removes the scheduling by making the writer's output far larger than anything the pipe can hold after the reader leaves.
- The test uses the repository's existing pattern for a fake program on `PATH` (the jq-without-`-b` test in `preflight.bats`), which runs on all three CI systems.

## R3. The refusing walk

- **Decision**: `tests/pipefail.bats` with a helper that reads file paths on stdin, keeps the files whose text holds `pipefail`, and names each line that pipes into `grep` with `-q` (alone or in a flag group) or `--quiet`. The real test feeds it `git ls-files '*.sh' '*.bash'` minus `.specify/` and test directories; fixture tests feed it planted files. It fails on zero files kept.
- **Rationale**: derived coverage (principle V). Reading paths from stdin lets the same helper be tested on fixtures without a git repository.
- **Sweep result at `e255029`**: one such line exists, `pipeline/scripts/preflight.sh:322` — the bug itself.

## R4. The release

- **Decision**: the fix commit adds a `### Fixed` entry under `## [Unreleased]` in `pipeline/CHANGELOG.md`; the release commit (`release: pipeline 1.7.2`) turns that heading into `## [1.7.2] - <date>`, sets `"version": "1.7.2"` in `pipeline/.claude-plugin/plugin.json` and the pipeline entry of `.claude-plugin/marketplace.json` (with `sed`, never `jq`, which reformats the `tags` arrays). `bash scripts/check-versions.sh` must pass. After merge, the tag `pipeline-v1.7.2` is made from `origin/main` after a fetch, and CI's "tag matches the manifest version" STEP conclusion must read `success` (it reads `skipped` on non-tag runs).
- **Rationale**: the repository's recorded release recipe (1.7.1 used the same three-file release commit).
