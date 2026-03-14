# noteskit-minimal.tcl
# Minimal in-memory noteskit implementation for demo purposes.

namespace eval noteskit {
    variable notes {}
    variable nextId 1
    variable currentId ""
}

proc noteskit::init {backend} {
    variable notes
    variable nextId
    variable currentId
    set notes {}
    set nextId 1
    set currentId ""
}

proc noteskit::new {title} {
    variable nextId
    set id "note-$nextId"
    incr nextId
    set note [dict create id $id title $title body ""]
    return $note
}

proc noteskit::save {note} {
    variable notes
    set id [dict get $note id]
    dict set notes $id $note
    return $note
}

proc noteskit::list {{filter ""}} {
    variable notes
    set result {}
    dict for {id note} $notes {
        lappend result $note
    }
    return $result
}

proc noteskit::hasCurrentNote {} {
    variable currentId
    variable notes
    expr {$currentId ne "" && [dict exists $notes $currentId]}
}

proc noteskit::getCurrent {} {
    variable currentId
    variable notes
    if {$currentId eq "" || ![dict exists $notes $currentId]} {
        error "no current note"
    }
    return [dict get $notes $currentId]
}

proc noteskit::setCurrent {note} {
    variable currentId
    variable notes
    set id [dict get $note id]
    dict set notes $id $note
    set currentId $id
}

proc noteskit::clearCurrent {} {
    variable currentId
    set currentId ""
}

proc noteskit::load {id} {
    variable notes
    variable currentId
    if {![dict exists $notes $id]} {
        error "note $id not found"
    }
    set currentId $id
    return [dict get $notes $id]
}

proc noteskit::delete {id} {
    variable notes
    variable currentId
    if {[dict exists $notes $id]} {
        dict unset notes $id
    }
    if {$currentId eq $id} {
        set currentId ""
    }
}
