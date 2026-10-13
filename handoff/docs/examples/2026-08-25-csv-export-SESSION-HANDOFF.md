> **A sample, wholly fictional.** The project (ledgerlark), its feature, branch,
> commits and pull request are invented. This is the document `/handoff:handoff`
> writes into `docs/handoffs/`, the default `handoff.docsDir`, with the sections
> the skill requires. The Reconcile section at the end was written by the
> plugin's own `reconcile-block.sh`. No pipeline run was live, so the document
> has no Pipeline state section. The session that wrote it ended its last
> message with this:
>
> ```
> Resume with:
> Read docs/handoffs/2026-08-25-csv-export-SESSION-HANDOFF.md and continue from it. Follow the Resume protocol.
> ```

---

# Session handoff: CSV export

## Branch & SHA

- Branch: `014-csv-export`
- Last commit: `76fe1029a811175c1116028c527846375ecc2732`
- Pull request: #41, open, not yet reviewed
- CI: green at `76fe102`, the commit above

## Goal & done-condition

Add a CSV download to the report page of ledgerlark. Done when the report's
table downloads as a CSV that a spreadsheet opens with every cell intact
(commas, quotes and line breaks included), all tests pass, and PR #41 is
merged.

## State

| Task | Status | Commit |
|---|---|---|
| T001-T004 setup, export model | done | `7952bc0` |
| T005 CSV writer for plain cells | done | `76fe102` |
| T006 quote a cell holding a comma, a quote or a line break | in progress: the line-break case fails; next, wrap such a cell in quotes in `quoteCell` in `src/reports/csv.ts` | uncommitted |
| T007 download button on the report page | remaining | |
| T008 user guide entry | remaining | |
| T009 reports over 10,000 rows | blocked, see Blocked | |

## Uncommitted work

The work in progress is uncommitted. `git clean`, `git checkout` or
`git stash` will discard it or take it out of the working tree.

```
 M src/reports/csv.ts
 M test/csv.test.ts
?? tmp/
```

```
 src/reports/csv.ts | 4 ++++
 test/csv.test.ts   | 3 +++
 2 files changed, 7 insertions(+)
```

- `src/reports/csv.ts`, `test/csv.test.ts`: this run's work (T006).
- `tmp/`, which holds `tmp/sample-report.csv`: pre-existing, a hand-made test
  file. Leave it out.
- `docs/handoffs/2026-08-25-csv-export-SESSION-HANDOFF.md`: this run's work,
  this document, written after the status above. Not ignored, so it is on the
  `git add` line below.

To commit it yourself:

```bash
git add -- src/reports/csv.ts test/csv.test.ts docs/handoffs/2026-08-25-csv-export-SESSION-HANDOFF.md
git commit -m "wip(reports): quote cells holding a comma or a quote"
git push
```

## Verification state

- Tests: `npm test` ran 212, 211 passing; the one failure is T006's new
  "quotes a line break" test, red on purpose until the fix lands.
- Lint: `npm run lint` clean, the same zero-warning baseline as `main`.
- CI: green at `76fe102`; the uncommitted T006 work has not been through CI.
- Runtime: not yet tried in a browser; that comes with T007.

## Blocked

- T009, reports over 10,000 rows: waiting on the owner to choose between
  streaming the file and capping the export. Asked in a comment on PR #41.

## Gotchas discovered this session

- A spreadsheet opens a UTF-8 CSV as the wrong encoding unless the file starts
  with a byte-order mark. Decided: write the mark. `test/csv.test.ts` pins it.
- Tried a CSV library first and dropped it: it quotes every cell, and the spec
  asks for quotes only where a cell needs them.

## Deployments pending

None. The feature adds no migration, and nothing deploys before PR #41 merges.

## Resume protocol

1. Reconcile this document's claims against git: run the one-line command in
   the `~~~sh` fence of the Reconcile section at the end of this document (not
   the script below it) and report its output. If the output does not end in a
   `RECONCILE:` line, the check did not run: say so and check by hand. It
   cannot see the pull request or CI, so check by hand that PR #41 is open and
   CI is green at `76fe102`. HEAD should match the commit above exactly; a HEAD
   ahead of it means someone else committed, so report that. The tree should
   still be dirty as Uncommitted work says; if it is clean, ask before assuming
   the work was committed rather than discarded.
2. T006: run `npm test -- csv`, expect the one failure, make `quoteCell` wrap a
   cell holding a line break, and run it again.
3. T007: add the button to `src/pages/report.tsx`, calling `toCsv` in
   `src/reports/csv.ts`; then open the report page and download a file.
4. T008: add a section to `docs/user-guide.md`.
5. T009: read the owner's answer on PR #41 before writing any code.

<!-- handoff-reconcile v1: begin -->
## Reconcile

Written by the handoff plugin as the handoff's last write. Step 1 of the Resume
protocol runs the one-line command below: it reads this file and git, and
changes nothing.

~~~sh
cd "$(git rev-parse --show-toplevel)" && awk 'm && f && /^```$/ {exit} m && f; m && /^```bash handoff-reconcile$/ {f=1} $0 == "<!-- handoff-reconcile v1: begin -->" {m=1} END {if (!f) print "echo RECONCILE: cannot run, no reconcile block found; exit 2"}' 'docs/handoffs/2026-08-25-csv-export-SESSION-HANDOFF.md' | bash
~~~

It checks the branch, the commit and the `git status` lines against the ones
recorded below, and prints MATCH or MISMATCH for each. It sees which paths
changed, not what changed inside them. Its last line starts `RECONCILE:`; if
it does not, the check did not run.

```bash handoff-reconcile
# Compares the state this handoff recorded with the repository now. Read-only.
# The lines between the heredoc markers are data, never code. Every git call
# reads /dev/null: this script arrives on stdin, and a git hook would eat it.
top=$(git rev-parse --show-toplevel 2>/dev/null </dev/null) || { echo 'RECONCILE: cannot run: not inside a git repository'; exit 2; }
cd "$top" || exit 2
now=$(GIT_OPTIONAL_LOCKS=0 git -c core.quotePath=true status --porcelain=v1 --untracked-files=all --no-renames </dev/null) ||
  { echo 'RECONCILE: cannot run: git status failed'; exit 2; }
if b=$(git symbolic-ref -q HEAD </dev/null); then b=${b#refs/heads/}; else b='(detached HEAD)'; fi
h=$(git rev-parse --verify -q HEAD </dev/null) || h='(no commits)'
t=$(mktemp -d) || { echo 'RECONCILE: cannot run: mktemp failed'; exit 2; }
trap 'rm -rf "$t"' EXIT
cat > "$t/want" <<'DK~END'
|014-csv-export
|76fe1029a811175c1116028c527846375ecc2732
| M src/reports/csv.ts
| M test/csv.test.ts
|?? docs/handoffs/2026-08-25-csv-export-SESSION-HANDOFF.md
|?? tmp/sample-report.csv
DK~END
if [ -n "$now" ]; then printf '%s\n' "$now" > "$t/now"; else : > "$t/now"; fi
wb=$(sed -n '1s/^|//p' "$t/want")
wh=$(sed -n '2s/^|//p' "$t/want")
sed '1,2d; s/^|//' "$t/want" > "$t/was"
ok=1
if [ "$wb" = "$b" ]; then
  printf 'MATCH    branch: %s\n' "$b"
else
  ok=0; printf 'MISMATCH branch: recorded %s, now %s\n' "$wb" "$b"
fi
if [ "$wh" = "$h" ]; then
  printf 'MATCH    head: %s\n' "$h"
else
  ok=0; more=''
  case $wh in
    *[!0-9a-f]* | '') ;;
    *) git merge-base --is-ancestor "$wh" HEAD </dev/null 2>/dev/null && more=' (the recorded commit is behind it: commits were added since the handoff)' ;;
  esac
  printf 'MISMATCH head: recorded %s, now %s%s\n' "$wh" "$h" "$more"
fi
n=$(grep -c '' "$t/was")
if cmp -s "$t/was" "$t/now"; then
  printf 'MATCH    tree: %s status lines, as recorded\n' "$n"
else
  ok=0; printf 'MISMATCH tree: the status lines differ (< recorded only, > now only):\n'
  diff "$t/was" "$t/now"
fi
if [ "$ok" = 1 ]; then echo 'RECONCILE: MATCH'; exit 0; fi
echo 'RECONCILE: MISMATCH'
exit 1
```
<!-- handoff-reconcile v1: end -->
