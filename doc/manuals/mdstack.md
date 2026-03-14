# mdstack

## Zweck

`mdstack` ist der **Orchestrator** für Markdown-Dokumente.

Das Modul:
- verwaltet einen **Stack** von Dokumenten
- bindet **Editor** und **Preview** über Callbacks an
- abstrahiert die **Datenquelle** (z.B. noteskit)
- kennt **KEINE konkreten Module** - nur Callbacks

---

## Architektur

```
            mdstack (Orchestrator)
                 │
    ┌────────────┼────────────┐
    ▼            ▼            ▼
  Editor      Preview     Datenquelle
(Callbacks) (Callback)   (noteskit)
```

**WICHTIG:**
- mdstack ruft **niemals** Widget-Methoden auf
- mdstack kennt **keine** Editor-Widgets
- Alles läuft über definierte Callbacks

---

## Abhängigkeiten

- Tcl ≥ 8.6
- Keine Tk-Abhängigkeit
- Keine harte Kopplung zu mdtext, mdviewer, noteskit

---

## Editor-API (festgezogen, stabil)

### setEditorAPI

Registriert die Editor-Callbacks. **Pflicht vor Verwendung.**

```tcl
mdstack::setEditorAPI \
    -getText    SCRIPT \
    -setText    SCRIPT \
    -clear      SCRIPT \
    ?-onchange   SCRIPT? \
    ?-isModified SCRIPT?
```

| Option | Pflicht | Beschreibung |
|--------|---------|--------------|
| `-getText` | ✅ | Gibt Markdown-String zurück |
| `-setText` | ✅ | Erhält Text als Argument |
| `-clear` | ✅ | Leert den Editor |
| `-onchange` | optional | Registriert Change-Callback → Live-Preview |
| `-isModified` | optional | Gibt 0/1 zurück |

**Beispiel mit mdtext:**

```tcl
set editor [mdtext::create .editor]

mdstack::setEditorAPI \
    -getText    [list $editor get] \
    -setText    [list $editor set] \
    -clear      [list $editor clear] \
    -onchange   [list $editor onchange] \
    -isModified [list $editor modified]
```

### Wrapper-Procs (intern verwendet)

Diese Procs sind der **einzige** Zugriffspunkt auf den Editor:

```tcl
mdstack::editorGetText      ;# Text vom Editor
mdstack::editorSetText $t   ;# Text setzen
mdstack::editorClear        ;# Editor leeren
mdstack::editorIsModified   ;# Modified-Status
```

**Ab jetzt verboten in mdstack:**
- `$editor get`
- `$editor set`
- Jeglicher direkter Widget-Zugriff

---

## Preview-API

### setPreviewAPI

```tcl
mdstack::setPreviewAPI -render SCRIPT
```

Das Script erhält den Text als Argument.

**Beispiel:**

```tcl
mdstack::setPreviewAPI -render {renderMarkdown}

proc renderMarkdown {text} {
    set ast [mdparser::parse $text]
    set doc [mdmodel::new $ast]
    mdviewer::renderModel .preview $doc
}
```

### updatePreview

```tcl
mdstack::updatePreview   ;# Manuell aktualisieren
```

---

## Stack-Verwaltung

```tcl
# Eintrag hinzufügen
mdstack::push -id $id -text $markdown -source "noteskit"

# Eintrag entfernen (LIFO)
mdstack::pop

# Zu ID wechseln
mdstack::goto $id

# Stack leeren
mdstack::clear
```

### Aktueller Eintrag

```tcl
mdstack::current         ;# → {id text source modified}
mdstack::currentId       ;# → "note1"
mdstack::currentText     ;# → "# Markdown..."
mdstack::currentSource   ;# → "noteskit"
```

### Stack-Info

```tcl
mdstack::size       ;# Anzahl Einträge
mdstack::isEmpty    ;# Stack leer?
mdstack::index      ;# Aktueller Index
mdstack::history    ;# Liste aller IDs
mdstack::entries    ;# Alle Einträge (Metadaten)
```

### Modified-Status

```tcl
mdstack::modified       ;# Status abfragen (0/1)
mdstack::modified 0     ;# Status setzen
mdstack::modified 1     ;# Als geändert markieren
```

### Speichern

```tcl
mdstack::save   ;# Ruft onsave-Callback auf
```

---

## Callbacks

### onchange

Wird aufgerufen wenn der aktive Eintrag wechselt.

```tcl
mdstack::onchange {
    puts "Gewechselt zu: [mdstack::currentId]"
    updateUI
}
```

### onmodified

Wird aufgerufen wenn Text geändert wird.

```tcl
mdstack::onmodified {
    .status configure -text "Geändert"
}
```

### onsave

Wird aufgerufen bei `mdstack::save`.
Im Callback: `mdstack::currentId`, `currentText`, `currentSource` verwenden.

```tcl
mdstack::onsave {
    set id [mdstack::currentId]
    set text [mdstack::currentText]
    set source [mdstack::currentSource]
    
    # z.B. noteskit-Integration
    noteskit::saveNote $id $text
}
```

---

## Vollständiges Beispiel

```tcl
package require mdstack 0.1
package require mdtext 0.1
package require mdviewer 0.3
package require mdparser 0.2
package require mdmodel 0.1

# Editor erstellen
set editor [mdtext::create .editor]
$editor enableFeature smartReturn

# Preview erstellen
set preview [mdviewer::create .preview]

# Editor-API registrieren (NIEMALS Widget direkt!)
mdstack::setEditorAPI \
    -getText    [list $editor get] \
    -setText    [list $editor set] \
    -clear      [list $editor clear] \
    -onchange   [list $editor onchange]

# Preview-API registrieren
mdstack::setPreviewAPI -render {renderPreview}

proc renderPreview {text} {
    global preview
    set ast [mdparser::parse $text]
    set doc [mdmodel::new $ast]
    mdviewer::renderModel $preview $doc
}

# Callbacks
mdstack::onchange { updateUI }
mdstack::onmodified { showModified }
mdstack::onsave {
    noteskit::save [mdstack::currentId] [mdstack::currentText]
}

# Notiz öffnen
mdstack::push -id "note1" -text $markdown -source "noteskit"
```

---

## Integration mit noteskit

```tcl
# Notiz öffnen
proc openNote {id} {
    set text [noteskit::getText $id]
    mdstack::push -id $id -text $text -source "noteskit"
}

# Speichern
mdstack::onsave {
    if {[mdstack::currentSource] eq "noteskit"} {
        noteskit::saveNote [mdstack::currentId] [mdstack::currentText]
    }
}

# Schließen mit Save-Prompt
proc closeNote {} {
    if {[mdstack::modified]} {
        # Fragen ob speichern...
    }
    mdstack::pop
}
```

---

## Integration mit Action-Abstraction

```tcl
# Actions definieren
action::define note.open {
    set id [noteskit::selectedId]
    set text [noteskit::getText $id]
    mdstack::push -id $id -text $text -source "noteskit"
}

action::define note.save {
    mdstack::save
}

action::define note.close {
    mdstack::pop
}

action::define note.preview {
    mdhelp::render [mdstack::currentText]
}
```

---

## Nicht-Ziele

* Kein eigenes Rendering (→ mdviewer)
* Kein eigenes Editieren (→ mdtext)
* Keine Dateiverwaltung (→ Anwendung)
* Keine UI (→ Anwendung)
* **Keine Widget-Referenzen** (nur Callbacks)

mdstack ist **nur** für Kontext-Verwaltung zuständig.
