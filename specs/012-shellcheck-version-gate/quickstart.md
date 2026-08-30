# Quickstart: validating this feature

Every command below is run from the repository root. Each block is meant
to be executed, not read — a block that only looks right is the failure
mode this file exists to prevent.

## Prerequisites

The static analyser and the test runner must both be present.

```bash
shellcheck --version
bash "$HOME/bats/bin/bats" --version
```

Both must print a version and exit zero. If the analyser is absent,
install it through the platform's package channel; the run stops until it
is there, because a check that cannot run is not a check that passed.

---

## 1. The discovery rule yields the intended set

```bash
git ls-files -z -- '*.sh' '*.bash' ':(exclude).specify/' | tr '\0' '\n'
```

Expected: the first-party shell files, and nothing from the vendored
scaffold directory. The shared version-agreement script must appear in
this list once it exists — that is contract clause S8.

---

## 2. The discovery rule can return nothing, and that is caught

```bash
git ls-files -z -- '*.sh' '*.bash' ':(exclude)*' | tr -dc '\0' | wc -c
```

Expected: `0`. This proves the empty case is reachable, so the job's
guard against it is testable rather than decorative. The job itself must
fail on this condition — clause S3.

---

## 3. The analysis is clean on the current tree

```bash
git ls-files -z -- '*.sh' '*.bash' ':(exclude).specify/' | xargs -0 shellcheck --norc -f gcc
```

Expected: no output, exit zero.

---

## 4. The analysis is proven able to fail

Plant one real defect, echo the planted line so the mutation is proven to
have landed, run the analysis, then revert.

```bash
before="$(sha256sum < tests/helper.bash)"
cp tests/helper.bash /tmp/helper.bash.bak
printf '\nsc_probe() { echo $1; }\n' >> tests/helper.bash
tail -2 tests/helper.bash
git ls-files -z -- '*.sh' '*.bash' ':(exclude).specify/' | xargs -0 shellcheck --norc -f gcc; echo "exit=$?"
cp /tmp/helper.bash.bak tests/helper.bash && rm /tmp/helper.bash.bak
[ "$(sha256sum < tests/helper.bash)" = "$before" ] && echo "revert OK" || echo "REVERT FAILED"
```

Expected: the planted line is printed; the analysis names it and exits
non-zero; the revert check prints `revert OK`.

The revert is checked against the file as it stood BEFORE the plant, not
against the base branch. This branch changes that file on purpose, so a
comparison against the base branch would be non-empty for a correct
revert, and would teach the reader to ignore the one line that matters.

Never believe a red without first seeing the planted line, and never
believe the revert without the checksum.

---

## 5. The shared version script passes on a clean tree

```bash
bash scripts/check-versions.sh; echo "exit=$?"
```

Expected: one line per plugin naming its three agreeing versions, and
exit zero.

---

## 6. The shared version script refuses a wrong working directory

```bash
( cd "$(mktemp -d)" && bash "$OLDPWD/scripts/check-versions.sh"; echo "exit=$?" )
```

Expected: a named refusal and a non-zero exit — clause V5. A pass here
would mean the script examined nothing and said so in the voice of a
green.

---

## 7. Removing a version reddens both gates

Mutate one manifest, prove the mutation landed, run both gates, restore.

```bash
cp handoff/.claude-plugin/plugin.json /tmp/plugin.json.bak
jq 'del(.version)' /tmp/plugin.json.bak > handoff/.claude-plugin/plugin.json
jq -r 'has("version")' handoff/.claude-plugin/plugin.json
bash scripts/check-versions.sh; echo "script exit=$?"
bash "$HOME/bats/bin/bats" tests/portability.bats -f 'manifest, marketplace entry and changelog agree'; echo "suite exit=$?"
cp /tmp/plugin.json.bak handoff/.claude-plugin/plugin.json && rm /tmp/plugin.json.bak
git diff --stat -- handoff/.claude-plugin/plugin.json
```

Expected: `false` from the mutation probe, proving the key is gone; both
gates non-zero; an empty final diff.

---

## 8. The parity test is proven able to fail

The test asserting both callers name one script must be observed failing
before it is trusted. Break one caller in a scratch copy, not in place.

```bash
SCRATCH="$(mktemp -d)"
before="$(sha256sum < .github/workflows/ci.yml)"
cp .github/workflows/ci.yml "$SCRATCH/ci.yml.bak"
sed -i 's#scripts/check-versions\.sh#scripts/not-the-script.sh#' .github/workflows/ci.yml
grep -n 'not-the-script' .github/workflows/ci.yml
bash "$HOME/bats/bin/bats" tests/portability.bats -f 'one version-agreement script'; echo "exit=$?"
cp "$SCRATCH/ci.yml.bak" .github/workflows/ci.yml && rm -rf "$SCRATCH"
[ "$(sha256sum < .github/workflows/ci.yml)" = "$before" ] && echo "revert OK" || echo "REVERT FAILED"
```

Expected: the mutated line is printed; the parity test exits non-zero;
the revert check prints `revert OK`. Checked against the pre-mutation
file rather than the base branch, for the reason given at step 4.

---

## 9. The full house suite

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
```

Expected: exactly one more passing test than the baseline recorded for
this run, zero failures, zero non-conforming output lines. The suite
exceeds two minutes; allow for it.

---

## 10. The runner pin is the commit, not the release object

```bash
git ls-remote https://github.com/bats-core/bats-core.git 'refs/tags/v1.11.0*'
```

Expected: two lines. The one whose reference ends in the peel suffix
carries the commit. That is the value the workflow must pin.

The other line is the tag object. Measured: it can also be fetched and
checked out — git peels it, and HEAD lands on the same commit. The commit
is preferred because a checked-out copy reports the commit as its own
revision, and because a tag object's identifier moves when the same code
is re-tagged with a different message.
