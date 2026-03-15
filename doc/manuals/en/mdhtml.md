# mdhtml

> Version 0.1

## Purpose

`mdhtml` converts a Markdown AST (from `mdparser`) into clean HTML.
It is the HTML renderer in the mdstack ecosystem, complementing
`mdpdf` (PDF) and `mdviewer` (Tk widget).

```
Markdown
   |
mdparser  -->  AST
                |
      +---------+---------+
      |         |         |
   mdhtml     mdpdf    mdviewer
    HTML       PDF        Tk
```

---

## Public API

### `mdhtml::render ast ?options?`

Converts an AST into a complete HTML string.

```tcl
package require mdparser 0.2
package require mdhtml   0.1

set ast  [mdparser::parse $markdownText]
set html [mdhtml::render $ast -title "My Document" -toc 1]
```

| Option | Default | Description |
|--------|---------|-------------|
| `-title` | `""` | Document title (fallback: first H1 or YAML frontmatter) |
| `-toc` | `0` | Generate table of contents (0\|1) |
| `-theme` | `""` | mdtheme name: `hell`, `dunkel`, `solarized` |
| `-css` | `""` | Path to external CSS file |
| `-lang` | `de` | HTML `lang` attribute |
| `-encoding` | `utf-8` | Output encoding |

---

### `mdhtml::export ast outFile ?options?`

Like `render`, but writes directly to a file.

```tcl
mdhtml::export $ast output.html -title "Document" -toc 1
```

---

### `mdhtml::exportFile mdFile outFile ?options?`

Reads a Markdown file, parses it, and writes HTML to the output file.

```tcl
mdhtml::exportFile input.md output.html -title "Title" -toc 1
```

---

## Supported elements

### Block types

| Type | Markdown | HTML |
|------|----------|------|
| `heading` | `# H1` – `###### H6` | `<h1>`–`<h6>` with `id` attribute |
| `paragraph` | Normal text | `<p>` |
| `code_block` | ` ```lang ` | `<pre><code class="language-lang">` |
| `hr` | `---` | `<hr>` |
| `blockquote` | `> text` | `<blockquote>` (nestable) |
| `list` | `- item` / `1. item` | `<ul>` or `<ol>` |
| `deflist` | `Term\n: Def` | `<dl>`, `<dt>`, `<dd>` |
| `table` | `\| A \| B \|` | `<table>` with `<thead>`, `<tbody>` |
| `image` | `![alt](url)` | `<figure>`, `<img>`, `<figcaption>` |
| `footnote_section` | `[^1]: text` | `<section class="footnotes">` |

### Inline types

| Type | Markdown | HTML |
|------|----------|------|
| `strong` | `**text**` | `<strong>` |
| `emphasis` | `*text*` | `<em>` |
| `strike` | `~~text~~` | `<s>` |
| `inline_code` | `` `code` `` | `<code>` |
| `link` | `[label](url)` | `<a href="url">` |
| `image` | `![alt](url)` | `<img>` |
| `linebreak` | two trailing spaces | `<br>` |
| `span` | `[text]{.cmd}` | `<span class="cmd">` (TIP-700) |
| `footnote_ref` | `[^1]` | `<sup><a>` |

### Task lists

```markdown
- [x] Done
- [ ] Open
```

Generates `<input type="checkbox" checked/disabled>` before the list item.

---

## Table of contents

With `-toc 1` a `<nav class="toc">` is inserted before the body.
H1, H2 and H3 are included (deeper levels ignored).

---

## Theme and CSS

Four combinations are supported:

| Combination | Result |
|-------------|--------|
| `-theme only` | Full CSS from `mdtheme::toCSS` |
| `-theme` + `-css` | Theme CSS as base + external overrides (recommended) |
| `-css only` | External file only |
| neither | Built-in responsive default CSS |

```tcl
# Theme as base, custom overrides:
set html [mdhtml::render $ast -theme hell -css custom.css]
```

```css
/* custom.css -- only the differences from the theme */
body { font-size: 14pt; }
h1   { color: #cc0000; }
```

---

## YAML frontmatter

The `title` field from frontmatter is used as default document title:

```markdown
---
title: My Document
---

# Content
```

```tcl
set ast  [mdparser::parse $md]
set html [mdhtml::render $ast]   ;# title from frontmatter
```

---

## Limitations

- No base64 image embedding (src references only)
- No syntax highlighting in code blocks
  (only `language-X` class for external highlighters like highlight.js)
- Footnotes collected at end of document, not paginated
