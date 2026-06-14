#!/usr/bin/env tclsh
# tests/all.tcl -- mdstack Test Runner
#
# Aufteilung in vier Gruppen:
#   A. Core/Parser   -- headless, kein Tk, kein PDF
#   B. Renderer      -- headless, kein Tk (mdhtml, docir, toc via mdparser)
#   C. GUI/Tk        -- nur wenn Tk verfuegbar
#   D. PDF/Export    -- nur wenn pdf4tcl verfuegbar
#
# Aufruf:
#   tclsh tests/all.tcl            -- alle verfuegbaren Gruppen
#   tclsh tests/all.tcl --core     -- nur A + B
#   tclsh tests/all.tcl --gui      -- nur C
#   tclsh tests/all.tcl --pdf      -- nur D

set dir [file dirname [info script]]

# --- Flags auswerten ---
set runCore 1
set runGui  1
set runPdf  1
if {[llength $argv] > 0} {
    set runCore [expr {"--core" in $argv}]
    set runGui  [expr {"--gui"  in $argv}]
    set runPdf  [expr {"--pdf"  in $argv}]
}

# --- Zaehler ---
set grandTotal   0
set grandPassed  0
set grandFailed  0
set grandSkipped 0
set errorFiles   {}

# --- Hilfsprozeduren ---

# runTcltest: exec-basiert (tcltest braucht eigenen Interpreter).
# Parst tcltest-Output am Ende ("Total N Passed N Skipped N Failed N")
# und aggregiert die Counter ins Grand-Total. Vorher wurden Failures
# innerhalb von tcltest-Suites nur ausgegeben, aber nicht im Endstand
# gezählt — gemeldet 2026-05-07 via dritten externen Prüfbericht.
proc runTcltest {dir files} {
    global grandTotal grandPassed grandFailed grandSkipped errorFiles
    foreach f $files {
        set path [file join $dir $f]
        if {![file exists $path]} { puts "  SKIP: $f (not found)"; continue }
        if {[catch {exec [info nameofexecutable] $path} out]} {
            append out ""
        }
        if {$out ne ""} { puts $out }
        # tcltest-Format: ".../basic.tcl:	Total	17	Passed	17	Skipped	0	Failed	0"
        if {[regexp {Total\s+(\d+)\s+Passed\s+(\d+)\s+Skipped\s+(\d+)\s+Failed\s+(\d+)} \
                $out -> tot pas skp fld]} {
            incr grandTotal   $tot
            incr grandPassed  $pas
            incr grandSkipped $skp
            incr grandFailed  $fld
            if {$fld > 0} {
                lappend errorFiles "$f ($fld failed)"
            }
        }
    }
}

# runAssert: source-basiert, zaehlt Total/Passed/Failed via shared vars
proc runAssert {dir files} {
    global grandTotal grandPassed grandFailed grandSkipped errorFiles
    foreach f $files {
        set path [file join $dir $f]
        if {![file exists $path]} { puts "  SKIP: $f (not found)"; continue }
        set total 0; set passed 0; set failed 0; set skipped 0
        if {[catch {source $path} err]} {
            puts "  ERROR in $f: $err"
            lappend errorFiles $f
        }
        incr grandTotal   $total
        incr grandPassed  $passed
        incr grandFailed  $failed
        incr grandSkipped $skipped
    }
}

# runCustom: exec-basiert fuer Tests mit eigenem Output-Format
proc runCustom {dir files} {
    global grandFailed errorFiles
    foreach f $files {
        set path [file join $dir $f]
        if {![file exists $path]} { puts "  SKIP: $f (not found)"; continue }
        if {[catch {exec [info nameofexecutable] $path 2>@1} out]} {
            puts "  ERROR in $f"
            lappend errorFiles $f
        }
        if {$out ne ""} { puts $out }
    }
}

# ============================================================
# A. Core/Parser -- headless-safe (kein Tk, kein PDF)
# ============================================================

if {$runCore} {
    puts "\n--- A. Core/Parser (headless) ---"

    # tcltest-basiert
    runTcltest $dir {
        basic.tcl
        extended.tcl
        mdstack.tcl
        parser-blockquote.tcl
        parser-hardbreak.tcl
        parser-indented.tcl
        parser-oratcl-style.tcl
    }

    # assert-basiert
    runAssert $dir {
        parser-deflist.tcl
        parser-inline-features.tcl
        parser-inline-fixes.tcl
        parser-emphasis-flanking.tcl
        parser-multiline-list.tcl
        parser-nested-lists.tcl
        parser-phase2.tcl
        parser-reflinks.tcl
        parser-tip700.tcl
        parser-tip700-t2t3.tcl
        validator.tcl
    }

    # Eigenes Output-Format (kein Zaehler, aber headless)
    puts ""
    runCustom $dir {
        smoke-phase2.tcl
    }

    # --------------------------------------------------------
    # B. Renderer -- headless (mdhtml, docir-md, toc-logik)
    # --------------------------------------------------------
    puts "\n--- B. Renderer (headless) ---"

    # test-docir-md.tcl: eigenes Test-Framework, eigener Output --
    # via runCustom in Sub-Prozess. So skipt es sich sauber auch
    # ohne Renner abzubrechen.
    runCustom $dir {
        test-docir-md.tcl
    }
}

# ============================================================
# C. GUI/Tk -- nur wenn Tk verfuegbar
# ============================================================

if {$runGui} {
    if {![catch {package require Tk}]} {
        puts "\n--- C. GUI/Tk ---"
        runTcltest $dir {
            viewer.tcl
            mdtext.tcl
            ui-smoke-mdeditorkit.tcl
            ui-parser-error.tcl
        }
        # Tk-Tests mit assert-Format
        runAssert $dir {
            test-blockquote-italic.tcl
            test-context-tags.tcl
        }
    } else {
        puts "\n--- C. GUI/Tk: SKIP (Tk nicht verfuegbar) ---"
    }
}

# ============================================================
# D. PDF/Export -- nur wenn pdf4tcl verfuegbar
# ============================================================

if {$runPdf} {
    if {![catch {package require pdf4tcl}]} {
        puts "\n--- D. PDF/Export ---"
        runAssert $dir {
            test-emoji-sanitize.tcl
            test-emoji-pdf.tcl
        }
        runCustom $dir {
            test-toc.tcl
        }
    } else {
        puts "\n--- D. PDF/Export: SKIP (pdf4tcl nicht verfuegbar) ---"
    }
}

# ============================================================
# Gesamtergebnis (assert-basierte Tests)
# ============================================================

puts ""
puts "=========================================="
puts "GESAMT:\tTotal\t$grandTotal\tPassed\t$grandPassed\tSkipped\t$grandSkipped\tFailed\t$grandFailed"
if {[llength $errorFiles] > 0} {
    puts "ERRORS in: [join $errorFiles {, }]"
}
puts "=========================================="

# Exit-Code so setzen, dass CI / Skripte den Erfolg erkennen können.
exit [expr {$grandFailed > 0 || [llength $errorFiles] > 0 ? 1 : 0}]
