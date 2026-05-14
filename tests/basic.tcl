# tests/basic.tcl -- Package smoke tests
#
# stack-1: Core packages -- no Tk required, headless-safe
# stack-2: GUI packages  -- only when Tk is available
#
# Regelbuch: model_without_tk -- Core-Layer darf kein Tk laden.
# mdviewer/mdsearch/mdoutline/mdcontextmenu sind GUI-Module und
# gehoeren deshalb in stack-2 (Tk-Guard).

# Eigene Module aus dem Repo (Tests laufen aus dem Repo)
if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    # Plus docir suchen (mdstack::html ist Adapter auf docir).
    source [file join [file dirname [info script]] _paths.tcl]
    set ::_setup_done 1
}


package require tcltest
namespace import ::tcltest::*

# --------------------------------------------------------
# stack-1: Core -- headless-safe (kein Tk)
# --------------------------------------------------------
# mdstack::html ist Adapter zu docir::mdSource/docir::html. Wenn docir
# nicht findbar ist, ist das kein Bug in mdstack -- der Test wird dann
# auf mdstack-only-Module beschraenkt.
if {[haveDocir]} {
    test stack-1 "require core packages (headless-safe)" -body {
        package require mdstack  0.1
        package require mdstack::parser 0.2
        package require mdstack::model  0.1
        package require mdstack::html   0.1
        list ok
    } -result {ok}
} else {
    test stack-1-no-docir "core packages without docir adapter" -body {
        package require mdstack  0.1
        package require mdstack::parser 0.2
        package require mdstack::model  0.1
        # mdstack::html nicht laden -- braucht docir
        list ok
    } -result {ok}
    puts "  NOTE: docir not installed -- stack-1 reduced (no mdstack::html test)"
}

# --------------------------------------------------------
# stack-2: GUI -- nur wenn Tk verfuegbar
# --------------------------------------------------------
if {![catch {package require Tk}]} {
    test stack-2 "require viewer stack (Tk)" -body {
        package require mdstack::viewer      0.3
        package require mdstack::text        0.1
        package require mdstack::uicontextmenu 0.1
        package require mdstack::contextmenu 0.1
        package require mdstack::search      0.1
        list ok
    } -result {ok}

} else {
    puts "  SKIP: stack-2/stack-3 -- Tk nicht verfuegbar"
}

cleanupTests
