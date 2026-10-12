#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Pins over the pipeline's three sibling skills: pipeline:status,
# pipeline:spec-review and pipeline:device-verify. prose.bats pins the
# orchestrator and only the names of these three (plus a few status
# sentences); the rules below are the ones that change what a session does
# if they are inverted or dropped. Each pin was mutation-verified when it
# landed (invert the rule -> red).
#
# The files are read flattened, as prose.bats reads them: CR stripped,
# lines joined, spaces squeezed, so an innocent rewrap stays green. Matching
# is `[[ == ]]` only: a herestring hangs in Git Bash near 64 KB, and a grep
# fed by `< <(printf ...)` was measured matching text that was not there.

load ../../tests/helper

setup() {
  STATUS="$ROOT/pipeline/skills/status/SKILL.md"
  REVIEW="$ROOT/pipeline/skills/spec-review/SKILL.md"
  DEVICE="$ROOT/pipeline/skills/device-verify/SKILL.md"
  ORCH="$ROOT/pipeline/skills/pipeline/SKILL.md"
  PROG="$ROOT/pipeline/scripts/progress.sh"
}

# flat <file>: the whole file, flattened, with no trailing space.
flat() {
  local f="$1" s
  [ -f "$f" ] || { echo "flat: no file at $f" >&2; return 1; }
  s="$(tr -d '\r' < "$f" | tr '\n' ' ' | tr -s ' ')"
  printf '%s' "${s% }"
}

# span <file> <open-ere> <close-ere>: the lines from the first one matching
# <open> up to, not including, the next one matching <close>, flattened.
# Both boundaries must match: a span whose close is gone would run to the
# end of the file and pass a pin it should not.
span() {
  local f="$1" open="$2" close="$3" s
  [ -f "$f" ] || { echo "span: no file at $f" >&2; return 1; }
  s="$(tr -d '\r' < "$f" | awk -v o="$open" -v c="$close" '
    on && $0 ~ c { closed = 1; exit }
    !on && $0 ~ o { on = 1 }
    on { print }
    END { if (!closed) exit 3 }')" || { echo "span: '$open' .. '$close' did not both match in $f" >&2; return 1; }
  s="$(printf '%s\n' "$s" | tr '\n' ' ' | tr -s ' ')"
  s="${s% }"
  [ -n "$s" ] || { echo "span: '$open' .. '$close' is empty in $f" >&2; return 1; }
  printf '%s' "$s"
}

# pins_in <haystack> <label>: every non-empty line on stdin occurs in it.
pins_in() {
  local hay="$1" what="$2" pin n=0
  [ -n "$hay" ] || { echo "$what: the haystack is empty"; return 1; }
  while IFS= read -r pin; do
    [ -n "$pin" ] || continue
    [[ $pin == *[![:space:]]* ]] || { echo "$what: a pin holds only whitespace"; return 1; }
    n=$((n + 1))
    [[ $hay == *"$pin"* ]] || { echo "$what pin missing: $pin"; return 1; }
  done
  [ "$n" -gt 0 ] || { echo "$what: no pins were read"; return 1; }
}

# absent_in <haystack> <label>: no non-empty line on stdin occurs in it.
absent_in() {
  local hay="$1" what="$2" old n=0
  [ -n "$hay" ] || { echo "$what: the haystack is empty"; return 1; }
  while IFS= read -r old; do
    [ -n "$old" ] || continue
    n=$((n + 1))
    [[ $hay != *"$old"* ]] || { echo "$what still holds: $old"; return 1; }
  done
  [ "$n" -gt 0 ] || { echo "$what: no lines were read"; return 1; }
}

# exactly <got> <label>: <got> equals the flattened text on stdin, whole. An
# appended sentence that repeals a rule cannot pass beside an intact pin.
exactly() {
  local got="$1" what="$2" want
  want="$(tr -d '\r' | tr '\n' ' ' | tr -s ' ')"
  want="${want% }"
  [ -n "$want" ] || { echo "$what: nothing to compare against"; return 1; }
  [ "$got" = "$want" ] || { printf '%s changed:\n%s\n' "$what" "$got"; return 1; }
}

# --- pipeline:status --------------------------------------------------------

@test "the status skill renders the board from progress.sh board, never its own phase list" {
  local s
  s="$(span "$STATUS" '^3[.] ' '^4[.] ')" || return 1
  exactly "$s" 'status step 3' <<'TEXT'
3. Render the phase board from the script, never from a phase list of your
   own: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/progress.sh" board <feature>`
   prints one JSON object. Its `board` holds every phase in order, each
   `done`, `current` or `pending`, and `current` is the phase a resume
   re-enters. Render those rows as they are.
   Then report who holds the repository lock, from the same object's
   `lock`. A `lock` of null means no run holds the repository: say so.
   Otherwise name the holder's `feature`, `session` and `taken_at`, quoted
   as data like every string in step 4, and say whether it is this run
   (`this_run`). A `stale` lock, whose holder has no state file or whose
   run is DONE or abandoned (`holder_run`), is taken over by the next
   run's `lock-take`: say so. A `lock` whose `readable` is false could not
   be read: say so, and never guess its holder.
TEXT
  # The second copy of the phase list is gone, in any spelling: a dotted
  # phase name appears nowhere in the skill.
  absent_in "$(flat "$STATUS")" 'the status skill' <<'OLD'
C.5
F.5
H.5
H.7
N.5
OLD
}

@test "the status skill stays read-only and takes no lock" {
  pins_in "$(flat "$STATUS")" 'status skill' <<'PINS'
Read-only. This skill never edits the working tree, never takes the lock and never advances a phase — it reports.
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/progress.sh" read <feature>`. A validation error is the answer, not an obstacle: report the named fault it prints.
PINS
}

# The skill names fields of board's output; each must be one board prints,
# or a state its rows take. The names are read from the skill's step 3, not
# listed here, so a field renamed on either side goes red.
@test "every field the status skill reads from board is one board prints" {
  local s names n=0 k
  s="$(span "$STATUS" '^3[.] ' '^4[.] ')" || return 1
  cd "$BATS_TEST_TMPDIR"
  printf '%s\n' "$s" > step3.txt
  names="$(grep -o '`[a-z_]*`' step3.txt | tr -d '`' | sort -u)"
  bash "$PROG" init 001-demo b main web > /dev/null
  bash "$PROG" phase-done 001-demo preflight
  bash "$PROG" phase-start 001-demo A
  bash "$PROG" lock-take 001-demo session-one
  bash "$PROG" board 001-demo > board.json
  for k in $names; do
    n=$((n + 1))
    jq -e --arg k "$k" 'has($k) or (.lock | has($k)) or any(.board[]; .state == $k)' board.json > /dev/null \
      || { echo "the status skill names \`$k\`, which board does not print"; false; }
  done
  [ "$n" -ge 10 ] || { echo "only $n field names were read from step 3: $names"; false; }
}

# --- pipeline:spec-review ---------------------------------------------------

@test "spec-review's three lenses are independent agents dispatched in one message" {
  local s
  s="$(span "$REVIEW" '^Run all three' '^1[.] ')" || return 1
  exactly "$s" 'the three lenses paragraph' <<'TEXT'
Run all three as independent reviewers: three agents, one per lens,
dispatched together in one message, each given the same inputs and none
shown another's findings. That is what the pipeline's "three reviewers
in one message" means: together in time, independent in judgement.
Where agents cannot be dispatched, run the lenses one at a time, each
written down in full before the next begins, and never revise an
earlier lens's findings. Either way, findings from one lens never
soften another's, and no lens is skipped because another found nothing:
TEXT
  # The phrase it settles is the orchestrator's own, in phase I and in the
  # parallel-agents units: if either is reworded, this sentence quotes a
  # phrase that no longer exists.
  pins_in "$(flat "$ORCH")" 'the orchestrator' <<'PINS'
Three reviewers in one message — contract compliance, security, tests — per that skill's contract.
I — the three reviewers in one message;
PINS
}

@test "spec-review's lenses keep their operative rules" {
  pins_in "$(flat "$REVIEW")" 'spec-review' <<'PINS'
Read-only. This skill reviews; it never edits the working tree, and it never fixes what it finds — findings go to the caller.
Ask for what is missing rather than guessing
1. **Contract compliance.** Walk the specification requirement by requirement. For each: point at the code that implements it (file:line), or record it as MISSING.
Then walk the diff the other way: anything implemented that no requirement asks for is EXTRA. Wrong-shape implementations (the right feature built the wrong way) are MISUNDERSTOOD.
2. **Security.** Inputs that reach a shell, a query, a path, or a network call without validation; secrets in code or logs; permissions widened; injection surfaces opened by the change.
3. **Tests.** Do the new tests verify behaviour, not mocks? Does every new requirement have a covering test? Would each test fail if its feature were broken (name the mutation that proves it)?
PINS
}

@test "spec-review's findings are one parseable line each, with the pipeline's severities" {
  local s
  s="$(span "$REVIEW" '^## Output$' '^End with a verdict')" || return 1
  exactly "$s" 'the Output section' <<'TEXT'
## Output

One report, in a form the caller can parse. Every finding is one line,
its four fields in this order, separated by ` | `:

`SEVERITY | lens | file:line | finding`

- SEVERITY is one of CRITICAL, HIGH, MEDIUM or LOW, in capitals: the
  words the pipeline counts its findings by.
- lens is `contract`, `security` or `tests`, the lens that found it.
- file:line is where the fault is. A MISSING requirement has no code to
  point at: give the specification's file and the requirement's line.
- finding is the rest of the line: what is wrong, why it matters, and
  how to fix it if not obvious. A contract finding starts with MISSING,
  EXTRA or MISUNDERSTOOD.

The severities:

- **CRITICAL** — broken functionality, data loss, a security hole.
- **HIGH** — a missed or misunderstood requirement, a test that asserts
  nothing.
- **MEDIUM** — a fault that does not break the feature today: an
  unvalidated edge, a test that misses a branch, a harmless EXTRA.
- **LOW** — polish; note and move on.

Order the lines by severity, CRITICAL first. After them, one count line,
every severity named even at zero:
`Findings: CRITICAL <n>, HIGH <n>, MEDIUM <n>, LOW <n>`.
TEXT
  # The old three-level scale is gone: no phase counts by it.
  absent_in "$(flat "$REVIEW")" 'spec-review' <<'OLD'
**Critical**
**Important**
**Minor**
OLD
}

@test "spec-review ends with a verdict and never an unwalked looks-good" {
  local f
  f="$(flat "$REVIEW")"
  pins_in "$f" 'spec-review' <<'PINS'
End with a verdict: COMPLIANT, or the list of requirements that are not. Never say "looks good" without the requirement-by-requirement walk — an audit that skipped the walk is an opinion, not an audit.
PINS
  # The verdict is the report's last word.
  [[ $f == *"an opinion, not an audit." ]] || { echo "text follows the verdict rule"; false; }
}

# --- pipeline:device-verify -------------------------------------------------

@test "device-verify stops on a missing adb, no device or more than one" {
  local s
  s="$(span "$DEVICE" '^## Preconditions' '^## The pass$')" || return 1
  exactly "$s" 'the preconditions' <<'TEXT'
## Preconditions — check, and stop loudly on failure

1. `adb` on PATH. Without it, report the missing tool and stop — the
   caller decides what a skipped verification means.
2. Exactly one device attached: `adb devices` lists one device in state
   `device`. Zero devices: say so and stop. More than one: say so and
   stop — guessing which device the human means is how a wrong phone
   gets a debug build.
3. A mobile project at the working directory (the pipeline's detector
   calls this `mobile-android`). If the project's own build tooling is
   not obvious from its manifest, ask rather than guessing a build
   command.
TEXT
}

@test "device-verify builds release, installs, screenshots and reads every screenshot back" {
  pins_in "$(flat "$DEVICE")" 'device-verify' <<'PINS'
Verifies by looking, not by compiling. The build succeeding is not the claim; the screen showing the feature is.
1. **Build a release build** with the project's own build command — never a debug build; debug builds hide release-only failures. Show the command before running it.
2. **Install** the artefact: `adb install -r <artefact>`. A failed install is a finding, not an obstacle — report it verbatim.
3. **Navigate** to every screen the change touches.
where the mapping is unclear, say so and verify the entry screen plus whatever the change's description names.
4. **Screenshot** each screen: `adb exec-out screencap -p > <name>.png`, saved under the run's artefact directory.
5. **Read every screenshot back** and describe what it actually shows. The description is the verification: a screenshot nobody read is a file, not evidence.
PINS
}

@test "device-verify never reports verification that did not happen" {
  local s
  # The last section: read to the end of the file, so a rule appended after
  # it is part of the comparison.
  s="$(tr -d '\r' < "$DEVICE" | awk '/^## Honesty rules$/ { on = 1 } on' | tr '\n' ' ' | tr -s ' ')"
  s="${s% }"
  exactly "$s" 'the honesty rules' <<'TEXT'
## Honesty rules

- Never report verification that did not happen. A screen you could not
  reach is reported as unreached, with the reason.
- Never call a build "working" from the build log alone.
- If the device disconnects mid-pass, report which screens were
  verified before the disconnect and which were not.
TEXT
}
