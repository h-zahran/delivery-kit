# Research: Remove repeated and serial work from a pipeline run

## R1. Which test files the script runs

- **Decision**: `find -L <root> -type f -name '*.bats'`, sorted with `LC_ALL=C`. This is what `bats -r` does (`libexec/bats-core/bats`, line 472).
- **Rationale**: The new command must run the same set as the serial command. A `git ls-files` walk would silently skip a new uncommitted test file: memory `a-tracked-file-gate-is-blind-to-an-uncommitted-tree`.
- **Alternatives**: `git ls-files`, used by the seed's first measurement. Rejected for that reason. The two sets are the same today: 21 files.

## R2. How files run at the same time

- **Decision**: `xargs -P <jobs> -n 1`, calling the script's own internal per-file mode.
- **Rationale**: bash 3.2 has no `wait -n`, so a job pool of plain background jobs needs a polling loop. `xargs -P` works on Linux, macOS and Git Bash, and needs no install.
- **Alternatives**: `bats --jobs` needs GNU parallel, which is not on this machine, and the seed forbids the install. A polling loop adds code and delay.

## R3. How many at once

- **Decision**: The CPU count from `getconf _NPROCESSORS_ONLN`, else `nproc`, else 2. At least 2, at most 8.
- **Rationale**: 8 was measured green four times on 16 CPUs. The upper limit keeps a large machine's load at what was measured. CI's own comment warns that load pushes tests toward their 60-second timeout.
- **Alternatives**: A setting. Rejected as unneeded: nothing asks for it.

## R4. One report

- **Decision**: Hold each file's output in `<temp>/<index>.tap`, stdout and stderr together. After all end: check each file, print one plan line, then print each file in sorted order with its own plan line dropped and its test lines renumbered.
- **Rationale**: `tap_judge` wants the plan line first, and each number 1 to N once. Each `bats` process numbers from 1. Sorted order gives FR-004.
- **The plan line**: The sum of each file's declared plan. So a file with fewer test lines than its plan also makes `tap-check` red, by a second and independent route.
- **Renumbering**: Only a line that starts `ok <digits>` or `not ok <digits>`. A `#` comment is left unchanged. `awk -v BINMODE=3`, as `TAP_AWK` does, so a carriage return is kept and not hidden.

## R5. Exit statuses and messages

- **Decision**: See [contracts/run-suite.md](contracts/run-suite.md). 0 is green. 1 is a red suite. 2 means the suite could not run. 143 means it was stopped.
- **Rationale**: A caller can tell "tests failed" from "nothing ran". Messages go to stderr and name repository-relative paths only, because `suite-record` keeps the output and CI logs are public.

## R6. Stopping

- **Decision**: Start `xargs` in a process group of its own with `set -m`, as `base_start` does where `setsid` is absent. A trap on TERM and INT signals that group, removes the temporary folder, and exits 143.
- **Rationale**: `suite-base wait --limit` sends TERM to the runner's group, or to its own id where it has no group. A signal to the script alone reaches `xargs` but not the test processes. The trap covers both routes.
- **Checked by**: A test that stops the script while a stand-in test runner sleeps, then asserts that no stand-in still runs and the temporary folder is gone.

## R7. Shared temporary paths

- **Decision**: No extra isolation.
- **Rationale**: `tests/helper.bash`'s `setup` gives every test its own `TMPDIR` and `HOME`. Four passes at 8 files at once were green.

## R8. A new test root cannot be skipped

- **Decision**: The script holds its roots on one line, `roots='...'`. A test in `tests/run-suite.bats` reads that line and CI's `suite:` matrix line, and requires the same set.
- **Rationale**: Today the root list is in `.delivery-kit.json`, and `tests/portability.bats` checks only CI's side. Moving the list into a script must not lose that link. Constitution Principle V.

## R9. Where the harness rules live

- **Decision**: A new section "The fault harness" at the end of `pipeline/skills/spec-review/SKILL.md`. Phase I already loads that skill, so I's reviewers and fix step meet the rule. H and J meet it through one bullet under "Ground rules" in the orchestrator, about 80 bytes.
- **Rationale**: The orchestrator has 221 bytes free, and run 2's gaps need them. `spec-review` has no size pressure.
- **Fixed names**: `.delivery-kit/runs/<feature>/fault-harness.sh`, and the tests reviewer's own list at `.delivery-kit/runs/<feature>/faults-tests.txt`, written before it reads the harness.

## R10. The reviewers stay read-only

- **Decision**: The section says that the run directory is the one place a reviewer may write, and that a harness works only on a throwaway copy.
- **Rationale**: `spec-review` opens with "Read-only", and phase I says "every lens is read-only until all have reported". `.delivery-kit/` is never committed by the run, and the orchestrator's "MAY" list already allows a write there.

## R11. A harness that git tracks

- **Decision**: Before running it, an actor runs `git ls-files --error-unmatch -- <harness path>`. Exit 0 means tracked: the actor treats it as no harness and says so. Any exit other than 0 or 1 also means no harness.
- **Rationale**: A cloned repository can hold a tracked run directory. The tracked-state check covers a state file, not a script an agent would run. Fail-closed follows Principle I.

## R12. What is not done

- No cap on faults, no deferred findings, no lens removed: the owner rejected these on 2026-11-04.
- No shipped harness template: projects use different test tools, and the rules are what ship.
- No change to phase I's text in the orchestrator: the rule is reached by loading `pipeline:spec-review`, and I's text is pinned.
