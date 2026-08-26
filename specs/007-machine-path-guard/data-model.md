# Data Model: the machine path leaves the repository

This feature stores nothing and has no runtime state. The "model" is the set
of shell values the new checks build and the surface they read. It is recorded
because getting the relationships between them wrong is precisely how a scan
goes quietly blind.

**Document constraint (FR-021):** no banned shape is written joined here. The
literal spellings live in exactly one place, `tests/portability.bats`, and this
document points at them rather than repeating them.

## Entities

### `TREE_PATHS` — the tree-wide path pattern

| Field | Value |
|---|---|
| Kind | A single extended-regular-expression alternation, in one shell variable |
| Lives in | `tests/portability.bats`, near the existing path denylist |
| Branches | Four: drive root; Windows users prefix; Git-Bash home prefix **followed by a name character**; agent-projects prefix followed by a name character |
| Assembled | Exactly once (FR-010). Both the scan and its control read this variable and no other |
| Relationship | Deliberately SEPARATE from the existing denylist (FR-022). Neither derives from the other |

The third branch is the only one that differs from the existing list: it
requires a name character after the prefix. That single character is what lets
the three deliberate elided references survive (FR-008, FR-014) while a real
account name is still caught.

### `TREE_SURFACE` — the enumerated file list

| Field | Value |
|---|---|
| Kind | A list of repository-relative paths of tracked files |
| Produced by | `git ls-files` with root `tests/` excluded |
| Cardinality now | 132 files (measured 2026-08-26); 3 files are excluded |
| Validation | MUST be non-empty before it is scanned (R2). An empty list turns the scan into a read of standard input, which reports on nothing |
| Relationship | Consumed as explicit operands by the scan, which is what preserves the "could not look" exit status (R1) |

### The scan check

| Field | Value |
|---|---|
| Reads | `TREE_PATHS` and `TREE_SURFACE` |
| Asserts | Exit status **equal to 1** — looked, found nothing |
| Rejects | Exit 0 (a leak) and exit 2 (a renamed, unreadable or unparseable surface) |
| Never | `-ne 0`, and never a match-count comparison on its own (R6) |

### The positive control check

| Field | Value |
|---|---|
| Reads | The same `TREE_PATHS` variable — not a copy, not a re-spelling |
| Fixture | A synthetic line carrying an account-name shape, written to the test's own temporary directory |
| Asserts | Exit status **equal to 0** — the pattern still matches something |
| Proves | That the scan CAN fail. Nothing more, and the comment must say so (FR-013) |

## Relationships

```
TREE_PATHS ──────┬──> scan check      ── asserts exit 1 over TREE_SURFACE
                 └──> control check   ── asserts exit 0 over a known-bad fixture

TREE_SURFACE ────────> scan check     ── non-empty guard runs first
```

The single arrow from `TREE_PATHS` into both checks is the load-bearing edge.
If the control ever reads a different expression than the scan, it stops
proving anything about the scan — the rule the existing file states at
`:30-35` for the vocabulary alternation, and the reason `VOCAB_RE` exists there.

## State transitions

None. Both checks are pure reads with no side effect beyond a temporary
fixture file that `bats` removes.

## Validation rules

1. `TREE_PATHS` is defined once and referenced twice.
2. `TREE_SURFACE` is non-empty, and the check says what it counted.
3. The scan's assertion is `-eq 1`.
4. The control's assertion is `-eq 0`.
5. Neither check writes outside the test temporary directory.
6. The existing denylist is byte-identical before and after this feature.
