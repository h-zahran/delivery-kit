# Data model: what the gate reads, and what it refuses

No stored data. The entities are the paths the gate reads, the shapes it
accepts, and the shell it runs in.

## A read path

| Path | Refused when | Message (both forms) |
|---|---|---|
| `.claude-plugin` (repository) | it is a symbolic link | `.claude-plugin is a symbolic link, which the gate does not follow` |
| `.claude-plugin/marketplace.json` | it is a symbolic link | `.claude-plugin/marketplace.json is a symbolic link, which the gate does not follow` |
| `<p>/`, a top-level directory | it is a link and holds a `.claude-plugin` entry | `<p>: the plugin directory is a symbolic link, which the gate does not follow` |
| `<p>/.claude-plugin` | it is a symbolic link | `<p>: .claude-plugin is a symbolic link, which the gate does not follow` |
| `<p>/.claude-plugin/plugin.json` | it is a symbolic link | `<p>: plugin.json is a symbolic link, which the gate does not follow` |
| a marketplace source, any component, its `.claude-plugin` or `plugin.json` | one is a symbolic link | `marketplace entry '<name>': source '<source>' passes through a symbolic link` |
| a marketplace source | more than 64 components | `marketplace entry '<name>': source '<source>' has more than 64 components` |
| `<p>/CHANGELOG.md` | as Phase 27 | as Phase 27 |

`<p>`, `<name>` and `<source>` are shown masked (Phase 27's `shown`).
Order: the repository's two checks first, before the `-f` test (so a
broken link is a link, not "run me from the repository root"); in the
loop, after `shown p_s` (so a message names this plugin), directory,
`.claude-plugin`, `plugin.json`, each before anything reads through it;
in the reverse walk, before the `-f` test.

## A JSON file's shape

| File | Accepted shape | Not JSON | Wrong shape |
|---|---|---|---|
| `marketplace.json` | exactly one JSON document; `.plugins` an array of objects; `name`, `source` and `version`, when present, strings | `.claude-plugin/marketplace.json is not valid JSON` (an empty file too) | `.claude-plugin/marketplace.json is not one object whose plugins is a list of entries with string name, source and version, and no NUL character` |
| `plugin.json` | exactly one JSON document, an object; `name` and `version`, when present, strings | `<p>: plugin.json is not valid JSON` (an empty file too) | `<p>: plugin.json is not one object with a string name and version, and no NUL character` |

Checked once, before any other read of the file, after its open check
(`.claude-plugin/marketplace.json could not be read`; `<p>: plugin.json
could not be read`, as Phase 27), after `command -v jq`. `jq`'s own standard error is
discarded for the check and for every later read. A missing `name` or
`version`, or one that is `false` or `null`, keeps its message from
`5a78ea4` (`has no name`, `has no version`, `has no source`); a value of
any other wrong type, or a string holding a NUL, is a wrong shape. The
exact filters are in research R2.

## A printed value

As Phase 27 (`shown`: cut, then mask every byte outside printable ASCII
as `?`), and then `##[` shown as `#?[`. The walk's refusal text, which
the walk masks itself, gets the `##[` step in bash after the walk.

## The shell

| Option, set by the caller | Effect at `5a78ea4` | After |
|---|---|---|
| `xtrace`, `verbose` | every value, or the script's text, on standard error | off at the first command; at most the first lines echoed, no value |
| `noglob`, `keyword` | the gate refused the real tree | off at the first command |
| `dotglob`, `nocasematch` (through `BASHOPTS`) | a planted tree's verdict flipped: a hidden plugin directory read, `--RELEASED` taken as the release form (measured at review) | off at the first command, by `shopt -u` after the `set` |
| `noexec`, `onecmd`, and `BASH_ENV` | exit 0, nothing printed (`BASH_ENV`: a file ran first) | a recorded limit: no line of the gate runs before them |
