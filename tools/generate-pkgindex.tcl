#!/usr/bin/env tclsh
# tools/generate-pkgindex.tcl
#
# Generiert pkgIndex.tcl fuer ein Tcl-Module-Verzeichnis.
#
# Layout das unterstuetzt wird:
#   <dir>/foo-X.Y.tm           -> package ifneeded foo X.Y
#   <dir>/foo/bar-X.Y.tm       -> package ifneeded foo::bar X.Y
#
# Aufruf:
#   tclsh generate-pkgindex.tcl <module-dir>             # ausgeben
#   tclsh generate-pkgindex.tcl <module-dir> --write     # in pkgIndex.tcl schreiben
#
# Aufruf-Beispiele:
#   tclsh tools/generate-pkgindex.tcl lib/tm           # docir / man-viewer
#   tclsh tools/generate-pkgindex.tcl lib              # mdstack
#
# Nicht erfasst werden:
#   - .tm-Dateien tiefer als zwei Ebenen (X/Y/Z-V.tm)
#   - .tm-Dateien deren Name nicht dem Tcl-Modul-Pattern entspricht
#     (Bindestrich vor der Version, Punktversion danach)

namespace eval pkgIndexGen {

    # Erkennt einen TM-Dateinamen: <name>-<version>.tm
    # name = beliebige Buchstaben/Zahlen/Underscore (auch CamelCase)
    # version = Punkt-getrennte Zahlen (1, 0.1, 0.9.4, 0.9.4.25)
    variable tmPattern {^([A-Za-z][A-Za-z0-9_]*)-([0-9]+(?:\.[0-9]+)*)\.tm$}

    proc parseFile {basename} {
        variable tmPattern
        if {[regexp $tmPattern $basename -> name version]} {
            return [list $name $version]
        }
        return ""
    }

    proc generate {dir} {
        set dir [file normalize $dir]
        set lines [list \
            "# pkgIndex.tcl -- automatisch generiert von tools/generate-pkgindex.tcl" \
            "# Bei aenderungen oder neuen Modulen einfach neu generieren." \
            "" \
        ]
        set count 0

        # Ebene 0: direkt im Verzeichnis  -> package require <name>
        foreach tm [lsort [glob -nocomplain -directory $dir -tails *.tm]] {
            set parsed [parseFile $tm]
            if {$parsed eq ""} continue
            lassign $parsed name version
            lappend lines [format \
                "package ifneeded %-32s %-8s \[list source -encoding utf-8 \[file join \$dir %s\]\]" \
                $name $version $tm]
            incr count
        }

        # Ebene 1: in Sub-Verzeichnis  -> package require <subdir>::<name>
        foreach subdir [lsort [glob -nocomplain -directory $dir -type d -tails *]] {
            set subPath [file join $dir $subdir]
            foreach tm [lsort [glob -nocomplain -directory $subPath -tails *.tm]] {
                set parsed [parseFile $tm]
                if {$parsed eq ""} continue
                lassign $parsed name version
                set fullName "${subdir}::${name}"
                lappend lines [format \
                    "package ifneeded %-32s %-8s \[list source -encoding utf-8 \[file join \$dir %s %s\]\]" \
                    $fullName $version $subdir $tm]
                incr count
            }
        }

        if {$count == 0} {
            return -code error "Keine .tm-Module in $dir gefunden"
        }
        lappend lines ""
        return [join $lines "\n"]
    }
}

# --- main ---
if {$argc < 1} {
    puts stderr "Aufruf: tclsh generate-pkgindex.tcl <module-dir> ?--write?"
    exit 1
}
set dir [lindex $argv 0]
set write [expr {"--write" in $argv}]

if {![file isdirectory $dir]} {
    puts stderr "Verzeichnis nicht gefunden: $dir"
    exit 1
}

set content [pkgIndexGen::generate $dir]

if {$write} {
    set out [file join $dir pkgIndex.tcl]
    set fh [open $out w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh $content
    close $fh
    puts "Geschrieben: $out"
} else {
    puts $content
}
