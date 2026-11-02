# Contract: the pre-flight probe's git keys

This contract supersedes the "What the probe does NOT promise about git"
section of `specs/013-preflight-git-probe/contracts/capabilities.md`. Every
other part of that contract — pure JSON stdout, exit 0 when a tool is
missing, existing keys immutable, the document always complete — still
holds, and this feature keeps it.

## Keys

```json
{
  "capabilities": { "jq": true, "git": true, "gitUsable": false, "gh": true, "adb": false },
  "gitReason": "refused-ownership"
}
```

| `gitReason` | `capabilities.git` | `capabilities.gitUsable` | Means |
|---|---|---|---|
| `usable` | `true` | `true` | git runs and opens a repository at the probed folder |
| `absent` | `false` | `false` | git cannot be found on the search path |
| `broken` | `true` | `false` | git is found, but `git --version` fails |
| `refused-ownership` | `true` | `false` | git opens a repository here only when its ownership check is lifted |
| `no-repository` | `true` | `false` | git runs, but opens no repository here, for any other cause |

## What the probe promises

- It decides from exit codes only. It never reads git's message text.
- It writes no git configuration. It lifts the ownership check for one
  read-only command, `git rev-parse --git-dir`, which parses the refused
  repository's configuration and its includes but runs no hook and no
  configured program (measured on git 2.53.0 against 28 planted programs).
- It reports no path. The orchestrator never names the refused
  repository: git may have found one in a folder above the probed one,
  and only the owner can tell whether it is theirs. "The git stop" sends
  the owner to git's own message, which names it.
- With `gitUsable` false, the name checks that use git do not run; the names
  are reported unchecked, exactly as with git absent, and the script exits 0.

## What it does not promise

- `no-repository` does not say there is no repository. It says git opened
  none here. A refusal for a cause other than ownership, a git that runs
  `--version` but fails other commands, and EVERY ownership refusal on a
  git older than 2.38 read `no-repository`: before 2.38, git's own
  documentation says `safe.directory` given with `-c` is not respected
  (checked in `Documentation/config/safe.txt` at v2.35.2, v2.36.0, v2.37.0
  and v2.38.0, 2026-11-02). The `no-repository` advice sends the owner to
  git's own message, which names the ownership case on those gits too.
- Neither `usable` nor `refused-ownership` says the repository is the
  probed folder's own. git climbs to the nearest `.git` above the folder:
  for `usable` that is how a run started in a subfolder of a checkout
  works, and it is also how a folder that is not a repository reads
  `usable` inside an enclosing one the owner owns; for `refused-ownership`
  a repository planted above by another user reads the same.
- `usable` means git opened a repository, not that it has a working tree:
  inside `.git` or a bare repository, `rev-parse --git-dir` succeeds and
  the working-tree read later fails silently. That was so before this
  feature too, and is left to a later one.
- `broken` is reached only after `rev-parse` failed: a git that fails
  `--version` but opens the repository reads `usable`.
- The lifted call has no time limit. An include in the refused
  repository's configuration that points at a FIFO stalls it (measured);
  nothing runs, and the owner sees a hang. No portable `timeout` exists on
  every supported system, and a timer in the script would be a timing
  guard, which this suite has seen die under load.
- `capabilities.jq` is still hardcoded `true`: the report could not be
  written without jq. That claim is unchanged.

## Consumers

| Consumer | Reads | Effect |
|---|---|---|
| `pipeline/skills/pipeline/SKILL.md` pre-flight | `gitUsable`, `gitReason` | decision 11 fires on `gitUsable` false, first, and names the reason; the probe block's git line prints the reason |
| `pipeline/docs/rare-paths.md` | `gitUsable`, `gitReason` | the not-read rule and the git stop apply to every unusable reason |
| `pipeline/tests/preflight.bats` | every key | one fixture test per reason |
