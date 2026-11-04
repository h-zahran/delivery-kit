# Research: Phase B records config before the base suite starts

## R1. The wording and where it goes

**Decision**: In B, directly before ``Record `artifacts.spec`.``, add:

> A fresh run records `config` here, as Configuration says: `suite-base` reads it.

**Rationale**:

- "A fresh run" and "here" answer the question the skill leaves open: when. A resume keeps the recorded `config`, which is the reason Configuration gives for recording it, so the sentence must not tell a resume to write it again.
- "as Configuration says" points at the existing rule (FR-002).
- The existing pin ``Record `artifacts.spec`. Then run `progress.sh suite-base <feature> start` and print ...`` stays whole, because the new sentence goes before it. No pinned text moves.
- The sentence is about 80 bytes, against 362 free.

**Alternatives considered**:

- Between ``Record `artifacts.spec`.`` and `Then run`: it reads well, but it breaks the existing pin for no gain.
- Change `progress.sh` so the start refuses or exits 1: the seed forbids it.
- Have `init` take the config: a change to `progress.sh`, also forbidden.

## R2. The test's shape

**Decision**: One test in `pipeline/tests/prose.bats`, after "B starts the base suite run once the branch is cut". It slices phase B with `prose_slice ... flat`, so a wrap cannot change its verdict and text outside B cannot satisfy it. Then it checks, in this order:

1. The flat text holds the start phrase ``Then run `progress.sh suite-base <feature> start` ``. If not, it fails and names the start command.
2. The flat text holds the record sentence. If not, it fails and names the sentence.
3. The text before the first start phrase holds the record sentence. If not, it fails and names the order.

The cut is an assignment with no outer quotes, `before=${flat%%"$start"*}`, with the phrases in variables. Matching uses `[[ == ]]`, never `grep`: `< <(printf ...)` false-matched here (measured), and a herestring hangs at 64 KB on Git Bash.

**Rationale**: Three separate messages let a failure name its fault. A contiguous pin of the two sentences would go red on the swap too, but its message would not say why, and a later rewording between them would have to change it.

**Alternatives considered**:

- Comparing byte offsets with `awk`: more code, the same verdict.
- A runtime test that drives `suite-base start` without `config`: `tests/base-suite.bats` already covers the command's message. The gap is the skill's prose.

## R3. The second copy of the claim

**Decision**: `pipeline/docs/phases.md`, "Reusing a suite run", says "once the state file and the feature branch exist". That is the same claim with the same hole. Change it to name `config` too.

**Rationale**: Records go stale one copy at a time. The clause is not pinned by any test (checked with `grep` across the test files).

## R4. Release shape

**Decision**: One release piece, last, as commit `release: pipeline 1.9.1`, touching `pipeline/CHANGELOG.md`, `pipeline/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, the same three files as `bdc2915` (1.9.0). `scripts/check-versions.sh` must agree. The owner merges and tags after the run.

**Rationale**: The owner chose this at C. `.claude-plugin/marketplace.json` lies outside `codeRoots`, so K names it. K and L are still one stop, because K has nothing left to commit.

## R5. The fault runs

**Decision**: Run the four faults from the spec in a detached worktree outside the repository, never on the tracked tree. For each one, echo the mutated text to prove the mutation landed, run only the new test, and write the result to `measurements.md`. Also run the test before the sentence exists (red for the right reason).

**Rationale**: "A mutation rig belongs in a worktree" and "Prove a mutation landed" are both measured lessons in this repository. Also run the new test on Docker `bash:3.2` at run time: macOS CI uses that version.
