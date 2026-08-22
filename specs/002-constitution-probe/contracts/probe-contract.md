# Probe contract — speckit.constitutionSet and the probe line

## The boolean

`pipeline/scripts/preflight.sh` emits, inside the `speckit` object, one
new key:

| State of `.specify/memory/constitution.md` | Value |
|---|---|
| Absent | `false` |
| Present, template-placeholder shape (as `specify init` leaves it) | `false` |
| Present, no non-blank non-comment content (single-line `<!-- -->` comments) | `false` |
| Present, written principles | `true` |

Comment recognition is line-scoped: a file whose only content is a
multi-line `<!-- … -->` block reads as `true` — an accepted false
positive, recorded with the mechanism trade-offs in research R1 (the
real init template's comments are all single-line).

Everything else about the script's external contract is unchanged: same
flags (`--dir`, `--project-type`, `--base-branch`), all previously
emitted keys unchanged, stdout pure JSON, diagnostics on stderr.

## The probe line (quoted contract text, SKILL.md)

- Set: `Constitution : set`
- Not set: `Constitution : not set — plan gates run against an empty document`

## The offer (SKILL.md pre-flight decision list)

When `constitutionSet` is false, OFFER running `/speckit-constitution`
once — the principles are the owner's to write, declining is fine, and
the offer is not repeated within a run.

## The changelog

`pipeline/CHANGELOG.md` gains `## [Unreleased]` above `## [1.0.1] …`
with an Added entry for the probe and the offer. No version stamp.
