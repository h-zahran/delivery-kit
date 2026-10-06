# Contract: what the gate follows, which program speaks, and what it prints

`scripts/check-versions.sh`, run from the repository root as the default
form (no argument) or the release form (`--released <plugin>`). Each
clause names the requirement it holds. A test that fails names its
clause first (`N2: …`), and a fixture failure says `fixture: …`.

"Printed safely" is Phase 27's rule, with two changes (FR-004, FR-011):
in the output, with only the gate's own ` — this tree is NOT released`
removed, no byte is outside space to `~`, no line starts with `::` after
any leading spaces, and no line holds `##[`.

| ID | Clause | Spec |
|---|---|---|
| N1 | A `plugin.json` that is a symbolic link to a JSON file outside the tree is refused in both forms with `plugin.json is a symbolic link`, and no text of the outside file reaches the output. | FR-001 |
| N2 | A `marketplace.json` that is a link (a broken one too), and a repository `.claude-plugin` that is a link, are each refused in both forms with `check-versions.sh: <path> is a symbolic link`, never "run me from the repository root". | FR-001 |
| N3 | A plugin directory that is a link, and a plugin's `.claude-plugin` that is a link, are each refused in both forms, naming this plugin (`check-versions.sh: <plugin>: …`). | FR-001 |
| N4 | A marketplace source passing through a link, met only by the reverse walk (a linked component, a nested source's linked `.claude-plugin`, its linked `plugin.json`), is refused in both forms with `passes through a symbolic link`. | FR-001 |
| N5 | The test prints `# nolinks: made` (or, where a system made no link, `# nolinks: not available here`), on a pass as on a failure; a link it could not make outside Windows is a fixture failure. | FR-014 |
| N6 | Where a mode of 000 stops a read, an unreadable `marketplace.json` is refused with `.claude-plugin/marketplace.json could not be read` alone, never "is not valid JSON". | FR-002 |
| N7 | A marketplace source of more than 64 components (65, and 2,046) is refused with `has more than 64 components` at once (under `timeout 15`), counted before any file test, whatever exists on disk; one of 64 whose second component is missing gives `names no plugin directory`. | FR-008 |
| J1 | A trailing marketplace entry whose `name` is an object, a `.plugins` that is a string, a marketplace of two JSON documents, and one that is `[]`, are each refused with the gate's own wrong-shape line, exit 1, and no output line starts with `jq:`. | FR-002 |
| J2 | A `marketplace.json`, and a `plugin.json`, that is not JSON or is empty is refused with `is not valid JSON`, exit 1, and no `jq:` line; a `plugin.json` whose `name` is a number, one that is `[]`, one of two documents, and a NUL inside a `plugin.json` or marketplace string give the wrong-shape line, and no line says `ignored null byte`. | FR-002 |
| X1 | A `plugin.json` version, a first heading and a refused changelog line, each holding `##[`, are printed with no `##[` in any line, and `#?[` where it was. | FR-004 |
| X2 | Met and closed: on a runner (`GITHUB_ACTIONS` is `true`) the P test printed the probe lines (`##[` at a line's start, mid-line, `##[group]` and `##[endgroup]`, and a `::warning::` control) through file descriptor 3 in pull request #61's first CI run, 37405126582; what the runner did is recorded in research R3, and the probe was then removed, so `grep -c 'p28 probe' tests/portability.bats` prints `0`. | FR-003 |
| O1 | With each of `xtrace`, `verbose`, `noglob`, `keyword` in `SHELLOPTS`, set on the gate's own command only, both forms exit as without it, standard output is byte-identical, and standard error is exactly what FR-006 allows: `xtrace` one trace of the options line's `set` command (`+ set +o xtrace +o verbose +o noglob +o keyword`: xtrace is off before its `shopt` runs), `verbose` the `#!` line and the whole options line (`set +o xtrace +o verbose +o noglob +o keyword; shopt -u dotglob nocasematch`), the others nothing. The house test checks the default form (research R8: the options line reads nothing the form sets); quickstart SC-003 checks both forms on the real tree. | FR-005, FR-006 |
| O2 | With `dotglob` or `nocasematch` in `BASHOPTS`, set on the gate's own command only, the gate exits and prints exactly as without it, standard output and standard error each byte-identical: a hidden plugin directory `.hid` (a whole agreeing plugin) with its marketplace entry `./.hid` is still refused with `marketplace lists 2 plugins, the tree holds 1` under `dotglob`, and `--RELEASED <plugin>` is still refused as an unknown argument under `nocasematch`. Each run without the option is pinned to that whole refusal first. | FR-005, FR-006 |
| C1 | A marketplace of the first plugin plus 2,000 entries is walked under `timeout 15` (where the system has one) and refused for its count, exit 1. | FR-008 |
| T1 | The P0 scan's control names each planted shape exactly: `printf -v`, `norm_source`, `read` and `for` into a name ending `_s`, a `$(` in a `die` message, and a raw name on a `die` line continued with `\`. | FR-009 |
| T2 | K3's quote-marker plant is sized from the room under the size limit; its only floor is that the line is longer than the line limit. | FR-010 |
| T3 | `gate_safe`'s control fails an output holding an em dash that is not the gate's suffix, and one holding `##[`, and passes the suffix. | FR-011 |
| R1 | On the real tree both forms print and exit exactly as at `5a78ea4`. | FR-012 |
| R2 | The walk is unchanged: its sha256, as the quickstart extracts it, is `24c123b1b203af88fdcd745f3c4cba58ba6289e1612cf13f7bf1708d46314896`. | FR-012 |
