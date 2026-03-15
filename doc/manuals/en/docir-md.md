# docir-md

## Purpose

`docir-md` converts an **mdparser AST** into a **DocIR sequence**.

DocIR (Document Intermediate Representation) is a shared intermediate
format used by both `man-viewer` and `mdstack`. It allows a single
renderer (Tk, PDF, HTML) to handle documents from multiple sources
(nroff and Markdown).

```
mdparser AST  →  docir::md::fromAst  →  DocIR sequence
nroff AST     →  docir::roff         →  DocIR sequence
                                              ↓
                                   docir-renderer-tk  →  Tk
```

The module:
- is **stateless**
- has **no GUI dependency**
- returns a **flat list** of DocIR nodes (depth-first traversal)

---

## Dependencies

- Tcl ≥ 8.6
- `mdparser 0.2`
- No Tk dependency

---

## Public API

### `docir::md::fromAst ast`

Converts an mdparser AST into a DocIR sequence.

```tcl
package require docir-md 0.1

set ast [mdparser::parse $markdown]
set ir  [docir::md::fromAst $ast]
```

**Return value:** list of DocIR nodes (flat, depth-first)

---

## Block mapping

| mdparser type | DocIR type | Notes |
|---------------|-----------|-------|
| `document` | `doc_header` | meta from YAML frontmatter |
| `heading` | `heading` | level, anchor as id |
| `paragraph` | `paragraph` | |
| `code_block` | `pre` | kind=code, language |
| `list` (ul/ol) | `list` + `listItem` | kind=ul/ol |
| `blockquote` | `paragraph` | class=blockquote |
| `deflist` | `list` + `listItem` | kind=dl, term in meta |
| `table` | `pre` | kind=table (placeholder) |
| `hr` | `hr` | |
| `div` | — | inner blocks rendered recursively |

## Inline mapping

| mdparser type | DocIR type |
|---------------|-----------|
| `text` | `text` |
| `strong` | `strong` |
| `emphasis` | `emphasis` |
| `inline_code` | `code` |
| `link` | `link` (href in meta) |
| `image` | `text` (fallback: alt text) |
| `linebreak` | `linebreak` |
| `span` | `text` (class attribute ignored) |

---

## DocIR node structure

Every node is a `dict` with at least:

```tcl
{type TYPE  content CONTENT  meta META}
```

Examples:

```tcl
# Heading
{type heading  content "My Title"  meta {level 2 id "my-title"}}

# Paragraph with inlines
{type paragraph  content {{type text value "Text"}}  meta {}}

# Code block
{type pre  content "puts hello"  meta {kind code language tcl}}

# List item
{type listItem  content {{type text value "Item"}}  meta {kind ul}}
```

---

## Example

```tcl
package require mdparser 0.2
package require docir-md 0.1

set md {# Title

A paragraph with **bold** text.

- Item 1
- Item 2
}

set ast [mdparser::parse $md]
set ir  [docir::md::fromAst $ast]

foreach node $ir {
    puts "[dict get $node type]: [string range [dict get $node content] 0 40]"
}
```

---

## Tests

```bash
tclsh tests/test-docir-md.tcl   # 19 tests
tclsh tests/all.tcl --core      # included in group B (Renderer)
```

---

## Non-goals

- No rendering
- No full YAML support (frontmatter key-value only)
- No table rendering (tables passed through as `pre`)
