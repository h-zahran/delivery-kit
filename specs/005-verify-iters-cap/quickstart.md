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
grep -c 'maxVerifyIters' pipeline/skills/pipeline/SKILL.md   # 2 - tripwire, see below
grep -c 'maxVerifyIters' pipeline/docs/configuration.md      # 2 - tripwire, see below
# the defaults themselves, read out of each file and compared:
sed -n 's/.*| `maxVerifyIters` | \([0-9]*\) | Phase J cap |.*/\1/p' pipeline/skills/pipeline/SKILL.md   # 5
awk '/^```json$/{if(!seen){f=1;seen=1;next}} /^```$/{f=0} f' pipeline/docs/configuration.md \
  | jq -r '.pipeline.maxVerifyIters'   # 5
```

Those two counts are a TRIPWIRE, not a promise. They say "the key is mentioned
twice today" - a fact about the current documents, not a property the feature
must keep. Read them that way, because taken as a promise they FORBID
documentation: stating the value's domain near the orchestrator row, giving the
key its own narrative section the way `implementer` has one, or naming phase J
in the configuration row would each add a third mention and fail this check.
Phase I already had to write its deferred fix sentences under the hard
constraint "must contain NO occurrence of the key name", which is the tripwire
wagging the document. If a later change legitimately adds a mention, UPDATE THE
NUMBER - do not contort the prose to keep it at 2. The checks that protect
behaviour are section 1's exact strings, section 3's sliced greps and section
6's two site pins; this one only notices that something moved.

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
grep -cF 'The record lands under `gates.J`' <<<"$flat"   # 1
grep -cF 'the commit message carries it alone and the duty is discharged there' <<<"$flat"   # 1
grep -cF 'That answer covers the failures it names and no others' <<<"$flat"   # 1
grep -cF 'The duty names three destinations because three usually exist' <<<"$flat"   # 1
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

## 6. The sites outside the J slice (T007, FR-004)

Mutation testing at phase I found these two shipped sites had NO check anywhere.
Reverting T007 (`C, F, J or M` back to `C, F or M`) and rewriting the changelog
entry to announce an unbounded loop with a different default BOTH passed the full
`1..121` suite and every section above. Neither lives in the J slice section 3
greps, so they need their own checks. In `research.md` R3's enumeration the
conditional-stops line is site SEVEN and the changelog entry is site SIX — R3 is
the authoritative enumeration and this section follows it; an earlier draft of
this heading called the changelog "site 8", which was wrong.

```bash
grep -cF 'Conditional stops: the resume prompt, a cap breach in C, F, J or M, a' pipeline/skills/pipeline/SKILL.md   # 1
grep -cF 'The `maxVerifyIters` key, default 5:' pipeline/CHANGELOG.md   # 1
```

## 7. The phase N slice (T014)

Phase N gained a sentence at M round 1 telling it not to re-own a failure the
owner accepted at J's cap breach. Round 3 found it had NO cover: deleting it
passed the full suite and every section above, which is the relocation hole phase
I made a first-class defect. Section 3 cannot catch it, because section 3 slices
J only. This section slices N.

```bash
n="$(awk '/^\*\*N — re-verify and update the PR\.\*\*/,/^\*\*N\.5 — runtime check\.\*\*/' pipeline/skills/pipeline/SKILL.md)"
nflat="$(tr '\n' ' ' <<<"$n" | tr -s ' ')"
grep -cF 'One classification is inherited rather than made afresh' <<<"$nflat"   # 1
grep -cF 'never re-enter a fix loop the owner already ended' <<<"$nflat"   # 1
```
