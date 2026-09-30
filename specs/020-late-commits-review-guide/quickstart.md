# Quickstart: proving the late commits, the commit list and the review guide

Run everything from the repository root, in Git Bash on Windows or a shell on
Linux or macOS. Write multi-line blocks to a file and run the file: heredocs
through the agent's shell tool are not byte-safe.

## 1. The full house suite

```bash
out="$(mktemp)"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests > "$out" 2>&1; rc=$?
head -1 "$out"                                   # the plan line: 1..<N>
grep -c '^ok ' "$out"                            # must equal <N>
grep -c '^not ok ' "$out"                        # must be 0
grep -vcE '^(ok |not ok |1\.\.|#)' "$out"        # non-TAP lines: must be 0
echo "rc=$rc"                                    # must be 0
```

Expected: the baseline measured at F.5 before; that plus the new tests after;
the plan line equal to the ok count (a test can be counted and never run).

## 2. The pins alone, while iterating

```bash
bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/prose.bats
```

Iteration only. The verdict is step 1.

## 3. No old wording survives (SC-004)

The strings come from the contract's Absent section, never a typed copy
(Principle V). `$RUN/SKILL.md.orig` is the orchestrator saved before the
first edit; finding every string there is the positive control.

```bash
RUN=.delivery-kit/runs/020-late-commits-review-guide
C=specs/020-late-commits-review-guide/contracts/orchestrator-prose.md
new="$(tr '\n' ' ' < pipeline/skills/pipeline/SKILL.md | tr -s ' ')"
old="$(tr '\n' ' ' < "$RUN/SKILL.md.orig" | tr -s ' ')"
list="$(awk '/^## Absent/{f=1;next} /^## /{f=0} f && /^- `/' "$C" \
        | sed -E 's/^- `(.*)`( \(.*)?$/\1/')"
fail=0 n=0
while IFS= read -r s; do
  [ -n "$s" ] || continue
  n=$((n + 1))
  if grep -qF -- "$s" <<<"$new"; then in_new=1; else in_new=0; fi
  if grep -qF -- "$s" <<<"$old"; then in_old=1; else in_old=0; fi
  printf '%s | new=%s old=%s\n' "$s" "$in_new" "$in_old"
  [ "$in_new" = 0 ] && [ "$in_old" = 1 ] || fail=1
done <<<"$list"
[ "$n" -gt 0 ] || { echo "no strings read from the contract"; fail=1; }
echo "strings=$n fail=$fail"   # fail must be 0
```

## 4. The dry read (SC-003)

In a scratch git repository outside this one, with this repository's
`pipeline/scripts/progress.sh`: `init` a run, point `artifacts.tasks` at the
absolute path of `specs/017-guard-config-bounds/tasks.md`, and make and record
a `spec` commit. Then loop `piece-next`, making one REAL commit per piece in
the scratch repository (a placeholder file) and recording it with
`commit-add` and that commit's sha, until it prints nothing — real commits, so
the guide is joined against a real `rev-list`. 017's own `## Phase 7:` was
appended by a converge run before Phase 21 existed and was never recorded as
`converge`, so `piece-next` offers it and it appears as a `piece` row. Append a
`## Phase N: Convergence` section with one task to a COPY of the tasks file
(pointed at by `artifacts.tasks`), record it as kind `converge` with that
heading, and confirm `piece-next` then prints nothing. Make and record one
`simplify`, one `review`, one empty `tests` commit (`--allow-empty --only`,
no files), and one commit left unrecorded, which step V3 records as `other`.
Render the guide with the jq in [data-model.md](data-model.md) and save the commands, the
`piece-next` outputs and the rendered guide as
`specs/020-late-commits-review-guide/dry-read-017.md`. The saved file is the
measurement; nothing in it is predicted.

## 5. Tracked-state detection (research R5)

In a scratch repository, create `.delivery-kit/runs/f/progress.json` and run
`git --literal-pathspecs ls-files --error-unmatch -- <path>` untracked (with
and without `.delivery-kit/` ignored), after `git add -f`, and outside any
repository. Expected exits: 1, 1, 0, 128.

## 6. Scope (SC-005)

```bash
git diff --name-only "$(git merge-base main HEAD)"
git status --porcelain=v1 --untracked-files=all
```

Expected: `pipeline/skills/pipeline/SKILL.md`, `pipeline/tests/prose.bats`,
`pipeline/CHANGELOG.md`, and paths under
`specs/020-late-commits-review-guide/` — nothing else.

## 7. Shell analysis

```bash
git ls-files '*.sh' '*.bash' | grep -v '^\.specify/' | xargs shellcheck --norc -f gcc
```

Expected: clean. No shell file changes in this feature; this proves it.
