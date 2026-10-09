# Contract: the probe lines on a resume

## When the rule is reached

`SKILL.md`'s **Base branch:** pointer sends the run to `pipeline/docs/configuration.md` when any of `baseBranchOverride`, `--base-branch`, `--branch`, `--spec-dir`, `commitTrailers` or `--trailer` is set, or a resumed run's state file records one. A plain `--resume` types none of them, so the second clause is what reaches the rule (review 2, item 3).

## What is printed

| Line | Source on a resume | Mark |
|---|---|---|
| `Branch` | the branch recorded in the state file | recorded |
| `Spec folder` | the folder that holds the `spec.md` named by `artifacts.spec` | recorded |
| `Trailers` | `config.commitTrailers`, each entry with its layer from `config.commitTrailersFrom` | recorded |
| `Base branch` | the recorded base | recorded |

Each line is printed only when its value is set or recorded. A different value typed on the resume is never applied silently: the record stands, and both values are named.

## Pinned strings

| Site | Pinned text |
|---|---|
| SKILL.md **Base branch:** | the whole pointer sentence, `When any of … or a resumed run's state file records one, read … first, and follow it.` |
| SKILL.md Pre-flight | `and the Branch, Spec folder and Trailers lines only when set or recorded:` |
| `pipeline/docs/configuration.md` | the resume rule for the Branch and Spec folder lines; the resume rule for the trailers |
| `pipeline/CHANGELOG.md` | `On a resume, pre-flight prints the branch and the folder the run recorded.` |

## When the block is rendered (review 4)

On every re-entry (`--resume`, `--from`, or a resume chosen at decision item 8's prompt) the block is rendered from the state file, again if it was already shown, after decision item 7's lock and the tracked-state check under **Resume**. `prose.bats` pins the sentence whole ("review 3's rules are pinned where the operator and the run read them").
