# mdoutline

> **API reference:** [English version](../en/mdoutline.md)
> This German documentation covers concepts and usage scenarios.
> For exact signatures and options refer to the English version.


## Zweck

`mdoutline` zeigt die **Überschriften-Struktur** eines Markdown-Dokuments
als klickbaren Baum an. Ein Klick springt zur entsprechenden Stelle im Editor.

Das Modul:
- liest Überschriften aus einem `mdtext`-Editor-Widget
- zeigt sie als `ttk::treeview` an
- aktualisiert sich automatisch bei Änderungen (konfigurierbares Intervall)
- ist ein **reines UI-Widget** ohne Geschäftslogik

---

## Abhängigkeiten

- Tcl/Tk ≥ 8.6
- `mdtext 0.1` (als Editor-Quelle)

---

## Öffentliche API

### `mdoutline::create path ?options?`

Erzeugt ein Outline-Panel.

```tcl
set outline [mdoutline::create .outline -editor .editor]
pack $outline -fill both -expand 1
```

#### Optionen

| Option | Standard | Beschreibung |
|--------|----------|-------------|
| `-editor` | — | **Pflicht.** Pfad zum `mdtext`-Editor-Widget |
| `-refresh` | `500` | Aktualisierungsintervall in Millisekunden |

**Rückgabewert:** `path` (das erzeugte Widget)

---

### `mdoutline::refresh path`

Liest den Inhalt des Editors neu und aktualisiert den Baum sofort.

```tcl
mdoutline::refresh .outline
```

---

### `mdoutline::gotoSelection path`

Springt zur aktuell ausgewählten Überschrift im Editor.
Wird normalerweise automatisch bei `<<TreeviewSelect>>` aufgerufen.

```tcl
mdoutline::gotoSelection .outline
```

---

### `mdoutline::dispatch path subcmd ?args?`

Dispatch-Schnittstelle für externe Aufrufe.

```tcl
mdoutline::dispatch .outline refresh
```

---

### `mdoutline::destroy path`

Gibt Ressourcen frei und entfernt das Widget.

```tcl
mdoutline::destroy .outline
```

---

## Darstellung

Überschriften werden nach Ebene gestylt:

| Ebene | Darstellung |
|-------|-------------|
| h1 | 11pt bold |
| h2 | 10pt bold |
| h3 | 10pt normal |
| h4 | 9pt italic |
| h5 | 9pt normal |
| h6 | 8pt normal |

---

## Vollständiges Beispiel

```tcl
package require mdtext   0.1
package require mdoutline 0.1

# PanedWindow: Outline links, Editor rechts
ttk::panedwindow .pw -orient horizontal
pack .pw -fill both -expand 1

set outline [mdoutline::create .outline -editor .editor -refresh 300]
set editor  [mdtext::create .editor]

.pw add .outline -weight 0
.pw add .editor  -weight 1
```

---

## Nicht-Ziele

- Kein Rendering (nur Struktur-Anzeige)
- Keine Suche
- Kein Zugriff auf mdviewer (nur mdtext)
