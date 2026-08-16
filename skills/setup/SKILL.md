---
name: setup
description: Use when the context guard reports a misconfigured window, when the user says "set up delivery-kit", "configure the context guard", or asks where the guard should stop — measures the session's real context, proposes a window, and writes the answers to the user-level config.
---

# Setup — tell the guard your real context window and stopping point

The guard is a hook. A hook reads its input, prints an answer and exits; it has
no way to ask a person anything. Two facts only the user has therefore have to
arrive some other way, and this skill is that way.

Ask about both together. They are only coherent together: a stopping point in
tokens set against a wrong window produces a guard that fires at a percentage
the user never chose, and the reverse.

## 1. Measure, before asking

Claude is not given the session transcript path — that goes to the hook. So find
it, and find the right one: transcripts live under `~/.claude/projects/`, one
directory per project, and with two sessions open the newest file on the machine
belongs to whichever of them last did something. That may not be this one, and a
window measured from another session's context is not the thing the user asked
about.

Claude Code names each of those directories after the project's absolute path
with **every character that is not a letter or a digit replaced by a hyphen** —
path separators and the Windows drive colon, but equally the dots and
underscores inside the path, each character yielding its own hyphen. A rule that
flattens only the separators derives the wrong name whenever the path contains
anything else — a directory nested under a dotted one, or an account name
carrying an underscore, is enough on its own. Derive the name from the current
working directory by that rule rather than searching the whole tree, and take the
newest `.jsonl` inside that one directory.

Getting it wrong degrades quietly rather than loudly: the derived directory
simply does not exist, so it looks exactly like a session with no transcript and
the skill proceeds to ask without a proposal. That is safe, and it is still the
wrong answer — so confirm the directory exists before concluding there is
nothing to measure.

Compute observed context the same way the guard does, so this number is derived
by the guard's own rule rather than by a second method that could drift from it:

```bash
tail -n 5000 "$TRANSCRIPT" \
  | jq -Rr 'fromjson?
  | select(.isSidechain != true)
  | select(.message.usage.input_tokens != null)
  | .message.usage
  | (.input_tokens + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))' \
  | jq -rs '.[-15:] | sort | .[(length/2|floor)] // 0'
```

The `tail` is the hook's line budget, taken from `hooks/context-guard.sh` so this
reading is bounded the way the guard's is. Treat it as headroom rather than a
guarantee: the budget counts LINES while the median needs fifteen READINGS, and
tool results and sidechain lines consume it without yielding one. 5000 leaves
room for several subagent fan-outs between readings — at 300 the boundary was
reachable and clipped every honest reading. Reading the whole file instead buys
very little and costs a full pass over a transcript that can run to tens of
megabytes.

Expect the two numbers to agree, but do not promise it — the guard reads at the
moment it fires and this reads at the moment you ask, and the transcript grows
in between.

**Say which file you read.** One line naming the transcript is what makes a
wrong pick visible instead of silently shaping the proposal.

**State the limit rather than hiding it.** This reading is a LOWER BOUND on the
real window, and only a useful one once a session has accumulated context. In a
fresh session there is little to propose. Say so plainly and ask without a
proposal — a weak bound presented as a strong one is worse than no proposal.

If no transcript is found, say that, and ask without a proposal.

## 2. Propose, do not interrogate

Report the observed number plainly, then offer a window as a default rather
than asking a bare question. Common real values are 200,000 and 1,000,000; the
observed reading rules out anything below itself.

**The two ways of being wrong are not symmetric, so say so while the choice is
open.** A window set too small fires the guard early and names the window it
measured against, and once observed context passes that window the guard reports
it as provably wrong — loud, and self-diagnosing. A window set too large never
fires at all: with `thresholdTokens` unset, which is the default, no reading the
guard can take reveals the mistake, and the first sign of it is a session dying
mid-task. So when the user is unsure between two values, take the smaller one.
Guessing high is the one answer here that fails silently.

Then ask for the stopping point, and accept **either** form:

- a percentage of the window — `thresholdPct`, default 45
- an absolute token count — `thresholdTokens`, unset by default

Both may be set. They are independent tripwires and the guard fires on either,
which is deliberate: it takes two wrong values to silence it instead of one.
Setting `thresholdTokens` is also what removes the silence described above — it
is decided from the transcript alone, so it still fires when the window is too
large.

**Declining is a valid answer.** A question the user does not want to answer
writes nothing for that key, and the default stands: `windowTokens` 200,000,
`thresholdPct` 45, `thresholdTokens` unset. Say that rather than pressing for a
number the user does not have.

## 3. Write `~/.delivery-kit.json` — merged, never overwritten

The file is the user-level one. Do not ask which file to write; a user who
wants repository-scoped values edits that repository's `.delivery-kit.json`,
which still overrides this one.

That file may already hold `handoff.docsDir`, `contextGuard.maxBytes`, or keys
a later version added that this skill knows nothing about. Writing a fresh
object would silently delete them. Read, merge, write back:

```bash
CFG="$HOME/.delivery-kit.json"
[ -f "$CFG" ] || printf '{}\n' > "$CFG"
# Build the answers as $PATCH, e.g.
# {"contextGuard":{"windowTokens":1000000,"thresholdTokens":400000}}
printf '%s\n' "$PATCH" > "$CFG.patch"
jq -s '.[0] * .[1]' "$CFG" "$CFG.patch" > "$CFG.new" && mv "$CFG.new" "$CFG"
rc=$?
rm -f "$CFG.patch" "$CFG.new"
[ "$rc" -eq 0 ] || echo "merge failed; $CFG is unchanged"
```

`*` is jq's recursive merge: sibling keys under `contextGuard` survive, and so
does everything outside it.

The `&&` is what makes a failed merge harmless: `$CFG` is replaced only once the
merged document exists whole, so a `~/.delivery-kit.json` that will not parse
costs the user nothing. Both temporaries are removed on either path — without
that second name in the `rm`, a failed merge leaves a partial `$CFG.new` sitting
in the user's home directory. Carry `$rc` forward; it is the only thing that
distinguishes a write from a no-op.

## 4. Print what was written

If `$rc` was 0, show the resulting file. A user who has just answered two
questions about numbers should be able to see the numbers.

If it was not, say the merge failed and that the file is unchanged. Printing it
anyway shows the OLD contents under a heading claiming they were just written,
which is worse than the failure it hides.

## 5. Say so if the repository is overriding what was just written

The repository file beats the user-level one. So a project carrying a
`.delivery-kit.json` of its own, holding any of the keys just written, is
unaffected by everything above — and the case that matters most is the one the
guard sends here: when a `WINDOW MISCONFIGURED` note names a window that came
from the repository file, correcting the user-level file changes nothing and the
identical note fires again on the next session. Printing the right numbers while
the guard goes on using the wrong ones is the worst available outcome, so check
before claiming success.

Resolve the repository file the way the guard does — the current working
directory first, then the repository root, since Claude Code's working directory
can sit below it:

```bash
REPO_CFG="./.delivery-kit.json"
[ -f "$REPO_CFG" ] || REPO_CFG="$(git rev-parse --show-toplevel 2>/dev/null)/.delivery-kit.json"
[ -f "$REPO_CFG" ] && jq -r '.contextGuard // {} | keys[]' "$REPO_CFG" 2>/dev/null
```

If that lists any key just written, say plainly that the repository file
overrides `~/.delivery-kit.json`, name the file, and give the value it is
imposing. Then leave the choice with the user, who is the only one who knows
which was meant: remove the key from the repository file so the machine-level
answer applies, or keep it and change it there instead. **Do not edit the
repository file unasked** — it is normally committed and shared with everyone
else working on the project, which is exactly why it wins.

If it lists nothing, or there is no repository file, say nothing. There is no
conflict to report.

Then stop. This skill configures; it does not go on to do other work.
