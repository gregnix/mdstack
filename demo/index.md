# mdstack Demos

## GUI Demos (require Tk)

| Demo | Description |
|------|-------------|
| `mdviewer-app-v2.tcl` | **Complete viewer application** -- TOC, search, font size, PDF export |
| `mdviewer-tip700-demo.tcl` | TIP-700 features -- bracketed spans, fenced divs, YAML frontmatter |
| `mdstack-full-demo.tcl` | Full stack -- editor + live preview + search + context menu |
| `mdtext-demo.tcl` | Editor widget -- smart return, indent, format operations |
| `mdsearch-demo.tcl` | Full-text search with highlight and navigation |
| `mdoutline-demo.tcl` | Heading outline panel with live update |

## CLI Demos (tclsh, headless)

| Demo | Description |
|------|-------------|
| `mdpdf-features-demo.tcl` | PDF export -- TOC, header/footer, PDF/A, encryption, themes |
| `mdpdf-hyperlink-demo.tcl` | Clickable hyperlinks in PDF |
| `mdpdf-pdfa-demo.tcl` | PDF/A-1b and PDF/A-2b conformance |
| `mdpdf-encryption-demo.tcl` | AES-128 user/owner password |
| `mdhtml-themes-demo.tcl` | HTML export with hell/dunkel/solarized themes |
| `demo-tip700.tcl` | TIP-700 parser features -- YAML, fenced divs, spans |

## Demo files

| File | Used by |
|------|---------|
| `mdpdf-features-demo.md` | `mdpdf-features-demo.tcl` |
| `demo-tip700.md` | `demo-tip700.tcl` |
| `test-complete.md` | `mdviewer-app-v2.tcl` |
| `images/` | `mdviewer-app-v2.tcl`, `mdviewer-tip700-demo.tcl` |
| `icons/` | `mdviewer-app-v2.tcl` |
