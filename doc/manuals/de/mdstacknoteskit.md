# mdstacknoteskit

> **API reference:** [English version](../en/mdstacknoteskit.md)
> This German documentation covers concepts and usage scenarios.
> For exact signatures and options refer to the English version.


## Zweck

Adapter zwischen **noteskit** (Notiz-Verwaltung) und **mdstack** (Editor-Orchestrator).

Ermöglicht die Integration von noteskit-Notizen in mdstack-basierte Anwendungen.

---

## Architektur

```
┌─────────────────────────────────────────────────────┐
│                    Anwendung                        │
└─────────────────────────────────────────────────────┘
         │                         │
         ▼                         ▼
┌─────────────────┐     ┌─────────────────────────────┐
│    noteskit     │     │         mdstack             │
│  (CRUD/Storage) │     │  (Editor/Preview/Stack)     │
└─────────────────┘     └─────────────────────────────┘
         │                         │
         └────────┬────────────────┘
                  ▼
         ┌─────────────────┐
         │ mdstacknoteskit│
         │    (Adapter)    │
         └─────────────────┘
```

---

## Verwendung

```tcl
package require noteskit 0.1
package require mdstack 0.1
package require mdstacknoteskit 0.1

# 1. noteskit initialisieren
noteskit::init sqlite -db notes.db

# 2. mdstack Editor-API setzen
mdstack::setEditorAPI \
    -getText  [list $editor get] \
    -setText  [list $editor set] \
    -clear    [list $editor clear]

# 3. Notiz laden
mdstacknoteskit::loadNote $noteId

# 4. Änderungen speichern
mdstacknoteskit::saveCurrent
```

---

## API

### Laden

#### `mdstacknoteskit::loadNote id`

Lädt eine Notiz aus noteskit und pusht sie in mdstack.

```tcl
set note [mdstacknoteskit::loadNote "12345"]
```

#### `mdstacknoteskit::loadCurrent`

Lädt die aktuelle noteskit-Notiz in mdstack.

```tcl
noteskit::load $someId
mdstacknoteskit::loadCurrent
```

---

### Speichern

#### `mdstacknoteskit::saveCurrent`

Speichert den aktuellen mdstack-Text zurück in noteskit.

```tcl
mdstacknoteskit::saveCurrent
```

#### `mdstacknoteskit::syncFromEditor`

Synchronisiert Editor-Text in noteskit::currentNote (ohne zu speichern).

```tcl
mdstacknoteskit::syncFromEditor
```

---

### Erstellen/Löschen

#### `mdstacknoteskit::newNote ?title?`

Erstellt eine neue Notiz und pusht sie in mdstack.

```tcl
set note [mdstacknoteskit::newNote "Meine Notiz"]
```

#### `mdstacknoteskit::deleteCurrent`

Löscht die aktuelle Notiz aus noteskit und mdstack.

```tcl
mdstacknoteskit::deleteCurrent
```

---

### Callbacks

#### `mdstacknoteskit::onSave callback`

Callback nach dem Speichern.

```tcl
mdstacknoteskit::onSave {id title} {
    puts "Gespeichert: $title ($id)"
}
```

#### `mdstacknoteskit::onLoad callback`

Callback nach dem Laden.

```tcl
mdstacknoteskit::onLoad {id title} {
    puts "Geladen: $title"
    set ::windowTitle $title
}
```

---

### Hilfsfunktionen

#### `mdstacknoteskit::listNotes ?filter?`

Liste aller Notizen mit Stack-Status.

```tcl
set notes [mdstacknoteskit::listNotes]
# -> {id ... title ... modified ... inStack 1} ...
```

#### `mdstacknoteskit::isCurrentModified`

Prüft ob aktuelle Notiz geändert wurde.

```tcl
if {[mdstacknoteskit::isCurrentModified]} {
    # Warnung anzeigen
}
```

#### `mdstacknoteskit::currentNoteId`

ID der aktuellen Notiz.

#### `mdstacknoteskit::currentNoteTitle`

Titel der aktuellen Notiz.

---

## Typisches Pattern

```tcl
# Notiz auswählen
proc onSelectNote {id} {
    # Änderungen prüfen
    if {[mdstacknoteskit::isCurrentModified]} {
        set answer [tk_messageBox -type yesnocancel ...]
        if {$answer eq "yes"} {
            mdstacknoteskit::saveCurrent
        } elseif {$answer eq "cancel"} {
            return
        }
    }
    
    # Notiz laden
    mdstacknoteskit::loadNote $id
}

# Speichern
proc onSave {} {
    mdstacknoteskit::saveCurrent
}

# Neue Notiz
proc onNew {} {
    mdstacknoteskit::newNote "Unbenannt"
}
```

---

## Integration mit mdstack Callbacks

```tcl
# mdstack onsave → noteskit speichern
mdstack::onsave {
    mdstacknoteskit::saveCurrent
}

# Oder automatisch:
mdstacknoteskit::setupCallbacks
```

---

## Demo

```bash
wish demo/demo-mdstacknoteskit.tcl
```

---

## Abhängigkeiten

- noteskit 0.1
- mdstack 0.1
