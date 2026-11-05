#!/usr/bin/env bash
# run-suite.sh — this repository's full suite, with its test files side by side.
#
#   bash scripts/run-suite.sh [<root>...]
#
# Run it from the repository root. The serial command in CONTRIBUTING.md runs
# the same files, one at a time. specs/057-repeated-serial-work/measurements.md
# holds the times. CI stays serial and sharded: its comment says why. This is
# what the pipeline's testCommand calls here, and no plugin ships it.
#
# Stdout is one TAP report: the roots as given, each sorted, whichever file ends
# first. The pipeline's `progress.sh tap-check` judges that report, and needs the
# plan line first and each number used once, while each bats process numbers from
# 1. So each file's output is held, its first plan line dropped, its test lines
# renumbered, and the plan printed first. That plan is the sum of what the files
# declared, so a short file also fails tap-check, by a second route. Renumbering
# and dropping the plan would hide a repeated number or a late plan from tap-check,
# so each file is checked for those first: these two rules are copied from
# progress.sh's TAP_AWK, and only because tap-check cannot see what this hides.
#
# The exit status is the verdict on what a serial run shows by itself, which
# running side by side must not hide: 0 green, 1 a red suite, 2 it could not
# run, 143 stopped. The rows are in
# specs/057-repeated-serial-work/contracts/run-suite.md. A `# skip` and a stray
# line are passed through for tap-check to refuse. Messages name a path only as
# given, because this output is kept and CI logs are public, and they follow the
# report: the pipeline keeps stdout and stderr in one file, and tap-check reads
# the plan as its first line.
#
# A file name holding a line feed is not supported: the list is one per line.
set -u

roots='tests handoff/tests pipeline/tests team/tests'

bin="${BATS_BIN:-${HOME:-}/bats/bin/bats}"

# One file, called by xargs as: run-suite.sh --run-one <work> <index>. The status
# always lands in a file and this always exits 0: xargs stops at a worker that
# fails hard, and a status file missing afterwards is its own fault. Each file has
# its own TMPDIR: suites with their own setup share the one they are given, and a
# serial run never had two of them at once.
if [ "${1:-}" = --run-one ] && [ "$#" -eq 3 ]; then
  work="$2"
  i="$3"
  f="$(cat "$work/$i.name")"
  mkdir "$work/$i.tmp"
  rc=0
  TMPDIR="$work/$i.tmp" bash "$bin" --print-output-on-failure "$f" > "$work/$i.tap" 2>&1 < /dev/null || rc=$?
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

# The roots are checked before a temporary folder exists. These would reach find
# as part of its expression: -delete is one.
for r in "$@"; do
  case "$r" in
    -* | '!' | '(' | ')' | ,)
      say "$r: a root must not read as a find expression"
      exit 2
      ;;
  esac
  if [ ! -d "$r" ]; then
    say "$r: not a folder"
    exit 2
  fi
done

work="$(mktemp -d "${TMPDIR:-/tmp}/dk-run-suite.XXXXXX" 2> /dev/null)" || {
  say 'could not make a temporary folder'
  exit 2
}

# A test can leave a read-only folder in its TMPDIR, so the bits go first, and a
# leftover must not turn a green run red with a machine path.
trap 'chmod -R u+rwx "$work" 2> /dev/null; rm -rf -- "$work" 2> /dev/null' EXIT

faults=''
verdict=0
stopping=0
reported=0
xargs_ended=0
err_saved=0
n=0
names=()
fault() {
  faults="${faults}run-suite: $*
"
  verdict=1
}

# The verdict on each file, then the report, then the messages. Printed on every
# outcome, a stop included, so a failing test's output is there to read and a stop
# shows which file was running. Only each file's first plan line is dropped, so a
# second one reaches tap-check. Only a line that starts as a numbered test line is
# renumbered: a `#` comment holding `ok 3` is left as it is, and so is anything
# else. A carriage return is stripped, as TAP_AWK does. Reads of a folder that
# something removed say nothing here: the missing status is the fault, and the
# message of a failed read would print the temporary folder's path. So the names
# are held here, not read back.
report() {
  local total=0 i f tapfile rc counts plans plan tests nonum badnum huge late
  reported=1
  set --
  i=0
  while [ "$i" -lt "$n" ]; do
    i=$((i + 1))
    f="${names[$i]}"
    tapfile="$work/$i.tap"
    if [ -f "$work/$i.rc" ]; then
      rc="$(cat "$work/$i.rc" 2> /dev/null)"
      if [ "$rc" != 0 ]; then fault "$f: exit status $rc"; fi
    elif [ "$stopping" -eq 0 ]; then
      fault "$f: left no exit status"
    fi
    if [ ! -f "$tapfile" ]; then continue; fi
    set -- "$@" "$tapfile"
    counts="$(awk -v BINMODE=3 '
      function num(v) {
        if (v !~ /^[0-9]+$/) nonum++
        else if ((v + 0) in seen) badnum++
        else seen[v + 0] = 1
      }
      { sub(/\r$/, "") }
      /^1[.][.][0-9]+$/ {
        plans++
        if (plans == 1) {
          if (seenline) late = 1
          p = substr($0, 4)
          if (length(p) > 9) huge = 1
          else plan = p + 0
        }
        next
      }
      /[^[:space:]]/ { seenline = 1 }
      /^ok / { tests++; num($2); next }
      /^not ok / { tests++; num($3); next }
      END {
        if (plans == 1 && !huge) for (v in seen) if (v + 0 < 1 || v + 0 > plan) badnum++
        printf "%d %d %d %d %d %d %d\n", plans, plan, tests, nonum, badnum, huge, late
      }
    ' "$tapfile" 2> /dev/null)" || counts='0 0 0 0 0 0 0'
    read -r plans plan tests nonum badnum huge late <<EOF
$counts
EOF
    if [ "$plans" -eq 0 ]; then
      if [ "$stopping" -eq 0 ]; then fault "$f: no plan line"; fi
    elif [ "$plans" -gt 1 ]; then
      fault "$f: $plans plan lines"
    elif [ "$huge" -ne 0 ]; then
      fault "$f: the plan line is too large to be real"
    elif [ "$tests" -ne "$plan" ]; then
      if [ "$stopping" -eq 0 ]; then fault "$f: $tests test line(s), plan says $plan"; fi
    fi
    if [ "$late" -ne 0 ]; then fault "$f: the plan line is not first"; fi
    if [ "$nonum" -gt 0 ]; then fault "$f: a test line has no number"; fi
    if [ "$badnum" -gt 0 ]; then fault "$f: a test number repeated or outside its plan"; fi
    total=$((total + plan))
  done

  if [ "$total" -eq 0 ] && [ "$stopping" -eq 0 ]; then fault 'no test ran'; fi

  printf '1..%s\n' "$total" || fault 'the report could not be written'
  if [ "$#" -gt 0 ]; then
    awk -v BINMODE=3 '
      { sub(/\r$/, "") }
      FNR == 1 { dropped = 0 }
      !dropped && /^1[.][.][0-9]+$/ { dropped = 1; next }
      /^ok [0-9]+( |$)/ { sub(/^ok [0-9]+/, "ok " (++t)); print; next }
      /^not ok [0-9]+( |$)/ { sub(/^not ok [0-9]+/, "not ok " (++t)); print; next }
      { print }
    ' "$@" 2> /dev/null || fault 'the report could not be written'
  fi
  printf '%s' "$faults" >&2
}

# xargs runs in a process group of its own, so a stop reaches the test processes
# too. TERM to the group, else to its own id, as progress.sh's base_stop does. A
# process that ignores TERM gets KILL after 3 s, because base_run_exit allows this
# script 8 s. A SIGKILL to this script itself cannot be trapped: its test files
# then run on, in their own group.
end_group() {
  local pid="$1" t=0
  kill -TERM -- "-$pid" 2> /dev/null || kill -TERM "$pid" 2> /dev/null || true
  while [ "$t" -lt 3 ] && kill -0 -- "-$pid" 2> /dev/null; do
    sleep 1
    t=$((t + 1))
  done
  kill -KILL -- "-$pid" 2> /dev/null || kill -KILL "$pid" 2> /dev/null || true
  { wait "$pid"; } 2> /dev/null || true
}

# `${!:-}` covers a stop in the gap between starting xargs and reading its id. The
# second TERM is ignored: the first has begun the stop. Once
# xargs has ended its id is no longer this script's to signal, and a report already
# printed is not printed again. stderr comes back first: the wait below silences it,
# and a trap runs inside that silence.
# shellcheck disable=SC2329 # called by the trap below
stop() {
  local pid
  trap '' TERM INT HUP
  stopping=1
  if [ "$err_saved" -eq 1 ]; then exec 2>&4; fi
  pid="${!:-}"
  if [ -n "$pid" ] && [ "$xargs_ended" -eq 0 ]; then end_group "$pid"; fi
  if [ "$reported" -eq 0 ]; then report; fi
  say 'stopped'
  exit 143
}
trap stop TERM INT HUP

# The files bats -r would find: on disk, so a new test file not yet committed
# runs. A walk over tracked files would skip it in silence.
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
    names[n]="$f"
    printf '%s\n' "$f" > "$work/$n.name"
    printf '%s\n' "$n" >> "$work/indexes"
  done < "$work/sorted"
done

# Half the CPUs, at least 2 and at most 8: 8 on 16 CPUs is what was measured
# green, and CI's comment warns that load pushes tests toward their 60 s timeout.
# nproc first, because it respects CPU affinity and getconf does not.
cpus="$(nproc 2> /dev/null)" || cpus=''
case "$cpus" in
  '' | *[!0-9]*)
    cpus="$(getconf _NPROCESSORS_ONLN 2> /dev/null)" || cpus=''
    case "$cpus" in '' | *[!0-9]*) cpus=4 ;; esac
    ;;
esac
jobs_at_once=$((10#$cpus / 2))
if [ "$jobs_at_once" -lt 2 ]; then jobs_at_once=2; fi
if [ "$jobs_at_once" -gt 8 ]; then jobs_at_once=8; fi

set -m
xargs -n 1 -P "$jobs_at_once" bash "$0" --run-one "$work" < "$work/indexes" > /dev/null 2>&1 &
xpid=$!
set +m
xrc=0
# Silent, because bash adds its own line when xargs dies by a signal, and the report
# must come first. Only here: fd 4 is opened after xargs started, so no test holds it.
exec 4>&2 2> /dev/null
err_saved=1
wait "$xpid" || xrc=$?
xargs_ended=1
exec 2>&4 4>&-
err_saved=0

if [ "$xrc" -ne 0 ]; then
  fault "xargs exit status $xrc"
  # An xargs that left at once leaves its workers running in the group.
  end_group "$xpid"
fi

report
exit "$verdict"
