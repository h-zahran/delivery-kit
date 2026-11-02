#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load helper

# Under `pipefail`, a pipe into `grep -q` is a race. grep -q leaves at its
# first match and closes the pipe; the program still writing into it can die
# of SIGPIPE, the pipeline then fails, and an `if` built on it takes the wrong
# branch — the more so the busier the machine. pipeline/scripts/preflight.sh's
# constitution NUL check did exactly this, and read a UTF-16 constitution as
# set in 33 of 400 runs on a loaded machine (feature 047). This walk refuses
# the shape in every shipped script that runs under pipefail, found by walking
# the tracked files rather than by naming them.
#
# "Shipped" is the spec's rule: tracked *.sh and *.bash outside .specify/ and
# outside every tests/ directory. Proof material under specs/ (today
# specs/033-gate-fewer-processes/proof/differential.sh) stays listed: it sets
# no pipefail and nothing sources it, so the rule costs no false red, and a
# proof script that one day sets pipefail deserves the same check.

# The line scanner. Reads one file, joins a line ending in a backslash or a
# pipe with the next one, skips whole-line comments, and prints
# <path>:<line>: <text> for every pipe (not ||; |& counts) into grep, egrep or
# fgrep — behind VAR=value words, `command` or `env`, quoted or escaped — that
# carries -q in any flag group, --quiet or --silent before the grep command
# ends at ;, &&, ||, |, ), a comment or `--`. <line> is where the pipe starts.
# Quoted words after grep are blanked first, so a quoted ; or | cannot end the
# flag scan early. Written for one-true-awk as well as gawk and mawk: no
# character classes, no ^ or $ inside a group (padding spaces stand in), and no
# apostrophe anywhere in the program — q carries it.
PIPEFAIL_SCAN_AWK='
function scan(s, ln,    i, n, rest, r) {
  n = length(s)
  for (i = 1; i <= n; i++) {
    if (substr(s, i, 1) != "|") continue
    # The second bar of || (the first fails the grep match below).
    if (i > 1 && substr(s, i - 1, 1) == "|") continue
    rest = substr(s, i + 1)
    if (substr(rest, 1, 1) == "&") rest = substr(rest, 2)
    rest = rest " "
    if (!match(rest, gre)) continue
    r = " " substr(rest, RSTART + RLENGTH - 1)
    gsub(sq, "Q", r)
    gsub(/"[^"]*"/, "Q", r)
    if (match(r, /[|;)]|&&|[ \t]#|[ \t]--[ \t]/)) r = substr(r, 1, RSTART - 1)
    r = r " "
    if (r ~ /[ \t](-[A-Za-z0-9]*q[A-Za-z0-9]*|--quiet|--silent)[ \t]/) {
      print f ":" ln ": " s
      return
    }
  }
}
BEGIN {
  sq = q "[^" q "]*" q
  gre = "^[ \t]*([{(][ \t]*)*(([A-Za-z_][A-Za-z0-9_]*=[^ \t]*|command|env|exec|nice|timeout|-[A-Za-z]+|[0-9.]+[smhd]?)[ \t]+)*[\\\\]?[\"" q "]?([^ \t\"" q "|;&]*/)?[ef]?grep[\"" q "]?[ \t]"
  cm = "[ \t]+#[^\"" q "]*$"
}
{ sub(/\r$/, "") }
!cont && /^[ \t]*#/ { next }
{
  if (cont) buf = buf " " $0
  else { buf = $0; start = FNR }
  cont = 0
  if (match(buf, /\\+$/) && RLENGTH % 2 == 1) {
    buf = substr(buf, 1, length(buf) - 1)
    cont = 1
    next
  }
  t = buf
  sub(cm, "", t)
  sub(/[ \t]+$/, "", t)
  if (t ~ /\|$/) { buf = t; cont = 1; next }
  scan(buf, start)
}
END { if (cont) scan(buf, start) }'

# The source finder. For every `.` or `source` command in the given files,
# prints the first *.sh or *.bash name that follows it, joined to the
# sourcing file's own directory: `. "$here/lib.sh"` and
# `. "$(dirname "$0")/lib.sh"` in dir/a.sh both print dir/lib.sh. Only a
# library beside its caller is followed (the layout every shipped script
# uses); a same-named script elsewhere is never pulled in by mistake.
PIPEFAIL_SOURCES_AWK='
{
  d = FILENAME
  if (d ~ /\//) sub(/[^\/]*$/, "", d); else d = ""
  s = " " $0
  while (match(s, /[;&|({ \t](\.|source)[ \t]+/)) {
    s = substr(s, RSTART + RLENGTH)
    if (match(s, /[A-Za-z0-9_.-]+\.(sh|bash)/)) print d substr(s, RSTART, RLENGTH)
  }
}'

# pipefail_walk — reads newline-separated paths on stdin. Walks every file
# whose text holds `pipefail`, and every listed file a walked file sources
# from its own directory (a library sourced into a pipefail script runs under pipefail
# but need not say so), to a fixed point. Prints `walked: <path>` for each,
# every flagged line as <path>:<line>: <text>, and how many files it walked.
# Returns 1 on any flagged line, on a listed file grep cannot read, on an awk
# failure, and on zero files walked: a walk that looked at nothing has proved
# nothing.
pipefail_walk() {
  local p b i rc n=0 bad=0 hits names changed nl=$'\n'
  local -a all=() inwalk=() srcs=()
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    all+=("$p")
  done
  for ((i = 0; i < ${#all[@]}; i++)); do
    rc=0
    grep -q 'pipefail' "${all[i]}" || rc=$?
    case $rc in
      0) inwalk[i]=1 ;;
      1) inwalk[i]=0 ;;
      *) echo "cannot read ${all[i]} (grep status $rc)"; return 1 ;;
    esac
  done
  changed=1
  while [ "$changed" -eq 1 ]; do
    changed=0
    srcs=()
    for ((i = 0; i < ${#all[@]}; i++)); do
      [ "${inwalk[i]}" -eq 1 ] || continue
      srcs+=("${all[i]}")
    done
    [ "${#srcs[@]}" -gt 0 ] || break
    rc=0
    names="$(awk -v q="'" "$PIPEFAIL_SOURCES_AWK" "${srcs[@]}")" || rc=$?
    [ "$rc" -eq 0 ] || { echo "awk failed (status $rc) finding what the walked files source"; return 1; }
    for ((i = 0; i < ${#all[@]}; i++)); do
      [ "${inwalk[i]}" -eq 0 ] || continue
      b="${all[i]}"
      case "$nl$names$nl" in
        *"$nl$b$nl"*) inwalk[i]=1; changed=1 ;;
      esac
    done
  done
  for ((i = 0; i < ${#all[@]}; i++)); do
    [ "${inwalk[i]}" -eq 1 ] || continue
    p="${all[i]}"
    printf 'walked: %s\n' "$p"
    n=$((n + 1))
    rc=0
    hits="$(awk -v f="$p" -v q="'" "$PIPEFAIL_SCAN_AWK" "$p")" || rc=$?
    [ "$rc" -eq 0 ] || { echo "awk failed (status $rc) on $p"; return 1; }
    if [ -n "$hits" ]; then
      printf '%s\n' "$hits"
      bad=1
    fi
  done
  printf 'walked %s files that set pipefail or are sourced by one\n' "$n"
  [ "$n" -gt 0 ] || { echo 'no file that sets pipefail was walked'; return 1; }
  [ "$bad" -eq 0 ]
}

# A fixture script: `set -euo pipefail` (unless the first argument is
# `nopipefail`) and the given lines, written to a new file; prints its path.
# The shebang is line 1, the set line 2, so the first given line is line 3
# (line 2 without pipefail).
pipefail_fixture() {
  local mode="$1"; shift
  local f
  f="$(mktemp "$BATS_TEST_TMPDIR/fx.XXXXXX")"
  # A .sh name, as the source finder reads only *.sh and *.bash names (BSD
  # mktemp takes no suffix, so the name is made, then renamed).
  mv "$f" "$f.sh"; f="$f.sh"
  { printf '%s\n' '#!/usr/bin/env bash'
    [ "$mode" = nopipefail ] || printf '%s\n' 'set -euo pipefail'
    printf '%s\n' "$@"; } > "$f"
  printf '%s\n' "$f"
}

# Each argument is one script line set on line 4 (after `echo start`); the
# walk must refuse each and name line 4.
pipefail_expect_flagged() {
  local f s
  for s in "$@"; do
    f="$(pipefail_fixture pipefail 'echo start' "$s")"
    run pipefail_walk <<<"$f"
    [ "$status" -eq 1 ] || { echo "not refused: $s"; echo "$output"; return 1; }
    [[ $output == *"$f:4: "* ]] || { echo "line not named for: $s"; echo "$output"; return 1; }
  done
}

@test "no shipped script that sets pipefail pipes into grep -q" {
  local p rc=0 list="$BATS_TEST_TMPDIR/list" paths="$BATS_TEST_TMPDIR/paths"
  local -a found=()
  cd "$ROOT"
  git ls-files -z -- '*.sh' '*.bash' ':(exclude).specify/' ':(exclude,glob)**/tests/**' > "$list" || rc=$?
  [ "$rc" -eq 0 ] || { echo "git ls-files failed: $rc"; false; }
  while IFS= read -r -d '' p; do
    case $p in *$'\n'*) echo "a tracked path holds a line feed: the walk reads one path per line"; false ;; esac
    found+=("$p")
  done < "$list"
  [ "${#found[@]}" -gt 0 ] || { echo 'git listed no shell script'; false; }
  printf '%s\n' "${found[@]}" > "$paths"
  run pipefail_walk < "$paths"
  printf '%s\n' "$output"
  [ "$status" -eq 0 ] || { echo 'capture the output first, then match it: a reader that leaves early can kill the writer under pipefail'; false; }
  [[ $output == *'walked '*' files that set pipefail'* ]] || false
  # The reach floor: the bug's home, and a library walked only because a
  # pipefail script sources it.
  [[ $'\n'$output == *$'\n''walked: pipeline/scripts/preflight.sh'$'\n'* ]] || { echo 'preflight.sh was not walked'; false; }
  [[ $'\n'$output == *$'\n''walked: pipeline/scripts/hidden-chars.sh'$'\n'* ]] || { echo 'hidden-chars.sh was not walked'; false; }
}

@test "the walk names a planted pipe into grep -q, -qE or --quiet by its line" {
  local f s
  for s in "x | grep -q ' 00'" "x | grep -qE '^a'" "x |grep --quiet a" "x | grep -Fxq a"; do
    f="$(pipefail_fixture pipefail 'echo start' "if $s; then :; fi")"
    run pipefail_walk <<<"$f"
    [ "$status" -eq 1 ] || { echo "not refused: $s"; echo "$output"; false; }
    [[ $output == *"$f:4: "* ]] || { echo "line not named for: $s"; echo "$output"; false; }
  done
}

@test "the walk names a pipe continued on the next line by the line it starts on" {
  local f shape
  for shape in 1 2 3 4; do
    case $shape in
      1) f="$(pipefail_fixture pipefail 'echo start' 'x | \' 'grep -q a' 'echo end')" ;;
      2) f="$(pipefail_fixture pipefail 'echo start' 'x |' 'grep -q a' 'echo end')" ;;
      3) f="$(pipefail_fixture pipefail 'echo start' 'x |   ' '  grep -q a' 'echo end')" ;;
      4) f="$(pipefail_fixture pipefail 'echo start' 'x | grep \' '-q a' 'echo end')" ;;
    esac
    run pipefail_walk <<<"$f"
    [ "$status" -eq 1 ] || { echo "not refused: shape $shape"; cat "$f"; echo "$output"; false; }
    [[ $output == *"$f:4: "* ]] || { echo "line not named for shape $shape"; echo "$output"; false; }
  done
}

@test "the walk names a pipe into grep behind VAR=value, command, a backslash or quotes" {
  pipefail_expect_flagged \
    'x | LC_ALL=C grep -q a' \
    'x | LC_ALL=C LANG=C grep -q a' \
    'x | command grep -q a' \
    'x | env grep -q a' \
    'x | \grep -q a' \
    'x | "grep" -q a' \
    "x | 'grep' -q a"
}

@test "the walk names a grouped grep, a grep by path or behind a wrapper, and a pipe before a comment" {
  pipefail_expect_flagged \
    'x | { grep -q a; }' \
    'x | ( grep -q a )' \
    'x | /usr/bin/grep -q a' \
    'x | timeout 5 grep -q a' \
    'x | nice grep -q a' \
    'x | env -i grep -q a' \
    'x | exec grep -q a'
  # A pipe that ends its line before a comment still joins the next line.
  local f
  f="$(pipefail_fixture pipefail 'echo start' 'x |  # the hex dump' "grep -q ' 00'")"
  run pipefail_walk <<<"$f"
  [ "$status" -eq 1 ] || { echo "$output"; false; }
  [[ $output == *"$f:4: "* ]] || { echo "$output"; false; }
}

@test "the walk follows a library sourced through dirname, and only from the caller's directory" {
  local d="$BATS_TEST_TMPDIR/two" lib main far
  mkdir -p "$d/a" "$d/b"
  printf '%s\n' '#!/usr/bin/env bash' 'x | grep -q a' > "$d/a/lib.sh"
  printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' '. "$(dirname "$0")/lib.sh"' > "$d/a/main.sh"
  # A different lib.sh in another directory: never sourced by anything.
  printf '%s\n' '#!/usr/bin/env bash' 'y | grep -q b' > "$d/b/lib.sh"
  lib="$d/a/lib.sh"; main="$d/a/main.sh"; far="$d/b/lib.sh"
  run pipefail_walk <<<"$(printf '%s\n' "$far" "$lib" "$main")"
  [ "$status" -eq 1 ] || { echo "$output"; false; }
  [[ $output == *"$lib:2: "* ]] || { echo "$output"; false; }
  [[ $output != *"walked: $far"* ]] || { echo "the other directory's lib.sh was pulled in: $output"; false; }
  [[ $output == *'walked 2 files'* ]] || { echo "$output"; false; }
}

@test "the walk names |&, egrep, fgrep, --silent, flag groups with digits, and -q before ; or )" {
  pipefail_expect_flagged \
    'x |& grep -q a' \
    'x | egrep -q a' \
    'x | fgrep -q a' \
    'x | grep --silent a' \
    'x | grep -qm1 a' \
    'x | grep -m1q a' \
    'if x | grep a -q; then :; fi' \
    '( x | grep a -q)' \
    'v="$(x | grep -q a && echo y)"' \
    "x | grep -e ';' -q a"
}

@test "the walk passes ||, whole-line comments, and a -q that belongs to a later command" {
  local f
  f="$(pipefail_fixture pipefail \
    'a || grep -q x f' \
    "# was: od | grep -q ' 00'" \
    '   # x | grep -q a' \
    '	# x | grep -q a' \
    'x | grep -v a && rsync -q b c' \
    'x | grep -v a; rsync -q b c' \
    'x | grep -v a || rsync -q b c' \
    'x | grep -v a | sort -q' \
    'x | grep -v a # then grep -q' \
    'x | grep -- -q')"
  run pipefail_walk <<<"$f"
  [ "$status" -eq 0 ] || { echo "$output"; false; }
  [[ $output == *'walked 1 files that set pipefail'* ]] || { echo "$output"; false; }
}

@test "the walk passes grep with a file argument, a counted grep, and a script without pipefail" {
  local f g
  f="$(pipefail_fixture pipefail "grep -q pipefail \"\$0\"" "n=\"\$(x | grep -c a)\"" "x | grep -e q")"
  g="$(pipefail_fixture nopipefail "x | grep -q a")"
  run pipefail_walk <<<"$(printf '%s\n' "$f" "$g")"
  [ "$status" -eq 0 ] || { echo "$output"; false; }
  [[ $output == *'walked 1 files that set pipefail'* ]] || { echo "$output"; false; }
}

@test "the walk follows a library that a pipefail script sources" {
  local lib main lib2 main2
  # The library sets no pipefail; it runs under the pipefail of its caller.
  lib="$(pipefail_fixture nopipefail 'x | grep -q a')"
  main="$(pipefail_fixture pipefail 'here=${0%/*}' ". \"\$here/${lib##*/}\" || exit 2")"
  # Listed before its caller, so the walk must look twice.
  run pipefail_walk <<<"$(printf '%s\n' "$lib" "$main")"
  [ "$status" -eq 1 ] || { echo "$output"; false; }
  [[ $output == *"walked: $lib"* ]] || { echo "$output"; false; }
  [[ $output == *"$lib:2: "* ]] || { echo "$output"; false; }
  [[ $output == *'walked 2 files'* ]] || { echo "$output"; false; }
  # The `source` spelling, and a library sourced by a library.
  lib2="$(pipefail_fixture nopipefail 'echo lib2' 'printf x | grep -q x')"
  lib="$(pipefail_fixture nopipefail "source \"${lib2##*/}\"")"
  main2="$(pipefail_fixture pipefail "source ./${lib##*/}")"
  run pipefail_walk <<<"$(printf '%s\n' "$lib2" "$lib" "$main2")"
  [ "$status" -eq 1 ] || { echo "$output"; false; }
  [[ $output == *"$lib2:3: "* ]] || { echo "$output"; false; }
  [[ $output == *'walked 3 files'* ]] || { echo "$output"; false; }
}

@test "the walk leaves alone a library that no pipefail script sources" {
  local lib main other
  lib="$(pipefail_fixture nopipefail 'x | grep -q a')"
  other="$(pipefail_fixture nopipefail 'echo other')"
  main="$(pipefail_fixture pipefail ". \"./${other##*/}\"")"
  run pipefail_walk <<<"$(printf '%s\n' "$lib" "$other" "$main")"
  [ "$status" -eq 0 ] || { echo "$output"; false; }
  [[ $output != *"walked: $lib"* ]] || { echo "$output"; false; }
  [[ $output == *'walked 2 files'* ]] || { echo "$output"; false; }
}

@test "the walk fails naming a listed file it cannot read" {
  local f missing="$BATS_TEST_TMPDIR/no-such-file.sh"
  f="$(pipefail_fixture pipefail 'echo fine')"
  run pipefail_walk <<<"$(printf '%s\n' "$f" "$missing")"
  [ "$status" -eq 1 ] || { echo "$output"; false; }
  [[ $output == *"cannot read $missing"* ]] || { echo "$output"; false; }
}

@test "the walk fails when awk fails" {
  local f stub="$BATS_TEST_TMPDIR/stub"
  mkdir "$stub"
  printf '%s\n' '#!/bin/sh' 'exit 2' > "$stub/awk"
  chmod +x "$stub/awk"
  f="$(pipefail_fixture pipefail 'echo fine')"
  PATH="$stub:$PATH" run pipefail_walk <<<"$f"
  [ "$status" -eq 1 ] || { echo "$output"; false; }
  [[ $output == *'awk failed (status 2)'* ]] || { echo "$output"; false; }
  # The scan's own awk: a stub that fails only when given `-v f=…`, which
  # only the scan passes, so the source finder runs and the scan fails.
  local real
  real="$(command -v awk)"
  printf '%s\n' '#!/bin/sh' 'case " $* " in *" f="*) exit 2 ;; esac' "exec \"$real\" \"\$@\"" > "$stub/awk"
  chmod +x "$stub/awk"
  PATH="$stub:$PATH" run pipefail_walk <<<"$f"
  [ "$status" -eq 1 ] || { echo "$output"; false; }
  [[ $output == *"awk failed (status 2) on $f"* ]] || { echo "$output"; false; }
}

@test "the walk fails when it walked no file" {
  local g
  g="$(pipefail_fixture nopipefail 'echo hi')"
  run pipefail_walk <<<"$g"
  [ "$status" -eq 1 ] || { echo "$output"; false; }
  [[ $output == *'no file that sets pipefail was walked'* ]] || { echo "$output"; false; }
  run pipefail_walk < /dev/null
  [ "$status" -eq 1 ] || { echo "$output"; false; }
}
