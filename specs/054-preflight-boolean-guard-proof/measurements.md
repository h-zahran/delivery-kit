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
