#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load helper

# Under `pipefail`, a pipe into `grep -q` is a race. grep -q leaves at its
# first match and closes the pipe; the program still writing into it can die
# of SIGPIPE, the pipeline then fails, and an `if` built on it takes the wrong
# branch — the more so the busier the machine. pipeline/scripts/preflight.sh's
# constitution NUL check did exactly this, and read a UTF-16 constitution as
# set in 30 of 400 runs on a loaded machine (feature 047). This walk refuses
# the shape in every shipped script that sets pipefail, found by walking the
# tracked files rather than by naming them.

# pipefail_walk — reads paths on stdin; for each file whose text holds
# `pipefail`, prints every line that pipes into grep with -q (alone or in a
# flag group) or --quiet, as <path>:<line>: <text>. Prints how many files it
# walked. Returns 1 on any such line, and on zero files walked: a walk that
# looked at nothing has proved nothing.
pipefail_walk() {
  local p n=0 bad=0 hits
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    grep -q 'pipefail' "$p" || continue
    n=$((n + 1))
    hits="$(awk -v f="$p" '
      /\|[ \t]*grep[ \t]+([^|]*[ \t])?(-[A-Za-z]*q[A-Za-z]*|--quiet)([ \t]|$)/ {
        print f ":" FNR ": " $0
      }' "$p")"
    if [ -n "$hits" ]; then
      printf '%s\n' "$hits"
      bad=1
    fi
  done
  printf 'walked %s files that set pipefail\n' "$n"
  [ "$n" -gt 0 ] || { echo 'no file that sets pipefail was walked'; return 1; }
  [ "$bad" -eq 0 ]
}

# A fixture script: `set -euo pipefail` (unless the first argument is
# `nopipefail`) and the given lines, written to a new file; prints its path.
pipefail_fixture() {
  local mode="$1"; shift
  local f
  f="$(mktemp "$BATS_TEST_TMPDIR/fx.XXXXXX")"
  { printf '%s\n' '#!/usr/bin/env bash'
    [ "$mode" = nopipefail ] || printf '%s\n' 'set -euo pipefail'
    printf '%s\n' "$@"; } > "$f"
  printf '%s\n' "$f"
}

@test "no shipped script that sets pipefail pipes into grep -q" {
  local list
  list="$(git -C "$ROOT" ls-files -- '*.sh' '*.bash' | grep -vE '^\.specify/|(^|/)tests/' || true)"
  run pipefail_walk <<<"$(printf '%s\n' "$list" | sed "s|^|$ROOT/|")"
  printf '%s\n' "$output"
  [ "$status" -eq 0 ] || { echo 'capture the output first, then match it: a reader that leaves early can kill the writer under pipefail'; false; }
  [[ $output == *'walked '*' files that set pipefail'* ]] || false
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

@test "the walk passes grep with a file argument, a counted grep, and a script without pipefail" {
  local f g
  f="$(pipefail_fixture pipefail "grep -q pipefail \"\$0\"" "n=\"\$(x | grep -c a)\"" "x | grep -e q")"
  g="$(pipefail_fixture nopipefail "x | grep -q a")"
  run pipefail_walk <<<"$(printf '%s\n' "$f" "$g")"
  [ "$status" -eq 0 ] || { echo "$output"; false; }
  [[ $output == *'walked 1 files that set pipefail'* ]] || { echo "$output"; false; }
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
