# Quickstart: 050-preflight-unread-git-fields

Run from the repository root, in bash.

## 1. Usable git (this checkout)

```bash
bash pipeline/scripts/preflight.sh | jq -c '.notRead'
```

Expect: `[]`.

## 2. Refused for ownership, no base flag

```bash
q=$(mktemp -d); git init -q "$q/repo"; : > "$q/gitconfig"
GIT_CONFIG_GLOBAL="$q/gitconfig" GIT_CONFIG_NOSYSTEM=1 GIT_TEST_ASSUME_DIFFERENT_OWNER=1 \
  bash pipeline/scripts/preflight.sh --dir "$q/repo" | jq -c '.notRead'
```

Expect: `["baseBranch","baseBranchSource","remote.kind","tree.dirty","willSkip.L","willSkip.M"]`.

## 3. Refused for ownership, base from an override

```bash
q=$(mktemp -d); git init -q "$q/repo"; : > "$q/gitconfig"
GIT_CONFIG_GLOBAL="$q/gitconfig" GIT_CONFIG_NOSYSTEM=1 GIT_TEST_ASSUME_DIFFERENT_OWNER=1 \
  bash pipeline/scripts/preflight.sh --dir "$q/repo" --base-branch-override main | jq -c '.notRead'
```

Expect: `["remote.kind","tree.dirty","willSkip.L","willSkip.M"]`.

## 4. The suites

```bash
bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats pipeline/tests/prose.bats
```

Expect: every test `ok`; the plan line's count equals the `ok` count.
