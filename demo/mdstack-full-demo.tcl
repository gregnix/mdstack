#!/usr/bin/env wish
# mdstack-full-demo.tcl
# ============================================================
# Complete demo: mdstack Orchestrator
# ============================================================
# Shows die Integration von:
#   - mdstack (Orchestrator)
#   - mdtext (Editor)
#   - mdcontextmenu (Rechtsklick)
#   - mdviewer (Preview)
#   - mdparser + mdmodel (Parser)
#
# Simuliert noteskit als Datenquelle.

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require Tk
package require mdstack 0.1
package require mdtext 0.1
package require mdparser 0.2
package require mdmodel 0.1
package require mdviewer 0.3
package require uicontextmenu 0.1
package require mdcontextmenu 0.1

# ============================================================
# Fenster Setup
# ============================================================

wm title . "mdstack Orchestrator Demo"
wm geometry . 1200x700

# --- Toolbar ---
ttk::frame .toolbar
pack .toolbar -fill x -pady 2

ttk::label .toolbar.lbl -text "Notizen:"
ttk::combobox .toolbar.notes -state readonly -width 30
ttk::button .toolbar.new -text "Neue Notiz" -command newNote
ttk::button .toolbar.save -text "Speichern" -command saveNote
ttk::button .toolbar.close -text "Close" -command closeNote
ttk::separator .toolbar.sep -orient vertical
ttk::label .toolbar.stack -text "Stack: 0"

pack .toolbar.lbl -side left -padx 5
pack .toolbar.notes -side left -padx 5
pack .toolbar.new .toolbar.save .toolbar.close -side left -padx 2
pack .toolbar.sep -side left -padx 10 -fill y
pack .toolbar.stack -side left -padx 5

# --- Main Area: Editor + Preview ---
ttk::panedwindow .paned -orient horizontal
pack .paned -fill both -expand 1 -padx 5 -pady 5

# Editor-Pane
ttk::frame .paned.editor
ttk::label .paned.editor.lbl -text "Editor (mdtext)" -font {TkDefaultFont 10 bold}
pack .paned.editor.lbl -fill x

set editor [mdtext::create .paned.editor.text -width 60 -height 30]
$editor enableFeature smartReturn
$editor enableFeature indent

# Context menu
mdcontextmenu::attachToEditor $editor

# Scrollbar
ttk::scrollbar .paned.editor.sb -orient vertical -command [list [$editor text] yview]
[$editor text] configure -yscrollcommand [list .paned.editor.sb set]
pack .paned.editor.sb -side right -fill y
pack $editor -side left -fill both -expand 1

# Preview-Pane
ttk::frame .paned.preview
ttk::label .paned.preview.lbl -text "Preview (mdviewer)" -font {TkDefaultFont 10 bold}
pack .paned.preview.lbl -fill x

set preview [mdviewer::create .paned.preview.viewer -root [file dirname [info script]]]
pack $preview -fill both -expand 1

.paned add .paned.editor -weight 1
.paned add .paned.preview -weight 1

# --- Statusbar ---
ttk::frame .status
ttk::label .status.info -text "Bereit"
ttk::label .status.modified -text "" -foreground red
pack .status.info -side left -padx 5
pack .status.modified -side right -padx 5
pack .status -fill x

# ============================================================
# Simulierte Datenquelle (noteskit)
# ============================================================

# "Datenbank" mit Notizen
array set notesDB {
    note1 {# Willkommen

Dies ist die **erste Notiz**.

## Features

- Smart Return
- Tab/Shift-Tab
- Context menu (right-click)

## Tabelle

| Column A | Column B |
|----------|----------|
| Value 1   | Value 2   |
}
    note2 {# Tasks

## Diese Woche

- [x] Create mdstack orchestrator
- [x] Demo bauen
- [ ] Tests schreiben

## Next Week

1. Integration in noteskit
2. Action-Abstraction anbinden
}
    note3 {# Blockquote Demo

> Dies ist ein Zitat.
> It can span multiple lines.

Normaler Text danach.

> Noch ein Zitat
}
}

set notesList {note1 note2 note3}
set noteCounter 3

# Notiz laden
proc loadNote {id} {
    global notesDB
    if {[info exists notesDB($id)]} {
        return $notesDB($id)
    }
    return ""
}

# Notiz speichern
proc saveNoteToDb {id text} {
    global notesDB
    set notesDB($id) $text
    puts "SAVED: $id ([string length $text] chars)"
}

# ============================================================
# mdstack Setup
# ============================================================

# Editor-API registrieren (NIEMALS Widget direkt!)
mdstack::setEditorAPI \
    -getText    [list $editor get] \
    -setText    [list $editor set] \
    -clear      [list $editor clear] \
    -onchange   [list $editor onchange]

# Preview-API registrieren
mdstack::setPreviewAPI -render [list renderPreview]

proc renderPreview {text} {
    global preview
    if {$text eq ""} {
        mdviewer::clear $preview
        return
    }
    set ast [mdparser::parse $text]
    set doc [mdmodel::new $ast]
    mdviewer::renderModel $preview $doc
}

# Callbacks
mdstack::onchange {
    updateUI
}

mdstack::onmodified {
    .status.modified configure -text "\[MODIFIED\]"
}

mdstack::onsave {
    set id [mdstack::currentId]
    set text [mdstack::currentText]
    saveNoteToDb $id $text
    .status.info configure -text "Gespeichert: $id"
    after 2000 {.status.info configure -text "Bereit"}
}

# ============================================================
# UI-Funktionen
# ============================================================

proc updateUI {} {
    global notesList
    
    # Stack-Anzeige
    set size [mdstack::size]
    set idx [mdstack::index]
    .toolbar.stack configure -text "Stack: $size (Index: $idx)"
    
    # Combobox aktualisieren
    .toolbar.notes configure -values $notesList
    
    set id [mdstack::currentId]
    if {$id ne ""} {
        .toolbar.notes set $id
        .status.info configure -text "Aktiv: $id"
    } else {
        .toolbar.notes set ""
        .status.info configure -text "Kein Dokument"
    }
    
    # Reset modified if not modified
    if {![mdstack::modified]} {
        .status.modified configure -text ""
    }
}

proc openNote {id} {
    set text [loadNote $id]
    mdstack::push -id $id -text $text -source "noteskit"
}

proc newNote {} {
    global noteCounter notesList notesDB
    
    incr noteCounter
    set id "note$noteCounter"
    set notesDB($id) "# Neue Notiz\n\nText hier...\n"
    lappend notesList $id
    
    openNote $id
}

proc saveNote {} {
    mdstack::save
}

proc closeNote {} {
    if {[mdstack::modified]} {
        set answer [tk_messageBox -type yesnocancel \
            -icon question \
            -title "Speichern?" \
            -message "Save changes?"]
        switch $answer {
            yes { mdstack::save }
            cancel { return }
        }
    }
    mdstack::pop
}

# Combobox-Binding
bind .toolbar.notes <<ComboboxSelected>> {
    set id [.toolbar.notes get]
    if {$id ne "" && $id ne [mdstack::currentId]} {
        openNote $id
    }
}

# ============================================================
# Keyboard Shortcuts
# ============================================================

bind . <Control-s> { saveNote }
bind . <Control-w> { closeNote }
bind . <Control-n> { newNote }

# ============================================================
# Start
# ============================================================

# Open first note
openNote note1

puts "=== mdstack Demo ==="
puts "Shortcuts: Ctrl+S=Save, Ctrl+W=Close, Ctrl+N=New"
puts "Right-click in editor for context menu"
