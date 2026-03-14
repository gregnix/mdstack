# mdviewer

## Zweck

`mdviewer` rendert ein Markdown-Dokument **read-only** in eine Tk-GUI.

Das Modul:
- zeigt Markdown-Inhalte an
- rendert Bilder (PNG, GIF, JPG)
- erlaubt Navigation (Links)
- ist **kein Editor**

---

## Unterstützte Elemente

| Element | Rendering |
|---------|-----------|
| Überschriften | Font-Größe + Bold |
| Listen | Einrückung + Bullet/Nummer |
| Task Lists | ☑ / ☐ Symbole |
| Code-Blöcke | Monospace + Hintergrund |
| **Tabellen** | Box-Drawing (│ ├ ┼) mit Alignment |
| **Blockquotes** | │ Prefix pro Zeile + **kursive Formatierung** |
| **Bilder** | Echte Bilder oder [alt] Fallback |
| Links | Blau + Unterstrichen + Klickbar |

---

## Typische Einsatzszenarien

- Anzeige von Markdown-Dokumentation
- Hilfe-/Info-Viewer
- Preview-Komponente in Editoren
- Ersatz für alte mdhelp-Viewer

---

## Abhängigkeiten

- Tcl/Tk >= 8.6
- mdparser 0.2
- mdmodel 0.1
- Optional: Img-Paket (fuer JPG)

---

## Öffentliche API

### `mdviewer::create path ?options?`

Erzeugt einen Markdown-Viewer.

```tcl
set v [mdviewer::create .v -root $docsDir -onlink onLink]
pack $v -fill both -expand 1
```

#### Optionen

| Option | Beschreibung |
|--------|--------------|
| `-root` | Basis-Pfad für relative Bild-URLs |
| `-onlink` | Callback bei Klick auf Links (erhält URL) |
| `-onclick` | Callback bei Klick irgendwo (erhält x y index tags lineText) |

---

### `-onclick` Callback

Wird aufgerufen bei jedem Klick im Viewer.

```tcl
proc handleClick {x y index tags lineText} {
    # x, y      = Pixel-Koordinaten
    # index     = Text-Widget Index (z.B. "5.12")
    # tags      = Liste der Tags an dieser Position
    # lineText  = Text der angeklickten Zeile
    
    set line [lindex [split $index .] 0]
    puts "Zeile $line: $lineText"
    
    # Überschrift angeklickt?
    if {"h1" in $tags || "h2" in $tags || "h3" in $tags} {
        puts "Überschrift: $lineText"
    }
}

set v [mdviewer::create .v -onclick handleClick]
```

---

### `mdviewer::render path ast`

Rendert ein **AST** direkt.

```tcl
set ast [mdparser::parse "# Title\n\nText"]
mdviewer::render $v $ast
```

---

### `mdviewer::renderModel path docModel`

Rendert ein **mdmodel-Dokumentmodell**.

```tcl
set ast [mdparser::parse $markdown]
set doc [mdmodel::new $ast]
mdviewer::renderModel $v $doc
```

---

### `mdviewer::configure path ?options?`

Konfiguration ändern.

```tcl
mdviewer::configure $v -root /new/path
```

---

### `mdviewer::cget path option`

Option abfragen.

```tcl
set root [mdviewer::cget $v -root]
```

---

### `mdviewer::setFontSize path size`

Passt alle Tags proportional an die neue Basis-Schriftgroesse an.

```tcl
mdviewer::setFontSize $v 14
```

---

### `mdviewer::gotoAnchor path anchor`

Scrollt zum Heading mit dem angegebenen Anchor. Gibt 1/0 zurueck.

```tcl
mdviewer::gotoAnchor $v "installation"
```

---

### `mdviewer::anchors path`

Gibt eine Liste aller Anchor-Namen im Dokument zurueck.

---

### `mdviewer::clear path`

Leert den Viewer.

---

### `mdviewer::widget path`

Gibt das zugrundeliegende Text-Widget zurück.

---

## Bild-Unterstützung

### Unterstützte Formate

| Format | Unterstützung |
|--------|---------------|
| PNG | ✅ nativ |
| GIF | ✅ nativ |
| JPG | ✅ mit Img-Paket |

### Skalierung

| Kontext | Max. Größe |
|---------|------------|
| Standalone | 200px |
| Inline | 60px |
| In Tabellen | 40px |

### Fallback

Wenn ein Bild nicht geladen werden kann:
- `[Bild: alt-text]` für Standalone
- `[alt-text]` für Inline

### Relative Pfade

```tcl
set v [mdviewer::create .v -root /pfad/zu/docs]
# ![Bild](images/foto.png) → /pfad/zu/docs/images/foto.png
```

---

## Link-Handling

Links werden nicht automatisch geöffnet.

```tcl
proc onLink {url} {
    # Externe Links im Browser öffnen
    if {[string match "http*" $url]} {
        exec xdg-open $url &
    }
}

set v [mdviewer::create .v -onlink onLink]
```

---

## Tabellen-Rendering

- Dynamische Spaltenbreiten
- Alignment: left, center, right (via GFM `:---:`)
- Monospace-Font für Ausrichtung
- Box-Drawing-Zeichen: │ ├ ┼ ┤ ─

## Blockquote-Rendering

**Features:**
- Text innerhalb von Blockquotes wird **kursiv** dargestellt
- Visuelle Quote-Balken (│) für jede Verschachtelungsebene
- Unterstützung für verschachtelte Blockquotes mit korrekter Einrückung
- Inline-Formatierung (kursiv, fett) funktioniert innerhalb von Blockquotes
- Mehrzeilige Blockquotes werden korrekt mit Zeilenumbrüchen dargestellt

**Beispiel:**
```markdown
> Dies ist ein einfaches Zitat.
> 
> Es enthält *kursiven* Text und **fett** Text.
> 
> > Verschachteltes Zitat.
```

Wird gerendert als:
- Kursiver Text für den gesamten Blockquote-Inhalt
- Quote-Balken (│) am Anfang jeder Zeile
- Inline-Formatierung (*kursiv*, **fett**) wird korrekt angezeigt

---

## Nicht-Ziele

* Kein Editieren
* Kein Speichern
* Keine Dateiauswahl

Diese Aufgaben gehören in Anwendungen oder mdeditorkit.
