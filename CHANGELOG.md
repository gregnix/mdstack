# mdstack — Changelog

## 2026-06-14 — Viewer: wheel scrolling over frame-mode tables

### Fixed

- `viewer-0.3.tm`: mouse-wheel scrolling stopped while the pointer was over a
  frame-mode table (`-tablemode frame`). Embedded table frames and their cell
  widgets swallowed `<MouseWheel>`/`<Button-4>`/`<Button-5>`; they are now
  forwarded to the viewer text widget. New helper `_wheelToText`, called after
  the table's `window create`.

### Changed

- `_wheelToText` prefers `tkutils::tkuwheel::redirect` when that package is
  available (shared implementation) and falls back to an inline binding
  otherwise, so mdstack stays usable without tkutils.

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
