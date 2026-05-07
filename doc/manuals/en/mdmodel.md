# mdstack::model

## Purpose

`mdstack::model` provides a **semantic document model** for Markdown.

It sits **between parser and viewer**:

```
Markdown → mdstack::parser (AST) → mdstack::model (document model) → mdstack::viewer
```

The module:
- interprets the AST semantically
- provides structured document information
- is **GUI-independent**

`mdstack::model` is the central place for:
- table of contents
- search
- cross-references
- document analysis

---

## Dependencies

- Tcl ≥ 8.6
- `mdstack::parser 0.2`
- No Tk dependency

---

## Public API

### `mdstack::model::new ast`

Creates a document model from an AST.

```tcl
set ast [mdstack::parser::parse $markdown]
set doc [mdstack::model::new $ast]
```

**Return value:** document model (`dict`)

---

### `mdstack::model::ast docModel`

Returns the underlying AST.

```tcl
set ast [mdstack::model::ast $doc]
```

---

### `mdstack::model::toc docModel`

Returns a table of contents.

```tcl
set toc [mdstack::model::toc $doc]
foreach entry $toc {
    set level  [dict get $entry level]
    set text   [dict get $entry text]
    set anchor [dict get $entry anchor]
    puts "[string repeat "  " [expr {$level-1}]]$text"
}
```

**Return value:** list of dicts with keys `level`, `text`, `anchor`

---

### `mdstack::model::headings docModel`

Returns all headings.

```tcl
set headings [mdstack::model::headings $doc]
```

Each entry: `level` `text` `anchor`

---

### `mdstack::model::anchors docModel`

Returns a dictionary of all anchors.

```tcl
set anchors [mdstack::model::anchors $doc]
set heading [dict get $anchors "installation"]
```

**Return value:** dict `anchor → heading-dict`

---

### `mdstack::model::find docModel pattern`

Searches the document for a regexp pattern.

```tcl
set hits [mdstack::model::find $doc "important"]
puts "Found: [llength $hits] locations"
foreach block $hits {
    puts "Block type: [dict get $block type]"
}
```

Searches in: headings, paragraphs, code blocks, lists (including nested
via `list_item blocks`).

**Return value:** list of matching AST block nodes

---

### `mdstack::model::meta docModel`

Returns document metadata (from YAML frontmatter).

```tcl
set meta [mdstack::model::meta $doc]
if {[dict exists $meta title]} {
    puts "Title: [dict get $meta title]"
}
```

---

## Document model structure

```tcl
{
    type     "mdstack::model"
    version  1
    ast      { ... }    ;# original AST
    headings { ... }    ;# extracted heading list
    anchors  { ... }    ;# anchor → heading dict
}
```

---

## AST field names (current)

| Old (pre-0.3.1) | Current | Notes |
|-----------------|---------|-------|
| `inlines` | `content` | heading, paragraph, blockquote |
| `ordered` (bool) | `style` (string) | list: `"ordered"` or `"unordered"` |
| `text` (inline) | `value` | text, strong, emphasis, inline_code |
| `code` (inline) | `value` | inline_code |
| `content` + `children` | `blocks` | list_item |

List items now use `blocks` (list of block nodes):
- `blocks[0]` is always a paragraph with the item text
- `blocks[1]` (optional) is a sublist

---

## Error handling

- `mdstack::model::new` throws a Tcl error if AST is invalid
- AST must have `type document` with `version 1`
- Errors are not collected in the model

---

## Non-goals

- No rendering
- No editing
- No GUI
- No file access
