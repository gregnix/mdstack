package require tcltest
namespace import ::tcltest::*

# Eigene Module aus dem Repo (Tests laufen aus dem Repo)
if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}


package require Tk

# mdeditwidget 0.2 liegt in mdhelp, NICHT in mdstack. Der Test ist damit nicht
# obsolet -- mdstack::editorkit ist ein anderes Paket, geprueft von
# ui-smoke-mdeditorkit.tcl. Liegt mdhelp nicht im Pfad, wird uebersprungen
# statt abgebrochen: ein Abbruch hatte keine tcltest-Bilanz und fiel damit
# lautlos aus dem Gesamtlauf.
#
# Nachbildung nach dem Protokoll vom 29.09.2026. Gregors eigene Fassung ist
# die maßgebliche -- liegt sie in git, gilt die.
testConstraint mdeditwidget [expr {![catch {package require mdeditwidget 0.2}]}]
if {![testConstraint mdeditwidget]} {
    puts "SKIP: mdeditwidget 0.2 liegt in mdhelp, nicht in mdstack"
}

test ui-widget-1 "create mdeditwidget" -constraints mdeditwidget -body {
    set w [mdeditwidget::create .w]
    update
    set m [mdeditwidget::mode $w]
    destroy $w
    set m
} -result split

test ui-widget-2 "settext and gettext" -constraints mdeditwidget -body {
    set w [mdeditwidget::create .w]
    set input "# Test\n\nContent"
    mdeditwidget::settext $w $input
    update
    set output [mdeditwidget::gettext $w]
    destroy $w
    expr {$input eq $output}
} -result 1

test ui-widget-3 "mode switching" -constraints mdeditwidget -body {
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

test ui-widget-4 "getdocmodel" -constraints mdeditwidget -body {
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
