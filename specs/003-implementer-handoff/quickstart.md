# Quickstart validation — the implementer handoff package

Note: Git Bash commands for the author's machine — substitute your own
bats path elsewhere. CI runs portable equivalents on three platforms.

## 1. The seven names (FR-001)

```bash
for n in "Files to provide" "Repository state" "Instructions" "Forbidden list" "What will bite this feature" 'Validation before "done"' "Report-back contract"; do grep -cF "$n" pipeline/skills/pipeline/SKILL.md; done
# every count >= 1
```

## 2. The pinned sentences survive (FR-001)

```bash
grep -c "never collapses this gate: it spends money" pipeline/skills/pipeline/SKILL.md   # 1
grep -c "stamp it VOID at the top" pipeline/skills/pipeline/SKILL.md                     # 1
grep -c "DERIVED, not hardcoded" pipeline/skills/pipeline/SKILL.md                       # 1
```

## 3. The test, red-first then mutation (FR-002 / SC-004)

```bash
bash /c/Users/h_zah/bats/bin/bats pipeline/tests/prose.bats   # 1..9, 9 ok
# red-first: the appended test failed BEFORE the SKILL.md edit (recorded)
# mutation: one name removed -> the new test red; restored -> green (recorded)
```

## 4. The counts (SC-001 / SC-002)

```bash
bash /c/Users/h_zah/bats/bin/bats -r --print-output-on-failure tests handoff/tests pipeline/tests
# expect: 1..119, 119 ok, 0 not ok, 0 non-TAP
```

## 5. The changelog (FR-003)

```bash
grep -n '^## \[' pipeline/CHANGELOG.md | head -3
# [Unreleased] above [1.0.1] above [1.0.0]; no new version heading
```
