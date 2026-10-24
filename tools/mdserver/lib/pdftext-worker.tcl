# pdftext-worker.tcl -- reads the text of one PDF for mdserver's search.
#
# mdserver starts it once per PDF through tclutils::tutask (pipe), so the
# reading never holds up the server's event loop:
#
#   tclsh pdftext-worker.tcl PDF MTIME SIZE CACHEFILE TMPATHS
#
# TMPATHS is the server's module path (a Tcl list), so the worker finds the
# same tclutils. Writes [list PDF MTIME SIZE PAGES] to CACHEFILE (through a
# .tmp file and rename) and prints "ok N" with the number of pages. A PDF
# without text (scan, encrypted, damaged) is cached with no pages; when the
# reader failed, the line is "ok 0 (error: MESSAGE)", so the server can log
# why (review 2026-10-24, S01: a parser error looked like an empty PDF).
# Exit 1 when tclutils::tupdftext does not load.

lassign $argv pdf mt size cf tmPaths
foreach d [lreverse $tmPaths] { catch {tcl::tm::path add $d} }
if {[catch {package require tclutils::tupdftext 0.1} err]} {
    puts "tclutils::tupdftext not found: $err"
    exit 1
}
set why ""
if {[catch {::tclutils::tupdftext::pages $pdf} pages]} {
    set why [string map {\n " "} $pages]
    set pages {}
}
file mkdir [file dirname $cf]
set fh [open $cf.tmp w]
fconfigure $fh -encoding utf-8
puts -nonewline $fh [list $pdf $mt $size $pages]
close $fh
file rename -force $cf.tmp $cf
puts "ok [llength $pages][expr {$why ne "" ? " (error: $why)" : ""}]"
