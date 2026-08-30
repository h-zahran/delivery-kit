# Phase 0 research: Pre-flight names git

Every finding here was measured on 2026-08-30 against the tree at
`main` = `348597a`. Re-measure before trusting a line; a recorded measurement
is evidence of what was true when it was taken, not a guarantee.

## Decision 1 — the script reports, the orchestrator stops

**Decision**: `preflight.sh` reports `capabilities.git` and nothing else. The
hard stop lives in the orchestrator's pre-flight decision walk.

**Rationale**: three independent reasons point the same way.

- The script's own header states the contract: *"This script only REPORTS …
  A missing capability degrades a named phase; it never crashes one."*
- The absent-git test asserts on the emitted report. A script that aborted
  would emit no report, and the test could only assert on an exit code and a
  stderr line — weaker evidence for the same claim.
- The orchestrator already owns every other stop at pre-flight, including the
  one for an absent spec tool, which is the closest existing analogue.

**Alternatives considered**: `die "git is required and was not found on PATH"`,
mirroring the existing `jq` guard at the top of the script. Rejected: `jq` is
different in kind — the script cannot emit its own report without `jq`, so its
absence is a self-inflicted crash, not a reported fact. git's absence is a fact
the script can perfectly well report.

## Decision 2 — an absent git is a stop, not an announced skip

**Decision**: no `willSkip` entry is added on git's account.

**Rationale**: a `willSkip` entry means *this named phase will not run, and the
rest of the run still makes sense*. That is true of `adb` (only the runtime
check needs it) and of `gh` (only the review phase needs it). It is not true of
git: phases B, K and L are git operations, and the probe's own base-branch and
tree reads are git commands. There is no subset of the run that survives.

Note the second-order effect, which the absent-git test asserts on directly:
with git off the search path, `git remote get-url origin` fails, so `remote`
reads `none`, so the existing no-remote branch already announces skips for
phases L and M. Those two are consequences of the missing remote reading, not
of a new git rule — and the test pins the set to exactly `["L","M"]` so a
future git-flavoured skip cannot be added without a red test.

**Alternatives considered**: announcing skips for B, K and L. Rejected: the
seed names this exact trap — *"a `Missing: git` line alone would be a named
capability nobody acts on"* — and announcing three skips is the same failure
wearing more words.

## Decision 3 — the new item is numbered last and fires first

**Decision**: the git decision is written as item **11**, after item 10, and
its own text states that it fires before item 1 and before every other item.

**Rationale**: the specification forbids renumbering (FR-008), and the owner
chose "first, before everything" at clarify. Those two are only compatible if
the item's position on the page and its position in the order differ, and the
text says so.

There is precedent in the same list. Item 10 reads: *"The enum is checked when
configuration resolves, before this decision walk begins … this item anchors
the rule, it is not where the check first runs."* Item 11 uses the same shape.

**Why it must fire first**, concretely: item 5 runs `git status --porcelain`
and item 6 runs `git check-ignore`. With git absent, item 5 reads a clean tree
and item 6 reads "not ignored" — both wrong, both silent, and item 6 would then
offer to write to `.gitignore` in a repository the operator cannot commit to.

**Alternatives considered**: firing just before item 5. Rejected by the owner
at clarify, and it would leave items 1–4 spending the operator's attention on a
run that cannot happen.

## Decision 4 — the install pointer is the download page

**Decision**: the stop prints `https://git-scm.com/downloads`.

**Rationale**: the owner chose it at clarify. The pipeline supports Linux,
macOS and Windows, CI runs all three, and the probe has no way to know which
package manager the operator uses. A page that lists all of them cannot be
wrong; `apt install git` on a machine without apt is wrong and unhelpful.

**Alternatives considered**: detecting the platform and printing one of
`winget install Git.Git` / `brew install git` / `apt install git`. Rejected at
clarify.

## Finding A — the suite's `PROBE_TOOLS` already contains git

Measured at `pipeline/tests/preflight.bats`:

```
PROBE_TOOLS="awk git grep head jq od"
```

Its comment says the list is *"read out of the script rather than guessed"*.
The absent-git test therefore needs no new mechanism: it calls the existing
`shimdir` helper with the other five names, and `probe --path` runs the script
against that directory alone. Every other capability test in the suite is built
this way, and the suite's own comment explains why the ambient environment
cannot be trusted here.

## Finding B — the script survives git's absence today

Traced through `preflight.sh` with `set -euo pipefail` in force. All four git
reads are already guarded, so none of them can abort the script:

| Line | Form | Why it survives |
|---|---|---|
| `git symbolic-ref …` | inside `if b="$(…)"` | a failing command in an `if` condition is exempt from `errexit` |
| `git rev-parse …` | `$(… || true)` | the `|| true` swallows the status |
| `git remote get-url …` | inside `if url="$(…)"` | same exemption as the first |
| `git status --porcelain` | `[ -n "$(… || true)" ] && dirty=true` | `|| true` inside, and a failing left side of `&&` is exempt |

This is exactly the defect the seed describes: the script keeps going and
reports a happy empty base branch and a clean tree. Nothing about that
behaviour needs to change — what changes is that the report now says why.

The new probe uses the same `x=false; command -v x >/dev/null 2>&1 && x=true`
shape as the existing `gh` and `adb` probes. Under `errexit` a failing command
in a non-final position of an `&&` list does not exit the shell, which is why
those two lines have worked since they were written.

## Finding C — `pipeline/docs/configuration.md` enumerates no capability

Measured: the file contains no occurrence of `jq`, `gh`, `adb` or `git`, and no
capability list of any kind. FR-011 is conditional on such an enumeration
existing, so it resolves to **do not edit this file**. Re-run the grep before
acting; if the file has since grown a capability list, the requirement fires.

## Finding D — what the prose suite pins, and where

`pipeline/tests/prose.bats` builds two slices of the orchestrator and greps
inside them:

- `probe="$(awk '/^Project type : /,/^Will skip /' "$ORCH")"` — pins the
  `Implementer` template line verbatim inside this slice.
- `walk="$(awk '/^The script only reports; the decisions are yours/,/^\*\*Base branch:\*\*/' "$ORCH")"`
  — pins item 10's operative sentence inside this slice.

Both planned insertions land **inside** a slice, and both are still safe,
because a slice grows to hold a new line and every pinned string is still found
within it. What a slice cannot survive is a REWORD, and neither insertion
rewords anything.

- The new `git` line lands inside the probe slice, before `Base branch`. The
  one string pinned inside that slice is the `Implementer` template line, which
  is untouched. Adding a line to the block also has precedent for its content:
  the `Remote` line already calls out one capability — `gh` — on its own line,
  alongside the generic `Available`/`Missing` pair.
- Item 11 lands inside the walk slice, after item 10 and before the
  `**Base branch:**` line that closes it. The one string pinned inside that
  slice is item 10's operative sentence, which is untouched.

No pinned string is reworded by either. This was checked by reading
`pipeline/tests/prose.bats` lines 111–205, not inferred.

## Finding E — the analyser this repository is judged by is older than this one

CI installs whatever `shellcheck` the runner image ships and prints the
version; measured 2026-08-30 it is **0.9.0**. The local analyser here is
**0.11.0**. The older one reports findings the newer one does not, so a local
green does not predict CI. `CONTRIBUTING.md` states this and says to read the
version from the job log.

Consequence for this run: analyse locally with 0.11.0 as usual, but treat the
CI `shell-analysis` job as the arbiter at phases M and N, and do not conclude
from a local green that the job will pass. Nothing is installed to close the
gap — that would be a silent tool install.

## Finding F — `gh` is present despite the probe saying otherwise

`preflight.sh` reported `capabilities.gh: false` on this machine. That is a
false negative: `gh` is a Scoop shim at `C:\Users\h_zah\scoop\shims\gh.cmd`,
which the Bash environment's `command -v` cannot see. Verified in PowerShell:
`gh version 2.92.0`.

Consequence for this run: **phase M is not skipped**, and every `gh` call must
be made through PowerShell rather than Bash. This is a property of the machine,
not a defect in this feature, and it is recorded in the run's state file.
