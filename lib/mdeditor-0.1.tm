package require Tk
package provide mdeditor 0.1

namespace eval mdeditor {
    namespace export create gettext settext model setmodel isdirty onchange widget
    variable state
    array set state {}
}

proc mdeditor::create {path args} {
    variable state
    frame $path
    text $path.t -wrap word -undo 1 -autoseparators 1 -maxundo 2000
    scrollbar $path.sb -command [list $path.t yview]
    $path.t configure -yscrollcommand [list $path.sb set]
    grid $path.t  -row 0 -column 0 -sticky nsew
    grid $path.sb -row 0 -column 1 -sticky ns
    grid columnconfigure $path 0 -weight 1
    grid rowconfigure    $path 0 -weight 1

    set key "${path},text"
    set state($key) $path.t
    set key "${path},dirty"
    set state($key) 0
    set key "${path},filename"
    set state($key) ""
    set key "${path},onchange"
    set state($key) ""

    bind $path.t <<Modified>> [list mdeditor::_onModified $path]
    return $path
}

proc mdeditor::widget {path} {
    variable state
    set key "${path},text"
    return $state($key)
}

# Returns the text content of the editor.
proc mdeditor::gettext {path} {
    set t [mdeditor::widget $path]
    return [$t get 1.0 end-1c]
}

proc mdeditor::settext {path text} {
    variable state
    set t [mdeditor::widget $path]
    $t delete 1.0 end
    $t insert 1.0 $text
    $t edit modified 0
    set key "${path},dirty"
    set state($key) 0
}

proc mdeditor::isdirty {path} {
    variable state
    set key "${path},dirty"
    return $state($key)
}

proc mdeditor::onchange {path cmd} {
    variable state
    set key "${path},onchange"
    set state($key) $cmd
}

# Returns the editor model as dict.
proc mdeditor::model {path} {
    variable state
    set t [mdeditor::widget $path]
    set keyFilename "${path},filename"
    set keyDirty "${path},dirty"
    return [dict create \
        text       [mdeditor::gettext $path] \
        filename   $state($keyFilename) \
        dirty      $state($keyDirty) \
        cursor     [$t index insert] \
        selection  [expr {[$t tag ranges sel] eq "" ? {} : [$t tag ranges sel]}]]
}

proc mdeditor::setmodel {path m} {
    variable state
    mdeditor::settext $path [dict get $m text]
    set keyFilename "${path},filename"
    set keyDirty "${path},dirty"
    if {[dict exists $m filename]} {
        set state($keyFilename) [dict get $m filename]
    }
    if {[dict exists $m dirty]} {
        set state($keyDirty) [dict get $m dirty]
    }
    set t [mdeditor::widget $path]
    if {[dict exists $m cursor]} {
        catch {$t mark set insert [dict get $m cursor]}
    }
    if {[dict exists $m selection] && [dict get $m selection] ne {}} {
        catch {$t tag add sel {*}[dict get $m selection]}
    }
}

proc mdeditor::_onModified {path} {
    variable state
    set t [mdeditor::widget $path]
    if {[$t edit modified]} {
        set keyDirty "${path},dirty"
        set state($keyDirty) 1
        $t edit modified 0
        set keyOnchange "${path},onchange"
        set cb $state($keyOnchange)
        if {$cb ne ""} {
            uplevel #0 [list {*}$cb [mdeditor::gettext $path]]
        }
    }
}
