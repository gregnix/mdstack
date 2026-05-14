# mdstack — Changelog

## 2026-05-13 — Repo-Hygiene + Test-Stabilitaet

**Affected consumers:** keine API-Aenderung. Konsumenten (man-viewer,
mdhelp4) brauchen nichts anzupassen.

### Removed

- **`tests/test-toc.pdf`** -- Test-Output war versionsverwaltet
  obwohl `.gitignore` `test-toc.pdf` explizit auflistet.

### Added

- **`tests/_paths.tcl`** -- gemeinsame Pfad-Konfiguration fuer Tests.
  Sucht `docir` an mehreren Stellen (`$DOCIR_HOME`, Sibling-Repo,
  Parent-Sibling, `~/lib/tcltk/docir`, System-Default). Stellt
  `haveDocir`-Helper bereit fuer Self-Skipping.

  Wird gesourced von `basic.tcl`, `test-docir-md.tcl`,
  `test-emoji-pdf.tcl`, `test-emoji-sanitize.tcl` -- vorher fehlte die
  Datei komplett, diese drei Tests kraschten mit
  "no such file or directory".

### Fixed

- **`tests/basic.tcl::stack-1`** scheiterte ohne docir, weil
  `mdstack::html` als Adapter `docir::mdSource` per `package require`
  laedt. Test prueft jetzt mit `haveDocir` und nutzt eine reduzierte
  Variante (`stack-1-no-docir`) wenn docir fehlt.
- **`tests/test-docir-md.tcl`** -- Self-Skip ohne docir.
- **`tests/test-emoji-pdf.tcl`** -- Self-Skip ohne pdf4tcl.
- **`tests/test-emoji-sanitize.tcl`** -- Self-Skip ohne pdf4tcllib.
- **`tests/all.tcl`** -- `test-docir-md.tcl` jetzt via `runCustom`
  (eigenes Test-Framework + Sub-Prozess), nicht `runAssert`. Damit
  beendet ein `exit 0` aus dem Skip nicht den Runner selbst.

### Documentation

- **`README.md`**:
  - `lib/docir-loader.tcl`-Hinweis entfernt -- Datei existiert nicht.
    Stattdessen Hinweis auf `tcl::tm::path`-Konfiguration durch
    Anwendung (oder `tests/_paths.tcl` fuer Development).
  - `vendors/tm/`-Eintrag in Directory Structure entfernt -- seit
    2026-05 keine vendored Deps.
  - `mdhtml-0.1.tm.legacy` und `mdpdf-0.2.tm.legacy` Verweise korrigiert
    -- diese Dateien existieren im Repo nicht (mehr).
  - **Requirements** mit konkreten Min-Versionen (`pdf4tcl 0.9.4+`,
    `pdf4tcllib 0.1+`, `tls 1.7+`) und einer **Consumer-Matrix**.
  - Test-Zahl auf realistische **532 tests passing ohne Deps**
    aktualisiert (vorher: "445 headless"); Skip-Verhalten dokumentiert.

### Test status

`tclsh tests/all.tcl --core` ohne externe Deps:
**Total 532, Passed 532, Failed 0**. Tests mit docir/pdf4tcl/Tk Bedarf
skippen sich sauber statt zu crashen.

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
