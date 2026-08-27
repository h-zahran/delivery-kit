# Data model — fixtures and the observable surface

**Feature**: `009-preflight-coverage-probe` · **Phase**: D

This feature adds no runtime data structure. Its "data" is of two kinds: the
**fixture trees** that put the probe into a known state, and the **observable
surface** the tests read back. Both are specified here exactly, so Phase H
builds them rather than re-deriving them.

Every fixture below was built and driven before this document was written. The
verdict column is what was observed, not what is expected.

---

## Part 1 — The observable surface

The probe emits two streams, and the separation between them is itself a
property under test (FR-010).

| Stream | Carries | How a test reads it |
|---|---|---|
| data | one JSON document, always, whenever the probe does not refuse | `output`, which must parse whole |
| diagnostic | zero or more lines, each prefixed `preflight: ` by the script's own warn and die helpers — with one exception below | `stderr` |

**The exception:** a flag supplied without its value is reported by the *shell's*
parameter expansion, not by the script's helpers. That line carries the script's
path and a line number and has no `preflight: ` prefix. Neither the path nor the
line number may be asserted on (FR-024).

### The keys these tests read

Only these. No test reads a key it does not assert on.

| Key path | Type | Read by |
|---|---|---|
| `speckit.version` | string, may be empty | FR-005 |
| `speckit.script` | string, may be empty | FR-006 |
| `speckit.invocationForm` | one of `hyphen-skills`, `dot-commands`, `none` | FR-007 |
| `speckit.constitutionSet` | boolean | FR-008, FR-014, FR-015 |
| `baseBranch` | string | FR-013 |
| `baseBranchSource` | one of `origin/HEAD`, `configured`, `current branch` | FR-013 |
| `capabilities.gh` | boolean | FR-012 |
| `capabilities.adb` | boolean | FR-011 |
| `willSkip` | array of `{phase, reason}` | FR-011, FR-012 |

**`willSkip` is a list and must be selected by phase, never indexed.** A run can
announce more than one skip at a time — the mobile fixture with a narrowed search
path announces both `N.5` and `M` — so reading the first element makes a test
pass or fail on ordering.

---

## Part 2 — The six new fixture trees

All live under `pipeline/tests/fixtures/`, all tracked. The ignore rules
re-include that tree wholesale, verified with controls in both directions
including the new `.agents/` shape (research.md §6). No ignore rule changes.

### Shared shape

Three of the six exist to fire exactly one warning. So that no *other* warning
fires and muddies the assertion, every fixture that is not deliberately missing a
value carries a complete init-options file:

```json
{ "speckit_version": "0.16.5", "script": "sh" }
```

and every fixture carries the two directories that open the spec-tool block —
without both, none of these warnings is reachable at all:

```text
.specify/templates/.gitkeep
.specify/scripts/bash/.gitkeep
```

Fixtures that must **not** read as a foreign-agent install also carry a local
skills entry, which is what holds the invocation form at `hyphen-skills`:

```text
.claude/skills/speckit-clarify/SKILL.md
```

### 1. `speckit-no-version`

Proves FR-005.

| Path | Content |
|---|---|
| `.specify/init-options.json` | `{ "script": "sh" }` — a flavour, **no version key** |
| `.specify/templates/.gitkeep` | empty |
| `.specify/scripts/bash/.gitkeep` | empty |
| `.claude/skills/speckit-clarify/SKILL.md` | a one-line placeholder |

**Observed:** exit 0 · data stream parses whole · `speckit.version` empty ·
diagnostic stream carries `preflight: no version recorded in
.specify/init-options.json` and nothing else.

### 2. `speckit-no-flavour`

Proves FR-006. The mirror of the above.

| Path | Content |
|---|---|
| `.specify/init-options.json` | `{ "speckit_version": "0.16.5" }` — a version, **no script key** |
| the other three | as fixture 1 |

**Observed:** exit 0 · data stream parses whole · `speckit.script` empty ·
diagnostic stream carries `preflight: no script flavour recorded in
.specify/init-options.json` and nothing else.

**A fixture with no init-options file at all is deliberately not used.** It fires
*both* warnings, so a test built on it could attribute neither.

### 3. `foreign-agent`

Proves FR-007 — the warning **and** an invocation form of `none`, together, in
one run.

| Path | Content |
|---|---|
| `.specify/init-options.json` | the complete file, so neither other warning fires |
| `.specify/templates/.gitkeep` | empty |
| `.specify/scripts/bash/.gitkeep` | empty |
| `.agents/skills/speckit-clarify/SKILL.md` | a one-line placeholder |

**There must be no `.claude/skills/speckit-*` and no `.claude/commands/speckit.*.md`
anywhere in this tree.** Either one holds the form away from `none` and silences
the warning entirely — that is the measured negative control (research.md §1,
case F).

**Observed:** exit 0 · data stream parses whole · `speckit.invocationForm` is
`none` · diagnostic stream carries `preflight: found .agents/skills/speckit-* —
this repository was initialised for a different agent; not adopting it` and
nothing else.

### 4. `constitution-nul`

Proves FR-008.

| Path | Content |
|---|---|
| `.specify/init-options.json` | the complete file |
| `.specify/templates/.gitkeep`, `.specify/scripts/bash/.gitkeep` | empty |
| `.claude/skills/speckit-clarify/SKILL.md` | a one-line placeholder |
| `.specify/memory/constitution.md` | **a UTF-16LE save** — see below |

The governance file is a little-endian byte-order mark followed by
`# Constitution` and a newline, each character stored as two bytes. Written with
one `printf` and octal escapes:

```
\377\376\043\000\040\000\103\000\157\000\156\000\163\000\164\000\151\000\164\000\165\000\164\000\151\000\157\000\156\000\012\000
```

This shape is chosen over an arbitrary NUL because it is what the warning
actually names — a UTF-16 or UTF-32 save — and because it is **discriminating**:
its bytes carry non-whitespace and no placeholder token, so without the NUL check
the file would read as carrying principles. A fixture that read as not-set for
some other reason would prove nothing.

**Observed:** exit 0 · data stream parses whole · `speckit.constitutionSet` is
`false` · diagnostic stream carries `preflight: constitution carries NUL bytes (a
UTF-16/32 save?) — read as not set`.

**Byte-exactness is safe.** The tracked attributes file normalises line endings
for every path and names Markdown explicitly, so this was checked the only way
that settles it: committed, then read back **out of a fresh clone**. The bytes
came back identical (research.md §6).

### 5. `constitution-bom`

Proves FR-014.

| Path | Content |
|---|---|
| everything but the governance file | as fixture 4 |
| `.specify/memory/constitution.md` | `\357\273\277` then three spaces, a newline, a tab, a newline |

**This fixture must be the mark followed by nothing but whitespace.** The obvious
fixture — a mark followed by a real constitution — reads as carrying principles
**with or without** the stripping, because the mark merely rides in front of text
that already counts. Measured vacuous, twice, in two sessions.

| Fixture | as shipped | with the strip removed |
|---|---|---|
| mark then whitespace only | `false` | `true` |
| mark then real prose | `true` | `true` — vacuous |

**Observed (as shipped):** exit 0 · data stream parses whole ·
`speckit.constitutionSet` is `false` · diagnostic stream **empty**.

Byte-exactness verified by fresh clone, as fixture 4.

### 6. `constitution-unclosed`

Proves FR-015.

| Path | Content |
|---|---|
| everything but the governance file | as fixture 4 |
| `.specify/memory/constitution.md` | **opens with the comment**, principles after it |

**The comment must be the very first byte of the file.** This was measured in
this feature's research and is not obvious:

| Fixture | as shipped | with the unclosed-comment branch removed |
|---|---|---|
| a heading, then the unclosed comment, then principles | `true` | `true` — vacuous |
| the unclosed comment first, then principles | `true` | `false` |

Any real text before the comment already makes the file read as carrying
principles, so the test would pass whether or not the text after the comment
survives. Only a file that opens with the comment isolates the property.

The document is a comment opened and never closed, then a blank line, then real
principle prose carrying no placeholder token.

**Observed:** exit 0 · data stream parses whole · `speckit.constitutionSet` is
`true` · diagnostic stream empty.

---

## Part 3 — Constructions that are not fixtures

Four behaviours are reached by shaping the *environment*, not a directory, so
they build what they need inside the per-test temporary directory. They add no
tracked file.

| Used by | Construction |
|---|---|
| FR-004 | an **empty** directory given to the helper as the whole search path |
| FR-011 | a directory of shims for the six commands the probe needs, **without** the device tool, used with the existing mobile fixture |
| FR-012 | two scratch repositories, one with a non-GitHub remote and one with a GitHub remote, each probed with a shim directory that does or does not carry a command-line-client shim |
| FR-013 | a scratch repository initialised on a named branch, **with one empty commit**, probed with the base-branch flag omitted |

### The shim directory

Six shims — `awk`, `git`, `grep`, `head`, `jq`, `od` — each a two-line script
that executes the real tool. Derived from the probed script's own text, not
guessed. A tool whose mere presence is under test needs only to exit zero.

**The directory must be a path with no drive letter.** A drive-letter path used
as a search-path entry splits on its own colon and then *every* tool reads as
absent, including the data tool — so the probe dies for the wrong reason and the
test passes for the wrong cause. The per-test temporary directory is already in
the right form.

### FR-013's commit is load-bearing

Without a commit the branch is unborn, and the command the fallback uses exits
128 while printing the literal word `HEAD` on the data stream. The script
discards that status, so the reported branch becomes the string `HEAD`. The
`baseBranchSource` assertion would still pass. **One empty commit is what makes
the branch name mean anything.**

### FR-012's first cause needs the client forced present

The command-line client is absent to this shell on the development machine and
present on every runner. A non-GitHub remote alone therefore fires the skip here
for the *other* cause, and the test proves nothing. The test puts a client shim
on the search path first.

Its negative control — client present **and** a GitHub remote — must produce an
empty skip list. Without that control the assertion cannot be shown to go red
when it should.
