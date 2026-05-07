# mdstack::theme

> Version 0.1

## Purpose

`mdstack::theme` provides shared color themes and typography settings for all
mdstack renderers:

- **mdstack::viewer** (Tk widget) — colors for text tags
- **mdstack::html** (HTML renderer) — via `toCSS`
- **mdstack::pdf** (PDF renderer) — via `toPdfOpts`

Define a theme once, all three renderers benefit.

---

## Dependencies

- Tcl 8.6+
- No other mdstack packages required

---

## Public API

### Query and activate themes

```tcl
mdstack::theme::names       ;# --> dunkel hell solarized
mdstack::theme::current     ;# --> hell
mdstack::theme::activate dunkel
```

### Read individual values

```tcl
mdstack::theme::color bg        ;# --> #ffffff  (current theme)
mdstack::theme::get hell bg     ;# --> #ffffff  (named theme)
mdstack::theme::get hell font_size  ;# --> 11
```

### Read full theme dict

```tcl
set th [mdstack::theme::theme hell]
dict get $th link    ;# --> #0066cc
```

### For HTML renderer

```tcl
package require mdstack::theme 0.1
package require mdstack::html  0.1

set html [mdstack::html::render $ast -theme hell]

# Theme as base + external overrides (recommended):
set html [mdstack::html::render $ast -theme hell -css custom.css]
```

`toCSS` returns a complete CSS string with all colors and typography
values. When `-css` is also given, the external file is appended after
the theme CSS — later rules win.

### For PDF renderer

```tcl
package require mdstack::theme 0.1
package require mdstack::pdf   0.2

mdstack::pdf::export $ast output.pdf -theme hell
```

`toPdfOpts` returns a dict with PDF-relevant values:
`fontsize`, `margin`, `colorLink`, `colorCode`.

### For Tk viewer

```tcl
package require mdstack::theme  0.1
package require mdstack::viewer 0.3

mdstack::theme::activate dunkel
mdstack::theme::applyToViewer .viewer
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
set mdstack::theme::themes(mytheme) {
    name   "My Theme"
    bg     "#fafafa"
    fg     "#111111"
    link   "#cc0000"
    font_size   12
    margin_page 60
    ;# ... all required keys as in "hell" ...
}
mdstack::theme::activate mytheme
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

- [mdstack::html](mdhtml.md) – HTML renderer
- [mdstack::pdf](mdpdf.md) – PDF renderer
- [mdstack::viewer](mdviewer.md) – Tk viewer
