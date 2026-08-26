# Quickstart validation — the implementer key

Note: Git Bash commands for the author's machine — substitute your own
bats path elsewhere. CI runs portable equivalents on three platforms.

## 1. The sites (FR-001 / FR-002)

> Amended at phase M round 4: the value set gained `ask`, so all three
> value-bearing site strings moved; site 2 also gained its `\|` escapes.
> `pipeline/README.md` became a fifth site in the same pass.

```bash
grep -cF '| `implementer` | unset | Pre-answers the G gate: `claude` or `handoff`; `ask` restores the stop |' pipeline/skills/pipeline/SKILL.md   # 1
grep -cF '| `--implementer <claude\|handoff\|ask>` | Pre-answers the G gate, or restores it with `ask`; beats the config key. |' pipeline/skills/pipeline/SKILL.md   # 1
grep -cF '"implementer": null' pipeline/docs/configuration.md   # 1
grep -cF '| `implementer` | Pre-answers the implementer gate: `claude` or `handoff`; `ask` restores the stop; unset means ask. |' pipeline/docs/configuration.md   # 1
grep -cF 'the `implementer` key, or `--implementer`, pre-answers the implementer' pipeline/README.md   # 1
```

## 2. Name-and-default identity across the two files (SC-001)

```bash
grep -oF '`implementer`' pipeline/skills/pipeline/SKILL.md | sort -u
grep -oF '`implementer`' pipeline/docs/configuration.md | sort -u
# both print exactly: `implementer`
grep -c 'claude.*handoff\|handoff.*claude' pipeline/docs/configuration.md   # >= 1 (the value set, present)
grep -c '`ask`' pipeline/docs/configuration.md   # >= 1 (the re-arm value, present)
```

## 3. The quoted G sentences, verbatim (FR-003)

```bash
g="$(awk '/^\*\*G — implementer gate\.\*\*/,/^\*\*H — implement\.\*\*/' pipeline/skills/pipeline/SKILL.md)"
flat="$(tr '\n' ' ' <<<"$g" | tr -s ' ')"
grep -cF 'When `implementer` resolves to `claude` or `handoff` (config or flag), G records that answer in `gates` and does not stop — the choice was typed on purpose.' <<<"$flat"   # 1
grep -cF '`ask` pre-answers nothing: G stops, asks, and records the owner'"'"'s answer in `gates` like any asked gate.' <<<"$flat"   # 1
grep -cF 'a pre-answered `implementer` silences nothing else: cap breaches, hard failures and every other gate still stop exactly as before.' <<<"$flat"   # 1
```

## 4. Nothing moved (SC-002 / SC-003)

```bash
bash "$HOME/bats/bin/bats" --tap pipeline/tests/prose.bats   # 1..11, 11 ok  (was 1..9 before round 4 spent the prose-pin debt)
bash "$HOME/bats/bin/bats" --tap -r --print-output-on-failure tests handoff/tests pipeline/tests
# expect: 1..121, 121 ok, 0 not ok, 0 non-TAP  (was 1..119; +2 by the
#         owner-ordered test-debt spend at phase M round 4)
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
