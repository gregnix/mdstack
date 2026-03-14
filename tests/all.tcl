#!/usr/bin/env tclsh
# ============================================================
# mdstack Test Runner
# Run: tclsh test/all.tcl
# ============================================================

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

set dir [file dirname [info script]]

# Collect overall results
set grandTotal 0
set grandPassed 0
set grandFailed 0
set grandSkipped 0
set errorFiles {}

# ============================================================
# A. tcltest-basierte Tests
#    (brauchen eigenen Interpreter wegen cleanupTests-Konflikten)
# ============================================================

set tcltestFiles {
    basic.tcl
    extended.tcl
    parser-indented.tcl
    parser-hardbreak.tcl
    parser-blockquote.tcl
    parser-oratcl-style.tcl
    mdstack.tcl
}

foreach f $tcltestFiles {
    set path [file join $dir $f]
    if {![file exists $path]} {
        puts "  SKIP: $f (not found)"
        continue
    }
    if {[catch {exec [info nameofexecutable] $path} output]} {
        # tclsh gibt bei tcltest-Fehlern exit 1 zurueck,
        # but the output is still in $output
        append output "\n" $::errorInfo
    }
    # Forward output
    if {$output ne ""} {
        puts $output
    }
}

# ============================================================
# B. assert-basierte Tests (direkt sourcen)
# ============================================================

set assertFiles {
    parser-nested-lists.tcl
    parser-multiline-list.tcl
    parser-inline-features.tcl
    parser-inline-fixes.tcl
    parser-reflinks.tcl
    parser-deflist.tcl
    parser-phase2.tcl
}

foreach f $assertFiles {
    set path [file join $dir $f]
    if {![file exists $path]} {
        puts "  SKIP: $f (not found)"
        continue
    }
    # Reset counters vor jedem File
    set total 0; set passed 0; set failed 0; set skipped 0
    if {[catch {source $path} err]} {
        puts "  ERROR in $f: $err"
        lappend errorFiles $f
    }
    incr grandTotal $total
    incr grandPassed $passed
    incr grandFailed $failed
    incr grandSkipped $skipped
}

# ============================================================
# C. UI-Tests (nur wenn Tk verfuegbar)
# ============================================================

if {![catch {package require Tk}]} {
    set uiFiles {
        mdtext.tcl
        ui-smoke-mdeditorkit.tcl
        ui-smoke-mdeditwidget.tcl
        ui-parser-error.tcl
    }
    foreach f $uiFiles {
        set path [file join $dir $f]
        if {![file exists $path]} {
            puts "  SKIP: $f (not found)"
            continue
        }
        if {[catch {exec [info nameofexecutable] $path} output]} {
            append output "\n"
        }
        if {$output ne ""} {
            puts $output
        }
    }
} else {
    puts "  SKIP: UI-Tests (Tk nicht verfuegbar)"
}

# ============================================================
# Overall result (only assert-based tests counted)
# ============================================================

puts ""
puts "=========================================="
puts "GESAMT (assert-Tests):\tTotal\t$grandTotal\tPassed\t$grandPassed\tSkipped\t$grandSkipped\tFailed\t$grandFailed"
if {[llength $errorFiles] > 0} {
    puts "ERRORS in: [join $errorFiles {, }]"
}
puts "=========================================="
