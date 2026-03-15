package require Tk
package require mdtext   0.1
package require mdparser 0.2
package require mdmodel  0.1
package require mdviewer 0.3

package provide mdeditorkit 0.2

namespace eval mdeditorkit {
    namespace export create settext gettext setmode mode model setmodel \
        getdocmodel configure cget widgets editor viewer ast
    variable state
    array set state {}
}

proc mdeditorkit::create {path args} {
    variable state

    ttk::frame $path
    set pw [ttk::panedwindow $path.pw -orient horizontal]
    grid $pw -row 0 -column 0 -sticky nsew
    grid columnconfigure $path 0 -weight 1
    grid rowconfigure    $path 0 -weight 1

    # Left: editor container
    set left  [ttk::frame $pw.left]
    set right [ttk::frame $pw.right]
    $pw add $left  -weight 1
    $pw add $right -weight 1

    set ed [mdtext::create $left.ed]
    pack $ed -fill both -expand 1

    # Right: preview + status
    set status [ttk::label $right.status -text "" -anchor w]
    set view   [mdviewer::create $right.view -tablemode frame]
    pack $status -side top -fill x
    pack $view   -side top -fill both -expand 1

    # defaults
    set state($path,pw) $pw
    set state($path,left) $left
    set state($path,right) $right
    set state($path,editor) $ed
    set state($path,viewer) $view
    set state($path,status) $status

    set state($path,mode) "split"
    set state($path,debounce) 300
    set state($path,afterid) ""
    set state($path,onerror) ""
    set state($path,onchange) ""

    set state($path,ast) [dict create type document version 1 meta {} blocks {} reflinks {}]
    set state($path,doc) [mdmodel::new $state($path,ast)]
    set state($path,lasterror) ""
    set state($path,syncscroll) 1

    # Connect editor onchange
    $ed onchange [list mdeditorkit::_onEditorChange $path]

    # Sync-Scroll: Editor scrollt -> Preview scrollt proportional
    set edText [mdtext::_t $ed]
    set viewText [mdviewer::widget $view]
    bind $edText <ButtonRelease-1> [list mdeditorkit::_syncScroll $path]
    bind $edText <KeyRelease>      [list mdeditorkit::_syncScroll $path]
    bind $edText <MouseWheel>      [list after 50 [list mdeditorkit::_syncScroll $path]]
    # Linux: Button-4/5 for Scroll
    bind $edText <Button-4>        [list after 50 [list mdeditorkit::_syncScroll $path]]
    bind $edText <Button-5>        [list after 50 [list mdeditorkit::_syncScroll $path]]

    # Apply options
    mdeditorkit::configure $path {*}$args
    mdeditorkit::setmode $path $state($path,mode)

    # initial render
    mdeditorkit::_reparseNow $path [mdtext::gettext $ed]
    return $path
}

# Return widget paths dict
proc mdeditorkit::widgets {path} {
    variable state
    return [dict create \
        panedwindow $state($path,pw) \
        editorFrame $state($path,left) \
        previewFrame $state($path,right) \
        editor $state($path,editor) \
        viewer $state($path,viewer) \
        status $state($path,status)]
}

# Shortcut: editor widget path (mdtext instance)
proc mdeditorkit::editor {path} {
    variable state
    return $state($path,editor)
}

# Shortcut: viewer widget path
proc mdeditorkit::viewer {path} {
    variable state
    return $state($path,viewer)
}

proc mdeditorkit::configure {path args} {
    variable state
    if {[llength $args] == 0} { return }
    if {[llength $args] % 2 != 0} { error "mdeditorkit::configure: expected key value pairs" }

    foreach {k v} $args {
        switch -- $k {
            -debounce {
                if {![string is integer -strict $v] || $v < 0} { error "mdeditorkit: -debounce must be integer >= 0" }
                set state($path,debounce) $v
            }
            -mode {
                set state($path,mode) $v
            }
            -onerror {
                set state($path,onerror) $v
            }
            -onchange {
                set state($path,onchange) $v
            }
            -onlink {
                mdviewer::configure $state($path,viewer) -onlink $v
            }
            -fontsize {
                mdviewer::setFontSize $state($path,viewer) $v
            }
            -root {
                mdviewer::configure $state($path,viewer) -root $v
            }
            -syncscroll {
                set state($path,syncscroll) [expr {!!$v}]
            }
            default {
                error "mdeditorkit::configure: unknown option $k"
            }
        }
    }
}

proc mdeditorkit::cget {path option} {
    variable state
    switch -- $option {
        -debounce { return $state($path,debounce) }
        -mode     { return $state($path,mode) }
        -onerror  { return $state($path,onerror) }
        -onchange { return $state($path,onchange) }
        default { error "mdeditorkit::cget: unknown option $option" }
    }
}

proc mdeditorkit::settext {path markdown} {
    variable state
    mdtext::settext $state($path,editor) $markdown
    mdeditorkit::_reparseNow $path $markdown
}

proc mdeditorkit::gettext {path} {
    variable state
    return [mdtext::gettext $state($path,editor)]
}

proc mdeditorkit::mode {path} {
    variable state
    return $state($path,mode)
}

proc mdeditorkit::setmode {path newMode} {
    variable state
    set newMode [string tolower $newMode]
    if {$newMode ni {edit preview split}} {
        error "mdeditorkit::setmode: expected edit|preview|split"
    }
    set state($path,mode) $newMode

    set pw $state($path,pw)
    set left $state($path,left)
    set right $state($path,right)

    foreach p [list $left $right] {
        catch {$pw forget $p}
    }

    switch -- $newMode {
        edit {
            $pw add $left -weight 1
        }
        preview {
            $pw add $right -weight 1
        }
        split {
            $pw add $left -weight 1
            $pw add $right -weight 1
        }
    }
}

proc mdeditorkit::model {path} {
    variable state
    set ed $state($path,editor)
    set t [mdtext::_t $ed]
    return [dict create \
        text      [mdtext::gettext $ed] \
        dirty     [$ed modified] \
        cursor    [$t index insert] \
        selection [expr {[$t tag ranges sel] eq "" ? {} : [$t tag ranges sel]}]]
}

proc mdeditorkit::setmodel {path m} {
    variable state
    mdtext::settext $state($path,editor) [dict get $m text]
    mdeditorkit::_reparseNow $path [dict get $m text]
}

proc mdeditorkit::getdocmodel {path} {
    variable state
    return $state($path,doc)
}

# Return current AST
proc mdeditorkit::ast {path} {
    variable state
    return $state($path,ast)
}

# --- Internal: editor changes ---

proc mdeditorkit::_onEditorChange {path markdown} {
    variable state

    set cb $state($path,onchange)
    if {$cb ne ""} {
        if {[catch {uplevel #0 [list {*}$cb $markdown]} err]} {
            puts stderr "mdeditorkit: onchange callback error: $err"
        }
    }

    # debounce parse
    if {$state($path,afterid) ne ""} {
        after cancel $state($path,afterid)
        set state($path,afterid) ""
    }

    if {$state($path,debounce) == 0} {
        mdeditorkit::_reparseNow $path $markdown
        return
    }

    set state($path,afterid) [after $state($path,debounce) [list mdeditorkit::_reparseNow $path $markdown]]
}

proc mdeditorkit::_syncScroll {path} {
    variable state
    if {!$state($path,syncscroll)} return
    if {$state($path,mode) eq "edit"} return

    set edText [mdtext::_t $state($path,editor)]
    set viewText [mdviewer::widget $state($path,viewer)]

    # Proportionale Position im Editor
    set fraction [lindex [$edText yview] 0]

    # Preview auf gleiche Position scrollen
    $viewText yview moveto $fraction
}

proc mdeditorkit::_reparseNow {path markdown} {
    variable state
    set state($path,afterid) ""

    set ok 1
    set err ""
    if {[catch {
        set ast [mdparser::parse $markdown]
        set doc [mdmodel::new $ast]
    } msg opts]} {
        set ok 0
        set err $msg
    }

    if {$ok} {
        set state($path,ast) $ast
        set state($path,doc) $doc
        set state($path,lasterror) ""
        $state($path,status) configure -text ""
        mdviewer::renderModel $state($path,viewer) $doc
    } else {
        set state($path,lasterror) $err
        $state($path,status) configure -text "Parse error: $err"
        set cb $state($path,onerror)
        if {$cb ne ""} {
            if {[catch {uplevel #0 [list {*}$cb $err]} cbErr]} {
                puts stderr "mdeditorkit: onerror callback error: $cbErr"
            }
        }
    }
}
