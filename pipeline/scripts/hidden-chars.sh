# hidden-chars.sh - the one list of characters that can disguise text.
# shellcheck shell=bash
# Sourced, never run: it only sets HIDDEN_CHARS.
#
# progress.sh refuses these in a question or an answer (text_file), and
# trailer-check.sh refuses them in a commit trailer and escapes them when
# it shows one. Both read THIS list, so the two can never disagree
# (constitution, principle IV).
#
# HIDDEN_CHARS is a jq regular-expression class, spelled for a jq string
# literal: it goes into a jq program's text, never through --arg, because
# jq joins the surrogate pairs that spell the characters above U+FFFF only
# inside a literal.
#
# Characters a terminal can act on, or that can make text read as
# something else: C1 controls, bidi marks, overrides and isolates
# (U+061C, U+200E-200F, U+202A-202E, U+2066-2069), line and paragraph
# separators, zero-width and invisible formatting characters (U+00AD the
# soft hyphen, U+034F, U+180E, U+200B-200D, U+2060-2064, U+206A-206F, the
# shorthand format controls U+1BCA0-1BCA3, the musical format controls
# U+1D173-1D17A), invisible fillers (U+115F-1160, U+17B4-17B5, U+3164,
# U+FFA0), variation selectors, the byte-order mark, U+FFF0-FFFB
# (unassigned, then the interlinear annotation marks), and the block
# U+E0000-E0FFF at the start of plane 14: tags, which can carry text a
# model reads and a person does not see, supplementary variation
# selectors, and the rest, unassigned.
# Each added range is in Unicode's Default_Ignorable_Code_Point set: a font
# draws nothing for it. Every character is spelled as an escape, so the
# file is ASCII and its bytes cannot change in an editor. An allowlist
# would refuse ordinary text in most scripts, so this is a list: widen it
# when a new invisible character is found, and pin the new edges in
# pending.bats and preflight.bats.
# shellcheck disable=SC2034 # read by the scripts that source this file
HIDDEN_CHARS='[\u0080-\u009f\u00ad\u034f\u061c\u115f-\u1160\u17b4-\u17b5\u180b-\u180f\u200b-\u200f\u2028-\u202e\u2060-\u206f\u3164\ufe00-\ufe0f\ufeff\uffa0\ufff0-\ufffb\ud82f\udca0-\ud82f\udca3\ud834\udd73-\ud834\udd7a\udb40\udc00-\udb43\udfff]'
