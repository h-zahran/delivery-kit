# Quickstart: validating the forked-skill DONE fix

Run from the repository root.

```bash
claude plugin validate mission-control; echo "validate rc=$?"
claude plugin test mission-control 2>&1 | tail -4
bash scripts/check-versions.sh; echo "versions rc=$?"
```

Expected: validate passes; the test run ends `N pass`, `0 fail`; versions rc 0
with mission-control at 0.9.7.

The full suite is the four bats roots and mission-control's tests:

```bash
out="$(mktemp)"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests team/tests > "$out" 2>&1 && claude plugin test mission-control >> "$out" 2>&1; echo "rc=$?"
```
