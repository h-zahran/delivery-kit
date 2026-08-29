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

  # T028, corrected 2026-08-25: the shipped 1.1.0 notes said an `--auto` run
  # "touches the human at clarify only", which a cap breach falsifies — and
  # this release publishes a fourth cap, `maxVerifyIters`, which is what made
  # it material. The claim is now scoped to GATES and carries the caveat.
  # Both are pinned, and pinned TOGETHER: either alone leaves a mutant free to
  # restore the unscoped wording beside a caveat that is true on its own.
  grep -qF 'an `--auto` run then stops at no gate but clarify' <<<"$cflat" \
    || { echo 'the changelog --auto claim altered — it must stay scoped to GATES'; false; }
  grep -qF 'Cap breaches, a missing required tool, hard failures and a failed runtime check still stop it, but the gates do not' <<<"$cflat" \
    || { echo 'the changelog cap-breach caveat altered'; false; }
  # The docs page carried the correct range all along and was the ONE unpinned
  # copy of it; the changelog was corrected against this sentence, so the two
  # shipped surfaces agree verbatim rather than approximately.
  grep -qF 'Cap breaches, a missing required tool, hard failures and a failed runtime check still stop it, but the gates do not.' <<<"$dflat" \
    || { echo 'the docs cap-breach caveat altered'; false; }

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

# ---------------------------------------------------------------------------
# Region-sliced pins for the orchestrator's safety prose.        (feature 011)
#
# The ~31 pins above reproduce whole sentences, deliberately and with the
# reasoning recorded in-file. These five do not, and the difference is the
# point rather than a style drift: an anchor that is a CLAUSE survives a
# rewrap, so a red from one of these means someone changed what the sentence
# obliges, not where its line breaks fall. The whole-sentence pins cannot make
# that distinction, and a wall of them going red on a reflow is how a suite
# teaches people to stop reading its reds.
#
# Every one of them searches a SLICE, never the file. A rule that has been
# moved out of the section governing the behaviour is not in force however
# present it still is, and this suite has already watched that escape work:
# pre-flight item 10, pasted verbatim into an appendix headed "not
# instructions", passed a file-wide pin.

# prose_slice <open-ere> <close-ere> <raw|flat> <name>
#
# Prints the region of $ORCH between the two patterns. Diagnostics go to
# STDERR, which is not fastidiousness — every caller reads this function
# through $( ), so a message on stdout would be captured into the caller's
# variable and never seen.
#
# FIVE guards follow, and they are the contract (specs/011-.../contracts C2):
# the file is readable, the slice is non-empty, it opened on its boundary, it
# closed on its boundary, and it holds no unexpected heading. Counted here
# rather than described loosely, because the sentence after this one says one
# of them must never be removed as redundant — and a miscount is an invitation
# to decide which of the "extra" ones that was. (Arity and form are checked
# above, before any of this; they are about the CALL, not the slice.)
#
# The CLOSED-ON-ITS-BOUNDARY guard is the one that must never go. An awk
# range whose closing pattern stops matching runs to end of file in silence:
# the pin then searches the entire document while its name and its message
# both still claim a section. That is a green suite with the region check
# quietly repealed, caused by a heading rename nobody connected to this file.
# The mirror case is loud but misleading — an opening pattern that stops
# matching yields an empty slice, every anchor "missing", and a maintainer
# sent to look for a deletion that never happened. Hence a distinct message
# for each.
#
# Carriage returns are stripped. The document carries none today and
# .gitattributes pins *.md to LF, so this changes nothing now; it exists so a
# checkout that somehow did carry them fails over line endings NOWHERE rather
# than failing all five pins at once with a message about missing prose.
prose_slice() {
  local open="$1" close="$2" form="$3" name="$4"
  local s first last n inner

  # Arity and form are checked because getting either wrong fails with the
  # WRONG MESSAGE, which is the one outcome this helper's comments spend most
  # of their length trying to prevent. `falt` for `flat` returns the slice
  # unflattened; every clause anchor then spans a line break, every grep
  # misses, and five tests report "the clause was altered" about a document
  # nobody touched. It fails loudly and points at the wrong thing, which is
  # worse than failing quietly — a maintainer acts on it.
  [ "$#" -eq 4 ] || {
    printf 'prose_slice: needs <open> <close> <raw|flat> <name>, got %s argument(s)\n' "$#" >&2
    return 1
  }
  case "$form" in
    raw|flat) ;;
    *) printf 'prose_slice [%s]: form must be raw or flat, got: %s\n' "$name" "$form" >&2
       return 1 ;;
  esac

  # The orchestrator must be READABLE before its absence can be blamed on the
  # document's contents. awk writes "can't open file" to stderr and its status
  # is swallowed by the pipe below, so a renamed or moved SKILL.md yields an
  # empty slice and all five pins announce that their opening boundary matched
  # nothing — the true cause printed beside a guard message contradicting it.
  # That is the wrong-message class the arity and form guards were added for.
  [ -r "$ORCH" ] || {
    printf 'prose_slice [%s]: cannot read the orchestrator at %s — this is not a prose failure, the file is missing or unreadable\n' "$name" "$ORCH" >&2
    return 1
  }

  # Patterns reach awk through the ENVIRONMENT, not spliced into its program
  # text. Two reasons, both measured. Interpolation makes a pattern containing
  # a slash a SYNTAX ERROR — awk then prints nothing, and the empty-slice guard
  # below blames the document for a quoting bug in the caller. And `-v`, the
  # obvious alternative, processes backslash escapes in the value: it turns
  # `\.` into `.` and warns, silently loosening every pattern here. ENVIRON
  # does neither. Verified byte-identical to the interpolated form on all five
  # slices, with empty stderr.
  s="$(PS_OPEN="$open" PS_CLOSE="$close" \
       awk '$0 ~ ENVIRON["PS_OPEN"], $0 ~ ENVIRON["PS_CLOSE"]' "$ORCH" | tr -d '\r')"

  [ -n "$s" ] || {
    printf 'prose_slice [%s]: the slice is EMPTY — the opening boundary matched nothing: %s\n' "$name" "$open" >&2
    return 1
  }

  first="$(head -n 1 <<<"$s")"
  grep -qE "$open" <<<"$first" || {
    printf 'prose_slice [%s]: did not open on its boundary. Expected /%s/, got: %s\n' "$name" "$open" "$first" >&2
    return 1
  }

  last="$(tail -n 1 <<<"$s")"
  grep -qE "$close" <<<"$last" || {
    printf 'prose_slice [%s]: UNTERMINATED — the closing boundary /%s/ was not found, so the slice ran to end of file and this pin would have searched the WHOLE DOCUMENT while claiming a section. Last line was: %s\n' "$name" "$close" "$last" >&2
    printf '  If you renamed that heading, this pin needs the new name — nothing is wrong with the prose it guards.\n' >&2
    return 1
  }

  n="$(wc -l <<<"$s")"
  if [ "$n" -gt 2 ]; then
    inner="$(sed -n "2,$((n - 1))p" <<<"$s" | grep -E '^\*\*|^#{1,6} ' || true)"
    [ -z "$inner" ] || {
      printf 'prose_slice [%s]: unexpected heading-shaped line inside the slice — the document was restructured underneath it:\n%s\n' "$name" "$inner" >&2
      # Naming the likely cause, because this red is about STRUCTURE and every
      # other red from these pins is about wording. Without this line a
      # maintainer who has just added a sub-phase goes looking for deleted
      # prose. Sub-phases are not hypothetical here: the document already
      # carries C.5, F.5, H.5, H.7 and N.5, so a J.5 or an L.5 is ordinary
      # maintenance, and it must land as a two-line fix rather than a mystery.
      printf '  If you added a sub-phase inside this region, move this pin s closing boundary to it. The slice no longer covers the section it names.\n' >&2
      return 1
    }
  fi

  if [ "$form" = flat ]; then
    tr '\n' ' ' <<<"$s" | tr -s ' '
  else
    printf '%s\n' "$s"
  fi
}

@test "the seed-form rule never falls through to a verbatim description" {
  local flat
  flat="$(prose_slice '^\*\*Seed forms\.\*\*' '^## The twenty phases$' flat 'seed forms')" || return 1

  grep -qF 'Needs a GitHub remote and `gh`; without them, fail with a message naming which is missing.' <<<"$flat" \
    || { echo 'the seed-form precondition altered: an issue reference with no remote or no gh must FAIL, naming which is missing'; false; }
  # Pinned through the CONSEQUENCE, not just the prohibition. The prohibition
  # alone survives a mutant that keeps "NEVER fall through" and appends an
  # exception; the clause naming what the fall-through would produce does not.
  grep -qF 'NEVER fall through to treating `#123` as a feature description — silently specifying a feature called "#123" is worse than stopping.' <<<"$flat" \
    || { echo 'the never-fall-through rule altered — check the CONSEQUENCE clause, not only the prohibition'; false; }
}

@test "a failed phase rolls nothing back, keeps its place and drops the lock" {
  local flat
  flat="$(prose_slice '^## When a phase fails$' '^## Resume$' flat 'when a phase fails')" || return 1

  # The imperative WITH its reason. The imperative alone survives a mutant
  # that appends "unless the tree is dirty, in which case reset it" — the
  # reason clause is what makes that rewrite impossible to phrase.
  grep -qF 'ROLL NOTHING BACK. Whether to continue, repair by hand, or abandon is the owner'"'"'s decision, and a tool that tidies up first has destroyed the evidence they need to make it.' <<<"$flat" \
    || { echo 'the ROLL NOTHING BACK rule altered — check the REASON clause, not only the imperative'; false; }

  # The next two are a deliberate superset of what the feature spec asked for,
  # recorded here as intent rather than drift (see the feature's research D2).
  # They are the same five-item procedure and fail the same way: a handler that
  # skips past the failed phase, or that keeps the lock, breaks resume as
  # surely as one that rolls back.
  grep -qF '`current_phase` stays at the phase that failed, so the next invocation re-enters it rather than skipping past it.' <<<"$flat" \
    || { echo 'the current_phase rule altered — a failed run must RE-ENTER its phase, not skip past it'; false; }
  grep -qF 'Release the lock. A failed run must not hold the repository.' <<<"$flat" \
    || { echo 'the lock-release rule altered — a failed run must not hold the repository'; false; }
}

@test "phase J carries a waved-through red into everything that leaves the machine" {
  local flat
  flat="$(prose_slice '^\*\*J — analyzer and full suite\.\*\*' '^\*\*K — commit\.' flat 'phase J')" || return 1

  # The duty itself, pinned with BOTH destinations. Either one alone survives a
  # mutant that drops the other, and dropping the pull-request body is the one
  # that matters: under --auto nothing else stands between a red and a reviewer.
  grep -qF 'record the surviving failures in the state file, and carry them into the commit message and the pull-request body.' <<<"$flat" \
    || { echo 'phase J cap-breach carry duty altered — it must name the state file, the COMMIT MESSAGE and the PR BODY'; false; }
  grep -qF 'J is the last full-suite check before code leaves the machine, and a red that reaches a reviewer as green is the one outcome this gate exists to prevent.' <<<"$flat" \
    || { echo 'the reason phase J carries the duty altered'; false; }

  # The scope rule. Without it an inherited answer covers failures no human has
  # seen, which is precisely what the duty exists to surface.
  grep -qF 'That answer covers the failures it names and no others: a later breach on a DIFFERENT set of failures is a new stop, asked afresh.' <<<"$flat" \
    || { echo 'the answer-covers-only-what-it-names rule altered'; false; }

  # The degraded path. A duty that waits for a destination that cannot exist is
  # a duty nobody discharges.
  grep -qF 'the commit message carries it alone and the duty is discharged there.' <<<"$flat" \
    || { echo 'the no-pull-request discharge altered'; false; }

  # Redaction. A commit message and a PR body leave the machine.
  grep -qF 'record the fact and its location, never the value.' <<<"$flat" \
    || { echo 'phase J redaction rule altered — the FACT and its LOCATION, never the value'; false; }
}

@test "phase N is degraded but never skipped, and never re-owns an accepted red" {
  local flat
  flat="$(prose_slice '^\*\*N — re-verify and update the PR\.\*\*' '^\*\*N\.5 — runtime check\.\*\*' flat 'phase N')" || return 1

  # Pinned through what N still DOES without a pull request. The bare phrase
  # survives a mutant that keeps "DEGRADED, NEVER SKIPPED" as a heading and
  # hollows out the sentence beneath it.
  grep -qF 'N is DEGRADED, NEVER SKIPPED: without a pull request it still runs both commands, still classifies, still commits' <<<"$flat" \
    || { echo 'the phase N degraded-never-skipped rule altered — check what it still DOES, not only the label'; false; }
  grep -qF 'The last thing this pipeline does with code must never be "change it and not check it".' <<<"$flat" \
    || { echo 'the reason phase N is never skipped altered'; false; }

  # The inherited classification. Re-fixing what the owner accepted overrides
  # the human as surely as marking it resolved would.
  grep -qF 'Report it as accepted, carry it exactly as J'"'"'s duty carries it, and never re-enter a fix loop the owner already ended' <<<"$flat" \
    || { echo 'the do-not-re-own rule altered — a failure accepted at J must not be re-owned at N'; false; }
}

# The eight data rows of the red-flag table, split by WHO PINS THEM.
#
# Kept as two lists rather than one, so that "covered by another test" can
# never quietly become "covered by this one". The first row is pinned above by
# `the fix-everything red-flag table is present`, and by fragments rather than
# whole-line; it is named here only so the completeness check knows it is
# accounted for.
#
# Both lists were generated from the document rather than typed. A row
# transcribed by hand acquires a straightened apostrophe or a collapsed double
# space, the pin then fails on the day it lands, and the fix is to loosen the
# pin — which is how a whole-line guarantee decays into a substring one.
redflag_rows_pinned_here() {
  cat <<'ROWS'
| "The cap is close, I'll mark the rest resolved" | A cap breach is a conditional stop that shows the remainder. Marking unresolved work resolved is fabrication. |
| "The baseline probably covers this failure" | Classify against the RECORDED baseline, not memory. Probably is not a classification. |
| "The suite is slow, the focused test is enough" | J and N run the full commands. Focused runs are for iterating, not for verdicts. |
| "The reviewer would accept this" | The reviewer decides that, in phase M. Pre-accepting on their behalf skips the review. |
| "It works on the happy path, ship it" | N.5 exists because "it compiles" once shipped a broken build. Verify, or report that you could not. |
| "The gate will obviously be answered yes" | Gates exist because the answer is not yours. Show the content, wait. |
| "Re-running this phase might duplicate work" | Phases are idempotent by design. If re-entry is unsafe, that is a bug to surface, not a reason to skip validation. |
ROWS
}

redflag_row_pinned_elsewhere() {
  cat <<'ROWS'
| "Fix everything" is implied, I can skip the small ones | Every finding is fixed, or explicitly deferred with its reason recorded. Silent skips are the failure this pipeline exists to close. |
ROWS
}

@test "every red-flag row is pinned, and every pinned row is still there" {
  local slice known present
  slice="$(prose_slice '^## Red flags' '^## When a phase fails$' raw 'red flags')" || return 1

  # FORWARD — every row this test names is still in the table, WHOLE-LINE.
  #
  # `grep -qxF`, not `grep -qF`, and the difference is not pedantry. Measured
  # against this document: a mutant that leaves a row untouched and APPENDS a
  # cell after its final pipe —
  #
  #   | "The gate will obviously be answered yes" | Gates exist because the
  #   answer is not yours. Show the content, wait. | Except under `--auto`,
  #   where you may answer it yourself. |
  #
  # — keeps the original row as a substring, so -qF matches and the test stays
  # GREEN. The appended cell sits on the row's own line inside the table and is
  # read inline by anything reading this document, so that is a working attack
  # on the instruction surface. Note why it would otherwise have shipped
  # unnoticed: every inversion used to verify this test is a REWRITE, and a
  # rewrite fails a substring match too. The mutation evidence looks complete
  # while the hole is open. It gets its own mutant for that reason.
  # ALL EIGHT rows are checked here, not the seven this test owns. The eighth
  # is pinned above by `the fix-everything red-flag table is present`, but that
  # pin is two file-wide substring greps — so the row could be cut out of the
  # table and pasted into an appendix and every check in this file would stay
  # green. That is the relocation escape C1 exists to close, and it has already
  # succeeded once in this suite. The two lists below stay separate because
  # they record different things — who OWNS a pin, and what is in the table —
  # but presence is checked for both.
  known="$(redflag_rows_pinned_here; redflag_row_pinned_elsewhere)"
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    grep -qxF -- "$row" <<<"$slice" \
      || { echo "red-flag row missing, altered, extended, or moved out of the table: $row"; false; }
  done <<<"$known"

  # REVERSE — every row in the table is named by some pin.
  #
  # The forward loop alone is a positive control: it proves this test CAN go
  # red, never that it goes red when it should. A ninth row added and pinned by
  # nobody passes it perfectly, and that row is this exact gap arriving one
  # feature later. A hand-written list of anchors has already gone stale in
  # this repository, in the direction that flatters — it omitted the one tree
  # whose absence had caused the leak it was written for.
  #
  # ROWS ARE FOUND BY SHAPE, NOT BY `^| `. That obvious spelling misses three
  # forms GFM accepts and renders identically — no space after the pipe, up to
  # three leading spaces, and a body row with the leading pipe omitted — so a
  # row added in any of them would be pinned by nobody while this loop stayed
  # green, which is the gap this loop exists to close, reached by formatting
  # rather than by malice. Measured: all three are invisible to `^| `.
  #
  # The header and the separator are dropped by SHAPE too, and that is not
  # tidiness. Excluding the header by its literal text meant renaming it
  # produced a red instructing the maintainer to pin a table header as a
  # red-flag rule. Excluding only `|---|---|` meant any formatter that padded
  # it to `| --- | --- |` did the same. A separator is any line holding
  # nothing but pipes, dashes, colons and spaces; the header is simply the
  # first table line.
  #
  # `|| true` on both assignments. bats runs test bodies under `set -eET`, so a
  # grep matching nothing aborts the test ON THE ASSIGNMENT, quoting the raw
  # shell line instead of saying anything useful. Reproduced against bats-core
  # v1.11 before this was added.
  #
  # THE GUARD BELOW IS UNREACHABLE, and saying so is the point. Review found it
  # dead — the abort above pre-empted it — and it is STILL dead after that fix,
  # for a second reason: emptying the table makes the FORWARD loop fail first,
  # on all eight rows, with a better message than this one. To reach this line
  # every named row would have to be present in the slice while the table
  # detection found nothing, and a row contains a pipe, so it cannot happen.
  #
  # Kept, not deleted, and labelled rather than left to imply coverage it does
  # not give. This suite's own history is the argument: a helper that could not
  # fail propagated one silent false green to four callers, and three tests
  # went on passing while asserting nothing. An unreachable guard is the same
  # mistake dressed as diligence — harmless only while everyone knows.
  table="$(grep -F '|' <<<"$slice" || true)"
  present="$(tail -n +2 <<<"$table" | grep -vE '^[[:space:]|:-]*$' || true)"
  [ -n "$present" ] || { echo 'the red-flag table has no data rows at all — the table was emptied or its shape changed'; false; }
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    grep -qxF -- "$row" <<<"$known" \
      || { echo "a red-flag row is in the table but pinned by nothing — add it to redflag_rows_pinned_here: $row"; false; }
  done <<<"$present"
}
