# Research — preflight.sh coverage and a probe helper

**Feature**: `009-preflight-coverage-probe` · **Phase**: D · **Date**: 2026-08-27

Everything below was **driven and observed**, not reasoned about. It exists so
that no later phase and no later session re-measures any of it. Where a fact
contradicts an earlier record, the contradiction is stated rather than quietly
corrected.

Per FR-024, nothing here is anchored to a line number. Every reference is to
content that can be searched for.

---

## 1. The gate that hid three behaviours — RESOLVED

The previous session ended on one open question: three behaviours (empty
recorded version, empty recorded script flavour, foreign-agent skills
directory) produced **no diagnostic output at all** when probed, and two causes
were possible — a fixture too thin to enter the code path, or a broken capture.

**It was the fixture.** All three warnings live inside a single guard in
`pipeline/scripts/preflight.sh` that opens the spec-tool block:

```
if [ -d .specify/templates ] && [ -d .specify/scripts ]; then
```

A fixture that carries `.agents/skills/speckit-*` but no `.specify/templates`
**and** `.specify/scripts` never enters that block, so the whole spec-tool
section — including all three warnings — is skipped in silence. The capture was
never at fault.

### Measured, six cases

| Case | Fixture shape | stderr observed | `present` | `version` | `script` | `invocationForm` |
|---|---|---|---|---|---|---|
| **A** | `.agents/skills/speckit-*` only, **no `.specify/`** | *(nothing)* | `false` | empty | empty | `none` |
| **B** | `.specify/templates/` + `.specify/scripts/` + init-options carrying `script` only | `preflight: no version recorded in .specify/init-options.json` | `true` | empty | `sh` | `hyphen-skills` |
| **C** | same + init-options carrying `speckit_version` only | `preflight: no script flavour recorded in .specify/init-options.json` | `true` | `0.16.5` | empty | `hyphen-skills` |
| **D** | same, **no init-options file at all** | *both* warnings above | `true` | empty | empty | `hyphen-skills` |
| **E** | full init-options + `.agents/skills/speckit-*`, **no** `.claude/skills/speckit-*` | `preflight: found .agents/skills/speckit-* — this repository was initialised for a different agent; not adopting it` | `true` | `0.16.5` | `sh` | **`none`** |
| **F** | case E **plus** `.claude/skills/speckit-*` | *(nothing)* | `true` | `0.16.5` | `sh` | `hyphen-skills` |

**Case A is the reproduction of the old symptom.** Case **F is the negative
control** that makes case E meaningful: it proves the warning is caused by the
foreign directory **together with** the absence of a recognised local form —
not by the foreign directory alone. Without F, a test built on E would pass for
a cause it does not name.

**Case D is deliberately not used as a fixture.** It fires two warnings at once,
so a test built on it could not attribute either. B and C are one-warning
fixtures by construction.

### Consequence for the fixtures

- FR-005 needs a fixture with both `.specify` directories and an init-options
  file carrying **`script` but no `speckit_version`**.
- FR-006 needs the mirror: **`speckit_version` but no `script`**.
- FR-007 needs both `.specify` directories, a **complete** init-options file (so
  neither of the other two warnings fires and muddies the assertion),
  `.agents/skills/speckit-*` present, and **no** `.claude/skills/speckit-*` and
  no `.claude/commands/speckit.*.md`.

FR-007's test asserts the warning **and** an `invocationForm` of `none` in the
same run, which is what the requirement asks for.

---

## 2. CORRECTION to the previously recorded research — the base-branch fallback

The previous session recorded this as measured:

> fresh `git init -b feature-x`, **no `--base-branch`** produces
> `baseBranch: feature-x`, `baseBranchSource: current branch`

**Only the second half is right.** Re-driven:

| Repository | `baseBranch` | `baseBranchSource` |
|---|---|---|
| `git init -b feature-x`, **no commit** (unborn branch) | **`HEAD`** | `current branch` |
| `git init -b feature-x`, **one commit** | `feature-x` | `current branch` |

The cause is in the fallback itself. It runs `git rev-parse --abbrev-ref HEAD`
with stderr discarded and the status swallowed. On an unborn branch that command
**exits 128** and prints the literal word `HEAD` on stdout with a `fatal:` on
stderr. The discard hides the fatal and the swallow hides the status, so the
string `HEAD` is adopted as a branch name.

**The FR-013 fixture MUST make one commit** (an empty one is enough). Without it
the test still passes its `baseBranchSource` assertion while the branch name it
reports is meaningless — a test passing for the wrong reason, which is the exact
hazard the specification's Edge Cases name.

This is also a real, previously unrecorded finding about the script. It is
**out of scope** for this feature (FR-021: the probed script is not modified)
and is recorded here so it is not lost.

### The fallback needs two absences, and that is verified

A control was run: adding a remote **and** a symbolic ref for the remote's HEAD
to the same committed repository moves the answer to `main` / `origin/HEAD`. So
the fixture reaches the fallback only because neither earlier route applies — it
is not passing by accident.

---

## 3. The probe helper — mechanics, measured

### `run` inside a loaded function works

The open design risk was whether `run --separate-stderr` called from a function
defined in `tests/helper.bash` sets `status`, `output` and `stderr` for the
**calling test**. It does. Measured with a throwaway suite: a thin pass-through
helper, called with a fixture and a base-branch flag, left a zero status, a
661-byte output that `jq` parsed whole, and a diagnostic capture carrying both
expected warnings — all readable in the test body. `bats` does not declare those
names local, which is why this holds.

### The search-path shape: an environment prefix, not a subshell

The previously recorded technique wrapped the probe in a subshell that exported
`PATH`. **Do not use that shape inside a helper**: `run` executed inside a
subshell sets its variables in the subshell, and the calling test sees nothing.

The measured replacement keeps `run` at the caller's level and changes only the
child's environment, by invoking the probe through `env` with `PATH` set for
that one process.

**Trap 2 from the earlier session does not apply here.** That trap — a temporary
assignment prefix does not affect a builtin's own lookup — is about a builtin in
the *current* shell. The probe is a separate `bash` process, so its own
`command -v` honours the environment it was born with. Verified: with `PATH` set
to an empty directory, the probe exits non-zero with
`preflight: jq is required and was not found on PATH`.

**Trap 3 still applies.** Stripping `PATH` also removes `bash`, so the probe must
be invoked through an absolute interpreter path captured beforehand, in `setup`.

**Trap 1 still applies.** The shim directory must be a POSIX-form path, because a
drive-letter path used as a `PATH` entry splits on its own colon and every tool
then reads as absent. `BATS_TEST_TMPDIR` satisfies this for free and is what the
new tests use — no `mktemp -d` is needed.

### The six commands the probe needs

`awk`, `git`, `grep`, `head`, `jq`, `od` — derived from the script's own text,
not guessed. A shim directory carrying exactly these lets the probe run normally
while any other tool (`gh`, `adb`) reads as absent.

### Helper signature

The 24 existing call sites are not uniform: 21 pass a fixture and a base-branch
of `main`, two pass a base-branch of `trunk`, and one appends a project-type
override. FR-013 needs the base-branch flag **omitted entirely**. A helper that
hardcodes any flag therefore cannot express every call.

The shape that satisfies FR-018, FR-019 and FR-020 together is a **thin
pass-through**: the helper supplies only the `run` invocation and the script
path, and every caller still writes its own arguments, fixture included. That
keeps the conversion mechanical, keeps the fixture visible at each call site, and
makes SC-004 true by construction.

---

## 4. The announced skips — both causes discriminated

FR-012 is one test covering two routes into one branch. The branch fires when the
remote is not the expected host **or** the command-line client is absent.

### Route (a) is environment-dependent unless the test forces the issue

On this machine the client is a shim that Git Bash cannot see, so it reads absent
here and present on every CI runner. A route-(a) test that only sets a non-GitHub
remote **passes on this machine for route (b)'s reason**, and proves nothing.
This is the same class of vacuous test as the byte-order-mark fixture below.

**The discriminating construction:** put a client shim on the modified search
path so the client reads present, *then* set a non-GitHub remote.

| Sub-case | Search path | Remote | reported client | `willSkip` names M |
|---|---|---|---|---|
| route (a) | shims **plus a client shim** | a GitLab URL | **present** | **yes** |
| route (b) | shims, **no client** | a GitHub URL | absent | **yes** |
| **negative control** | shims **plus a client shim** | a GitHub URL | present | **no** |

The negative control is required: without it the assertion "M is named" cannot be
shown to go red when it should. Measured — the skip list is empty in that case.

The client shim needs no behaviour; a two-line script that exits zero, made
executable, is enough. The probe only asks whether the command can be found.

### FR-011, the runtime-check skip

The mobile fixture probed with a shim path that omits the device tool reports
that tool as absent, and the skip list carries an `N.5` entry whose reason names
the tool.

Note that this run **also** carries an M skip, because the mobile fixture sits
inside this checkout and inherits its remote while the client is off the shim
path. The FR-011 test must assert on the **N.5** entry specifically — selecting
by phase, never reading the first element of the list.

### The already-covered case

The no-remote cause (phases L and M) has a test already. FR-012 must not
duplicate it.

---

## 5. The refusal messages, captured verbatim

| FR | Driven with | Exit | Diagnostic stream |
|---|---|---|---|
| FR-001 | an unrecognised flag | 1 | `preflight: unknown argument '--nope' (legal: --dir --project-type --base-branch)` |
| FR-002 | the directory flag with nothing after it | 1 | a shell-generated line ending `2: --dir needs a path` |
| FR-003 | a directory path that does not exist | 1 | `preflight: cannot enter '<the path>'` |
| FR-004 | search path set to an empty directory | 1 | `preflight: jq is required and was not found on PATH` |

**FR-002 carries a line number and a script path, and neither may be asserted
on.** That message is emitted by the shell's own parameter expansion, not by the
script's own diagnostic function. Its line number moves whenever the script is
edited, and its path varies with how the suite invokes the probe. The test
asserts on the substring `--dir needs a path`, which is the part the script
actually chose. This is FR-024 applied to a message rather than to a document.

FR-004's test must also confirm the refusal is the data-tool one — an empty
search path can break the probe several ways, and a test asserting only a
non-zero exit would pass for any of them.

---

## 6. Fixtures: tracked, and proven to survive a clone

### The ignore rules already cover the new shapes

`.gitignore` carries a wholesale re-include of the fixtures tree. Checked with
`git check-ignore -q` — **and with controls in both directions**, because
`git check-ignore -v` exits 0 when it matches a *negation* rule too, and reading
its output as "ignored" is a trap.

| Path | Result |
|---|---|
| a path under the run-state directory *(positive control)* | ignored |
| a path under a dependency directory *(positive control)* | ignored |
| `pipeline/scripts/preflight.sh` *(negative control)* | not ignored |
| `README.md` *(negative control)* | not ignored |
| every planned new fixture path, **`.agents/` shape included** | **not ignored** |

So no new ignore rule is needed, and FR-023 is satisfiable with tracked fixtures
throughout.

### Byte-exact fixtures survive the attributes file

The attributes file normalises line endings for every path, and names Markdown
explicitly. Two fixtures carry bytes that rule could plausibly rewrite: a
byte-order mark, and a NUL. Both were committed and then read back **out of a
fresh clone** — the authoritative test, because that is what a new contributor
and CI both get:

| Fixture bytes | md5 before | md5 in a fresh clone | First bytes in the clone |
|---|---|---|---|
| mark, then spaces, newline, tab, newline | `79b38f9a…` | `79b38f9a…` | `ef bb bf 20 20 20 0a 09` |
| a letter, a NUL, then prose and a newline | `8017c8ee…` | `8017c8ee…` | `78 00 79 20 70 72 69 6e` |

**Both identical.** Tracked fixtures are safe for both, and no attributes change
is needed.

*An earlier attempt in this session appeared to show the NUL fixture vanishing.
That was an artefact of restoring a deleted directory from the index inside the
same working tree, not a property of the file. The fresh-clone measurement above
supersedes it, and the add step was separately confirmed to return zero and to
place the NUL file in the index.*

### Probe verdicts on the three parser fixtures

| Fixture | reported as carrying principles | Diagnostic stream |
|---|---|---|
| byte-order mark then whitespace only | `false` | *(none)* |
| NUL byte in the head | `false` | `preflight: constitution carries NUL bytes (a UTF-16/32 save?) — read as not set` |
| comment opened, never closed, principle prose after it | `true` | *(none)* |

All three at exit 0.

---

## 7. Carried forward from the previous session — verified there, not re-measured here

### The byte-order-mark fixture must be the discriminating one

The obvious fixture — a mark followed by a real constitution — reads as set
**with or without** the stripping, because the mark merely rides in front of text
that already counts. It is a vacuous test.

The discriminating fixture is **a mark followed by nothing but whitespace**.
Measured previously by mutating the stripping in the parser:

| | reads as set |
|---|---|
| stripping present (as shipped) | **false** — correct |
| stripping removed | **true** — the mark itself counted as content |

The script was restored and its hash re-checked. Section 6 above confirms the
shipped half independently.

### FR-016 — the multi-line comment case is already pinned

The seed warns that a previous review claimed this case was uncovered and was
wrong. Rather than trust either party, the multi-line stripping was deliberately
broken and the existing test *constitutionSet is true once the constitution
carries real principles* **went red**; the parser was then restored with its hash
re-checked.

**No test is to be added for it.** Doing so would also make fourteen new tests
against a stated acceptance of thirteen.

### The probed script is unchanged

Two temporary mutations were applied during the previous session's research and
both were restored with the object hash re-checked. The script's diff is empty.

---

## 7.1 Discrimination re-verified here — on **copies** of the script

The two parser fixtures whose stripping could make them vacuous were re-checked
in this session. **The tracked script was never modified.** Each mutation was
applied to a `cp` of it in a temporary directory, the mutation's diff was printed
before any verdict was believed, and the tracked script's own diff was confirmed
empty at the same time.

This matters beyond confirming the earlier record: **it found a constraint that
was not recorded anywhere.**

### The unclosed-comment fixture must open **with** the comment

Mutation: the parser's end-of-file branch for a still-open comment removed, so an
unclosed comment swallows everything after it.

| Fixture | as shipped | with the branch removed | discriminates? |
|---|---|---|---|
| a heading, blank line, **then** the unclosed comment, then principles | `true` | `true` | **no — vacuous** |
| the unclosed comment **on the very first line**, then principles | `true` | `false` | **yes** |

The reason is the same one that makes the byte-order-mark fixture subtle: any
real text *before* the comment already makes the file read as carrying
principles, so the test passes whether or not the text *after* the comment
survives. Only a file that begins with the comment isolates the property.

**The `constitution-unclosed` fixture therefore starts with `<!--` at the very
first byte.**

### The byte-order-mark fixture — the earlier record confirmed

Mutation: the parser's first-line mark strip removed. The mutation's diff was
exactly one deletion and zero insertions, printed before any verdict.

| Fixture | as shipped | with the strip removed | discriminates? |
|---|---|---|---|
| mark, then spaces, newline, tab, newline | `false` | `true` | **yes** |
| mark, then real prose | `true` | `true` | **no — vacuous** |
| mark, then a newline and nothing else | `false` | `true` | **yes** |

This reproduces the previous session's recorded result exactly, from a
different direction, and confirms that the obvious fixture is the vacuous one.

### The first attempt at this measurement was a false negative, and was caught

The mark-strip mutation initially matched **zero** occurrences of its anchor and
silently changed nothing, while the comparison table still printed a tidy-looking
`false` / `false`. That reads as "the fixture does not discriminate" and is
entirely wrong. It was caught only because the mutation's diff is printed and
checked before the verdict is read — the diff was empty. The rule that caught it
is the campaign's own: **prove the mutation landed before believing red or
green.**

## 8. Decisions this research settles

| Decision | Chosen | Rejected, and why |
|---|---|---|
| How to reach the three quiet warnings | Fixtures carrying **both** `.specify/templates/` and `.specify/scripts/` | A thinner fixture never enters the guarded block and warns nothing |
| One warning per fixture | Separate no-version and no-flavour fixtures | One fixture missing the init-options file fires both, so neither can be attributed |
| Helper shape | Thin pass-through; callers keep their own arguments | A helper that supplies a base-branch flag cannot express FR-013 |
| Search-path shape | An environment prefix on the child, `run` at caller level | A subshell loses `run`'s variables to the caller |
| Shim directory location | The per-test temporary directory | A freshly made temporary directory also works, but this is POSIX-form for free and cleaned up for free |
| FR-013 fixture | A fresh repository on a named branch **plus one empty commit** | Without a commit the reported branch is the literal string `HEAD` |
| FR-012 route (a) | Force the client present with a shim, then use a non-GitHub remote | A bare non-GitHub remote passes here for route (b)'s reason |
| Fixture storage | Tracked, under the existing fixtures directory | Runtime construction was considered for the byte-exact fixtures and is unnecessary: both survive a fresh clone unchanged |
| Byte-order-mark fixture | Mark then whitespace only | Mark then real prose passes either way |
| Unclosed-comment fixture | The comment on the **very first byte**, principles after it | Any real text before the comment makes the file read as set either way — measured vacuous in §7.1 |
| How to prove a fixture discriminates | Mutate a **copy** of the script, print the mutation's diff, then read the verdict | Mutating the tracked script risks leaving it changed; and a mutation that silently matched nothing produced a confident, wrong answer until its diff was checked |

## 9. Open items

**None.** Every behaviour named in the specification has been driven and
observed, and every fixture shape needed to reach it is recorded above.
