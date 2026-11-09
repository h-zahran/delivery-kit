#!/usr/bin/env bash
# build-run.sh — builds, in the current folder, a project whose pipeline run
# waits at phase K, made with the kit's own progress.sh, never a hand-written
# state file. A case's fixture.sh sources this file, then adds what its case
# needs (a stray file, a tracked state file).
#
# The run: feature 001-greeting, base main, codeRoots ["src"]. G answered
# claude with review pieces, H built one piece (src/greet.js) and committed it
# after the spec commit, and the phases through J are done. No lock is left:
# the session that made the run is gone, as after a real crash.
set -euo pipefail

# This file sits in <plugin>/evals/lib/, so the plugin is two folders up.
plugin="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ps="$plugin/scripts/progress.sh"
[ -f "$ps" ] || { echo "build-run.sh: no progress.sh at $ps" >&2; exit 1; }
F=001-greeting
p() { bash "$ps" "$@"; }

git init -q -b main
git config user.email eval@example.com
git config user.name eval
git config commit.gpgsign false

# A spec-kit install as pre-flight reads one: the folders and the recorded
# version and script flavour. Nothing here runs a spec-kit command.
mkdir -p .specify/templates .specify/scripts/bash .specify/memory .claude/skills/speckit-plan src
printf -- "---\nname: speckit-plan\n---\n" > .claude/skills/speckit-plan/SKILL.md
printf '{"speckit_version":"0.16.5","script":"sh","integration":"claude"}\n' > .specify/init-options.json
printf '# spec template\n' > .specify/templates/spec-template.md
printf '#!/usr/bin/env bash\n' > .specify/scripts/bash/common.sh
printf '# Constitution\n\nKeep it small.\n' > .specify/memory/constitution.md
printf '.delivery-kit/\n' > .gitignore
printf '{"pipeline":{"codeRoots":["src"],"testCommand":"true","analyzeCommand":"true","baseBranch":"main"}}\n' > .delivery-kit.json
printf '# Greeter\n' > README.md
printf 'export const name = "app";\n' > src/app.js
git add .
git commit -qm "init"

git switch -qc "$F"
mkdir -p "specs/$F"
printf '# Spec: greeting\n\nFR-001: greet a person by name.\n' > "specs/$F/spec.md"
printf '# Plan: greeting\n\nOne function in src/greet.js.\n' > "specs/$F/plan.md"
printf '# Tasks: greeting\n\n## Phase 1: Greeting\n\n- [ ] T001 Add greet(name) in src/greet.js\n' > "specs/$F/tasks.md"

p init "$F" "$F" main other > /dev/null
p state-set "$F" config '{"planFile":"main-plan.md","testCommand":"true","analyzeCommand":"true","codeRoots":["src"],"baseBranch":"main","projectType":"other","commitStyle":"conventional","commitTrailers":[],"maxParallelAgents":3,"suiteReuse":"commit"}' > /dev/null
p state-set "$F" artifacts "{\"spec\":\"specs/$F/spec.md\",\"plan\":\"specs/$F/plan.md\",\"tasks\":\"specs/$F/tasks.md\"}" > /dev/null
for ph in preflight A B C C.5 D E F F.5 G; do p phase-start "$F" "$ph" > /dev/null; p phase-done "$F" "$ph" > /dev/null; done
p state-set "$F" gates G '{"answer":"claude","reviewMode":"commits"}' > /dev/null

p phase-start "$F" H > /dev/null
p spec-commit "$F" > /dev/null
p snapshot "$F" piece > /dev/null
cat > src/greet.js <<'JS'
export function greet(name) {
  return `Hello, ${name}!`;
}
JS
sed -i.bak 's/- \[ \] T001/- [X] T001/' "specs/$F/tasks.md" && rm -f "specs/$F/tasks.md.bak"
msg="$(mktemp)"
printf 'feat: greet a person by name\n' > "$msg"
p piece-commit "$F" "$msg" > /dev/null
rm -f "$msg"
p phase-done "$F" H > /dev/null
for ph in H.5 H.7; do p phase-start "$F" "$ph" > /dev/null; p phase-done "$F" "$ph" > /dev/null; done
# I is done only once each of its parts has a record: a short one each.
p phase-start "$F" I > /dev/null
p i-measure "$F" dispatch > /dev/null
for part in contract security tests bugs simplify fixes recheck; do
  p i-measure "$F" start "$part" > /dev/null; p i-measure "$F" "done" "$part" > /dev/null
done
p i-measure "$F" unmeasured findings > /dev/null
p phase-done "$F" I > /dev/null
p phase-start "$F" J > /dev/null; p phase-done "$F" J > /dev/null
p phase-start "$F" K > /dev/null
p lock-release "$F" > /dev/null 2>&1 || true
p validate "$F" > /dev/null
