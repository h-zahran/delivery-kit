# Research: Phase B records config before the base suite starts

## R1. The wording and where it goes

**Decision**: In B, directly after the sentence that writes the `.gitignore` answer, and before ``THEN create the feature branch``, add:

> Record `config` here if it is still empty, as Configuration says: `suite-base` reads it.

Phase I changed this from "A fresh run records `config` here": a resume into B whose first attempt stopped before the record holds an empty `config`, and "fresh" told it not to write. `init` writes `config: {}` (measured), so "still empty" covers both, and a resume with a recorded `config` keeps it. Phase I's last pass also moved the sentence here from just before ``Record `artifacts.spec`.``: a stop before the record now cannot have passed the branch cut, which has no resume guard, and the window for losing flag values on a resume shrinks to `init`'s first writes.

**Rationale**:

- "here" and "if it is still empty" answer the question the skill leaves open: when. A resume keeps a recorded `config`, which is the reason Configuration gives for recording it, so the sentence must not tell a resume to write it again.
- "as Configuration says" points at the existing rule (FR-002).
- The existing pin ``Record `artifacts.spec`. Then run `progress.sh suite-base <feature> start` and print ...`` stays whole, because the new sentence does not sit inside it. No pinned text moves.
- The sentence and Configuration's added sentence cost 141 bytes in all, against 362 free at the start.

**Alternatives considered**:

- Between ``Record `artifacts.spec`.`` and `Then run`: it reads well, but it breaks the existing pin for no gain, and it comes after the branch cut.
- Change `progress.sh` so the start refuses or exits 1: the seed forbids it.
- Have `init` take the config: a change to `progress.sh`, also forbidden.

## R2. The test's shape

**Decision**: One test in `pipeline/tests/prose.bats`, after "B starts the base suite run once the branch is cut". It slices phase B with `prose_slice ... flat`, so a wrap cannot change its verdict and text outside B cannot satisfy it. Then it checks, in this order:

1. The flat text holds the start phrase `` `progress.sh suite-base <feature> start` ``. If not, it fails and names the start command.
2. The flat text holds the record sentence. If not, it fails and names the sentence.
3. The text before the first start phrase holds the record sentence. If not, it fails and names the order.

The cut is an assignment with no outer quotes, `before=${flat%%"$start"*}`, with the phrases in variables. Matching uses `[[ == ]]`, never `grep`: `< <(printf ...)` false-matched here (measured), and a herestring hangs at 64 KB on Git Bash.

Phase I added three more checks. The text is cut at the C heading, because `prose_slice` keeps the closing line. The sentence must sit between the `.gitignore` answer and the branch cut. And nothing before it may name `suite-base`.

**Rationale**: Separate messages let a failure name its fault. The between-neighbours check goes red on a sentence added beside it, which is the cost of closing the lower bound and the countermands, and this file pins whole sentences throughout.

**Alternatives considered**:

- Comparing byte offsets with `awk`: more code, the same verdict.
- A runtime test instead of the prose test: the gap is the skill's prose. Phase I found that `pipeline/tests/base-suite.bats` did not cover the command's message on this path, as this document first claimed, so a test was added there too, to hold FR-008.

## R3. The second copy of the claim

**Decision**: `pipeline/docs/phases.md`, "Reusing a suite run", says "once the state file and the feature branch exist". That is the same claim with the same hole. Change it to name `config` too.

**Rationale**: Records go stale one copy at a time. No test pinned the clause at first (checked with `grep` across the test files). Phase I added the pin to the `phases.md` test.

## R4. Release shape

**Decision**: One release piece, last, as commit `release: pipeline 1.9.1`, touching `pipeline/CHANGELOG.md`, `pipeline/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, the same three files as `bdc2915` (1.9.0). `scripts/check-versions.sh` must agree. The owner merges and tags after the run.

**Rationale**: The owner chose this at C. `.claude-plugin/marketplace.json` lies outside `codeRoots`, so K names it. K and L are still one stop, because K has nothing left to commit.

## R5. The fault runs

**Decision**: Run the four faults from the spec in a detached worktree outside the repository, never on the tracked tree. For each one, echo the mutated text to prove the mutation landed, run only the new test, and write the result to `measurements.md`. Also run the test before the sentence exists (red for the right reason).

**Rationale**: "A mutation rig belongs in a worktree" and "Prove a mutation landed" are both measured lessons in this repository. Also run the new test on Docker `bash:3.2` at run time: macOS CI uses that version.
