#!/usr/bin/env tclsh
# test-mdserver-oo.tcl -- Test-Suite fuer mdserver-0.1.tm
# ============================================================================
# Testet mdserver::Request, mdserver::Renderer und mdserver::Server.
# Keine echte Netzwerkverbindung -- Pipes simulieren Channels.
#
# Usage:
#   tclsh test-mdserver-oo.tcl
#   tclsh test-mdserver-oo.tcl -verbose passed
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

# mdserver-0.1.tm laden
foreach _candidate {../lib lib} {
    set _d [file normalize [file join $scriptDir $_candidate]]
    if {[file exists $_d]} { tcl::tm::path add $_d }
}
# Fallback: direkt aus Parent-Verzeichnis sourcen falls kein lib/ vorhanden
set _tm [file normalize [file join $scriptDir ../mdserver-0.1.tm]]
if {[file exists $_tm]} {
    source $_tm
} elseif {[catch {package require mdserver 0.1} err]} {
    puts stderr "FEHLER: mdserver 0.1 nicht gefunden: $err"
    exit 1
}
unset -nocomplain _candidate _d _tm err

# ============================================================
# Hilfsprozeduren
# ============================================================

# Schreibt eine Datei mit UTF-8 Encoding
proc writeFile {path content} {
    set fh [open $path w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh $content
    close $fh
}

# Erzeugt einen lesbaren Channel mit HTTP-Request-Inhalt
# Gibt den Lese-Channel zurueck (Write-End schon geschlossen)
proc makeRequestChan {method path {query ""} {headers {}}} {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    set url $path
    if {$query ne ""} { append url "?$query" }
    puts $w "$method $url HTTP/1.1"
    foreach {k v} $headers {
        puts $w "$k: $v"
    }
    puts $w ""
    close $w
    fconfigure $r -translation crlf -encoding utf-8
    return $r
}

# ============================================================
# Test-Verzeichnis anlegen
# ============================================================

set testDir [file join [::tcltest::temporaryDirectory] mdserver_oo_test]
file mkdir $testDir
file mkdir [file join $testDir subdir]
file mkdir [file join $testDir empty]

writeFile [file join $testDir index.md] \
    "# Startseite\n\nWillkommen.\n\n## Abschnitt\n\nText."
writeFile [file join $testDir doc.md] \
    "# Dokumentation\n\nEin **fetter** \[Link\](https://tcl.tk).\n\n| A | B |\n|---|---|\n| 1 | 2 |"
writeFile [file join $testDir plain.txt]  "Nur Text."
writeFile [file join $testDir style.css]  "body { color: red; }"
writeFile [file join $testDir subdir/sub.md] "# Sub\n\nInhalt."
writeFile [file join $testDir utf8.md]    "# Tüte\n\näöüÄÖÜß"

# Shared Objekte fuer alle Tests
set renderer [mdserver::Renderer new "mdserver-test"]
set server   [mdserver::Server new \
    --root $testDir --log 0 --port 19999]

# Private Methoden fuer Tests freischalten
# (TclOO: _ -Methoden sind per Default nicht von aussen aufrufbar)
oo::objdefine $renderer export _readFile
oo::objdefine $server   export _safePath _mime _send _sendBin _dispatch _log

# ============================================================
# A -- mdserver::Request: URL-Decode
# ============================================================

test request-urldecode-1 "Normaler Pfad unveraendert" {
    set chan [makeRequestChan GET /index.md]
    set req [mdserver::Request new $chan]
    $req path
} "/index.md"

test request-urldecode-2 "Leerzeichen als %20" {
    set chan [makeRequestChan GET /mein%20dokument.md]
    set req [mdserver::Request new $chan]
    $req path
} "/mein dokument.md"

test request-urldecode-3 "Umlaut als %C3%BC" {
    set chan [makeRequestChan GET /f%C3%BCr.md]
    set req [mdserver::Request new $chan]
    $req path
} "/f\u00FCr.md"

# ============================================================
# B -- mdserver::Request: Parsen
# ============================================================

test request-parse-1 "Method GET erkannt" {
    set chan [makeRequestChan GET /index.md]
    set req [mdserver::Request new $chan]
    $req method
} "GET"

test request-parse-2 "Method HEAD erkannt" {
    set chan [makeRequestChan HEAD /index.md]
    set req [mdserver::Request new $chan]
    $req method
} "HEAD"

test request-parse-3 "Pfad korrekt" {
    set chan [makeRequestChan GET /subdir/sub.md]
    set req [mdserver::Request new $chan]
    $req path
} "/subdir/sub.md"

test request-parse-4 "Query-Parameter theme" {
    set chan [makeRequestChan GET /index.md "theme=dunkel"]
    set req [mdserver::Request new $chan]
    $req param theme
} "dunkel"

test request-parse-5 "Mehrere Query-Parameter" {
    set chan [makeRequestChan GET /index.md "theme=hell&toc=0"]
    set req [mdserver::Request new $chan]
    list [$req param theme] [$req param toc]
} {hell 0}

test request-parse-6 "Fehlender Parameter liefert Default" {
    set chan [makeRequestChan GET /index.md]
    set req [mdserver::Request new $chan]
    $req param theme "hell"
} "hell"

test request-parse-7 "Header Host lesbar" {
    set chan [makeRequestChan GET /index.md "" {Host localhost:8080}]
    set req [mdserver::Request new $chan]
    $req header host
} "localhost:8080"

test request-parse-8 "Fehlender Header liefert Leerstring" {
    set chan [makeRequestChan GET /index.md]
    set req [mdserver::Request new $chan]
    $req header x-nonexistent
} ""

test request-parse-9 "Ungueltiger Request wirft MDDOCS BADREQUEST" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    puts $w "KAPUTT"
    puts $w ""
    close $w
    fconfigure $r -translation crlf -encoding utf-8
    try {
        mdserver::Request new $r
        return "kein Fehler"
    } trap {MDDOCS BADREQUEST} {} {
        return "BADREQUEST"
    }
} "BADREQUEST"

# ============================================================
# C -- mdserver::Server: _safePath
# ============================================================

test safepath-1 "Gueltige Datei im Root" {
    $server _safePath /index.md
} [file join $testDir index.md]

test safepath-2 "Gueltige Datei im Unterverzeichnis" {
    $server _safePath /subdir/sub.md
} [file join $testDir subdir sub.md]

test safepath-3 "Directory Traversal wirft MDDOCS TRAVERSAL" {
    try {
        $server _safePath /../etc/passwd
        return "kein Fehler"
    } trap {MDDOCS TRAVERSAL} {} {
        return "TRAVERSAL"
    }
} "TRAVERSAL"

test safepath-4 "Root-URL liefert Root-Verzeichnis" {
    $server _safePath /
} $testDir

test safepath-5 "Relativer Pfad blockiert" {
    try {
        $server _safePath ../../etc/passwd
        return "kein Fehler"
    } trap {MDDOCS TRAVERSAL} {} {
        return "TRAVERSAL"
    }
} "TRAVERSAL"

# ============================================================
# D -- mdserver::Renderer: _readFile
# ============================================================

test readfile-1 "Datei lesen" {
    string trim [$renderer _readFile [file join $testDir plain.txt]]
} "Nur Text."

test readfile-2 "UTF-8 Umlaute erhalten" {
    string match {*äöüÄÖÜß*} \
        [$renderer _readFile [file join $testDir utf8.md]]
} 1

test readfile-3 "Nicht-existente Datei wirft Fehler" {
    catch {$renderer _readFile [file join $testDir nichtda.md]}
} 1

# ============================================================
# E -- mdserver::Renderer: markdown
# ============================================================

test render-md-1 "DOCTYPE vorhanden" {
    string match {*<!DOCTYPE html>*} \
        [$renderer markdown [file join $testDir index.md] hell 0]
} 1

test render-md-2 "Titel aus H1 im HTML" {
    string match {*Startseite*} \
        [$renderer markdown [file join $testDir index.md] hell 0]
} 1

test render-md-3 "TOC eingefuegt bei toc=1" {
    string match {*toc*} \
        [$renderer markdown [file join $testDir index.md] hell 1]
} 1

test render-md-4 "TOC fehlt bei toc=0" {
    expr {![string match {*class="toc"*} \
        [$renderer markdown [file join $testDir index.md] hell 0]]}
} 1

test render-md-5 "Theme hell Georgia im CSS" {
    string match {*Georgia*} \
        [$renderer markdown [file join $testDir index.md] hell 0]
} 1

test render-md-6 "Theme dunkel dunkler Hintergrund" {
    string match {*1e1e2e*} \
        [$renderer markdown [file join $testDir index.md] dunkel 0]
} 1

test render-md-7 "Tabelle gerendert" {
    string match {*<table>*} \
        [$renderer markdown [file join $testDir doc.md] hell 0]
} 1

test render-md-8 "Fetter Text als strong" {
    string match {*<strong>*} \
        [$renderer markdown [file join $testDir doc.md] hell 0]
} 1

test render-md-9 "Link als href" {
    string match {*href="https://tcl.tk"*} \
        [$renderer markdown [file join $testDir doc.md] hell 0]
} 1

test render-md-10 "Unbekanntes Theme kein Crash" {
    string match {*<!DOCTYPE html>*} \
        [$renderer markdown [file join $testDir index.md] unbekannt 0]
} 1

# ============================================================
# F -- mdserver::Renderer: index
# ============================================================

test render-index-1 "Liefert HTML-Dokument" {
    string match {*<!DOCTYPE html>*} [$renderer index $testDir "/" hell]
} 1

test render-index-2 "Zeigt Markdown-Dateien" {
    string match {*doc.md*} [$renderer index $testDir "/" hell]
} 1

test render-index-3 "Zeigt Unterverzeichnisse" {
    string match {*subdir*} [$renderer index $testDir "/" hell]
} 1

test render-index-4 "Kein up-Link im Root" {
    expr {![string match {*(up)*} [$renderer index $testDir "/" hell]]}
} 1

test render-index-5 "up-Link in Unterverzeichnis" {
    string match {*(up)*} \
        [$renderer index [file join $testDir subdir] "/subdir" hell]
} 1

test render-index-6 "Titel aus H1 sichtbar" {
    string match {*Startseite*} [$renderer index $testDir "/" hell]
} 1

test render-index-7 "Leeres Verzeichnis zeigt Hinweis" {
    string match {*No Markdown files found*} \
        [$renderer index [file join $testDir empty] "/empty" hell]
} 1

# ============================================================
# G -- mdserver::Server: _mime
# ============================================================

test mime-1 "html MIME korrekt" {
    $server _mime .html
} "text/html; charset=utf-8"

test mime-2 "png MIME korrekt" {
    $server _mime .png
} "image/png"

test mime-3 "css MIME korrekt" {
    $server _mime .css
} "text/css; charset=utf-8"

test mime-4 "pdf MIME korrekt" {
    $server _mime .pdf
} "application/pdf"

test mime-5 "unbekannte Extension liefert octet-stream" {
    $server _mime .xyz
} "application/octet-stream"

# ============================================================
# H -- mdserver::Server: _send / _sendBin via Pipe
# ============================================================

test send-1 "200 OK Status-Zeile" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    $server _send $w "200 OK" "text/html; charset=utf-8" "<html/>"
    close $w
    string match {*HTTP/1.1 200 OK*} [read $r]
} 1

test send-2 "Content-Type im Header" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    $server _send $w "200 OK" "text/html; charset=utf-8" "body"
    close $w
    string match {*text/html*} [read $r]
} 1

test send-3 "Body im Response" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    $server _send $w "200 OK" "text/plain" "Hallo Welt"
    close $w
    string match {*Hallo Welt*} [read $r]
} 1

test send-4 "404 Status-Zeile korrekt" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    $server _send $w "404 Not Found" "text/html; charset=utf-8" \
        "<html><body><h1>404 Not Found</h1></body></html>"
    close $w
    string match {*404*} [read $r]
} 1

test send-5 "500 Status-Zeile korrekt" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    $server _send $w "500 Internal Server Error" "text/html; charset=utf-8" \
        "<html><body><h1>500</h1></body></html>"
    close $w
    string match {*500*} [read $r]
} 1

test send-6 "Server-Header gesetzt" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    $server _send $w "200 OK" "text/plain" "ok"
    close $w
    string match {*Server: mdserver*} [read $r]
} 1

test send-7 "Content-Length korrekt" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    $server _send $w "200 OK" "text/plain" "12345"
    close $w
    string match {*Content-Length: 5*} [read $r]
} 1

# ============================================================
# I -- Integration: _dispatch via Pipe
# ============================================================

test dispatch-1 "Existierende .md liefert 200" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    set reqChan [makeRequestChan GET /index.md]
    set req [mdserver::Request new $reqChan]
    $server _dispatch $w /index.md hell 0
    close $w
    string match {*200 OK*} [read $r]
} 1

test dispatch-2 "Nicht-existente Datei liefert 404" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    set reqChan [makeRequestChan GET /nichtda.md]
    set req [mdserver::Request new $reqChan]
    $server _dispatch $w /nichtda.md hell 0
    close $w
    string match {*404*} [read $r]
} 1

test dispatch-3 "Directory Traversal liefert 403" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    set reqChan [makeRequestChan GET /../etc/passwd]
    set req [mdserver::Request new $reqChan]
    $server _dispatch $w /../etc/passwd hell 0
    close $w
    string match {*403*} [read $r]
} 1

test dispatch-4 "Verzeichnis liefert Index-HTML" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    set reqChan [makeRequestChan GET /]
    set req [mdserver::Request new $reqChan]
    $server _dispatch $w / hell 0
    close $w
    # Root hat index.md -> rendered als Markdown
    string match {*200 OK*} [read $r]
} 1

test dispatch-5 "Statische CSS-Datei liefert text/css" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    set reqChan [makeRequestChan GET /style.css]
    set req [mdserver::Request new $reqChan]
    $server _dispatch $w /style.css hell 0
    close $w
    string match {*text/css*} [read $r]
} 1

# ============================================================
# Aufraumen
# ============================================================

$renderer destroy
$server   destroy

tcltest::cleanupTests
file delete -force $testDir
