# Quickstart: prove 060

From the repository root, on the feature branch:

```bash
"$HOME/bats/bin/bats" -f 'phase time' pipeline/tests/progress-git.bats
bash scripts/run-suite.sh > "$(mktemp)"
```

Expected: the first prints only `ok` lines, and the second exits 0.
