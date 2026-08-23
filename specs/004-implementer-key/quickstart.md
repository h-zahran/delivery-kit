# Quickstart validation — the implementer key

Note: Git Bash commands for the author's machine — substitute your own
bats path elsewhere. CI runs portable equivalents on three platforms.

## 1. The four sites (FR-001 / FR-002)

```bash
grep -cF '| `implementer` | unset | Pre-answers the G gate: `claude` or `handoff` |' pipeline/skills/pipeline/SKILL.md   # 1
grep -cF '| `--implementer <claude|handoff>` | Pre-answers the G gate; beats the config key. |' pipeline/skills/pipeline/SKILL.md   # 1
grep -cF '"implementer": null' pipeline/docs/configuration.md   # 1
grep -cF '| `implementer` | Pre-answers the implementer gate: `claude` or `handoff`; unset means ask. |' pipeline/docs/configuration.md   # 1
```

## 2. Name-and-default identity across the two files (SC-001)

```bash
grep -oF '`implementer`' pipeline/skills/pipeline/SKILL.md | sort -u
grep -oF '`implementer`' pipeline/docs/configuration.md | sort -u
# both print exactly: `implementer`
grep -c 'claude.*handoff\|handoff.*claude' pipeline/docs/configuration.md   # >= 1 (the value set, present)
```

## 3. The quoted G sentences, verbatim (FR-003)

```bash
g="$(awk '/^\*\*G — implementer gate\.\*\*/,/^\*\*H — implement\.\*\*/' pipeline/skills/pipeline/SKILL.md)"
flat="$(tr '\n' ' ' <<<"$g" | tr -s ' ')"
grep -cF 'When `implementer` is set (config or flag), G records the configured answer in `gates` and does not stop — the choice was typed on purpose.' <<<"$flat"   # 1
grep -cF 'silences nothing else: cap breaches, hard failures and every other gate still stop exactly as before.' <<<"$flat"   # 1
```

## 4. Nothing moved (SC-002 / SC-003)

```bash
bash /c/Users/h_zah/bats/bin/bats --tap pipeline/tests/prose.bats   # 1..9, 9 ok
bash /c/Users/h_zah/bats/bin/bats --tap -r --print-output-on-failure tests handoff/tests pipeline/tests
# expect: 1..119, 119 ok, 0 not ok, 0 non-TAP — growth exactly zero
grep -cF '| Implementer | G |' pipeline/skills/pipeline/SKILL.md   # 1, byte-identical
git status --porcelain -- handoff/   # empty: handoff/** untouched
```

## 5. The changelog (FR-005)

```bash
grep -n '^## \[' pipeline/CHANGELOG.md | head -3
# [Unreleased] above [1.0.1] above [1.0.0]; no new version heading
```

## 6. The field test (SC-004) — run evidence, not a command

The run's own G gate is answered "handoff": the package file lands
under `.delivery-kit/runs/004-implementer-key/`, the run parks at H
with the lock released, the external implementer's report and the
resume's verification are recorded in tasks.md Completion notes.
