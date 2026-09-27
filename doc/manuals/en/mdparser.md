# mdstack::parser

> Version 0.8.0

## Purpose

`mdstack::parser` converts Markdown text into an **abstract syntax tree (AST)**.

The module:
- is **stateless**
- has **no GUI dependency**
- produces **pure data**

`mdstack::parser` is the **only place** where Markdown syntax is interpreted.

---

## Supported elements

### Block types

| Element | Syntax | Example |
|---------|--------|---------|
| Headings | `#` to `######` | `## H2` |
| Paragraphs | blank line separates | |
| Fenced code blocks | ` ``` ` | ` ```tcl ` |
| Indented code blocks | 4 spaces | |
| Unordered lists | `- ` / `* ` / `+ ` | `- Item` |
| Ordered lists | `1. ` | `1. Item` |
| Nested lists | 2+ space indent | `  - Sub` |
| Task lists | `- [ ]` / `- [x]` | `- [x] Done` |
| Definition lists | `Term\n: Definition` | |
| Horizontal rule | `---` | |
| Tables (GFM) | `\| A \| B \|` | |
| Blockquotes | `> ` | `> Quote` |
| Fenced divs (TIP-700) | `::: {.class} ... :::` | |
| Standalone images | `![alt](url)` | |
| YAML frontmatter | `---` at document start | |
| HTML blocks (0.8.0) | CommonMark start conditions 1–7 | `<div>…</div>` → `html_block` |
| Display math | `$$…$$` on its own line | `math_block` |
| Footnote defs | `[^id]: text` | `footnote_def` / `footnote_section` |

### Inline types

| Element | Syntax |
|---------|--------|
| Bold | `**text**` |
| Italic | `*text*` |
| Strikethrough | `~~text~~` |
| Inline code | `` `code` `` |
| Links | `[text](url)` |
| Reference links | `[text][ref]` / `[text]` |
| Autolinks | `<https://...>` / bare URLs |
| Inline images | `![alt](url)` |
| Hard line break | two trailing spaces |
| Backslash escape | `\*` `\_` `\`` etc. |
| Bracketed spans (TIP-700) | `[text]{.class}` |
| Inline math | `$…$` |
| Footnote refs | `[^id]` |

### Nested lists

Mixed types are allowed (ordered outer, unordered inner):

```tcl
set md {1. First
   - Sub A
   - Sub B
2. Second}

set ast [mdstack::parser::parse $md]
set lst [lindex [dict get $ast blocks] 0]
# -> type=list style=ordered  items=2
# -> item 0: blocks=[paragraph, list(unordered)]
```

### Definition lists

```markdown
Term
: Definition text

Another term
: First definition
: Second definition
```

### YAML frontmatter

```markdown
---
title: My Document
author: Gregor
date: 2026-03-14
---

# Content starts here
```

Available via `dict get $ast meta`.

### TIP-700 bracketed spans

```markdown
The [command]{.cmd} takes an [argument]{.arg}.
```

Classes: `.cmd` `.sub` `.lit` `.optlit` `.arg` `.optarg` `.ins`
`.ccmd` `.cargs` `.ret`

### Fenced divs

```markdown
::: {.note}
This is a note block.
:::
```

### HTML blocks (0.8.0)

Raw block HTML is kept verbatim as `html_block` (previously dropped).
All seven CommonMark start conditions apply. Sinks decide the rest:
`docir::html` emits the markup as-is; PDF/Tk/ODT show the source.

### Math

```markdown
Inline $E=mc^2$ and display:

$$
\frac{a}{b}
$$
```

`supports` lists `inline:math` and `blocks:math_block`. The `$ast` argument
to `supports` is unused — the list is static.

---

## Dependencies

- Tcl ≥ 8.6
- No Tk dependency

---

## Public API

### `mdstack::parser::parse markdown`

Parses Markdown text and returns an AST.

```tcl
set ast [mdstack::parser::parse "# Title\n\nText."]
```

**Return value:** `dict` with keys `version`, `meta`, `reflinks`, `blocks`

### Parse from file

```tcl
set fd [open README.md r]
fconfigure $fd -encoding utf-8
set content [read $fd]
close $fd
set ast [mdstack::parser::parse $content]
```

### `mdstack::parser::validate ast`

Shallow check: root `type=document`, `version=1`, key `blocks`. Throws on
failure; returns 1. Node walks belong to `mdstack::validator`.

### `mdstack::parser::supports ast`

Returns the capability token list (`blocks:html_block`, `blocks:math_block`,
`inline:math`, …). Argument unused.

### `mdstack::parser::anchorize title`

Heading text → anchor id.

---

## AST structure

### Document root

```tcl
{
    version  1
    meta     {}      ;# YAML frontmatter dict
    reflinks {}      ;# reference link definitions
    blocks   { ... } ;# list of block nodes
}
```

### Heading

```tcl
{type heading  level 2  anchor "my-title"
 content {{type text value "My Title"}}}
```

### List and list_item

```tcl
{type list  style unordered  items {
    {type list_item  blocks {
        {type paragraph content {{type text value "Item text"}}}
        ;# optional sublist as second block:
        {type list style unordered items { ... }}
    }}
}}
```

Note: `style` is `"ordered"` or `"unordered"` (not a boolean).

### Task list item

```tcl
{type list_item  checked 1  blocks {
    {type paragraph content {{type text value "Done"}}}
}}
```

### Code block

```tcl
{type code_block  language "tcl"  value "puts hello"}
```

### HTML block

```tcl
{type html_block  content "<div class=\"x\">\n<p>hi</p>\n</div>"}
```

### Display math

```tcl
{type math_block  display 1  content "E=mc^2"}
```

### Table

```tcl
{type table
 header         {Col1 Col2}
 alignments     {left right}
 rows           {{Val1 Val2}}
 headerInlines  { {inlines...} {inlines...} }
 rowsInlines    { { {inlines...} {inlines...} } }
}
```

### Inline field names

| Field | Content |
|-------|---------|
| `type` | `text` `strong` `emphasis` `inline_code` `link` `image` `span` `strike` `linebreak` `softbreak` `math` `footnote_ref` |
| `value` | text content (type=text, strong, emphasis, inline_code, strike) |
| `url` | URL (type=link, image) |
| `title` | title attribute (type=link, image) |
| `label` | inline list for link label |
| `class` | CSS class (type=span) |
| `content` | inline list (type=span) |

---

## Error handling

- Syntax errors are **never thrown**
- The parser is **fault-tolerant**
- Unknown syntax is treated as a paragraph

---

## Non-goals

- No rendering
- No editing
- No file management
- No GUI
