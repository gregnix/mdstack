# Changelog

## Version 0.3.4 (2026-04-12)

### Dependency update

- **pdf4tcllib 0.1 → 0.2** (`vendors/tm`, `pkgIndex.tcl`)
  - New in 0.2: `form` namespace for AcroForm layout helpers
  - BSD 2-Clause license added
  - `mdpdf-0.2.tm`: `package require pdf4tcllib 0.2`
  - `-producer` string updated to `pdf4tcllib 0.2`

### Improvements

- **mdpdf-0.2.tm** — `_newPage` helper proc extracted: the page-break
  pattern (writeFooter + endPage + incr pageNo + startPage + optional
  writeHeader + reset y) was duplicated 19×. All replaced by `_newPage`
  calls. ~80 lines removed.

- **mdviewer-0.3.tm** — `renderTableFrame`: deprecated `stripMarkdown`
  call replaced by `inlinesToText`, consistent with all other render paths.
  `stripMarkdown` kept but marked DEPRECATED.

- **mdstack-0.1.tm** — `_defaultRender`: comment clarifies that direct
  module calls are intentional for the default implementation.

- **mdpdf-0.2.tm** — `_renderBlock` render context refactored: the 16
  parameters `pageW pageH margin fontSize root debug footerTemplate
  headerTemplate` are now passed as a single `rctx` dict. All 4
  recursive call sites updated. Reduces call complexity significantly.

- **mdpdf-0.2.tm** — `_renderBlock` split into 11 dedicated sub-procs
  (`_render_heading`, `_render_paragraph`, `_render_code_block`,
  `_render_list`, `_render_hr`, `_render_blockquote`, `_render_table`,
  `_render_image`, `_render_div`, `_render_footnote_section`,
  `_render_deflist`). `_renderBlock` is now a 25-line dispatcher.
  1622 → 1789 lines (more structured, each type independently readable).

---

## Version 0.3.3 (2026-03-14)

### Bug-fixes

- **mdviewer 0.3** -- Link tags had empty ranges: links did not respond to clicks.
  Root cause: `set start [$t index end]` was called before inserting the link
  label text. After rendering, both `start` and `end` pointed to the same
  position (or `start > end` due to trailing newlines), so `tag add` silently
  added nothing. The binding existed but was unreachable.
  Fix: use `"end -1 chars"` instead of `end` for both `start` and `end`.
  Applies to normal links and PDF-links.
- **mdviewer 0.3** -- Task list items (`- [x]`) were rendered with
  strikethrough (`-overstrike 1`) on the `taskdone` tag. Changed to grey
  foreground only (`#999999`), no strikethrough.
- **mdviewer-app-v2** -- Welcome document TOC links had wrong anchors:
  `#tastenk-rzel` → `#keyboard-shortcuts`, `#tabellen` → `#tables`.

### New features

- **mdviewer-app-v2** -- HTML export via `File → Export HTML…` (`Ctrl+H`),
  optional (requires `mdhtml 0.1`).
- **mdviewer-app-v2** -- Help viewer via `Help → Help…` (`F1`), opens
  `help.md` in the viewer.
- **demo/help.md** -- New help document for mdviewer-app-v2.

---

## Version 0.3.2 (2026-03-14)

### Bug-fixes

- **mdparser 0.2** -- `parseListBlock`: Fixed nested-list bug.
  Mixed-type nested lists (e.g. `1.` outer, `- ` inner) were parsed as
  separate blocks instead of child nodes.
  Root cause: ordered/unordered type check applied to all indent levels.
  Fix: check only applies at `lineIndent <= baseIndent` (top-level markers).

### Test improvements

- **tests/all.tcl** -- Four-way split A/B/C/D: Core/Parser (headless),
  Renderer (headless), GUI/Tk, PDF/Export.
  New flags `--core`, `--gui`, `--pdf`.
  Previously missing tests added: `parser-tip700`, `parser-tip700-t2t3`,
  `validator`, `test-docir-md`.
- **tests/basic.tcl** -- Core and GUI tests properly separated (Tk guard).
- **tests/parser-inline-*.tcl** -- Counter variable names unified.
- **tests/test-docir-md.tcl** -- Counter and `upvar` fixed.
- **tests/validator.tcl** -- C2 test made language-independent.
- Headless: **445 tests, 0 failures** | With Tk: **466 tests, 0 failures**

### Documentation

- **README.md** -- License corrected BSD→MIT, `mdvalidator` and `docir-md`
  added, test runner instructions with flags.
- **doc/manuals/mdparser.md** -- Nested lists documented.
- **doc/manuals/mdvalidator.md** -- New.

---

## Version 0.3.1 (2026-03-14) -- Initial GitHub Release

### New

- **mdhtml 0.1** -- Markdown → HTML renderer (completes the stack: HTML + PDF + Tk)
- **mdtheme 0.1** -- Shared theme system for HTML, PDF and Tk (light, dark, solarized)
- **mdvalidator 0.1** -- AST validator (validate, report, strict mode)
- **docir-md 0.1** -- mdparser AST → DocIR intermediate representation
- **tools/mdserver** -- HTTP/HTTPS Markdown web server (pure Tcl, no Tk)

### Enhancements

- **mdpdf 0.2** -- Clickable hyperlinks, `-pdfa`, `-userpassword`,
  `-ownerpassword`, `-theme`
- **mdtheme 0.1** -- `toCSS`, `toPdfOpts` for HTML and PDF renderers
- **mdparser 0.2** -- TIP-700 (bracketed spans, shortcut reference links),
  YAML frontmatter, fenced divs, nested lists, multi-line items,
  definition lists, reference links, inline features, backslash escapes
