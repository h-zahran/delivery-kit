# Contract: the release form, after Phase 26

Clause IDs used by the tests and the quickstart. Phase 25's clauses H1-H9
(`specs/024-gate-every-heading-form/contracts/release-form.md`) still hold,
except where a clause below replaces part of one. A test failure echoes its
clause ID first. Plants that must be found by their text use tokens no
changelog holds (`CRplant`, `### Plantnote`): the copied changelog holds
`### Notes` five times.

| ID | Clause | Spec |
|---|---|---|
| K1 | A changelog line holding a CR byte is refused under `--released`, naming the line and saying `carriage return`, the CR shown as `?`. A lone CR is planted (`CRplant`, a CR, `## x`). | FR-001 |
| K2 | The default form's `state=UNRELEASED-ABOVE:` field and the release form's first-heading refusal show every non-printable character as `?`. With an escape sequence in a first heading above the release, neither output holds the escape byte, and the default form exits as it does today. Since review (research R14), both are also cut as K4 cuts a quote, and both hold for a first heading with a byte that is not valid UTF-8, run under a UTF-8 locale. | FR-002 |
| K3 | A line longer than 1,000 bytes is refused under `--released`, naming the line and its length, before it is judged; a line of exactly 1,000 is not refused for its length. A line of 400,000 `> ` markers is refused this way, in under 2 s on this machine (measured by the quickstart). | FR-003 |
| K4 | A refusal quotes at most 200 characters of a line, then ` [cut]`. Every non-printable byte in a quote is shown as `?`, a lone `\x9b` included. | FR-004 |
| K5 | A changelog holding a NUL byte stops both forms with a non-zero status and `holds a NUL byte`, naming the plugin. | FR-005 |
| K6 | Each narrowing kept passes its plant; each one not kept is refused as before. Passing plants: `1. a` then `2. ` + a fence (N1); `<details>`, a blank line, `x`, a blank line, `</details>`, a blank line, then a fence (N2); `### Plantnote` then `---`, and Phase 25's `### x` then `---` (N3); `> Notes`, `>`, `> ---` (N4). Still refused: `Para`, `2. ` + a fence; `Para`, `1.`, `2. ` + a fence; `1234567890. a`, `2. ` + a fence (N1); `<!--`, a fence; `<div>`, a fence with no blank line between; `<x`, `<!--`, a blank line, a fence (N2); `- a`, `  ### x`, `  ---`; `Para`, `    > ### x`, `---`; `> ### x`, `> ---` (N3); `Para`, `    >`, `---`; `> a`, `>     >`, `> ---` (N4, added at pull request review). | FR-008-FR-010 |
| K7 | The real tree: both forms print and exit exactly as at `88cb603`. | FR-007 |
| H8 (reworded) | The default form passes a copy holding every refused plant of a test that the default form accepts, each after its own `Plain text.` and blank line, and still reports the judged plugin as released. Left out by name: the NUL plant (K5 stops both forms) and a first heading above the release (K2; it cannot report `state=released`). | FR-013 |
| U1 | No `run bash -c` in the `--released` tests holds the directory, the root or the plugin name inside its command string. | FR-011 |
| U2 | No captured output of a `--released` test, passing runs included, holds the test directory or the root in any spelling the platform prints. | FR-012 |
| U3 | `forms_passes` refuses a plant that did not land, naming the fixture. | FR-014 |
| U4 | The fixture helper's self-check fails on a file still holding a refused shape, and a failed `mv` fails the helper, each with a `fixture:` message. | FR-015 |
| U5 | `forms_at` prints `fixture:` when its line is missing. | FR-016 |
| U6 | The fixture helper drops a CR line and an over-long line with its own constants. | FR-017 |
