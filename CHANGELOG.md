# mdstack — Changelog

## Unreleased — mdstack::parser 0.7.0

`lib/mdstack/parser-0.7.0.tm` (was `parser-0.6.5.tm`).

### Changed — emphasis via the CommonMark delimiter stack

The scanner resolved each `*`/`_` run on sight, with a regexp per attempt. That
shape cannot express three of CommonMark's rules, and no amount of patching
would have changed it:

- **flanking of the OPENER** — `** foo bar**` came out as
  `<em>*</em><em>foo bar</em>*`; a run followed by whitespace must stay literal.
- **the rule of 3** — `a**"foo"**` came out as `a*<em>"foo"</em>*`; a pair whose
  run lengths sum to a multiple of 3 (when one side could do both jobs) must not
  match.
- **intraword `_`** — `_foo_bar_baz_` stayed literal instead of becoming one
  emphasis; the inner underscores may not close.

Now `parseInlines` **tokenises** each delimiter run into a `_delim` node with its
`canOpen`/`canClose` flags, and `_processEmphasis` matches openers and closers
afterwards over the finished node list — the standard two-pass algorithm.
Leftover delimiters become literal text, and adjacent text nodes are merged
(`_foo_bar_baz_` is now a single text node inside one `emphasis`, not five).

**Nesting of `***` changed to CommonMark's:** `<em><strong>x</strong></em>` — the
strong pair is consumed first, the leftover single pair wraps it. It used to be
`strong[emphasis[...]]`. Both render bold+italic; the CommonMark order is the
reference now.

### Numbers

| | before | after |
|---|---|---|
| CommonMark emphasis section | 46/132 | **77/132** |
| CommonMark strict, overall | 285/655 (43.5%) | **321/655 (49.0%)** |
| CommonMark lenient, overall | 327/655 | **363/655 (55.4%)** |
| mdstack core suite | 638/0 | **648/0** |

Cross-checked: docir 763/0, mdhelp 7 suites/0. Test expectations that asserted
the old node granularity (an escaped run as three text nodes) or the old `***`
nesting were updated in `parser-inline-fixes.tcl`,
`parser-emphasis-flanking.tcl` and mdhelp's `test_commonmark.tcl`.

## Unreleased — mdstack::parser 0.6.5

`lib/mdstack/parser-0.6.5.tm` (was `parser-0.6.4.tm`).

- **`*` emphasis scans candidate closing runs.** `_tryEmphasis` used a lazy
  regexp (`{^\*(.+?)\*}`), which tries exactly ONE candidate closer: the first
  `*` after the opener. In `*italic **bold** text*` that candidate is the
  opening star of `**bold**`; it fails right-flanking (a space precedes it), so
  the match was rejected and the whole run collapsed to literal text — the
  emphasis was lost although a perfectly good closer sat at the end of the line.
- The new `_emphasisInner` walks the delimiter runs and takes the first
  candidate that flanks. Pass 1 prefers a run of *exactly* the opener's length
  (a balanced closer — this is what makes the nested case work); pass 2 falls
  back to any run of at least that length, so `*foo***` still closes at the
  first star of the trailing run, as CommonMark wants.
- CommonMark conformance: emphasis 44/132 → **46/132**, overall 283 → **285**
  strict (325 → **327** lenient). Six new cases in
  `tests/parser-emphasis-flanking.tcl`.
- Found because the mdhelp suite demanded `docir 1.0` in its dependency check —
  a version that cannot exist — so it aborted before running and had been
  hiding this failure.

## Unreleased — mdstack::parser 0.6.4

`lib/mdstack/parser-0.6.4.tm` (was `parser-0.6.3.tm`).

- **GFM tables: cells split on unescaped pipes only.** `parseTableRow` walked
  the row with `split $line "|"`, so a `\|` inside a cell was treated as a
  column separator: the backslash stayed in the output, the rest of the cell
  moved into a phantom column, and the column count no longer matched the
  header (visible in HTML *and* PDF).
- A `\|` is now resolved to a literal `|` in the cell text — as GFM requires,
  this also happens inside code spans, where the generic CommonMark backslash
  escape does not apply and the inline parser would never see it. `\\` is left
  for the inline parser, and the pipe following it still delimits.
- A trailing row pipe is only stripped when it is not escaped (`| a | b \|`
  ends in a literal pipe, not an empty cell).
- The alignment row runs through the same splitter and is unaffected.
- New suite `tests/parser-tables.tcl` (13 tests). CommonMark conformance
  unchanged (283/655 strict, 325 lenient — the spec suite has no GFM tables).

## Unreleased — mdstack::parser 0.6.3

`lib/mdstack/parser-0.6.3.tm` (was `parser-0.6.2.tm`).

- **List items can hold nested blocks.** Indented code, block quotes and
  fenced blocks that belong to a list item (indented to the item's content
  column) are now parsed *inside* the item (`_mkListItem` runs the item body
  through `parseBlocks`) instead of being flattened. Renders nested in the
  docir html/pdf/roff renderers (odt keeps them flat).
- **Deliberate behaviour preserved:** a 4-space-indented block after a tight
  list still forms a *separate* code block (the collection rule only pulls in
  genuine sub-blocks — code at content-col+4, quotes, fences, sub-list markers),
  so `parser-loose-lists` / `parser-indented` / `parser-multiline-list` are
  unchanged.
- Conformance: List items 14 -> 16 / 48 (lenient 323 -> 325).

## Unreleased — mdstack::parser 0.6.2

`lib/mdstack/parser-0.6.2.tm` (was `parser-0.6.1.tm`).

- **Ordered lists preserve their start number.** A list beginning at a number
  other than 1 now carries `start N`, rendered as `<ol start="N">` (e.g.
  `123456789. ok`, `5) x`). Requires the matching docir mdSource/html change.
- Conformance (structural): 270 -> 274 / 655; List items 20.8 -> 27.1 %.

## Unreleased — mdstack::parser 0.6.1

`lib/mdstack/parser-0.6.1.tm` (was `parser-0.6.0.tm`).

- **Emphasis flanking: symbol/currency punctuation.** `_isPunct` now follows
  CommonMark's "Unicode P *and* S" punctuation definition, so delimiters next to
  `$` `£` `€` and the ASCII symbols `+ < = > ^ ` + "`" + ` | ~` flank correctly —
  e.g. `*$*alpha.` stays literal instead of emphasising `$`.
- **`+` bullets and `N)` ordered markers** are now recognised (previously a
  line like `+ item` or `3) item` became a paragraph).
- **New list on marker / delimiter change** (CommonMark): `- a` then `+ b` are
  two `<ul>`s; `1.` then `3)` two `<ol>`s, instead of the second marker
  becoming a paragraph.
- Conformance (structural): 269 -> 270 / 655; Lists 19.2 -> 23.1 %. No
  regressions in the parser test suite.

## Unreleased — mdstack::pdf 0.3 (Adapter)

`lib/mdstack/pdf-0.3.tm` (was `pdf-0.2.tm`); pkgIndex bumped to 0.3.

- **PDF/A and AES encryption restored.** `-pdfa` (`1b`/`2b`/`3b`),
  `-userpassword` and `-ownerpassword` are forwarded to `docir::pdf`, which
  threads them to `pdf4tcl::new`. Since the 2026-05-06 DocIR cutover these had
  been silently dropped, so callers received plain / unencrypted PDFs without
  any notice.
- **`-toc` wired to docir-pdf's two-pass TOC** (`generateToc`, with page
  numbers). Previously ignored.
- Requesting PDF/A together with a password now raises a clear error — the two
  are mutually exclusive — instead of emitting an invalid encrypted-yet-PDF/A
  file.
- Requires **docir::pdf 0.3** and **pdf4tcllib 0.3**.
- With this, nothing from the original `mdpdf` renderer remains unported.


## 0.6.0

Doctools-oriented parser fixes (rendering of tcllib `embedded/md` pages) plus a
viewer performance option. Paired with **DocIR 0.1.1 + renderer-tk 0.2**.

### parser 0.6.0

#### Fixed
- **Reference-link comment definitions no longer leak into the output.**
  doctools metadata lines of the form `[//NNN]: # (text)` were emitted as a
  paragraph because the reflink regex only accepted `"…"` titles. It now also
  accepts `'…'` and `(…)` titles (with backslash escapes), so these definition
  lines are consumed instead of shown.
- **Indented definition-list bodies stay inside the list item.** A doctools
  entry `  - __cmd__` (marker col 2, content col 4) followed by a 4-space
  indented body kept its continuation as the item's body instead of detaching
  it into an indented code block. Top-level lists keep their previous closing
  behaviour (no regression).

#### Added
- **Underscore emphasis / strong (`_em_`, `__strong__`).** Underscore emphasis
  now follows the CommonMark intraword rules: a `_` inside a word does not
  toggle, so `snake_case` stays literal, while `__name__` becomes strong.
  doctools uses `__name__` extensively for command names — these now render
  bold. (Complements the `*`-flanking work from 0.5.0.)

### viewer 0.4

#### Added
- **`-tableframemax` option (default 12).** In `-tablemode frame`, tables with
  more rows than the threshold fall back to fast text rendering — one label
  widget per cell is O(n²) on `grid`. `-tableframemax 0` forces text for all
  tables (fastest). The tcllib keyword index dropped from ~21 s to ~1.5 s.
  Added to `create` / `configure` / `cget`.

## 0.5.0

### Fixed
- **Indented code keeps trailing spaces.** `parseIndentedCode` no longer
  trims trailing whitespace from code lines (`    foo  ` -> `foo  `), matching
  CommonMark. Indented code blocks 66.7->75.0 %.

### Added
- **Soft line breaks are now structured nodes.** A soft line break between two
  lines of a paragraph emits a `softbreak` inline node (mirroring the existing
  `linebreak` for hard breaks) instead of being flattened to a space at parse
  time. Renderers decide the presentation: docir HTML emits a newline
  (CommonMark; visually identical to a space in a browser), while PDF / ODT /
  roff / Tk viewer / plain text render a space -- so non-HTML output is
  unchanged. This was the single largest conformance lever: Paragraphs 50->100 %,
  Soft line breaks 0->100 %, Setext 59.3->77.8 % (multi-line content now
  matches), Indented code +1; overall strict 39.1->43.1 %, lenient 45.8->49.9 %.
- **Link destinations rewritten (`_tryLink`).** The destination is now parsed
  with a hand-written scanner instead of a single regex: it supports
  backslash-escaped characters, balanced parentheses (`[x](foo(and(bar)))` ->
  `foo(and(bar))`), and treats unbalanced parens as "not a link". `<bracketed>`,
  empty and titled destinations are unchanged. Conformance: Links 47.8->57.8 %
  (combined with the docir-side title/empty-href/percent-encoding fixes);
  parser side strict 37.1->39.1 %, lenient 43.8->45.8 %.
- **Character references (numeric + named).** Inline decimal (`&#35;`),
  hexadecimal (`&#x22;` / `&#X22;`) and HTML5 named (`&amp;`, `&copy;`,
  `&mdash;`, multi-codepoint like `&ngE;`, ...) entities are now decoded to
  their character(s). Invalid, out-of-range, NUL or surrogate numeric
  codepoints map to U+FFFD; named references must be semicolon-terminated
  (CommonMark) and unknown names are left literal. References inside code spans
  stay literal. The named table (2125 semicolon forms) is derived from the
  WHATWG HTML Standard (html.spec.whatwg.org/entities.json) and stored as
  ASCII-safe codepoints.
  Note (Tcl 8.6): astral characters (codepoint > U+FFFF, a handful of
  math-script names) decode to U+FFFD on Tcl 8.6 because `format %c` is limited
  to the BMP there; they decode correctly on Tcl 9.0. Conformance: Entity and
  numeric character references 29.4→64.7 %; overall strict 33.6→34.5 %,
  lenient 40.3→41.2 %.
- **Thematic breaks generalised.** `isHr` now matches any line of three or more
  identical markers (`-`, `*`, `_`) separated by arbitrary spaces/tabs (e.g.
  `** * ** * **`, `-     -      -      -`) and is indent-aware: a marker line
  indented 4+ spaces is indented code, not a thematic break. Conformance:
  Thematic breaks 63.2→78.9 %; overall strict 33.1→33.6 %, lenient 39.7→40.3 %.
- **Setext heading precedence.** A line indented 4+ spaces is now treated as
  indented code, not a setext title; a line that is itself a thematic break
  cannot be a setext title; and a setext underline must be indented 0-3 spaces
  (4+ is a paragraph continuation). Fixes cases like `    foo` + `---` (indented
  code, not `<h2>`). Conformance: Setext headings 48.1→59.3 %; overall strict
  33.0→33.1 %, lenient 39.1→39.7 %.
- **Hard line breaks.** A hard break (two trailing spaces or a trailing
  backslash) now applies only BETWEEN lines: at the end of a block it produces
  no `<br>` (trailing spaces dropped, trailing backslash kept literal). The
  hard-break placeholder no longer leaks into code spans (line endings collapse
  to a space there). Conformance: Hard line breaks 46.7→60.0 %; overall strict
  32.7→33.0 %, lenient 38.6→39.1 %.
- **Code spans (CommonMark).** Arbitrary backtick-run length with exact-length
  closing run (so `` `` foo ` bar `` `` keeps the inner backtick), line endings
  collapse to spaces, and a single leading+trailing space is stripped unless the
  content is all spaces. New test `parser-code-spans.tcl`. Conformance: Code
  spans 40.9→63.6 %; overall strict 31.6→32.7 %, lenient 37.6→38.6 %.
- **Backslash escapes & entities.** A backslash now escapes any ASCII
  punctuation character (previously only a subset); apostrophes are no longer
  HTML-escaped to `&#39;` in docir output (matches CommonMark, which leaves `'`
  literal and only escapes `& < > "`). New test `parser-backslash.tcl`.
  Autolinks accept any URI scheme. Conformance moved to strict 31.6 % /
  lenient 37.6 % (Backslash escapes 46.2→53.8 %, broad apostrophe gains).
- **Links / images (CommonMark coverage).** Inline links and images now accept
  empty text (`[](u)`), empty destination (`[t]()`), `<bracketed>` destinations,
  and `"..."` / `'...'` / `(...)` titles. Image `alt` is now the plain text of the
  label (markup stripped), and reference images support the collapsed `![a][]`
  and shortcut `![a]` forms. Angle autolinks now accept any valid URI scheme
  (`<irc:…>`, `<MAILTO:…>`, `<localhost:5001/…>`, custom schemes), not just
  http(s)/email. New test `parser-link-features.tcl`. Conformance:
  Links 27.8→31.1 %, Images 31.8→63.6 %, Autolinks 52.6→78.9 %; overall
  strict 28.2→30.5 %, lenient 34.2→36.5 %.
- **Loose lists / multi-paragraph list items (parser).** A blank line inside a
  list item now starts a new paragraph instead of being merged into one; the
  list dict carries `loose 1` when any blank separates items or blocks.
  `parseListBlock` keeps the list open across a blank line followed by a 2-3
  space continuation, while a 4-space/tab indented block after the list stays a
  separate code block (unchanged mdstack semantics). The Tk viewer already
  iterates all item blocks, so loose lists render there immediately.
- New test `parser-loose-lists.tcl`.

### Changed
- `mdstack::parser` 0.2 → **0.5.0** (file `parser-0.5.0.tm`, `lib/pkgIndex.tcl`
  updated). Consumers use minimum-version requires, satisfied by 0.5.0.
- Emphasis now follows CommonMark flanking (whitespace + punctuation): a `*`
  opens only when left-flanking and closes only when right-flanking
  (`a * foo*`, `*foo *`, `a*"foo"*` are literal; intraword `foo*bar*baz` and
  line-start `*(foo)*` still emphasise). New test `parser-emphasis-flanking.tcl`.
- `mdstack::viewer` 0.3 and `mdstack::validator` 0.1 now handle the new
  `softbreak` inline node — the viewer renders it as a space (so multi-line
  paragraphs keep word spacing in the Tk view) and the validator accepts it
  as a known inline type.

### docir side (paired, implemented additively)
- `docir::md::_mapList` + `docir::html` now render loose lists correctly:
  multi-paragraph items become `<li><p>…</p><p>…</p></li>`, tight items stay
  inline. Additive only — `listItem` gains optional `blocks`, the list meta gains
  `loose`; pdf/roff/odt read `content` (now carrying all paragraph text) so no
  output regresses. Loose lists now work in the Tk viewer, mdstack::html,
  md2html and md2tilehtml.
- Conformance: strict 28.2 %, lenient 34.2 % (List items 16.7 %, Lists 19.2 %).

## 2026-05-16 — Parser v0.2.10: Setext headings + math

### Added

- **Setext-style headings** in `parser-0.2.tm`:
  - `Title\n=====` → `heading level 1`
  - `Subtitle\n-----` → `heading level 2`
  - Setext check runs before HR check, so `Text\n---` is heading,
    not HR.
  - Standalone `---` (after blank line) remains an HR as before.
- **Inline math** (`$...$`) parsed as new inline node
  `{type math display 0 text "..."}`. Conservative regex rules
  prevent false positives like `$5 and $10`:
  - No space/digit directly after opening `$`
  - No digit directly after closing `$`
  - No nested `$` characters
- **Display math** (`$$...$$`) parsed as new block node
  `{type math_block display 1 content "..."}`. Supports:
  - Single-line: `$$E=mc^2$$`
  - Multi-line: `$$` on own line, content lines, `$$` on own line
  - Content can start on same line as opening `$$`

### Changed

- **`parser-0.2.tm`** version bumped from 0.2.9 to 0.2.10 in the
  history comment.
- **`tests/extended.tcl`** extended with 11 new tests (setext-1..5,
  math-inline-1..3, math-block-1..3, mermaid-1). Total: 30 tests,
  all passing.

### Notes on Mermaid

The parser already recognized fenced code blocks with the `mermaid`
language tag (because every fenced code retains its `language`
field). No parser change was needed. Rendering as
`<pre class="mermaid">` is done in `docir::html` (see DocIR
CHANGES 2026-05-16).

### Compatibility

No public API changes. The new inline `math` and block `math_block`
node types are additive — consumers that don't handle them fall
through their default branches (rendered as text or skipped).

---

## 2026-05-13 — Repo hygiene + test stability

**Affected consumers:** no API changes. Consumers (man-viewer,
mdhelp) need no adjustments.

### Removed

- **`tests/test-toc.pdf`** — test output was version-controlled
  although `.gitignore` explicitly listed `test-toc.pdf`.

### Added

- **`tests/_paths.tcl`** — shared path configuration for tests.
  Searches for `docir` in several locations (`$DOCIR_HOME`, sibling
  repo, parent sibling, `~/lib/tcltk/docir`, system default).
  Provides the `haveDocir` helper for self-skipping.

  Sourced by `basic.tcl`, `test-docir-md.tcl`,
  `test-emoji-pdf.tcl`, `test-emoji-sanitize.tcl` — previously the
  file was missing, and these three tests crashed with
  "no such file or directory".

### Fixed
- **Standalone images reuse `_tryImage`.** `isStandaloneImage` /
  `parseStandaloneImage` no longer use a separate naive regex; they delegate to
  the inline image parser, so angle-bracket destinations (`![a](<url>)` ->
  `url`), titles (`![a](p.jpg "Cap")`) and plain-text alt (markup stripped) are
  handled consistently. Fixes `src="&lt;url&gt;"` in docir HTML output.
  (No CommonMark-conformance change: standalone images remain docir `<figure>`.)

- **`tests/basic.tcl::stack-1`** previously failed without docir,
  because `mdstack::html` as an adapter loads `docir::mdSource` via
  `package require`. The test now checks with `haveDocir` and uses a
  reduced variant (`stack-1-no-docir`) when docir is missing.
- **`tests/test-docir-md.tcl`** — self-skip without docir.
- **`tests/test-emoji-pdf.tcl`** — self-skip without pdf4tcl.
- **`tests/test-emoji-sanitize.tcl`** — self-skip without pdf4tcllib.
- **`tests/all.tcl`** — `test-docir-md.tcl` now runs via `runCustom`
  (its own test framework + subprocess) rather than `runAssert`,
  so that an `exit 0` from a skip does not end the runner itself.

### Documentation

- **`README.md`**:
  - removed the `lib/docir-loader.tcl` hint — that file does not
    exist. Replaced by a note about `tcl::tm::path` configuration by
    the application (or `tests/_paths.tcl` for development).
  - removed the `vendors/tm/` entry from the directory structure —
    no vendored dependencies since May 2026.
  - corrected references to `mdhtml-0.1.tm.legacy` and
    `mdpdf-0.2.tm.legacy` — these files no longer exist in the repo.
  - **Requirements** with concrete minimum versions (`pdf4tcl 0.9.4+`,
    `pdf4tcllib 0.1+`, `tls 1.7+`) and a **consumer matrix**.
  - Test count updated to the realistic **532 tests passing without
    deps** (previously: "445 headless"); skip behavior documented.

### Test status

`tclsh tests/all.tcl --core` without external deps:
**Total 532, Passed 532, Failed 0**. Tests requiring docir / pdf4tcl /
Tk skip cleanly instead of crashing.

## 2026-05-07 — Namespace refactor, pkgIndex convention, doc sync

### Changed

- **Namespace refactor**: all 14 sub-modules converted from
  `::mdparser` etc. to the `::mdstack::*` scheme (`mdstack::parser`,
  `mdstack::pdf`, `mdstack::viewer`, `mdstack::theme`, `mdstack::text`,
  `mdstack::model`, `mdstack::validator`, `mdstack::outline`,
  `mdstack::search`, `mdstack::contextmenu`, `mdstack::html`,
  `mdstack::editorkit`, `mdstack::stacknoteskit`,
  `mdstack::uicontextmenu`). Module name and Tcl namespace now match.
- **Sub-directory layout**: `lib/mdparser-0.2.tm` →
  `lib/mdstack/parser-0.2.tm`. Standard Tcl module mechanism via
  `auto_path`. One `pkgIndex.tcl` per sub-directory.
- **Makefile convention**: `install`, `install-user`, `pkgindex`,
  `test`. `make install` installs modules to
  `/usr/local/lib/tcltk/mdstack/`.
- **Table AST recursively structured** (matching DocIR 0.5):
  `mdparser` now produces the canonical `tableRow > tableCell` form,
  consistent with the DocIR spec.
- **Vendoring cleanup**: no more vendored dependencies; `docir`,
  `pdf4tcllib`, and `pdf4tcl` are loaded via standard
  `package require`.

### Fixed

- Triple `mdstack::` prefix in `mdcontextmenu.md`
  (`mdstack::mdstack::mdstack::uicontextmenu`) caused by a `\b`-based
  bulk replacement. Fixed with anchored patterns.

### Tests

532 tests passing.

---

## 2026-05-06 — DocIR cutover, mdhtml + mdpdf as adapters

### Changed

- **`mdhtml` and `mdpdf` are now adapters** to the DocIR pipeline.
  Roughly 600 + 1786 lines of legacy code superseded. Public APIs are
  unchanged; original implementations kept as `.legacy` backups.
- **DocIR modules extracted** into the separate `docir` repository.
  mdstack now loads them via standard `package require` (initially via
  `docir-loader.tcl` with seven search strategies; replaced by
  `auto_path` on 2026-05-07).
- **Asset copy**: `mdstack::html::exportFile` copies referenced images
  along with the output, including images inside table cells.
- The `-root` option is forwarded for relative path resolution in PDF
  export.

### Fixed

- `mdstack::pdf::_renderBlock`: missing heading case
- `mdhtml`: asset copy for images inside table cells
- `mdpdf`: `-root` not forwarded for relative path resolution

---

## Version 0.3.4 (2026-04-12)

### Changed

- **pdf4tcllib 0.1 → 0.2** (`vendors/tm`, `pkgIndex.tcl`)
  - New in 0.2: `form` namespace for AcroForm layout helpers
  - BSD 2-Clause license added
  - `mdpdf-0.2.tm`: `package require pdf4tcllib 0.2`
  - `-producer` string updated to `pdf4tcllib 0.2`

### Refactored

- **mdpdf-0.2.tm** — `_newPage` helper proc extracted: the page-break
  pattern (writeFooter + endPage + incr pageNo + startPage + optional
  writeHeader + reset y) was duplicated 19 times. All replaced by
  `_newPage` calls. About 80 lines removed.
- **mdpdf-0.2.tm** — `_renderBlock` render context refactored: the 16
  parameters `pageW pageH margin fontSize root debug footerTemplate
  headerTemplate` are now passed as a single `rctx` dict. All four
  recursive call sites updated.
- **mdpdf-0.2.tm** — `_renderBlock` split into 11 dedicated sub-procs
  (`_render_heading`, `_render_paragraph`, `_render_code_block`,
  `_render_list`, `_render_hr`, `_render_blockquote`, `_render_table`,
  `_render_image`, `_render_div`, `_render_footnote_section`,
  `_render_deflist`). `_renderBlock` is now a 25-line dispatcher.
  1622 → 1789 lines (more structured, each type independently
  readable).
- **mdviewer-0.3.tm** — `renderTableFrame`: deprecated `stripMarkdown`
  call replaced by `inlinesToText`, consistent with all other render
  paths. `stripMarkdown` kept but marked deprecated.
- **mdstack-0.1.tm** — `_defaultRender`: comment clarifies that direct
  module calls are intentional for the default implementation.

---

## Version 0.3.3 (2026-03-14)

### Fixed

- **mdviewer 0.3** — Link tags had empty ranges; links did not respond
  to clicks. Root cause: `set start [$t index end]` was called before
  inserting the link label text. After rendering, both `start` and
  `end` pointed to the same position (or `start > end` due to
  trailing newlines), so `tag add` silently added nothing. The
  binding existed but was unreachable. Fix: use `"end -1 chars"`
  instead of `end` for both `start` and `end`. Applies to normal
  links and PDF links.
- **mdviewer 0.3** — Task list items (`- [x]`) were rendered with
  strikethrough (`-overstrike 1`) on the `taskdone` tag. Changed to
  grey foreground only (`#999999`), no strikethrough.
- **mdviewer-app-v2** — Welcome document TOC links had wrong anchors:
  `#tastenk-rzel` → `#keyboard-shortcuts`, `#tabellen` → `#tables`.

### Added

- **mdviewer-app-v2** — HTML export via `File → Export HTML…`
  (`Ctrl+H`), optional (requires `mdhtml 0.1`).
- **mdviewer-app-v2** — Help viewer via `Help → Help…` (`F1`), opens
  `help.md` in the viewer.
- **demo/help.md** — New help document for mdviewer-app-v2.

---

## Version 0.3.2 (2026-03-14)

### Fixed

- **mdparser 0.2** — `parseListBlock`: nested-list bug. Mixed-type
  nested lists (e.g. `1.` outer, `- ` inner) were parsed as separate
  blocks instead of child nodes. Root cause: ordered/unordered type
  check applied to all indent levels. Fix: check only applies at
  `lineIndent <= baseIndent` (top-level markers).

### Test improvements

- **tests/all.tcl** — Four-way split A/B/C/D: Core/Parser (headless),
  Renderer (headless), GUI/Tk, PDF/Export. New flags `--core`,
  `--gui`, `--pdf`. Previously missing tests added: `parser-tip700`,
  `parser-tip700-t2t3`, `validator`, `test-docir-md`.
- **tests/basic.tcl** — Core and GUI tests properly separated (Tk
  guard).
- **tests/parser-inline-*.tcl** — Counter variable names unified.
- **tests/test-docir-md.tcl** — Counter and `upvar` fixed.
- **tests/validator.tcl** — C2 test made language-independent.
- Headless: 445 tests, 0 failures. With Tk: 466 tests, 0 failures.

### Documentation

- **README.md** — License corrected BSD → MIT, `mdvalidator` and
  `docir-md` added, test runner instructions with flags.
- **doc/manuals/mdparser.md** — Nested lists documented.
- **doc/manuals/mdvalidator.md** — New.

---

## Version 0.3.1 (2026-03-14) — Initial GitHub release

### Added

- **mdhtml 0.1** — Markdown → HTML renderer (completes the stack:
  HTML + PDF + Tk)
- **mdtheme 0.1** — Shared theme system for HTML, PDF, and Tk
  (light, dark, solarized)
- **mdvalidator 0.1** — AST validator (`validate`, `report`,
  strict mode)
- **docir-md 0.1** — mdparser AST → DocIR intermediate representation
- **tools/mdserver** — HTTP/HTTPS Markdown web server (pure Tcl,
  no Tk)

### Changed

- **mdpdf 0.2** — Clickable hyperlinks, `-pdfa`, `-userpassword`,
  `-ownerpassword`, `-theme`
- **mdtheme 0.1** — `toCSS`, `toPdfOpts` for HTML and PDF renderers
- **mdparser 0.2** — TIP-700 (bracketed spans, shortcut reference
  links), YAML frontmatter, fenced divs, nested lists, multi-line
  items, definition lists, reference links, inline features,
  backslash escapes
