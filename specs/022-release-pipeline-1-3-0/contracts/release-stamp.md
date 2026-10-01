# Contract: the release stamp

The release is correct when every clause below holds on the branch head.
`quickstart.md` checks each one; the clause ID is printed beside its check.

| ID | Clause | Check |
|---|---|---|
| S1 | The marketplace lists `handoff 2.2.0` and `pipeline 1.3.0`, in that order. | `jq -r '.plugins[] \| "\(.name) \(.version)"'` |
| S2 | The pipeline manifest says `1.3.0`. | `jq -r .version` |
| S3 | The pipeline changelog's first `## ` heading is `## [1.3.0] - 2026-10-01`. | first `^## ` line |
| S4 | No `## [Unreleased]` heading remains. | `grep -c` = 0 |
| S5 | The changelog equals the `d9a085e` file with the one heading replaced, byte for byte. | `cmp` against a rewritten copy |
| S6 | Outside this feature's spec directory (`specs/022-release-pipeline-1-3-0/`), the diff from `d9a085e` is the three files, `1 1` each, and no untracked file exists. | `git diff --numstat`; `git ls-files --others --exclude-standard` |
| S7 | Nothing under `handoff/` differs from `d9a085e`. | `git diff --quiet` |
| S8 | The agreement gate reports both plugins `state=released` and exits 0. | `scripts/check-versions.sh` |
| S9 | The tag-mode gate passes on the branch and FAILS at `d9a085e` with its own refusal ("this tree is NOT released"), not merely a non-zero rc. | `--released pipeline`, both trees |
| S10 | Both JSON files still parse. | `jq empty` |
| S11 | The house suite: plan line `1..240`, 240 ok, 0 skipped, 0 not ok, 0 non-TAP lines. | the full suite from the root |

After the merge, outside this run: the tag `pipeline-v1.3.0` is pushed from
`origin/main`, and its run's "tag matches the manifest version" step concludes
`success`, not `skipped`.
