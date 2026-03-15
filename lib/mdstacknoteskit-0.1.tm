# mdstacknoteskit-0.1.tm
# Adapter zwischen noteskit und mdstack
#
# Connects noteskit (Note management) mit mdstack (Editor-Orchestrator).
#
# Pattern:
#   noteskit → stores/loads notes (CRUD, storage)
#   mdstack  → manages editor stack and preview
#   Adapter  → synchronisiert beide
#
# Usage:
#   package require noteskit 0.1       ;# or source noteskit-minimal.tcl
#   package require mdstack 0.1
#   package require mdstacknoteskit 0.1
#
#   # Notiz laden → in mdstack pushen
#   mdstacknoteskit::loadNote $noteId
#
#   # Save changes
#   mdstacknoteskit::saveCurrent

package provide mdstacknoteskit 0.1

package require mdstack 0.1
# noteskit wird separat geladen (package oder source)

namespace eval ::mdstacknoteskit {
    variable onSaveCallback ""
    variable onLoadCallback ""
    
    namespace export loadNote loadCurrent saveCurrent syncFromEditor \
        onSave onLoad
}

# =========================================================================
# Load Note → mdstack
# =========================================================================

proc ::mdstacknoteskit::loadNote {id} {
    variable onLoadCallback
    
    # Notiz von noteskit laden
    set note [::noteskit::load $id]
    if {$note eq {}} {
        error "Note not found: $id"
    }
    
    set title [dict get $note title]
    set body [dict get $note body]
    
    # In mdstack pushen
    ::mdstack::push \
        -id $id \
        -text $body \
        -source "noteskit"
    
    # Callback
    if {$onLoadCallback ne ""} {
        uplevel #0 [list {*}$onLoadCallback $id $title]
    }
    
    return $note
}

proc ::mdstacknoteskit::loadCurrent {} {
    if {![::noteskit::hasCurrentNote]} {
        return
    }
    
    set note [::noteskit::getCurrent]
    set id [dict get $note id]
    
    return [loadNote $id]
}

# =========================================================================
# Save mdstack → noteskit
# =========================================================================

proc ::mdstacknoteskit::saveCurrent {} {
    variable onSaveCallback
    
    if {![::noteskit::hasCurrentNote]} {
        return
    }
    
    # Currente Notiz holen
    set note [::noteskit::getCurrent]
    set id [dict get $note id]
    
    # Text von mdstack holen
    set text [::mdstack::currentText]
    
    # In noteskit speichern
    dict set note body $text
    ::noteskit::save $note
    
    # Reset mdstack modified flag
    ::mdstack::modified 0
    
    # Callback
    if {$onSaveCallback ne ""} {
        set title [dict get $note title]
        uplevel #0 [list {*}$onSaveCallback $id $title]
    }
    
    return $note
}

proc ::mdstacknoteskit::syncFromEditor {} {
    # Gets current text from mdstack and updates noteskit::currentNote
    # (ohne zu speichern)
    
    if {![::noteskit::hasCurrentNote]} {
        return
    }
    
    set note [::noteskit::getCurrent]
    set text [::mdstack::currentText]
    
    dict set note body $text
    ::noteskit::setCurrent $note
    
    return $note
}

# =========================================================================
# New Note
# =========================================================================

proc ::mdstacknoteskit::newNote {{title "Neue Notiz"}} {
    variable onLoadCallback
    
    # Create new note in noteskit
    set note [::noteskit::new $title]
    set id [dict get $note id]
    
    # In mdstack pushen (leer)
    ::mdstack::push \
        -id $id \
        -text "" \
        -source "noteskit"
    
    # Callback
    if {$onLoadCallback ne ""} {
        uplevel #0 [list {*}$onLoadCallback $id $title]
    }
    
    return $note
}

# =========================================================================
# Delete Note
# =========================================================================

proc ::mdstacknoteskit::deleteCurrent {} {
    if {![::noteskit::hasCurrentNote]} {
        return
    }
    
    set note [::noteskit::getCurrent]
    set id [dict get $note id]
    
    # Delete from noteskit
    ::noteskit::delete $id
    
    # Remove from mdstack
    ::mdstack::pop
}

# =========================================================================
# Callbacks
# =========================================================================

proc ::mdstacknoteskit::onSave {callback} {
    variable onSaveCallback
    set onSaveCallback $callback
}

proc ::mdstacknoteskit::onLoad {callback} {
    variable onLoadCallback
    set onLoadCallback $callback
}

# =========================================================================
# mdstack Callback Integration
# =========================================================================

proc ::mdstacknoteskit::setupCallbacks {} {
    # mdstack onsave Callback → noteskit speichern
    ::mdstack::onsave {
        ::mdstacknoteskit::saveCurrent
    }
}

# =========================================================================
# Convenience: list of all notes for UI
# =========================================================================

proc ::mdstacknoteskit::listNotes {{filter ""}} {
    set notes [::noteskit::list $filter]
    set result {}
    
    foreach note $notes {
        set id [dict get $note id]
        set title [dict get $note title]
        set modified [dict get $note modified]
        
        lappend result [dict create \
            id $id \
            title $title \
            modified $modified \
            inStack [::mdstack::hasId $id]]
    }
    
    return $result
}

# =========================================================================
# Stack-Status
# =========================================================================

proc ::mdstacknoteskit::isCurrentModified {} {
    return [::mdstack::modified]
}

proc ::mdstacknoteskit::currentNoteId {} {
    return [::mdstack::currentId]
}

proc ::mdstacknoteskit::currentNoteTitle {} {
    if {![::noteskit::hasCurrentNote]} {
        return ""
    }
    set note [::noteskit::getCurrent]
    return [dict get $note title]
}
