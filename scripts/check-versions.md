# Why check-versions.sh is written as it is

The longer reasons behind scripts/check-versions.sh, moved out of its
comments: what was measured, what review found, and how a rule came to be.
The script keeps the short why beside each line and this page holds the full
paragraph, so the two overlap on purpose; the script is the authority.
Beside each line the script keeps the sentences that say why that line must
be exactly as it is, and one pointer line,
`# Why: check-versions.md, "<section>".`, where a longer reason was moved
here. Each section holds, whole and in the order of the script, the comment
paragraphs that reason came from, so a moved sentence is read beside the one
it followed; in them, this file, here, above and below mean the script.
tests/gate.bats holds every pointer to a section on this page, and every
section here to a pointer.

## Shell options

The first command, above everything else here: a caller can switch these
options on through SHELLOPTS. Then xtrace printed every value uncut, and
verbose the script's text, on standard error, while noglob and keyword
made the gate refuse a correct tree (measured). Bash echoes or traces a
line before it runs it, so verbose still shows the two lines above and
xtrace the set command, and no value: placed lower, verbose echoed every
line above it. The shopt comes after the set, so xtrace is off before it
runs. A caller sets shopt options through BASHOPTS: dotglob made the
plugin loop read a hidden directory, so a marketplace entry the count
should refuse passed, and nocasematch made `--RELEASED` the release
form (measured). noexec, onecmd, BASH_ENV and BASHOPTS=extdebug cannot be
stopped from in here: under the first two no line of this file runs,
BASH_ENV runs a file before the first, and extdebug makes bash print this
script's path, as invoked, before the first (measured: it looks for a
debugger file that is not there). Only a caller sets them, and a caller
who does controls the shell already
(specs/027-gate-closes-phase27-deferrals/research.md R4).

## One implementation

This file exists because those two callers used to hold two copies of this
logic. They were kept in step by hand, they drifted once — an unanchored
regex in one accepted a heading the other rejected — and the drift was
invisible until a release. A comment asking maintainers to edit the pair
together is exactly what was there when it drifted. One implementation is
the only arrangement that cannot drift, and a test in the suite pins that
both callers name this file, so a hand-written copy cannot quietly return.

## Run from the repository root

Run from the repository root. The script refuses to run anywhere else rather
than guessing a root or walking upward looking for one: two callers start in
two places, and a script that silently examines the wrong tree reports a
clean result in the voice of a verdict. Resolution belongs to the caller
that has the context — the suite resolves its root and cd's there, CI runs
at the workspace root by construction — and the assertion belongs here,
where the two meet. Writing a second root resolver in this file would hand-
copy the one in tests/helper.bash, which is the defect this file exists to
end, arriving by a different door.

## jq and text mode

jq here may be a native Windows binary whose stdout is text mode: without
-b it writes a CR before every line feed, inside a value too, and Git
Bash's $( ) keeps an inner CR (measured: `a\nb` read as `a\r\nb`), so the
same file gave other values on Windows than on Linux. Every jq below runs
with -b, which writes the bytes as they are, so the values agree on every
system. -b sets standard input and output to binary; a file jq opens by
name, as --slurpfile opens the marketplace in each plugin's read, is still
read in text mode there, where a Ctrl-Z byte ends it. That is safe only
because the marketplace's own read, on standard input, comes first and
refuses a file that is not whole JSON: keep that order.

## One exit helper

One exit helper, prefixed with the script name, matching the house pattern in
pipeline/scripts/preflight.sh and pipeline/scripts/progress.sh. There were
briefly two — one prefixed for preconditions, one bare for check findings —
and nothing in the file said which to use. Two ways to exit with no stated
rule is how a maintainer picks the wrong one, and the bare messages were the
ones that actually reach a CI log without naming what emitted them.

## norm_source

Both spellings a relative source can take resolve to the same directory, so
normalise before comparing: what is asserted is WHICH directory is named, not
how it was written. One function, called from both walks. Writing this rule
out twice — in the file whose header explains why a hand-kept pair is the
defect — would be the same mistake one level down.
norm_source <name> <value> sets the named variable, as shown() does, and
prints nothing: called in a `$( )` it cost a process per marketplace
entry, about 20 ms each on Windows (400 entries: 9 s, and 1.3 s by name,
measured; research R5), which a fork listing thousands of entries turns
into minutes. The name is a caller's variable, never one of the locals
below.

Collapse doubled separators FIRST, then strip leading current-directory
prefixes, then trailing separators — in that order, and each repeatedly.
A single pass of each was not enough: ".//handoff" survived as "/handoff",
which then tripped the absolute-path guard in the reverse walk and was
reported as escaping the repository. Every spelling here names the same
directory, which is what this function exists to say. The leading
prefixes go in one regex match: stripping one per pass copied the whole
string each time, and 10,000 of them took 3.5 s (measured). The collapse
also grows faster than the length, so callers bound the length first
(source_limit). The pattern and its replacement are held in variables:
written `\/\/` and `\/` in place, macOS's bash 3.2 did not collapse a
source padded with slashes, which then did not resolve (CI; no test had
doubled a slash before, and the other steps resolve `./handoff` there).

## count_parts and the C locale

count_parts <name> <value> sets the named variable to the number of
components in the value: its separators, plus one. In the C locale, as
norm_source works: under a UTF-8 locale the substitution cost 9.2 ms on
a 4,091-character source and 17.6 ms on 16 parts of 250, against 2.9
and 4.5 ms in C (measured, research R1). A separator byte never occurs
inside a UTF-8 character, so the count is the same in either locale.
The pattern is held in a variable, as norm_source holds its own.

## Trailing line feeds

One jq per plugin reads its plugin.json on standard input and the
marketplace by its fixed path, and answers: the shape check; the name and
the version; whether an entry has that name (`1` or `0`); and the
matching entries' versions and sources. Each value is what one jq per
value, read through $( ), gives on Linux (research R1): `// ""` for a
missing value, and trailing line feeds removed, as $( ) removes them.
nl finds the last character that is not a line feed and cuts there, in
time that grows with the length. Two other ways grow with its square
(measured, 64,000 line feeds, research R12): cutting one line feed per
step (14 s when they trail), and sub("\n+\\z"; "") (14 s when they sit
before a last character, as Oniguruma retries the run from every
start). Several entries with the name give their values joined by line
feeds, one per line. Every `+` joins two strings: a length the program
writes and a value the shape check has made a string.

## Name and directory

The release-tag gate in ci.yml resolves a plugin FROM THE DIRECTORY NAME —
it strips the version suffix from the tag and reads
<plugin>/.claude-plugin/plugin.json — while this loop resolves the
marketplace entry from the manifest's .name. Nothing else holds those two
identities together: a manifest renamed without its directory left every
gate green while release tags silently stopped naming the plugin.

## Entry messages

Different defects get different messages — no entry, an entry with no
version, an entry with no source — each of which has a separate fix and
each of which has happened. plugin_read answers each as its own value
(specs/033-gate-fewer-processes/research.md R1, R3).

Existence and the version key are two different absences with two different
fixes, so they get two different messages. Without `// empty`, jq would
print the literal string "null" for a present entry missing the key, which
passes a non-empty test and sends the maintainer diffing two version
numbers when one of them does not exist.

## Entry source

And the entry must point AT the directory this iteration just read. Nothing
else in the repository reads `source` — no other test, no workflow — and it
is the field the installer follows to find the manifest, so an entry naming
the wrong directory is a broken install that every other check here calls
agreement. That is not hypothetical: `source` said "./", a directory holding
no plugin manifest, from the commit that moved the plugin into its own
directory until the commit that renamed it, and the whole suite was green
for the duration.

## The NUL count

A NUL byte makes grep call the changelog binary: the version read below
then finds no version, and errexit ends the run with no message at all.
Name it instead, in both forms. Counted with tr, before any grep or awk
reads the file, because what an awk does with a NUL differs between the
awks CI runs; tr under the C locale, because macOS tr under a UTF-8
locale stops at a byte that is not valid text ("Illegal byte
sequence"), and the gate died with no message of its own. Not with
bash `read -d ''`, which starts no process but
reads one byte at a time: measured, 1.9 s on an 800 KB changelog against
0.1 s for tr at any size. A missing changelog is left to the diagnostic
below.

## Changelog links

Nothing reads the changelog unless it is a regular file of its own. A
test with -f follows a symbolic link, so a link to a device skipped the
NUL check and the search tools read the device: a link to /dev/urandom
ran until it was killed, naming nothing. Every link is refused, wherever
it points and a broken one too: judging a target is more code, and the
target can change after the check. A wrong refusal fails closed.

## The version heading read

The heading format is pinned precisely because this line parses it, so
assert the date half too rather than trusting it to stay. Be exact about
what that buys: -m1 takes the first heading that MATCHES, so when the newest
heading has drifted and the older ones have not, this reads an older
release's version and the drift surfaces as a version disagreement rather
than as a complaint about the format. Measured, not assumed.

Anchored with a trailing $ deliberately: an unanchored match accepted a
heading carrying a trailing parenthetical in one of the two copies this file
replaces while the other refused it. That divergence is the drift this file
exists to end.

## The report line and the first heading

Print what was read before comparing it. In a workflow log this line is the
difference between a red that explains itself and a red that sends someone
to open three files.
Every value is printed through its masked copy. jq emits a value raw, a
version or a directory name may hold a line feed, and this line lands in
a public workflow log where a forged extra line would misreport what the
gate found. The comparisons below read the raw values, so the masking
cleans the report and hides nothing from the check.
Is the version heading the FIRST heading, or does something sit above it?
The three comparisons in this loop are satisfied by ANY matching heading, so
an `## [Unreleased]` heading above the newest release is invisible to them —
`grep -m1` skips it rather than rejecting it, and reads the release below.
That blindness let both plugins carry an open heading through an entire
release cycle while this gate printed agreement. Reported on every run;
enforced only for the plugin named by --released, because unreleased work is
normal and correct everywhere else.

## The heading walk

The walk keeps, from line to line, an open fence (with the
text before its fence characters, which every line inside must carry),
whether a list item can be open, and the previous line. It does not
follow Markdown's every rule. Each place it cuts a corner, it cuts toward
refusing: a wrong refusal fails closed and the changelog is fixed, while
a wrong pass would ship an open heading in a release. So while any list
item can be open every deep `##` is judged, a `-` under any line that is
not blank is an underline, only a line of spaces is blank, and a fence
is followed only while its shape is clean.
specs/024-gate-every-heading-form/research.md R2 gives the steps.

## The reverse walk

The walk reads entries_tsv, the name and source of every entry, which the
marketplace's one jq wrote at the top (market_read). One read for the whole
walk: an earlier shape read the names, then re-queried this same file once
per name to fetch the source of the entry it had just read — looking an
entry up by a value taken from that entry.

jq runs in its OWN statement, never in a process substitution feeding the
loop. A process substitution's exit status is invisible to `set -e`: the shell
waits for the loop, not for the producer. Measured, on a marketplace whose
SECOND entry has an object where a name should be — jq emits the first line,
errors on the second, and exits non-zero; the old shape read the one good line,
set entries=1, matched checked=1, and exited 0 having never validated the bad
entry's `source`, which pointed at a directory that did not exist. A leading
malformed entry died correctly, so only trailing ones escaped. Assigning first
puts the failure where errexit can see it, and the shape check in the same
jq stops such a file before any line is written. The loop is then fed by
printf over the assigned text, which cannot fail, and not by a herestring:
Git Bash hung, naming nothing, on a herestring of 65,536 to about 65,700
bytes (measured), a size a fork controls through one entry's name.
An empty result would make the loop below run zero times and pass vacuously.
The count comparison further down would not catch it either when the tree
holds no plugin directory — two zeroes agree.

## Traversal

`..` as a PATH COMPONENT, not as a substring. `*..*` also matched a
directory legitimately named "my..plugin" and refused it while naming a
traversal that was not there — a wrong diagnostic is its own defect, even
when it fails in the safe direction.

## The link walk count

No link on the way, as in the loop above: each leading part of the
source, then its .claude-plugin, then plugin.json, before the -f test
below follows any of them. The components are counted from the text
first, with no process and no file test, so a long source costs one
count and is refused whatever exists on disk: a count kept inside the
walk would never reach the bound, because the walk stops at the first
part that is not there, below which nothing can be a link. Each
leading part is cut off with prefix and suffix removal; with no
separator left the suffix removal returns the text unchanged, so the
walk ends when the part is the whole rest. The walk runs on to
.claude-plugin and plugin.json, the last two parts of the same path,
and stops at the first part that is not there; the count is of the
source alone. Entries naming the source walked last are neither
counted nor walked again: the count depends on the source alone, and
that source passed it. The count is taken in the C locale
(count_parts): under a UTF-8 locale, 2,000 entries naming one long
source cost about 30 s in the count alone (research R1).

## Analyser versions

Written as an `if`, not `A && B || C`. The chained form means the same
thing here, but it is the shape that silently does the wrong thing when B
can fail for a second reason, and CI's analyser reports it. WHICH analyser
matters, and this is measured rather than assumed: the runner image ships
0.9.0, which reports this, while 0.11.0 does not. A contributor with a
newer local copy therefore sees FEWER findings than the gate does.

## Vacuous passes

A loop over zero plugins passes vacuously, having verified nothing. That is
the defect this repository keeps rediscovering, and it is why the count above
is compared rather than trusted. Pin that this walk found work to do.
The working directory is not printed here either, for the reason given at
the refusal above.
