# Probe contract — speckit.constitutionSet and the probe line

## The boolean

`pipeline/scripts/preflight.sh` emits, inside the `speckit` object, one
new key:

| State of `.specify/memory/constitution.md` | Value |
|---|---|
| Absent | `false` |
| Present, template-placeholder shape (as `specify init` leaves it) | `false` |
| Present, no non-blank non-comment content | `false` |
| Present, written principles | `true` |

"Template-placeholder shape" means the shipped template's OWN tokens
(`[PROJECT_NAME]`, `[PRINCIPLE_n_NAME]`, …) surviving outside HTML
comments — an arbitrary bracketed token (`[RFC2119]`, a checked `[X]`
box) is a written constitution's prose and reads `true`. Comments —
single-line and multi-line — are stripped before both checks, so the
Sync Impact Report comment the constitution command itself prepends
never flips its own output to `false`; an unclosed comment is kept as
literal text, so a template hidden behind a stray `<!--` still reads
`false`. Any NUL byte in the file's head (a UTF-16/32 save, with or
without a BOM) reads `false` with a named warning on stderr —
unparseable bytes fail toward offering, never toward `set`. The named
residual edges are recorded with the mechanism trade-offs in research
R1.

Everything else about the script's external contract is unchanged: same
flags (`--dir`, `--project-type`, `--base-branch`), all previously
emitted keys unchanged, stdout pure JSON, diagnostics on stderr.

## The probe line (rendered forms; SKILL.md carries the template)

The orchestrator's probe block holds one combined template line —
`Constitution : <set / not set — plan gates run against an empty
document>` — which renders as exactly one of:

- Set: `Constitution : set`
- Not set: `Constitution : not set — plan gates run against an empty document`

The rendered forms are the output contract; the template line is what a
fixed-string search of SKILL.md finds.

## The offer (SKILL.md pre-flight decision list)

When `constitutionSet` is false, OFFER running `/speckit-constitution`
once — the principles are the owner's to write, declining is fine, and
the offer is not repeated within a run.


## The changelog

`pipeline/CHANGELOG.md` gains `## [Unreleased]` above `## [1.0.1] …`
with an Added entry for the probe and the offer. No version stamp.
