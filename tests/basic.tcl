package require tcltest
namespace import ::tcltest::*

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

test stack-1 "require core packages" -body {
    package require mdstack 0.1
    package require mdparser 0.2
    package require mdmodel  0.1
    package require mdviewer 0.3
    package require mdtext 0.1
    package require uicontextmenu 0.1
    package require mdcontextmenu 0.1
    list ok
} -result {ok}

test stack-2 "require editor stack" -body {
    package require Tk
    package require mdeditor 0.1
    package require mdeditorkit 0.2
    package require mdeditwidget 0.2
    list ok
} -result {ok}

cleanupTests
