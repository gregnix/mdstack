# mdmodel

> **API reference:** [English version](../en/mdmodel.md)
> This German documentation covers concepts and usage scenarios.
> For exact signatures and options refer to the English version.


## Zweck

`mdmodel` stellt ein **semantisches Dokumentmodell** für Markdown bereit.

Es sitzt **zwischen Parser und Viewer**:

```
Markdown → mdparser (AST) → mdmodel (Dokumentmodell) → mdviewer
```

Das Modul:
- interpretiert das AST semantisch
- stellt strukturierte Informationen bereit
- ist **GUI-unabhängig**

`mdmodel` ist die zentrale Stelle für:
- Inhaltsverzeichnisse
- Suche
- Querverweise
- Analyse von Dokumenten

---

## Typische Einsatzszenarien

- Erzeugen eines Inhaltsverzeichnisses (TOC)
- Volltext- oder Abschnittssuche
- Analyse von Überschriften und Anchors
- Grundlage für Navigation in Viewern
- Verarbeitung von Markdown außerhalb einer GUI

---

## Abhängigkeiten

- Tcl ≥ 8.6
- mdparser 0.2

Keine Tk-Abhängigkeit.

---

## Dokumentmodell (Überblick)

Ein Dokumentmodell ist ein `dict`, das enthält:

- `ast` – das ursprüngliche AST
- `headings` – Liste aller Überschriften
- `anchors` – Dictionary (anchor → heading)
- `type` – immer "mdmodel"
- `version` – Modell-Version (aktuell: 1)

Das exakte Format ist in  
`docs/technical/EDIT-MODEL-v1.md` beschrieben.

---

## Öffentliche API

### `mdmodel::new ast`

Erzeugt ein Dokumentmodell aus einem AST.

```tcl
set ast [mdparser::parse $markdown]
set doc [mdmodel::new $ast]
```

#### Rückgabewert

* Dokumentmodell (`dict`)

---

### `mdmodel::ast docModel`

Gibt das zugrundeliegende AST zurück.

```tcl
set ast [mdmodel::ast $doc]
```

---

### `mdmodel::toc docModel`

Erzeugt ein Inhaltsverzeichnis.

```tcl
set toc [mdmodel::toc $doc]
```

Rückgabewert:

* Liste von TOC-Einträgen (jeder Eintrag: `level`, `text`, `anchor`)

**Hinweis:** `toc` gibt die gleichen Daten wie `headings` zurück.

---

### `mdmodel::headings docModel`

Gibt alle Überschriften zurück.

```tcl
set h [mdmodel::headings $doc]
```

Rückgabewert:

* Liste von Überschriften-Dicts mit:
  * `level` – Überschriftenebene (1-6)
  * `text` – Überschriftentext
  * `anchor` – Anchor-ID für Sprungmarken

---

### `mdmodel::anchors docModel`

Gibt ein Dictionary aller Anchors zurück.

```tcl
set anchors [mdmodel::anchors $doc]
```

Rückgabewert:

* Dictionary: `anchor → heading-dict`

Nützlich für:
- Schnelle Anchor-Lookup
- Navigation zu bestimmten Überschriften
- Validierung von internen Links

---

### `mdmodel::find docModel pattern`

Durchsucht das Dokument nach einem Regexp-Pattern.

```tcl
set hits [mdmodel::find $doc "Begriff"]
```

Rückgabewert:

* Liste von gefundenen Blöcken (AST-Blöcke, die das Pattern enthalten)

**Hinweis:** Sucht in:
- Überschriften
- Absätzen
- Code-Blöcken
- Listen

---

### `mdmodel::meta docModel`

Gibt Metadaten aus dem AST zurück.

```tcl
set meta [mdmodel::meta $doc]
```

Rückgabewert:

* Metadaten-Dict (aus dem AST)

---

## Fehlerbehandlung

* mdmodel wirft **Tcl-Fehler** bei ungültigem AST
* AST muss Format "document" mit Version 1 haben
* Fehler werden nicht im Modell gesammelt

---

## Typische Fehler

* AST manuell verändern
  → AST ist read-only
* mdmodel mit GUI-Logik vermischen
  → mdmodel ist rein logisch
* Modellstruktur fest einbauen
  → nur über API zugreifen
* `find` mit zu komplexen Regexp-Patterns
  → kann langsam werden bei großen Dokumenten

---

## Zusammenspiel mit anderen Modulen

| Modul       | Rolle                   |
| ----------- | ----------------------- |
| mdstack     | Orchestrierung          |
| mdparser    | Syntax → AST            |
| mdmodel     | AST → Bedeutung         |
| mdviewer    | Bedeutung → Darstellung |
| mdtext      | Editor-Widget           |

---

## Beispiel: TOC erstellen

```tcl
set ast [mdparser::parse $markdown]
set doc [mdmodel::new $ast]
set headings [mdmodel::headings $doc]

foreach h $headings {
    set level [dict get $h level]
    set text [dict get $h text]
    set anchor [dict get $h anchor]
    puts "[string repeat "  " [expr {$level - 1}]]$text ($anchor)"
}
```

---

## Beispiel: Suche

```tcl
set ast [mdparser::parse $markdown]
set doc [mdmodel::new $ast]
set results [mdmodel::find $doc "wichtig"]

puts "Gefunden: [llength $results] Stellen"
foreach block $results {
    puts "Block-Typ: [dict get $block type]"
}
```

---

## Nicht-Ziele

* Kein Rendering
* Kein Editieren
* Keine UI
* Kein Dateizugriff
* Keine Link-Extraktion (nur über AST möglich)

Diese Aufgaben liegen außerhalb von mdmodel.
