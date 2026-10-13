# A sample review guide

> **A sample, wholly fictional.** The project (ferncast) and its run
> `009-tag-filter` are invented, and unrelated to the
> [sample handoff](../../../handoff/docs/examples/2026-08-25-csv-export-SESSION-HANDOFF.md).
> The branch was built through `progress.sh`'s own commit commands, and the
> guide below is what `progress.sh guide` printed for it, unchanged. The real
> [`specs/018-progress-commits-pieces`](018-annotated-run.md) run came before
> runs built in pieces, so it has no guide of its own.

Phase L puts this guide in the pull-request body, and rebuilds it each time
phase M or N pushes. The run's final summary carries it too. What each kind
means, and which phase makes it, is in
[reviewing a run commit by commit](../../README.md#reviewing-a-run-commit-by-commit).

## The guide, as the pull request shows it

Read this branch commit by commit, top to bottom: each row is one commit, oldest first.

| Commit | Kind | Piece | Task IDs | Files |
|---|---|---|---|---|
| 08692ad | spec |  |  | `specs/009-tag-filter/data-model.md`<br>`specs/009-tag-filter/plan.md`<br>`specs/009-tag-filter/quickstart.md`<br>`specs/009-tag-filter/research.md`<br>`specs/009-tag-filter/spec.md`<br>`specs/009-tag-filter/tasks.md` |
| 5151b0a | piece | `Phase 1: Setup` | T001, T002 | `specs/009-tag-filter/tasks.md`<br>`src/tags/model.ts` |
| fd5b8f2 | piece | `Phase 2: User Story 1 - filter the notes by tag (Priority: P1)` | T003, T004, T005, T006 | `specs/009-tag-filter/tasks.md`<br>`src/pages/notes.tsx`<br>`src/tags/filter.ts`<br>`test/filter.test.ts` |
| 83f4c73 | piece | ``Phase 3: User Story 2 - a tag holding `,` `"` or `\|` still matches (Priority: P2)`` | T007, T008 | `specs/009-tag-filter/tasks.md`<br>`src/tags/filter.ts`<br>`test/filter.test.ts` |
| 337e022 | converge | `Phase 4: Convergence` | T009, T010 | `specs/009-tag-filter/tasks.md`<br>`src/tags/filter.ts` |
| 4f4cfc7 | simplify |  |  | `src/tags/filter.ts` |
| b3504e8 | review |  |  | `src/tags/filter.ts`<br>`test/filter.test.ts` |
| ad9c30c | other |  |  | `src/pages/notes.tsx` |

## How to read it

- **Top to bottom.** One row per commit on the branch, oldest first. Read the
  `spec` commit first: it says what the rest is meant to do.
- **A `piece` row is one phase of `tasks.md`.** Its task IDs are the tasks that
  commit marked done, and `tasks.md` is among its files.
- **The rest come from later phases**: `converge` from H.5, which appended its
  own phase to `tasks.md` (`Phase 4: Convergence`, with the two tasks it found
  missing); `simplify` from H.7; `review` from I; and here `other` from M, a
  fix the pull-request review asked for.
- **Every file is listed.** No row is cut short.

## The escaping rules

The third piece's name holds a backtick and a `|`. In the body's Markdown
source that cell reads:

```
``Phase 3: User Story 2 - a tag holding `,` `"` or `\|` still matches (Priority: P2)``
```

Every piece name and path is a code span, fenced with one more backtick than
the longest run of backticks inside it, and every `|` is written `\|`, so no
value can break the table or add markup. A value that starts or ends with a
backtick also gets a space inside the fence, so its own backtick cannot join
the fence. A value holding a carriage return or a line feed is refused
instead: phase L stops and names the commit.

A body over GitHub's limit of 65,536 characters shows each commit's file count
in place of its files, and the full guide follows as comments: see
[a body over the GitHub limit](../rare-paths.md#a-body-over-the-github-limit).
