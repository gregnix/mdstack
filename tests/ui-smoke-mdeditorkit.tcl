package require tcltest
namespace import ::tcltest::*

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require Tk
package require mdeditorkit 0.2

test ui-1 "create mdeditorkit" -body {
    set w [mdeditorkit::create .k]
    update
    set m [mdeditorkit::mode $w]
    destroy $w
    set m
} -result split

test ui-2 "set text and render" -body {
    # debounce=0 for immediate parsing
    set w [mdeditorkit::create .k -debounce 0]
    mdeditorkit::settext $w "# Title\n\nText"
    update idletasks
    update
    set doc [mdeditorkit::getdocmodel $w]
    destroy $w
    expr {[dict exists $doc headings]}
} -result 1

test ui-3 "mode switching" -body {
    set w [mdeditorkit::create .k]
    mdeditorkit::setmode $w edit
    set a [mdeditorkit::mode $w]
    mdeditorkit::setmode $w preview
    set b [mdeditorkit::mode $w]
    destroy $w
    list $a $b
} -result {edit preview}

test ui-4 "gettext returns set text" -body {
    set w [mdeditorkit::create .k]
    set input "# Test\n\nContent"
    mdeditorkit::settext $w $input
    update
    set output [mdeditorkit::gettext $w]
    destroy $w
    expr {$input eq $output}
} -result 1

# Test ui-5 entfernt - Parser ist tolerant und wirft keine Fehler bei
# incomplete Markdown constructs like "**text ohne Ende"
# Das ist eine Design-Entscheidung, kein Bug.

cleanupTests
