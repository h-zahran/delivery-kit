# Quickstart validation — pipeline 1.0.1

Prerequisites: repo root `D:\Github\delivery-kit`, branch
`001-pipeline-101-polish`, bats 1.11.0 at the house path.

Note: these are Git Bash commands for the author's machine — substitute
your own bats path elsewhere. Run the greps from bash, not PowerShell
(PowerShell eats the backtick escapes). CI runs portable equivalents on
ubuntu, macos and windows.

## 1. The four new orchestrator sentences exist (FR-001..FR-004)

```bash
grep -c "With \`releaseCommand\` unset there is nothing to publish" pipeline/skills/pipeline/SKILL.md   # expect 1
grep -c "extra evidence, not the configured check" pipeline/skills/pipeline/SKILL.md                    # expect 1
grep -c "a stale package addressed to another model" pipeline/skills/pipeline/SKILL.md                  # expect 1
grep -c "A missing tool is its own question" pipeline/skills/pipeline/SKILL.md                          # expect 1
```

## 2. Pinned strings survived (SC-002)

```bash
bash /c/Users/h_zah/bats/bin/bats pipeline/tests/prose.bats
# expect: 1..8, all ok
```

## 3. README spelling (FR-005 / SC-005)

Read `pipeline/README.md` "How it runs": three examples spell
`/pipeline:pipeline …`; any short-form sentence matches the measurement
recorded in [research.md](research.md) R1 / this run's state.

## 4. Version agreement (FR-006 / SC-004)

```bash
jq -r '.plugins[] | "\(.name) \(.version)"' .claude-plugin/marketplace.json
# expect: handoff 2.1.0 / pipeline 1.0.1
jq -r .version pipeline/.claude-plugin/plugin.json
# expect: 1.0.1
head -40 pipeline/CHANGELOG.md   # ## [1.0.1] - <date> sits above ## [1.0.0]
```

## 5. Full house suite (SC-003)

```bash
cd /d/Github/delivery-kit
bash /c/Users/h_zah/bats/bin/bats -r --print-output-on-failure tests handoff/tests pipeline/tests
# expect: 1..116, 116 ok, 0 not ok, 0 non-TAP lines
```
