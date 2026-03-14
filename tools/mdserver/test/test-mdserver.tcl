#!/usr/bin/env tclsh
# test-mdserver.tcl -- Test-Suite fuer mdserver
# ============================================================================
# Testet alle Kernprozeduren von mdserver ohne echten HTTP-Server.
# Prozeduren werden direkt definiert -- kein fragiles eval/source.
#
# Usage:
#   tclsh test-mdserver.tcl
#   tclsh test-mdserver.tcl -verbose passed
#
# Requires: mdparser 0.2, mdtheme 0.1, mdhtml 0.1
# ============================================================================

package require Tcl 8.6
package require tcltest 2.0
namespace import tcltest::*

# ============================================================
# Module laden
# ============================================================

set scriptDir [file dirname [file normalize [info script]]]

foreach candidate {
    "../lib"
    "lib"
    "../../lib"
    "../../../lib"
} {
    set d [file normalize [file join $scriptDir $candidate]]
    if {[file exists $d]} { tcl::tm::path add $d }
}

foreach {pkg ver} {mdparser 0.2 mdtheme 0.1 mdhtml 0.1} {
    if {[catch {package require $pkg $ver} err]} {
        puts stderr "FEHLER: $pkg $ver nicht verfuegbar: $err"
        exit 1
    }
}

# ============================================================
# Prozeduren aus mdserver -- direkt definiert
# ============================================================

array set cfg {
    port 8080  root .  theme hell  title mdserver
    index index.md  toc 1  log 0
}

array set mimeTypes {
    .html  "text/html; charset=utf-8"
    .htm   "text/html; charset=utf-8"
    .css   "text/css; charset=utf-8"
    .js    "application/javascript; charset=utf-8"
    .json  "application/json"
    .txt   "text/plain; charset=utf-8"
    .md    "text/plain; charset=utf-8"
    .png   "image/png"
    .jpg   "image/jpeg"
    .jpeg  "image/jpeg"
    .gif   "image/gif"
    .svg   "image/svg+xml"
    .ico   "image/x-icon"
    .pdf   "application/pdf"
}

proc urlDecode {str} {
    set str [string map {+ " "} $str]
    regsub -all {%([0-9A-Fa-f]{2})} $str {[binary format H2 \1]} str
    set str [subst $str]
    # Rohe Bytes als UTF-8 interpretieren
    return [encoding convertfrom utf-8 $str]
}

proc parseQuery {query} {
    set result {}
    foreach pair [split $query &] {
        set kv [split $pair =]
        set k [urlDecode [lindex $kv 0]]
        set v [urlDecode [lindex $kv 1]]
        if {$k ne ""} { dict set result $k $v }
    }
    return $result
}

proc safePath {root urlPath} {
    set path [file normalize [file join $root [string trimleft $urlPath /]]]
    if {![string match "${root}*" $path]} { return "" }
    return $path
}

proc readFile {path} {
    set fh [open $path r]
    fconfigure $fh -encoding utf-8
    set data [read $fh]
    close $fh
    return $data
}

proc readFileBin {path} {
    set fh [open $path rb]
    set data [read $fh]
    close $fh
    return $data
}

proc renderMarkdown {path theme toc} {
    set md [readFile $path]
    set ast [mdparser::parse $md]
    return [mdhtml::render $ast -theme $theme -toc $toc]
}

proc renderIndex {dirPath urlPath theme} {
    set mdFiles {}
    set subdirs {}
    foreach f [lsort [glob -nocomplain -directory $dirPath *.md]] {
        lappend mdFiles [file tail $f]
    }
    foreach d [lsort [glob -nocomplain -directory $dirPath -type d *]] {
        set name [file tail $d]
        if {$name ni {. ..}} { lappend subdirs $name }
    }
    set css ""
    catch {set css [mdtheme::toCSS $theme]}
    set body "<h1>Index: [mdhtml::escapeHtml $urlPath]</h1>\n"
    if {$urlPath ne "/"} {
        set parent [file dirname [string trimright $urlPath /]]
        if {$parent eq ""} { set parent "/" }
        append body "<p><a href=\"$parent\">.. (up)</a></p>\n"
    }
    if {[llength $subdirs] > 0} {
        append body "<ul class=\"dirlist\">\n"
        foreach d $subdirs {
            append body "<li><a href=\"[string trimright $urlPath /]/$d/\">$d/</a></li>\n"
        }
        append body "</ul>\n"
    }
    if {[llength $mdFiles] > 0} {
        append body "<ul class=\"filelist\">\n"
        foreach f $mdFiles {
            set ftitle $f
            catch {
                foreach line [split [readFile [file join $dirPath $f]] "\n"] {
                    set line [string trim $line]
                    if {[string match "# *" $line]} {
                        set ftitle [string range $line 2 end]; break
                    }
                }
            }
            append body "<li><a href=\"[string trimright $urlPath /]/$f\">\
[mdhtml::escapeHtml $ftitle]</a></li>\n"
        }
        append body "</ul>\n"
    }
    if {[llength $mdFiles] == 0 && [llength $subdirs] == 0} {
        append body "<p><em>No Markdown files found.</em></p>\n"
    }
    return "<!DOCTYPE html>\n<html><head><style>$css</style></head>\
<body><article>$body</article></body></html>"
}

proc sendResponse {chan status contentType body} {
    set len [string length [encoding convertto utf-8 $body]]
    puts $chan "HTTP/1.1 $status"
    puts $chan "Content-Type: $contentType"
    puts $chan "Content-Length: $len"
    puts $chan "Connection: close"
    puts $chan ""
    puts -nonewline $chan $body
}

proc send404 {chan path} {
    sendResponse $chan "404 Not Found" "text/html; charset=utf-8" \
        "<html><body><h1>404 Not Found</h1></body></html>"
}

proc send500 {chan msg} {
    sendResponse $chan "500 Internal Server Error" "text/html; charset=utf-8" \
        "<html><body><h1>500 Internal Server Error</h1></body></html>"
}

# ============================================================
# Hilfsprozeduren fuer Tests
# ============================================================

proc writeFile {path content} {
    set fh [open $path w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh $content
    close $fh
}

# ============================================================
# Test-Verzeichnis anlegen
# ============================================================

set testDir [file join [::tcltest::temporaryDirectory] mdserver_test]
file mkdir $testDir
file mkdir [file join $testDir subdir]

writeFile [file join $testDir index.md] \
    "# Startseite\n\nWillkommen.\n\n## Abschnitt\n\nText."
writeFile [file join $testDir doc.md] \
    "# Dokumentation\n\nEin **fetter** \[Link\](https://tcl.tk).\n\n| A | B |\n|---|---|\n| 1 | 2 |"
writeFile [file join $testDir plain.txt] "Nur Text."
writeFile [file join $testDir subdir/sub.md] "# Sub\n\nInhalt."
writeFile [file join $testDir style.css] "body { color: red; }"

# ============================================================
# A -- urlDecode
# ============================================================

test urlDecode-1 "Normaler String unveraendert" {
    urlDecode "/index.md"
} "/index.md"

test urlDecode-2 "Leerzeichen als %20" {
    urlDecode "/mein%20dokument.md"
} "/mein dokument.md"

test urlDecode-3 "Plus als Leerzeichen" {
    urlDecode "/mein+dokument.md"
} "/mein dokument.md"

test urlDecode-4 "Umlaut als %C3%BC" {
    urlDecode "/f%C3%BCr.md"
} "/f\u00FCr.md"

test urlDecode-5 "Mehrfach-Encoding" {
    urlDecode "/a%20b%2Fc.md"
} "/a b/c.md"

test urlDecode-6 "Leerer String" {
    urlDecode ""
} ""

# ============================================================
# B -- parseQuery
# ============================================================

test parseQuery-1 "Leerer Query-String" {
    parseQuery ""
} {}

test parseQuery-2 "Einzelner Parameter" {
    dict get [parseQuery "theme=dunkel"] theme
} "dunkel"

test parseQuery-3 "Mehrere Parameter" {
    set q [parseQuery "theme=hell&toc=1"]
    list [dict get $q theme] [dict get $q toc]
} {hell 1}

test parseQuery-4 "Parameter mit Encoding" {
    dict get [parseQuery "title=Mein%20Dokument"] title
} "Mein Dokument"

test parseQuery-5 "Zweiter Parameter erreichbar" {
    dict get [parseQuery "theme=solarized&foo=bar"] foo
} "bar"

# ============================================================
# C -- safePath
# ============================================================

test safePath-1 "Gueltige Datei im Root" {
    safePath $testDir "/index.md"
} [file join $testDir index.md]

test safePath-2 "Gueltige Datei im Unterverzeichnis" {
    safePath $testDir "/subdir/sub.md"
} [file join $testDir subdir sub.md]

test safePath-3 "Directory Traversal blockiert" {
    safePath $testDir "/../etc/passwd"
} ""

test safePath-4 "Root-URL liefert Root-Verzeichnis" {
    safePath $testDir "/"
} $testDir

test safePath-5 "Doppelter Slash kein Problem" {
    expr {[safePath $testDir "//index.md"] ne ""}
} 1

test safePath-6 "Relativer Pfad blockiert" {
    safePath $testDir "../../etc/passwd"
} ""

# ============================================================
# D -- readFile
# ============================================================

test readFile-1 "Datei lesen" {
    string trim [readFile [file join $testDir plain.txt]]
} "Nur Text."

test readFile-2 "UTF-8 Umlaute erhalten" {
    writeFile [file join $testDir utf8.md] "# Tüte\n\näöüÄÖÜß"
    string match {*äöüÄÖÜß*} [readFile [file join $testDir utf8.md]]
} 1

test readFile-3 "Nicht-existente Datei wirft Fehler" {
    catch {readFile [file join $testDir nichtda.md]}
} 1

# ============================================================
# E -- renderMarkdown
# ============================================================

test renderMarkdown-1 "DOCTYPE vorhanden" {
    string match {*<!DOCTYPE html>*} \
        [renderMarkdown [file join $testDir index.md] hell 0]
} 1

test renderMarkdown-2 "Titel aus H1 im HTML" {
    string match {*Startseite*} \
        [renderMarkdown [file join $testDir index.md] hell 0]
} 1

test renderMarkdown-3 "TOC eingefuegt bei toc=1" {
    string match {*toc*} \
        [renderMarkdown [file join $testDir index.md] hell 1]
} 1

test renderMarkdown-4 "TOC fehlt bei toc=0" {
    expr {![string match {*class="toc"*} \
        [renderMarkdown [file join $testDir index.md] hell 0]]}
} 1

test renderMarkdown-5 "Theme hell Georgia im CSS" {
    string match {*Georgia*} \
        [renderMarkdown [file join $testDir index.md] hell 0]
} 1

test renderMarkdown-6 "Theme dunkel dunkler Hintergrund" {
    string match {*1e1e2e*} \
        [renderMarkdown [file join $testDir index.md] dunkel 0]
} 1

test renderMarkdown-7 "Tabelle gerendert" {
    string match {*<table>*} \
        [renderMarkdown [file join $testDir doc.md] hell 0]
} 1

test renderMarkdown-8 "Fetter Text als strong" {
    string match {*<strong>*} \
        [renderMarkdown [file join $testDir doc.md] hell 0]
} 1

test renderMarkdown-9 "Link als href" {
    string match {*href="https://tcl.tk"*} \
        [renderMarkdown [file join $testDir doc.md] hell 0]
} 1

test renderMarkdown-10 "Unbekanntes Theme kein Crash" {
    string match {*<!DOCTYPE html>*} \
        [renderMarkdown [file join $testDir index.md] unbekannt 0]
} 1

# ============================================================
# F -- renderIndex
# ============================================================

test renderIndex-1 "Liefert HTML-Dokument" {
    string match {*<!DOCTYPE html>*} [renderIndex $testDir "/" hell]
} 1

test renderIndex-2 "Zeigt Markdown-Dateien" {
    string match {*doc.md*} [renderIndex $testDir "/" hell]
} 1

test renderIndex-3 "Zeigt Unterverzeichnisse" {
    string match {*subdir*} [renderIndex $testDir "/" hell]
} 1

test renderIndex-4 "Kein up-Link im Root" {
    expr {![string match {*(up)*} [renderIndex $testDir "/" hell]]}
} 1

test renderIndex-5 "up-Link in Unterverzeichnis" {
    string match {*(up)*} \
        [renderIndex [file join $testDir subdir] "/subdir" hell]
} 1

test renderIndex-6 "Titel aus H1 sichtbar" {
    string match {*Startseite*} [renderIndex $testDir "/" hell]
} 1

test renderIndex-7 "Leeres Verzeichnis zeigt Hinweis" {
    set emptyDir [file join $testDir empty]
    file mkdir $emptyDir
    string match {*No Markdown files found*} \
        [renderIndex $emptyDir "/empty" hell]
} 1

# ============================================================
# G -- MIME-Types
# ============================================================

test mimeType-1 "html MIME korrekt" {
    set mimeTypes(.html)
} "text/html; charset=utf-8"

test mimeType-2 "png MIME korrekt" {
    set mimeTypes(.png)
} "image/png"

test mimeType-3 "css MIME korrekt" {
    set mimeTypes(.css)
} "text/css; charset=utf-8"

test mimeType-4 "pdf MIME korrekt" {
    set mimeTypes(.pdf)
} "application/pdf"

test mimeType-5 "unbekannte Extension fehlt" {
    info exists mimeTypes(.xyz)
} 0

# ============================================================
# H -- HTTP-Response via Pipe
# ============================================================

test httpResponse-1 "sendResponse 200 Header" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    sendResponse $w "200 OK" "text/html; charset=utf-8" "<html/>"
    close $w
    string match {*HTTP/1.1 200 OK*} [read $r]
} 1

test httpResponse-2 "sendResponse Content-Type" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    sendResponse $w "200 OK" "text/html; charset=utf-8" "body"
    close $w
    string match {*text/html*} [read $r]
} 1

test httpResponse-3 "sendResponse Body vorhanden" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    sendResponse $w "200 OK" "text/plain" "Hallo Welt"
    close $w
    string match {*Hallo Welt*} [read $r]
} 1

test httpResponse-4 "send404 liefert 404" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    send404 $w "/missing.md"
    close $w
    string match {*404*} [read $r]
} 1

test httpResponse-5 "send500 liefert 500" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    send500 $w "Fehler"
    close $w
    string match {*500*} [read $r]
} 1

# ============================================================
# Aufraumen
# ============================================================

tcltest::cleanupTests
file delete -force $testDir
