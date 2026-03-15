# mdpdf

> **API reference:** [English version](../en/mdpdf.md)
> This German documentation covers concepts and usage scenarios.
> For exact signatures and options refer to the English version.


> Version 0.2 – pdf4tcllib-Backend

## Zweck

`mdpdf` exportiert Markdown-Dokumente als PDF-Dateien.

Das Modul:
- konvertiert Markdown-AST oder Model in PDF
- unterstützt alle Block-Typen (Headings, Paragraphs, Lists, Code, Blockquotes, HR)
- generiert Inhaltsverzeichnis (TOC)
- unterstützt Custom Footer mit Seitenzahlen
- rendert Blockquotes mit kursive Formatierung
- sanitized Unicode-Zeichen für PDF-Standard-Fonts

---

## Unterstützte Elemente

| Element | Rendering |
|---------|-----------|
| Überschriften | Font-Größe + Bold (H1-H6) |
| Absätze | Text mit Umbruch |
| Listen | Einrückung + Bullet/Nummer |
| Code-Blöcke | Monospace-Font |
| **Blockquotes** | Einrückung + **kursive Formatierung** |
| **Tabellen** | Spalten mit Alignment (links, zentriert, rechts) |
| **Bilder** | Bild-Rendering mit Fallback auf Alt-Text |
| Horizontale Linie | `---` |
| Inhaltsverzeichnis | Automatisch generiert (ohne Seitenzahlen) |

**Inline-Formatierung:**
- **Fett** (`**text**`)
- *Kursiv* (`*text*`)
- `Code` (`` `code` ``)
- Kombinationen (z.B. ***fett und kursiv***)

---

## Abhängigkeiten

- Tcl ≥ 8.6
- pdf4tcl 0.9+
- pdf4tcllib 0.1
- mdparser 0.2 (optional, für AST)
- mdmodel 0.1 (optional, für Model)

---

## Oeffentliche API

### `mdpdf::exportFile mdFile outputFile ?options?`

Liest eine Markdown-Datei und exportiert sie als PDF.
**Empfohlene API fuer Dateien mit Emojis und Sonderzeichen.**

Liest die Datei binaer und ersetzt Emoji-Bytes (4-Byte UTF-8)
durch ASCII-Fallbacks, bevor Tcl 8.6 sie zu U+FFFD zerstoert.
Intern: `open rb` -> `preprocessBytes` -> `encoding convertfrom` -> `parse` -> `export`.

```tcl
package require mdpdf 0.2

mdpdf::exportFile "input.md" "output.pdf" \
    -title "Dokumentation" \
    -toc 1 \
    -fontsize 11 \
    -footer "Seite %p"
```

---

### `mdpdf::export ast outputFile ?options?`

Exportiert ein **AST** als PDF.

```tcl
package require mdpdf 0.2
package require pdf4tcl
package require mdparser 0.2

set ast [mdparser::parse $markdown]
mdpdf::export $ast "output.pdf" \
    -title "Dokumentation" \
    -toc 1 \
    -fontsize 11 \
    -footer "Seite %p"
```

---

### `mdpdf::exportModel doc outputFile ?options?`

Exportiert ein **mdmodel-Dokumentmodell** als PDF.

```tcl
package require mdpdf 0.2
package require pdf4tcl
package require mdmodel 0.1

set doc [mdmodel::new $ast]
mdpdf::exportModel $doc "output.pdf" \
    -title "Dokumentation" \
    -toc 1
```

---

### Optionen

| Option | Standard | Beschreibung |
|--------|----------|--------------|
| `-title` | `""` | Titel auf erster Seite |
| `-pagesize` | `A4` | Seitengröße (A4, Letter) |
| `-margin` | `50` | Rand in Punkten |
| `-fontsize` | `11` | Basis-Schriftgröße |
| `-toc` | `0` | Inhaltsverzeichnis (0|1) |
| `-header` | `""` | Header-Text |
| `-footer` | `"- %p -"` | Footer-Text (%p = Seitenzahl) |
| `-root` | `""` | Basis-Pfad für relative Bild-URLs |
| `-fontdir` | `""` | Verzeichnis mit TTF-Dateien |
| `-debug` | `0` | Debug-Ausgaben (0|1) |
| `-compress` | `1` | zlib-Kompression (0 oder 1) |
| `-pdfa` | `""` | PDF/A-Konformität: `1b`, `2b` (pdf4tcl 0.9.4.11) |
| `-userpassword` | `""` | AES-128 Benutzer-Passwort (pdf4tcl 0.9.4.11) |
| `-ownerpassword` | `""` | AES-128 Eigentümer-Passwort (pdf4tcl 0.9.4.11) |
| `-theme` | `""` | mdtheme-Name: `hell`, `dunkel`, `solarized` |

---

### `mdpdf::configure ?options?`

Globale Konfiguration ändern.

```tcl
mdpdf::configure -fontsize 12 -margin 60
```

---

## Beispiele

### Einfaches Dokument

```tcl
set md {# Titel

Dies ist ein **einfaches** Dokument.

## Abschnitt

- Punkt eins
- Punkt zwei
}

set ast [mdparser::parse $md]
mdpdf::export $ast "output.pdf" -title "Mein Dokument"
```

### Mit Inhaltsverzeichnis

```tcl
mdpdf::export $ast "output.pdf" \
    -title "Dokumentation" \
    -toc 1 \
    -fontsize 11
```

### Custom Footer

```tcl
mdpdf::export $ast "output.pdf" \
    -title "Dokumentation" \
    -footer "Seite %p von mdpdf Demo"
```

### Letter Format

```tcl
mdpdf::export $ast "output.pdf" \
    -title "Letter Format" \
    -pagesize Letter \
    -fontsize 11
```

### Mit Header und TrueType-Fonts

```tcl
mdpdf::export $ast "output.pdf" \
    -title "Dokumentation" \
    -header "Dokumentation - Seite %p" \
    -footer "- %p -" \
    -toc 1 \
    -fontsize 11
```

---

## Blockquote-Rendering

**Features:**
- Text innerhalb von Blockquotes wird **kursiv** dargestellt
- Verschachtelte Blockquotes mit korrekter Einrückung
- Inline-Formatierung (kursiv, fett) funktioniert innerhalb von Blockquotes
- Automatische Seitenumbrüche

**Beispiel:**
```markdown
> Dies ist ein einfaches Zitat.
> 
> Es enthält *kursiven* Text und **fett** Text.
> 
> > Verschachteltes Zitat.
```

Wird im PDF gerendert als:
- Kursiver Text für den gesamten Blockquote-Inhalt
- Einrückung basierend auf Verschachtelungstiefe
- Inline-Formatierung (*kursiv*, **fett**) wird korrekt angezeigt

---

## Unicode-Sanitization und Emoji-Fallbacks

PDF-Standard-Fonts (Helvetica, Courier) und auch DejaVu Sans haben
keine Emoji-Glyphen. `mdpdf` ersetzt automatisch nicht darstellbare
Zeichen durch lesbare ASCII-Aequivalente.

**Emoji-Fallbacks (via `preprocessBytes`):**

| Emoji | Fallback | Emoji | Fallback |
|-------|----------|-------|----------|
| :-) Grinning | `:-)`  | Party | `(!)`  |
| :-D Beaming  | `:-D`  | Thumbs Up | `(+1)` |
| :'D Joy      | `:'D`  | Thumbs Down | `(-1)` |
| <3 Heart     | `<3`   | Fire | `(*)`  |
| B-) Cool     | `B-)`  | Rocket | `[>]`  |
| (?) Thinking | `(?)`  | Memo | `[doc]`|

40+ spezifische Mappings plus Range-basierte Defaults (z.B. alle
Smileys -> `:-)`). Siehe pdf4tcllib-Doku fuer die vollstaendige Tabelle.

**BMP-Ersetzungen (via `sanitize`):**

| Unicode | Ersetzung |
|---------|-----------|
| Box-Drawing | ASCII-Zeichen |
| Task List | [x] [ ] |
| Typografie (Gedankenstriche, Anfuehrungszeichen) | ASCII |
| Symbole (Checkmark, Kreuz, Warnung, Herz) | (OK) (X) (!) <3 |

**Latin-1-Zeichen (Umlaute) bleiben erhalten.**

**Wichtig:** `exportFile` fuehrt das Emoji-Preprocessing automatisch aus.
Bei `export` mit vorgeladenem AST muss die Datei manuell binaer gelesen
werden -- siehe pdf4tcllib-Doku fuer den Workflow.


---

## Technische Details

**Font-Breiten-Berechnung:**
- Empirische Faktoren für verschiedene Fonts
- Helvetica: 0.52 × Fontgröße
- Courier: 0.60 × Fontgröße

**Text-Umbruch:**
- Automatischer Umbruch nach Wörtern
- Berücksichtigt Font-Breiten für genaue Berechnung
- Code-Blöcke: Backslash-Fortsetzung bei langen Zeilen

**Seitenumbrüche:**
- Automatisch bei Überschreitung der Seitenhöhe
- Footer wird auf jeder Seite angezeigt
- Seitenzahlen werden automatisch inkrementiert

---

## Tabellen-Rendering

**Features:**
- Automatische Spaltenbreiten-Berechnung basierend auf Inhalt
- Unterstützung für Header mit Alignment (links, zentriert, rechts)
- Rendering von Tabellenzellen mit Textausrichtung
- Seitenumbruch-Behandlung für große Tabellen

**Beispiel:**
```markdown
| Spalte 1 | Spalte 2 | Spalte 3 |
|----------|:--------:|---------:|
| Links    | Mitte    | Rechts   |
| Text     | **Bold** | *Italic* |
```

---

## Bild-Rendering

**Features:**
- Unterstützung für Bild-Blöcke (`image` Block-Typ)
- Pfad-Auflösung relativ zu `-root` Option
- Fallback auf Alt-Text wenn Bild nicht geladen werden kann
- Seitenumbruch-Prüfung vor Bild-Rendering

**Beispiel:**
```markdown
![Beispielbild](image.png)
```

Falls das Bild nicht gefunden wird, wird `[Beispielbild]` als Text angezeigt.

---

## TrueType-Font-Support

**Features:**
- Automatisches Laden von DejaVu Sans Fonts via pdf4tcllib
- Unterstuetzung fuer Windows, Linux und macOS Font-Pfade
- Fallback auf Helvetica/Courier wenn keine TTF-Fonts gefunden
- Unicode-Support ohne Sanitization bei TrueType-Fonts

**Verwendung:**
```tcl
# Automatisch (sucht in Standard-Pfaden)
mdpdf::export $ast "output.pdf"

# Mit explizitem Font-Verzeichnis
mdpdf::export $ast "output.pdf" -fontdir "/pfad/zu/fonts"
```

**Vorteile:**
- Umlaute und Unicode funktionieren korrekt
- Bessere Font-Auswahl (DejaVu Sans statt Helvetica)
- Keine manuelle Unicode-Sanitization noetig

---

## Header-Support

**Features:**
- Header-Rendering auf jeder Seite
- Unterstützung für `%p` Platzhalter für Seitenzahlen
- Header wird bei allen Seitenumbrüchen automatisch eingefügt

**Beispiel:**
```tcl
mdpdf::export $ast "output.pdf" \
    -header "Dokumentation - Seite %p"
```

---

## Einschränkungen

**Noch nicht implementiert:**
- TOC-Seitenzahlen (erfordert zweiphasigen Export)
- Metadaten (Title, Author, Subject)
- Bookmarks (PDF-Bookmarks)

**Bekannte Probleme:**
- Strikethrough wird als normaler Text gerendert (PDF hat kein natives Strikethrough)

**Alternative: mdhelp_pdf**

Fuer Widget-basierten Export (mit Frame-Tabellen, eingebetteten Bildern)
siehe [mdhelp_pdf](mdhelp_pdf.md). Nutzt [pdf4tcllib](pdf4tcllib.md)
als Backend mit erweitertem Unicode-Support und Font-Management.

---

## Siehe auch

- [mdhelp_pdf](mdhelp_pdf.md) - Widget-basierter PDF-Export (nutzt pdf4tcllib)
- [pdf4tcllib](pdf4tcllib.md) - PDF-Erweiterungsbibliothek
- [mdviewer](mdviewer.md) - GUI-Viewer fuer Markdown
- [mdparser](mdparser.md) - Markdown-Parser
- [mdmodel](mdmodel.md) - Dokument-Model

---

## Hyperlinks (neu in 0.2)

Links aus Markdown `[Label](URL)` werden als klickbare PDF-Annotationen
eingebettet. Im PDF-Viewer sind sie anklickbar.

```tcl
set md {
Besuche [Tcl/Tk](https://www.tcl.tk) fuer mehr Informationen.
}
set ast [mdparser::parse $md]
mdpdf::export $ast output.pdf
```

Technisch: `hyperlinkAdd` aus pdf4tcl 0.9.4.11 wird nach jedem
Link-Segment aufgerufen. Die URL wird durch die gesamte
Rendering-Pipeline gereicht:
`_inlinesToSegments` -> `_wrapStyledSegments` -> `_renderStyledLine`.

---

## PDF/A-Export (neu in 0.2)

```tcl
# PDF/A-1b (Langzeitarchivierung)
mdpdf::export $ast output.pdf -pdfa 1b

# PDF/A-2b (moderne Features)
mdpdf::export $ast output.pdf -pdfa 2b
```

Erfordert pdf4tcl 0.9.4.11 mit `-pdfa`-Option.
Fuer vollstaendige Konformitaet eingebettete CIDFonts verwenden
(Standard-Fonts wie Helvetica sind nicht eingebettet).

---

## Verschluesselung (neu in 0.2)

AES-128-Verschluesselung via pdf4tcl 0.9.4.11:

```tcl
# Benutzer-Passwort (Oeffnen gesperrt)
mdpdf::export $ast output.pdf -userpassword "geheim"

# Eigentümer-Passwort (Bearbeitung gesperrt)
mdpdf::export $ast output.pdf -ownerpassword "admin"

# Beides kombiniert
mdpdf::export $ast output.pdf \
    -userpassword  "user123" \
    -ownerpassword "admin456"
```

---

## Theme-Unterstützung (neu in 0.2)

```tcl
package require mdtheme 0.1

# Verfuegbare Themes
mdtheme::names   ;# --> dunkel hell solarized

# Theme anwenden
mdpdf::export $ast output.pdf -theme hell
mdpdf::export $ast output.pdf -theme dunkel
```

Heute wirken: `fontsize` und `margin` aus dem Theme.
Farben (`colorLink`, `colorCode`, `colorHeading`) folgen
mit pdf4tcl 0.9.4.12.

---

## Einschränkungen (aktualisiert)

**Noch nicht implementiert:**
- TOC-Seitenzahlen (erfordert zweiphasigen Export)
- Theme-Farben im PDF (folgt mit pdf4tcl 0.9.4.12)

**Bekannte Probleme:**
- Strikethrough wird als normaler Text gerendert

---

## Changelog

### 0.2 (2026-03-14)

- Klickbare Hyperlinks (`hyperlinkAdd`)
- Neue Optionen: `-compress`, `-pdfa`, `-userpassword`, `-ownerpassword`, `-theme`
- Theme-Integration via `mdtheme::toPdfOpts`
