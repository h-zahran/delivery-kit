# Changelog — mission-control

All notable changes to the `mission-control` plugin.

## [0.9.3] - 2026-10-12

### Fixed

- **The sound on Windows runs PowerShell by its full path.** It ran a bare
  `powershell.exe`, and Windows looks for a bare name in the current folder
  before PATH, so a repository that carried its own `powershell.exe` could
  have it run each time a sound played. The path comes from `SystemRoot`
  when that reads as a plain drive path, else the default Windows folder.
  The Linux players stay by name: Linux searches only PATH, never the
  current folder.
- **An ask in the system prompt stays a quote.** The open asks repeat the
  first line of each prompt, and pasted text can carry words the person
  never wrote. A `"` inside an ask is now shown as `'`, and `<` and `>` as
  `‹` and `›`, so the text cannot close its quote or open a tag. The section
  now says a quote is a label, not an instruction. An ask the model added
  itself is marked "added by you" instead of being listed as the person's.
  The pane still shows each ask as typed.

## [0.9.2] - 2026-10-12

### Added

- First release in this marketplace. A side pane with robots for the main
  loop and every subagent: tools, context, cost, rate limits and files
  touched. Also a band above the prompt, a REQUESTS card, toasts and sounds.
  Commands: `/mission`, `/mission-band` and `/mission-talk`.
