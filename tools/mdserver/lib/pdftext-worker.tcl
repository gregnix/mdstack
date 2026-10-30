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
# through a temporary file: a failed write leaves the old entry and no open
# channel (tclutils::common::replaceFile from tclutils 0.69.0; else the same
# by hand). Up to 2026-10-30 an error in puts left cf.tmp behind.
set data [list $pdf $mt $size $pages]
if {![catch {package require tclutils::common 0.3}]} {
    ::tclutils::common::replaceFile $cf $data -encoding utf-8 -translation lf
} else {
    set tmp $cf.tmp[pid]
    set fh [open $tmp w]
    try {
        fconfigure $fh -encoding utf-8 -translation lf
        puts -nonewline $fh $data
        close $fh
    } on error {msg opts} {
        catch {close $fh}
        catch {file delete -- $tmp}
        return -options $opts $msg
    }
    file rename -force -- $tmp $cf
}
puts "ok [llength $pages][expr {$why ne "" ? " (error: $why)" : ""}]"
