# uicontextmenu.tcl - Tests for mdstack::uicontextmenu::createFromSpec
# Run: tclsh tests/uicontextmenu.tcl   (needs Tk / a display)

set scriptDir [file dirname [info script]]
tcl::tm::path add [file normalize [file join $scriptDir .. lib]]

package require tcltest
namespace import ::tcltest::*

testConstraint haveTk [expr {![catch {package require Tk}]}]
if {[testConstraint haveTk]} {
    wm withdraw .
    package require mdstack::uicontextmenu 0.1
}

# Entries of a menu as {type label ...}
proc entries {m} {
    set r {}
    if {[$m index end] eq "none"} { return $r }
    for {set i 0} {$i <= [$m index end]} {incr i} {
        set t [$m type $i]
        if {$t eq "separator"} {
            lappend r separator
        } else {
            lappend r $t [$m entrycget $i -label]
        }
    }
    return $r
}

proc cleanupMenu {} {
    catch {mdstack::uicontextmenu::destroy .cm}
    catch {destroy .cm}
}

# Regression: a multi-word command was taken for a submenu spec
test spec-1 "multi-word command is a command entry" -constraints haveTk -body {
    set m [mdstack::uicontextmenu::createFromSpec .cm {
        {Save {puts saved}}
        {Open {app::open $w -force}}
    }]
    list [entries $m] [$m entrycget 0 -command] [$m entrycget 1 -command]
} -cleanup cleanupMenu -result {{command Save command Open} {puts saved} {app::open $w -force}}

test spec-2 "short submenu form {label {spec}} still works" -constraints haveTk -body {
    set m [mdstack::uicontextmenu::createFromSpec .cm {
        {Format {{Bold {puts b}} - {Italic {puts i}}}}
        {Single {{Only {puts o}}}}
    }]
    set sub  [$m entrycget 0 -menu]
    set sub2 [$m entrycget 1 -menu]
    list [entries $m] [entries $sub] [entries $sub2]
} -cleanup cleanupMenu -result {{cascade Format cascade Single} {command Bold separator command Italic} {command Only}}

test spec-3 "explicit -menu and -command forms" -constraints haveTk -body {
    set m [mdstack::uicontextmenu::createFromSpec .cm {
        {Insert -menu {{Link {puts l}}}}
        {Run -command {puts run} -accelerator Ctrl+R}
        {Quit {puts bye} -accelerator Ctrl+Q}
    }]
    list [entries $m] [entries [$m entrycget 0 -menu]] \
        [$m entrycget 1 -command] [$m entrycget 1 -accelerator] \
        [$m entrycget 2 -command] [$m entrycget 2 -accelerator]
} -cleanup cleanupMenu -result {{cascade Insert command Run command Quit} {command Link} {puts run} Ctrl+R {puts bye} Ctrl+Q}

test spec-4 "check and radio entries in a submenu" -constraints haveTk -body {
    set m [mdstack::uicontextmenu::createFromSpec .cm {
        {View {{check Wrap -variable ::_wrap} {radio Small -variable ::_size -value s}}}
    }]
    entries [$m entrycget 0 -menu]
} -cleanup {cleanupMenu; unset -nocomplain ::_wrap ::_size} -result {checkbutton Wrap radiobutton Small}

cleanupTests
