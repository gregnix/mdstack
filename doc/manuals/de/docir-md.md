# docir-md

> **API reference:** [English version](../en/docir-md.md)
> This German documentation covers concepts and usage scenarios.
> For exact signatures and options refer to the English version.


## Zweck

`docir-md` wandelt einen **mdparser-AST** in eine **DocIR-Sequenz** um.

DocIR (Document Intermediate Representation) ist eine gemeinsame
Zwischendarstellung, die von `man-viewer` und `mdstack` geteilt wird.
Sie ermöglicht es, verschiedene Renderer (Tk, PDF, HTML) für beide
Dokumentquellen (nroff und Markdown) zu nutzen.

```
mdparser-AST  →  docir::md::fromAst  →  DocIR-Sequenz
nroff-AST     →  docir::roff         →  DocIR-Sequenz
                                               ↓
                                    docir-renderer-tk  →  Tk
```

Das Modul:
- ist **zustandslos**
- hat **keine GUI**
- liefert eine **flache Liste** von DocIR-Nodes (tiefenrekursiv)

---

## Abhängigkeiten

- Tcl ≥ 8.6
- `mdparser 0.2`
- Keine Tk-Abhängigkeit

---

## Öffentliche API

### `docir::md::fromAst ast`

Wandelt einen mdparser-AST in eine DocIR-Sequenz um.

```tcl
package require docir-md 0.1

set ast [mdparser::parse $markdown]
set ir  [docir::md::fromAst $ast]
```

**Rückgabewert:** Liste von DocIR-Nodes (flach, depth-first)

---

## Block-Mapping

| mdparser-Typ | DocIR-Typ | Hinweis |
|-------------|-----------|---------|
| `document` | `doc_header` | meta aus YAML-Frontmatter |
| `heading` | `heading` | level, anchor als id |
| `paragraph` | `paragraph` | |
| `code_block` | `pre` | kind=code, language |
| `list` (ul/ol) | `list` + `listItem` | kind=ul/ol |
| `blockquote` | `paragraph` | class=blockquote |
| `deflist` | `list` + `listItem` | kind=dl, term in meta |
| `table` | `pre` | kind=table (Platzhalter) |
| `hr` | `hr` | |
| `div` | — | innere Blöcke rekursiv |

## Inline-Mapping

| mdparser-Typ | DocIR-Typ |
|-------------|-----------|
| `text` | `text` |
| `strong` | `strong` |
| `emphasis` | `emphasis` |
| `inline_code` | `code` |
| `link` | `link` (href in meta) |
| `image` | `text` (Fallback: alt-Text) |
| `linebreak` | `linebreak` |
| `span` | `text` (class-Attribut ignoriert) |

---

## DocIR-Node-Struktur

Jeder Node ist ein `dict` mit mindestens:

```tcl
{type TYPE  content CONTENT  meta META}
```

Beispiele:

```tcl
# Überschrift
{type heading  content "Mein Titel"  meta {level 2 id "mein-titel"}}

# Absatz mit Inlines
{type paragraph  content {{type text value "Text"}}  meta {}}

# Code-Block
{type pre  content "puts hello"  meta {kind code language tcl}}

# Listenpunkt
{type listItem  content {{type text value "Item"}}  meta {kind ul}}
```

---

## Vollständiges Beispiel

```tcl
package require mdparser 0.2
package require docir-md 0.1

set md {# Titel

Ein Absatz mit **fettem** Text.

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
tclsh tests/test-docir-md.tcl   # 19 Tests
tclsh tests/all.tcl --core      # enthalten in Gruppe B (Renderer)
```

---

## Nicht-Ziele

- Kein Rendering
- Keine vollständige YAML-Unterstützung (nur Frontmatter-Felder)
- Kein Tabellenrendering (Tabellen werden als `pre` durchgereicht)
