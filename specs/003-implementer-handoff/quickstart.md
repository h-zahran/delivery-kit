# Quickstart validation — the implementer handoff package

Note: Git Bash commands for the author's machine — substitute your own
bats path elsewhere. CI runs portable equivalents on three platforms.

## 1. The seven names, inside the G section (FR-001)

```bash
g="$(awk '/^\*\*G — implementer gate\.\*\*/,/^\*\*H — implement\.\*\*/' pipeline/skills/pipeline/SKILL.md)"
tail -n 1 <<<"$g" | grep -cF '**H — implement.**'   # 1 — the slice terminated; without this check a reworded H heading silently extends the slice to EOF
for n in "Files to provide" "Repository state" "Instructions" "Forbidden list" "What will bite this feature" 'Validation before "done"' "Report-back contract"; do printf '%s: ' "$n"; grep -cF -- "- **$n**" <<<"$g"; done
# every name: 1 — the same slice-and-bullet form the shipped test uses
```

## 2. The pinned sentences survive, whole (FR-001 / FR-004)

```bash
g="$(awk '/^\*\*G — implementer gate\.\*\*/,/^\*\*H — implement\.\*\*/' pipeline/skills/pipeline/SKILL.md)"
flat="$(tr '\n' ' ' <<<"$g" | tr -s ' ')"
grep -cF 'forbidden list is DERIVED, not hardcoded: the fixed rules (no commit, no push, no branch operations, no pull request) plus whatever `releaseCommand` and `verifyCommand` name, plus any deploy or migration verb found in the tasks file.' <<<"$flat"   # 1
grep -cF '`--auto` never collapses this gate: it spends money.' <<<"$flat"   # 1
grep -cF 'answer later changes, delete the written package file (or stamp it VOID at the top) before proceeding' <<<"$flat"   # 1
grep -cF 'A "handoff" answer parks the run at H:' <<<"$flat"   # 1
# whole-sentence pins on the flattened slice — the shipped test's own
# form; name-only fragments survived polarity inversion, and whole-file
# greps cannot see relocation out of G
```

## 3. The test, red-first then mutation (FR-002 / SC-004)

```bash
bash /c/Users/h_zah/bats/bin/bats --tap pipeline/tests/prose.bats   # 1..9, 9 ok
# red-first: the appended test failed BEFORE the SKILL.md edit (recorded)
# mutation: one name removed -> the new test red; restored -> green (recorded)
```

## 4. The counts (SC-001 / SC-002)

```bash
bash /c/Users/h_zah/bats/bin/bats --tap -r --print-output-on-failure tests handoff/tests pipeline/tests
# expect: 1..119, 119 ok, 0 not ok, 0 non-TAP
# (--tap matters: the interactive pretty formatter prints no plan line,
# and hand-counting its output corrupts the numbers)
```

## 5. The changelog (FR-003)

```bash
grep -n '^## \[' pipeline/CHANGELOG.md | head -3
# [Unreleased] above [1.0.1] above [1.0.0]; no new version heading
```
