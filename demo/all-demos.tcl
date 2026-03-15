#!/usr/bin/env tclsh
# all-demos.tcl -- Run all CLI demos (non-GUI)
#
# Runs all headless demos and reports pass/fail.
# GUI demos (mdviewer-app-v2.tcl, mdtext-demo.tcl etc.) are skipped.
#
# Usage:
#   tclsh all-demos.tcl
#   tclsh all-demos.tcl --pdf    # only PDF demos
#   tclsh all-demos.tcl --html   # only HTML demos

set scriptDir [file dirname [file normalize [info script]]]

# CLI-only demos (headless, produce files)
set allDemos {
    demo-tip700.tcl
    mdhtml-themes-demo.tcl
    mdpdf-features-demo.tcl
    mdpdf-hyperlink-demo.tcl
    mdpdf-pdfa-demo.tcl
    mdpdf-encryption-demo.tcl
}

set pdfdemos  {mdpdf-features-demo.tcl mdpdf-hyperlink-demo.tcl
               mdpdf-pdfa-demo.tcl mdpdf-encryption-demo.tcl}
set htmldemos {mdhtml-themes-demo.tcl}

# Filter by flag
set flag [lindex $argv 0]
switch -- $flag {
    --pdf  { set demos $pdfdemos }
    --html { set demos $htmldemos }
    default { set demos $allDemos }
}

set passed 0
set failed 0
set errors {}

puts "\n=== mdstack demo runner ===\n"

foreach demo $demos {
    set path [file join $scriptDir $demo]
    if {![file exists $path]} {
        puts "SKIP  $demo (not found)"
        continue
    }

    set t0 [clock milliseconds]
    set rc [catch {exec [info nameofexecutable] $path 2>@1} out]
    set ms [expr {[clock milliseconds] - $t0}]

    if {$rc == 0} {
        puts [format "PASS  %-40s  %dms" $demo $ms]
        incr passed
    } else {
        puts [format "FAIL  %-40s  %dms" $demo $ms]
        lappend errors [list $demo $out]
        incr failed
    }
}

puts "\n--- [expr {$passed + $failed}] demos: $passed passed, $failed failed ---"

if {[llength $errors] > 0} {
    puts "\nErrors:"
    foreach {e} $errors {
        lassign $e name msg
        puts "\n--- $name ---"
        puts $msg
    }
    exit 1
}
