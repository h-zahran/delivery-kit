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
  runs snapshot "$F" piece
  printf 'built\n' > src/a.sh
  printf 'state\n' > ".delivery-kit/runs/$F/extra.txt"
  mark T001 T002
  msg 'feat: the setup piece' '' 'Builds T001 to T002.'
  runs piece-commit "$F" "$MSG"
  [ "$(cat "$OUT")" = "$(git rev-parse HEAD)" ]
  [ "$(files_of HEAD)" = "$(printf '%s\n' specs/001-demo/tasks.md src/a.sh)" ]
  # Dirt from before the piece stays for K; the spec, listed before the piece
  # started, is not the piece's either.
  [ "$(git status --porcelain -- dirt.txt)" = "?? dirt.txt" ]
  [ "$(msg_tail 2)" = "$(printf '%s\n' 'Tasks: T001,T002' 'Piece: Phase 1: Setup')" ]
  [ "$(last_entry)" = "{\"sha\":\"$(git rev-parse HEAD)\",\"kind\":\"piece\",\"piece\":\"Phase 1: Setup\",\"tasks\":[\"T001\",\"T002\"],\"files\":[\"src/a.sh\",\"specs/001-demo/tasks.md\"]}" ]
  run bash "$PROG" piece-next "$F"
  [ "${lines[0]}" = "Phase 2: Core" ]
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
  refuses "already carries 'Late: J'" late-commit "$F" J "$MSG" --record
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
  runs spec-commit "$F"
  [ ! -s "$OUT" ]
  [[ "$(cat "$ERR")" == *"already recorded"* ]]
  [ "$(git rev-parse HEAD)" = "$head" ]
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
  [ -f "$d/guide-1.md" ] && [ -f "$d/guide-2.md" ] && [ ! -e "$d/guide-3.md" ]
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
