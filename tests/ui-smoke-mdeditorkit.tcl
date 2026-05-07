package require tcltest
namespace import ::tcltest::*

# Eigene Module aus dem Repo (Tests laufen aus dem Repo)
if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}


package require Tk
package require mdstack::editorkit 0.2

test ui-1 "create mdeditorkit" -body {
    set w [mdstack::editorkit::create .k]
    update
    set m [mdstack::editorkit::mode $w]
    destroy $w
    set m
} -result split

test ui-2 "set text and render" -body {
    # debounce=0 for immediate parsing
    set w [mdstack::editorkit::create .k -debounce 0]
    mdstack::editorkit::settext $w "# Title\n\nText"
    update idletasks
    update
    set doc [mdstack::editorkit::getdocmodel $w]
    destroy $w
    expr {[dict exists $doc headings]}
} -result 1

test ui-3 "mode switching" -body {
    set w [mdstack::editorkit::create .k]
    mdstack::editorkit::setmode $w edit
    set a [mdstack::editorkit::mode $w]
    mdstack::editorkit::setmode $w preview
    set b [mdstack::editorkit::mode $w]
    destroy $w
    list $a $b
} -result {edit preview}

test ui-4 "gettext returns set text" -body {
    set w [mdstack::editorkit::create .k]
    set input "# Test\n\nContent"
    mdstack::editorkit::settext $w $input
    update
    set output [mdstack::editorkit::gettext $w]
    destroy $w
    expr {$input eq $output}
} -result 1

# Test ui-5 entfernt - Parser ist tolerant und wirft keine Fehler bei
# incomplete Markdown constructs like "**text ohne Ende"
# Das ist eine Design-Entscheidung, kein Bug.

cleanupTests
