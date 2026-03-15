package require tcltest
namespace import ::tcltest::*

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require Tk
package require mdeditorkit 0.2

# The mdparser is tolerant and does not throw errors on incomplete
# Markdown-Konstrukten. Stattdessen testen wir, dass der Editor nicht crasht.

test ui-err-1 "unterminated fenced code does not crash" -body {
    set w [mdeditorkit::create .ke -debounce 0]
    
    mdeditorkit::settext $w "# ok\n\ntext"
    update idletasks
    update
    
    # Incomplete code block - should not crash
    mdeditorkit::settext $w "~~~\nunterminated fenced"
    update idletasks
    update
    
    # Check that we still have a valid doc
    set doc [mdeditorkit::getdocmodel $w]
    set ok [dict exists $doc headings]
    
    destroy $w
    set ok
} -result 1

cleanupTests
