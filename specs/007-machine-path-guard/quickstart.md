# Quickstart: validating the machine-path guard

Every block below is runnable as written, from the repository root, in Git Bash.
Run them in order. Each states what it must print.

**Document constraint (FR-021):** this file is tracked and inside the scanned
surface, so it never writes a banned shape joined. Every pattern below is
assembled from parts at run time. That is not decoration — a joined literal
here would make this file a hit on the guard it validates.

**Before anything else, read this:** an expression passed as a shell argument
through some tooling loses one level of backslash escaping, and the two Windows
shapes then silently match nothing. A scan reporting zero hits is
indistinguishable from a scan that has stopped working. Every block that claims
"nothing matched" is preceded here by one that MUST match. Do not skip them,
and do not believe a clean result whose control you did not watch pass.

## 0. Prerequisites

```bash
cd "$(git rev-parse --show-toplevel)"
git rev-parse --abbrev-ref HEAD          # expect: 007-machine-path-guard
command -v jq >/dev/null && echo "jq ok" || echo "jq MISSING"
BATS="${BATS:-$HOME/bats/bin/bats}"
"$BATS" --version                        # expect: Bats 1.11.0
```

## 1. Build the four shapes, and prove the build worked

```bash
d=$(printf 'D:%s' '\')
c=$(printf 'C:%sUsers%s' '\' '\')
home_re='[/]c/Users/[A-Za-z0-9_]'
proj_re='~/\.claude/projects/[A-Za-z0-9-]'
printf 'drive-root  = [%s]\n' "$d"
printf 'windows-users = [%s]\n' "$c"
```

Expected: each prints the shape with its backslashes intact. If a backslash is
missing, stop — everything below this point would be a false green.

## 2. Positive controls — every one MUST print 1

```bash
printf '%s%s\n' '/c/Users/' 'alice'      | grep -cE "$home_re"
printf 'x %sGithub y\n'      "$d"        | grep -cF "$d"
printf 'x %sbob y\n'         "$c"        | grep -cF "$c"
printf '%s%s\n' '~/.claude/projects/' 'x' | grep -cE "$proj_re"
```

Expected: `1`, `1`, `1`, `1`. Any `0` means that shape is dead and every clean
result below is meaningless.

## 3. Negative control — MUST print 0

```bash
printf '%s%s\n' '/c/Users/' '...' | grep -cE "$home_re"
```

Expected: `0`. This is the narrowing that lets the three deliberate elided
references survive (FR-008). If this prints `1`, the scan will delete
documentation it must preserve.

## 4. The tracked tree is clean — every one MUST print 0

```bash
git grep -nE "$home_re" -- . ':(exclude)tests/' | wc -l
git grep -nF "$d"       -- . ':(exclude)tests/' | wc -l
git grep -nF "$c"       -- . ':(exclude)tests/' | wc -l
git grep -nE "$proj_re" -- . ':(exclude)tests/' | wc -l
```

Expected: `0`, `0`, `0`, `0`.

Before this feature the same four printed `35`, `1`, `0`, `1`.

> These four use `git grep` for convenience at a prompt. The **suite** must not
> — `git grep` exits 1 for a bad path, so it cannot tell "clean" from "could not
> look". See `research.md` R1. The suite enumerates with `git ls-files` and
> scans with plain `grep`.

## 5. The deliberate elided references survived

```bash
for s in specs/003-implementer-handoff/tasks.md:103 \
         specs/006-release-1-1-0/quickstart.md:127 \
         specs/006-release-1-1-0/tasks.md:1219; do
  f=${s%:*}; l=${s##*:}
  if [ "$(git show "main:$f" | sed -n "${l}p")" = "$(sed -n "${l}p" "$f")" ]
  then echo "IDENTICAL $s"; else echo "CHANGED   $s"; fi
done
```

Expected: three lines, all `IDENTICAL`. These are documentation, not leaks —
one of them is the recorded deferral of this very sweep.

> Compare the LINES, not a per-file count of the prefix. A count is the wrong
> check and this guide originally made that mistake: after the scrub the
> placeholder form still contains the prefix, so the counts read `1, 2, 3`
> rather than `1, 1, 1` and the block failed while nothing was wrong. Caught by
> executing this file instead of reading it.
>
> The comparison is against `main` because that is the branch this feature
> forks from. After the merge, compare against the commit before it.

## 6. The two new checks pass

```bash
BATS="${BATS:-$HOME/bats/bin/bats}"
"$BATS" --filter 'machine.path' tests/portability.bats
```

Expected: two tests, both `ok`, and a `1..2` plan line.

## 7. The control can actually fail — plant a leak and watch it go red

```bash
BATS="${BATS:-$HOME/bats/bin/bats}"
printf 'fixture: %sTemp%sscratch\n' "$c" '\' > /tmp/planted-leak.md
cp /tmp/planted-leak.md ./planted-leak.md
git add -N ./planted-leak.md
"$BATS" --filter 'machine.path' tests/portability.bats ; echo "exit=$?"
```

Expected: the scan **fails**, and names the file. `exit=1`.

Now remove it and confirm green returns:

```bash
BATS="${BATS:-$HOME/bats/bin/bats}"
git rm -q --cached ./planted-leak.md 2>/dev/null || true
rm -f ./planted-leak.md /tmp/planted-leak.md
git status --porcelain                     # expect: no planted-leak.md
"$BATS" --filter 'machine.path' tests/portability.bats ; echo "exit=$?"
```

Expected: both tests `ok`, `exit=0`.

> This block is the whole point of the feature. A check nobody has watched fail
> is not known to be a check.

## 8. Renaming a scanned path fails the scan, rather than passing it

```bash
BATS="${BATS:-$HOME/bats/bin/bats}"
"$BATS" --filter 'machine.path' tests/portability.bats >/dev/null && echo "baseline green"
```

Then, by hand, break the enumeration in `tests/portability.bats` — point it at
a directory that does not exist — and re-run. Expected: **fail**, not pass.
Restore the line afterwards and confirm green. This is contract C4 and it is the
difference between a guard and a decoration.

## 9. The existing denylist is untouched

```bash
git diff --stat main -- tests/portability.bats
git diff main -- tests/portability.bats | grep -c '^-.*BANNED_PATHS'
```

Expected: the file changed, and the second command prints `0` — the existing
denylist line was not removed or rewritten (FR-022, contract C7).

## 10. The whole suite, from the repository root

```bash
BATS="${BATS:-$HOME/bats/bin/bats}"
"$BATS" -r --print-output-on-failure tests handoff/tests pipeline/tests 2>&1 | tail -5
```

Expected: `1..123`, 123 ok, 0 not ok, 0 non-TAP.

The baseline before this feature was `1..121`. Any number other than 123 is a
finding, not a footnote.

## 11. Nothing this feature wrote trips the guard it built

```bash
d=$(printf 'D:%s' '\'); c=$(printf 'C:%sUsers%s' '\' '\')
files=$(find specs/007-machine-path-guard -type f -name '*.md' | sort)
[ -n "$files" ] || { echo "NO FILES FOUND - this check just checked nothing"; false; }
echo "checking $(printf '%s\n' "$files" | wc -l) files"
for f in $files; do
  n=$(( $(grep -cE '[/]c/Users/[A-Za-z0-9_]' "$f") \
      + $(grep -cF "$c" "$f") \
      + $(grep -cF "$d" "$f") \
      + $(grep -cE '~/\.claude/projects/[A-Za-z0-9-]' "$f") ))
  printf '%-60s %s\n' "$f" "$n"
done
```

Expected: a count line naming at least eight files, then every line ending
in `0`.

> Uses `find`, not `git ls-files`, and guards for emptiness. This block
> originally used `git ls-files` and printed **nothing at all**, because these
> files are still untracked while the feature is in flight — the loop body
> never ran and the check silently passed on an empty set. That is the same
> failure this whole feature exists to catch, reproduced inside the guide that
> validates it. Caught only by executing this file. The guard is now the point
> of the block as much as the counts are.

This feature's own documents live inside the surface it scans. That is exactly
how the original leak spread — a working note carried a path, the tooling copied
the note into the tree, and it multiplied across six directories.
