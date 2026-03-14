#!/usr/bin/env wish
# demo-noteskit-mdstack.tcl
# Demo: noteskit + mdstack integration
#
# Shows the usage of the noteskit-mdstack adapter:
# - Left: Note list (noteskit)
# - Center: Editor (mdtext via mdstack)
# - Right: Preview (mdviewer via mdstack)

set scriptDir [file dirname [info script]]

# mdstack Modules
tcl::tm::path add [file join $scriptDir .. lib]

package require Tk
package require mdstack 0.1
package require mdtext 0.1
package require mdparser 0.2
package require mdmodel 0.1
package require mdviewer 0.3

# noteskit (minimal embedded for demo)
# In Produktion: package require noteskit 0.1
source [file join $scriptDir noteskit-minimal.tcl]

# Adapter
package require mdstacknoteskit 0.1

# =========================================================================
# Init
# =========================================================================

wm title . "noteskit + mdstack Demo"
wm geometry . 1200x700

# Initialize noteskit (memory backend for demo)
noteskit::init memory

# =========================================================================
# GUI
# =========================================================================

# Toolbar
ttk::frame .toolbar
pack .toolbar -fill x -pady 2

ttk::button .toolbar.new -text "New Note" -command newNote
ttk::button .toolbar.save -text "Save" -command saveNote
ttk::button .toolbar.delete -text "Delete" -command deleteNote
ttk::separator .toolbar.sep -orient vertical
ttk::label .toolbar.stack -text "Stack: 0"
ttk::label .toolbar.modified -text "" -foreground red

pack .toolbar.new .toolbar.save .toolbar.delete -side left -padx 2
pack .toolbar.sep -side left -padx 10 -fill y
pack .toolbar.stack -side left -padx 5
pack .toolbar.modified -side left -padx 5

# Hauptbereich
ttk::panedwindow .main -orient horizontal
pack .main -fill both -expand 1 -padx 5 -pady 5

# Left: Note list
ttk::frame .main.left
.main add .main.left -weight 1

ttk::label .main.left.lbl -text "Notes:" -font {TkDefaultFont 10 bold}
pack .main.left.lbl -anchor w

listbox .main.left.list -height 20 -width 30 -selectmode single
ttk::scrollbar .main.left.sb -command ".main.left.list yview"
.main.left.list configure -yscrollcommand ".main.left.sb set"

pack .main.left.list -side left -fill both -expand 1
pack .main.left.sb -side right -fill y

# Center: Editor (mdtext)
ttk::frame .main.center
.main add .main.center -weight 2

ttk::frame .main.center.header
pack .main.center.header -fill x

ttk::label .main.center.header.lbl -text "Editor:" -font {TkDefaultFont 10 bold}
ttk::entry .main.center.header.title -textvariable ::noteTitle -width 40
pack .main.center.header.lbl -side left
pack .main.center.header.title -side left -fill x -expand 1 -padx 5

set editor [mdtext::create .main.center.editor -width 50 -height 25]
$editor enableFeature smartReturn
$editor enableFeature indent

ttk::scrollbar .main.center.sb -orient vertical -command [list [$editor text] yview]
[$editor text] configure -yscrollcommand [list .main.center.sb set]

pack .main.center.sb -side right -fill y
pack $editor -side left -fill both -expand 1

# Right: Preview (mdviewer)
ttk::frame .main.right
.main add .main.right -weight 2

ttk::label .main.right.lbl -text "Preview:" -font {TkDefaultFont 10 bold}
pack .main.right.lbl -anchor w

set preview [mdviewer::create .main.right.viewer -root $scriptDir]
pack $preview -fill both -expand 1

# Statusbar
ttk::frame .status
ttk::label .status.info -text "Ready" -relief sunken -anchor w
pack .status.info -fill x
pack .status -fill x -side bottom

# =========================================================================
# mdstack Setup
# =========================================================================

# Register editor API
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
    .toolbar.modified configure -text "\[MODIFIED\]"
}

# =========================================================================
# mdstacknoteskit Adapter Callbacks
# =========================================================================

proc onNoteLoaded {id title} {
    set ::noteTitle $title
    .status.info configure -text "Geladen: $title"
}

proc onNoteSaved {id title} {
    .status.info configure -text "Gespeichert: $title"
    .toolbar.modified configure -text ""
    refreshList
}

mdstacknoteskit::onLoad onNoteLoaded
mdstacknoteskit::onSave onNoteSaved

# =========================================================================
# UI Funktionen
# =========================================================================

proc updateUI {} {
    set size [mdstack::size]
    set idx [mdstack::index]
    .toolbar.stack configure -text "Stack: $size (Index: $idx)"
    
    if {![mdstack::modified]} {
        .toolbar.modified configure -text ""
    }
}

proc refreshList {} {
    global noteIds
    
    set notes [noteskit::list]
    set noteIds {}
    
    .main.left.list delete 0 end
    foreach note $notes {
        set title [dict get $note title]
        set id [dict get $note id]
        
        # Markierung wenn im Stack
        if {[mdstack::hasId $id]} {
            set title "● $title"
        }
        
        .main.left.list insert end $title
        lappend noteIds $id
    }
}

proc onSelectNote {} {
    global noteIds noteTitle
    
    set sel [.main.left.list curselection]
    if {$sel eq "" || [llength $sel] == 0} return
    
    set idx [lindex $sel 0]
    if {$idx >= [llength $noteIds]} return
    
    # Save changes?
    if {[mdstack::modified]} {
        set answer [tk_messageBox -type yesnocancel \
            -icon question \
            -title "Speichern?" \
            -message "Aktuelle Notiz speichern?"]
        switch $answer {
            yes { mdstacknoteskit::saveCurrent }
            cancel { return }
        }
    }
    
    set id [lindex $noteIds $idx]
    mdstacknoteskit::loadNote $id
    refreshList
}

proc newNote {} {
    global noteTitle
    
    # Save changes?
    if {[mdstack::modified]} {
        set answer [tk_messageBox -type yesnocancel \
            -icon question \
            -title "Speichern?" \
            -message "Aktuelle Notiz speichern?"]
        switch $answer {
            yes { mdstacknoteskit::saveCurrent }
            cancel { return }
        }
    }
    
    set noteTitle "Neue Notiz"
    mdstacknoteskit::newNote $noteTitle
    refreshList
}

proc saveNote {} {
    global noteTitle
    
    if {![noteskit::hasCurrentNote]} return
    
    # Titel aktualisieren
    set note [noteskit::getCurrent]
    dict set note title $noteTitle
    noteskit::setCurrent $note
    
    mdstacknoteskit::saveCurrent
}

proc deleteNote {} {
    if {![noteskit::hasCurrentNote]} return
    
    set note [noteskit::getCurrent]
    set title [dict get $note title]
    
    set answer [tk_messageBox -type yesno \
        -icon question \
        -title "Delete?" \
        -message "Really delete note?"]
    
    if {$answer ne "yes"} return
    
    mdstacknoteskit::deleteCurrent
    set ::noteTitle ""
    refreshList
    .status.info configure -text "Deleted: $title"
}

# =========================================================================
# Bindings
# =========================================================================

bind .main.left.list <<ListboxSelect>> {onSelectNote}
bind . <Control-s> {saveNote}
bind . <Control-n> {newNote}

# =========================================================================
# Demo-Daten
# =========================================================================

# Notiz 1
set n1 [noteskit::new "Willkommen"]
dict set n1 body {# Willkommen bei mdstack + noteskit

Diese Demo zeigt die **Integration** von:

- **noteskit** - Notiz-Verwaltung (CRUD, Storage)
- **mdstack** - Editor-Orchestrator (Stack, Preview)
- **mdtext** - Markdown-Editor
- **mdviewer** - Markdown-Preview

## Features

1. Create, edit, delete notes
2. Live-Preview beim Tippen
3. Smart return and tab indentation
4. Stack-Navigation (mehrere Notizen offen)

## Shortcuts

| Taste | Aktion |
|-------|--------|
| Ctrl+S | Speichern |
| Ctrl+N | Neue Notiz |

> Klicke links auf eine Notiz zum Laden!
}
noteskit::save $n1

# Note 2
set n2 [noteskit::new "Markdown Examples"]
dict set n2 body {# Markdown Examples

## Formatting

**Bold**, *italic*, `code`

## Lists

- Item 1
- Item 2
  - Sub-item

1. First
2. Second
3. Third

## Code

```tcl
proc hello {name} {
    puts "Hello $name!"
}
```

## Table

| A | B | C |
|---|---|---|
| 1 | 2 | 3 |

## Blockquote

> This is a quote.
}
noteskit::save $n2

# Note 3
set n3 [noteskit::new "TODO List"]
dict set n3 body {# TODO List

## Today

- [x] Finish mdstack
- [x] Write noteskit adapter
- [ ] Write tests
- [ ] Documentation

## This Week

- [ ] Integrate PIM2
- [ ] Prepare release
}
noteskit::save $n3

noteskit::clearCurrent

# =========================================================================
# Start
# =========================================================================

refreshList
.status.info configure -text "3 demo notes loaded - click left to open"

puts "=== noteskit + mdstack Demo ==="
puts "Shortcuts: Ctrl+S=Speichern, Ctrl+N=Neu"
