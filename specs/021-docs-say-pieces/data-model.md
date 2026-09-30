# Data model: the documentation says pieces

No data changes. The feature's entities are records of the audit, not stored
data.

## Claim

- **Text**: the seed's phrase ("five stops", "no gate stopping", "K commits",
  "one commit", "pre-answers the implementer gate").
- **Grep**: the fixed-string, case-insensitive patterns in
  [contracts/doc-sites.md](contracts/doc-sites.md), run over the derived file
  set (quickstart step 1).
- **Positive control**: one known hit, fired first; a grep that cannot find it
  is broken and its empty result means nothing.
- **Hit list**: every file and line the grep returns after the change, each
  with a verdict. Goes into the commit message.

## Site

- **ID**: `P#`, `C#`, `R#`, `M#` or `S#` (contract).
- **File, line** as measured at `db2875d`.
- **Verdict**: false, stale, true or history.
- **Must say**: the meaning the new text carries, checked against the
  orchestrator's section for that phase or its Gates section.

## State-file fields the status skill reads (existing, unchanged)

Read by `pipeline/skills/status/SKILL.md` step 4 (research R7); written by the
orchestrator, never by this feature:

- `current_phase` — the phase to re-enter.
- `gates.G` — an object (`answer`, `reviewMode`) or, from an older pipeline, a
  plain string holding the implementer answer alone.
- `gates.H.pauses` — the pause answers recorded so far, with each listed
  path's hash.
