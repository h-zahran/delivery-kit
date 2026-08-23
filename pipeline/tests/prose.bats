#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Grep gates over the pipeline's prose surfaces. Regression guards, not
# proofs: a newly worded instruction to skip findings would pass them.
# Each assertion was mutation-verified when it landed (edit the promise
# away -> red).

load ../../tests/helper

setup() {
  ORCH="$ROOT/pipeline/skills/pipeline/SKILL.md"
  CMD="$ROOT/pipeline/commands/pipeline.md"
}

@test "the front door disables model invocation" {
  grep -qE '^disable-model-invocation: true$' "$CMD"
}

@test "the five gates are named with their phases" {
  for pair in "Clarify | C" "Implementer | G" "Commit | K" "Push and pull request | L" "Release | O"; do
    grep -qF "| $pair |" "$ORCH" || { echo "gate row missing: $pair"; false; }
  done
}

@test "every never-bend rule is present verbatim" {
  while IFS= read -r rule; do
    [ -n "$rule" ] || continue
    grep -qF "$rule" "$ORCH" || { echo "never-bend row missing: $rule"; false; }
  done <<'RULES'
git push --force
`git reset --hard`, `git clean`, `git checkout --` on tracked files
Delete a branch
`--no-verify`, or skipping a hook
`git add -A`, or staging by wildcard
Merge a pull request
Push before the L gate is answered
Amend or rewrite a commit that has been pushed
Continue past a hard failure
RULES
}

@test "the fix-everything red-flag table is present" {
  grep -qF '"Fix everything" is implied, I can skip the small ones' "$ORCH"
  grep -qF 'Every finding is fixed, or explicitly deferred with its reason recorded' "$ORCH"
}

@test "the invocation form is never dot-only" {
  grep -qF 'Never write the dot form as the only spelling' "$ORCH"
  grep -qF 'hyphen-skills' "$ORCH"
}

@test "auto never collapses the release gate" {
  # Pinned against the FLATTENED file, not the raw one: a round-4 mutation
  # showed the raw form goes red on an innocent rewrap, and green on a
  # subject swap ("Only a set `implementer` is still required before
  # anything publishes unasked") — red for the wrong reason, green for the
  # dangerous one. The table row stays raw because a row is one line.
  local flat
  flat="$(tr '\n' ' ' < "$ORCH" | tr -s ' ')"
  grep -qF '`--auto` never collapses O. Publishing is the least reversible thing' <<<"$flat" \
    || { echo 'the auto-never-collapses-O sentence altered'; false; }
  grep -qF '`--auto-release` is still required before anything publishes unasked.' <<<"$flat" \
    || { echo 'the auto-release assurance altered — check its SUBJECT, not just its tail'; false; }
  grep -qF '| `--auto` | Collapse the K and L gates to automatic. It collapses neither C, G nor O: C and O stop when they have something to ask, and G stops unless `implementer` pre-answered it. |' "$ORCH" \
    || { echo 'the --auto flags row altered'; false; }
}

@test "the runtime check never claims verification it did not do" {
  grep -qF 'It never reports verification it did not do' "$ORCH"
}

@test "the helpers are named by plugin namespace" {
  for n in 'pipeline:status' 'pipeline:spec-review' 'pipeline:device-verify'; do
    grep -qF "$n" "$ORCH" || { echo "namespaced helper missing: $n"; false; }
  done
}

@test "the handoff package names its seven parts" {
  g="$(awk '/^\*\*G — implementer gate\.\*\*/,/^\*\*H — implement\.\*\*/' "$ORCH")"
  head -n 1 <<<"$g" | grep -qF '**G — implementer gate.**' \
    || { echo "G slice did not open on the G heading"; false; }
  tail -n 1 <<<"$g" | grep -qF '**H — implement.**' \
    || { echo "G slice unterminated: H heading missing or reworded"; false; }
  extra="$(grep -E '^\*\*|^#{1,6} ' <<<"$g" | grep -vF -e '**G — implementer gate.**' -e '**H — implement.**' || true)"
  [ -z "$extra" ] || { echo "unexpected heading-shaped lines inside the G slice:"; echo "$extra"; false; }
  while IFS= read -r part; do
    [ -n "$part" ] || continue
    grep -qF -- "- **$part**" <<<"$g" || { echo "package part missing: $part"; false; }
  done <<'PARTS'
Files to provide
Repository state
Instructions
Forbidden list
What will bite this feature
Validation before "done"
Report-back contract
PARTS
  flat="$(tr '\n' ' ' <<<"$g" | tr -s ' ')"
  grep -qF 'forbidden list is DERIVED, not hardcoded: the fixed rules (no commit, no push, no branch operations, no pull request) plus whatever `releaseCommand` and `verifyCommand` name, plus any deploy or migration verb found in the tasks file.' <<<"$flat" \
    || { echo "derived-forbidden-list sentence altered"; false; }
  grep -qF '`--auto` never collapses this gate: it spends money.' <<<"$flat" \
    || { echo "the G auto sentence altered"; false; }
  grep -qF 'answer later changes, delete the written package file (or stamp it VOID at the top) before proceeding — a stale package addressed to another model is an instruction nobody should find.' <<<"$flat" \
    || { echo "the VOID sentence altered"; false; }
  grep -qF 'A "handoff" answer parks the run at H:' <<<"$flat" \
    || { echo "the park sentence missing"; false; }
}

@test "the implementer key's consent surface is pinned outside the G slice" {
  # Phase M round 4. These sites live in pre-flight, the configuration
  # section, the docs page and the changelog; nothing sliced any of them, and
  # round-2 mutants proved every one could be deleted while the suite stayed
  # green. Round 4 then proved the first version of THIS test could be beaten
  # by relocation — item 10 pasted verbatim into an appendix headed "not
  # instructions" passed — so the pre-flight pins are sliced, not file-wide.
  local docs="$ROOT/pipeline/docs/configuration.md"
  local changelog="$ROOT/pipeline/CHANGELOG.md"
  local flat walk probe
  flat="$(tr '\n' ' ' < "$ORCH" | tr -s ' ')"
  # The decision walk only — so a rule cannot satisfy the pin from a footnote.
  walk="$(awk '/^The script only reports; the decisions are yours/,/^\*\*Base branch:\*\*/' "$ORCH" | tr '\n' ' ' | tr -s ' ')"
  probe="$(awk '/^Project type : /,/^Will skip /' "$ORCH")"

  # Item 10, pinned through the operative action. The carve-out alone was
  # cuttable: a mutant kept "unset is not a value and never stops anything"
  # and replaced the action with "coerce the value to `claude` and continue
  # silently".
  grep -qF 'unset is not a value and never stops anything): stop and name the value — never coerced, never treated as unset.' <<<"$walk" \
    || { echo 'pre-flight item 10 altered — check the ACTION, not just the unset carve-out'; false; }

  # Resolution-time validation, pinned through the ordering guarantee. Without
  # the tail a mutant inverted it to "after the decision walk has completed and
  # both of its offered writes have landed" — the dirty-tree bug it prevents.
  grep -qF 'unset is not a value and never stops anything — stops the run HERE, before pre-flight'"'"'s decision walk begins' <<<"$flat" \
    || { echo 'the resolution-time enum check or its ordering guarantee altered'; false; }

  # The merge semantic, and the consequence for the keys that have no `ask`.
  grep -qF "A later layer's \`null\` is silence, not an override" <<<"$flat" \
    || { echo 'the null-merge semantic altered'; false; }
  grep -qF 'it is the only spelling that overrides toward the stop.' <<<"$flat" \
    || { echo 'the ask-is-the-only-override rule altered'; false; }
  grep -qF 'can be REPLACED by a later layer but never returned to unset' <<<"$flat" \
    || { echo 'the command-keys consequence altered'; false; }

  # The disclosure line. Pinned WITH its print rule: a mutant kept the template
  # and rewrote the rule to "Omit the line entirely — the operator does not
  # need it", deleting the design's whole safety argument, and stayed green.
  grep -qF 'Implementer  : <claude|handoff|ask>  (from <implementerSource>)' <<<"$probe" \
    || { echo 'the pre-flight Implementer probe line altered or left its block'; false; }
  grep -qF 'Print it whenever the key resolves to a value; omit the line entirely when the key is unset.' <<<"$flat" \
    || { echo 'the probe line print rule altered'; false; }
  grep -qF '`<implementerSource>` must name the LAYER that won' <<<"$flat" \
    || { echo 'the implementerSource layer rule altered'; false; }
  grep -qF 'a tracked configuration file must never do that without the operator seeing which file it came from.' <<<"$flat" \
    || { echo 'the disclosure rationale altered'; false; }

  # Both STRICT surfaces, by whole sentence. Heading-and-fragment coverage let
  # a mutant rewrite the docs body to "`implementer` pre-answers every gate …
  # an illegal value is coerced to `claude`" while every pin held.
  local dflat cflat
  dflat="$(tr '\n' ' ' < "$docs" | tr -s ' ')"
  cflat="$(tr '\n' ' ' < "$changelog" | tr -s ' ')"
  grep -qxF '## The implementer key' "$docs" \
    || { echo 'the configuration page lost its implementer section heading'; false; }
  grep -qF '| `implementer` | Pre-answers the implementer gate: `claude` or `handoff`; `ask` restores the stop; unset means ask. |' "$docs" \
    || { echo 'the docs key-table row altered'; false; }
  grep -qF 'With `ask` the gate simply asks, as it does when the key is unset' <<<"$dflat" \
    || { echo 'the docs ask sentence altered'; false; }
  grep -qF 'An illegal value stops pre-flight by name: never coerced, never treated as unset.' <<<"$dflat" \
    || { echo 'the docs illegal-value sentence altered'; false; }
  grep -qF 'Layers merge by silence, not by erasure' <<<"$dflat" \
    || { echo 'the docs null-merge sentence altered'; false; }
  grep -qF '`--implementer <claude|handoff|ask>`' "$changelog" \
    || { echo 'the changelog entry lost the value set'; false; }
  grep -qF 'an illegal value stops pre-flight by name — never coerced, never treated as unset.' <<<"$cflat" \
    || { echo 'the changelog illegal-value clause altered'; false; }
  grep -qF 'Pre-flight prints an `Implementer` line naming the resolved value and the layer it came from' <<<"$cflat" \
    || { echo 'the changelog disclosure clause altered'; false; }

  # The FIRST json block only. Reading every fence let a later illustrative
  # block mask a canonical one that had lost the key entirely.
  awk '/^```json$/{if(!seen){f=1;seen=1;next}} /^```$/{f=0} f' "$docs" \
    | jq -e 'has("pipeline") and (.pipeline | has("implementer")) and .pipeline.implementer == null' > /dev/null \
    || { echo 'the FIRST configuration JSON block no longer parses with implementer null'; false; }
}

@test "the G pre-answer contract is pinned sentence by sentence" {
  # Split out of the package-parts test at phase M round 4: hosting the
  # consent contract inside a test named for the handoff package hid it from
  # anyone auditing consent coverage, and paying for that in name accuracy to
  # keep a count frozen was the wrong trade. Whole sentences, against the
  # flattened G slice — fragment pins leave the words between them mutable,
  # and round-4 mutants proved every short pin here could be cut.
  local g flat
  g="$(awk '/^\*\*G — implementer gate\.\*\*/,/^\*\*H — implement\.\*\*/' "$ORCH")"
  flat="$(tr '\n' ' ' <<<"$g" | tr -s ' ')"

  grep -qF '**G — implementer gate.** STOP AND ASK, unless `implementer` pre-answered it: implement with Claude here, or produce a handoff package for a cheaper model.' <<<"$flat" \
    || { echo "the G lead's pre-answer qualifier altered"; false; }
  grep -qF 'When `implementer` resolves to `claude` or `handoff` (config or flag), G records that answer in `gates` and does not stop — the choice was typed on purpose.' <<<"$flat" \
    || { echo "the G pre-answer sentence altered"; false; }
  grep -qF '`ask` pre-answers nothing: G stops, asks, and records the owner'"'"'s answer in `gates` like any asked gate.' <<<"$flat" \
    || { echo "the ask re-arm sentence altered"; false; }
  grep -qF 'It is how a command line takes back a stop a configuration file gave away.' <<<"$flat" \
    || { echo "the ask rationale sentence altered"; false; }
  grep -qF 'a pre-answered `implementer` silences nothing else: cap breaches, hard failures and every other gate still stop exactly as before.' <<<"$flat" \
    || { echo "the silences-nothing-else sentence altered"; false; }
  # Pinned through the OPERATIVE clause, not just the carve-out: a mutant
  # rewrote the tail to "is coerced to `claude` and the run continues without
  # saying so" while the carve-out survived, and the suite stayed green.
  grep -qF 'An illegal `implementer` value — one that is none of `claude`, `handoff` or `ask`, unset being no value at all — stops pre-flight by name, never coerced and never treated as unset.' <<<"$flat" \
    || { echo "the G illegal-value sentence altered"; false; }
  grep -qF 'Record the answer under `gates.G`, and treat that entry as its only authoritative record — the re-ask suppression every gate relies on reads `gates`.' <<<"$flat" \
    || { echo "the gates.G authority sentence altered"; false; }
  grep -qF 'The state file also carries a top-level `implementer` field, created empty by `init` and read by nothing: write nothing there.' <<<"$flat" \
    || { echo "the write-nothing-there instruction altered"; false; }
  # The re-entry precedence rule. Round 4 flipped it: the record outranks the
  # config key, a typed flag outranks the record. Both halves are pinned,
  # because a mutant that keeps one and inverts the other reads as coherent.
  grep -qF 'takes the recorded answer over the CONFIGURATION KEY: an inherited file never quietly flips an answer the run already holds.' <<<"$flat" \
    || { echo "the record-over-config rule altered"; false; }
  grep -qF 'A `--implementer` typed on that command line is different, and it WINS: typing it is a present-tense act by the person at the keyboard, and it is the only way `ask` can do the job it exists for.' <<<"$flat" \
    || { echo "the flag-wins-on-re-entry rule altered"; false; }
  grep -qF 'A flag that disagrees with the record is never applied silently — say which answer now stands and which it replaced.' <<<"$flat" \
    || { echo "the never-silently rule altered"; false; }
}
