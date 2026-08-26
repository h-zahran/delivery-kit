# Quickstart validation — constitution probe

Note: Git Bash commands for the author's machine — substitute your own
bats path elsewhere. CI runs portable equivalents on three platforms.

## 1. The boolean, both ways (FR-001 / SC-002)

```bash
bash pipeline/scripts/preflight.sh --dir pipeline/tests/fixtures/constitution-unset | jq .speckit.constitutionSet   # false
bash pipeline/scripts/preflight.sh --dir pipeline/tests/fixtures/constitution-set   | jq .speckit.constitutionSet   # true
bash pipeline/scripts/preflight.sh | jq .          # this repo: parses; constitutionSet false (template still unfilled)
```

## 2. The two tests, and the count (FR-002 / SC-001)

```bash
bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats     # all ok, count grew by 2
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
# expect: 1..118, 118 ok, 0 not ok, 0 non-TAP
```

Red-first evidence: the run artifacts record both tests failing before
the script change (SC-004).

## 3. The prose (FR-003 / SC-003)

```bash
grep -n "not set — plan gates run against an empty document" pipeline/skills/pipeline/SKILL.md   # 1 hit
grep -n "speckit-constitution" pipeline/skills/pipeline/SKILL.md                                  # the one-time offer
bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats                                       # 1..8 ok
```

## 4. The changelog (FR-004)

```bash
grep -n '^## \[' pipeline/CHANGELOG.md | head -3
# [Unreleased] above [1.0.1] above [1.0.0]; no new version heading
```
