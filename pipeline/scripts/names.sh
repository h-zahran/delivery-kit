# names.sh - the one rule for a name the run types into a command.
# shellcheck shell=bash
# Sourced, never run. preflight.sh and progress.sh read THIS file, so the two can
# never disagree (constitution, principle IV). It needs jq, and HIDDEN_CHARS from
# hidden-chars.sh, sourced first.
#
# Anyone may use the kit, in any language, so a name is refused only for what it
# would do: what a shell reads, what can disguise text on a terminal, and what is
# not text at all. git decides the rest of what a branch's name may be. Every later
# print of a name that passed here is safe, so nothing downstream masks it.

# text_ok <value> — valid UTF-8, with no control character, no character from
# HIDDEN_CHARS, and no other separator, format, private-use or unassigned character,
# or U+2800, U+FFFC or U+FFFD, which is what jq makes of a byte that is not text:
# each can look like something it is not (measured: with
# U+00A0, `x --force` reads as an option). An ASCII space is for name_problem and
# git to judge, so a name that holds one still reads as itself in a refusal. Plain
# ASCII starts no process. jq replaces a byte that is not UTF-8, so a value it does
# not hand back whole was not text. jq reads the program text for the list, as
# hidden-chars.sh says it must.
text_ok() {
  local LC_ALL=C
  case "$1" in *[[:cntrl:]]*) return 1 ;; esac
  case "$1" in *[!\ -~]*) ;; *) return 0 ;; esac
  [ "$(jq -jn --arg t "$1" '$t' 2>/dev/null)" = "$1" ] || return 1
  [ "$(jq -n --arg t "$1" '$t | test("'"$HIDDEN_CHARS"'") or (gsub(" "; "") | test("[\\p{Z}\\p{C}\\x{2800}\\x{FFFC}\\x{FFFD}]"))' 2>/dev/null)" = false ]
}

# shown <name> <value> sets the named variable to a copy safe to print in a
# refusal: cut to 200 bytes then ` [cut]`, with every byte that is not printable
# ASCII shown as `?` when the value is not plain text by text_ok, so a value from
# a tracked file cannot put a terminal escape on the screen, and a name in any
# language still reads as itself. printf -v sets the copy, and the value is never
# the format.
shown() {
  local LC_ALL=C s=$2 c='' ok=1
  text_ok "$s" || ok=0
  if [ "${#s}" -gt 200 ]; then
    s=${s:0:200}; c=" [cut]"
    # Plain text keeps whole characters: back over the bytes of a split one.
    if [ "$ok" = 1 ]; then
      while case "${s: -1}" in [$'\200'-$'\277']) true ;; *) false ;; esac; do s=${s%?}; done
      case "${s: -1}" in [$'\300'-$'\377']) s=${s%?} ;; esac
    fi
  fi
  [ "$ok" = 1 ] || s=${s//[![:print:]]/?}
  printf -v "$1" '%s' "$s$c"
}

# name_problem <value> — prints why a branch's name cannot be typed into a command,
# or nothing. git refuses the other characters (~ ^ : ? * [ \), a space and a
# control character itself. It takes these, measured: $ ` ; & | ( ) < > ' " { } !,
# and any byte past 0x7f. A lone @ passes git's format check, and git reads it as
# HEAD. A # is a comment only at the start of a word. A leading + on a push is a
# forced update, measured: `git push origin +main` erased a teammate's commit.
name_problem() {
  local LC_ALL=C
  case "$1" in
    @) printf 'is what git reads as HEAD'; return 0 ;;
    -*) printf 'starts with a dash, which a command reads as an option'; return 0 ;;
    \#*) printf 'starts with #, which a shell reads as a comment'; return 0 ;;
    +*) printf 'starts with +, which git push reads as a forced update'; return 0 ;;
    *[\$\`\;\&\|\(\)\<\>\'\"\{\}\!]*) printf 'holds a character a shell reads: one of $ ` ; & | ( ) < > quotes { } !'; return 0 ;;
  esac
  text_ok "$1" || printf 'holds a control or hidden character, or is not text'
}

# run_name_ok <value> — a run's name, which is also a folder on every system:
# letters of any language, their marks, digits, dot, dash and underscore. Plain
# ASCII starts no process. A superscript digit is refused: Windows reads COM¹ as a
# device, and the device check reads ASCII.
run_name_ok() {
  local LC_ALL=C
  [ -n "$1" ] || return 1
  case "$1" in *[!\ -~]*) ;; *)
    case "$1" in *[!A-Za-z0-9._-]*) return 1 ;; esac
    return 0 ;;
  esac
  text_ok "$1" || return 1
  [ "$(jq -n --arg t "$1" '$t | test("^[\\p{L}\\p{M}\\p{Nd}._-]+$")' 2>/dev/null)" = true ]
}
