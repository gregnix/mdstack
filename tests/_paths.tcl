# tests/_paths.tcl -- gemeinsame Pfad-Konfiguration fuer mdstack-Tests
#
# Wird gesourced von Tests die mdstack-Module ODER docir-Module via
# 'package require' laden wollen.
#
# Was wir setzen:
#  - tcl::tm::path um $repoRoot/lib  (mdstack-Module)
#  - tcl::tm::path um Pfade zu docir (Konsumenten-Modul, separater Repo)
#  - $auto_path falls noetig (fuer pkgIndex.tcl-basierte Pakete)
#
# Docir wird in dieser Reihenfolge gesucht:
#  1. $::env(DOCIR_HOME)/lib/tm           (Env-Variable, explizit)
#  2. ../docir/lib/tm                      (Sibling-Repo)
#  3. ../../docir/lib/tm                   (Parent-of-Parent)
#  4. ~/lib/tcltk/docir                    (User-Install)
#  5. systemweit ueber Default-auto_path   (z.B. /usr/local/lib/tcltk/docir)
#
# Wird docir nicht gefunden, hat der Aufrufer Pech und 'package require
# docir::*' schlaegt fehl. Der Test sollte sich dann self-skippen.

if {[info exists ::_mdstack_paths_done]} { return }
set ::_mdstack_paths_done 1

set _here     [file dirname [file normalize [info script]]]
set _repoRoot [file dirname $_here]

# 1. mdstack selber
tcl::tm::path add [file join $_repoRoot lib]

# 2. docir suchen
set _docirCandidates [list]
if {[info exists ::env(DOCIR_HOME)]} {
    lappend _docirCandidates [file join $::env(DOCIR_HOME) lib tm]
}
lappend _docirCandidates [file normalize [file join $_repoRoot .. docir lib tm]]
lappend _docirCandidates [file normalize [file join $_repoRoot ../.. docir lib tm]]
lappend _docirCandidates [file normalize [file join ~ lib tcltk docir]]

foreach _candidate $_docirCandidates {
    if {[file isdirectory $_candidate]} {
        tcl::tm::path add $_candidate
        set ::_mdstack_docir_path $_candidate
        break
    }
}

# Helper: gibt 1 zurueck wenn docir-Module verfuegbar (per package).
# Tests koennen damit sauber skippen:
#   if {![haveDocir]} { puts "Skipping: docir not installed"; exit 0 }
proc haveDocir {} {
    return [expr {![catch {package require docir}]}]
}

unset -nocomplain _here _repoRoot _docirCandidates _candidate
