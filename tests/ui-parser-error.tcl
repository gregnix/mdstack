package require tcltest
namespace import ::tcltest::*

# Eigene Module aus dem Repo (Tests laufen aus dem Repo)
if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}


package require Tk
package require mdstack::editorkit 0.2

# The mdparser is tolerant and does not throw errors on incomplete
# Markdown-Konstrukten. Stattdessen testen wir, dass der Editor nicht crasht.

test ui-err-1 "unterminated fenced code does not crash" -body {
    set w [mdstack::editorkit::create .ke -debounce 0]
    
    mdstack::editorkit::settext $w "# ok\n\ntext"
    update idletasks
    update
    
    # Incomplete code block - should not crash
    mdstack::editorkit::settext $w "~~~\nunterminated fenced"
    update idletasks
    update
    
    # Check that we still have a valid doc
    set doc [mdstack::editorkit::getdocmodel $w]
    set ok [dict exists $doc headings]
    
    destroy $w
    set ok
} -result 1

cleanupTests
