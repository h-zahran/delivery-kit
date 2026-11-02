# Quickstart: 051-preflight-failed-git-reads

Run from the repository root, in bash. `id` is the identity a scratch
commit needs.

```bash
P="$PWD/pipeline/scripts/preflight.sh"
id=(-c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false)
```

## 1. No commit yet, no base flag

```bash
q=$(mktemp -d); git init -q -b work "$q"
bash "$P" --dir "$q"; echo "rc=$?"
```

Expect: no JSON; one `preflight:` line saying the current branch has no
commit yet; `rc=1`.

## 2. Detached HEAD, no base flag

```bash
q=$(mktemp -d); git init -q -b work "$q"; git -C "$q" "${id[@]}" commit -q --allow-empty -m seed
git -C "$q" checkout -q --detach
bash "$P" --dir "$q"; echo "rc=$?"
```

Expect: no JSON; one `preflight:` line saying `HEAD` is detached; `rc=1`.

## 3. A damaged index

```bash
q=$(mktemp -d); git init -q -b work "$q"; git -C "$q" "${id[@]}" commit -q --allow-empty -m seed
: > "$q/untracked"; printf garbage > "$q/.git/index"
bash "$P" --dir "$q"; echo "rc=$?"
```

Expect: no JSON; one `preflight:` line saying the working tree's status
could not be read; `rc=1`.

## 4. The same commit-less repository with a base flag

```bash
q=$(mktemp -d); git init -q -b work "$q"
bash "$P" --dir "$q" --base-branch main | jq -c '{baseBranch, baseBranchSource, notRead}'
```

Expect: `{"baseBranch":"main","baseBranchSource":"configured","notRead":[]}`.

## 5. The suites

```bash
bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats pipeline/tests/prose.bats
```

Expect: every test `ok`; the plan line's count equals the `ok` count.
