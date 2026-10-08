#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for progress.sh's commit mechanics: snapshot, spec-commit,
# piece-commit, late-commit, record-branch, guide, commit-list, metrics and
# state-set. Every test builds its own throwaway git repository under
# $BATS_TEST_TMPDIR, so no test sees another's state and nothing touches this
# repository's own tree.
#
# PROGRESS_SH_UNDER_TEST points the suite at another copy of the script. It
# exists for mutation runs: mutate a copy, point the suite at it, watch the
# matching test go red.

load ../../tests/helper

setup() {
  PROG="${PROGRESS_SH_UNDER_TEST:-$ROOT/pipeline/scripts/progress.sh}"
  [ -f "$PROG" ] || { echo "no script at $PROG"; return 1; }
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"
  cd "$WORK"
  # The developer's own git configuration must not reach these repositories:
  # a global or system autocrlf, signing, hooks path or default branch would
  # change what a commit holds. HOME and the system file are both cut off.
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export GIT_CONFIG_NOSYSTEM=1
  # HOME alone does not cut off every global file: git also reads
  # XDG_CONFIG_HOME and GIT_CONFIG_GLOBAL, and an identity in the environment
  # beats the repository's own.
  export XDG_CONFIG_HOME="$HOME/.config"
  export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
  F=001-demo
  SF=".delivery-kit/runs/$F/progress.json"
  TASKS=specs/001-demo/tasks.md
  MSG="$BATS_TEST_TMPDIR/msg.txt"
  OUT="$BATS_TEST_TMPDIR/out.txt"
  ERR="$BATS_TEST_TMPDIR/err.txt"
}

# repo — a repository whose main holds README.md and src/keep.sh, checked out
# on branch 001-demo, with an uncommitted spec directory and a state file that
# records the spec, the tasks file, base main and codeRoots ["src"].
repo() {
  git init -q .
  git symbolic-ref HEAD refs/heads/main
  git config user.name test
  git config user.email test@example.invalid
  git config commit.gpgsign false
  git config core.autocrlf false
  git config core.hooksPath "$BATS_TEST_TMPDIR/hooks"
  mkdir -p src specs/001-demo
  printf 'base\n' > README.md
  printf 'keep\n' > src/keep.sh
  git add README.md src/keep.sh
  git commit -q -m base
  git checkout -q -b 001-demo
  printf 'the spec\n' > specs/001-demo/spec.md
  printf '%s\n' '# Tasks' '' '## Phase 1: Setup' '' '- [ ] T001 first setup task' \
    '- [ ] T002 second setup task' '' '## Phase 2: Core' '' '- [ ] T003 the core task' > "$TASKS"
  bash "$PROG" init "$F" "$F" main other > /dev/null
  jq --arg t "$TASKS" '.artifacts = {spec: "specs/001-demo/spec.md", tasks: $t} | .config.codeRoots = ["src"]' \
    "$SF" > t.json
  mv t.json "$SF"
}

# mark <id...> — marks each task [X] in the tasks file.
mark() {
  local id
  for id in "$@"; do
    awk -v id="$id" '{ if (index($0, "- [ ] " id " ") == 1) $0 = "- [X] " substr($0, 7); print }' \
      "$TASKS" > "$BATS_TEST_TMPDIR/tasks.t"
    mv "$BATS_TEST_TMPDIR/tasks.t" "$TASKS"
  done
}

msg() { printf '%s\n' "$@" > "$MSG"; }

# runs <args...> — runs the script, stdout to $OUT, stderr to $ERR; exit 0.
runs() {
  local rc=0
  bash "$PROG" "$@" > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -eq 0 ] || { echo "exit $rc, expected 0: $(cat "$ERR")"; return 1; }
}

# refuses <fragment> <args...> — a refusal is proven only when all hold: a
# non-zero exit, the fragment on stderr, ZERO bytes on stdout, the state file
# byte-identical, and no new commit.
refuses() {
  local frag="$1" rc=0 head; shift
  cp "$SF" "$BATS_TEST_TMPDIR/before.json"
  head="$(git rev-parse HEAD)"
  bash "$PROG" "$@" > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -ne 0 ] || { echo "exit 0, expected a refusal naming: $frag"; cat "$ERR"; return 1; }
  [[ "$(cat "$ERR")" == *"$frag"* ]] || { echo "stderr lacks '$frag': $(cat "$ERR")"; return 1; }
  [ ! -s "$OUT" ] || { echo "a refusal printed on stdout: $(od -c "$OUT")"; return 1; }
  cmp "$BATS_TEST_TMPDIR/before.json" "$SF" || { echo "a refusal changed the state file"; return 1; }
  [ "$(git rev-parse HEAD)" = "$head" ] || { echo "a refusal made a commit"; return 1; }
}

# files_of <rev> — the files a commit touched, one per line, sorted.
files_of() { git diff-tree --no-commit-id --name-only -r --root "$1" | sort; }

last_entry() { jq -c '.commits[-1]' "$SF"; }

# msg_tail <n> — the last <n> lines of HEAD's message, exactly as stored:
# `git log --format=%B` adds a blank line of its own after a message.
msg_tail() { git cat-file commit HEAD | sed '1,/^$/d' | tail -n "$1"; }

# commit_by_hand <message> <path...> — a commit the run did not record.
commit_by_hand() {
  local m="$1"; shift
  printf '%s\n' "$m" > "$BATS_TEST_TMPDIR/hand.txt"
  git add -- "$@"
  git commit -q -F "$BATS_TEST_TMPDIR/hand.txt" -- "$@"
}

# --- snapshot -----------------------------------------------------------------

@test "snapshot piece saves the heading piece-next names and every path git status lists" {
  repo
  printf 'dirt\n' > dirt.txt
  runs snapshot "$F" piece
  [ ! -s "$OUT" ]
  [ "$(jq -r '.measurements.pieceBefore.piece' "$SF")" = "Phase 1: Setup" ]
  jq -e '.measurements.pieceBefore.paths | index("dirt.txt") and index("specs/001-demo/tasks.md")' "$SF"
  run bash "$PROG" validate "$F"
  [ "$status" -eq 0 ]
}

@test "snapshot piece keeps a list already saved for the same piece" {
  repo
  runs snapshot "$F" piece
  printf 'later\n' > later.txt
  runs snapshot "$F" piece
  [[ "$(cat "$ERR")" == *"the saved list stands"* ]]
  jq -e '.measurements.pieceBefore.paths | index("later.txt") | not' "$SF"
}

@test "snapshot late saves each path with its hash, deleted for a gone file, and --fresh saves afresh" {
  repo
  rm src/keep.sh
  printf 'new\n' > src/new.sh
  runs snapshot "$F" late H.7
  [ "$(jq -r '.measurements.lateBefore.phase' "$SF")" = "H.7" ]
  [ "$(jq -r '.measurements.lateBefore.paths[] | select(.path == "src/keep.sh") | .hash' "$SF")" = deleted ]
  [ "$(jq -r '.measurements.lateBefore.paths[] | select(.path == "src/new.sh") | .hash' "$SF")" = "$(git hash-object src/new.sh)" ]
  printf 'more\n' > src/more.sh
  runs snapshot "$F" late H.7
  [[ "$(cat "$ERR")" == *"the saved list stands"* ]]
  jq -e '[.measurements.lateBefore.paths[].path] | index("src/more.sh") | not' "$SF"
  # A --from saves afresh, less the paths the phase's failure entry names.
  jq '.gates["H.7"] = {failure: {paths: ["src/new.sh"], output: "hook said no"}}' "$SF" > t.json
  mv t.json "$SF"
  runs snapshot "$F" late H.7 --fresh
  jq -e '[.measurements.lateBefore.paths[].path] | (index("src/more.sh") != null) and (index("src/new.sh") == null)' "$SF"
}

@test "snapshot refuses a path holding a line feed" {
  repo
  git -c core.protectNTFS=false update-index --add --cacheinfo "100644,$(git hash-object -w README.md),$(printf 'two\nlines.txt')"
  refuses "carriage return or a line feed" snapshot "$F" piece
}

@test "snapshot refuses a phase that is not a late phase" {
  repo
  refuses "needs a late phase" snapshot "$F" late K
}

# --- piece-commit -------------------------------------------------------------

@test "piece-commit commits what the piece changed plus tasks.md, never a state path" {
  repo
  printf 'dirt\n' > dirt.txt
  printf 'saved\n' > src/ab.sh
  runs snapshot "$F" piece
  printf 'built\n' > src/a.sh
  # A path the saved list holds only as part of a longer one is new: the
  # list is matched line by line, never as a substring.
  printf 'built\n' > ab.sh
  printf 'state\n' > ".delivery-kit/runs/$F/extra.txt"
  mark T001 T002
  # Trailing spaces and a doubled blank line: the message is kept verbatim.
  msg 'feat: the setup piece' '' '' 'Builds T001 to T002.  '
  runs piece-commit "$F" "$MSG"
  [ "$(cat "$OUT")" = "$(git rev-parse HEAD)" ]
  [ "$(files_of HEAD)" = "$(printf '%s\n' ab.sh specs/001-demo/tasks.md src/a.sh | sort)" ]
  # Dirt from before the piece stays for K; the spec, listed before the piece
  # started, is not the piece's either.
  [ "$(git status --porcelain -- dirt.txt src/ab.sh)" = "$(printf '%s\n' '?? dirt.txt' '?? src/ab.sh')" ]
  [ "$(git cat-file commit HEAD | sed '1,/^$/d' | head -n 4)" = "$(printf '%s\n' 'feat: the setup piece' '' '' 'Builds T001 to T002.  ')" ]
  [ "$(msg_tail 2)" = "$(printf '%s\n' 'Tasks: T001,T002' 'Piece: Phase 1: Setup')" ]
  [ "$(last_entry)" = "{\"sha\":\"$(git rev-parse HEAD)\",\"kind\":\"piece\",\"piece\":\"Phase 1: Setup\",\"tasks\":[\"T001\",\"T002\"],\"files\":[\"ab.sh\",\"src/a.sh\",\"specs/001-demo/tasks.md\"]}" ]
  run bash "$PROG" piece-next "$F"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Phase 2: Core" ]
  # The next piece saves its own list: the first piece's never stands for it.
  runs snapshot "$F" piece
  [ "$(jq -r '.measurements.pieceBefore.piece' "$SF")" = "Phase 2: Core" ]
  jq -e '.measurements.pieceBefore.paths | index("dirt.txt") and (index("src/a.sh") | not)' "$SF"
}

@test "piece-commit --list prints the paths and commits nothing" {
  repo
  runs snapshot "$F" piece
  printf 'built\n' > src/a.sh
  mark T001 T002
  head="$(git rev-parse HEAD)"
  runs piece-commit "$F" --list
  [ "$(sort "$OUT")" = "$(printf '%s\n' specs/001-demo/tasks.md src/a.sh)" ]
  [ "$(git rev-parse HEAD)" = "$head" ]
}

@test "piece-commit names the tasks file as git does when artifacts records it absolute" {
  repo
  jq --arg t "$PWD/$TASKS" '.artifacts.tasks = $t' "$SF" > t.json
  mv t.json "$SF"
  runs snapshot "$F" piece
  printf 'built\n' > src/a.sh
  mark T001 T002
  runs piece-commit "$F" --list
  [ "$(sort "$OUT")" = "$(printf '%s\n' specs/001-demo/tasks.md src/a.sh)" ]
}

@test "piece-commit refuses a piece with a task not marked [X]" {
  repo
  runs snapshot "$F" piece
  printf 'built\n' > src/a.sh
  mark T001
  msg 'feat: the setup piece'
  refuses "T002 not marked [X]" piece-commit "$F" "$MSG"
}

@test "piece-commit refuses a piece with no saved list" {
  repo
  mark T001 T002
  msg 'feat: the setup piece'
  refuses "measurements.pieceBefore does not name 'Phase 1: Setup'" piece-commit "$F" "$MSG"
}

@test "piece-commit refuses a message carrying its own Piece line, a CR, or nothing" {
  repo
  runs snapshot "$F" piece
  mark T001 T002
  msg 'feat: x' '' 'Piece: Phase 2: Core'
  refuses "carries a 'Piece:' line" piece-commit "$F" "$MSG"
  msg 'feat: x' '' 'Late: H.5'
  refuses "carries a 'Late:' line" piece-commit "$F" "$MSG"
  msg 'feat: x' '' 'Tasks: T003'
  refuses "carries a 'Tasks:' line" piece-commit "$F" "$MSG"
  printf 'feat: x\r\n' > "$MSG"
  refuses "carriage return" piece-commit "$F" "$MSG"
  printf '\n\n' > "$MSG"
  refuses "is empty" piece-commit "$F" "$MSG"
}

@test "piece-commit refuses an empty path list and leaves what is staged alone" {
  repo
  # The tasks file under the state directory: the one path a piece always adds
  # is then never committable, so the list is empty.
  mkdir -p ".delivery-kit/runs/$F"
  cp "$TASKS" ".delivery-kit/runs/$F/tasks.md"
  TASKS=".delivery-kit/runs/$F/tasks.md"
  jq --arg t "$TASKS" '.artifacts.tasks = $t' "$SF" > t.json
  mv t.json "$SF"
  printf 'staged\n' > staged.txt
  git add staged.txt
  runs snapshot "$F" piece
  mark T001 T002
  msg 'feat: the setup piece'
  refuses "the path list is empty" piece-commit "$F" "$MSG"
  [ "$(git diff --cached --name-only)" = staged.txt ]
}

@test "piece-commit refuses a path holding a carriage return" {
  repo
  runs snapshot "$F" piece
  mark T001 T002
  git -c core.protectNTFS=false update-index --add --cacheinfo "100644,$(git hash-object -w README.md),$(printf 'cr\r.txt')"
  msg 'feat: the setup piece'
  refuses "carriage return or a line feed" piece-commit "$F" "$MSG"
}

@test "piece-commit reads no path as a pattern" {
  repo
  printf 'a\n' > a.txt
  printf 'b\n' > b.txt
  runs snapshot "$F" piece
  # Read as a glob, [ab].txt would also stage a.txt and b.txt, which the
  # saved list keeps for K.
  printf 'class\n' > '[ab].txt'
  printf 'dash\n' > -dash.txt
  mark T001 T002
  msg 'feat: the setup piece'
  runs piece-commit "$F" "$MSG"
  [ "$(files_of HEAD)" = "$(printf '%s\n' -dash.txt '[ab].txt' specs/001-demo/tasks.md | sort)" ]
  [ "$(git status --porcelain -- a.txt b.txt)" = "$(printf '%s\n' '?? a.txt' '?? b.txt')" ]
}

@test "piece-commit stops when a commit hook rejects the commit, recording nothing" {
  repo
  runs snapshot "$F" piece
  printf 'built\n' > src/a.sh
  mark T001 T002
  mkdir -p "$BATS_TEST_TMPDIR/hooks"
  printf '#!/bin/sh\necho "hook: no" >&2\nexit 1\n' > "$BATS_TEST_TMPDIR/hooks/pre-commit"
  chmod +x "$BATS_TEST_TMPDIR/hooks/pre-commit"
  msg 'feat: the setup piece'
  refuses "the commit was rejected" piece-commit "$F" "$MSG"
  [[ "$(cat "$ERR")" == *"hook: no"* ]]
}

@test "piece-commit records an unrecorded commit for the piece and never commits it again" {
  repo
  runs snapshot "$F" piece
  printf 'built\n' > src/a.sh
  mark T001 T002
  commit_by_hand "$(printf '%s\n' 'feat: the setup piece' '' 'Piece: Phase 1: Setup')" src/a.sh "$TASKS"
  made="$(git rev-parse HEAD)"
  msg 'feat: the setup piece'
  runs piece-commit "$F" "$MSG"
  [ "$(cat "$OUT")" = "$made" ]
  [ "$(git rev-parse HEAD)" = "$made" ]
  [[ "$(cat "$ERR")" == *"not built or committed again"* ]]
  [ "$(jq -r '.commits[-1] | "\(.sha) \(.kind) \(.piece) \(.tasks | join(","))"' "$SF")" = "$made piece Phase 1: Setup T001,T002" ]
}

@test "snapshot piece records an already committed piece instead of saving a list" {
  repo
  printf 'built\n' > src/a.sh
  mark T001 T002
  commit_by_hand "$(printf '%s\n' 'feat: setup' '' 'Piece: Phase 1: Setup' 'Late: H.5')" src/a.sh "$TASKS"
  made="$(git rev-parse HEAD)"
  runs snapshot "$F" piece
  [ "$(cat "$OUT")" = "$made" ]
  [ "$(jq -r '.commits[-1].kind' "$SF")" = converge ]
  jq -e '.measurements.pieceBefore == null' "$SF"
}

@test "a Piece line that only begins with the heading does not recover the piece" {
  repo
  printf 'built\n' > src/a.sh
  mark T001 T002
  commit_by_hand "$(printf '%s\n' 'feat: setup' '' 'Piece: Phase 1: Setup more')" src/a.sh "$TASKS"
  runs snapshot "$F" piece
  [ ! -s "$OUT" ]
  [ "$(jq -r '.measurements.pieceBefore.piece' "$SF")" = "Phase 1: Setup" ]
  [ "$(jq '.commits | length' "$SF")" -eq 0 ]
}

@test "a hand commit claiming a piece whose tasks are open is refused, never recorded" {
  # Measured before the guard: snapshot recorded this commit as the piece and
  # piece-next moved on, with T001 and T002 still open.
  repo
  printf 'tweak\n' >> README.md
  commit_by_hand "$(printf '%s\n' 'docs: tweak' '' 'Piece: Phase 1: Setup')" README.md
  made="$(git rev-parse HEAD)"
  refuses "T001,T002 not marked [X]" snapshot "$F" piece
  [[ "$(cat "$ERR")" == *"$made"* ]]
  msg 'feat: the setup piece'
  refuses "T001,T002 not marked [X]" piece-commit "$F" "$MSG"
  run bash "$PROG" piece-next "$F"
  [ "${lines[0]}" = "Phase 1: Setup" ]
}

# --- late-commit --------------------------------------------------------------

@test "late-commit commits what changed since the snapshot and leaves an outside untracked path" {
  repo
  printf 'dirty before\n' > src/dirty.sh
  printf 'still\n' > src/still.sh
  runs snapshot "$F" late H.7
  printf 'changed\n' >> src/keep.sh
  printf 'changed again\n' >> src/dirty.sh
  printf 'new\n' > src/new.sh
  printf 'outside\n' > outside.txt
  msg 'refactor: simplify'
  runs late-commit "$F" H.7 "$MSG"
  [ "$(cat "$OUT")" = "$(git rev-parse HEAD)" ]
  [ "$(files_of HEAD)" = "$(printf '%s\n' src/dirty.sh src/keep.sh src/new.sh)" ]
  [[ "$(cat "$ERR")" == *"left uncommitted for K"*"outside.txt"* ]]
  [ "$(msg_tail 1)" = "Late: H.7" ]
  [ "$(jq -r '.commits[-1].kind' "$SF")" = simplify ]
  # The next phase saves its own list: H.7's never stands for I.
  runs snapshot "$F" late I
  [ "$(jq -r '.measurements.lateBefore.phase' "$SF")" = I ]
}

@test "late-commit reads codeRoots as K does: root or root/, ./ and / stripped, every path for ., and only untracked paths stay" {
  repo
  jq '.config.codeRoots = ["./src/"]' "$SF" > t.json; mv t.json "$SF"
  mkdir -p srcx
  runs snapshot "$F" late H.7
  printf 'new\n' > src/new.sh
  printf 'sibling\n' > srcx/x.sh
  printf 'plan\n' > specs/001-demo/plan.md
  printf 'tracked\n' >> README.md
  printf 'outside\n' > outside.txt
  runs late-commit "$F" H.7 --list
  [ "$(sort "$OUT")" = "$(printf '%s\n' README.md specs/001-demo/plan.md src/new.sh | sort)" ]
  [[ "$(cat "$ERR")" == *"left uncommitted for K"*"outside.txt"* ]]
  [[ "$(cat "$ERR")" == *"left uncommitted for K"*"srcx/x.sh"* ]]
  jq '.config.codeRoots = ["."]' "$SF" > t.json; mv t.json "$SF"
  runs late-commit "$F" H.7 --list
  [ "$(sort "$OUT")" = "$(printf '%s\n' README.md outside.txt specs/001-demo/plan.md src/new.sh srcx/x.sh | sort)" ]
}

@test "late-commit refuses a path holding a line feed that appears after the snapshot" {
  repo
  runs snapshot "$F" late H.7
  git -c core.protectNTFS=false update-index --add --cacheinfo "100644,$(git hash-object -w README.md),$(printf 'two\nlines.txt')"
  msg 'refactor: simplify'
  refuses "carriage return or a line feed" late-commit "$F" H.7 "$MSG"
}

@test "late-commit makes no commit when the phase changed no file, and leaves the index alone" {
  repo
  printf 'staged\n' > staged.txt
  git add staged.txt
  runs snapshot "$F" late I
  head="$(git rev-parse HEAD)"
  msg 'fix: review'
  runs late-commit "$F" I "$MSG"
  [ ! -s "$OUT" ]
  [[ "$(cat "$ERR")" == *"I changed no file"* ]]
  [ "$(git rev-parse HEAD)" = "$head" ]
  [ "$(git diff --cached --name-only)" = staged.txt ]
}

@test "late-commit H.5 carries the Tasks and Piece lines of converge's phase" {
  repo
  bash "$PROG" commit-add "$F" piece "$(printf 'a%039d' 1)" "Phase 1: Setup" T001,T002 "$TASKS"
  bash "$PROG" commit-add "$F" piece "$(printf 'a%039d' 2)" "Phase 2: Core" T003 "$TASKS"
  runs snapshot "$F" late H.5
  printf '%s\n' '' '## Phase 3: Converge gaps' '' '- [X] T004 a gap' >> "$TASKS"
  printf 'gap\n' > src/gap.sh
  msg 'feat: close the gaps'
  runs late-commit "$F" H.5 "$MSG"
  [ "$(msg_tail 3)" = "$(printf '%s\n' 'Tasks: T004' 'Piece: Phase 3: Converge gaps' 'Late: H.5')" ]
  [ "$(jq -r '.commits[-1] | "\(.kind)|\(.piece)|\(.tasks | join(","))"' "$SF")" = "converge|Phase 3: Converge gaps|T004" ]
  run bash "$PROG" piece-next "$F"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "late-commit H.5 refuses converge's phase with a task not marked [X]" {
  repo
  bash "$PROG" commit-add "$F" piece "$(printf 'a%039d' 1)" "Phase 1: Setup" T001,T002 "$TASKS"
  bash "$PROG" commit-add "$F" piece "$(printf 'a%039d' 2)" "Phase 2: Core" T003 "$TASKS"
  runs snapshot "$F" late H.5
  printf '%s\n' '' '## Phase 3: Converge gaps' '' '- [ ] T004 a gap' >> "$TASKS"
  msg 'feat: close the gaps'
  refuses "T004 not marked [X]" late-commit "$F" H.5 "$MSG"
}

@test "late-commit refuses another phase's snapshot, a phase that is not late, and --record off J" {
  repo
  runs snapshot "$F" late H.7
  msg 'fix: review'
  refuses "measurements.lateBefore does not name I" late-commit "$F" I "$MSG"
  refuses "needs a late phase" late-commit "$F" K "$MSG"
  refuses "for phase J only" late-commit "$F" I "$MSG" --record
}

@test "late-commit J --record makes one empty record commit, with nothing staged riding along" {
  repo
  printf 'staged\n' > staged.txt
  git add staged.txt
  msg 'test: carry the accepted reds' '' 'One failure accepted at the cap.'
  runs late-commit "$F" J "$MSG" --record
  [ "$(cat "$OUT")" = "$(git rev-parse HEAD)" ]
  [ -z "$(files_of HEAD)" ]
  [ "$(msg_tail 1)" = "Late: J" ]
  [ "$(last_entry)" = "{\"sha\":\"$(git rev-parse HEAD)\",\"kind\":\"tests\",\"piece\":\"\",\"tasks\":[],\"files\":[]}" ]
  [ "$(git diff --cached --name-only)" = staged.txt ]
  # A re-entered J finds its record made and recorded: it prints that id, as
  # spec-commit does, and makes nothing.
  made="$(git rev-parse HEAD)"
  runs late-commit "$F" J "$MSG" --record
  [ "$(cat "$OUT")" = "$made" ]
  [ "$(git rev-parse HEAD)" = "$made" ]
  [ "$(jq '.commits | length' "$SF")" -eq 1 ]
}

@test "snapshot late records an unrecorded commit carrying the phase's Late line, and saves no list" {
  # A re-entered late phase finds its commit first, at the phase's start,
  # rather than redoing the phase.
  repo
  printf 'fix\n' > src/fix.sh
  commit_by_hand "$(printf '%s\n' 'refactor: simplify' '' 'Late: H.7')" src/fix.sh
  made="$(git rev-parse HEAD)"
  runs snapshot "$F" late H.7
  [ "$(cat "$OUT")" = "$made" ]
  [ "$(jq -r '.commits[-1] | "\(.sha) \(.kind)"' "$SF")" = "$made simplify" ]
  jq -e '.measurements.lateBefore == null' "$SF"
}

@test "a Late H.5 commit is refused when its piece has open tasks, is not in tasks.md, or is not the next piece" {
  # The three shapes measured before the guard: each was recorded as converge.
  repo
  printf 'tweak\n' >> README.md
  commit_by_hand "$(printf '%s\n' 'docs: tweak' '' 'Late: H.5' 'Piece: Phase 1: Setup')" README.md
  refuses "T001,T002 not marked [X]" record-branch "$F"
  msg 'feat: close the gaps'
  refuses "T001,T002 not marked [X]" late-commit "$F" H.5 "$MSG"
  mkdir -p "$BATS_TEST_TMPDIR/two"; cd "$BATS_TEST_TMPDIR/two"
  repo
  printf 'x\n' > src/x.sh
  commit_by_hand "$(printf '%s\n' 'feat: x' '' 'Late: H.5' 'Piece: Phase 9: Ghost')" src/x.sh
  refuses "is not a section of the tasks file" record-branch "$F"
  refuses "is not a section of the tasks file" snapshot "$F" late H.5
  mkdir -p "$BATS_TEST_TMPDIR/three"; cd "$BATS_TEST_TMPDIR/three"
  repo
  mark T003
  printf 'x\n' > src/x.sh
  commit_by_hand "$(printf '%s\n' 'feat: x' '' 'Late: H.5' 'Piece: Phase 2: Core')" src/x.sh "$TASKS"
  refuses "not the piece piece-next names ('Phase 1: Setup')" record-branch "$F"
}

@test "late-commit J --record is refused when J changed files: the record rides in J's own commit" {
  repo
  runs snapshot "$F" late J
  printf 'fixed\n' >> src/keep.sh
  msg 'test: carry the accepted reds'
  refuses "J changed files" late-commit "$F" J "$MSG" --record
}

@test "a recovered Late H.5 commit is recorded with its phase's task ids, by late-commit and by record-branch" {
  repo
  bash "$PROG" commit-add "$F" piece "$(printf 'a%039d' 1)" "Phase 1: Setup" T001,T002 "$TASKS"
  bash "$PROG" commit-add "$F" piece "$(printf 'a%039d' 2)" "Phase 2: Core" T003 "$TASKS"
  printf '%s\n' '' '## Phase 3: Converge gaps' '' '- [X] T004 a gap' '- [X] T005 another' >> "$TASKS"
  printf 'gap\n' > src/gap.sh
  commit_by_hand "$(printf '%s\n' 'feat: gaps' '' 'Piece: Phase 3: Converge gaps' 'Late: H.5')" src/gap.sh "$TASKS"
  cp "$SF" "$BATS_TEST_TMPDIR/two.json"
  msg 'feat: close the gaps'
  runs late-commit "$F" H.5 "$MSG"
  [ "$(jq -r '.commits[-1] | "\(.kind)|\(.piece)|\(.tasks | join(","))"' "$SF")" = "converge|Phase 3: Converge gaps|T004,T005" ]
  cp "$BATS_TEST_TMPDIR/two.json" "$SF"
  runs record-branch "$F"
  [ "$(jq -r '.commits[-1] | "\(.kind)|\(.piece)|\(.tasks | join(","))"' "$SF")" = "converge|Phase 3: Converge gaps|T004,T005" ]
}

@test "record-branch records J's empty record commit as kind tests" {
  repo
  msg 'test: the record'
  runs late-commit "$F" J "$MSG" --record
  made="$(git rev-parse HEAD)"
  jq '.commits = []' "$SF" > t.json; mv t.json "$SF"
  runs record-branch "$F"
  [ "$(cat "$OUT")" = "$made" ]
  [ "$(last_entry)" = "{\"sha\":\"$made\",\"kind\":\"tests\",\"piece\":\"\",\"tasks\":[],\"files\":[]}" ]
}

@test "late-commit records an unrecorded commit carrying its Late line and never makes it again" {
  repo
  printf 'fix\n' > src/fix.sh
  commit_by_hand "$(printf '%s\n' 'fix: review' '' 'Late: I')" src/fix.sh
  made="$(git rev-parse HEAD)"
  msg 'fix: review'
  runs late-commit "$F" I "$MSG"
  [ "$(cat "$OUT")" = "$made" ]
  [ "$(git rev-parse HEAD)" = "$made" ]
  [ "$(jq -r '.commits[-1] | "\(.sha) \(.kind) \(.files | join(","))"' "$SF")" = "$made review src/fix.sh" ]
}

# --- spec-commit --------------------------------------------------------------

@test "spec-commit commits the spec directory alone, once" {
  repo
  printf 'outside\n' > outside.txt
  printf 'ignored\n' > specs/001-demo/scratch.log
  printf 'specs/001-demo/scratch.log\n' > .git/info/exclude
  runs spec-commit "$F"
  [ "$(cat "$OUT")" = "$(git rev-parse HEAD)" ]
  [ "$(git log -1 --format=%B)" = "docs(spec): 001-demo" ]
  [ "$(files_of HEAD)" = "$(printf '%s\n' specs/001-demo/spec.md specs/001-demo/tasks.md)" ]
  [ "$(jq -r '.commits[-1].kind' "$SF")" = spec ]
  [ "$(git status --porcelain -- outside.txt)" = "?? outside.txt" ]
  head="$(git rev-parse HEAD)"
  # A new file in the spec directory does not make a second spec commit.
  printf 'plan\n' > specs/001-demo/plan.md
  runs spec-commit "$F"
  [ ! -s "$OUT" ]
  [[ "$(cat "$ERR")" == *"already recorded"* ]]
  [ "$(git rev-parse HEAD)" = "$head" ]
  [ "$(jq '[.commits[] | select(.kind == "spec")] | length' "$SF")" -eq 1 ]
}

@test "spec-commit makes no commit for a spec the owner committed" {
  repo
  commit_by_hand 'docs: the owner commits the spec' specs/001-demo/spec.md "$TASKS"
  head="$(git rev-parse HEAD)"
  runs spec-commit "$F"
  [ ! -s "$OUT" ]
  [[ "$(cat "$ERR")" == *"committed already"* ]]
  [ "$(git rev-parse HEAD)" = "$head" ]
}

@test "spec-commit records a spec commit already on the branch" {
  repo
  commit_by_hand 'docs(spec): 001-demo' specs/001-demo/spec.md "$TASKS"
  made="$(git rev-parse HEAD)"
  runs spec-commit "$F"
  [ "$(cat "$OUT")" = "$made" ]
  [ "$(git rev-parse HEAD)" = "$made" ]
  [ "$(jq -r '.commits[-1] | "\(.sha) \(.kind)"' "$SF")" = "$made spec" ]
}

@test "spec-commit refuses a recorded artefact that git ignores" {
  repo
  printf 'plan\n' > specs/001-demo/plan.md
  printf 'specs/001-demo/plan.md\n' > .git/info/exclude
  jq '.artifacts.plan = "specs/001-demo/plan.md"' "$SF" > t.json
  mv t.json "$SF"
  refuses "specs/001-demo/plan.md is ignored by git" spec-commit "$F"
}

# --- record-branch ------------------------------------------------------------

@test "record-branch records each unrecorded commit under its kind, oldest first" {
  repo
  commit_by_hand 'docs(spec): 001-demo' specs/001-demo/spec.md "$TASKS"
  s1="$(git rev-parse HEAD)"
  printf 'a\n' > src/a.sh
  mark T001 T002
  commit_by_hand "$(printf '%s\n' 'feat: setup' '' 'Piece: Phase 1: Setup')" src/a.sh "$TASKS"
  s2="$(git rev-parse HEAD)"
  printf 'b\n' >> src/a.sh
  commit_by_hand "$(printf '%s\n' 'refactor: simplify' '' 'Late: H.7')" src/a.sh
  s3="$(git rev-parse HEAD)"
  printf 'c\n' > notes.txt
  commit_by_hand 'chore: notes' notes.txt
  s4="$(git rev-parse HEAD)"
  runs record-branch "$F"
  [ "$(cat "$OUT")" = "$(printf '%s\n' "$s1" "$s2" "$s3" "$s4")" ]
  [ "$(jq -r '[.commits[] | "\(.kind):\(.piece):\(.tasks | join(","))"] | join(" ")' "$SF")" = "spec:: piece:Phase 1: Setup:T001,T002 simplify:: other::" ]
}

@test "record-branch stops on a Piece line for another piece, and on a commit with no file" {
  repo
  printf 'a\n' > src/a.sh
  commit_by_hand "$(printf '%s\n' 'feat: core' '' 'Piece: Phase 2: Core')" src/a.sh
  refuses "not the piece piece-next names ('Phase 1: Setup')" record-branch "$F"
  repo_two="$BATS_TEST_TMPDIR/two"
  mkdir -p "$repo_two"; cd "$repo_two"
  repo
  git commit -q --allow-empty -m 'chore: nothing'
  refuses "no file and no 'Late: J' line" record-branch "$F"
}

@test "record-branch records a commit of 800 files, past the Windows command-line limit" {
  # About 40,000 characters of paths: passed to jq as arguments, a native
  # Windows jq could not start, and the commit could never be recorded.
  repo
  local d=src/generated/components/module i=0
  mkdir -p "$d"
  while [ "$i" -lt 800 ]; do i=$((i + 1)); printf '%s\n' "$i" > "$d/file-number-$i.ts"; done
  git add -- src/generated
  git commit -q -m 'feat: generated'
  runs record-branch "$F"
  [ "$(cat "$OUT")" = "$(git rev-parse HEAD)" ]
  [ "$(jq '.commits[-1].files | length' "$SF")" -eq 800 ]
}

# --- commit-add --files-from --------------------------------------------------

# nul_paths <file> <count> — <count> synthetic paths, NUL-separated.
nul_paths() {
  local i=0
  while [ "$i" -lt "$2" ]; do i=$((i + 1)); printf 'src/generated/components/module/file-number-%04d.ts\0' "$i"; done > "$1"
}

@test "commit-add --files-from records 800 paths from a NUL-separated file, and again is the same entry" {
  repo
  nul_paths "$BATS_TEST_TMPDIR/files.nul" 800
  sha="$(printf 'a%039d' 1)"
  runs commit-add "$F" --files-from "$BATS_TEST_TMPDIR/files.nul" other "$sha" "" ""
  [ ! -s "$OUT" ]
  [ "$(jq '.commits[-1].files | length' "$SF")" -eq 800 ]
  [ "$(jq -r '.commits[-1].files[0]' "$SF")" = src/generated/components/module/file-number-0001.ts ]
  [ "$(jq -r '.commits[-1].files[799]' "$SF")" = src/generated/components/module/file-number-0800.ts ]
  runs commit-add "$F" --files-from "$BATS_TEST_TMPDIR/files.nul" other "$sha" "" ""
  [ "$(jq '.commits | length' "$SF")" -eq 1 ]
}

@test "commit-add --files-from refuses an empty path, an empty list for a kind that needs files, and extra paths" {
  repo
  sha="$(printf 'a%039d' 1)"
  printf 'a.txt\0\0b.txt\0' > "$BATS_TEST_TMPDIR/files.nul"
  refuses "the file list holds an empty path" commit-add "$F" --files-from "$BATS_TEST_TMPDIR/files.nul" other "$sha" "" ""
  : > "$BATS_TEST_TMPDIR/files.nul"
  refuses "a review entry needs the files it changed" commit-add "$F" --files-from "$BATS_TEST_TMPDIR/files.nul" review "$sha" "" ""
  printf 'a.txt\0' > "$BATS_TEST_TMPDIR/files.nul"
  refuses "takes no paths after" commit-add "$F" --files-from "$BATS_TEST_TMPDIR/files.nul" other "$sha" "" "" b.txt
  refuses "no file at" commit-add "$F" --files-from "$BATS_TEST_TMPDIR/missing.nul" other "$sha" "" ""
}

# --- guide --------------------------------------------------------------------

# guide_branch — three commits on the branch, recorded with awkward names:
# backtick runs, backticks at the edges, pipes, an em dash and an emoji.
guide_branch() {
  repo
  printf '1\n' > src/1.sh; commit_by_hand 'one' src/1.sh; G1="$(git rev-parse HEAD)"
  printf '2\n' > src/2.sh; commit_by_hand 'two' src/2.sh; G2="$(git rev-parse HEAD)"
  printf '3\n' > src/3.sh; commit_by_hand 'three' src/3.sh; G3="$(git rev-parse HEAD)"
  bash "$PROG" commit-add "$F" spec "$G1" "" "" 'a`b.md' '``x``' 'p|q.txt' '`edge' 'edge`' 'plain dir/with space.md'
  bash "$PROG" commit-add "$F" piece "$G2" 'Phase 1: Set`up` — 🎯 a|b' T001,T002,T010 specs/001-demo/tasks.md src/a.sh
  bash "$PROG" commit-add "$F" simplify "$G3" '``' "" 'x```y`z' '|'
}

@test "guide prints the table byte for byte as the reference builder does" {
  # The expected rows were produced by the hand-written builder this command
  # replaces, run on the same values, and compared byte for byte with this
  # command's output before being pinned here.
  guide_branch
  local r1 r2 r3
  r1='| spec |  |  | ``a`b.md``<br>``` ``x`` ```<br>`p\|q.txt`<br>`` `edge ``<br>`` edge` ``<br>`plain dir/with space.md` |'
  r2='| piece | ``Phase 1: Set`up` — 🎯 a\|b`` | T001, T002, T010 | `specs/001-demo/tasks.md`<br>`src/a.sh` |'
  r3='| simplify | ``` `` ``` |  | ````x```y`z````<br>`\|` |'
  printf '%s\n' 'Read this branch commit by commit, top to bottom: each row is one commit, oldest first.' '' \
    '| Commit | Kind | Piece | Task IDs | Files |' '|---|---|---|---|---|' \
    "| ${G1:0:7} $r1" "| ${G2:0:7} $r2" "| ${G3:0:7} $r3" > "$BATS_TEST_TMPDIR/expected.md"
  runs guide "$F"
  cmp "$BATS_TEST_TMPDIR/expected.md" "$OUT" || { diff "$BATS_TEST_TMPDIR/expected.md" "$OUT"; false; }
}

@test "guide refuses a carriage return in a cell" {
  repo
  printf '1\n' > src/1.sh; commit_by_hand 'one' src/1.sh
  bash "$PROG" commit-add "$F" other "$(git rev-parse HEAD)" "" "" "$(printf 'bad\rname.sh')"
  refuses "carriage return or a line feed" guide "$F"
}

@test "guide refuses a recorded commit not on the branch, and an unrecorded one on it" {
  repo
  bash "$PROG" commit-add "$F" other "$(printf 'b%039d' 7)" "" "" gone.sh
  refuses "which is not in main..HEAD" guide "$F"
  jq '.commits = []' "$SF" > t.json; mv t.json "$SF"
  printf '1\n' > src/1.sh; commit_by_hand 'one' src/1.sh
  refuses "are not recorded: run record-branch first" guide "$F"
}

@test "guide builds no guide for a run with an old-style entry, and says so" {
  repo
  jq '.commits = ["abc1234 feat: old"]' "$SF" > t.json; mv t.json "$SF"
  runs guide "$F"
  [ ! -s "$OUT" ]
  [[ "$(cat "$ERR")" == *"old-style string entry"* ]]
}

@test "guide says so for an old-style run before it reads the base, which such a run may not record" {
  repo
  jq '.commits = ["abc1234 feat: old"] | .baseBranch = "no-such-base"' "$SF" > t.json; mv t.json "$SF"
  runs guide "$F"
  [ ! -s "$OUT" ]
  [[ "$(cat "$ERR")" == *"old-style string entry"* ]]
}

@test "guide --parts gives file counts and writes the full guide in parts under the limit" {
  repo
  printf '1\n' > src/1.sh; commit_by_hand 'one' src/1.sh; a="$(git rev-parse HEAD)"
  printf '2\n' > src/2.sh; commit_by_hand 'two' src/2.sh; b="$(git rev-parse HEAD)"
  # Two rows of about 43 KB each: together past one comment's limit.
  jq --arg a "$a" --arg b "$b" '.commits = [
      {sha: $a, kind: "other", piece: "", tasks: [], files: [range(400) | "dir/" + ("x" * 90) + "-a\(.).txt"]},
      {sha: $b, kind: "other", piece: "", tasks: [], files: [range(400) | "dir/" + ("y" * 90) + "-b\(.).txt"]}]' \
    "$SF" > t.json
  mv t.json "$SF"
  runs guide "$F" --parts
  [ "$(tail -n 2 "$OUT")" = "$(printf '%s\n' "| ${a:0:7} | other |  |  | 400 files |" "| ${b:0:7} | other |  |  | 400 files |")" ]
  d=".delivery-kit/runs/$F/guide-parts"
  # One assertion a line: errexit fires only on the last command of an && list.
  [ -f "$d/guide-1.md" ]
  [ -f "$d/guide-2.md" ]
  [ ! -e "$d/guide-3.md" ]
  [ ! -e "$d/guide-0.md" ]
  for p in "$d"/guide-*.md; do
    [ "$(wc -c < "$p")" -le 65000 ]
    [ "$(head -n 1 "$p")" = 'Read this branch commit by commit, top to bottom: each row is one commit, oldest first.' ]
  done
  [ "$(cat "$d"/guide-*.md | grep -o '\.txt`' | wc -l)" -eq 800 ]
}

@test "guide --parts refuses a single row past the limit rather than drop files" {
  repo
  printf '1\n' > src/1.sh; commit_by_hand 'one' src/1.sh; a="$(git rev-parse HEAD)"
  jq --arg a "$a" '.commits = [{sha: $a, kind: "other", piece: "", tasks: [], files: [range(700) | "dir/" + ("x" * 90) + "-\(.).txt"]}]' \
    "$SF" > t.json
  mv t.json "$SF"
  refuses "one row of the guide alone passes" guide "$F" --parts
}

# --- drop-stale ---------------------------------------------------------------

@test "drop-stale removes only the entries for commits not on the branch" {
  repo
  printf '1\n' > src/1.sh; commit_by_hand 'one' src/1.sh; on="$(git rev-parse HEAD)"
  bash "$PROG" commit-add "$F" other "$on" "" "" src/1.sh
  gone="$(printf 'b%039d' 7)"
  bash "$PROG" commit-add "$F" other "$gone" "" "" gone.sh
  jq '.commits += ["abc1234 feat: old"]' "$SF" > t.json; mv t.json "$SF"
  runs drop-stale "$F"
  [ "$(cat "$OUT")" = "$gone" ]
  [ "$(jq -c '[.commits[] | if type == "object" then .sha else . end]' "$SF")" = "[\"$on\",\"abc1234 feat: old\"]" ]
  run bash "$PROG" validate "$F"
  [ "$status" -eq 0 ]
}

@test "drop-stale changes nothing when every entry is on the branch" {
  repo
  printf '1\n' > src/1.sh; commit_by_hand 'one' src/1.sh
  bash "$PROG" commit-add "$F" other "$(git rev-parse HEAD)" "" "" src/1.sh
  cp "$SF" "$BATS_TEST_TMPDIR/before.json"
  runs drop-stale "$F"
  [ ! -s "$OUT" ]
  [[ "$(cat "$ERR")" == *"nothing removed"* ]]
  cmp "$BATS_TEST_TMPDIR/before.json" "$SF"
}

# --- commit-list --------------------------------------------------------------

@test "commit-list shows each commit's message and files, then the remainder, marked in or out" {
  repo
  printf 'a\n' > src/a.sh
  commit_by_hand "$(printf '%s\n' 'feat: a' '' 'Piece: Phase 1: Setup')" src/a.sh
  sha="$(git rev-parse HEAD)"
  printf 'docs\n' > NOTES.md
  printf 'more\n' >> src/keep.sh
  runs commit-list "$F"
  out="$(cat "$OUT")"
  [[ "$out" == "codeRoots: 'src'"* ]]
  [[ "$out" == *"commit 1: $sha"$'\n'"  message:"$'\n'"    feat: a"$'\n'"    "$'\n'"    Piece: Phase 1: Setup"$'\n'"  files:"$'\n'"    - src/a.sh"* ]]
  [[ "$out" == *$'uncommitted:\n'*"  ! NOTES.md"* ]]
  [[ "$out" == *"  - src/keep.sh"* ]]
  [[ "$out" != *".delivery-kit/"* ]]
}

@test "commit-list stops on a commit with no file and no Late J line, and shows J's record" {
  repo
  msg 'test: the record'
  runs late-commit "$F" J "$MSG" --record
  runs commit-list "$F"
  [[ "$(cat "$OUT")" == *"(none: J's record of a waved-through red)"* ]]
  git commit -q --allow-empty -m 'chore: nothing'
  refuses "no file and no 'Late: J' line" commit-list "$F"
}

@test "commit-list lists commits oldest first and marks a committed path outside the feature" {
  repo
  printf 'a\n' > src/a.sh; commit_by_hand 'feat: a' src/a.sh; c1="$(git rev-parse HEAD)"
  printf 'n\n' > NOTES.md; commit_by_hand 'docs: notes' NOTES.md; c2="$(git rev-parse HEAD)"
  runs commit-list "$F"
  out="$(cat "$OUT")"
  [[ "$out" == *"commit 1: $c1"*"commit 2: $c2"* ]]
  [[ "$out" == *$'\n'"    - src/a.sh"$'\n'* ]]
  [[ "$out" == *$'\n'"    ! NOTES.md"$'\n'* ]]
}

@test "a merge on the branch is walked by its first parent: record-branch, guide and commit-list, and an explicit base" {
  repo
  printf 'a\n' > src/a.sh; commit_by_hand 'feat: a' src/a.sh; c1="$(git rev-parse HEAD)"
  git checkout -q -b side
  printf 's\n' > src/side.sh; commit_by_hand 'feat: side' src/side.sh; side="$(git rev-parse HEAD)"
  git checkout -q 001-demo
  printf 'b\n' > src/b.sh; commit_by_hand 'feat: b' src/b.sh; c2="$(git rev-parse HEAD)"
  git merge -q --no-ff -m 'merge side' side
  m="$(git rev-parse HEAD)"
  runs record-branch "$F"
  [ "$(cat "$OUT")" = "$(printf '%s\n' "$c1" "$c2" "$m")" ]
  # The merge's files are what it brought onto the first-parent line.
  [ "$(jq -c '.commits[-1].files' "$SF")" = '["src/side.sh"]' ]
  runs guide "$F"
  [ "$(grep -c '^| [0-9a-f]\{7\} | other |' "$OUT")" -eq 3 ]
  [[ "$(cat "$OUT")" != *"${side:0:7}"* ]]
  runs commit-list "$F"
  [[ "$(cat "$OUT")" == *"commit 3: $m"* ]]
  [[ "$(cat "$OUT")" != *"$side"* ]]
  runs commit-list "$F" "$c2"
  [[ "$(cat "$OUT")" == *"commit 1: $m"* ]]
  [[ "$(cat "$OUT")" != *"commit 2:"* ]]
}

# accept <gate> <path> — records the pre-flight offer as accepted, with the
# hash of the file as the offer wrote it.
accept() {
  jq --arg g "$1" --arg h "$(git hash-object -- "$2")" '.gates[$g] = {accepted: true, hash: $h}' "$SF" > t.json
  mv t.json "$SF"
}

@test "commit-list marks .gitignore and the constitution inside only for an accepted offer they still match" {
  repo
  # Every root: without the rule both files would be inside.
  jq '.config.codeRoots = ["."]' "$SF" > t.json; mv t.json "$SF"
  mkdir -p .specify/memory
  printf 'principles\n' > .specify/memory/constitution.md
  printf '.delivery-kit/\n' > .gitignore
  printf 'more\n' >> README.md
  runs commit-list "$F"
  out="$(cat "$OUT")"
  [[ "$out" == *$'\n'"  - README.md"$'\n'* ]]
  [[ "$out" == *$'\n'"  ! .gitignore"$'\n'* ]]
  [[ "$out" == *$'\n'"  ! .specify/memory/constitution.md"$'\n'* ]]
  # A string "true" is not an accepted offer.
  jq --arg h "$(git hash-object .gitignore)" '.gates.gitignore = {accepted: "true", hash: $h}' "$SF" > t.json; mv t.json "$SF"
  runs commit-list "$F"
  [[ "$(cat "$OUT")" == *$'\n'"  ! .gitignore"$'\n'* ]]
  accept gitignore .gitignore
  accept constitution .specify/memory/constitution.md
  runs commit-list "$F"
  out="$(cat "$OUT")"
  [[ "$out" == *$'\n'"  - .gitignore"$'\n'* ]]
  [[ "$out" == *$'\n'"  - .specify/memory/constitution.md"$'\n'* ]]
  # Changed after the offer wrote it: no longer what the offer wrote.
  printf 'and more\n' >> .specify/memory/constitution.md
  commit_by_hand 'chore: ignore the state' .gitignore
  runs commit-list "$F"
  out="$(cat "$OUT")"
  [[ "$out" == *$'\n'"    - .gitignore"$'\n'* ]]
  [[ "$out" == *$'\n'"  ! .specify/memory/constitution.md"$'\n'* ]]
}

# --- remainder-commit ---------------------------------------------------------

@test "remainder-commit commits every uncommitted path but the state directory, as kind other, once" {
  repo
  printf 'note\n' > NOTES.md
  printf 'more\n' >> src/keep.sh
  printf 'state\n' > ".delivery-kit/runs/$F/extra.txt"
  want="$(printf '%s\n' NOTES.md specs/001-demo/spec.md specs/001-demo/tasks.md src/keep.sh | sort)"
  runs remainder-commit "$F" --list
  [ "$(sort "$OUT")" = "$want" ]
  msg 'chore: the rest of the feature'
  runs remainder-commit "$F" "$MSG"
  [ "$(cat "$OUT")" = "$(git rev-parse HEAD)" ]
  [ "$(files_of HEAD)" = "$want" ]
  [ "$(msg_tail 1)" = 'chore: the rest of the feature' ]
  [ "$(jq -r '.commits[-1] | "\(.kind) \(.files | length)"' "$SF")" = "other 4" ]
  head="$(git rev-parse HEAD)"
  runs remainder-commit "$F" "$MSG"
  [ ! -s "$OUT" ]
  [[ "$(cat "$ERR")" == *"nothing is left uncommitted"* ]]
  [ "$(git rev-parse HEAD)" = "$head" ]
}

@test "remainder-commit gives an accepted constitution its own commit, kind constitution, outside the remainder" {
  repo
  mkdir -p .specify/memory
  printf 'principles\n' > .specify/memory/constitution.md
  printf 'note\n' > NOTES.md
  msg 'docs: the constitution'
  refuses "records no accepted pre-flight offer" remainder-commit "$F" "$MSG" --kind constitution
  # Unaccepted, the constitution is part of the remainder.
  runs remainder-commit "$F" --list
  [ "$(grep -cxF -- .specify/memory/constitution.md "$OUT")" -eq 1 ]
  accept constitution .specify/memory/constitution.md
  runs remainder-commit "$F" --list
  [ "$(grep -cxF -- .specify/memory/constitution.md "$OUT")" -eq 0 ]
  runs remainder-commit "$F" --list --kind constitution
  [ "$(cat "$OUT")" = .specify/memory/constitution.md ]
  runs remainder-commit "$F" "$MSG" --kind constitution
  [ "$(files_of HEAD)" = .specify/memory/constitution.md ]
  [ "$(jq -r '.commits[-1].kind' "$SF")" = constitution ]
  [ "$(git status --porcelain -- NOTES.md)" = "?? NOTES.md" ]
  refuses "unknown kind 'piece'" remainder-commit "$F" "$MSG" --kind piece
}

@test "remainder-commit refuses a message carrying its own Late line, and stops on a rejecting hook" {
  repo
  printf 'note\n' > NOTES.md
  msg 'chore: x' '' 'Late: J'
  refuses "carries a 'Late:' line" remainder-commit "$F" "$MSG"
  mkdir -p "$BATS_TEST_TMPDIR/hooks"
  printf '#!/bin/sh\nexit 1\n' > "$BATS_TEST_TMPDIR/hooks/pre-commit"
  chmod +x "$BATS_TEST_TMPDIR/hooks/pre-commit"
  msg 'chore: x'
  refuses "the commit was rejected" remainder-commit "$F" "$MSG"
}

# --- the state directory in other letter case -----------------------------------

@test "a state directory spelled in other letter case is never committed or listed" {
  # Made before the run's own directory: on a file system that ignores case
  # the run then writes into it, and git lists it under this spelling.
  mkdir -p .Delivery-Kit
  repo
  runs spec-commit "$F"
  runs snapshot "$F" piece
  printf 'stray\n' > .Delivery-Kit/stray.txt
  printf 'built\n' > src/a.sh
  mark T001 T002
  msg 'feat: the setup piece'
  runs piece-commit "$F" "$MSG"
  [ "$(git log --name-only --format= main..HEAD | grep -ci '^\.delivery-kit/')" -eq 0 ]
  runs snapshot "$F" late H.7
  printf 'stray two\n' > .Delivery-Kit/stray2.txt
  runs late-commit "$F" H.7 --list
  [ "$(grep -ci '^\.delivery-kit/' "$OUT")" -eq 0 ]
  runs remainder-commit "$F" --list
  [ "$(grep -ci '^\.delivery-kit/' "$OUT")" -eq 0 ]
  runs commit-list "$F"
  [ "$(grep -ci 'delivery-kit/' "$OUT")" -eq 0 ]
}

# --- cost ---------------------------------------------------------------------

@test "400 dirty paths cost no process each: snapshot late, late-commit --list and commit-list stay quick" {
  # Measured before: about 0.3 s a path on Windows, a fork for each hash and
  # each mark — over a minute here. The hashes must still be each path's own.
  repo
  local i=0
  mkdir -p vendor src/gen
  while [ "$i" -lt 400 ]; do
    i=$((i + 1))
    if [ $((i % 2)) -eq 0 ]; then printf 'x%s\n' "$i" > "src/gen/f-$i.ts"; else printf 'y%s\n' "$i" > "vendor/u-$i.bin"; fi
  done
  git init -q nested
  rm src/keep.sh
  local t0=$SECONDS
  runs snapshot "$F" late H.7
  printf 'z\n' >> src/gen/f-2.ts
  runs late-commit "$F" H.7 --list
  [ "$(cat "$OUT")" = src/gen/f-2.ts ]
  runs commit-list "$F"
  [ $((SECONDS - t0)) -lt 30 ]
  [ "$(grep -c '^  - src/gen/' "$OUT")" -eq 200 ]
  [ "$(grep -c '^  ! vendor/' "$OUT")" -eq 200 ]
  for p in src/gen/f-4.ts src/gen/f-400.ts vendor/u-1.bin vendor/u-399.bin; do
    [ "$(jq -r --arg p "$p" '.measurements.lateBefore.paths[] | select(.path == $p) | .hash' "$SF")" = "$(git hash-object -- "$p")" ] || { echo "hash differs: $p"; false; }
  done
  [ "$(jq -r '.measurements.lateBefore.paths[] | select(.path == "src/keep.sh") | .hash' "$SF")" = deleted ]
  [ "$(jq -r '.measurements.lateBefore.paths[] | select(.path == "nested/") | .hash' "$SF")" = unhashable ]
}

# --- metrics ------------------------------------------------------------------

@test "metrics derives the run file, keeps the orchestrator's keys, and is idempotent" {
  repo
  jq '.timestamps = {B: {started: "2026-10-06T10:00:00Z", done: "2026-10-06T10:05:30Z"}}
      | .analyze_changelog = [{iteration: 1}, {iteration: 2}]' "$SF" > t.json
  mv t.json "$SF"
  bash "$PROG" commit-add "$F" spec "$(printf 'c%039d' 1)" "" "" a.md
  runs metrics "$F"
  M=".delivery-kit/runs/$F/pipeline-run.json"
  [ "$(cat "$OUT")" = "$M" ]
  [ "$(jq -r '.phases.B.seconds' "$M")" = 330 ]
  [ "$(jq -c '.commits' "$M")" = '{"total":1,"by_kind":{"spec":1}}' ]
  [ "$(jq -r '.analyze_iterations' "$M")" = 2 ]
  jq '.agents_dispatched = {F: 3}' "$M" > t.json; mv t.json "$M"
  runs metrics "$F"
  cp "$M" "$BATS_TEST_TMPDIR/first.json"
  runs metrics "$F"
  cmp "$BATS_TEST_TMPDIR/first.json" "$M"
  [ "$(jq -c '.agents_dispatched' "$M")" = '{"F":3}' ]
  # A derived key is rewritten from the state file, never kept from the old run file.
  bash "$PROG" commit-add "$F" other "$(printf 'c%039d' 2)" "" "" b.md
  runs metrics "$F"
  [ "$(jq -c '.commits' "$M")" = '{"total":2,"by_kind":{"other":1,"spec":1}}' ]
  printf '[1]' > "$M"
  run bash "$PROG" metrics "$F"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not one JSON object"* ]]
  [ "$(cat "$M")" = '[1]' ]
}

# --- state-set ----------------------------------------------------------------

@test "state-set writes a whole key, or one member of it, and prints nothing" {
  repo
  runs state-set "$F" gates '{"G": {"answer": "claude", "reviewMode": "commits"}}'
  [ ! -s "$OUT" ]
  [ "$(jq -c '.gates' "$SF")" = '{"G":{"answer":"claude","reviewMode":"commits"}}' ]
  runs state-set "$F" gates K '{"answer": "auto"}'
  [ "$(jq -c '.gates' "$SF")" = '{"G":{"answer":"claude","reviewMode":"commits"},"K":{"answer":"auto"}}' ]
  runs state-set "$F" test_baseline '"12 passed, 1 failed"'
  [ "$(jq -r '.test_baseline' "$SF")" = "12 passed, 1 failed" ]
  run bash "$PROG" validate "$F"
  [ "$status" -eq 0 ]
}

@test "state-set refuses a key it does not own, invalid JSON, and the wrong type" {
  repo
  refuses "does not write 'commits'" state-set "$F" commits '[]'
  refuses "does not write 'current_phase'" state-set "$F" current_phase '"DONE"'
  refuses "does not write 'feature'" state-set "$F" feature '"x"'
  refuses "not one valid JSON document" state-set "$F" gates '{"G": '
  refuses "not one valid JSON document" state-set "$F" gates '{} {}'
  refuses "must be a JSON object" state-set "$F" gates '"claude"'
  refuses "has no sub-keys" state-set "$F" last_task K '"T001"'
}

# A write that fails inside the subshell a commit command records from must
# still let go of the state lock: a subshell does not run its parent's EXIT
# trap, and a lock left behind makes every later write wait, then refuse.
@test "a commit whose recording fails inside its subshell leaves no state lock behind" {
  repo
  local shim="$BATS_TEST_TMPDIR/jqshim" real
  real="$(command -v jq)"
  mkdir "$shim"
  printf '%s\n' '#!/bin/bash' \
    'for a in "$@"; do case "$a" in *".commits += [entry]"*) exit 5 ;; esac; done' \
    "exec '$real' \"\$@\"" > "$shim/jq"
  chmod +x "$shim/jq"
  printf 'note\n' > NOTES.md
  msg 'chore: the rest of the feature'
  local rc=0
  PATH="$shim:$PATH" bash "$PROG" remainder-commit "$F" "$MSG" > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -ne 0 ] || { echo "the recording did not fail: the test proves nothing"; false; }
  [[ "$(cat "$ERR")" == *"is made but not recorded"* ]] || { echo "unexpected failure: $(cat "$ERR")"; false; }
  [ ! -e "$SF.lock" ] || { echo "the failed recording left $SF.lock behind"; false; }
}

# --- commit trailers ------------------------------------------------------------
# Feature 042. Every commit the run makes carries the trailers the run
# recorded in config.commitTrailers: each subcommand adds them through the one
# shared path, read from the state file as data.

# trailers <json> — records the run's trailer list, as the orchestrator does.
trailers() { runs state-set "$F" config commitTrailers "$1"; }

# body — HEAD's whole message, exactly as stored.
body() { git cat-file commit HEAD | sed '1,/^$/d'; }

@test "trailers: spec-commit carries them after its subject, which stays exact" {
  repo
  trailers '["Plan-Item: DEPENDENCY-02","Reviewed-by: a-reviewer"]'
  runs spec-commit "$F"
  [ "$(body)" = "$(printf '%s\n' 'docs(spec): 001-demo' '' 'Plan-Item: DEPENDENCY-02' 'Reviewed-by: a-reviewer')" ]
  [ "$(jq -r '.commits[-1].kind' "$SF")" = spec ]
}

@test "trailers: piece-commit joins them to its Tasks and Piece lines, the body kept byte for byte" {
  repo
  trailers '["Plan-Item: DEPENDENCY-02","Reviewed-by: a-reviewer"]'
  runs snapshot "$F" piece
  printf 'built\n' > src/a.sh
  mark T001 T002
  # Trailing spaces, a doubled blank line and a `---` line: the body is kept
  # as written, and the `---` line does not end the message.
  msg 'feat: the setup piece' '' '' 'Builds T001 to T002.  ' '---' 'after the line'
  runs piece-commit "$F" "$MSG"
  [ "$(body)" = "$(printf '%s\n' 'feat: the setup piece' '' '' 'Builds T001 to T002.  ' '---' 'after the line' '' \
    'Tasks: T001,T002' 'Piece: Phase 1: Setup' 'Plan-Item: DEPENDENCY-02' 'Reviewed-by: a-reviewer')" ]
  [ "$(jq -r '.commits[-1].piece' "$SF")" = "Phase 1: Setup" ]
  run bash "$PROG" piece-next "$F"
  [ "$status" -eq 0 ] || { echo "piece-next failed: $output"; false; }
  [ "${lines[0]}" = "Phase 2: Core" ]
}

@test "trailers: late-commit carries them after its Late line" {
  repo
  trailers '["Plan-Item: DEPENDENCY-02"]'
  runs snapshot "$F" late H.7
  printf 'changed\n' >> src/keep.sh
  msg 'refactor: simplify'
  runs late-commit "$F" H.7 "$MSG"
  [ "$(body)" = "$(printf '%s\n' 'refactor: simplify' '' 'Late: H.7' 'Plan-Item: DEPENDENCY-02')" ]
  [ "$(jq -r '.commits[-1].kind' "$SF")" = simplify ]
}

@test "trailers: J's empty record commit carries them, and is still read as J's record" {
  repo
  trailers '["Plan-Item: DEPENDENCY-02"]'
  msg 'test: carry the accepted reds'
  runs late-commit "$F" J "$MSG" --record
  made="$(git rev-parse HEAD)"
  [ -z "$(files_of HEAD)" ]
  [ "$(body)" = "$(printf '%s\n' 'test: carry the accepted reds' '' 'Late: J' 'Plan-Item: DEPENDENCY-02')" ]
  # A re-entered J still finds its record by the whole `Late: J` line.
  runs late-commit "$F" J "$MSG" --record
  [ "$(cat "$OUT")" = "$made" ]
  [ "$(git rev-parse HEAD)" = "$made" ]
  # An unrecorded copy, as after a crash, is still read as kind tests.
  jq '.commits = []' "$SF" > t.json && mv t.json "$SF"
  runs record-branch "$F"
  [ "$(jq -r '.commits[-1] | "\(.sha) \(.kind)"' "$SF")" = "$made tests" ]
}

@test "trailers: remainder-commit carries them, never adds one twice, and leaves the caller's file alone" {
  repo
  trailers '["Plan-Item: DEPENDENCY-02","Reviewed-by: a-reviewer"]'
  printf 'note\n' > NOTES.md
  # The message already ends with one of the two trailers.
  msg 'chore: the rest of the feature' '' 'Plan-Item: DEPENDENCY-02'
  cp "$MSG" "$BATS_TEST_TMPDIR/msg.before"
  runs remainder-commit "$F" "$MSG"
  [ "$(body)" = "$(printf '%s\n' 'chore: the rest of the feature' '' 'Plan-Item: DEPENDENCY-02' 'Reviewed-by: a-reviewer')" ]
  cmp "$BATS_TEST_TMPDIR/msg.before" "$MSG"
  [ "$(jq -r '.commits[-1].kind' "$SF")" = other ]
}

@test "trailers: a one-line subject shaped like a trailer stays the subject" {
  repo
  trailers '["Plan-Item: DEPENDENCY-02"]'
  printf 'note\n' > NOTES.md
  msg 'chore: the rest'
  runs remainder-commit "$F" "$MSG"
  [ "$(body)" = "$(printf '%s\n' 'chore: the rest' '' 'Plan-Item: DEPENDENCY-02')" ]
}

@test "trailers: no recorded list leaves remainder-commit's message as written" {
  repo
  printf 'note\n' > NOTES.md
  msg 'chore: the rest'
  runs remainder-commit "$F" "$MSG"
  [ "$(body)" = 'chore: the rest' ]
  local m
  for m in ".delivery-kit/runs/$F"/trailers-msg*; do
    [ ! -e "$m" ] || { echo "a message copy was made: $m"; false; }
  done
}

# Review 3, item 7: the message copy, the check's error file and
# show-message's record message are each call's own (mktemp), and are gone
# when the call ends. A fixed name let a show-message during a commit of the
# same run swap the message git commits.
@test "trailers: the message copies are each call's own, and none is left behind" {
  repo
  trailers '["Plan-Item: X"]'
  printf 'note\n' > NOTES.md
  msg 'chore: the rest'
  # A file at each old fixed name stands for another call's copy: a call
  # that wrote or removed one of these would swap that call's message.
  local d=".delivery-kit/runs/$F" n m
  for n in trailers-msg.txt trailer-check.err show-record-msg.txt; do printf 'other call\n' > "$d/$n"; done
  runs show-message "$F" "$MSG"
  runs show-message "$F" "$MSG" --record
  runs remainder-commit "$F" "$MSG"
  [ "$(body)" = "$(printf '%s\n' 'chore: the rest' '' 'Plan-Item: X')" ]
  for n in trailers-msg.txt trailer-check.err show-record-msg.txt; do
    [ "$(cat "$d/$n" 2>/dev/null)" = 'other call' ] || { echo "another call's $n was written or removed"; false; }
    rm -f "$d/$n"
  done
  for m in "$d"/trailers-msg* "$d"/trailer-check* "$d"/show-record-msg*; do
    [ ! -e "$m" ] || { echo "left behind: $m"; false; }
  done
}

# Review 3: each looped refusal test is split in two. A trailer check
# costs about a second on Windows, and under load six of these hit bats'
# 60-second limit whole.
@test "trailers: a recorded list that is not an array is refused" {
  repo
  trailers '"Plan-Item: x"'
  refuses "must be an array of non-empty strings" spec-commit "$F"
}

@test "trailers: a recorded list holding a number or an empty string is refused" {
  repo
  local bad
  for bad in '[1]' '[""]'; do
    trailers "$bad"
    refuses "must be an array of non-empty strings" spec-commit "$F"
  done
}

# control_refused <JSON list>... — each recorded list is refused before any
# commit, shown as JSON, with no control character reaching stderr raw.
# jqs strips a CR from what it prints, so a CR the filter let through would
# be silently rewritten: `a\rb` would commit as `ab`. NEL (U+0085) and NUL
# are refused here exactly as pre-flight refuses them: both run
# trailer-check.sh.
control_refused() {
  local bad want
  for bad in "$@"; do
    case "$bad" in *'\n'*|*'\r'*) want='holds a line break' ;; *) want='holds a control character' ;; esac
    trailers "$bad"
    refuses "$want" spec-commit "$F" || return 1
    [[ "$(cat "$ERR")" == *'the recorded trailer "'* ]] || { echo "not shown as JSON: $(cat "$ERR")"; return 1; }
    ! LC_ALL=C grep -q $'[\x01-\x08\x0b-\x1f\x7f]\|\xc2[\x80-\x9f]' "$ERR" \
      || { echo "a control character reached stderr raw: $(od -c "$ERR")"; return 1; }
  done
}

@test "trailers: a line break or an escape sequence in a recorded trailer is refused" {
  repo
  control_refused '["Plan-Item: a\nb"]' '["Plan-Item: a\rb"]' '["Note: a\u001b[31mb"]'
}

@test "trailers: a tab, NEL or NUL in a recorded trailer is refused" {
  repo
  control_refused '["Note: a\tb"]' '["Note: a\u0085b"]' '["Note: a\u0000b"]'
}

@test "trailers: a run marker is refused, naming it" {
  repo
  local bad
  for bad in 'Tasks: T001' 'piece: Phase 1: Setup' 'LATE: J'; do
    trailers "[\"$bad\"]"
    refuses "'$bad' uses the token" spec-commit "$F"
  done
}

@test "trailers: no colon or an empty value is refused, naming it" {
  repo
  trailers '["no colon"]'
  refuses "'no colon' has no ':'" spec-commit "$F"
  trailers '["Plan-Item:   "]'
  refuses "has an empty value" spec-commit "$F"
}

@test "trailers: a token git would read differently is refused" {
  # Which case proves which part of the pattern: `: x` the empty token;
  # `Bad token` and `Bad_token` a character outside letters, digits and dash;
  # `---`, `-` and `--foo` a first character that is not a letter; `Piece-` a
  # last character that is not a letter or a digit; `A` a one-character
  # token. Git strips a token's trailing non-alphanumerics, so `---: x` was
  # dropped and `Piece-: x` would commit as a run marker.
  repo
  local bad
  for bad in ': x' 'Bad token: x' 'Bad_token: x' '---: x'; do
    trailers "[\"$bad\"]"
    refuses "a token starts with a letter, ends with a letter or a digit, and holds letters, digits and dash only" spec-commit "$F"
  done
}

@test "trailers: a token git would read differently is refused (its first and last characters, and its length)" {
  repo
  local bad
  for bad in '-: x' '--foo: x' 'Piece-: x' 'A: x'; do
    trailers "[\"$bad\"]"
    refuses "a token starts with a letter, ends with a letter or a digit, and holds letters, digits and dash only" spec-commit "$F"
  done
}

@test "trailers: a trailer that skips GitHub's checks is refused, in any letter case" {
  repo
  trailers '["skip-checks: true"]'
  refuses "'skip-checks: true' uses the token 'skip-checks'" spec-commit "$F"
  local bad
  for bad in 'Note: [skip ci]' 'Note: a [CI Skip] b'; do
    trailers "[\"$bad\"]"
    refuses "'$bad' asks GitHub to skip the checks" spec-commit "$F"
  done
}

@test "trailers: a trailer that skips GitHub's checks is refused, in its other spellings" {
  repo
  local bad
  for bad in 'Note: [no ci]' 'Note: [Skip Actions]' 'Note: [actions skip]'; do
    trailers "[\"$bad\"]"
    refuses "'$bad' asks GitHub to skip the checks" spec-commit "$F"
  done
}

@test "trailers: a trailer that names another author is refused" {
  repo
  local bad
  for bad in 'Co-authored-by: A <a@example.invalid>' 'signed-off-by: A <a@example.invalid>' 'On-behalf-of: org'; do
    trailers "[\"$bad\"]"
    refuses "which acts on GitHub or names another author" spec-commit "$F"
  done
}

@test "trailers: a trailer that closes an issue is refused" {
  repo
  local bad
  for bad in 'Fixes: #1' 'Closes: owner/repo#1'; do
    trailers "[\"$bad\"]"
    refuses "which acts on GitHub or names another author" spec-commit "$F"
  done
  local val
  for val in 'Note: this fixes #12' 'Note: closes o/r#1'; do
    trailers "[\"$val\"]"
    refuses "would close an issue" spec-commit "$F"
  done
}

@test "trailers: a one-word last paragraph is not a trailer block, and a spaces-only line splits paragraphs" {
  # Git reads a line of only spaces as blank, and a last paragraph whose
  # line has no "token: " is prose: the trailers then need a blank line.
  repo
  trailers '["Plan-Item: X"]'
  printf 'one\n' > NOTES.md
  msg 'chore: one' '' 'word'
  runs remainder-commit "$F" "$MSG"
  [ "$(body)" = "$(printf '%s\n' 'chore: one' '' 'word' '' 'Plan-Item: X')" ]
  printf 'two\n' > MORE.md
  msg 'chore: two' '' 'Body.' '   ' 'Note: y'
  runs remainder-commit "$F" "$MSG"
  [ "$(body)" = "$(printf '%s\n' 'chore: two' '' 'Body.' '   ' 'Note: y' 'Plan-Item: X')" ]
}

@test "trailers: the same trailer twice in the list is added once" {
  repo
  trailers '["Ab: x","Ab: x"]'
  runs spec-commit "$F"
  [ "$(body)" = "$(printf '%s\n' 'docs(spec): 001-demo' '' 'Ab: x')" ]
}

@test "trailers: a token that only holds a run marker's letters commits exactly" {
  # A reserved-token match by prefix or substring would refuse these.
  repo
  trailers '["Pieces: x","Related: y","XPiece: z"]'
  runs spec-commit "$F"
  [ "$(body)" = "$(printf '%s\n' 'docs(spec): 001-demo' '' 'Pieces: x' 'Related: y' 'XPiece: z')" ]
}

@test "trailers: another value under the same token is added; the same line is not" {
  repo
  trailers '["Plan-Item: DEPENDENCY-02"]'
  printf 'one\n' > NOTES.md
  msg 'chore: one' '' 'Plan-Item: OTHER'
  runs remainder-commit "$F" "$MSG"
  [ "$(body)" = "$(printf '%s\n' 'chore: one' '' 'Plan-Item: OTHER' 'Plan-Item: DEPENDENCY-02')" ]
  trailers '["Plan-Item: X"]'
  printf 'two\n' > MORE.md
  msg 'chore: two' '' 'Plan-Item: X'
  runs remainder-commit "$F" "$MSG"
  [ "$(body)" = "$(printf '%s\n' 'chore: two' '' 'Plan-Item: X')" ]
}

@test "trailers: no trailer setting in the repository's git configuration moves, renames or runs on them" {
  repo
  git config trailer.where start
  git config trailer.ifexists replace
  git config trailer.separators '='
  git config trailer.zz.key Piece
  git config trailer.zz.cmd "touch '$BATS_TEST_TMPDIR/ran'"
  trailers '["zz: x","Plan-Item: DEPENDENCY-02"]'
  runs snapshot "$F" late H.7
  printf 'changed\n' >> src/keep.sh
  msg 'refactor: simplify'
  runs late-commit "$F" H.7 "$MSG"
  [ "$(body)" = "$(printf '%s\n' 'refactor: simplify' '' 'Late: H.7' 'zz: x' 'Plan-Item: DEPENDENCY-02')" ]
  [ ! -e "$BATS_TEST_TMPDIR/ran" ]
}

@test "show-message prints the exact message the commit then carries, and leaves the file alone" {
  repo
  trailers '["Plan-Item: DEPENDENCY-02","Reviewed-by: a-reviewer"]'
  printf 'note\n' > NOTES.md
  msg 'chore: the rest of the feature' '' 'Plan-Item: DEPENDENCY-02'
  cp "$MSG" "$BATS_TEST_TMPDIR/msg.before"
  runs show-message "$F" "$MSG"
  cp "$OUT" "$BATS_TEST_TMPDIR/shown"
  cmp "$BATS_TEST_TMPDIR/msg.before" "$MSG"
  runs remainder-commit "$F" "$MSG"
  git cat-file commit HEAD | sed '1,/^$/d' > "$BATS_TEST_TMPDIR/committed"
  cmp "$BATS_TEST_TMPDIR/shown" "$BATS_TEST_TMPDIR/committed"
  [ "$(body)" = "$(printf '%s\n' 'chore: the rest of the feature' '' 'Plan-Item: DEPENDENCY-02' 'Reviewed-by: a-reviewer')" ]
}

@test "show-message --record prints J's record commit exactly as late-commit J --record makes it" {
  # Review 3: in the single-commit flow K makes J's record commit after the
  # answer. Its message gains `Late: J` before the trailers, so the plain
  # preview was not the commit.
  repo
  trailers '["Plan-Item: DEPENDENCY-02"]'
  msg 'test: carry the accepted reds'
  runs show-message "$F" "$MSG" --record
  cp "$OUT" "$BATS_TEST_TMPDIR/shown"
  runs late-commit "$F" J "$MSG" --record
  git cat-file commit HEAD | sed '1,/^$/d' > "$BATS_TEST_TMPDIR/committed"
  cmp "$BATS_TEST_TMPDIR/shown" "$BATS_TEST_TMPDIR/committed"
  [ "$(cat "$BATS_TEST_TMPDIR/shown")" = "$(printf '%s\n' 'test: carry the accepted reds' '' 'Late: J' 'Plan-Item: DEPENDENCY-02')" ]
  refuses "unknown option '--late'" show-message "$F" "$MSG" --late
}

@test "show-message refuses a run marker in the message, a bad recorded trailer, and a subdirectory" {
  repo
  msg 'chore: x' '' 'Piece: Phase 1: Setup'
  refuses "carries a 'Piece:' line of its own" show-message "$F" "$MSG"
  trailers '["Note: [skip ci]"]'
  msg 'chore: x'
  refuses "asks GitHub to skip the checks" show-message "$F" "$MSG"
  # The state directory is relative: from a subdirectory holding its own
  # copy, the preview would read another run than the commit, so it refuses
  # there as the commit does.
  trailers '["Plan-Item: X"]'
  mkdir -p src/.delivery-kit/runs
  cp -R ".delivery-kit/runs/$F" src/.delivery-kit/runs/
  cd src
  refuses "run this from the repository's top level" show-message "$F" "$MSG"
}

# --- review 3 of PR #68 -------------------------------------------------------
# Each test below kills a mutant the review measured surviving on 92ca321.

@test "trailers: a line already in the block, though not its last, is not added twice" {
  repo
  trailers '["Plan-Item: X"]'
  printf 'one\n' > NOTES.md
  msg 'chore: one' '' 'Plan-Item: X' 'Other: y'
  runs remainder-commit "$F" "$MSG"
  [ "$(body)" = "$(printf '%s\n' 'chore: one' '' 'Plan-Item: X' 'Other: y')" ]
}

@test "trailers: a prose last paragraph gets a blank line, even holding ': ' or the same line" {
  # Neither paragraph is a trailer block to git (interpret-trailers --parse
  # prints nothing for either), so the trailers start their own paragraph.
  repo
  trailers '["Plan-Item: X"]'
  printf 'one\n' > NOTES.md
  msg 'chore: one' '' 'See the docs: here'
  runs remainder-commit "$F" "$MSG"
  [ "$(body)" = "$(printf '%s\n' 'chore: one' '' 'See the docs: here' '' 'Plan-Item: X')" ]
  printf 'two\n' > MORE.md
  msg 'chore: two' '' 'Prose here.' 'Plan-Item: X'
  runs remainder-commit "$F" "$MSG"
  [ "$(body)" = "$(printf '%s\n' 'chore: two' '' 'Prose here.' 'Plan-Item: X' '' 'Plan-Item: X')" ]
}
