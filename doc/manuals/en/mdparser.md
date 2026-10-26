# mdstack::parser

> Version 0.9.2

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
| Bracketed spans (TIP-700) | `[text]{.class}`, `[text]{.a .b #id key="v"}` (0.9.0) |
| Section references (0.9.0) | `[Heading text]` -> link to that heading |
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

Since 0.9.0 the braces take a Pandoc attribute list: several classes,
`#id`, `key="value"` / `key='value'` / `key=value`:

```markdown
[*interp]{.carg .in type="Tcl_Interp"}   [lfilter]{.cmd version="TIP735"}
```

The span node gets `class` (all classes, space separated), `id` and `attrs`
(dict of the other attributes). Braces that are no attribute list
(`[a]{a b c}`, `[x]{}`) stay text.

### Switches (0.9.2)

Two namespace variables change the parser for whole documents:

- `::mdstack::parser::inlineMath` (1): 0 turns `$...$` math off. Tcl manual
  pages are full of `$var`.
- `::mdstack::parser::listContinuation` (0): 1 keeps what follows a list
  item after a blank line, indented to its content column, in the item and
  parses it as blocks (CommonMark, Pandoc). With 0 a 4-space line after a
  top-level item starts indented code (the old rule).

createpdf (tcltk-manuals) sets `inlineMath 0` and `listContinuation 1`.
Since 0.9.2 a span may hold a reference link:
`[made by [interp alias][interp].]{version="TIP426"}`.

### Three stars between two emphases (0.9.1)

`*a***b**` is italic *a* followed by bold **b**, `**a***b*` the other way
round, as Pandoc reads it. TIP-700 pages write nroff `\fIa\fBb\fR` like
this. Plain CommonMark left the stars literal when punctuation follows
(`*ZIPFS_VOLUME***/app**`). Only a run of exactly three stars that
touches text on both sides and follows an open `*` or `**` switches;
`foo***bar***baz` is still nested bold italic.

### Section references (0.9.0)

`[Name resolution]` without a link definition links to the heading with
exactly that text (`url "#name-resolution"`, field `sectionRef`). With
several such headings the one in the nearest enclosing section wins; in a
merged manual a reference stays in its page. A target whose anchor an
earlier heading has gets an alias anchor (heading field `alias`). Without
such a heading the brackets stay text.

### Blocks in definitions (0.9.0)

Lines indented 4 spaces (or a tab) after a definition belong to it, also
behind blank lines, and are parsed as blocks (Pandoc):

```markdown
**base64**
: The encoding.

    1. a list
    2. in the definition

    [-maxlen]{.lit}
    : an inner definition list
```

The item keeps `definitions` (flat inline lists, as before) and gets
`defblocks` -- one block list per definition -- when a definition holds
more than paragraphs. Outside definitions an indented block is still
indented code.

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
| `class` | CSS classes, space separated (type=span) |
| `attrs` | dict of further attributes (type=span, 0.9.0) |
| `sectionRef` | heading text of a section reference (type=link, 0.9.0) |
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
