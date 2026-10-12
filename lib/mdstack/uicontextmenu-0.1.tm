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

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::mdstack::uicontextmenu {
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
proc ::mdstack::uicontextmenu::create {path args} {
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
proc ::mdstack::uicontextmenu::addItem {menu label args} {
    variable instances
    
    if {![info exists instances($menu)]} {
        error "mdstack::uicontextmenu::addItem: Unknown menu '$menu'"
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
proc ::mdstack::uicontextmenu::addSeparator {menu} {
    variable instances
    
    if {![info exists instances($menu)]} {
        error "mdstack::uicontextmenu::addSeparator: Unknown menu '$menu'"
    }
    
    $menu add separator
    return [$menu index end]
}

# ------------------------------------------------------------
# addSubmenu - Add submenu
# ------------------------------------------------------------
proc ::mdstack::uicontextmenu::addSubmenu {menu label submenu} {
    variable instances
    
    if {![info exists instances($menu)]} {
        error "mdstack::uicontextmenu::addSubmenu: Unknown menu '$menu'"
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
proc ::mdstack::uicontextmenu::addCheckItem {menu label args} {
    variable instances
    
    if {![info exists instances($menu)]} {
        error "mdstack::uicontextmenu::addCheckItem: Unknown menu '$menu'"
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
        set opts(-variable) "::mdstack::uicontextmenu::check_${menu}_${safeName}"
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
proc ::mdstack::uicontextmenu::addRadioItem {menu label args} {
    variable instances
    
    if {![info exists instances($menu)]} {
        error "mdstack::uicontextmenu::addRadioItem: Unknown menu '$menu'"
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
proc ::mdstack::uicontextmenu::attach {menu widget args} {
    variable instances
    
    if {![info exists instances($menu)]} {
        error "mdstack::uicontextmenu::attach: Unknown menu '$menu'"
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
        bind $widget <Button-$opts(-button)> [list ::mdstack::uicontextmenu::show $menu %X %Y]
        bind $widget <Control-Button-1> [list ::mdstack::uicontextmenu::show $menu %X %Y]
    } else {
        bind $widget <Button-$opts(-button)> [list ::mdstack::uicontextmenu::show $menu %X %Y]
    }
    
    # Widget registrieren
    set widgets [dict get $instances($menu) widgets]
    lappend widgets $widget
    dict set instances($menu) widgets $widgets
}

# ------------------------------------------------------------
# detach - Menu von Widget loesen
# ------------------------------------------------------------
proc ::mdstack::uicontextmenu::detach {menu widget} {
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
proc ::mdstack::uicontextmenu::show {menu x y} {
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
proc ::mdstack::uicontextmenu::enable {menu label} {
    variable instances
    
    if {![info exists instances($menu)]} return
    
    set items [dict get $instances($menu) items]
    if {![dict exists $items $label]} return
    
    set idx [dict get $items $label index]
    $menu entryconfigure $idx -state normal
}

proc ::mdstack::uicontextmenu::disable {menu label} {
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
proc ::mdstack::uicontextmenu::setCallback {menu label command} {
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
proc ::mdstack::uicontextmenu::setUpdateHandler {menu handler} {
    variable instances
    
    if {![info exists instances($menu)]} return
    
    dict set instances($menu) updateHandler $handler
}

# ------------------------------------------------------------
# destroy - Destroy menu
# ------------------------------------------------------------
proc ::mdstack::uicontextmenu::destroy {menu} {
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
proc ::mdstack::uicontextmenu::createStandardEdit {path args} {
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
#       {label -command command ?-accelerator acc? ...}
#       -
#       {label -menu {submenu-spec}}
#       {label {submenu-spec}}
#       {check label -variable var ?-command cmd?}
#       {radio label -variable var -value val ?-command cmd?}
#   }
#
# Submenu detection:
#   - "-menu" after the label always means a submenu, "-command" always
#     a command entry (explicit forms, never ambiguous).
#   - Short form {label X}: X is a submenu only if it is a well-formed
#     spec, i.e. every element is "-" or a list of at least two words
#     (an entry). A command such as {puts hello} or {app::save $w} starts
#     with a one-word command name and is therefore a command entry.
#   - An entry with options after the command ({label cmd -accelerator ..})
#     is always a command entry.
#
proc ::mdstack::uicontextmenu::createFromSpec {path spec} {
    set menu [create $path]
    _buildFromSpec $menu $spec
    return $menu
}

proc ::mdstack::uicontextmenu::_buildFromSpec {menu spec} {
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
        set rest  [lrange $item 1 end]
        set second [lindex $rest 0]

        if {$second eq "-menu"} {
            # Explicit submenu: {label -menu {spec}}
            _addSubmenuFromSpec $menu $label [lindex $rest 1]
        } elseif {$second eq "-command"} {
            # Explicit command entry: {label -command cmd ?opts?}
            addItem $menu $label {*}$rest
        } elseif {[llength $rest] == 1 && [_isSpec $second]} {
            # Short form {label {spec}}
            _addSubmenuFromSpec $menu $label $second
        } elseif {[llength $rest] >= 1} {
            # Normal entry: command is the first element, rest are options.
            # A multi-word command ({puts hello}) stays a command.
            addItem $menu $label -command $second {*}[lrange $rest 1 end]
        }
    }
}

# _isSpec - is value a submenu spec? Every element must be a separator
# "-" or an entry list with at least two words (label + command/spec,
# or check/radio + label ...). A Tcl command starts with a one-word
# command name, so {puts hello} or {app::save $w} is not a spec.
proc ::mdstack::uicontextmenu::_isSpec {value} {
    if {[catch {llength $value} n] || $n == 0} { return 0 }
    foreach entry $value {
        if {$entry eq "-"} continue
        if {[catch {llength $entry} m] || $m < 2} { return 0 }
    }
    return 1
}

# _addSubmenuFromSpec - create a cascade with a generated child path.
# The label is not used for the path: Tk window names must not start
# with an upper-case letter and must be unique.
proc ::mdstack::uicontextmenu::_addSubmenuFromSpec {menu label spec} {
    set n 0
    while {[winfo exists $menu.sub$n]} { incr n }
    set submenu [create $menu.sub$n]
    _buildFromSpec $submenu $spec
    addSubmenu $menu $label $submenu
}

package provide mdstack::uicontextmenu 0.1
