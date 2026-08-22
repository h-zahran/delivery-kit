# Prose contract — the byte-exact deliverables

This feature's external interface is shipped text. The contract is exact:
each block below must appear character-for-character in its named file, and
every string already pinned by `pipeline/tests/prose.bats` must survive
byte-for-byte.

## C1 — O paragraph addition (`pipeline/skills/pipeline/SKILL.md`, FR-001)

After the O — release paragraph's final sentence:

> With `releaseCommand` unset there is nothing to publish: record that in the state file and move on — the gate guards a command, it does not invent one.

## C2 — N.5 addition (`pipeline/skills/pipeline/SKILL.md`, FR-002)

After the sentence ending "then continue.":

> Verification beyond the configured strategy is welcome when it is real — run it, then report it as exactly what it is: extra evidence, not the configured check.

Must survive unchanged: `It never reports verification it did not do`

## C3 — G paragraph addition (`pipeline/skills/pipeline/SKILL.md`, FR-003)

In the G — implementer gate paragraph:

> If the gate's answer later changes, delete the written package file (or stamp it VOID at the top) before proceeding — a stale package addressed to another model is an instruction nobody should find.

## C4 — Ground rules bullet (`pipeline/skills/pipeline/SKILL.md`, FR-004)

One new list bullet:

> **A missing tool is its own question.** When the run needs a tool the machine lacks, stop: name the tool, show the exact install command, and record the answer in the state file. Never install anything silently.

## C5 — README invocation spelling (`pipeline/README.md`, FR-005)

- The three example invocations in "How it runs" each read `/pipeline:pipeline …`.
- A short-form sentence exists only if the live measurement (research R1)
  proved what it says; indeterminate → no sentence.

## C6 — The 1.0.1 stamp (FR-006)

| Site | Value |
|---|---|
| `pipeline/.claude-plugin/plugin.json` → `.version` | `1.0.1` |
| `.claude-plugin/marketplace.json` → pipeline plugin entry `.version` | `1.0.1` |
| `pipeline/CHANGELOG.md` heading, above `## [1.0.0] …` | `## [1.0.1] - <stamp day>` |

Changelog entries: describe the fixes, count-free; heading shape must parse as
`## [X.Y.Z] - YYYY-MM-DD`.
