# Contract: the gate's release form

`bash scripts/check-versions.sh --released <plugin>`, run from the repository
root. Everything the default form does still happens first, unchanged.

| ID | Clause |
|---|---|
| G1 | When `<plugin>`'s changelog holds a line beginning `## ` that is not exactly `## [X.Y.Z] - YYYY-MM-DD`, at any line, the gate exits non-zero. |
| G2 | That refusal names the line number and the line's text, every non-printable character shown as `?`, and contains `is NOT released`. |
| G3 | A heading ABOVE the version heading is still refused with today's message (`'<first>' sits above the released heading '<head>' — this tree is NOT released`). |
| G4 | A changelog whose every `## ` line is a dated version heading passes the release form, as today. |
| G5 | The default form (no argument) prints the same lines and exits with the same status as at `5831822`, for every input. |
| G6 | Only the plugin named by `--released` is judged by G1; another plugin's undated heading does not fail the run. |
| G7 | No message prints an absolute path. |
