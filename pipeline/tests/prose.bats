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
# reasoning recorded in-file. These five prefer the operative CLAUSE — though
# not uniformly, and the exception matters more than the rule here: several
# anchors below are complete sentences, because that is how long the obligation
# runs. Anchor LENGTH is not what makes them reflow-safe. FLATTENING is, and
# the older `flat`-based pins above already do it.
#
# Say that plainly, because getting it wrong is dangerous in one direction: a
# maintainer who believes short anchors are what survives a rewrap will shorten
# one, and a shortened anchor is a cuttable anchor — the failure C3 records
# twice in this very suite. Shorten nothing to buy reflow-safety you already
# have.
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
# FIVE guards follow: the file is readable, the slice is non-empty, it opened
# on its boundary, it closed on its boundary, and it holds no unexpected
# heading. THREE of them are contract C2 (opened, closed, no heading); the
# readable-file and non-empty checks come from FR-008 and from this function's
# own reasoning, not from C2.
#
# The split is spelled out because the first version of this comment cited C2
# for all five — while the sentence below warns that a surplus guard invites
# deletion. A maintainer reconciling code against the cited contract would have
# found two guards the contract does not ask for, having just been told that a
# miscount is suspicious. (Arity and form are checked further up, before any of
# this; they are about the CALL, not the slice.)
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
  # `-f` as well as `-r`: a directory is READABLE, so replacing SKILL.md with a
  # directory of the same name passed this guard, `tr` failed with "Is a
  # directory", the slice came back empty, and all five pins blamed a missing
  # opening boundary — the exact wrong-message failure this guard exists to
  # stop, surviving one substitution of the path.
  { [ -f "$ORCH" ] && [ -r "$ORCH" ]; } || {
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
  # THE CR STRIP RUNS BEFORE awk, NOT AFTER. An earlier version piped awk's
  # output through `tr -d '\r'`, which is far too late to be the defence it
  # claimed to be: awk had already matched the boundaries against lines still
  # carrying their CR, and three of the five closing patterns are `$`-anchored
  # — '^## Resume$', '^## The twenty phases$', '^## When a phase fails$'. On a
  # CRLF checkout, under an awk that does not itself ignore a trailing CR (GNU
  # awk, which is what the Linux CI runner has), none of the three matches: the
  # range runs to end of file and three pins fail with UNTERMINATED and advice
  # about a heading nobody renamed. That is precisely the wrong-message class
  # the strip was added to prevent, produced by the strip sitting in the wrong
  # place. It is invisible on this machine, where the Cygwin awk and grep both
  # ignore a trailing CR — which is why it survived the first round.
  s="$(tr -d '\r' < "$ORCH" | PS_OPEN="$open" PS_CLOSE="$close" \
       awk '$0 ~ ENVIRON["PS_OPEN"], $0 ~ ENVIRON["PS_CLOSE"]')"

  [ -n "$s" ] || {
    printf 'prose_slice [%s]: the slice is EMPTY — the opening boundary matched nothing: %s\n' "$name" "$open" >&2
    return 1
  }

  # NEAR-UNREACHABLE, and labelled rather than left to look load-bearing.
  # awk's range operator only starts emitting on a line matching PS_OPEN, so
  # the first line always matches unless awk and grep disagree about the ERE —
  # which they do not for the `\*`, `\.` and em dashes used here. Contract C2
  # obligation 1 asks for it, so it stays; but a maintainer reconciling code
  # against C2 should know its red is not producible, because the comment above
  # warns that a surplus guard invites deletion.
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
      # ACCEPTED COST, named so nobody rediscovers it as a bug: this fires on
      # ANY line starting with `**`, not only a heading. A bold-led sentence
      # inside one of these four regions — "**Note.** Under `--auto` the
      # analyzer runs first." — trips it, and these are prose sections where
      # that is an ordinary thing to write. The alternative is a rule that
      # distinguishes a heading from emphasis, which markdown does not let a
      # grep do reliably; a false red that names its own cause was judged the
      # better failure. Hence the line below.
      #
      # Naming the likely cause, because this red is about STRUCTURE and every
      # other red from these pins is about wording. Without this line a
      # maintainer who has just added a sub-phase goes looking for deleted
      # prose. Sub-phases are not hypothetical here: the document already
      # carries C.5, F.5, H.5, H.7 and N.5, so a J.5 or an L.5 is ordinary
      # maintenance, and it must land as a two-line fix rather than a mystery.
      printf '  If you added a sub-phase inside this region, move this pin'"'"'s closing boundary to it. The slice no longer covers the section it names.\n' >&2
      return 1
    }
  fi

  if [ "$form" = flat ]; then
    tr '\n' ' ' <<<"$s" | tr -s ' '
  else
    printf '%s\n' "$s"
  fi
}

# ---------------------------------------------------------------------------
# INSERTION GUARDS for the four clause pins.                    (feature 011)
#
# Phase-M round 2 found the hole these close, and it is the SAME hole this
# feature congratulated itself for closing on the table rows. `grep -qxF` was
# adopted for rows because a mutant that leaves a row intact and APPENDS to it
# keeps the original as a substring. That reasoning was never carried to the
# four prose pins, and the comment above the roll-nothing-back anchor claimed
# an immunity it did not have — "the reason clause is what makes that rewrite
# impossible to phrase". It is entirely possible to phrase. Measured, landed,
# and watched: appending
#
#   " Exception: under `--auto`, reset the tree first so the next phase
#     starts clean."
#
# after the ROLL NOTHING BACK reason clause left the whole suite GREEN, and the
# same trick silenced phase J's carry duty and phase N's never-skipped rule.
# The rule is inverted, the anchor is untouched, and a substring match cannot
# tell the difference.
#
# Whole-line matching cannot help here: a flattened slice IS one line. What
# distinguishes an insertion is that it changes what SURROUNDS the rule, so the
# guard has to assert the surroundings. Each span below runs from the first
# safety sentence of its region to the region's closing boundary, flattened.
# Nothing can be inserted anywhere inside it, or appended after the last rule,
# without breaking the match.
#
# The cost, stated rather than discovered later: any word change inside a span
# reddens its pin. That is a heavier trigger than the clause anchors, and it is
# accepted because these four regions are safety prose end to end — there is no
# incidental sentence in them to reword innocently. The brittleness the seed
# objected to was REFLOW, and flattening already answers that: a span is
# immune to rewrapping and sensitive only to words.
#
# The two layers report different things, which is why both are kept:
#   a clause anchor fails  -> a named rule was ALTERED
#   only the span fails    -> something was inserted or reworded AROUND them
#
# Generated from the document, never transcribed.
# assert_span <span-function> <message>
#
# Never `grep -qF -- "$(span_x)"` directly, and this is not style. A command
# substitution that fails — a renamed function, a typo, an emptied heredoc — is
# NOT caught by errexit in an argument position, and GNU grep treats an EMPTY
# -F pattern as matching every line. The guard then passes, silently, having
# asserted nothing. Measured: `grep -qF -- "$(nosuchfn)" <<<"whatever"` prints
# "command not found" to stderr and exits 0.
#
# That is the fault helper.bash records for bytes_of in capitals — IT MUST ALSO
# BE ABLE TO FAIL — arriving by a different route, and here one typo would have
# repealed a whole region's insertion protection with nothing going red.
assert_span() {
  local fn="$1" msg="$2" span
  span="$("$fn" 2>/dev/null)" || span=""
  [ -n "$span" ] || {
    echo "the span function $fn produced NOTHING — an empty pattern matches every line, so this guard asserted nothing at all"
    return 1
  }
  grep -qF -- "$span" <<<"$flat" || { echo "$msg"; return 1; }
}

span_redflags() {
  cat <<'SPAN'
## Red flags — findings are fixed or surfaced, never waved through If you notice one of these thoughts, stop: you are rationalising. | Thought | Reality | |---|---| | "Fix everything" is implied, I can skip the small ones | Every finding is fixed, or explicitly deferred with its reason recorded. Silent skips are the failure this pipeline exists to close. | | "The cap is close, I'll mark the rest resolved" | A cap breach is a conditional stop that shows the remainder. Marking unresolved work resolved is fabrication. | | "The baseline probably covers this failure" | Classify against the RECORDED baseline, not memory. Probably is not a classification. | | "The suite is slow, the focused test is enough" | J and N run the full commands. Focused runs are for iterating, not for verdicts. | | "The reviewer would accept this" | The reviewer decides that, in phase M. Pre-accepting on their behalf skips the review. | | "It works on the happy path, ship it" | N.5 exists because "it compiles" once shipped a broken build. Verify, or report that you could not. | | "The gate will obviously be answered yes" | Gates exist because the answer is not yours. Show the content, wait. | | "Re-running this phase might duplicate work" | Phases are idempotent by design. If re-entry is unsafe, that is a bug to surface, not a reason to skip validation. | ## When a phase fails
SPAN
}

span_seed() {
  cat <<'SPAN'
**Seed forms.** The seed is interpreted three ways, in order: 1. Text matching `Phase <N>: <title>` — read that section out of `planFile`. 2. `#` followed by digits — fetch that GitHub issue. Needs a GitHub remote and `gh`; without them, fail with a message naming which is missing. NEVER fall through to treating `#123` as a feature description — silently specifying a feature called "#123" is worse than stopping. 3. Anything else — the feature description, verbatim, which is what the specify command takes natively. ## The twenty phases
SPAN
}

span_fail() {
  cat <<'SPAN'
## When a phase fails 1. Print the phase, the reason, and the working tree as it stands. 2. Write the failure into the state file; `current_phase` stays at the phase that failed, so the next invocation re-enters it rather than skipping past it. 3. ROLL NOTHING BACK. Whether to continue, repair by hand, or abandon is the owner's decision, and a tool that tidies up first has destroyed the evidence they need to make it. 4. Release the lock. A failed run must not hold the repository. 5. Offer the resume prompt on the next invocation. ## Resume
SPAN
}

span_j() {
  cat <<'SPAN'
**J — analyzer and full suite.** Run `analyzeCommand`, then `testCommand`. Classify every failure against `test_baseline`: pre-existing failures are reported, not owned; new failures are this run's to fix. Fixes for independent failures fan out. Loop until clean against baseline, at most `maxVerifyIters` iterations; a cap breach is a conditional stop — show the failures that survived and ask whether to continue; a hard failure still stops the run outright. A breach the owner waves through carries a duty the other caps do not: record the surviving failures in the state file, and carry them into the commit message and the pull-request body. J is the last full-suite check before code leaves the machine, and a red that reaches a reviewer as green is the one outcome this gate exists to prevent. The record lands under `gates.J`, beside the answer that waved it through — the same key every answered stop already writes. That answer covers the failures it names and no others: a later breach on a DIFFERENT set of failures is a new stop, asked afresh. The never-re-ask rule suppresses a repeat of the same question, never a first sight of a new one, and a run that inherits an answer for failures no human has seen has waved through exactly what this duty exists to surface. Where a degradation named at L leaves no pull request to carry — no remote, a non-GitHub remote, no `gh` — the commit message carries it alone and the duty is discharged there. The duty names three destinations because three usually exist; it never waits on one that cannot. Redaction binds that carry exactly as it binds the handoff package: where a surviving failure's output holds a credential, an endpoint or a token, record the fact and its location, never the value. A commit message and a pull-request body leave the machine, and under `--auto` no gate stands between them and whoever can read the repository. **K — commit. STOPS AND ASKS.**
SPAN
}

span_n() {
  cat <<'SPAN'
**N — re-verify and update the PR.** Run `analyzeCommand` and `testCommand` again, classify against baseline, commit fixes, push to the PR branch. N is DEGRADED, NEVER SKIPPED: without a pull request it still runs both commands, still classifies, still commits — it just has nothing to push a review fix to. The last thing this pipeline does with code must never be "change it and not check it". One classification is inherited rather than made afresh: a failure the owner accepted at J's cap breach is still new against the baseline, and N must not re-own it. Report it as accepted, carry it exactly as J's duty carries it, and never re-enter a fix loop the owner already ended — an answer given at a stop binds the phases downstream of it, and re-fixing what was accepted overrides the human as surely as marking it resolved would. **N.5 — runtime check.**
SPAN
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
  # INSERTION GUARD — see the block above. A clause anchor proves a rule is
  # still present; only this proves nothing was added beside it.
  assert_span span_seed 'the seed-form region gained, lost or reworded text around its rules. The anchors above name a rule that CHANGED; this one fires when text was INSERTED beside them — an appended exception inverts a rule while leaving its anchor intact.' || false
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
  # INSERTION GUARD — see the block above. A clause anchor proves a rule is
  # still present; only this proves nothing was added beside it.
  assert_span span_fail 'the failure procedure gained, lost or reworded text around its rules. An appended exception ("unless the tree is dirty, reset it") inverts ROLL NOTHING BACK while leaving its anchor a perfect substring.' || false
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
  # INSERTION GUARD — see the block above. A clause anchor proves a rule is
  # still present; only this proves nothing was added beside it.
  assert_span span_j 'the phase J cap-breach paragraphs gained, lost or reworded text around the duty. An appended opt-out ("under --auto the carry is optional") inverts the duty while leaving its anchor intact.' || false
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
  # INSERTION GUARD — see the block above. A clause anchor proves a rule is
  # still present; only this proves nothing was added beside it.
  assert_span span_n 'phase N gained, lost or reworded text around its rules. An appended skip clause ("when the PR is absent, skip N") inverts DEGRADED, NEVER SKIPPED while leaving its anchor intact.' || false
}

# The eight data rows of the red-flag table, split by WHO PINS THEM.
#
# Kept as two lists rather than one to record WHO OWNS each pin — nothing more.
# Both lists are whole-line checked by the forward loop below, so the split is
# documentation, not a difference in protection. An earlier version of this
# comment said the second row was named "only so the completeness check knows
# it is accounted for", which contradicted the loop and invited someone to drop
# it as inert; dropping it would have removed the only whole-line check on that
# row, since the test that owns it pins it with two file-wide substrings.
#
# The ownership claim itself is UNVERIFIED and cannot easily be otherwise: no
# assertion connects this list to the test named in it, so reword or delete
# that test and this comment quietly becomes false. That is the same
# hand-written-list-goes-stale failure the reverse loop exists to close, one
# level up. It is tolerable only because the claim is no longer load-bearing —
# the forward loop checks the row either way.
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
  # INSERTION GUARD for this region too. Round 3 found the Red flags section
  # was the one safety region without one — and its rows are the most directly
  # instruction-shaped text in the document. Rewriting the intro to "…stop: you
  # are rationalising — except under `--auto`, where every one of them is
  # acceptable." neutralised all eight rows while both loops below stayed
  # green, because both check only the rows themselves. Measured.
  local flat
  flat="$(prose_slice '^## Red flags' '^## When a phase fails$' flat 'red flags')" || return 1
  assert_span span_redflags 'the Red flags region gained, lost or reworded text around the table. The row checks below prove each ROW is intact; only this proves nothing was written around them — an exception added to the intro neutralises every row without touching one.' || false

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
  # THE GUARD BELOW IS NEARLY, BUT NOT ENTIRELY, UNREACHABLE — and the earlier
  # version of this comment called it dead outright, which was wrong in a way
  # worth recording. Normally the FORWARD loop fails first, on all eight rows,
  # with a better message. But if someone empties the table AND empties both
  # row lists, `known` is empty, the forward loop's `[ -n "$row" ] || continue`
  # makes it assert nothing at all, and this line is the only thing left that
  # reddens. Calling it dead invited its removal, which would have left that
  # case with no assertion whatsoever — a test passing on an empty table by
  # iterating an empty list.
  #
  # Kept, not deleted, and labelled rather than left to imply coverage it does
  # not give. This suite's own history is the argument: a helper that could not
  # fail propagated one silent false green to four callers, and three tests
  # went on passing while asserting nothing. An unreachable guard is the same
  # mistake dressed as diligence — harmless only while everyone knows.
  # THE TABLE IS FOUND BY ITS SEPARATOR, not by "the first line carrying a
  # pipe". That earlier rule assumed the first pipe-bearing line in the region
  # is the header — and the region is PROSE. A sentence mentioning
  # `--auto | --auto-release` above the table displaced the header into the
  # data rows, and the test then demanded somebody pin `| Thought | Reality |`
  # as a red-flag rule; a sentence below the table was reported as an unpinned
  # row. Both measured. It also had a false-green direction: delete the header
  # line and the first real row silently stopped needing a pin.
  #
  # A GFM table is a separator line, then rows, then a blank line. That is the
  # real shape, so that is what this looks for — skip to the separator (pipes,
  # dashes, colons and spaces, with at least one dash), then take lines until
  # the table ends. Prose on either side is outside by construction rather than
  # by exclusion, and every row spelling GFM accepts is inside.
  # The separator must contain a PIPE as well as a dash. Without that, a plain
  # `---` thematic break anywhere in the region was taken as the table
  # separator: the next line is blank, the scan ended immediately, and the test
  # announced that the table had been emptied while all eight rows sat intact
  # below. Measured.
  #
  # And the scan does not STOP at the first blank line, it resumes looking for
  # the next separator. Stopping made a second table block — blank line,
  # header, separator, a ninth rationalisation — completely invisible to the
  # completeness check, which is the FR-005a escape this loop exists to close,
  # reached by adding a table instead of a row. Measured too.
  present="$(awk '
    !seen && /\|/ && /-/ && /^[[:space:]]*[|[:space:]:-]+$/ { seen = 1; next }
    seen && /^[[:space:]]*$/ { seen = 0; next }
    seen { print }
  ' <<<"$slice" || true)"
  [ -n "$present" ] || { echo 'the red-flag table has no data rows at all — the table was emptied or its shape changed'; false; }
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    grep -qxF -- "$row" <<<"$known" \
      || { echo "a red-flag row is in the table but pinned by nothing — add it to redflag_rows_pinned_here, or to redflag_row_pinned_elsewhere if another test owns it: $row"; false; }
  done <<<"$present"
}
