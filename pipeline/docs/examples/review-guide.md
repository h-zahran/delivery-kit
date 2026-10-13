# A sample review guide

> **A sample, wholly fictional.** The project (ledgerlark) and its run
> `014-csv-export` are invented. The guide below is what `progress.sh guide`
> printed for that run's branch, unchanged. The real
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
| 17d206d | spec |  |  | `specs/014-csv-export/spec.md`<br>`specs/014-csv-export/plan.md`<br>`specs/014-csv-export/research.md`<br>`specs/014-csv-export/data-model.md`<br>`specs/014-csv-export/quickstart.md`<br>`specs/014-csv-export/tasks.md` |
| 7add542 | piece | `Phase 1: Setup` | T001, T002 | `src/reports/model.ts`<br>`specs/014-csv-export/tasks.md` |
| 4b5dfab | piece | `Phase 2: User Story 1 - download the report as CSV (Priority: P1)` | T003, T004, T005, T006 | `src/reports/csv.ts`<br>`src/pages/report.tsx`<br>`test/csv.test.ts`<br>`specs/014-csv-export/tasks.md` |
| 4d43eec | piece | ``Phase 3: User Story 2 - a cell holding `,` `"` or `\|` survives (Priority: P2)`` | T007, T008 | `src/reports/csv.ts`<br>`test/csv.test.ts`<br>`specs/014-csv-export/tasks.md` |
| e028424 | converge |  | T009, T010 | `src/reports/csv.ts`<br>`specs/014-csv-export/tasks.md` |
| ade0ed5 | simplify |  |  | `src/reports/csv.ts` |
| 4b9f7b9 | review |  |  | `src/reports/csv.ts`<br>`test/csv.test.ts` |
| e2bdfdc | other |  |  | `src/pages/report.tsx` |

## How to read it

- **Top to bottom.** One row per commit on the branch, oldest first. Read the
  `spec` commit first: it says what the rest is meant to do.
- **A `piece` row is one phase of `tasks.md`.** Its task IDs are the tasks that
  commit marked done, and `tasks.md` is among its files.
- **The rest come from later phases**: `converge` from H.5 (T009 and T010 are
  tasks it found missing), `simplify` from H.7, `review` from I, and here
  `other` from M, a fix the pull-request review asked for.
- **Every file is listed.** No row is cut short.

## The escaping rules

The third piece's name holds a backtick and a `|`. In the body's Markdown
source that cell reads:

```
``Phase 3: User Story 2 - a cell holding `,` `"` or `\|` survives (Priority: P2)``
```

Every piece name and path is a code span, fenced with one more backtick than
the longest run of backticks inside it, and every `|` is written `\|`, so no
value can break the table or add markup. A value holding a carriage return or
a line feed is refused instead: phase L stops and names the commit.

A body over GitHub's limit of 65,536 characters shows each commit's file count
in place of its files, and the full guide follows as comments: see
[a body over the GitHub limit](../rare-paths.md#a-body-over-the-github-limit).
