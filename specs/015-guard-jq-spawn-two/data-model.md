# Data model: the guard stops counting jq, part two

**Feature**: `015-guard-jq-spawn-two`
**Date**: 2026-09-02

This change moves no data between systems and stores nothing new. What follows
is the shape of the values that flow through the two regions being changed, and
the rules each must still obey afterwards.

---

## Payload

The JSON object the caller writes to the hook's standard input, once per tool
call.

| Field | Type | Default when absent | Used for |
|---|---|---|---|
| `agent_id` | string | `""` | Non-empty means a subagent; the guard exits. |
| `transcript_path` | string | `""` | The file the readings are taken from. |
| `session_id` | string | `"unknown"` | Names the once-per-bucket flag file. |
| `cwd` | string | `""` | Locates the repository configuration file. |

**Rules that must survive this change**

- All four are extracted in **one** parser call, joined by a separator byte that
  is defined once in the file and used by both the joining and the splitting.
- The separator is not a tab. A tab collapses runs and strips empty fields, and
  `agent_id` is empty in every main-session payload — so with a tab the fields
  shift left, `agent_id` reads as the transcript path, and the guard never fires
  in the main session again.
- The split is done by parameter expansion, not by a line-reading builtin. A
  value may contain a newline; a line reader keeps a prefix and drops every
  field after it.
- Every field is coerced to a string before joining, so one field of an
  unexpected type cannot abort the whole extraction and leave the guard silent.
- The order of the four fields in the parser program and the order of the four
  assignments in the shell agree by convention alone. That coupling is pinned
  emergently, by a behavioural test for each field, not by a structural test.

**What changes**: only how the payload text reaches the parser. Today it is read
into a shell variable and written back out; afterwards the parser reads standard
input directly. The fields, their order, their defaults and their coercion are
untouched.

---

## Transcript

A file of JSON lines. The hook reads a suffix of it.

| Property | Value | Why |
|---|---|---|
| Line budget | last 5000 lines | Bounds the work when lines are small. |
| Byte budget | last 8 000 000 bytes, configurable | Bounds the work when lines are large; 5000 lines of tool results measured 48 MB. |
| Excluded | entries marked as a sidechain | They are not this session's context. |
| Excluded | entries with no input-token field | They carry no reading. |

---

## Reading

One token total taken from one transcript line:

```
input_tokens + (cache_read_input_tokens or 0) + (cache_creation_input_tokens or 0)
```

| Rule | Detail |
|---|---|
| A line that is not valid JSON | skipped; the lines around it are still read |
| A line whose token field is not a number | skipped; the lines around it are still read. **This is the rule that forces the `?` in the new program** — without it the whole read yields nothing. |
| A negative total | **excluded from the count, included in the median**. Preserved exactly; see the count rule below. |

---

## Reading summary — the value that is new

The single value the new parser call returns, replacing three separate results.
It is two fields joined by the same separator byte the payload uses.

| Field | Type | Definition |
|---|---|---|
| count | integer | The number of readings whose text form begins with a digit. |
| median | number | Of the **last fifteen** readings: sort them, take the element at the middle index rounded down. Zero when there are none. |

**Rules**

- The count is *not* the length of the reading list. It reproduces the text
  search it replaces, which skips a negative reading. The two disagree by one on
  a transcript holding a negative value, and that disagreement changes the
  fallback decision, which is forbidden.
- The median is taken over the last fifteen readings **including** any negative
  one. The count and the median therefore look at different sets. That is the
  existing behaviour and it is deliberate to keep, not an inconsistency this
  change introduces.
- A count that is not a run of digits is treated as zero. The direction matters:
  zero means *starved*, which takes the fallback. The opposite default would
  skip the fallback, which is the failure the fallback exists to prevent.

---

## Fallback decision

| Count | Action |
|---|---|
| fifteen or more | answer from the capped read |
| fewer than fifteen | re-read the transcript with no byte cap and answer from that |

The floor of fifteen equals the median window of fifteen, and must stay equal to
it. A suffix that still holds fifteen readings yields the same last fifteen as
the whole file, so the capped answer is identical and the cap is free. A suffix
holding fewer can differ, and every way it can differ rests the median on an
inflated run.

**Unchanged by this feature.** The only thing that changes is where the count
comes from.

---

## Percentage and the warning flag

| Value | Definition |
|---|---|
| percentage | median × 100 ÷ window |
| bucket | percentage ÷ 5 |
| flag file | one per session, under the temporary directory, holding the last bucket warned |

**Unchanged by this feature**, and listed only because the flag file is the
reason a comparison harness must isolate the home directory *and* all three
temporary-directory settings separately for each side of each shape. Isolate
only the home directory and the first side leaves the flag behind, silencing the
second — which reads as a catastrophic regression on a correct hook.
