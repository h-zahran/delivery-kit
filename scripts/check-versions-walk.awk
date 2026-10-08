# The release gate's heading walk: scripts/check-versions.sh runs it, as
# `awk -f` on one plugin's CHANGELOG.md, and nothing else does but the
# suite's direct tests of it. It reads DATED_RE (the dated version heading
# pattern), LINE_LIMIT (the longest line it judges, in bytes) and QUOTE_CUT
# (the length it cuts a quoted line to) from the environment, and the gate
# runs it under LC_ALL=C. It prints nothing for a changelog it accepts, or
# one refusal; the gate adds the plugin's name before it and its verdict
# after. Why the walk exists and what it does are written above the call in
# the gate, and step by step in specs/024-gate-every-heading-form/research.md
# R2. The program below is the one that sat inside the gate, unchanged.
      function expand(s,   o, i, c, col) {
        if (index(s, "\t") == 0) return s
        o = ""; col = 0
        for (i = 1; i <= length(s); i++) {
          c = substr(s, i, 1)
          if (c == "\t") { do { o = o " "; col++ } while (col % 4 != 0) }
          else { o = o c; col++ }
        }
        return o
      }
      function lead(s,   i) { i = 1; while (substr(s, i, 1) == " ") i++; return i - 1 }
      function run(s, ch,   i) { i = 1; while (substr(s, i, 1) == ch) i++; return i - 1 }
      function rtrim(s) { sub(/ +$/, "", s); return s }
      function show(s,   t) {
        t = ""
        if (length(s) > cut) { s = substr(s, 1, cut); t = " [cut]" }
        gsub(/[^[:print:]]/, "?", s)
        return s t
      }
      function cont(s,   o, i) {
        o = ""
        for (i = 1; i <= length(s); i++) o = o (substr(s, i, 1) == ">" ? ">" : " ")
        return o
      }
      function atx(s,   k) { k = run(s, "#"); return k >= 1 && k <= 6 && (length(s) == k || substr(s, k + 1, 1) == " ") }
      function closer(s,   k) { k = run(s, fch); return k >= flen && substr(s, k + 1) ~ /^ *$/ }
      # One definition of a fence opener for every rule that asks: a
      # backtick opener holding a further backtick is text, not a fence.
      function opener(s,   c, k) {
        c = substr(s, 1, 1)
        if (c != "`" && c != "~") return 0
        k = run(s, c)
        return k >= 3 && !(c == "`" && index(substr(s, k + 1), "`"))
      }
      # One quote marker off the front: any indent, `>`, one optional space.
      function unquote(s) { s = substr(s, lead(s) + 2); if (substr(s, 1, 1) == " ") s = substr(s, 2); return s }
      function refuse(msg) { print msg; refused = 1; exit }
      # The digits a list marker starts with, counted, not matched.
      function digits(s,   i) { i = 1; while (substr(s, i, 1) ~ /[0-9]/) i++; return i - 1 }
      # An HTML block that only its own end marker closes: a comment, a
      # processing instruction, a declaration, CDATA, or script, pre, style
      # or textarea. Every other kind ends at a blank line.
      function hardhtml(s,   l) {
        l = tolower(s)
        return l ~ /^<[!?]/ || l ~ /^<(script|pre|style|textarea)/
      }
      BEGIN {
        prev = "blank"; LM = "^([-*+]|[0-9]+[.)])( |$)"
        limit = ENVIRON["LINE_LIMIT"] + 0; cut = ENVIRON["QUOTE_CUT"] + 0
      }
      {
        # A line too long to judge is refused before anything reads it, and
        # a CR is refused rather than split: Markdown reads a CR as a line
        # end, and a split line could be a heading or close a fence. Both
        # come before the fence rules, so a fence hides neither.
        if (length($0) > limit)
          refuse("line " NR " is " length($0) " bytes long, longer than the release form judges: \047" show($0) "\047")
        if (index($0, "\r"))
          refuse("line " NR " holds a carriage return, which Markdown reads as a line end: \047" show($0) "\047")

        # The ordered item on the line before, if the walk accepted it.
        pok = cok; pdel = cdel; ppre = cpre; cok = 0

        line = expand($0)
        # Only a line of spaces is blank. A line of `>` markers alone is
        # not: deep in a list item it is text, and calling it blank would
        # end the item and hide a deep heading below it.
        blank = (line ~ /^ *$/)

        # An open fence: every line inside must carry the opener prefix.
        # closer() needs a run of at least the opener length, so it also
        # proves the line starts with the fence character.
        if (fenced) {
          inpre = (substr(line, 1, length(fpre)) == fpre)
          body = substr(line, length(fpre) + 1)
          if (inpre && closer(body)) { fenced = 0; prev = "text"; praw = $0; pnr = NR; next }
          if (line ~ /^[ >]*$/) {
            if (rtrim(line) == rtrim(fpre)) next
          } else if (inpre && !closer(substr(body, lead(body) + 1))) next
          refuse("the code fence opened at line " fnr " may already have ended at line " NR ", which holds \047" show($0) "\047")
        }

        # Quote markers, then what is left of the line.
        t = line; depth = 0
        while (substr(t, lead(t) + 1, 1) == ">") { t = unquote(t); depth++ }
        ind = lead(t)
        text = substr(t, ind + 1)
        under = (text ~ /^-+ *$/)

        # An unindented line ends every list item: after a blank line, or
        # when it starts a heading or a fence. Straight after item text, a
        # plain line is a lazy continuation and does not.
        if (depth == 0 && ind == 0 && !blank && text !~ LM)
          if (prev == "blank" || atx(text) || opener(text)) listed = 0

        # A setext underline: the previous text line is a heading. Checked
        # before list markers come off: a bare `-` here is an underline.
        if (under && prev == "text")
          refuse("line " pnr " holds \047" show(praw) "\047, underlined at line " NR)

        # List markers and quote markers, in any order. After a text line
        # an ordered marker other than 1 does not start a list, so a fence
        # on it would not be a fence: such a marker sets odd, and odd
        # refuses the fence. One shape is let through (N1): the FIRST marker
        # on the line, of one to nine digits, after a blank line, or continuing
        # the ordered item on the line before (same text before the marker,
        # same delimiter). CommonMark takes at most nine digits.
        rest = text; marked = 0; odd = 0; first = ""
        while (1) {
          r = substr(rest, lead(rest) + 1)
          if (match(r, LM)) {
            m = substr(r, 1, RLENGTH)
            if (!marked && m ~ /^[0-9]/) {
              first = m; fdel = substr(m, digits(m) + 1, 1)
              fpfx = substr(line, 1, length(line) - length(r))
            }
            if (m ~ /^[0-9]/ && m !~ /^1[.)]/) {
              if (marked || digits(m) > 9) odd = 1
              else if (prev != "blank" && !(pok && pdel == fdel && ppre == fpfx)) odd = 1
            }
            rest = substr(r, RLENGTH + 1); marked = 1; continue
          }
          if (substr(r, 1, 1) == ">") { rest = unquote(r); continue }
          rest = r
          break
        }
        if (marked) listed = 1
        # This line is an accepted ordered item for the next line: its first
        # marker ordered, one to nine digits, the item not empty, not odd.
        if (first != "" && digits(first) <= 9 && rest !~ /^ *$/ && !odd) {
          cok = 1; cdel = fdel; cpre = fpfx
        }

        # A line that starts with `<` may open an HTML block, and a fence
        # line inside one is not a fence: it would hide what follows it.
        # Every `<` line is classified, whatever came before: a block that
        # only its own end marker closes (hard) refuses every fence opener
        # from here on; any other kind (soft) ends at a line of spaces (N2).
        if (blank) soft = 0
        if (substr(rest, 1, 1) == "<") {
          if (hardhtml(rest)) { hard = 1; hnr = NR } else { soft = 1; snr = NR }
        }

        # A fence opener, at any indent, unless Markdown might not open it.
        if (opener(rest) && odd)
          refuse("line " NR " opens a code fence on an ordered list marker other than 1, which may not start a list: \047" show($0) "\047")
        if (opener(rest) && (hard || soft))
          refuse("line " NR " opens a code fence that the HTML at line " (hard ? hnr : snr) " may hold: \047" show($0) "\047")
        if (opener(rest)) {
          fc = substr(rest, 1, 1)
          fenced = 1; fch = fc; flen = run(rest, fc)
          fpre = cont(substr(line, 1, length(line) - length(rest)))
          fnr = NR; ftext = $0; next
        }

        # Indented code, when no list item can be open to claim the line.
        if (ind >= 4 && !marked && !listed) { prev = "text"; praw = $0; pnr = NR; next }

        # An ATX level-2 heading, in any container.
        if (rest ~ /^##( |$)/ && $0 !~ ENVIRON["DATED_RE"])
          refuse("line " NR " holds \047" show($0) "\047, which is not a dated version heading")

        # Every line that is not blank counts as text for the underline
        # test, a fence closer and an underline included: a `-` run under
        # any of them is refused rather than read as a break. Two kinds are
        # let through. An ATX heading with no container and at most three
        # columns of indent, while no list item can be open, is a heading
        # wherever it stands (N3). A line of `>` marks starting at column
        # zero, with at most one space between two marks, is a blank line
        # inside a quote, which ends any paragraph (N4). A wider gap is not:
        # after five spaces a `>` is text that continues the paragraph, and
        # the run below it is an underline. Found at pull request review;
        # tabs are expanded before this test. Neither counts as blank for
        # any other rule.
        if (blank) prev = "blank"
        else if (depth == 0 && !marked && ind <= 3 && !listed && atx(text)) prev = "heading"
        else if (line ~ /^>( ?>)* *$/) prev = "qblank"
        else prev = "text"
        praw = $0; pnr = NR
      }
      END {
        if (fenced && !refused)
          print "line " fnr " opens a code fence that is never closed: \047" show(ftext) "\047"
      }
