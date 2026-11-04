# Quickstart: validate phase B's order

Run from the repository root.

## The test passes on the shipped skill

```bash
bash "$HOME/bats/bin/bats" --filter 'B records config before' pipeline/tests/prose.bats
```

Expected: plan line `1..1`, one `ok`.

## The skill reads in the right order

```bash
awk '/^\*\*B — specify\./{f=1} /^\*\*C — clarify/{f=0} f' pipeline/skills/pipeline/SKILL.md | grep -n 'Record `config` here\|progress.sh suite-base\|suite-base <feature> start'
```

Expected: the line with ``Record `config` here`` comes before the start command's lines.

## The size limit holds

```bash
wc -c < pipeline/skills/pipeline/SKILL.md
```

Expected: at most 65,535.

## progress.sh did not change

```bash
git diff --stat b80ae0e78345063e09bbd9cbd9a73387a41bb0f0 -- pipeline/scripts/progress.sh
```

Expected: no output.

## The versions agree

```bash
bash scripts/check-versions.sh
```

Expected: exit 0, with pipeline at 1.9.1.

## The faults

The results are in [measurements.md](measurements.md). Each fault makes its test fail.
