# uicontextmenu-0.1.tm
# Generic, reusable context menu system
# Package: uicontextmenu 0.1
#
# Features:
# - Einfache Menu-Definition per Liste
# - Dynamic menus (update before display)
# - Cross-platform (Windows/Linux/macOS)
# - Untermenues
# - Checkbuttons/Radiobuttons
# - Accelerator display
# - State-Management (enable/disable)
#

package require Tk

namespace eval ::uicontextmenu {
    namespace export create attach detach show \
                   addItem addSeparator addSubmenu \
                   addCheckItem addRadioItem \
                   enable disable setCallback \
                   setUpdateHandler destroy
    variable instances
}

# ------------------------------------------------------------
# create - Create context menu
# ------------------------------------------------------------
# Options:
#   -tearoff    0|1 (Default: 0)
#   -items      List of menu items (optional)
#   -dynamic    0|1 - Update before each display (Default: 0)
#
# Items-Format:
#   {label command ?accelerator? ?state?}
#   oder "-" for Separator
#
proc ::uicontextmenu::create {path args} {
    variable instances
    
    # Defaults
    array set opts {
        -tearoff  0
        -items    {}
        -dynamic  0
    }
    array set opts $args
    
    # Create menu
    menu $path -tearoff $opts(-tearoff)
    
    # State speichern
    set instances($path) [dict create \
        tearoff       $opts(-tearoff) \
        dynamic       $opts(-dynamic) \
        items         {} \
        widgets       {} \
        updateHandler "" \
    ]
    
    # Add initial items
    foreach item $opts(-items) {
        if {$item eq "-"} {
            addSeparator $path
        } elseif {[llength $item] >= 2} {
            set label [lindex $item 0]
            set cmd [lindex $item 1]
            set accel [lindex $item 2]
            set state [lindex $item 3]
            if {$state eq ""} {set state normal}
            addItem $path $label -command $cmd -accelerator $accel -state $state
        }
    }
    
    return $path
}

# ------------------------------------------------------------
# addItem - Add menu entry
# ------------------------------------------------------------
# Options:
#   -command     Callback (Pflicht)
#   -accelerator Shortcut display (optional)
#   -state       normal|disabled (Default: normal)
#   -icon        Icon-Image (optional)
#
proc ::uicontextmenu::addItem {menu label args} {
    variable instances
    
    if {![info exists instances($menu)]} {
        error "uicontextmenu::addItem: Unknown menu '$menu'"
    }
    
    # Defaults
    array set opts {
        -command     {}
        -accelerator ""
        -state       normal
        -icon        ""
    }
    array set opts $args
    
    # Add menu entry
    set cmdArgs [list -label $label -command $opts(-command) -state $opts(-state)]
    
    if {$opts(-accelerator) ne ""} {
        lappend cmdArgs -accelerator $opts(-accelerator)
    }
    if {$opts(-icon) ne ""} {
        lappend cmdArgs -image $opts(-icon) -compound left
    }
    
    $menu add command {*}$cmdArgs
    
    # Item registrieren
    set idx [$menu index end]
    set items [dict get $instances($menu) items]
    dict set items $label [dict create \
        index       $idx \
        command     $opts(-command) \
        accelerator $opts(-accelerator) \
        state       $opts(-state) \
        type        command \
    ]
    dict set instances($menu) items $items
    
    return $idx
}

# ------------------------------------------------------------
# addSeparator - Add separator
# ------------------------------------------------------------
proc ::uicontextmenu::addSeparator {menu} {
    variable instances
    
    if {![info exists instances($menu)]} {
        error "uicontextmenu::addSeparator: Unknown menu '$menu'"
    }
    
    $menu add separator
    return [$menu index end]
}

# ------------------------------------------------------------
# addSubmenu - Add submenu
# ------------------------------------------------------------
proc ::uicontextmenu::addSubmenu {menu label submenu} {
    variable instances
    
    if {![info exists instances($menu)]} {
        error "uicontextmenu::addSubmenu: Unknown menu '$menu'"
    }
    
    $menu add cascade -label $label -menu $submenu
    
    # Item registrieren
    set idx [$menu index end]
    set items [dict get $instances($menu) items]
    dict set items $label [dict create \
        index   $idx \
        submenu $submenu \
        type    cascade \
    ]
    dict set instances($menu) items $items
    
    return $idx
}

# ------------------------------------------------------------
# addCheckItem - Add checkbutton entry
# ------------------------------------------------------------
proc ::uicontextmenu::addCheckItem {menu label args} {
    variable instances
    
    if {![info exists instances($menu)]} {
        error "uicontextmenu::addCheckItem: Unknown menu '$menu'"
    }
    
    # Defaults
    array set opts {
        -variable    ""
        -command     {}
        -accelerator ""
        -onvalue     1
        -offvalue    0
    }
    array set opts $args
    
    # Create variable automatically if not specified
    if {$opts(-variable) eq ""} {
        set safeName [string map {. _ " " _} $label]
        set opts(-variable) "::uicontextmenu::check_${menu}_${safeName}"
        set $opts(-variable) $opts(-offvalue)
    }
    
    set cmdArgs [list -label $label \
        -variable $opts(-variable) \
        -onvalue $opts(-onvalue) \
        -offvalue $opts(-offvalue)]
    
    if {$opts(-command) ne {}} {
        lappend cmdArgs -command $opts(-command)
    }
    if {$opts(-accelerator) ne ""} {
        lappend cmdArgs -accelerator $opts(-accelerator)
    }
    
    $menu add checkbutton {*}$cmdArgs
    
    # Item registrieren
    set idx [$menu index end]
    set items [dict get $instances($menu) items]
    dict set items $label [dict create \
        index    $idx \
        variable $opts(-variable) \
        command  $opts(-command) \
        type     checkbutton \
    ]
    dict set instances($menu) items $items
    
    return $idx
}

# ------------------------------------------------------------
# addRadioItem - Add radiobutton entry
# ------------------------------------------------------------
proc ::uicontextmenu::addRadioItem {menu label args} {
    variable instances
    
    if {![info exists instances($menu)]} {
        error "uicontextmenu::addRadioItem: Unknown menu '$menu'"
    }
    
    # Defaults
    array set opts {
        -variable    ""
        -value       ""
        -command     {}
        -accelerator ""
    }
    array set opts $args
    
    if {$opts(-value) eq ""} {
        set opts(-value) $label
    }
    
    set cmdArgs [list -label $label -variable $opts(-variable) -value $opts(-value)]
    
    if {$opts(-command) ne {}} {
        lappend cmdArgs -command $opts(-command)
    }
    if {$opts(-accelerator) ne ""} {
        lappend cmdArgs -accelerator $opts(-accelerator)
    }
    
    $menu add radiobutton {*}$cmdArgs
    
    # Item registrieren
    set idx [$menu index end]
    set items [dict get $instances($menu) items]
    dict set items $label [dict create \
        index    $idx \
        variable $opts(-variable) \
        value    $opts(-value) \
        command  $opts(-command) \
        type     radiobutton \
    ]
    dict set instances($menu) items $items
    
    return $idx
}

# ------------------------------------------------------------
# attach - Menu an Widget binden
# ------------------------------------------------------------
# Options:
#   -button  2|3 (Default: plattformabhaengig)
#
proc ::uicontextmenu::attach {menu widget args} {
    variable instances
    
    if {![info exists instances($menu)]} {
        error "uicontextmenu::attach: Unknown menu '$menu'"
    }
    
    # Defaults
    array set opts {
        -button ""
    }
    array set opts $args
    
    # Plattformabhaengige Button-Bestimmung
    if {$opts(-button) eq ""} {
        if {[tk windowingsystem] eq "aqua"} {
            set opts(-button) 2
        } else {
            set opts(-button) 3
        }
    }
    
    # Create bindings
    if {[tk windowingsystem] eq "aqua"} {
        bind $widget <Button-$opts(-button)> [list ::uicontextmenu::show $menu %X %Y]
        bind $widget <Control-Button-1> [list ::uicontextmenu::show $menu %X %Y]
    } else {
        bind $widget <Button-$opts(-button)> [list ::uicontextmenu::show $menu %X %Y]
    }
    
    # Widget registrieren
    set widgets [dict get $instances($menu) widgets]
    lappend widgets $widget
    dict set instances($menu) widgets $widgets
}

# ------------------------------------------------------------
# detach - Menu von Widget loesen
# ------------------------------------------------------------
proc ::uicontextmenu::detach {menu widget} {
    variable instances
    
    if {![info exists instances($menu)]} return
    
    # Remove bindings
    if {[tk windowingsystem] eq "aqua"} {
        bind $widget <Button-2> {}
        bind $widget <Control-Button-1> {}
    } else {
        bind $widget <Button-3> {}
    }
    
    # Widget deregistrieren
    set widgets [dict get $instances($menu) widgets]
    set idx [lsearch -exact $widgets $widget]
    if {$idx >= 0} {
        set widgets [lreplace $widgets $idx $idx]
        dict set instances($menu) widgets $widgets
    }
}

# ------------------------------------------------------------
# show - Show menu
# ------------------------------------------------------------
proc ::uicontextmenu::show {menu x y} {
    variable instances
    
    if {![info exists instances($menu)]} return
    if {![winfo exists $menu]} return
    
    # Update-Handler aufrufen wenn dynamisch
    if {[dict get $instances($menu) dynamic]} {
        set handler [dict get $instances($menu) updateHandler]
        if {$handler ne ""} {
            uplevel #0 $handler
        }
    }
    
    tk_popup $menu $x $y
}

# ------------------------------------------------------------
# enable / disable - Enable/disable menu entry
# ------------------------------------------------------------
proc ::uicontextmenu::enable {menu label} {
    variable instances
    
    if {![info exists instances($menu)]} return
    
    set items [dict get $instances($menu) items]
    if {![dict exists $items $label]} return
    
    set idx [dict get $items $label index]
    $menu entryconfigure $idx -state normal
}

proc ::uicontextmenu::disable {menu label} {
    variable instances
    
    if {![info exists instances($menu)]} return
    
    set items [dict get $instances($menu) items]
    if {![dict exists $items $label]} return
    
    set idx [dict get $items $label index]
    $menu entryconfigure $idx -state disabled
}

# ------------------------------------------------------------
# setCallback - Change callback after creation
# ------------------------------------------------------------
proc ::uicontextmenu::setCallback {menu label command} {
    variable instances
    
    if {![info exists instances($menu)]} return
    
    set items [dict get $instances($menu) items]
    if {![dict exists $items $label]} return
    
    set idx [dict get $items $label index]
    $menu entryconfigure $idx -command $command
}

# ------------------------------------------------------------
# setUpdateHandler - Handler for dynamische Menus
# ------------------------------------------------------------
proc ::uicontextmenu::setUpdateHandler {menu handler} {
    variable instances
    
    if {![info exists instances($menu)]} return
    
    dict set instances($menu) updateHandler $handler
}

# ------------------------------------------------------------
# destroy - Destroy menu
# ------------------------------------------------------------
proc ::uicontextmenu::destroy {menu} {
    variable instances
    
    if {![info exists instances($menu)]} return
    
    # Remove bindings
    set widgets [dict get $instances($menu) widgets]
    foreach widget $widgets {
        if {[winfo exists $widget]} {
            detach $menu $widget
        }
    }
    
    # Menu zerstoeren
    ::destroy $menu
    
    # Remove state
    unset instances($menu)
}

# ============================================================
# Convenience-Procs for haeufige Anwendungsfaelle
# ============================================================

# ------------------------------------------------------------
# createStandardEdit - Standard edit context menu
# ------------------------------------------------------------
proc ::uicontextmenu::createStandardEdit {path args} {
    array set opts {
        -cutcmd     {}
        -copycmd    {}
        -pastecmd   {}
        -selectall  {}
        -undo       {}
        -redo       {}
    }
    array set opts $args
    
    set menu [create $path]
    
    if {$opts(-undo) ne {}} {
        addItem $menu "Rueckgaengig" -command $opts(-undo) -accelerator "Ctrl+Z"
    }
    if {$opts(-redo) ne {}} {
        addItem $menu "Wiederholen" -command $opts(-redo) -accelerator "Ctrl+Y"
    }
    if {$opts(-undo) ne {} || $opts(-redo) ne {}} {
        addSeparator $menu
    }
    
    if {$opts(-cutcmd) ne {}} {
        addItem $menu "Cut" -command $opts(-cutcmd) -accelerator "Ctrl+X"
    }
    if {$opts(-copycmd) ne {}} {
        addItem $menu "Copy" -command $opts(-copycmd) -accelerator "Ctrl+C"
    }
    if {$opts(-pastecmd) ne {}} {
        addItem $menu "Paste" -command $opts(-pastecmd) -accelerator "Ctrl+V"
    }
    if {$opts(-selectall) ne {}} {
        addSeparator $menu
        addItem $menu "Alles auswaehlen" -command $opts(-selectall) -accelerator "Ctrl+A"
    }
    
    return $menu
}

# ------------------------------------------------------------
# createFromSpec - Create menu from specification
# ------------------------------------------------------------
# Spec-Format:
#   {
#       {label command ?-accelerator acc? ?-state state? ?-icon icon?}
#       -
#       {label {submenu-spec}}
#       {check label -variable var ?-command cmd?}
#       {radio label -variable var -value val ?-command cmd?}
#   }
#
proc ::uicontextmenu::createFromSpec {path spec} {
    set menu [create $path]
    _buildFromSpec $menu $spec
    return $menu
}

proc ::uicontextmenu::_buildFromSpec {menu spec} {
    foreach item $spec {
        if {$item eq "-"} {
            addSeparator $menu
            continue
        }
        
        set first [lindex $item 0]
        
        # Check for special types
        if {$first eq "check"} {
            set label [lindex $item 1]
            set rest [lrange $item 2 end]
            addCheckItem $menu $label {*}$rest
            continue
        }
        
        if {$first eq "radio"} {
            set label [lindex $item 1]
            set rest [lrange $item 2 end]
            addRadioItem $menu $label {*}$rest
            continue
        }
        
        # Normal item or submenu
        set label $first
        set second [lindex $item 1]
        
        # Ist second eine Liste (Submenu)?
        if {[llength $second] > 1 && [lindex $second 0] ni {-command -accelerator -state -icon}} {
            # Submenu
            set submenuPath $menu.[string map {" " _ . _} $label]
            set submenu [create $submenuPath]
            _buildFromSpec $submenu $second
            addSubmenu $menu $label $submenu
        } else {
            # Normal entry
            set rest [lrange $item 1 end]
            # Command is first element, rest are options
            if {[llength $rest] >= 1} {
                set cmd [lindex $rest 0]
                set opts [lrange $rest 1 end]
                addItem $menu $label -command $cmd {*}$opts
            }
        }
    }
}

package provide uicontextmenu 0.1
