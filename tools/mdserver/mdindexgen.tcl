#!/usr/bin/env tclsh
# mdindexgen.tcl -- CLI front-end for mdstack::indexgen
#
# Generates/updates index.md + indexsub.md across a Markdown directory tree.
# Thin wrapper: all logic lives in the mdstack::indexgen package.
#
# Usage:
#   tclsh mdindexgen.tcl --root docs
#   tclsh mdindexgen.tcl --root docs --dry-run
#   tclsh mdindexgen.tcl --root docs --quiet

package require Tcl 8.6 9

# Locate mdstack's module tree relative to this script (mdstack/tools -> mdstack/lib).
set here [file dirname [file normalize [info script]]]
foreach cand [list [file join $here .. lib] [file join $here .. .. lib] [file join $here lib]] {
    if {[file isdirectory [file join $cand mdstack]]} {
        tcl::tm::path add $cand
        break
    }
}

set root "."; set dryrun 0; set verbose 1
for {set i 0} {$i < [llength $argv]} {incr i} {
    switch -- [lindex $argv $i] {
        --root    { set root [lindex $argv [incr i]] }
        --dry-run { set dryrun 1 }
        --quiet   { set verbose 0 }
        --help - -h {
            puts "mdindexgen.tcl -- generate index.md + indexsub.md (mdstack::indexgen)"
            puts "  --root DIR    document root to scan (default: .)"
            puts "  --dry-run     report only, write nothing"
            puts "  --quiet       no per-file output"
            exit 0
        }
        default { puts stderr "Unknown option: [lindex $argv $i] (try --help)"; exit 1 }
    }
}

if {[catch {package require mdstack::indexgen} err]} {
    puts stderr "ERROR: mdstack::indexgen not found ($err)"
    puts stderr "Put mdstack/lib on the module path (TCLLIBPATH) or place this script under mdstack/tools/."
    exit 1
}

set res [mdstack::indexgen::scan $root -dryrun $dryrun -verbose $verbose]
puts "created:   [llength [dict get $res created]]"
puts "updated:   [llength [dict get $res updated]]"
puts "unchanged: [llength [dict get $res unchanged]]"
