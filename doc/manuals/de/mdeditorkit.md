# mdeditorkit

> **API reference:** [English version](../en/mdeditorkit.md)
> This German documentation covers concepts and usage scenarios.
> For exact signatures and options refer to the English version.


> ⚠️ **Legacy-Modul** - Für neue Projekte wird `mdstack` + `mdtext` + `mdviewer` empfohlen.

## Zweck

`mdeditorkit` ist ein **Editor-Subsystem** für Markdown mit Live-Preview.

Es kombiniert:
- `mdeditor` (Editieren)
- `mdparser` (Markdown → AST)
- `mdmodel` (Dokumentmodell)
- `mdviewer` (Rendering)

und stellt daraus **eine konsistente Edit-/Preview-Pipeline** bereit.

`mdeditorkit` ist **kein vollständiger Editor** und **keine Anwendung**.

---

## Typische Einsatzszenarien

- Edit + Preview in einer Anwendung
- Markdown-Editor als Teil einer Fach-GUI
- Vorbereitung für Migration von Alt-Viewern (z. B. mdhelp)
- Testumgebung für Parser / Renderer

---

## Abhängigkeiten

- Tcl/Tk ≥ 8.6
- mdparser 0.2
- mdmodel 0.1
- mdviewer 0.3
- mdeditor 0.1

---

## Öffentliche API

### `mdeditorkit::create path ?options?`

Erzeugt ein Editor-Subsystem (Split-View).

```tcl
set kit [mdeditorkit::create .kit]
pack $kit -fill both -expand 1
```

#### Optionen

* `-debounce ms`
  Verzögerung zwischen Editieren und Re-Parse (Standard: 300)
* `-mode edit|preview|split`
* `-onerror cmdPrefix`
* `-onchange cmdPrefix`
* `-onlink cmdPrefix` (wird an mdviewer weitergereicht)

---

### `mdeditorkit::settext path markdown`

Setzt den Markdown-Text und triggert sofortiges Parsing.

```tcl
mdeditorkit::settext $kit "# Title\n\nText"
```

---

### `mdeditorkit::gettext path`

Gibt den aktuellen Markdown-Text zurück.

---

### `mdeditorkit::setmode path edit|preview|split`

Schaltet die Darstellung um.

```tcl
mdeditorkit::setmode $kit split
```

---

### `mdeditorkit::mode path`

Gibt den aktuellen Modus zurück.

---

### `mdeditorkit::model path`

Gibt das **Edit-Model v1** zurück (via mdeditor).

Typischer Inhalt:

* text
* dirty
* cursor
* selection

---

### `mdeditorkit::setmodel path editModelDict`

Setzt den Editorzustand (z. B. für Undo/Restore).

---

### `mdeditorkit::getdocmodel path`

Gibt das **mdmodel-Dokumentmodell** zurück.

Damit möglich:

```tcl
set doc [mdeditorkit::getdocmodel $kit]
set toc [mdmodel::toc $doc]
set hits [mdmodel::find $doc "Text"]
```

---

## Fehlerbehandlung

* Parser-Fehler werden **abgefangen**
* Preview bleibt auf dem **letzten gültigen Stand**
* Fehler werden über `-onerror` gemeldet
* Editor bleibt immer bedienbar

---

## Typische Fehler

* `package require` ohne Master-pkgIndex
  → `auto_path` falsch gesetzt
* Zu kleines `-debounce` bei großen Dateien
* Logik im App-Code, die direkt mdparser aufruft
  → gehört nicht in Anwendungen

---

## Nicht-Ziele

* Kein Dateimanagement
* Kein Projekt-/Workspace-Handling
* Keine Such-UI
* Kein Publishing

Diese Dinge gehören **in Anwendungen**, nicht in mdeditorkit.
