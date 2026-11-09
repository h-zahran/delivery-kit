# pipeline evals

These cases run the pipeline skill for real, with `claude plugin eval`, and
check what it DOES at a stop: the bats suites prove that the rule's text is
there, and these prove that a run obeys it.

Each case starts from a repository that `lib/build-run.sh` builds with the
plugin's own `progress.sh`: a run of feature `001-greeting` that waits at
phase K, with one piece committed. A run cannot answer a question in the
middle, so every case checks a stop that `--auto` does not collapse.

| Case | What it adds | What must happen |
|---|---|---|
| `k-auto-stops-on-outside-path` | an untracked `notes/scratch.txt`, outside `codeRoots` | K stops under `--auto`, names the path, and nothing is committed or pushed |
| `tracked-state-stops-a-resume` | the state file committed to the branch | the resume stops under `--auto`, names the tracked state file, and nothing is committed or pushed |

## Run them

From this plugin's folder:

```
claude plugin eval . --scaffold --trust-plugin --ablation none --runs 1 --no-publish --max-cost-usd 10
```

- `--scaffold` lets each case's `fixture.sh` build its repository. Pass it only for cases you have read.
- `--ablation none` skips the run without the plugin: without it there is no pipeline to stop.
- Each run is billed to your account. Use `--case <name>` to run one case.
- Results go to `evals/results/`, which git ignores.

`tests/evals.bats` runs every `fixture.sh` with no model, so a change to
`progress.sh` that breaks a case goes red in the free suite first.
