# mdcontextmenu

> **API reference:** [English version](../en/mdcontextmenu.md)
> This German documentation covers concepts and usage scenarios.
> For exact signatures and options refer to the English version.


## Zweck

`mdcontextmenu` stellt **Rechtsklick-Menüs** für Markdown-Editoren bereit.

Das Modul:
- ist **editor-lokal** (keine App-Logik)
- bietet Formatierungs-Aktionen
- bietet Einfüge-Aktionen
- hat **keine Save/Open/Preview** Funktionen

---

## Architektur

```
mdcontextmenu
    └── uicontextmenu (generisches Menü-System)
```

---

## Abhängigkeiten

- Tcl/Tk ≥ 8.6
- uicontextmenu 0.1

---

## Öffentliche API

### `mdcontextmenu::attachToEditor editor`

Bindet das Kontextmenü an einen mdtext-Editor.

```tcl
package require mdtext 0.1
package require uicontextmenu 0.1
package require mdcontextmenu 0.1

set editor [mdtext::create .editor]
mdcontextmenu::attachToEditor $editor
```

Danach: **Rechtsklick** im Editor öffnet das Menü.

---

## Menü-Einträge

### Bearbeiten

| Eintrag | Accelerator | Beschreibung |
|---------|-------------|--------------|
| Ausschneiden | Ctrl+X | Selektion in Clipboard |
| Kopieren | Ctrl+C | Selektion kopieren |
| Einfügen | Ctrl+V | Aus Clipboard einfügen |

### Formatierung

| Eintrag | Accelerator | Beschreibung |
|---------|-------------|--------------|
| Fett | Ctrl+B | `**text**` |
| Kursiv | Ctrl+I | `*text*` |
| Code | Ctrl+` | `` `text` `` |
| Durchgestrichen | - | `~~text~~` |

### Überschrift (Untermenü)

| Eintrag | Accelerator |
|---------|-------------|
| H1 | Ctrl+1 |
| H2 | Ctrl+2 |
| H3 | Ctrl+3 |
| H4 | - |
| H5 | - |
| H6 | - |

### Liste / Zitat (Untermenü)

| Eintrag | Beschreibung |
|---------|--------------|
| Aufzählung | `- Item` |
| Nummeriert | `1. Item` |
| Checkbox | `- [ ] Task` |
| Zitat | `> Text` |

### Einfügen

| Eintrag | Accelerator | Beschreibung |
|---------|-------------|--------------|
| Link einfügen... | Ctrl+K | Dialog für URL + Text |
| Bild einfügen... | - | Datei-Dialog |
| Tabelle einfügen... | - | Dialog für Spalten/Zeilen |
| Code-Block | - | ` ```\n\n``` ` |
| Horizontale Linie | - | `---` |

### Auswahl

| Eintrag | Accelerator |
|---------|-------------|
| Alles auswählen | Ctrl+A |

---

## Erlaubte Aktionen

Diese Aktionen gehören ins Editor-Kontextmenü:

✅ Cut / Copy / Paste
✅ Formatierung (Bold, Italic, Code, Strike)
✅ Struktur (Headings, Listen, Quotes)
✅ Einfügen (Link, Bild, Tabelle, Code-Block)
✅ Alles auswählen

---

## Nicht erlaubte Aktionen

Diese Aktionen gehören **nicht** ins Editor-Kontextmenü:

❌ Save / Open / Export
❌ Preview ein/aus
❌ Navigation
❌ File-Operationen
❌ Undo/Redo (bereits in Tk eingebaut)

Diese Funktionen gehören in die **Anwendung** oder **Action-Abstraction**.

---

## Beispiel: Kompletter Editor

```tcl
package require Tk
package require mdtext 0.1
package require uicontextmenu 0.1
package require mdcontextmenu 0.1

wm title . "Markdown Editor"

# Editor erstellen
set editor [mdtext::create .editor -width 80 -height 30]
pack $editor -fill both -expand 1

# Features aktivieren
$editor enableFeature smartReturn
$editor enableFeature indent

# Kontextmenü anbinden
mdcontextmenu::attachToEditor $editor
```

---

## Nicht-Ziele

* Keine App-Logik (Save/Open)
* Keine Preview-Steuerung
* Keine Navigation
* Keine Dateiverwaltung

Diese Aufgaben gehören in die Anwendung.

---

# uicontextmenu

## Zweck

`uicontextmenu` ist ein **generisches Kontextmenü-System** für Tcl/Tk.

---

## Öffentliche API

### `uicontextmenu::create path ?options?`

```tcl
set menu [uicontextmenu::create .mymenu -dynamic 1]
```

#### Optionen

| Option | Beschreibung |
|--------|--------------|
| `-tearoff` | 0 oder 1 (Default: 0) |
| `-dynamic` | 0 oder 1 - vor Anzeige aktualisieren |

---

### Einträge hinzufügen

```tcl
uicontextmenu::addItem $menu "Kopieren" \
    -command {clipboard copy} \
    -accelerator "Ctrl+C" \
    -state normal

uicontextmenu::addSeparator $menu

uicontextmenu::addCheckItem $menu "Option" \
    -variable ::myOption \
    -command {puts "Toggled"}
```

---

### An Widget binden

```tcl
uicontextmenu::attach $menu .textwidget
```

Bindet Button-3 (Rechtsklick) automatisch.

---

### Dynamische Menüs

```tcl
uicontextmenu::setUpdateHandler $menu {
    # Wird vor jedem Anzeigen aufgerufen
    updateMenuState
}
```
