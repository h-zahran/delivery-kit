#!/usr/bin/env python3
"""The narrowing proof for the release form (Phase 26, research R10).

usage: python enumerate.py <path to scripts/check-versions.sh> [--full]

It extracts the release form's walk byte for byte from the gate script,
generates changelog fragments by combination, asks a CommonMark reader
(markdown-it-py, CommonMark mode) whether each one renders a level-2
heading other than the release heading, and runs the walk on each. A wrong
pass is a fragment that renders such a heading and that the walk passes.

For each narrowing (N1-N4) the gate either holds it or not: that is decided
by running the gate's walk on the narrowing's passing plant. For each one
it holds, a positive control (the narrowing with its guard removed, as an
explicit substitution) must find at least one wrong pass, or the proof
proves nothing.

The walk runs in batch, twice, in generated and in reversed case order;
the two runs must agree, and every disagreement and a fixed-seed sample of
rendered cases are rerun one file at a time with the unmodified walk.

Exit status: non-zero if the gate's walk passes a rendered heading, a kept
narrowing's control finds none, the two orders disagree, a sampled rerun
disagrees with the batch, or a control substitution changes nothing.

By default the third line before a case is drawn only from one
narrowing's own lines (the full set took far longer than the 30 minutes
the tasks allow); --full draws it from the whole vocabulary.
"""
import itertools
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
import time
from multiprocessing import Pool

from markdown_it import MarkdownIt

BUILTINS = set("""ARGC ARGIND ARGV BINMODE CONVFMT ENVIRON ERRNO FIELDWIDTHS
FILENAME FNR FPAT FS FUNCTAB IGNORECASE LINT NF NR OFMT OFS ORS PREC
PROCINFO RLENGTH ROUNDMODE RS RSTART RT SUBSEP SYMTAB TEXTDOMAIN""".split())

PLANTS = {
    'N1': ['1. a', '2. ```', '   code', '   ```'],
    'N2': ['<details>', '', 'x', '', '</details>', '', '```', 'code', '```'],
    'N3': ['### Plantnote', '---'],
    'N4': ['> Notes', '>', '> ---'],
}

# Each control removes the narrowing's guard. A list of (old, new) pairs,
# every one of which must change the walk.
CONTROLS = {
    'N1': [('if (marked || digits(m) > 9) odd = 1', 'if (marked) odd = 1'),
           ('if (first != "" && digits(first) <= 9 && rest !~ /^ *$/ && !odd) {',
            'if (first != "" && !odd) {')],
    'N2': [('        l = tolower(s)\n', '        return 0\n')],
    'N3': [('else if (depth == 0 && !marked && ind <= 3 && !listed && atx(text)) prev = "heading"',
            'else if (atx(rest)) prev = "heading"')],
    'N4': [('else if (line ~ /^>( ?>)* *$/) prev = "qblank"',
            'else if (line ~ /^ *>[> ]*$/) prev = "qblank"')],
}

OWN = {
    'N1': ['Para', '1. a', '1.', '5. a', '123456789. a', '1234567890. a', ''],
    'N2': ['<details>', '<div>', '<pre>', '<PRE>', '<x', '<!--', '-->', '</details>', ''],
    'N3': ['### Plantnote', 'Para', ''],
    # Gaps between two `>` marks: up to four spaces still open a nested
    # quote, five do not, and a tab can stand for either (found at review).
    'N4': ['> Notes', '>', '> >', '>  >', '>    >', '>     >', '>\t\t>', ''],
}
BEFORE = ['Para', '- a', '> Para', '1. a', '1.', '5. a', '123456789. a',
          '1234567890. a', '<details>', '<div>', '<pre>', '<PRE>', '<x', '<!--', '-->',
          '</details>', '### Plantnote', '> Notes', '>', '>     >', '>\t\t>', '', '  - b']
# Every container the Phase 25 rig covered, and the ordered markers at
# other indents that N1 must not take for a continuation.
PREFIX = ['', '  ', '   ', '    ', '> ', '>', '- ', '  - ', '1. ', '2. ', '2) ',
          '10. ', '1234567890. ', '- > ', '> - ', '    > ',
          '-\t', '>\t', '-     ', '-   ', '- - ', '* ', '  > ', '1) ',
          '> 1. ', '> 2. ', '- 2. ', '  2. ', '   2. ']
AFTER = [None, '## x', '  ## x', '    ## x', '---', 'Notes\n---', '> ---', '-->',
         '  Notes\n  ---', '> ## x']


def die(msg):
    print('FAIL ' + msg)
    sys.exit(2)


def cont(p):
    return ''.join(c if c == '>' else ' ' for c in p.expandtabs(4))


def bodies(p):
    c = cont(p)
    out = []
    for x, y in itertools.product(['', c], ['', c]):
        out.append([p + '```', x + '## x', y + '```'])
    for end in ['-->', '</pre>']:
        for x in ['', c]:
            out.append([p + '```', x + end, x + '## x', x + '```'])
    for b in ['### x', '>', '---', '--', '## x']:
        out.append([p + b])
    return out


def befores(full):
    yield ()
    for k in (1, 2):
        yield from itertools.product(BEFORE, repeat=k)
    if full:
        yield from itertools.product(BEFORE, repeat=3)
    else:
        seen = set()
        for own in OWN.values():
            for t in itertools.product(own, repeat=3):
                if t not in seen:
                    seen.add(t)
                    yield t


def cases(full):
    for b in befores(full):
        for p in PREFIX:
            for body in bodies(p):
                for a in AFTER:
                    lines = list(b) + body
                    if a is not None:
                        lines += a.split('\n')
                    yield '\n'.join(lines)


MD = None


def rendered(chunk):
    global MD
    if MD is None:
        MD = MarkdownIt('commonmark')
    out = bytearray()
    for frag in chunk:
        n = sum(1 for t in MD.parse(HEAD_TEXT + frag + '\n')
                if t.type == 'heading_open' and t.tag == 'h2')
        out.append(1 if n > 1 else 0)
    return bytes(out)


def walk_of(src):
    m = re.search(r"LC_ALL=C awk '\n(.*?)\n    ' \"\./\$p/CHANGELOG\.md\"\)\"", src, re.S)
    if not m:
        die('the walk was not found in the gate script')
    return m.group(1)


def value(src, name):
    m = re.search(r"^%s=(.*)$" % name, src, re.M)
    if not m:
        die('%s not found in the gate script' % name)
    v = m.group(1)
    return v[1:-1] if v.startswith("'") else v


def batch_walk(walk, gawk, env):
    """The walk, reading many cases from one stream separated by a marker
    line, with every global reset between cases."""
    if walk.count('function refuse(msg) { print msg; refused = 1; exit }') != 1:
        die('refuse() not found as expected')
    w = walk.replace('function refuse(msg) { print msg; refused = 1; exit }',
                     'function refuse(msg) { print cid; refused = 1; skip = 1; next }')
    begin = re.search(r'\n      BEGIN \{\n(.*?)\n      \}\n', w, re.S)
    if not begin:
        die('BEGIN not found as expected')
    end = re.search(r'\n      END \{\n.*\Z', w, re.S)
    if not end:
        die('END not found as expected')
    w = w[:end.start()] + '\n      END { if (cid != "" && fenced && !refused) print cid }\n'
    probe = tempfile.NamedTemporaryFile('w', suffix='.awk', delete=False)
    probe.write(w)
    probe.close()
    dump = probe.name + '.vars'
    subprocess.run([gawk, '--dump-variables=' + dump, '-f', probe.name],
                   input='', env=env, capture_output=True, text=True)
    names = []
    for ln in open(dump, encoding='utf-8', errors='replace'):
        n = ln.split(':', 1)[0].strip()
        if n and n not in BUILTINS and re.match(r'^[A-Za-z_]\w*$', n):
            names.append(n)
    os.remove(dump)
    os.remove(probe.name)
    reset = '; '.join('%s = ""' % n for n in sorted(set(names) - {'cid'}))
    head = ('      $0 ~ /^\\001CASE / { if (cid != "" && fenced && !refused) print cid; '
            + reset + '; ' + begin.group(1).strip().replace('\n', '; ')
            + '; cid = $2; next }\n      skip { next }\n')
    i = w.index('\n      {\n')
    return w[:i] + '\n' + head + w[i:]


def run_batch(prog, frags, order, gawk, env, tmp):
    path = os.path.join(tmp, 'stream.txt')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        for i in order:
            f.write('\x01CASE %d\n%s%s\n' % (i, HEAD_TEXT, frags[i]))
    pf = os.path.join(tmp, 'batch.awk')
    open(pf, 'w', encoding='utf-8', newline='\n').write(prog)
    r = subprocess.run([gawk, '-f', pf, path], env=env, capture_output=True, text=True)
    if r.returncode != 0:
        die('the batch walk failed: ' + r.stderr[:400])
    return set(int(x) for x in r.stdout.split())


def refused_one(walk, frag, gawk, env, tmp):
    path = os.path.join(tmp, 'one.md')
    open(path, 'w', encoding='utf-8', newline='\n').write(HEAD_TEXT + frag + '\n')
    pf = os.path.join(tmp, 'one.awk')
    open(pf, 'w', encoding='utf-8', newline='\n').write(walk)
    r = subprocess.run([gawk, '-f', pf, path], env=env, capture_output=True, text=True)
    return r.stdout.strip() != ''


def full_gate(gate, frag, bash, tmp):
    """The whole gate script, run as CI runs it, on a one-plugin fixture
    built from the repository the gate script sits in."""
    root = os.path.dirname(os.path.dirname(os.path.abspath(gate)))
    fx = os.path.join(tmp, 'fixture')
    shutil.rmtree(fx, ignore_errors=True)
    os.makedirs(os.path.join(fx, '.claude-plugin'))
    os.makedirs(os.path.join(fx, 'handoff', '.claude-plugin'))
    shutil.copy(os.path.join(root, 'handoff', '.claude-plugin', 'plugin.json'),
                os.path.join(fx, 'handoff', '.claude-plugin', 'plugin.json'))
    import json
    mk = json.load(open(os.path.join(root, '.claude-plugin', 'marketplace.json'), encoding='utf-8'))
    mk['plugins'] = mk['plugins'][:1]
    json.dump(mk, open(os.path.join(fx, '.claude-plugin', 'marketplace.json'), 'w', encoding='utf-8'))
    head = next(ln for ln in open(os.path.join(root, 'handoff', 'CHANGELOG.md'), encoding='utf-8')
                if re.match(r'^## \[[0-9]', ln)).rstrip('\n')
    open(os.path.join(fx, 'handoff', 'CHANGELOG.md'), 'w', encoding='utf-8', newline='\n').write(
        head + '\n\nPlain text.\n\n' + frag + '\n')
    r = subprocess.run([bash, os.path.abspath(gate), '--released', 'handoff'], cwd=fx,
                       capture_output=True, text=True)
    return r.returncode != 0


def main():
    if len(sys.argv) < 2:
        die('usage: enumerate.py <check-versions.sh> [--full]')
    t0 = time.time()
    gate = sys.argv[1]
    full = '--full' in sys.argv[2:]
    src = open(gate, encoding='utf-8').read()
    walk = walk_of(src)
    gawk = shutil.which('gawk') or shutil.which('awk')
    bash = shutil.which('bash')
    if not gawk or not bash:
        die('gawk and bash are needed')
    # What this run judged, so its result names the walk it proves.
    import hashlib
    import markdown_it
    where = os.path.dirname(os.path.abspath(gate))
    head = subprocess.run(['git', '-C', where, 'rev-parse', 'HEAD'],
                          capture_output=True, text=True).stdout.strip() or 'unknown'
    dirty = subprocess.run(['git', '-C', where, 'diff', '--quiet', 'HEAD', '--', os.path.abspath(gate)]).returncode
    print('walk sha256 %s' % hashlib.sha256(walk.encode('utf-8')).hexdigest())
    print('gate at commit %s%s' % (head, ', changed in the working tree' if dirty else ''))
    print('reader markdown-it-py %s, CommonMark mode' % markdown_it.__version__)
    env = dict(os.environ, DATED_RE=value(src, 'dated_re'),
               LINE_LIMIT=value(src, 'line_limit'), QUOTE_CUT=value(src, 'quote_cut'),
               LC_ALL='C')
    tmp = tempfile.mkdtemp()
    frags = list(cases(full))
    n = len(frags)
    print('cases %d (%s third line before)' % (n, 'full' if full else 'own'))
    with Pool(max(1, (os.cpu_count() or 2) - 1)) as pool:
        size = 4000
        parts = pool.map(rendered, [frags[i:i + size] for i in range(0, n, size)])
    flags = b''.join(parts)
    h2 = [i for i in range(n) if flags[i]]
    print('rendered a level-2 heading: %d' % len(h2))

    # The extracted walk must judge as the whole gate does: check a few
    # cases, refused and passed, against the gate script itself.
    probe = [h2[0], h2[len(h2) // 2], h2[-1]] + [i for i in range(n) if not flags[i]][:3]
    for i in probe:
        if full_gate(gate, frags[i], bash, tmp) != refused_one(walk, frags[i], gawk, env, tmp):
            die('the extracted walk and the gate script disagree on %r' % frags[i])

    # Which narrowings the gate holds: its own walk on each passing plant.
    kept = {k: not refused_one(walk, '\n'.join(v), gawk, env, tmp) for k, v in PLANTS.items()}

    failed = False
    walks = [('gate', walk)]
    for k in sorted(CONTROLS):
        if not kept[k]:
            continue
        w = walk
        for old, new in CONTROLS[k]:
            if w.count(old) != 1:
                die('control %s: substitution matched %d times: %r' % (k, w.count(old), old[:60]))
            w2 = w.replace(old, new)
            if w2 == w:
                die('control %s: substitution changed nothing' % k)
            w = w2
        walks.append(('control ' + k, w))

    order = list(range(n))
    rng = random.Random(26)
    sample = rng.sample(h2, min(2000, len(h2)))
    for name, w in walks:
        prog = batch_walk(w, gawk, env)
        fwd = run_batch(prog, frags, order, gawk, env, tmp)
        rev = run_batch(prog, frags, list(reversed(order)), gawk, env, tmp)
        diff = fwd ^ rev
        for i in sorted(diff):
            print('DISAGREE %s case %d: %r' % (name, i, frags[i]))
        if diff:
            failed = True
        wrong = [i for i in h2 if i not in fwd]
        print('%s: cases %d, rendered %d, wrong passes %d' % (name, n, len(h2), len(wrong)))
        if name == 'gate':
            for i in sample:
                if refused_one(w, frags[i], gawk, env, tmp) != (i in fwd):
                    print('SAMPLE DISAGREES case %d: %r' % (i, frags[i]))
                    failed = True
            for i in wrong[:20]:
                print('  WRONG PASS %r' % frags[i])
            if wrong:
                failed = True
        else:
            for i in wrong[:3]:
                print('  control finds %r' % frags[i])
            if not wrong:
                print('  the control found no wrong pass, so the proof proves nothing')
                failed = True
    for k in sorted(PLANTS):
        print('%s %s' % ('KEPT' if kept[k] else 'REVERTED', k))
    print('run time %d s' % (time.time() - t0))
    shutil.rmtree(tmp, ignore_errors=True)
    sys.exit(1 if failed else 0)


HEAD_TEXT = '## [1.0.0] - 2026-01-01\n\nPlain text.\n\n'

if __name__ == '__main__':
    main()
