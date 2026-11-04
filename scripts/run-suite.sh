#!/usr/bin/env bash
# run-suite.sh — this repository's full suite, with its test files side by side.
#
#   bash scripts/run-suite.sh [<root>...]
#
# Run it from the repository root. The serial command in CONTRIBUTING.md runs
# the same files, one at a time, and took 561 s where this took 81 to 97 s
# (16 CPUs; specs/057-repeated-serial-work/measurements.md). CI stays serial
# and sharded: its comment says why. This is what the pipeline's testCommand
# calls here, and no plugin ships it.
#
# Stdout is one TAP report, in sorted file order, whichever file ends first.
# The pipeline's `progress.sh tap-check` judges that report, and needs the plan
# line first and each number used once, while each bats process numbers from 1.
# So each file's output is held, its own plan line dropped, its test lines
# renumbered, and the plan printed first. That plan is the sum of what the files
# declared, so a short file also fails tap-check, by a second route.
#
# The exit status is the verdict on what a serial run shows by itself, which
# running side by side must not hide: 0 green, 1 a red suite, 2 it could not
# run, 143 stopped. The rows R1 to R13 are in
# specs/057-repeated-serial-work/contracts/run-suite.md. A `# skip` and a stray
# line are passed through for tap-check to refuse. Messages name a path only as
# given, because this output is kept and CI logs are public.
#
# A file name holding a line feed is not supported: the list is one per line.
set -u

roots='tests handoff/tests pipeline/tests team/tests'

bin="${BATS_BIN:-$HOME/bats/bin/bats}"

# One file, called by xargs as: run-suite.sh --run-one <work> <index>. The status
# always lands in a file and this always exits 0: xargs stops at a worker that
# fails hard, and a status file missing afterwards is its own fault (R7).
if [ "${1:-}" = --run-one ]; then
  work="$2"
  i="$3"
  f="$(cat "$work/$i.name")"
  rc=0
  bash "$bin" --print-output-on-failure "$f" > "$work/$i.tap" 2>&1 < /dev/null || rc=$?
  printf '%s\n' "$rc" > "$work/$i.rc"
  exit 0
fi

say() { printf 'run-suite: %s\n' "$*" >&2; }

if [ ! -f "$bin" ]; then
  say 'the test runner is missing: set BATS_BIN, or install bats as CONTRIBUTING.md says'
  exit 2
fi

if [ "$#" -eq 0 ]; then
  # shellcheck disable=SC2086 # roots is one space-separated line, split on purpose
  set -- $roots
fi

# The roots are checked before a temporary folder exists.
for r in "$@"; do
  if [ ! -d "$r" ]; then
    say "$r: not a folder"
    exit 2
  fi
done

work="$(mktemp -d "${TMPDIR:-/tmp}/dk-run-suite.XXXXXX" 2> /dev/null)" || {
  say 'could not make a temporary folder'
  exit 2
}

xpid=''
trap 'rm -rf -- "$work"' EXIT

# xargs runs in a process group of its own, so a stop reaches the test processes
# too. TERM to the group, else to its own id, as progress.sh's base_stop does.
# shellcheck disable=SC2329 # called by the trap below
stop() {
  trap - TERM INT
  if [ -n "$xpid" ]; then
    kill -TERM -- "-$xpid" 2> /dev/null || kill -TERM "$xpid" 2> /dev/null || true
    wait "$xpid" 2> /dev/null || true
  fi
  say 'stopped'
  exit 143
}
trap stop TERM INT

# The files bats -r would find: on disk, so a new test file not yet committed
# runs. A walk over tracked files would skip it in silence.
n=0
: > "$work/indexes"
for r in "$@"; do
  find -L "$r" -type f -name '*.bats' > "$work/found" 2> /dev/null || {
    say "$r: could not be read"
    exit 2
  }
  LC_ALL=C sort "$work/found" > "$work/sorted"
  if [ ! -s "$work/sorted" ]; then
    say "$r: holds no .bats file"
    exit 2
  fi
  while IFS= read -r f; do
    n=$((n + 1))
    printf '%s\n' "$f" > "$work/$n.name"
    printf '%s\n' "$n" >> "$work/indexes"
  done < "$work/sorted"
done

# At least 2 and at most 8: 8 is what was measured green on 16 CPUs, and CI's
# comment warns that load pushes tests toward their 60 s timeout.
jobs_at_once="$(getconf _NPROCESSORS_ONLN 2> /dev/null)" || jobs_at_once=''
case "$jobs_at_once" in
  '' | *[!0-9]*)
    jobs_at_once="$(nproc 2> /dev/null)" || jobs_at_once=''
    case "$jobs_at_once" in '' | *[!0-9]*) jobs_at_once=2 ;; esac
    ;;
esac
if [ "$jobs_at_once" -lt 2 ]; then jobs_at_once=2; fi
if [ "$jobs_at_once" -gt 8 ]; then jobs_at_once=8; fi

set -m
xargs -n 1 -P "$jobs_at_once" bash "$0" --run-one "$work" < "$work/indexes" > /dev/null 2>&1 &
xpid=$!
set +m
xrc=0
wait "$xpid" || xrc=$?
xpid=''

verdict=0
if [ "$xrc" -ne 0 ]; then
  say "xargs exit status $xrc"
  verdict=1
fi

# Each file's own account: exit status, plan lines, plan, test lines, and test
# lines with no number. BINMODE=3 as in progress.sh's TAP_AWK: a carriage return
# is kept, so a line it changes is not read as a plan or a test.
total=0
i=0
while [ "$i" -lt "$n" ]; do
  i=$((i + 1))
  f="$(cat "$work/$i.name")"
  tapfile="$work/$i.tap"
  if [ ! -f "$work/$i.rc" ]; then
    say "$f: left no exit status"
    verdict=1
    : >> "$tapfile"
    continue
  fi
  rc="$(cat "$work/$i.rc")"
  if [ "$rc" != 0 ]; then
    say "$f: exit status $rc"
    verdict=1
  fi
  counts="$(awk -v BINMODE=3 '
    /^1[.][.][0-9]+$/ { plans++; if (plans == 1) plan = substr($0, 4) + 0; next }
    /^ok / { tests++; if ($2 !~ /^[0-9]+$/) nonum++; next }
    /^not ok / { tests++; if ($3 !~ /^[0-9]+$/) nonum++; next }
    END { printf "%d %d %d %d\n", plans, plan, tests, nonum }
  ' "$tapfile")" || counts=''
  read -r plans plan tests nonum <<EOF
$counts
EOF
  if [ "${plans:-0}" -eq 0 ]; then
    say "$f: no plan line"
    verdict=1
  elif [ "$plans" -gt 1 ]; then
    say "$f: $plans plan lines"
    verdict=1
  elif [ "$tests" -ne "$plan" ]; then
    say "$f: $tests test line(s), plan says $plan"
    verdict=1
  fi
  if [ "${nonum:-0}" -gt 0 ]; then
    say "$f: a test line has no number"
    verdict=1
  fi
  total=$((total + ${plan:-0}))
done

if [ "$total" -eq 0 ]; then
  say 'no test ran'
  verdict=1
fi

# The report. Printed on every outcome, so a failing test's output is there to
# read. Only each file's first plan line is dropped, so a second one reaches
# tap-check. Only a line that starts as a numbered test line is renumbered: a
# `#` comment holding `ok 3` is left as it is, and so is anything else.
printf '1..%s\n' "$total"
i=0
set --
while [ "$i" -lt "$n" ]; do
  i=$((i + 1))
  set -- "$@" "$work/$i.tap"
done
awk -v BINMODE=3 '
  FNR == 1 { dropped = 0 }
  !dropped && /^1[.][.][0-9]+$/ { dropped = 1; next }
  /^ok [0-9]+( |$)/ { sub(/^ok [0-9]+/, "ok " (++t)); print; next }
  /^not ok [0-9]+( |$)/ { sub(/^not ok [0-9]+/, "not ok " (++t)); print; next }
  { print }
' "$@"

exit "$verdict"
