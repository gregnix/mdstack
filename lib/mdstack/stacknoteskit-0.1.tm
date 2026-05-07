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
#   package require mdstack::stacknoteskit 0.1
#
#   # Notiz laden → in mdstack pushen
#   mdstack::stacknoteskit::loadNote $noteId
#
#   # Save changes
#   mdstack::stacknoteskit::saveCurrent

package provide mdstack::stacknoteskit 0.1

package require mdstack 0.1
# noteskit wird separat geladen (package oder source)

namespace eval ::mdstack::stacknoteskit {
    variable onSaveCallback ""
    variable onLoadCallback ""
    
    namespace export loadNote loadCurrent saveCurrent syncFromEditor \
        onSave onLoad
}

# =========================================================================
# Load Note → mdstack
# =========================================================================

proc ::mdstack::stacknoteskit::loadNote {id} {
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

proc ::mdstack::stacknoteskit::loadCurrent {} {
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

proc ::mdstack::stacknoteskit::saveCurrent {} {
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

proc ::mdstack::stacknoteskit::syncFromEditor {} {
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

proc ::mdstack::stacknoteskit::newNote {{title "Neue Notiz"}} {
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

proc ::mdstack::stacknoteskit::deleteCurrent {} {
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

proc ::mdstack::stacknoteskit::onSave {callback} {
    variable onSaveCallback
    set onSaveCallback $callback
}

proc ::mdstack::stacknoteskit::onLoad {callback} {
    variable onLoadCallback
    set onLoadCallback $callback
}

# =========================================================================
# mdstack Callback Integration
# =========================================================================

proc ::mdstack::stacknoteskit::setupCallbacks {} {
    # mdstack onsave Callback → noteskit speichern
    ::mdstack::onsave {
        ::mdstack::stacknoteskit::saveCurrent
    }
}

# =========================================================================
# Convenience: list of all notes for UI
# =========================================================================

proc ::mdstack::stacknoteskit::listNotes {{filter ""}} {
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

proc ::mdstack::stacknoteskit::isCurrentModified {} {
    return [::mdstack::modified]
}

proc ::mdstack::stacknoteskit::currentNoteId {} {
    return [::mdstack::currentId]
}

proc ::mdstack::stacknoteskit::currentNoteTitle {} {
    if {![::noteskit::hasCurrentNote]} {
        return ""
    }
    set note [::noteskit::getCurrent]
    return [dict get $note title]
}
