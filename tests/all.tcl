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
set runSrv  1
if {[llength $argv] > 0} {
    set runCore [expr {"--core" in $argv}]
    set runGui  [expr {"--gui"  in $argv}]
    set runPdf  [expr {"--pdf"  in $argv}]
    set runSrv  [expr {"--server" in $argv}]
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
# Eine Testdatei, die beim Laden stirbt, hat KEINE Bilanzzeile. Bis 2026-09-29
# fiel sie damit lautlos aus dem Endstand: die Fehlermeldung wurde gedruckt,
# aber nichts gezaehlt, errorFiles blieb leer, und der Exit-Code war 0.
# Gemessen mit einer Datei, deren "package require" fehlschlaegt:
#
#   basic.tcl: Total 1 Passed 1 Skipped 0 Failed 0
#   can't find package gibtsnichtmehr 9.9
#   GESAMT: Total 1 Failed 0
#   EXIT=0
#
# In CI waere das gruen. Dasselbe Muster wie der Befund vom 2026-05-07, nur
# eine Ebene hoeher: damals wurden Failures INNERHALB einer Suite nicht
# gezaehlt, jetzt der Ausfall einer ganzen Suite. Keine Bilanz heisst ab jetzt
# Fehler.
proc runTcltest {dir files} {
    global grandTotal grandPassed grandFailed grandSkipped errorFiles
    foreach f $files {
        set path [file join $dir $f]
        if {![file exists $path]} {
            # Kein "SKIP": diese Liste steht im Repo, die Dateien auch. Fehlt
            # eine, ist die Liste falsch oder die Datei verloren -- gemessen am
            # 29.09.2026 blieb GESAMT unveraendert, Failed 0, Exit 0.
            puts "  ERROR in $f: steht in der Liste, ist aber nicht da"
            lappend errorFiles "$f (fehlt)"
            incr grandFailed 1
            incr grandTotal  1
            continue
        }
        # 2>@1: die Abbruchmeldung gehoert in die Ausgabe, nicht ins Nichts
        catch {exec [info nameofexecutable] $path 2>@1} out
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
        } else {
            puts "  ERROR in $f: keine tcltest-Bilanz -- die Datei ist nicht gelaufen"
            incr grandTotal  1
            incr grandFailed 1
            lappend errorFiles "$f (nicht gelaufen)"
        }
    }
}

# runAssert: source-basiert, zaehlt Total/Passed/Failed via shared vars
proc runAssert {dir files} {
    global grandTotal grandPassed grandFailed grandSkipped errorFiles
    foreach f $files {
        set path [file join $dir $f]
        if {![file exists $path]} {
            # Kein "SKIP": diese Liste steht im Repo, die Dateien auch. Fehlt
            # eine, ist die Liste falsch oder die Datei verloren -- gemessen am
            # 29.09.2026 blieb GESAMT unveraendert, Failed 0, Exit 0.
            puts "  ERROR in $f: steht in der Liste, ist aber nicht da"
            lappend errorFiles "$f (fehlt)"
            incr grandFailed 1
            incr grandTotal  1
            continue
        }
        set total 0; set passed 0; set failed 0; set skipped 0
        if {[catch {source $path} err]} {
            puts "  ERROR in $f: $err"
            lappend errorFiles $f
            incr grandFailed 1
            incr grandTotal  1
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
        if {![file exists $path]} {
            # Kein "SKIP": diese Liste steht im Repo, die Dateien auch. Fehlt
            # eine, ist die Liste falsch oder die Datei verloren -- gemessen am
            # 29.09.2026 blieb GESAMT unveraendert, Failed 0, Exit 0.
            puts "  ERROR in $f: steht in der Liste, ist aber nicht da"
            lappend errorFiles "$f (fehlt)"
            incr grandFailed 1
            incr grandTotal  1
            continue
        }
        if {[catch {exec [info nameofexecutable] $path 2>@1} out]} {
            puts "  ERROR in $f"
            lappend errorFiles $f
            incr grandFailed 1
            incr grandTotal  1
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
        parser-tables.tcl
        parser-backslash.tcl
        parser-code-spans.tcl
        parser-emphasis-flanking.tcl
        parser-link-features.tcl
        parser-loose-lists.tcl
        parser-html-blocks.tcl
    }

    # assert-basiert
    runAssert $dir {
        parser-deflist.tcl
        parser-inline-features.tcl
        parser-inline-fixes.tcl
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
        test-html-assets.tcl
    }
}

# ============================================================
# C. GUI/Tk -- nur wenn Tk verfuegbar
# ============================================================

if {$runGui} {
    if {![catch {package require Tk}]} {
        puts "\n--- C. GUI/Tk ---"
        runTcltest $dir {
            mdtext.tcl
            ui-smoke-mdeditorkit.tcl
            ui-smoke-mdeditwidget.tcl
            ui-parser-error.tcl
            viewer.tcl
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
# E. mdserver -- lag bis 2026-09-29 gar nicht im Gesamtlauf
# ============================================================
#
# Die Suite liegt nicht in tests/, sondern bei ihrem Werkzeug, und war darum
# hier nie aufgefuehrt: wer "make test" lief, pruefte mdserver nicht mit. Sie
# laedt ihr Modul selbst (tcl::tm::path relativ zum Skript) und startet
# eigene Serverprozesse, braucht also nur einen eigenen Interpreter -- genau
# das, was runTcltest tut. Sie dauert laenger als die anderen (Prozessstarts,
# Wartezeiten beim Beenden), darum am Ende und mit --server einzeln aufrufbar.
if {$runSrv} {
    set srvDir [file normalize [file join $dir .. tools mdserver test]]
    if {[file exists [file join $srvDir test-mdserver-oo.tcl]]} {
        puts "\n--- E. mdserver (HTTP, eigene Prozesse) ---"
        runTcltest $srvDir { test-mdserver-oo.tcl }
    } else {
        puts "\n--- E. mdserver: SKIP (tools/mdserver/test nicht gefunden) ---"
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
