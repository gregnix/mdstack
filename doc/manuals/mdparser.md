# mdparser

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
| Code-Blöcke | ` ``` ` | ` ```tcl ` |
| Listen (ungeordnet) | `- ` / `* ` / `+ ` | `- Item` |
| Listen (geordnet) | `1. ` | `1. Item` |
| Task Lists | `- [ ]` / `- [x]` | `- [x] Done` |
| Horizontale Linie | `---` | |
| **Tabellen (GFM)** | `\| A \| B \|` | |
| **Blockquotes** | `> ` | `> Zitat` |
| **Standalone Images** | `![](url)` | |

### Inline

| Element | Syntax |
|---------|--------|
| Fett | `**text**` |
| Kursiv | `*text*` |
| Durchgestrichen | `~~text~~` |
| Code | `` `code` `` |
| Links | `[text](url)` |
| **Inline-Bilder** | `![alt](url)` |

---

## Typische Einsatzszenarien

- Parsing von Markdown für Anzeige (Viewer)
- Parsing als Grundlage für Editoren
- Tests von Markdown-Inhalten
- Vorverarbeitung für Analyse (TOC, Links, Suche)

---

## Abhängigkeiten

- Tcl ≥ 8.6
- keine Tk-Abhängigkeit

---

## Öffentliche API

### `mdparser::parse markdown`

Parst Markdown-Text und liefert ein **AST** zurück.

```tcl
set ast [mdparser::parse "# Title\n\nText"]
```

#### Rückgabewert

* `dict` mit Struktur: `{version 1 blocks {...}}`

---

### Datei parsen

```tcl
set fd [open README.md r]
fconfigure $fd -encoding utf-8
set content [read $fd]
close $fd
set ast [mdparser::parse $content]
```

---

## AST-Struktur (Beispiele)

### Überschrift

```tcl
{type heading level 2 inlines {{type text text "Titel"}}}
```

### Tabelle

```tcl
{type table header {Spalte1 Spalte2} alignments {left right} rows {{Wert1 Wert2}}}
```

### Blockquote

```tcl
{type blockquote inlines {{type text text "Zitat"}}}
```

### Image (standalone)

```tcl
{type image alt "Beschreibung" url "bild.png"}
```

### Task List

```tcl
{type list ordered 0 items {
    {checked 1 inlines {{type text text "Erledigt"}}}
    {checked 0 inlines {{type text text "Offen"}}}
}}
```

---

## Fehlerbehandlung

* Syntaxfehler werden **nicht geworfen**
* Der Parser ist **fehlertolerant**
* Unbekannte Syntax wird als Paragraph behandelt

---

## Nicht-Ziele

* Kein Rendering
* Kein Editieren
* Kein Dateimanagement
* Keine UI

Diese Aufgaben liegen **außerhalb** von mdparser.
