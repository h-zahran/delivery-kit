# Measurements: Remove repeated and serial work from a pipeline run

## T003: bash 3.2

Docker image `bash:3.2`, GNU bash 3.2.57, read-only root, no network, with a stand-in `git` that answers only `rev-parse --show-toplevel`. `/tmp` is a tmpfs mounted with `exec`, because the tests' stand-in tools run from there.

| Tree | Check | Result |
|---|---|---|
| Piece 1's text | `tests/run-suite.bats` | `1..14`, 14 ok, rc 0 |
