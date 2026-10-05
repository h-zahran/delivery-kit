# Contract: what the gate reads, and what it prints

`scripts/check-versions.sh`, run from the repository root as the default
form (no argument) or the release form (`--released <plugin>`). Each
clause names the requirement it holds. A test that fails names its
clause first (`L2: …`), and a fixture failure says `fixture: …`.

"Printed safely" below means: in the output, with every em dash
(`\342\200\224`, the gate's own text) removed, no byte is outside space to
`~`, and no line starts with `::` after any leading spaces (research R6).

| ID | Clause | Spec |
|---|---|---|
| L1 | A `CHANGELOG.md` that is a symbolic link, to a regular file or to nothing, is refused in both forms with `is a symbolic link`, naming the plugin, and with ` — this tree is NOT released` in the release form only; no tool reads through it. The test prints `# links: made` to the test log. A link it cannot make is a fixture failure, except on Windows (Git Bash, MSYS, Cygwin), where it checks instead that a regular file holding the target path (what a checkout makes there) is refused with `no changelog heading`, and prints `# links: not available here`. | FR-001, FR-011 |
| L2 | A `CHANGELOG.md` that exists and is not a regular file (a directory) is refused in both forms with `is not a regular file`, naming the plugin, and with ` — this tree is NOT released` in the release form only. | FR-001 |
| L3 | Under `--released <plugin>`, that plugin's changelog of 262,145 bytes is refused with `262145 bytes` and `(262144) — this tree is NOT released`; one of exactly 262,144 bytes is not refused for its size; the default form never refuses for size. | FR-003 |
| L4 | A missing changelog is refused in both forms with the gate's own `no changelog heading in the pinned '## [X.Y.Z] - YYYY-MM-DD' format`, and nothing else: the output is that line alone. | FR-002, FR-014 |
| L5 | A `plugin.json`, then (under `--released`) a `CHANGELOG.md`, that the shell cannot open is refused with the gate's own `plugin.json could not be read` (or `CHANGELOG.md could not be read — this tree is NOT released`), and the output is that line alone. Only where a mode of 000 stops a read; elsewhere the test prints `# unreadable: not available here`. | FR-014 |
| P0 | Every variable a `die` line of the gate expands is a masked copy (`_s`) or a value the gate makes itself; a static scan, after a control that a planted raw `$p` and `${pn}` are both found by name. | FR-004 |
| P1 | A `plugin.json` name or version holding a line feed, `::error title=x::y` and an escape sequence is printed safely, and its masked fragments appear. | FR-004, FR-006 |
| P2 | A marketplace version or source, and three extra marketplace entries whose name and source hold the same (a missing, an absolute and a traversing source), are printed safely, and their masked fragments appear. | FR-004 |
| P3 | A plugin directory whose name starts with `::` (and one starting with a space then `::`) and holds an escape byte is printed safely: the report line starts with `?`, and no program's own error prints the name. | FR-004, FR-006, FR-014 |
| P4 | An escape byte in the `--released` argument or in an unknown argument is printed safely. | FR-005 |
| P5 | Under `--released <plugin>`, a first heading holding an escape sequence above the release is printed safely in the report line and in the refusal, and that refusal still holds its em dash: the gate's own text is not masked. | FR-004, FR-007 |
| P6 | A value longer than the quote cut is shown as its first 200 bytes, masked, then ` [cut]`; a value of exactly 200 bytes is shown whole, with no ` [cut]`; a value holding a byte that is not valid UTF-8 and an `é`, run under a UTF-8 locale, is shown with each of those bytes as `?`. | FR-015 |
| W1 | A marketplace whose walk input is 65,600 bytes, through one trailing entry's name, is refused for that entry (`names no plugin directory`, exit 1) within 30 s: Git Bash hung on a herestring of that size. | beyond the seed (research R10) |
| R1 | On the real tree both forms print and exit exactly as at `4016666`. | FR-008 |
| R2 | The walk is unchanged: its sha256, as the proof script extracts it, is `24c123b1b203af88fdcd745f3c4cba58ba6289e1612cf13f7bf1708d46314896`. | FR-008 |
