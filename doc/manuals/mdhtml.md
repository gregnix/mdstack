# mdhtml -- Markdown to HTML Renderer

**Version:** 0.1  
**Modul:** `mdhtml-0.1.tm`  
**Abhaengigkeiten:** `mdparser-0.2` (fuer `exportFile`)

---

## Ueberblick

`mdhtml` wandelt einen Markdown-AST (erzeugt von `mdparser-0.2`) in sauberes
HTML um. Es ist der HTML-Renderer im mdstack-Oekosystem und ergaenzt
`mdpdf-0.2.tm` (PDF) und `mdviewer-0.3.tm` (Tk-Widget).

```
Markdown
   |
mdparser-0.2  -->  AST
                    |
          +---------+---------+
          |         |         |
       mdhtml     mdpdf    mdviewer
        HTML       PDF        Tk
```

---

## Einbinden

```tcl
tcl::tm::path add /pfad/zu/mdstack-2.0/lib
package require mdhtml 0.1
```

---

## Public API

### mdhtml::render

```tcl
set html [mdhtml::render $ast ?-option wert ...?]
```

Wandelt einen mdparser-AST in einen vollstaendigen HTML-String um.

**Parameter:**

| Option | Standard | Beschreibung |
|--------|----------|--------------|
| `-title` | `""` | Dokument-Titel (Standard: erster H1 oder YAML-Frontmatter) |
| `-toc` | `0` | Inhaltsverzeichnis erzeugen (0 oder 1) |
| `-theme` | `""` | mdtheme-Name: `hell`, `dunkel`, `solarized` |
| `-css` | `""` | Pfad zu externer CSS-Datei |
| `-lang` | `de` | HTML `lang`-Attribut |
| `-encoding` | `utf-8` | Ausgabe-Encoding |

**Beispiel:**

```tcl
package require mdparser 0.2
package require mdhtml 0.1

set ast  [mdparser::parse $markdownText]
set html [mdhtml::render $ast -title "Mein Dokument" -toc 1]
```

---

### mdhtml::export

```tcl
mdhtml::export $ast $outFile ?-option wert ...?
```

Wie `render`, schreibt das Ergebnis aber direkt in eine Datei.

```tcl
mdhtml::export $ast output.html -title "Dokument" -toc 1
```

---

### mdhtml::exportFile

```tcl
mdhtml::exportFile $mdFile $outFile ?-option wert ...?
```

Liest eine Markdown-Datei, parst sie und schreibt HTML in die Ausgabedatei.
Laedt `mdparser-0.2` automatisch.

```tcl
mdhtml::exportFile input.md output.html -title "Titel" -toc 1
```

---

## Unterstuetzte Markdown-Elemente

### Block-Typen

| Typ | Markdown | HTML |
|-----|----------|------|
| `heading` | `# H1` bis `###### H6` | `<h1>` bis `<h6>` mit `id`-Attribut |
| `paragraph` | Normaler Text | `<p>` |
| `code_block` | ` ```lang ` oder `~~~` | `<pre><code class="language-lang">` |
| `hr` | `---` oder `***` | `<hr>` |
| `blockquote` | `> Text` | `<blockquote>` (verschachtelbar) |
| `list` | `- Item` oder `1. Item` | `<ul>` oder `<ol>` |
| `deflist` | `Begriff\n: Def` | `<dl>`, `<dt>`, `<dd>` |
| `table` | `\| A \| B \|` | `<table>` mit `<thead>`, `<tbody>` |
| `image` | `![alt](url)` | `<figure>`, `<img>`, `<figcaption>` |
| `footnote_section` | `[^1]: Text` | `<section class="footnotes">` |

### Inline-Typen

| Typ | Markdown | HTML |
|-----|----------|------|
| `strong` | `**Text**` | `<strong>` |
| `emphasis` | `*Text*` | `<em>` |
| `strike` | `~~Text~~` | `<s>` |
| `inline_code` | `` `Code` `` | `<code>` |
| `link` | `[Label](URL)` | `<a href="URL">` |
| `image` | `![alt](url)` | `<img>` |
| `linebreak` | Zwei Leerzeichen am Zeilenende | `<br>` |
| `span` | `[Text]{.cmd}` | `<span class="cmd">` (TIP-700) |
| `footnote_ref` | `[^1]` | `<sup><a>` |

### Tabellen-Ausrichtung

```markdown
| Links | Zentriert | Rechts |
|-------|:---------:|-------:|
| L     |     C     |      R |
```

Erzeugt `style="text-align:left/center/right"` auf den Zellen.

### Task-Listen

```markdown
- [x] Erledigt
- [ ] Offen
```

Erzeugt `<input type="checkbox" checked/disabled>` vor dem Listenelement.

### TIP-700-Spans

```markdown
Befehl [proc]{.cmd}, Argument [filename]{.arg}, Literal [42]{.lit}
```

Erzeugt `<span class="cmd">proc</span>` etc. mit CSS-Styling.

---

## Inhaltsverzeichnis

Mit `-toc 1` wird ein `<nav class="toc">` vor dem Body eingefuegt.
Aufgenommen werden H1, H2 und H3 (tiefer ignoriert).

```tcl
set html [mdhtml::render $ast -toc 1]
```

---

## Theme und CSS

`mdhtml` unterstuetzt vier Kombinationen fuer das Styling:

### 1. Nur Theme (Basis aus mdtheme)

```tcl
set html [mdhtml::render $ast -theme hell]
set html [mdhtml::render $ast -theme dunkel]
set html [mdhtml::render $ast -theme solarized]
```

Liefert vollstaendiges CSS aus `mdtheme::toCSS`. Voraussetzung:
`package require mdtheme 0.1`.

### 2. Theme + externe Overrides (empfohlen)

```tcl
set html [mdhtml::render $ast -theme hell -css custom.css]
```

Theme-CSS als Basis, `custom.css` wird dahinter angehaengt.
Spaetera Regeln gewinnen -- nur die Unterschiede schreiben:

```css
/* custom.css -- nur Overrides, Rest kommt aus dem Theme */
body { font-size: 14pt; max-width: 700px; }
h1   { color: #cc0000; }
a    { color: #008800; font-weight: bold; }
```

### 3. Nur externe CSS-Datei

```tcl
set html [mdhtml::render $ast -css /pfad/zu/style.css]
```

Vollstaendige externe CSS-Datei, kein Theme-CSS.

### 4. Eingebettetes Default

```tcl
set html [mdhtml::render $ast]
```

Responsive eingebettetes CSS (Georgia/serif, max-width 860px, helles Theme).
Wird verwendet wenn weder `-theme` noch `-css` angegeben.

### Prioritaet

```
-theme + -css  -->  Theme-CSS + custom.css (kombiniert)
-theme only    -->  Theme-CSS (vollstaendig)
-css only      -->  externe Datei (vollstaendig)
(nichts)       -->  eingebettetes Default
```

---

## YAML-Frontmatter

`mdparser` verarbeitet YAML-Frontmatter automatisch. Der `title`-Wert
wird als Standard-Dokumenttitel verwendet:

```markdown
---
title: Mein Dokument
---

# Ueberschrift
```

```tcl
set ast  [mdparser::parse $md]
# Titel kommt automatisch aus dem Frontmatter
set html [mdhtml::render $ast]
```

---

## Vollstaendiges Beispiel

```tcl
package require mdparser 0.2
package require mdhtml 0.1

set markdown {
# Dokumentation

Eine **wichtige** Funktion mit [Link](https://tcl.tk).

## API

| Methode | Beschreibung |
|---------|--------------|
| `proc` | Prozedur definieren |
| `set`  | Variable setzen |

```tcl
proc hello {name} {
    puts "Hallo, $name!"
}
```
}

set ast [mdparser::parse $markdown]
mdhtml::export $ast /tmp/doku.html -title "Dokumentation" -toc 1 -lang de
```

---

## Architektur

```
mdhtml::exportFile
   |
mdparser::parse  -->  AST (document-Dict)
   |
mdhtml::render
   |
mdhtml::_renderBlock  (Dispatcher per Block-Typ)
   |
+----------+----------+----------+----------+
|          |          |          |          |
_renderList _renderTable _renderDefList _renderFootnotes
   |
mdhtml::_inlinesToHtml  (Inlines rekursiv)
   |
mdhtml::_wrapDocument   (vollstaendiges HTML-Dokument)
```

### Hilfsprozeduren (intern)

| Prozedur | Funktion |
|----------|---------|
| `mdhtml::escapeHtml` | `& < > "` escapen |
| `mdhtml::escapeAttr` | Attributwerte escapen |
| `mdhtml::_makeId` | Text -> URL-sichere ID |
| `mdhtml::_buildToc` | TOC aus H1-H3 aufbauen |
| `mdhtml::_inlinesToText` | Inlines als Plaintext |
| `mdhtml::_defaultCss` | Eingebettetes CSS |

---

## Bekannte Einschraenkungen

- Keine Bild-Einbettung (Base64) -- nur `src`-Referenzen
- Keine Syntax-Hervorhebung im Code-Block (nur `language-X`-Klasse fuer externe Highlighter wie highlight.js)
- Fussnoten werden am Ende des Dokuments gesammelt, nicht seitenweise

---

## Changelog

### 0.1.1 (2026-03-14)

- `-theme` + `-css` kombinierbar: Theme als Basis, externe Datei als Overrides
- Prioritaets-Logik: theme+css > theme > css > default

### 0.1 (2026-03-14)

- Initiale Version
- Alle Block-Typen: heading, paragraph, code_block, hr, blockquote,
  list (ul/ol/task), deflist, table, image, footnote_section
- Alle Inline-Typen: text, strong, emphasis, strike, inline_code,
  link, image, linebreak, span (TIP-700), footnote_ref
- Tabellen mit Ausrichtung (`alignments`-Feld)
- TOC fuer H1-H3
- Theme-Integration via `mdtheme::toCSS`
- Eingebettetes CSS (responsive, max-width 860px)
- `render`, `export`, `exportFile` API
