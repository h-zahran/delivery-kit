# Quickstart: verifying the J cap

Every command here is meant to be run verbatim from the repository root, and
every documented output was measured, not predicted. If a command's output
disagrees with what is written here, the document is wrong and should be fixed
— that is what happened to the previous phase's §4 and it was caught by a
reviewer, not by the author.

## 1. The three sites (FR-001)

```bash
grep -cF '| `maxVerifyIters` | 5 | Phase J cap |' pipeline/skills/pipeline/SKILL.md   # 1
grep -cF '"maxVerifyIters": 5' pipeline/docs/configuration.md   # 1
grep -cF '| `maxVerifyIters` | Verification fix-loop cap; a breach stops and asks, and a breach waved through is recorded in the commit message and the pull request. |' pipeline/docs/configuration.md   # 1
```

## 2. The name token, and each file's mention count (SC-001)

This heading used to say "Name-and-**default** identity". It overclaimed: the
first four commands compare the NAME token and count mentions, and never read a
`5`. Mutation proved it — drifting the orchestrator row's default to `3` against
the JSON block's `5` passes all four, and only §1's exact-string grep catches it.
The last two commands were added at phase I so this section earns its heading.

```bash
grep -oF '`maxVerifyIters`' pipeline/skills/pipeline/SKILL.md | sort -u
grep -oF '`maxVerifyIters`' pipeline/docs/configuration.md | sort -u
# both print exactly: `maxVerifyIters`
grep -c 'maxVerifyIters' pipeline/skills/pipeline/SKILL.md   # 2
grep -c 'maxVerifyIters' pipeline/docs/configuration.md      # 2
# the defaults themselves, read out of each file and compared:
sed -n 's/.*| `maxVerifyIters` | \([0-9]*\) | Phase J cap |.*/\1/p' pipeline/skills/pipeline/SKILL.md   # 5
awk '/^```json$/{if(!seen){f=1;seen=1;next}} /^```$/{f=0} f' pipeline/docs/configuration.md \
  | jq -r '.pipeline.maxVerifyIters'   # 5
```

## 3. The J paragraph, verbatim AND IN PLACE (FR-002, FR-003a)

Slice the J region FIRST, then flatten, then grep. A file-wide grep is
location-blind, and phase I proved it with a mutation: moving both new sentences
into an appendix headed "notes, not instructions" left phase J with no loop
bound at all, and the full suite AND every check in this document stayed green.
That is the same relocation hole `pipeline/tests/prose.bats` already slices for.

```bash
j="$(awk '/^\*\*J — analyzer and full suite\.\*\*/,/^\*\*K — commit\./' pipeline/skills/pipeline/SKILL.md)"
flat="$(tr '\n' ' ' <<<"$j" | tr -s ' ')"
grep -cF 'Loop until clean against baseline, at most `maxVerifyIters` iterations; a cap breach is a conditional stop — show the failures that survived and ask whether to continue; a hard failure still stops the run outright.' <<<"$flat"   # 1
grep -cF 'record the surviving failures in the state file, and carry them into the commit message and the pull-request body.' <<<"$flat"   # 1
grep -cF 'Redaction binds that carry exactly as it binds the handoff package' <<<"$flat"   # 1
# this pins the paragraph's OPENER only — not all four untouched sentences
grep -cF '**J — analyzer and full suite.** Run `analyzeCommand`, then `testCommand`.' <<<"$flat"   # 1
# and the sentence the cap replaced is GONE from the WHOLE file, not just from J
flatall="$(tr '\n' ' ' < pipeline/skills/pipeline/SKILL.md | tr -s ' ')"
grep -cF 'Loop until clean against baseline or a hard failure stops the run.' <<<"$flatall"   # 0
```

That `0` proves the exact replaced string is absent. It does NOT prove that no
contradictory unbounded claim survives: a PARAPHRASE inserted two lines from the
cap sentence passes it untouched. The sweep that covers paraphrases was run by
hand and no command here reproduces it in full; the grep below is its cheap part.

```bash
grep -ciE 'until (the )?(suite|tests?) ?(is |are )?(clean|green)' <<<"$flat"   # 0
```

## 4. Nothing moved (SC-002, SC-003)

```bash
bash /c/Users/h_zah/bats/bin/bats --tap pipeline/tests/prose.bats   # 1..11, 11 ok
bash /c/Users/h_zah/bats/bin/bats --tap -r --print-output-on-failure tests handoff/tests pipeline/tests
# expect: 1..121, 121 ok, 0 not ok, 0 non-TAP — growth exactly zero
git status --porcelain -- handoff/   # empty
```

## 5. The JSON block still parses, and the changelog is ordered (FR-004)

```bash
awk '/^```json$/{if(!seen){f=1;seen=1;next}} /^```$/{f=0} f' pipeline/docs/configuration.md \
  | jq -e '.pipeline.maxVerifyIters == 5'   # true
grep -n '^## \[' pipeline/CHANGELOG.md | head -3
# [Unreleased] first, then [1.0.1], then [1.0.0] — no new version heading
```

## 6. The two sites nothing else covers (T007, FR-004)

Mutation testing at phase I found these two shipped sites had NO check anywhere.
Reverting T007 (`C, F, J or M` back to `C, F or M`) and rewriting the changelog
entry to announce an unbounded loop with a different default BOTH passed the full
`1..121` suite and every section above. They are recorded as sites 7 and 8 of the
unpinned surface in `research.md` R3; these two greps are the manual cover until
that debt is spent.

```bash
grep -cF 'Conditional stops: the resume prompt, a cap breach in C, F, J or M, a' pipeline/skills/pipeline/SKILL.md   # 1
grep -cF 'The `maxVerifyIters` key, default 5:' pipeline/CHANGELOG.md   # 1
```
