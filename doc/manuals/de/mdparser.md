# mdparser

> **API reference:** [English version](../en/mdparser.md)
> This German documentation covers concepts and usage scenarios.
> For exact signatures and options refer to the English version.


## Zweck

`mdparser` wandelt Markdown-Text in eine **abstrakte Syntaxstruktur (AST)** um.

Das Modul:
- ist **zustandslos**
- hat **keine GUI**
- erzeugt **reines Datenmaterial**

`mdparser` ist die **einzige Stelle**, an der Markdown-Syntax interpretiert wird.

---

## Unterstützte Elemente

### Blöcke

| Element | Syntax | Beispiel |
|---------|--------|----------|
| Überschriften | `#` bis `######` | `## H2` |
| Absätze | Leerzeile trennt | |
| Code-Blöcke (Fence) | ` ``` ` | ` ```tcl ` |
| Code-Blöcke (Einrückung) | 4 Spaces | |
| Listen (ungeordnet) | `- ` / `* ` / `+ ` | `- Item` |
| Listen (geordnet) | `1. ` | `1. Item` |
| Verschachtelte Listen | 2+ Spaces Einrückung | `  - Sub` |
| Task Lists | `- [ ]` / `- [x]` | `- [x] Erledigt` |
| Definitionslisten | `Begriff\n: Definition` | |
| Horizontale Linie | `---` | |
| Tabellen (GFM) | `\| A \| B \|` | |
| Blockquotes | `> ` | `> Zitat` |
| Fenced Divs (TIP-700) | `::: {.class} ... :::` | |
| Standalone-Bilder | `![alt](url)` | |
| YAML-Frontmatter | `---` am Dokumentanfang | |

### Inline

| Element | Syntax |
|---------|--------|
| Fett | `**text**` |
| Kursiv | `*text*` |
| Durchgestrichen | `~~text~~` |
| Code | `` `code` `` |
| Links | `[text](url)` |
| Referenz-Links | `[text][ref]` / `[text]` |
| Autolinks | `<https://...>` / bare URLs |
| Inline-Bilder | `![alt](url)` |
| Harter Zeilenumbruch | zwei Leerzeichen am Zeilenende |
| Backslash-Escape | `\*` `\_` `\`` etc. |
| Bracketed Spans (TIP-700) | `[text]{.class}` |

### Verschachtelte Listen

Gemischte Typen sind erlaubt (geordnet außen, ungeordnet innen):

```tcl
set md {1. First
   - Sub A
   - Sub B
2. Second}

set ast [mdparser::parse $md]
set lst [lindex [dict get $ast blocks] 0]
# -> type=list style=ordered  items=2
# -> item 0: blocks=[paragraph, list(unordered)]
```

### Definitionslisten

```markdown
Begriff
: Definition

Wort
: Bedeutung 1
: Bedeutung 2
```

### YAML-Frontmatter

```markdown
---
title: Mein Dokument
author: Gregor
date: 2026-03-14
---

# Inhalt beginnt hier
```

Zugriff über `dict get $ast meta`.

### TIP-700 Bracketed Spans

```markdown
Der [Befehl]{.cmd} nimmt ein [Argument]{.arg}.
```

Klassen: `.cmd` `.sub` `.lit` `.optlit` `.arg` `.optarg` `.ins`
`.ccmd` `.cargs` `.ret`

### Fenced Divs

```markdown
::: {.note}
Dies ist ein Hinweis-Block.
:::
```

---

## Abhängigkeiten

- Tcl ≥ 8.6
- Keine Tk-Abhängigkeit

---

## Öffentliche API

### `mdparser::parse markdown`

Parst Markdown-Text und liefert ein AST zurück.

```tcl
set ast [mdparser::parse "# Titel\n\nText."]
```

**Rückgabewert:** `dict` mit Schlüsseln `version`, `meta`, `reflinks`, `blocks`

### Datei parsen

```tcl
set fd [open README.md r]
fconfigure $fd -encoding utf-8
set content [read $fd]
close $fd
set ast [mdparser::parse $content]
```

---

## AST-Struktur

### Dokument-Root

```tcl
{
    version  1
    meta     {}          ;# YAML-Frontmatter als Dict
    reflinks {}          ;# Referenz-Link-Definitionen
    blocks   { ... }     ;# Liste der Block-Nodes
}
```

### Überschrift

```tcl
{type heading  level 2  anchor "mein-titel"
 content {{type text value "Mein Titel"}}}
```

### Liste und list_item

```tcl
{type list  style unordered  items {
    {type list_item  blocks {
        {type paragraph content {{type text value "Item-Text"}}}
        ;# optionale Unterliste als zweiter Block:
        {type list style unordered items { ... }}
    }}
}}
```

Hinweis: `style` ist `"ordered"` oder `"unordered"` (kein Boolean).

### Code-Block

```tcl
{type code_block  language "tcl"  value "puts hallo"}
```

### Tabelle

```tcl
{type table
 header      {Spalte1 Spalte2}
 alignments  {left right}
 rows        {{Wert1 Wert2}}
 headerInlines  { {inlines...} {inlines...} }
 rowsInlines    { { {inlines...} {inlines...} } }
}
```

### Inline-Feldnamen

| Feld | Inhalt |
|------|--------|
| `type` | `text` `strong` `emphasis` `inline_code` `link` `image` `span` `strike` `linebreak` |
| `value` | Textinhalt (type=text, strong, emphasis, inline_code, strike) |
| `url` | URL (type=link, image) |
| `title` | Titel-Attribut (type=link, image) |
| `label` | Inline-Liste für Link-Label |
| `class` | CSS-Klasse (type=span) |
| `content` | Inline-Liste (type=span) |

---

## Fehlerbehandlung

- Syntaxfehler werden **nicht geworfen**
- Der Parser ist **fehlertolerant**
- Unbekannte Syntax wird als Absatz behandelt

---

## Nicht-Ziele

- Kein Rendering
- Kein Editieren
- Kein Dateimanagement
- Keine GUI
