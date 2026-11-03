# Measurements: 054 preflight boolean guard proof

Each section is a record of one run on the date it names, not a claim about
the current files.

## Rig controls (T002), 2026-11-03

Run on Linux, from the repository root, against commit
`86b1973888e053ce903b8d45b3114be73f30bf8d`. Each control is a scratch copy
of `mutate.sh` with ONE line changed, line 118, the mutation's `sed`.

### (a) A mutation that changes nothing reads NO-OP and fails the rig

Changed line: `sed "s/--argjson $v \"/--argjson $v \"/" …` (replaces the
text with itself). Command: `bash rig-noop.sh 86b1973888e053ce903b8d45b3114be73f30bf8d`.
Exit 1. Output:

```text
commit   86b1973888e053ce903b8d45b3114be73f30bf8d
date     2026-11-03T16:02:43Z
mode     base
CONTROL green 1..119
derived  sk_present sk_in_range sk_const gh git git_usable adb dirty runs_live

var | fields | verdict | mutated line | red tests
sk_present | speckit.present | NO-OP |  | 
sk_in_range | speckit.versionInRange | NO-OP |  | 
sk_const | speckit.constitutionSet | NO-OP |  | 
gh | remote.ghPresent,capabilities.gh | NO-OP |  | 
git | capabilities.git | NO-OP |  | 
git_usable | capabilities.gitUsable | NO-OP |  | 
adb | capabilities.adb | NO-OP |  | 
dirty | tree.dirty | NO-OP |  | 
runs_live | tree.runsLive | NO-OP |  | 

BYTES    worktree preflight.sh identical to 86b1973888e053ce903b8d45b3114be73f30bf8d
```

### (b) A mutant that does not parse reads BAD and fails the rig

Changed line: `sed "s/--argjson $v \"/--arg $v /" …` (drops the opening
quote, so the script no longer parses). Command:
`bash rig-bad.sh 86b1973888e053ce903b8d45b3114be73f30bf8d`. Exit 1. Output:

```text
commit   86b1973888e053ce903b8d45b3114be73f30bf8d
date     2026-11-03T16:03:24Z
mode     base
CONTROL green 1..119
derived  sk_present sk_in_range sk_const gh git git_usable adb dirty runs_live

var | fields | verdict | mutated line | red tests
sk_present | speckit.present | BAD | bash -n failed | 
sk_in_range | speckit.versionInRange | BAD | bash -n failed | 
sk_const | speckit.constitutionSet | BAD | bash -n failed | 
gh | remote.ghPresent,capabilities.gh | BAD | bash -n failed | 
git | capabilities.git | BAD | bash -n failed | 
git_usable | capabilities.gitUsable | BAD | bash -n failed | 
adb | capabilities.adb | BAD | bash -n failed | 
dirty | tree.dirty | BAD | bash -n failed | 
runs_live | tree.runsLive | BAD | bash -n failed | 

BYTES    worktree preflight.sh identical to 86b1973888e053ce903b8d45b3114be73f30bf8d
```

### (c) The rig leaves this checkout alone (SC-002)

`git status --porcelain` saved before (a) and after (b): byte-identical
(`cmp` exit 0). Its one line, both times:
`?? specs/054-preflight-boolean-guard-proof/mutate.sh`. After both runs,
`git worktree list` names only the main checkout.

## Base table (T003), 2026-11-03

Before any assertion is added. Command, from the repository root:
`bash specs/054-preflight-boolean-guard-proof/mutate.sh 86b1973888e053ce903b8d45b3114be73f30bf8d`.
Exit 0 (HOLE is a finding on the base run, not a failure). Wall time 2 min
12 s. Output:

```text
commit   86b1973888e053ce903b8d45b3114be73f30bf8d
date     2026-11-03T16:04:28Z
mode     base
CONTROL green 1..119
derived  sk_present sk_in_range sk_const gh git git_usable adb dirty runs_live

var | fields | verdict | mutated line | red tests
sk_present | speckit.present | HOLE | 674:  --arg sk_present "$sk_present" --arg sk_version "$sk_version" \ | 
sk_in_range | speckit.versionInRange | HOLE | 675:  --arg sk_in_range "$sk_in_range" --arg sk_script "$sk_script" \ | 
sk_const | speckit.constitutionSet | CAUGHT | 677:  --arg sk_const "$sk_const" \ | a NUL in the constitution is found even when the reader stops at its first match; a NUL captured before the reading pipeline fails still reads as not set; a failed read of the constitution's head still reaches the parse and exits 0
gh | remote.ghPresent,capabilities.gh | CAUGHT | 681:  --arg  remote "$remote" --arg gh "$gh_present" --arg gh_command "$gh_command" \ | capabilities reports jq true and booleans for gh and adb; gh installed only as gh.cmd is found, named, and keeps the review phase
git | capabilities.git | CAUGHT | 683:  --arg git "$git_present" --argjson git_usable "$git_usable" \ | the capability report names git present when git is findable; the capability report names git absent, and the report survives it; the capability report names a git that refuses the repository for ownership; the ownership refusal is found from exit codes, with git's messages gone; an unusable git reports names unchecked, as an absent one does; the capability report names a git that opens no repository here; the capability report names a git that is found but cannot run; an unusable git with no base flag names the base fields, and never a device skip; a usable git names nothing, even with no remote; without git, the override and the feature branch are reported unchecked
git_usable | capabilities.gitUsable | CAUGHT | 683:  --argjson git "$git_present" --arg git_usable "$git_usable" \ | the capability report names git present when git is findable; the capability report names git absent, and the report survives it; the capability report names a git that refuses the repository for ownership; the ownership refusal is found from exit codes, with git's messages gone; an unusable git reports names unchecked, as an absent one does; the capability report names a git that opens no repository here; the capability report names a git that is found but cannot run; an unusable git with no base flag names the base fields, and never a device skip; a usable git names nothing, even with no remote
adb | capabilities.adb | CAUGHT | 682:  --arg adb "$adb_present" \ | capabilities reports jq true and booleans for gh and adb
dirty | tree.dirty | CAUGHT | 685:  --arg dirty "$dirty" --argjson runs_live "$runs_live" \ | tree: work the repository's configuration hides from git status is dirty; tree: a skip-worktree file and a clean sparse checkout are not dirty
runs_live | tree.runsLive | CAUGHT | 685:  --argjson dirty "$dirty" --arg runs_live "$runs_live" \ | a DONE run and an abandoned run are not live;  each live run is named; an unreadable state file is warned about and named, never counted as live

BYTES    worktree preflight.sh identical to 86b1973888e053ce903b8d45b3114be73f30bf8d
```

**HOLE vars:** `sk_present` (`speckit.present`) and `sk_in_range`
(`speckit.versionInRange`), exactly the two research R2 expected. Emitted as
strings, they leave all 119 tests in `preflight.bats` green. Phase 3 adds an
assertion for these two and no others.

**The guard of each CAUGHT row** (FR-003): a red test whose failing line
reads that field.

| var | guard test | the line that goes red |
|---|---|---|
| `sk_const` | "a NUL in the constitution is found even when the reader stops at its first match" (and two neighbours) | `jq -e '.speckit.constitutionSet == false'` |
| `gh` | "capabilities reports jq true and booleans for gh and adb" | `jq -e '.capabilities.gh \| type == "boolean"'` |
| `git` | "the capability report names git present when git is findable" (and nine more) | the `type == "boolean"` checks on `.capabilities.git` |
| `git_usable` | "the capability report names git present when git is findable" (and eight more) | `(.capabilities.gitUsable \| type) == "boolean"` in the shared check |
| `adb` | "capabilities reports jq true and booleans for gh and adb" | `jq -e '.capabilities.adb \| type == "boolean"'` |
| `dirty` | "tree: work the repository's configuration hides from git status is dirty" | `jq -e --argjson w "$want" '.tree.dirty == $w'` |
| `runs_live` | "a DONE run and an abandoned run are not live" | `jq -e '.tree.runsLive \| type == "boolean"'` |

So issue #34's two assertions (`gh`, `adb`) are each proved here: their
mutant turns red the test that holds them, on the base commit, with nothing
added.

## Rig fix, and its controls run again (T007), 2026-11-03

The first finished-table run (rig as committed in `8d8e2be`) counted the
red tests by splitting their joined names on `;`. One test name holds a `;`
("a DONE run and an abandoned run are not live; each live run is named"), so
`runs_live` was counted as four red tests where three failed. No verdict
changed: every row was CAUGHT, and CAUGHT needs only one red test besides the
walk. The rig now takes both counts from the TAP file (`grep -c '^not ok'`,
and `grep -cxF` for the walk's name) and joins the names with ` | ` for
display only. The base table above is unaffected: its verdicts read only
whether any test was red.

Both controls were run again on the fixed rig, against `HEAD` =
`89083394f0770a16200b3e0561ae3a63353c616d`, the same one-line changes now at
line 121: the NO-OP copy exits 1 with 9 of 9 rows `NO-OP`; the BAD copy exits
1 with 9 of 9 rows `BAD`. `git status --porcelain` was byte-identical before
the two controls and after the finished table below.

## Finished table (T007), 2026-11-03

Command, from the repository root:
`bash specs/054-preflight-boolean-guard-proof/mutate.sh --final HEAD`, with
HEAD = `89083394f0770a16200b3e0561ae3a63353c616d` (Phase 3's commit). Exit 0.
Output:

```text
commit   89083394f0770a16200b3e0561ae3a63353c616d
date     2026-11-03T16:18:01Z
mode     final
CONTROL green 1..120
derived  sk_present sk_in_range sk_const gh git git_usable adb dirty runs_live

var ; fields ; verdict ; mutated line ; red count ; red tests (joined by ' | ')
sk_present ; speckit.present ; CAUGHT ; 674:  --arg sk_present "$sk_present" --arg sk_version "$sk_version" \ ; 2 ; the no-speckit fixture reports the tool absent, exit 0 -- reporting is not failing | no report field is the string "true" or "false"
sk_in_range ; speckit.versionInRange ; CAUGHT ; 675:  --arg sk_in_range "$sk_in_range" --arg sk_script "$sk_script" \ ; 2 ; the web fixture reads version and sh flavour, resolving the bash scripts dir | no report field is the string "true" or "false"
sk_const ; speckit.constitutionSet ; CAUGHT ; 677:  --arg sk_const "$sk_const" \ ; 4 ; no report field is the string "true" or "false" | a NUL in the constitution is found even when the reader stops at its first match | a NUL captured before the reading pipeline fails still reads as not set | a failed read of the constitution's head still reaches the parse and exits 0
gh ; remote.ghPresent,capabilities.gh ; CAUGHT ; 681:  --arg  remote "$remote" --arg gh "$gh_present" --arg gh_command "$gh_command" \ ; 3 ; capabilities reports jq true and booleans for gh and adb | no report field is the string "true" or "false" | gh installed only as gh.cmd is found, named, and keeps the review phase
git ; capabilities.git ; CAUGHT ; 683:  --arg git "$git_present" --argjson git_usable "$git_usable" \ ; 11 ; no report field is the string "true" or "false" | the capability report names git present when git is findable | the capability report names git absent, and the report survives it | the capability report names a git that refuses the repository for ownership | the ownership refusal is found from exit codes, with git's messages gone | an unusable git reports names unchecked, as an absent one does | the capability report names a git that opens no repository here | the capability report names a git that is found but cannot run | an unusable git with no base flag names the base fields, and never a device skip | a usable git names nothing, even with no remote | without git, the override and the feature branch are reported unchecked
git_usable ; capabilities.gitUsable ; CAUGHT ; 683:  --argjson git "$git_present" --arg git_usable "$git_usable" \ ; 10 ; no report field is the string "true" or "false" | the capability report names git present when git is findable | the capability report names git absent, and the report survives it | the capability report names a git that refuses the repository for ownership | the ownership refusal is found from exit codes, with git's messages gone | an unusable git reports names unchecked, as an absent one does | the capability report names a git that opens no repository here | the capability report names a git that is found but cannot run | an unusable git with no base flag names the base fields, and never a device skip | a usable git names nothing, even with no remote
adb ; capabilities.adb ; CAUGHT ; 682:  --arg adb "$adb_present" \ ; 2 ; capabilities reports jq true and booleans for gh and adb | no report field is the string "true" or "false"
dirty ; tree.dirty ; CAUGHT ; 685:  --arg dirty "$dirty" --argjson runs_live "$runs_live" \ ; 3 ; no report field is the string "true" or "false" | tree: work the repository's configuration hides from git status is dirty | tree: a skip-worktree file and a clean sparse checkout are not dirty
runs_live ; tree.runsLive ; CAUGHT ; 685:  --argjson dirty "$dirty" --arg runs_live "$runs_live" \ ; 3 ; no report field is the string "true" or "false" | a DONE run and an abandoned run are not live; each live run is named | an unreadable state file is warned about and named, never counted as live

BYTES    worktree preflight.sh identical to 89083394f0770a16200b3e0561ae3a63353c616d
```

Every one of the nine derived mutants is CAUGHT (SC-001): its own guard goes
red, and so does the walk.

- `sk_present` and `sk_in_range`, the two HOLE rows of the base table, are
  now caught by the assertions T004 added, in "the no-speckit fixture reports
  the tool absent, exit 0 -- reporting is not failing" and "the web fixture
  reads version and sh flavour, resolving the bash scripts dir".
- The other seven keep the guards the base table names.
- The `gh` mutant turns two fields into strings, `capabilities.gh` and
  `remote.ghPresent`: one variable fills both.
