# tests/basic.tcl -- Package smoke tests
#
# stack-1: Core packages -- no Tk required, headless-safe
# stack-2: GUI packages  -- only when Tk is available
#
# Regelbuch: model_without_tk -- Core-Layer darf kein Tk laden.
# mdviewer/mdsearch/mdoutline/mdcontextmenu sind GUI-Module und
# gehoeren deshalb in stack-2 (Tk-Guard).

package require tcltest
namespace import ::tcltest::*

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

# --------------------------------------------------------
# stack-1: Core -- headless-safe (kein Tk)
# --------------------------------------------------------
test stack-1 "require core packages (headless-safe)" -body {
    package require mdstack  0.1
    package require mdparser 0.2
    package require mdmodel  0.1
    package require mdhtml   0.1
    list ok
} -result {ok}

# --------------------------------------------------------
# stack-2: GUI -- nur wenn Tk verfuegbar
# --------------------------------------------------------
if {![catch {package require Tk}]} {
    test stack-2 "require viewer stack (Tk)" -body {
        package require mdviewer      0.3
        package require mdtext        0.1
        package require uicontextmenu 0.1
        package require mdcontextmenu 0.1
        package require mdsearch      0.1
        list ok
    } -result {ok}

} else {
    puts "  SKIP: stack-2/stack-3 -- Tk nicht verfuegbar"
}

cleanupTests
