# Measurements: Phase B records config before the base suite starts

Measured 2026-11-04 on Linux, local bats, from the repository root. The base commit is `b80ae0e78345063e09bbd9cbd9a73387a41bb0f0`.

## T001: the test is red before the sentence exists

Command: `bash "$HOME/bats/bin/bats" --filter 'B records config before' --print-output-on-failure pipeline/tests/prose.bats`

```
1..1
not ok 1 B records config before it starts the base suite run
# phase B no longer says to record config
```

Exit status 1. It is red for the right reason: the sentence is absent.
