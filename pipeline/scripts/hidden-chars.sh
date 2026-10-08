# hidden-chars.sh — the one list of characters that can disguise text.
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
# jq joins the surrogate pairs of the tag plane only inside a literal.
#
# Characters a terminal can act on, or that can make text read as
# something else: C1 controls, bidi marks, overrides and isolates
# (U+061C, U+200E-200F, U+202A-202E, U+2066-2069), line and paragraph
# separators, zero-width and invisible formatting characters (U+034F,
# U+180E, U+200B-200D, U+2060-2064, U+206A-206F), invisible fillers
# (U+115F-1160, U+17B4-17B5, U+3164, U+FFA0), variation selectors, the
# byte-order mark, interlinear annotation marks, and the tag plane, which
# can carry text a model reads and a person does not see. An allowlist
# would refuse ordinary text in most scripts, so this is a list — widen it
# when a new invisible character is found, and pin the new edges in
# pending.bats and preflight.bats.
# shellcheck disable=SC2034 # read by the scripts that source this file
HIDDEN_CHARS='[\u0080-\u009f͏؜ᅟᅠ឴឵᠋-᠏​-‏ -‮⁠-⁯ㅤ︀-️﻿ﾠ￹-￻󠀀-󠁿󠄀-󠇯]'
