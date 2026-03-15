# mdtheme

> Version 0.1

## Purpose

`mdtheme` provides shared color themes and typography settings for all
mdstack renderers:

- **mdviewer** (Tk widget) — colors for text tags
- **mdhtml** (HTML renderer) — via `toCSS`
- **mdpdf** (PDF renderer) — via `toPdfOpts`

Define a theme once, all three renderers benefit.

---

## Dependencies

- Tcl 8.6+
- No other mdstack packages required

---

## Public API

### Query and activate themes

```tcl
mdtheme::names       ;# --> dunkel hell solarized
mdtheme::current     ;# --> hell
mdtheme::activate dunkel
```

### Read individual values

```tcl
mdtheme::color bg        ;# --> #ffffff  (current theme)
mdtheme::get hell bg     ;# --> #ffffff  (named theme)
mdtheme::get hell font_size  ;# --> 11
```

### Read full theme dict

```tcl
set th [mdtheme::theme hell]
dict get $th link    ;# --> #0066cc
```

### For HTML renderer

```tcl
package require mdtheme 0.1
package require mdhtml  0.1

set html [mdhtml::render $ast -theme hell]

# Theme as base + external overrides (recommended):
set html [mdhtml::render $ast -theme hell -css custom.css]
```

`toCSS` returns a complete CSS string with all colors and typography
values. When `-css` is also given, the external file is appended after
the theme CSS — later rules win.

### For PDF renderer

```tcl
package require mdtheme 0.1
package require mdpdf   0.2

mdpdf::export $ast output.pdf -theme hell
```

`toPdfOpts` returns a dict with PDF-relevant values:
`fontsize`, `margin`, `colorLink`, `colorCode`.

### For Tk viewer

```tcl
package require mdtheme  0.1
package require mdviewer 0.3

mdtheme::activate dunkel
mdtheme::applyToViewer .viewer
```

---

## Available themes

| Name | Description |
|------|-------------|
| `hell` | Light default theme (white, Helvetica) |
| `dunkel` | Dark theme (Catppuccin Mocha) |
| `solarized` | Solarized Light |

---

## Typography defaults

All themes share these defaults (overridable per theme dict):

| Key | Default | Description |
|-----|---------|-------------|
| `font_body` | Georgia, serif | Body text font |
| `font_heading` | Helvetica, Arial | Heading font |
| `font_mono` | Courier New | Monospace font |
| `font_size` | `11` | Base font size in pt |
| `line_spacing` | `1.4` | Line spacing factor |
| `margin_page` | `50` | Page margin in pt (PDF) |
| `max_width_px` | `860` | Maximum width in px (HTML) |

---

## Adding a custom theme

```tcl
set mdtheme::themes(mytheme) {
    name   "My Theme"
    bg     "#fafafa"
    fg     "#111111"
    link   "#cc0000"
    font_size   12
    margin_page 60
    ;# ... all required keys as in "hell" ...
}
mdtheme::activate mytheme
```

---

## Color keys (selection)

| Key | Usage |
|-----|-------|
| `bg` | Background |
| `fg` | Foreground (text) |
| `bg_alt` | Alternate background (zebra stripes) |
| `link` | Hyperlink color |
| `code_bg` | Code block background |
| `code_inline_bg` | Inline code background |
| `quote_fg` | Blockquote text color |
| `quote_bg` | Blockquote background |
| `table_header_bg` | Table header background |
| `span_cmd` | TIP-700 `.cmd` color |
| `span_arg` | TIP-700 `.arg` color |

---

## See also

- [mdhtml](mdhtml.md) – HTML renderer
- [mdpdf](mdpdf.md) – PDF renderer
- [mdviewer](mdviewer.md) – Tk viewer
