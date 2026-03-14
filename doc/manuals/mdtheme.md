# mdtheme

> Version 0.1

## Zweck

`mdtheme` stellt gemeinsame Farbthemes und Typografie-Einstellungen
für alle mdstack-Renderer bereit:

- **mdviewer** (Tk-Widget) -- Farben für Text-Tags
- **mdhtml** (HTML-Renderer) -- via `toCSS`
- **mdpdf** (PDF-Renderer) -- via `toPdfOpts`

Ein Theme einmal definieren, drei Renderer profitieren.

---

## Abhängigkeiten

- Tcl 8.6+
- Kein `package require` für andere mdstack-Module nötig

---

## Öffentliche API

### Themes abfragen

```tcl
mdtheme::names       ;# --> dunkel hell solarized
mdtheme::current     ;# --> hell
mdtheme::activate dunkel
```

### Einzelnen Farbwert abfragen

```tcl
mdtheme::color bg    ;# --> #ffffff  (aktuelles Theme)
mdtheme::get hell bg ;# --> #ffffff  (benanntes Theme)
mdtheme::get hell font_size ;# --> 11  (Typografie)
```

### Theme-Dict abfragen

```tcl
set th [mdtheme::theme hell]
dict get $th link    ;# --> #0066cc
```

### Für HTML-Renderer

```tcl
package require mdtheme 0.1
package require mdhtml  0.1

# Theme als vollstaendiges CSS
set html [mdhtml::render $ast -theme hell]

# Theme als Basis + eigene Overrides (kombiniert)
set html [mdhtml::render $ast -theme hell -css custom.css]
```

`toCSS` liefert einen vollstaendigen CSS-String mit allen
Farben und Typografie-Werten des Themes.

Wenn zusaetzlich `-css` angegeben wird, wird die externe Datei
**hinter** dem Theme-CSS eingefuegt. Spaetere CSS-Regeln gewinnen --
so koennen gezielt einzelne Eigenschaften ueberschrieben werden:

```css
/* custom.css -- nur die Abweichungen vom Theme */
body { font-size: 14pt; }
h1   { color: #cc0000; }
```

### Für PDF-Renderer

```tcl
package require mdtheme 0.1
package require mdpdf   0.2

mdpdf::export $ast output.pdf -theme hell
```

`toPdfOpts` liefert ein Dict mit PDF-relevanten Werten:
`fontsize`, `margin`, `colorLink`, `colorCode`.

### Für Tk-Viewer

```tcl
package require mdtheme  0.1
package require mdviewer 0.3

mdtheme::activate dunkel
mdtheme::applyToViewer .viewer
```

---

## Verfügbare Themes

| Name | Beschreibung |
|------|-------------|
| `hell` | Helles Standard-Theme (weiß, Helvetica) |
| `dunkel` | Dunkles Theme (Catppuccin Mocha) |
| `solarized` | Solarized Light |

---

## Typografie-Defaults

Alle Themes teilen diese Typografie-Defaults (überschreibbar im Theme-Dict):

| Schlüssel | Standard | Beschreibung |
|-----------|----------|-------------|
| `font_body` | Georgia, serif | Brottext-Font |
| `font_heading` | Helvetica, Arial | Überschriften-Font |
| `font_mono` | Courier New | Monospace-Font |
| `font_size` | `11` | Basis-Schriftgröße in pt |
| `line_spacing` | `1.4` | Zeilenabstand-Faktor |
| `margin_page` | `50` | Seitenrand in pt (PDF) |
| `max_width_px` | `860` | Maximale Breite in px (HTML) |

---

## Eigenes Theme hinzufügen

```tcl
set mdtheme::themes(mein) {
    name   "Mein Theme"
    bg     "#fafafa"
    fg     "#111111"
    link   "#cc0000"
    # ... alle Pflicht-Schlüssel wie in 'hell' ...
    font_size  12
    margin_page 60
}
mdtheme::activate mein
```

---

## Farb-Schlüssel (Auswahl)

| Schlüssel | Verwendung |
|-----------|------------|
| `bg` | Hintergrund |
| `fg` | Vordergrund (Text) |
| `bg_alt` | Alternativer Hintergrund (Zebrastreifen) |
| `link` | Hyperlink-Farbe |
| `code_bg` | Code-Block-Hintergrund |
| `code_inline_bg` | Inline-Code-Hintergrund |
| `quote_fg` | Blockquote-Text |
| `quote_bg` | Blockquote-Hintergrund |
| `table_header_bg` | Tabellen-Header-Hintergrund |
| `span_cmd` | TIP-700 `.cmd`-Farbe |
| `span_arg` | TIP-700 `.arg`-Farbe |

---

## Changelog

### 0.1.1 (2026-03-14)

- `-theme` + `-css` kombinierbar in `mdhtml`: Theme als Basis,
  externe Datei als Overrides (mdtheme selbst unveraendert,
  Kombinations-Logik liegt in `mdhtml::render`)

### 0.1 (2026-03-14)

- Initiale Version (Umbenennung/Erweiterung von mdtheme für Tk-Viewer)
- `toCSS` -- Theme -> CSS-String für mdhtml
- `toPdfOpts` -- Theme -> Dict für mdpdf
- `get name key` -- Wert mit Typografie-Fallback
- Typografie-Defaults für font, size, margin, spacing

## Siehe auch

- [mdhtml](mdhtml.md) -- HTML-Renderer
- [mdpdf](mdpdf.md) -- PDF-Renderer
- [mdviewer](mdviewer.md) -- Tk-Viewer
