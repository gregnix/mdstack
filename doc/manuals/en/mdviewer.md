# mdviewer

## Purpose

`mdviewer` renders a Markdown AST **read-only** into a Tk text widget.

The module:
- displays Markdown content with full formatting
- renders images (PNG, GIF, JPG)
- handles navigation (links, anchors)
- is **not an editor**

---

## Supported elements

| Element | Rendering |
|---------|-----------|
| Headings h1–h6 | Font size + bold, proportional scaling |
| Paragraphs | Normal text with typographic spacing |
| Unordered lists | Bullet symbols `• ◦ ▪ ▸` per nesting level |
| Ordered lists | `1.` `2.` numbering |
| Nested lists | Visual indentation, arbitrary depth |
| Task lists | ☑ / ☐ symbols |
| Definition lists | Term in **bold**, definitions with `—` prefix |
| Code blocks | Monospace font + background color |
| Tables | Box-drawing (`│ ├ ┼`) with column alignment |
| Blockquotes | `│` prefix per nesting level + italic text |
| Fenced divs | Inner blocks rendered recursively |
| Images | Real image or `[alt]` fallback |
| Links | Blue + underlined + clickable |
| Bracketed spans | `.cmd`/`.sub`/`.lit` → bold, `.arg`/`.optarg` → italic |

---

## Dependencies

- Tcl/Tk ≥ 8.6
- `mdparser 0.2`
- `mdmodel 0.1`
- Optional: `Img` package (for JPG support)

---

## Public API

### `mdviewer::create path ?options?`

Creates a Markdown viewer widget.

```tcl
set v [mdviewer::create .v -root $docsDir -onlink onLink]
pack $v -fill both -expand 1
```

#### Options

| Option | Default | Description |
|--------|---------|-------------|
| `-root` | `""` | Base path for relative image URLs |
| `-onlink` | `""` | Callback on link click (receives URL) |
| `-onclick` | `""` | Callback on any click (receives x y index tags lineText) |
| `-fontsize` | `10` | Base font size in points |

---

### `mdviewer::render path ast`

Renders an AST directly.

```tcl
set ast [mdparser::parse "# Title\n\nText."]
mdviewer::render $v $ast
```

---

### `mdviewer::renderModel path docModel`

Renders an mdmodel document model.

```tcl
set ast [mdparser::parse $markdown]
set doc [mdmodel::new $ast]
mdviewer::renderModel $v $doc
```

---

### `mdviewer::setFontSize path size`

Adjusts all tags proportionally to the new base font size.

```tcl
mdviewer::setFontSize $v 14
```

Heading scaling: h1=1.6×, h2=1.4×, h3=1.2×, h4=1.1×, h5/h6=1.0×

---

### `mdviewer::gotoAnchor path anchor`

Scrolls to the heading with the given anchor. Returns 1/0.

```tcl
mdviewer::gotoAnchor $v "installation"
```

---

### `mdviewer::anchors path`

Returns a list of all anchor names in the current document.

---

### `mdviewer::configure path ?options?`

Changes configuration options.

```tcl
mdviewer::configure $v -root /new/path
```

---

### `mdviewer::cget path option`

Queries a configuration option.

```tcl
set root [mdviewer::cget $v -root]
set size [mdviewer::cget $v -fontsize]
```

---

### `mdviewer::clear path`

Clears the viewer content.

---

### `mdviewer::widget path`

Returns the underlying Tk text widget.

---

## Image support

| Format | Support |
|--------|---------|
| PNG | ✅ native |
| GIF | ✅ native |
| JPG | ✅ with Img package |
| SVG | ✅ with tksvg package |

| Context | Max size |
|---------|----------|
| Standalone | 200 px |
| Inline | 60 px |
| In tables | 40 px |

Fallback when image cannot be loaded: `[Image: alt-text]`

---

## Link handling

Links are not opened automatically. Use the `-onlink` callback:

```tcl
proc onLink {url} {
    if {[string match "http*" $url]} {
        exec xdg-open $url &
    } elseif {[string match "#*" $url]} {
        mdviewer::gotoAnchor $v [string range $url 1 end]
    }
}

set v [mdviewer::create .v -onlink onLink]
```

---

## Context tag system

Tk text widget cannot combine fonts across overlapping tags — the
higher-priority tag wins completely. `mdviewer` uses context-dependent
tags with predefined font combinations:

| Context | Tag | Font |
|---------|-----|------|
| Normal | `strong` | bold |
| Normal | `emphasis` | italic |
| Blockquote | `strong_q` | bold italic |
| Blockquote | `em_q` | italic |
| Table cell | `strong_t` | Courier bold |
| Table cell | `em_t` | Courier italic |

---

## Non-goals

- No editing
- No saving
- No file selection

These belong in applications or `mdeditorkit`.

---

## Internal: link tag index pattern

Link tags use `"end -1 chars"` (not `end`) for index capture:

```tcl
set start [$t index "end -1 chars"]
renderInlines ...
set end [$t index "end -1 chars"]
$t tag add link $start $end
$t tag add $ltag $start $end
```

**Why:** The text widget always has an implicit trailing newline.
`end` points *after* that newline. After inserting inline content,
the trailing newline shifts — `start` and `end` can end up equal
or inverted, so `tag add` silently assigns no range and the click
binding becomes unreachable. `"end -1 chars"` points to the last
real character and stays stable across insertions.

**Symptom if broken:** Links are blue and underlined but clicks have
no effect. `$t tag ranges link1` returns empty.
