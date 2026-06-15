# mdpdf-0.2.tm -- Markdown AST zu PDF Renderer
#
# CUTOVER 2026-05-06: Adapter zur DocIR-Pipeline.
#
# Diese Datei ist das Ergebnis der mdpdf-Konsolidierung in
# docir-pdf (Phase 3 Sessions 1-4). Public API bleibt
# rueckwaertskompatibel - Aufrufer (mdhelp, demos, tests)
# brauchen keine Anpassung. Intern wird die DocIR-Pipeline
# verwendet:
#
#   mdparser-AST -> docir-md::fromAst -> docir-pdf::render
#
# Optionen wurden auf docir-pdf-Optionen gemappt:
#   -title         -> title          (1:1)
#   -pagesize      -> paper           (A4 -> a4 lowercase)
#   -margin        -> margin          (1:1)
#   -fontsize      -> fontSize        (rename camelCase)
#   -header        -> header          (1:1, %p substitution)
#   -footer        -> footer          (1:1, %p substitution)
#   -theme         -> theme           (1:1, mdstack::theme::toPdfOpts)
#   -fontdir       -> ignoriert       (TTF-Pfade nun explizit)
#   -creator       -> author          (mappt auf author-meta)
#   -toc           -> IGNORIERT       (kein TOC in docir-pdf - siehe NICHT-PORTIERT)
#   -compress      -> IGNORIERT       (pdf4tcl-Default)
#   -pdfa          -> IGNORIERT       (siehe NICHT-PORTIERT)
#   -userpassword  -> IGNORIERT       (siehe NICHT-PORTIERT)
#   -ownerpassword -> IGNORIERT       (siehe NICHT-PORTIERT)
#   -debug         -> IGNORIERT       (Diagnostics nicht in docir-pdf-API)
#   -root          -> ignoriert       (Image-Resolution-Root, evtl. Phase 4)
#   -cid           -> cid             (1 = volles Unicode-Subset/CID statt 256-Enc)
#
# NICHT PORTIERT (bewusst, vom Repo-Owner so entschieden):
#   - PDF/A-Compliance
#   - AES-128 Encryption (User/Owner-Passwords)
#   - TOC-Generation (mdpdf hatte automatische TOC mit Outlines)
#
# Wenn diese Features benoetigt werden, kann mdpdf-0.2.tm.legacy
# (das Original) reaktiviert werden.
#
# Public API:
#   mdstack::pdf::configure  ?-key val ...?    setzt Defaults
#   mdstack::pdf::export      ast outFile ?options?
#   mdstack::pdf::exportFile  mdFile outFile ?options?
#   mdstack::pdf::exportModel doc outFile ?options?

package provide mdstack::pdf 0.2

# DocIR-Pipeline laden ueber das Standard Tcl Module System.
# Der Aufrufer muss einen tcl::tm::path konfiguriert haben, in dem
# docir-0.1.tm (Hub) und docir/pdf-0.1.tm + docir/mdSource-0.1.tm
# auffindbar sind.
package require docir::mdSource
package require docir::pdf

namespace eval mdstack::pdf {
    namespace export export exportFile exportModel configure

    variable imgCounter
    set imgCounter 0

    variable config
    array set config {
        title         ""
        pagesize      A4
        margin        50
        fontsize      11
        toc           0
        header        ""
        footer        "- %p -"
        root          ""
        fontdir       ""
        creator       ""
        debug         0
        compress      1
        pdfa          ""
        userpassword  ""
        ownerpassword ""
        theme         ""
        cid           0
    }
}

proc mdstack::pdf::configure {args} {
    variable config
    foreach {opt val} $args {
        set key [string trimleft $opt -]
        if {[info exists config($key)]} {
            set config($key) $val
        }
    }
    return
}

proc mdstack::pdf::export {ast outputFile args} {
    variable config

    array set opts [array get config]
    foreach {key val} $args {
        set k [string trimleft $key -]
        if {[info exists config($k)]} {
            set opts($k) $val
        }
    }

    set ir [::docir::md::fromAst $ast]
    set docirOpts [_mapOptions [array get opts]]
    ::docir::pdf::render $ir $outputFile $docirOpts

    return 1
}

proc mdstack::pdf::exportFile {mdFile outputFile args} {
    if {![file exists $mdFile]} {
        error "File not found: $mdFile"
    }
    if {[catch {package require pdf4tcllib} err]} {
        error "pdf4tcllib not available: $err"
    }
    set markdown [::pdf4tcllib::unicode::readFile $mdFile]
    if {[catch {package require mdstack::parser} err]} {
        error "mdstack::parser not available: $err"
    }
    set ast [mdstack::parser::parse $markdown]
    return [mdstack::pdf::export $ast $outputFile {*}$args]
}

proc mdstack::pdf::exportModel {doc outputFile args} {
    if {[dict exists $doc ast]} {
        set ast [dict get $doc ast]
    } else {
        error "Model enthaelt kein AST"
    }
    return [mdstack::pdf::export $ast $outputFile {*}$args]
}

proc mdstack::pdf::_mapOptions {optsList} {
    array set opts $optsList
    set d [dict create]

    if {$opts(title) ne ""}    { dict set d title    $opts(title) }
    if {$opts(creator) ne ""}  { dict set d author   $opts(creator) }
    if {$opts(margin) ne ""}   { dict set d margin   $opts(margin) }
    if {$opts(fontsize) ne ""} { dict set d fontSize $opts(fontsize) }
    if {$opts(header) ne ""}   { dict set d header   $opts(header) }
    if {$opts(footer) ne ""}   { dict set d footer   $opts(footer) }
    if {$opts(theme) ne ""}    { dict set d theme    $opts(theme) }
    if {$opts(root) ne ""}     { dict set d root     $opts(root) }

    if {$opts(cid)} { dict set d cid 1 }

    if {$opts(pagesize) ne ""} {
        dict set d paper [string tolower $opts(pagesize)]
    }

    return $d
}
