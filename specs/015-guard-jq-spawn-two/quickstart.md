# Quickstart: proving the guard stops counting jq, part two

Every block is meant to be **run**, not read. Run them from the repository root.
Run sections 1 to 3 before the change and again after, and keep both outputs.

The baseline is pinned to the commit id `168edc1` everywhere below. Never pin it
to a branch name: this repository rebase-merges, so once the work lands, the
branch *is* the change and every comparison against it reports a flawless zero
having compared nothing.

## Prerequisites

```bash
cd "$(git rev-parse --show-toplevel)"
command -v jq && jq --version
ls "$HOME/bats/bin/bats"
ls handoff/hooks/context-guard.sh
ls scripts/context-guard/differential.sh
git cat-file -e 168edc1^{commit} && echo "baseline commit exists"
```

## 1. Count the processes, on both transcript shapes and all three configuration paths

This is the acceptance measurement. It counts three kinds of process, not one:
the parser, the text counter, and the input copier.

The rig: a shim directory holding fake `jq`, `grep` and `cat` that each record
one line per invocation and then exec the real one, prepended to the search
path; the home directory and working directory controlled so the number of
configuration files is exactly what we say it is; and two real transcripts, one
holding twenty readings so the capped read answers, and one holding six so the
under-fifteen fallback fires.

**The shim directory must contain no drive letter.** A `C:/…` entry in the
search path splits on its own colon under Git Bash, the shim is never found, and
every count reads `0` — which is indistinguishable from a perfect result.

```bash
cat > /tmp/count-proc.sh <<'EOF'
#!/usr/bin/env bash
set -u
HOOK="${1:?need the hook path}"
HOOK=$(cd "$(dirname "$HOOK")" && pwd)/$(basename "$HOOK")
root=/tmp/proccount; rm -rf "$root"; mkdir -p "$root/shim"
case "$root" in *:*) echo "REFUSING: shim path holds a colon: $root" >&2; exit 2 ;; esac
for tool in jq grep cat; do
  real=$(command -v "$tool")
  cat > "$root/shim/$tool" <<SHIM
#!/bin/sh
echo x >> "\$PROC_COUNT_DIR/$tool"
exec "$real" "\$@"
SHIM
  chmod +x "$root/shim/$tool"
done
cfg='{"contextGuard":{"windowTokens":1000000,"thresholdPct":65,"thresholdTokens":650000}}'
line='{"message":{"usage":{"input_tokens":1000,"cache_read_input_tokens":2000,"output_tokens":10}}}'
run_path() {
  shape="$1"; nread="$2"; nfiles="$3"
  d="$root/$shape-$nfiles"; mkdir -p "$d/home" "$d/work" "$d/counts"
  : > "$d/t.jsonl"
  i=1; while [ "$i" -le "$nread" ]; do printf '%s\n' "$line" >> "$d/t.jsonl"; i=$((i+1)); done
  [ "$nfiles" -ge 1 ] && printf '%s\n' "$cfg" > "$d/home/.delivery-kit.json"
  [ "$nfiles" -ge 2 ] && printf '%s\n' "$cfg" > "$d/work/.delivery-kit.json"
  for tool in jq grep cat; do : > "$d/counts/$tool"; done
  printf '{"transcript_path":"%s","session_id":"s-%s-%s","cwd":"%s"}' "$d/t.jsonl" "$shape" "$nfiles" "$d/work" \
    | env PATH="$root/shim:$PATH" HOME="$d/home" TMPDIR="$d/tmp" TEMP="$d/tmp" TMP="$d/tmp" \
          PROC_COUNT_DIR="$d/counts" bash "$HOOK" >/dev/null 2>&1
  mkdir -p "$d/tmp"
  printf '  %-9s %2d readings, %d config: jq=%s grep=%s cat=%s\n' \
    "$shape" "$nread" "$nfiles" \
    "$(wc -l < "$d/counts/jq" | tr -d ' ')" \
    "$(wc -l < "$d/counts/grep" | tr -d ' ')" \
    "$(wc -l < "$d/counts/cat" | tr -d ' ')"
}
echo "ordinary transcript (capped read answers):"
for n in 0 1 2; do run_path ordinary 20 "$n"; done
echo "starved transcript (uncapped re-read fires):"
for n in 0 1 2; do run_path starved 6 "$n"; done
rm -rf "$root"
EOF
mkdir -p /tmp/proccount && bash /tmp/count-proc.sh handoff/hooks/context-guard.sh
```

**Expected before the change**: `jq` 4/5/6 on the ordinary shape and 5/6/7 on
the starved one; `grep` 1 everywhere; `cat` 2 everywhere.

**Expected after**: `jq` 3/4/5 and 4/5/6; `grep` 0 everywhere; `cat` 1
everywhere.

The `cat` count falls to one, not to zero. This feature removes the copy of
standard input; the hook starts a second one further down to read the warning
flag, and that one is out of scope. Report the number the rig prints, never the
number the requirement wishes for.

## 2. Prove the same answer, side by side, over every shape

The committed harness. Read `scripts/context-guard/README.md` first — chiefly
the trap that the home directory *and* all three temporary-directory settings
must be isolated per side per shape, or the first side leaves its once-per-bucket
flag behind and silences the second, reporting differences on a correct hook.

```bash
scripts/context-guard/differential.sh 168edc1
echo "exit: $?"
```

Expected: every shape identical, exit `0`.

**Fire the positive control before believing that zero.** A harness that has
only ever printed zero has not been shown capable of printing anything else.

The control below mutates the FALLBACK FLOOR. An earlier version of this page
mutated the counting rule instead, and it was wrong twice over — a lesson worth
more than the block it replaced. Its `sed` pattern did not match the file, so it
was a no-op and the harness's identical-files guard aborted with exit 2. And had
it matched, the harness reports every shape identical for that mutation anyway,
because the counting rule decides only whether a second parser process runs and
never what the guard answers. A reader following it faithfully either aborted or
concluded the harness was blind. **Always echo the mutated line, and always pick
a mutation the instrument can actually see.**

```bash
cd "$(git rev-parse --show-toplevel)"
cp handoff/hooks/context-guard.sh /tmp/broken-guard.sh
# The fallback floor: fifteen to zero, so the uncapped re-read never runs.
python - /tmp/broken-guard.sh <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8', newline='').read()
old, new = '-lt 15 ]; then', '-lt 0 ]; then'
assert s.count(old) == 1, 'pattern found %d times, refusing' % s.count(old)
m = s.replace(old, new, 1)
assert m != s, 'MUTATION WAS A NO-OP'
io.open(p, 'w', encoding='utf-8', newline='').write(m)
print([l.strip() for l in m.split(chr(10)) if new in l][0])
PY
NEWHOOK=/tmp/broken-guard.sh scripts/context-guard/differential.sh 168edc1
echo "exit: $? (a NON-ZERO exit here is the pass)"
```

Expected: the mutated line echoed, then **three** shapes reported different —
`config: maxBytes tiny` and the two `byte cap of 1` transcript shapes — and a
non-zero exit. Those three are the only shapes that starve the capped read, so
they are the only ones where the fallback does anything. A zero here means the
harness cannot see the change and its clean run above means nothing.

A second control, for the median rather than the fallback:

```bash
cp handoff/hooks/context-guard.sh /tmp/broken-window.sh
python - /tmp/broken-window.sh <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8', newline='').read()
old, new = '.[-15:] | sort', '.[:15] | sort'
assert s.count(old) == 1, 'pattern found %d times, refusing' % s.count(old)
m = s.replace(old, new, 1)
assert m != s, 'MUTATION WAS A NO-OP'
io.open(p, 'w', encoding='utf-8', newline='').write(m)
print([l.strip() for l in m.split(chr(10)) if new in l][0])
PY
NEWHOOK=/tmp/broken-window.sh scripts/context-guard/differential.sh 168edc1
echo "exit: $? (a NON-ZERO exit here is the pass)"
```

Expected: one shape different, `transcript: median window matters`, and a
non-zero exit.

### What this harness cannot see

Two limits, both measured, both worth knowing before a clean run persuades you
of more than it should:

- **The counting rule.** It decides whether a second parser process runs, never
  what the guard answers. Section 9 pins it by process count instead.
- **Anything that only moves standard error.** The harness captures it per side
  and never compares it.

## 3. Prove the harness looks at the shapes this change touches

A shape list the harness does not carry is a shape nobody checked. Read it out
of the script rather than trusting this document.

```bash
grep -oE '^run_shape "transcript: [^"]+"' scripts/context-guard/differential.sh \
  | sed 's/^run_shape //'
printf 'transcript shapes: %s\n' \
  "$(grep -c '^run_shape "transcript:' scripts/context-guard/differential.sh)"
```

Expected: the printed list includes empty, one reading, fourteen, fifteen,
sixteen, an unparseable line among good ones, a non-numeric token value, a
non-numeric cache field, a record whose three token fields are all strings,
another whose three strings concatenate into numeric text, sidechain entries, and
a negative reading.

The block prints the count rather than asserting one, and this paragraph gives no
total on purpose: the figure moved twice in a single session, and each time a
written total went stale it was a shape asserted to DIFFER that had been left out
of the list.

**Two of them leave the window at its default, and that is load bearing.** The
byte-cap shapes first set a window of a million tokens, which put the readings
at 18% and left the guard below its threshold — so both sides said nothing, two
silences compared equal, and the shapes reported `ok` against a hook whose
fallback had been disabled outright. Measured: the floor-to-zero control passed
every shape until that was fixed. A shape that cannot make the guard SPEAK cannot
tell you it has stopped speaking.

## 4. Prove the stdin hazard is closed by construction

The parser-unavailable path exits early. If it stopped consuming standard input,
the caller writing to it would be signalled.

**Hide the parser with a shim that fails, never with a stripped search path.**
The first version of this block built a directory of symbolic links to every
tool the hook needs and pointed the search path at it. Windows does not make
those links from an ordinary shell, so the directory held no working `cat`, the
hook could not drain anything, and BOTH the changed hook and the baseline
reported the writer killed at 141. That reads exactly like the regression you
are hunting, and it is a broken rig. A shim that exits non-zero leaves every
other tool alone, and the hook treats a parser that cannot run as one that is
not there — its own comment says so.

```bash
cd "$(git rev-parse --show-toplevel)"
d=$(mktemp -d); mkdir -p "$d/bin" "$d/t1" "$d/t2"
printf '#!/bin/sh\nexit 127\n' > "$d/bin/jq"; chmod +x "$d/bin/jq"

# A payload larger than any pipe buffer, so a reader that does not read is
# certain to signal the writer rather than getting away with it.
{ printf '{"session_id":"s","transcript_path":"/nope"}'; head -c 200000 /dev/zero | tr '\0' '\n'; } > "$d/big.in"

echo "== the changed hook =="
( cat "$d/big.in"; echo "WRITER_EXIT=$?" >&2 ) 2>"$d/w1" \
  | env PATH="$d/bin:$PATH" TMPDIR="$d/t1" TEMP="$d/t1" TMP="$d/t1" \
        bash handoff/hooks/context-guard.sh > "$d/o1" 2>/dev/null
cat "$d/w1"; head -c 60 "$d/o1"; echo

echo "== the baseline, as a control =="
git show 168edc1:handoff/hooks/context-guard.sh > "$d/base.sh"
( cat "$d/big.in"; echo "WRITER_EXIT=$?" >&2 ) 2>"$d/w2" \
  | env PATH="$d/bin:$PATH" TMPDIR="$d/t2" TEMP="$d/t2" TMP="$d/t2" \
        bash "$d/base.sh" > "$d/o2" 2>/dev/null
cat "$d/w2"; head -c 60 "$d/o2"; echo
rm -rf "$d"
```

Expected: `WRITER_EXIT=0` from both, and the same hint text from both. A `141`
means the branch stopped consuming standard input and the caller is being
signalled — stop and fix it, do not ship it. **Run the control every time.** A
`0` from the changed hook alone does not tell you the rig was capable of
printing anything else.

Each side gets its own temporary directory because the hint flag is written
there and is filed once per machine. Share one and the second side finds the
flag already set, says nothing, and the comparison reports a difference that is
an artefact of the rig.

## 5. The hook's own suite, unedited

```bash
bash "$HOME/bats/bin/bats" --print-output-on-failure handoff/tests/context-guard.bats
echo "--- was it edited? ---"
git diff --stat 168edc1 -- handoff/tests/context-guard.bats
```

Expected: green. **The diff is NOT empty, and that is approved** — see spec
FR-011. This section said "expect an empty diff; a test that needed changing is
proof the behaviour changed, so stop rather than change the test" until the
owner decided otherwise at the implementer gate, and it is corrected here rather
than left standing: a resumed run follows this page, and following the old
sentence means reverting an approved change.

The rule it stated is still right in general. It did not fit this case, where
the test required the median to appear as a SEPARATE parser call in two files —
a fact about how many processes the guard starts, not about which reading it
believes, and removing that call is the entire change. What replaces "the diff
is empty" is a stronger check, because an empty diff never proved the test was
strong, only that it was untouched:

```bash
cd "$(git rev-parse --show-toplevel)"
# Every quantity duplicated between the hook and the setup skill, mutated one
# at a time, each mutation echoed, each file restored and the restore verified.
git diff --stat 168edc1 -- handoff/tests/context-guard.bats
grep -c '^READINGS_JQ=' handoff/hooks/context-guard.sh handoff/skills/setup/SKILL.md
grep -c '^MEDIAN_JQ='   handoff/hooks/context-guard.sh handoff/skills/setup/SKILL.md
grep -ohE 'tail -n [0-9]+ [|"]' handoff/hooks/context-guard.sh handoff/skills/setup/SKILL.md | sort -u
grep -cF 'jq -Rrn "[ inputs | ( $READINGS_JQ )? ] | $MEDIAN_JQ"' handoff/skills/setup/SKILL.md
```

Expected: a non-empty diff on the test file; one `READINGS_JQ` and one
`MEDIAN_JQ` declaration in each of the two files; a single distinct `tail -n`
budget across all three sites; and exactly one skill invocation spending both
declared programs. The last of those is the part that was missing when the
anchors first moved, and a skill with matching declarations and a five-wide
window inlined at its call site passed everything else.

## 6. The full house suite, from the repository root

```bash
cd "$(git rev-parse --show-toplevel)"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests > /tmp/house.tap
echo "exit: $?"
head -1 /tmp/house.tap
grep -c '^ok ' /tmp/house.tap
grep -c '^not ok ' /tmp/house.tap
```

Expected: `1..163`, `ok` count `163`, `not ok` count `0`, exit `0`.

Do not pipe the suite into `head` or `tail`. A pipe hands the block the last
command's status, always `0`, and cuts the plan line the runner prints first.

## 7. The comments survived

An inventory, not a glance. Every dated incident and every named failure mode
must appear in the changed file as often as it did in the baseline.

```bash
git show 168edc1:handoff/hooks/context-guard.sh > /tmp/guard-before.sh
for pat in '2026-08-07' '2026-08-15' '2026-08-18' '2026-09-01' \
           'LOAD BEARING' 'load bearing' 'load-bearing' \
           'NEVER FIRE' 'silently' 'IFS-whitespace' 'octal'; do
  b=$(grep -c -- "$pat" /tmp/guard-before.sh)
  a=$(grep -c -- "$pat" handoff/hooks/context-guard.sh)
  if [ "$a" -lt "$b" ]; then v="LOST"; else v="kept"; fi
  printf '  %-16s before=%s after=%s  %s\n' "$pat" "$b" "$a" "$v"
done
```

Expected: no `LOST`. A count that fell is a comment that was compressed away.

## 8. The static analyser

```bash
shellcheck --version | head -2
shellcheck handoff/hooks/context-guard.sh scripts/context-guard/differential.sh
echo "exit: $?"
```

Expected: exit `0`. Note that continuous integration has historically run an
**older** analyser than a developer machine, and the older one reported more.
A local pass does not predict the remote one; check the remote run too.

## 9. Pin the counting rule, which the comparison harness cannot see

The reading count decides whether the uncapped re-read RUNS. It never decides
the answer: the capped read is a byte suffix, so whenever it holds fifteen
readings its last fifteen are the file's last fifteen, and whenever it holds
fewer under either counting rule, both rules fall back. Mutating the rule to a
plain count therefore reports every shape identical in section 2.

The straddle below is fourteen positive readings and one negative: fifteen
under a plain count, fourteen under the digit rule. The two disagree about the
fallback and agree about everything a reader can see, so the only instrument
that can tell them apart is a process count.

```bash
cd "$(git rev-parse --show-toplevel)"
root=/tmp/fr016; rm -rf "$root"; mkdir -p "$root/shim"
case "$root" in *:*) echo "REFUSING: the shim path holds a colon" >&2; exit 2 ;; esac
real=$(command -v jq)
cat > "$root/shim/jq" <<SHIM
#!/bin/sh
echo x >> "\$JQ_COUNT_FILE"
exec "$real" "\$@"
SHIM
chmod +x "$root/shim/jq"

cp handoff/hooks/context-guard.sh "$root/mutant.sh"
python - "$root/mutant.sh" <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8', newline='').read()
old = 'map(select(tostring | test(' + chr(92) + '"^[0-9]' + chr(92) + '"))) | length'
assert s.count(old) == 1, 'count rule found %d times, refusing' % s.count(old)
m = s.replace(old, 'length', 1)
assert m != s, 'MUTATION WAS A NO-OP'
io.open(p, 'w', encoding='utf-8', newline='').write(m)
print('  mutant: ' + [l.strip() for l in m.split(chr(10)) if '| [ (length)' in l][0])
PY

run() {
  d="$root/$2"; mkdir -p "$d/home" "$d/work" "$d/tmp"
  : > "$d/t.jsonl"
  i=0
  while [ "$i" -lt 14 ]; do
    printf '%s\n' '{"message":{"usage":{"input_tokens":90000,"cache_read_input_tokens":90000}}}' >> "$d/t.jsonl"
    i=$((i + 1))
  done
  printf '%s\n' '{"message":{"usage":{"input_tokens":-5}}}' >> "$d/t.jsonl"
  : > "$d/count"
  printf '{"transcript_path":"%s","session_id":"s-%s","cwd":"%s"}' "$d/t.jsonl" "$2" "$d/work" \
    | env PATH="$root/shim:$PATH" HOME="$d/home" TMPDIR="$d/tmp" TEMP="$d/tmp" TMP="$d/tmp" \
          JQ_COUNT_FILE="$d/count" bash "$1" > "$d/out" 2>/dev/null
  printf '  %-16s jq=%s  stdout=%s bytes\n' "$2" \
    "$(wc -l < "$d/count" | tr -d ' ')" "$(wc -c < "$d/out" | tr -d ' ')"
}
run handoff/hooks/context-guard.sh shipped
run "$root/mutant.sh"             mutant
rm -rf "$root"
```

Expected: `shipped jq=5` and `mutant jq=4`, with **identical** stdout byte
counts. The differing process count is the rule being observed; the identical
output is why section 2 cannot observe it.

If both counts are `0`, the shim was never found — check the search path for a
drive letter, which splits on its own colon under Git Bash.
