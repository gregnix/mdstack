package require tcltest
namespace import ::tcltest::*

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require Tk
package require mdeditwidget 0.2

test ui-widget-1 "create mdeditwidget" -body {
    set w [mdeditwidget::create .w]
    update
    set m [mdeditwidget::mode $w]
    destroy $w
    set m
} -result split

test ui-widget-2 "settext and gettext" -body {
    set w [mdeditwidget::create .w]
    set input "# Test\n\nContent"
    mdeditwidget::settext $w $input
    update
    set output [mdeditwidget::gettext $w]
    destroy $w
    expr {$input eq $output}
} -result 1

test ui-widget-3 "mode switching" -body {
    set w [mdeditwidget::create .w]
    mdeditwidget::setmode $w edit
    set a [mdeditwidget::mode $w]
    mdeditwidget::setmode $w preview
    set b [mdeditwidget::mode $w]
    mdeditwidget::setmode $w split
    set c [mdeditwidget::mode $w]
    destroy $w
    list $a $b $c
} -result {edit preview split}

test ui-widget-4 "getdocmodel" -body {
    # debounce=0 for immediate parsing
    set w [mdeditwidget::create .w -debounce 0]
    mdeditwidget::settext $w "# Title\n\nText"
    update idletasks
    update
    set doc [mdeditwidget::getdocmodel $w]
    destroy $w
    expr {[dict exists $doc headings]}
} -result 1

cleanupTests
