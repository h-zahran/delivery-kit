# Quickstart: 049-preflight-git-usable

Run from the repository root, in bash.

## 1. Usable (this checkout)

```bash
bash pipeline/scripts/preflight.sh | jq -c '{git: .capabilities.git, gitUsable: .capabilities.gitUsable, gitReason}'
```

Expect: `{"git":true,"gitUsable":true,"gitReason":"usable"}`.

## 2. Refused for ownership

```bash
q=$(mktemp -d); git init -q "$q/repo"; : > "$q/gitconfig"
GIT_CONFIG_GLOBAL="$q/gitconfig" GIT_CONFIG_NOSYSTEM=1 GIT_TEST_ASSUME_DIFFERENT_OWNER=1 \
  bash pipeline/scripts/preflight.sh --dir "$q/repo" | jq -c '{git: .capabilities.git, gitUsable: .capabilities.gitUsable, gitReason}'
echo "exit=$?"
```

Expect: `{"git":true,"gitUsable":false,"gitReason":"refused-ownership"}` and exit 0.

## 3. No repository

```bash
q=$(mktemp -d); mkdir "$q/plain"
GIT_CEILING_DIRECTORIES="$q" bash pipeline/scripts/preflight.sh --dir "$q/plain" | jq -c '.gitReason'
```

Expect: `"no-repository"`.

## 4. The suite

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests team/tests
```

Expect: every test ok, none skipped.
