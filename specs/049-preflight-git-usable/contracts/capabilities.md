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
  read-only command, `git rev-parse --git-dir`, which runs no hook and no
  configured program.
- With `gitUsable` false, the name checks that use git do not run; the names
  are reported unchecked, exactly as with git absent, and the script exits 0.

## What it does not promise

- `no-repository` does not say there is no repository. It says git opened
  none here. A refusal for a cause other than ownership, a git from 2.35.2
  to 2.35.x (ownership check, no `*`), and a git that runs `--version` but
  fails other commands all read `no-repository`.
- `capabilities.jq` is still hardcoded `true`: the report could not be
  written without jq. That claim is unchanged.

## Consumers

| Consumer | Reads | Effect |
|---|---|---|
| `pipeline/skills/pipeline/SKILL.md` pre-flight | `gitUsable`, `gitReason` | decision 11 fires on `gitUsable` false, first, and names the reason; the probe block's git line prints the reason |
| `pipeline/docs/rare-paths.md` | `gitUsable`, `gitReason` | the not-read rule and the git stop apply to every unusable reason |
| `pipeline/tests/preflight.bats` | every key | one fixture test per reason |
