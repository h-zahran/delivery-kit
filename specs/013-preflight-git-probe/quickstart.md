# Quickstart: proving pre-flight names git

Every block below is meant to be **run**, not read. Run them from the
repository root.

## Prerequisites

```bash
cd "$(git rev-parse --show-toplevel)"
command -v jq && jq --version
ls "$HOME/bats/bin/bats"
```

## 1. See the new capability, on a machine that has git

```bash
bash pipeline/scripts/preflight.sh \
  | jq -e '.capabilities | has("git") and (.git | type == "boolean")' \
  && echo "git is reported, as a boolean"
bash pipeline/scripts/preflight.sh | jq -c '.capabilities'
```

Expected: the assertion passes and the object printed below it carries
`"git": true` on a machine that has git.

The assertion deliberately does NOT count the members. A count would be wrong
the next time a capability is added, and wrong in the flattering direction — a
reader who counts one more and shrugs has learned to distrust this document.
The type is asserted because `jq -r` prints the JSON string `"true"` as a bare
`true`, so a value check alone cannot tell the two apart.

## 2. See it read `false`, without uninstalling anything

Build a search path holding every tool the probe uses **except** git, then run
the probe against it. This is the same mechanism the suite uses.

Every block below derives the same directory name, so any one of them can be
run on its own. A block that only worked as a continuation of the block above
is the failure mode this guards against.

Note `$B` below: the interpreter is called by ABSOLUTE path, because stripping
`PATH` removes `bash` itself and `env PATH=… bash …` then fails with
`env: 'bash': No such file or directory` — a failure that looks like the probe
broke when nothing has run at all. The suite solves it the same way, and says
so at `pipeline/tests/preflight.bats`.

```bash
d="${TMPDIR:-/tmp}/preflight-nogit"; rm -rf "$d"; mkdir -p "$d"
B="$(command -v bash)"
for t in awk grep head jq od; do
  src="$(command -v "$t")" || continue
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$src" > "$d/$t"
  chmod +x "$d/$t"
done
env PATH="$d" "$B" pipeline/scripts/preflight.sh --base-branch main | jq '.capabilities, .willSkip, .tree'
```

Expected, and all three parts matter:

- `capabilities.git` is `false`.
- `willSkip` holds exactly two entries, for phases `L` and `M`. Neither is
  about git — they are the existing no-remote entries, which fire because the
  remote cannot be read without git.
- The document still parses, and the command still exits `0`. Reporting is not
  failing.

Check the exit status explicitly, because a pipe would hide it:

```bash
d="${TMPDIR:-/tmp}/preflight-nogit"; B="$(command -v bash)"
# Rebuild the shim directory rather than assuming the block above left one.
# Re-deriving only the NAME is not enough: this block depends on the directory
# and its shims existing, and without them the probe dies at "jq is required"
# and the reader sees a failure that looks like the probe broke.
rm -rf "$d"; mkdir -p "$d"
for t in awk grep head jq od; do
  src="$(command -v "$t")" || continue
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$src" > "$d/$t"
  chmod +x "$d/$t"
done
env PATH="$d" "$B" pipeline/scripts/preflight.sh --base-branch main > "$d/out.json"
echo "exit: $?"
jq -e . < "$d/out.json" > /dev/null && echo "stdout is well-formed JSON"
```

## 3. Prove stdout stayed pure

A single stray line on stdout breaks every consumer. This asserts the whole of
stdout is one JSON document and nothing else.

```bash
p="$(mktemp -d)"
bash pipeline/scripts/preflight.sh > "$p/pure.json" 2> "$p/pure.err"
jq -e 'type == "object"' < "$p/pure.json" > /dev/null && echo "pure JSON on stdout"
echo "stderr bytes: $(wc -c < "$p/pure.err")"
rm -rf "$p"
```

## 4. Run the probe suite

```bash
bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/preflight.bats
```

Expected: every existing test passes **and was not edited**, plus the two new
ones.

## 5. Run the full house suite, from the repository root

This is the acceptance measurement. It takes longer than two minutes.

```bash
cd "$(git rev-parse --show-toplevel)"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests > /tmp/house.tap
echo "exit: $?"
head -1 /tmp/house.tap
grep -c '^ok ' /tmp/house.tap
grep -c '^not ok ' /tmp/house.tap
```

Expected: the plan line reports exactly two more tests than the run before this
change, `not ok` count `0`, and exit `0`.

Do **not** pipe the suite into `head` or `tail`. A pipe hands the block the
status of the last command in it, which is always `0`, and the plan line bats
prints first is the one a `tail` cuts. Redirect to a file, as above.

## 6. Read the orchestrator's new decision

Slice to the item's own terminator. A line count (`-A 12`) is a magic number
tuned to today's length: measured, it already cut the item mid-sentence, and
one more sentence would drop the `willSkip` clause this step tells you to look
for — while still exiting 0, so the check would pass having shown less than it
claims.

```bash
awk '/^The script only reports; the decisions are yours/,/^\*\*Base branch:\*\*/' \
  pipeline/skills/pipeline/SKILL.md \
  | awk '/^11\. /{f=1} /^\*\*Base branch:\*\*/{f=0} f' \
  | tee /dev/stderr \
  | grep -q 'git-scm.com/downloads' && echo "OK: the link is inside item 11"
```

Expected: the whole of decision item 11 is printed — no sentence cut — and it
says it fires before every other decision, names
`https://git-scm.com/downloads`, and says git is never a `willSkip` entry.

Check the read-me-first pointer is there too, since it is what a top-down
reader meets before item 1:

```bash
grep -n 'Read item 11 before item 1' pipeline/skills/pipeline/SKILL.md
```

## 7. Prove the pins are intact

```bash
bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/prose.bats
```

Expected: green — but read what that does and does not prove.

This suite slices the probe block and the decision walk and greps pinned
sentences inside each. Green means **the sentences it already pins** are
unchanged, which is what protects this feature: it proves the lines added here
did not disturb the `Implementer` template line or decision item 10.

It does **not** guard the lines this feature added. Nothing in the suite
mentions git, the `git` probe-block line, or decision item 11 — delete either
and this suite still passes. That gap is deliberate rather than overlooked: the
acceptance criterion for this change fixes the suite at exactly two new tests,
and a pin would be a third. It is recorded in the specification and named in
the pull request as follow-up work. Do not read step 7's green as coverage of
decision 11.

## Cleanup

```bash
rm -rf "${TMPDIR:-/tmp}/preflight-nogit"
```
