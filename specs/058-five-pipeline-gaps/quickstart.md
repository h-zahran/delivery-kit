# Quickstart: prove the five fixes

Run from the repository root, on the feature branch, with the built scripts. Each block makes its own fixture repository in a temporary folder and removes it. No block uses the plugin cache.

Every block is one script: paste it whole. Each prints `PASS` at its end, and exits non-zero on the first fault.

## 1. Status 3, and the legal lines stay 0

```bash
set -eu
ROOT="$PWD"; PROG="$ROOT/pipeline/scripts/progress.sh"
W="$(mktemp -d)"; cd "$W"
git init -q -b main .; git config user.email t@t; git config user.name t
mkdir -p specs/001-demo; printf 'x\n' > specs/001-demo/spec.md; printf '.delivery-kit/\nspecs/\n' > .gitignore
git add .gitignore; git commit -qm init
bash "$PROG" init 001-demo 001-demo main other > /dev/null
bash "$PROG" state-set 001-demo artifacts spec '"specs/001-demo/spec.md"'
rc=0; bash "$PROG" suite-base 001-demo start || rc=$?
[ "$rc" -eq 3 ]
bash "$PROG" state-set 001-demo config '{"suiteReuse":"off","testCommand":"true"}'
rc=0; bash "$PROG" suite-base 001-demo start || rc=$?
[ "$rc" -eq 0 ]
cd "$ROOT"; rm -rf "$W"; echo PASS
```

## 2. The started line names the layer

```bash
set -eu
ROOT="$PWD"; PROG="$ROOT/pipeline/scripts/progress.sh"
W="$(mktemp -d)"; cd "$W"
git init -q -b main .; git config user.email t@t; git config user.name t
mkdir -p specs/001-demo; printf 'x\n' > specs/001-demo/spec.md; printf '.delivery-kit/\nspecs/\n' > .gitignore
git add .gitignore; git commit -qm init
bash "$PROG" init 001-demo 001-demo main other > /dev/null
bash "$PROG" state-set 001-demo artifacts spec '"specs/001-demo/spec.md"'
printf '%s\n' '{"suiteReuse":"commit","testCommand":"printf 1..0","testCommandFrom":"--config"}' > cfg.json
printf 'cfg.json\n' >> .gitignore; git add .gitignore; git commit -qm ignore
bash "$PROG" state-set 001-demo config --json-file cfg.json
out="$(bash "$PROG" suite-base 001-demo start)"
case "$out" in *', from "--config"') ;; *) echo "line: $out"; exit 1 ;; esac
bash "$PROG" suite-base 001-demo wait > /dev/null || true
cd "$ROOT"; rm -rf "$W"; echo PASS
```

## 3. `branch-cut` three times, then HEAD elsewhere

```bash
set -eu
ROOT="$PWD"; PROG="$ROOT/pipeline/scripts/progress.sh"
W="$(mktemp -d)"; cd "$W"
git init -q -b main .; git config user.email t@t; git config user.name t
printf '.delivery-kit/\n' > .gitignore; git add .gitignore; git commit -qm init
bash "$PROG" init 001-demo 001-demo main other > /dev/null
printf 'draft\n' > spec.md
for n in 1 2 3; do bash "$PROG" branch-cut 001-demo; done
[ "$(git symbolic-ref --short HEAD)" = 001-demo ]
[ "$(git rev-parse 001-demo)" = "$(git rev-parse main)" ]
[ -f spec.md ]
git checkout -q main
bash "$PROG" branch-cut 001-demo
[ "$(git symbolic-ref --short HEAD)" = 001-demo ]
cd "$ROOT"; rm -rf "$W"; echo PASS
```

## 4. The 056 mutant goes red

```bash
set -eu
ROOT="$PWD"
W="$(mktemp -d)"; git worktree add -q --detach "$W/t" HEAD; cd "$W/t"
python3 - <<'PY'
import re
p='pipeline/skills/pipeline/SKILL.md'
s=open(p,encoding='utf-8',newline='').read()
rec=re.compile(r"Record `config` here if it\s+is still empty, as Configuration says: `suite-base` reads it\. ")
assert len(rec.findall(s))==1
s=rec.sub('',s)
start=re.compile(r"Then run\s+`progress\.sh suite-base <feature> start` and print the one line it\s+prints:")
assert len(start.findall(s))==1
s=start.sub('It prints:',s)
c='**C — clarify, looped.**'
assert s.count(c)==1
s=s.replace(c,c+' Record `config` here if it is still empty, as Configuration says: `suite-base` reads it. Then run `progress.sh suite-base <feature> start` and print the one line.')
open(p,'w',encoding='utf-8',newline='').write(s)
PY
if git diff --quiet; then echo "the mutant did not land"; exit 1; fi
rc=0; bash "$HOME/bats/bin/bats" -f 'B records config before' pipeline/tests/prose.bats > "$W/o" 2>&1 || rc=$?
[ "$rc" -ne 0 ] || { echo "the mutant stayed green"; exit 1; }
grep -q 'phase B no longer runs the base suite start command' "$W/o"
cd "$ROOT"; git worktree remove --force "$W/t"; rm -rf "$W"; echo PASS
```

## 5. No shell reads a hostile trailer

```bash
set -eu
ROOT="$PWD"; PROG="$ROOT/pipeline/scripts/progress.sh"; PRE="$ROOT/pipeline/scripts/preflight.sh"
W="$(mktemp -d)"; cd "$W"
git init -q -b main .; git config user.email t@t; git config user.name t
printf '.delivery-kit/\nhostile.json\nvalues.json\n' > .gitignore; git add .gitignore; git commit -qm init
bash "$PROG" init 001-demo 001-demo main other > /dev/null
jq -n '["Task: it'"'"'s $(touch marker)"]' > hostile.json
bash "$PROG" state-set 001-demo config commitTrailers --json-file hostile.json
[ "$(jq --slurpfile x hostile.json '.config.commitTrailers == $x[0]' .delivery-kit/runs/001-demo/progress.json)" = true ]
[ ! -e marker ]
jq -n --slurpfile t hostile.json '{commitTrailers: $t[0]}' > values.json
rc=0; bash "$PRE" --values-file values.json > /dev/null 2> err || rc=$?
[ "$rc" -eq 1 ]
grep -q -- 'a commit trailer' err
[ ! -e marker ]
cd "$ROOT"; rm -rf "$W"; echo PASS
```

## 6. The skill still fits, and the suite is green

```bash
set -eu
n="$(wc -c < pipeline/skills/pipeline/SKILL.md)"
[ "$n" -lt 65536 ]
echo "SKILL.md $n bytes"
t="$(mktemp)"
bash scripts/run-suite.sh > "$t"
bash pipeline/scripts/progress.sh tap-check "$t"
rm -f "$t"; echo PASS
```
