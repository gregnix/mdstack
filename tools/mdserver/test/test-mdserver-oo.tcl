#!/usr/bin/env tclsh
# test-mdserver-oo.tcl -- Test-Suite fuer mdserver-0.4.tm
# ============================================================================
# Testet mdserver::Request, mdserver::Renderer und mdserver::Server.
# Keine echte Netzwerkverbindung -- Pipes simulieren Channels.
#
# Usage:
#   tclsh test-mdserver-oo.tcl
#   tclsh test-mdserver-oo.tcl -verbose passed
# ============================================================================

package require Tcl 8.6-
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

foreach {pkg ver} {mdstack::parser 0.2 mdstack::theme 0.1 mdstack::html 0.1} {
    if {[catch {package require $pkg $ver} err]} {
        puts stderr "FEHLER: $pkg $ver nicht verfuegbar: $err"
        exit 1
    }
}

# mdserver-0.4.tm laden
foreach _candidate {../lib lib} {
    set _d [file normalize [file join $scriptDir $_candidate]]
    if {[file exists $_d]} { tcl::tm::path add $_d }
}
if {[catch {package require mdserver 0.4} err]} {
    puts stderr "FEHLER: mdserver 0.4 nicht gefunden: $err"
    exit 1
}
unset -nocomplain _candidate _d err

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

test render-md-11 "Themes unterscheiden sich tatsaechlich" {
    set a [$renderer markdown [file join $testDir index.md] hell 0]
    set b [$renderer markdown [file join $testDir index.md] dunkel 0]
    expr {$a ne $b}
} 1

test render-md-12 "Theme-CSS steht nach dem Default-CSS (gewinnt in der Kaskade)" {
    set html [$renderer markdown [file join $testDir index.md] dunkel 0]
    expr {[string last "1e1e2e" $html] > [string first "-apple-system" $html]}
} 1

test render-md-13 "Style-Datei steht nach dem Theme-CSS" {
    set css [file join $testDir style.css]
    set html [$renderer markdown [file join $testDir index.md] dunkel 0 $css]
    expr {[string first "color: red" $html] > [string last "1e1e2e" $html]}
} 1

test render-md-7 "Tabelle gerendert" {
    string match {*<table*} \
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
    string match {*href="../"*} \
        [$renderer index [file join $testDir subdir] "/subdir" hell]
} 1

test render-index-6 "Titel aus H1 sichtbar" {
    string match {*Startseite*} [$renderer index $testDir "/" hell]
} 1

test render-index-7 "Leeres Verzeichnis: nur der up-Link, keine Eintraege" {
    set html [$renderer index [file join $testDir empty] "/empty" hell]
    list [string match {*href="../"*} $html] [regexp -all {\.md"} $html]
} {1 0}

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
    $server _dispatch $w $req /index.md hell 0
    close $w
    string match {*200 OK*} [read $r]
} 1

test dispatch-2 "Nicht-existente Datei liefert 404" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    set reqChan [makeRequestChan GET /nichtda.md]
    set req [mdserver::Request new $reqChan]
    $server _dispatch $w $req /nichtda.md hell 0
    close $w
    string match {*404*} [read $r]
} 1

test dispatch-3 "Directory Traversal liefert 403" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    set reqChan [makeRequestChan GET /../etc/passwd]
    set req [mdserver::Request new $reqChan]
    $server _dispatch $w $req /../etc/passwd hell 0
    close $w
    string match {*403*} [read $r]
} 1

test dispatch-4 "Verzeichnis liefert Index-HTML" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    set reqChan [makeRequestChan GET /]
    set req [mdserver::Request new $reqChan]
    $server _dispatch $w $req / hell 0
    close $w
    # Root hat index.md -> rendered als Markdown
    string match {*200 OK*} [read $r]
} 1

test dispatch-5 "Statische CSS-Datei liefert text/css" {
    lassign [chan pipe] r w
    fconfigure $w -translation crlf -encoding utf-8 -buffering full
    set reqChan [makeRequestChan GET /style.css]
    set req [mdserver::Request new $reqChan]
    $server _dispatch $w $req /style.css hell 0
    close $w
    string match {*text/css*} [read $r]
} 1

# ============================================================
# F -- Navi-Leiste: Sektionen und Ueberlauf-Dropdown
# ============================================================

# Eigene Wurzel mit vielen Sektionen (mehr als navmax)
set navDir [file join [::tcltest::temporaryDirectory] mdserver_nav_test]
file delete -force $navDir
file mkdir $navDir
writeFile [file join $navDir index.md] "# Start"
foreach _s {A B C D E F G H} {
    file mkdir [file join $navDir $_s]
    writeFile [file join $navDir $_s index.md] "# Sektion $_s"
}
unset -nocomplain _s

# Server mit eigener Wurzel; private Nav-Methoden freischalten
proc navServer {args} {
    set srv [mdserver::Server new --root $::navDir --log 0 --port 19998 {*}$args]
    oo::objdefine $srv export _injectNav _sectionLinks
    return $srv
}

test nav-1 "Alle Top-Level-Sektionen erkannt" {
    set srv [navServer]
    set n [llength [$srv _sectionLinks]]
    $srv destroy
    set n
} 8

test nav-2 "Mehr Sektionen als navmax -> ein Dropdown statt vieler Links" {
    set srv [navServer]
    set html [$srv _injectNav "<html><body></body></html>"]
    $srv destroy
    list [string match {*<details class="mdserver-navmore">*} $html] \
         [regexp -all {<div class="mdserver-navmore-items">} $html]
} {1 1}

test nav-3 "Dropdown enthaelt alle Sektionen" {
    set srv [navServer]
    set html [$srv _injectNav "<html><body></body></html>"]
    $srv destroy
    regexp -all {href="/[A-H]/"} $html
} 8

test nav-4 "navmax 0 -> alle Sektionen inline, kein Dropdown" {
    set srv [navServer --navmax 0]
    set html [$srv _injectNav "<html><body></body></html>"]
    $srv destroy
    list [string match {*<details*} $html] [regexp -all {href="/[A-H]/"} $html]
} {0 8}

test nav-5 "Weniger Sektionen als navmax -> inline" {
    set srv [navServer --navmax 20]
    set html [$srv _injectNav "<html><body></body></html>"]
    $srv destroy
    string match {*<details*} $html
} 0

test nav-6 "Leiste umbricht, Links selbst brechen nicht" {
    set srv [navServer]
    set html [$srv _injectNav "<html><body></body></html>"]
    $srv destroy
    list [string match {*flex-wrap:wrap*} $html] [string match {*white-space:nowrap*} $html]
} {1 1}

test nav-7 "nav 0 -> keine Leiste" {
    set srv [navServer --nav 0]
    set html [$srv _injectNav "<html><body>X</body></html>"]
    $srv destroy
    string match {*mdserver-nav*} $html
} 0

test nav-8 "Leiste steht vor dem Inhalt" {
    set srv [navServer]
    set html [$srv _injectNav "<html><body>INHALT</body></html>"]
    $srv destroy
    expr {[string first "mdserver-nav" $html] < [string first "INHALT" $html]}
} 1

# ============================================================
# --bind: an welche Adresse der HTTP-Port geht (0.3.1)
# ============================================================
#
# Bis 0.3.1 horchte der HTTP-Port immer auf allen Schnittstellen; nur der
# Steuerport hatte ein -myaddr. Steht ein nginx mit auth_basic davor, ist der
# Port damit von aussen offen UND unangemeldet -- die Anmeldung haengt dann
# allein an der Firewall.
#
# Hier wird wirklich gebunden und wirklich verbunden, nicht nur die
# Einstellung abgefragt: die Frage ist, was das Betriebssystem tut.

proc freierPort {} {
    set s [socket -server {} 0]
    set p [lindex [fconfigure $s -sockname] 2]
    close $s
    return $p
}
proc lanAdresse {} {
    # irgendeine Adresse dieses Rechners, die nicht loopback ist
    if {[catch {exec hostname -I} out]} { return {} }
    foreach a $out { if {![string match "127.*" $a] && [string match "*.*" $a]} { return $a } }
    return {}
}
proc erreichbar {adresse port} {
    if {[catch {socket $adresse $port} s]} { return 0 }
    close $s
    return 1
}

test bind-1 "ohne --bind horcht der Port auf allen Schnittstellen" -setup {
    set p [freierPort]
    set srv [mdserver::Server new -root $testDir -port $p -log 0]
    $srv start
} -body {
    set lan [lanAdresse]
    if {$lan eq ""} { set ergebnis {kein LAN} } else { set ergebnis [erreichbar $lan $p] }
    list [erreichbar 127.0.0.1 $p] $ergebnis
} -cleanup {
    $srv destroy
} -result {1 1}

test bind-2 "--bind 127.0.0.1 haelt den Port auf localhost" -setup {
    set p [freierPort]
    set srv [mdserver::Server new -root $testDir -port $p -bind 127.0.0.1 -log 0]
    $srv start
} -body {
    set lan [lanAdresse]
    if {$lan eq ""} { set ergebnis 0 } else { set ergebnis [erreichbar $lan $p] }
    list [erreichbar 127.0.0.1 $p] $ergebnis
} -cleanup {
    $srv destroy
} -result {1 0}

test bind-3 "eine Adresse, die es hier nicht gibt, bricht mit Angabe ab" -body {
    set p [freierPort]
    set srv [mdserver::Server new -root $testDir -port $p -bind 10.99.99.99 -log 0]
    set meldung {}
    if {[catch {$srv start} meldung]} { catch {$srv destroy} } else { $srv destroy }
    expr {[string match "*10.99.99.99*" $meldung] ? 1 : "keine Angabe der Adresse: $meldung"}
} -result 1

# ============================================================
# Wurzel, Punkt-Dateien, Methoden, Server-Kopf (0.3.1)
# ============================================================
#
# Fuenf Befunde vom 28.09.2026, alle an einem Wurzelverzeichnis mit Fallen
# gemessen. Die Tests binden und verbinden wirklich -- die Frage ist, was der
# Server antwortet, nicht was im Dict steht.
#
# Der Server laeuft dafuer als eigener Prozess. Im selben Interpreter geht es
# nicht: ein blockierendes [read] auf dem Socket haelt genau die Ereignis-
# schleife an, die der Server braucht, um zu antworten. Der erste Anlauf lief
# darum in eine Verklemmung und wurde nach zwei Minuten abgebrochen.

proc fallenWurzel {} {
    set d [file join [tcltest::configure -tmpdir] mdfallen[pid]]
    file delete -force $d
    file mkdir $d/unterordner $d/.git
    writeFile $d/index.md "# Start\n"
    writeFile $d/unterordner/seite.md "# Unten\n"
    writeFile $d/.git/HEAD "ref: refs/heads/main\n"
    # was draussen liegt, liegt in einem eigenen Ordner neben der Wurzel --
    # sonst bleibt die Datei nach dem Lauf liegen und tcltest meldet sie
    file mkdir $d.draussen
    writeFile $d.draussen/geheim.txt "GEHEIM\n"
    # ein Verweis, der hinausfuehrt, und einer, der drinnen bleibt
    catch {file link -symbolic $d/hinaus.txt [file normalize $d.draussen/geheim.txt]}
    catch {file link -symbolic $d/innen.md unterordner/seite.md}
    return $d
}
proc fallenWeg {d} { file delete -force $d $d.draussen }
proc serverStart {wurzel args} {
    set port    [freierPort]
    set skript  [file normalize [file join [file dirname [info script]] .. mdserver.tcl]]
    set protokoll [file join [tcltest::configure -tmpdir] mdlog[pid]-$port.txt]
    set pid [exec [info nameofexecutable] $skript --root $wurzel --port $port \
        --bind 127.0.0.1 {*}$args > $protokoll 2>@1 &]
    # warten, bis er wirklich horcht -- hoechstens zehn Sekunden
    set da 0
    for {set i 0} {$i < 100} {incr i} {
        if {![catch {socket 127.0.0.1 $port} s]} { close $s; set da 1; break }
        after 100
    }
    if {!$da} {
        catch {exec kill -9 $pid}
        set t ""; catch { set h [open $protokoll r]; set t [read $h]; close $h }
        error "der Server kam nicht hoch auf Port $port: $t"
    }
    return [list $pid $port $protokoll]
}
# Ohne --bind: fuer start-1, wo genau das der Unterschied ist.
proc serverStartOhneBind {wurzel args} {
    set port    [freierPort]
    set skript  [file normalize [file join [file dirname [info script]] .. mdserver.tcl]]
    set protokoll [file join [tcltest::configure -tmpdir] mdlog[pid]-$port.txt]
    set pid [exec [info nameofexecutable] $skript --root $wurzel --port $port \
        {*}$args > $protokoll 2>@1 &]
    for {set i 0} {$i < 100} {incr i} {
        if {![catch {socket 127.0.0.1 $port} s]} { close $s; break }
        after 100
    }
    return [list $pid $port $protokoll]
}
proc koerper {antwort} {
    set i [string first "\r\n\r\n" $antwort]
    if {$i < 0} { return "" }
    return [string range $antwort [expr {$i + 4}] end]
}
proc serverStop {h} {
    lassign $h pid port protokoll
    catch {exec kill $pid}
    after 200
    catch {exec kill -9 $pid}
    catch {file delete -force $protokoll}
}
proc serverPort {h} { lindex $h 1 }
proc serverLog {h} {
    set t ""
    catch { set fh [open [lindex $h 2] r]; fconfigure $fh -encoding utf-8; set t [read $fh]; close $fh }
    return $t
}
proc holen {port pfad {kopf {}}} {
    set s [socket 127.0.0.1 $port]
    fconfigure $s -translation crlf
    puts $s "GET $pfad HTTP/1.0"
    puts $s "Host: 127.0.0.1"
    foreach {n w} $kopf { puts $s "$n: $w" }
    puts $s ""
    flush $s
    fconfigure $s -translation binary
    set antwort [read $s]
    close $s
    return $antwort
}
proc mitMethode {port methode pfad} {
    set s [socket 127.0.0.1 $port]
    fconfigure $s -translation crlf
    puts $s "$methode $pfad HTTP/1.0"
    puts $s "Host: 127.0.0.1"
    puts $s ""
    flush $s
    fconfigure $s -translation binary
    set antwort [read $s]
    close $s
    return $antwort
}
proc status {antwort} {
    if {[regexp {^HTTP/1\.1 (\d+)} $antwort -> c]} { return $c }
    return ""
}

test wurzel-1 "ein Symlink fuehrt nicht aus der Wurzel heraus" -setup {
    set w [fallenWurzel]
    set h [serverStart $w --no-log]
    set p [serverPort $h]
} -body {
    # drinnen: geliefert. hinaus: gesperrt. Punkt-Ordner: gesperrt.
    list [status [holen $p /unterordner/seite.md]] \
         [status [holen $p /innen.md]] \
         [status [holen $p /hinaus.txt]] \
         [status [holen $p /.git/HEAD]]
} -cleanup {
    serverStop $h
    fallenWeg $w
} -result {200 200 403 403}

test wurzel-2 "--dotfiles 1 liefert Punkt-Dateien, Verweise bleiben gesperrt" -setup {
    set w [fallenWurzel]
    set h [serverStart $w --no-log --dotfiles 1]
    set p [serverPort $h]
} -body {
    list [status [holen $p /.git/HEAD]] [status [holen $p /hinaus.txt]]
} -cleanup {
    serverStop $h
    fallenWeg $w
} -result {200 403}

test wurzel-3 "die Wurzel wird bis zum Trennzeichen verglichen" -body {
    # /srv/md darf nicht auf /srv/mdxyz passen
    set srv [mdserver::Server new -root $testDir -log 0]
    oo::objdefine $srv export _unterhalb
    set r [list [$srv _unterhalb /srv/md /srv/md/a.md] \
                [$srv _unterhalb /srv/md /srv/mdxyz/a.md] \
                [$srv _unterhalb /srv/md /srv/md]]
    $srv destroy
    set r
} -result {1 0 1}

test methode-1 "POST bekommt 405 mit Allow, nicht Schweigen" -setup {
    set h [serverStart $testDir --no-log]
    set p [serverPort $h]
} -body {
    set a [mitMethode $p POST /index.md]
    list [status $a] [expr {[string match "*Allow: GET, HEAD*" $a] ? 1 : "kein Allow"}]
} -cleanup {
    serverStop $h
} -result {405 1}

test methode-2 "unsinnige Anfragezeile bleibt ohne Antwort" -setup {
    set h [serverStart $testDir --no-log]
    set p [serverPort $h]
} -body {
    # kein HTTP: dafuer gibt es keine sinnvolle Antwort, und 405 waere falsch
    set s [socket 127.0.0.1 $p]
    fconfigure $s -translation crlf
    puts $s "QUATSCH"
    puts $s ""
    flush $s
    fconfigure $s -translation binary
    set a [read $s]
    close $s
    string length $a
} -cleanup {
    serverStop $h
} -result 0

test serverkopf-1 "der Server-Kopf nennt die Paketfassung" -setup {
    set h [serverStart $testDir --no-log]
    set p [serverPort $h]
} -body {
    set a [holen $p /index.md]
    expr {[string match "*Server: mdserver/[package provide mdserver]*" $a]
            ? 1 : "falscher Kopf in: [lindex [split $a \n] 0]..."}
} -cleanup {
    serverStop $h
} -result 1

test log-1 "das Protokoll nennt Methode und Pfad" -setup {
    set h [serverStart $testDir]
    set p [serverPort $h]
} -body {
    holen $p /subdir/sub.md
    after 300
    set t [serverLog $h]
    expr {[string match "*GET /subdir/sub.md*" $t] ? 1 : "fehlt in: $t"}
} -cleanup {
    serverStop $h
} -result 1

# ============================================================
# HEAD ohne Koerper, X-Forwarded-For nur vom vertrauten Proxy (0.3.2)
# ============================================================
#
# Zwei Reparaturen an dem, was 0.3.1 geliefert hat. Beides wurde erst durch
# eine Durchsicht gefunden, nicht durch die Tests -- die Tests dafuer gibt es
# jetzt.
#
# 1. 0.3.1 schrieb "Allow: GET, HEAD" in jede 405 und beantwortete HEAD mit
#    200 -- MIT Koerper. Nach RFC 9110 9.3.2 ist die Antwort auf HEAD
#    dieselbe wie auf GET, nur ohne Koerper; Content-Length bleibt die
#    Laenge, die ein GET geliefert haette.
# 2. 0.3.1 glaubte X-Forwarded-For ungeprueft. Anhaengen kann den Kopf jeder,
#    der den Port erreicht -- gemessen mit einem direkten curl, ohne Proxy.

proc kopfteil {antwort} {
    set i [string first "\r\n\r\n" $antwort]
    if {$i < 0} { return $antwort }
    return [string range $antwort 0 $i]
}
proc koerperlaenge {antwort} {
    set i [string first "\r\n\r\n" $antwort]
    if {$i < 0} { return 0 }
    return [string length [string range $antwort [expr {$i + 4}] end]]
}
proc kopfwert {antwort name} {
    foreach z [split [kopfteil $antwort] "\n"] {
        set z [string trim $z]
        if {[string match -nocase "$name:*" $z]} {
            return [string trim [string range $z [expr {[string length $name] + 1}] end]]
        }
    }
    return ""
}

# Dieser Test steht hier, weil beim Bauen von 0.3.2 ein Anfuehrungszeichen zu
# viel in eine puts-Zeile des Hilfetextes geriet. Der Fehler war erst zu sehen,
# wenn jemand --help aufruft -- die 80 anderen Tests blieben gruen, weil keiner
# das Startskript als Programm ausfuehrt. Gefunden hat ihn das Nachmessen von
# Hand, nicht die Suite. Jetzt die Suite.
test hilfe-1 "--help laeuft durch und nennt jede Option" -body {
    set skript [file normalize [file join [file dirname [info script]] .. mdserver.tcl]]
    set rc [catch {exec [info nameofexecutable] $skript --help} ausgabe]
    set fehlt {}
    foreach o {--port --bind --dotfiles --trusted-proxy --root --theme --no-log
               --cert --key --tlsport --control --style --navmax
               --maxline --maxheader --healthpath} {
        if {![string match "*$o*" $ausgabe]} { lappend fehlt $o }
    }
    list [expr {$rc == 0 ? 0 : "--help brach ab: $ausgabe"}] $fehlt
} -result {0 {}}

test head-1 "HEAD liefert den Kopf von GET, aber keinen Koerper" -setup {
    set h [serverStart $testDir --no-log]
    set p [serverPort $h]
} -body {
    set g [holen $p /index.md]
    set k [mitMethode $p HEAD /index.md]
    # gleicher Status, gleiches Content-Length -- nur der Koerper fehlt
    list [status $k] \
         [expr {[kopfwert $k Content-Length] eq [kopfwert $g Content-Length]}] \
         [expr {[kopfwert $g Content-Length] eq [koerperlaenge $g]}] \
         [koerperlaenge $k]
} -cleanup {
    serverStop $h
} -result {200 1 1 0}

test head-2 "auch statische Datei, 206 und 404 bleiben ohne Koerper" -setup {
    set h [serverStart $testDir --no-log]
    set p [serverPort $h]
} -body {
    set datei [mitMethode $p HEAD /plain.txt]
    set fehlt [mitMethode $p HEAD /gibtsnicht.md]
    # 206: ein Bereich, der wirklich kuerzer ist als die Datei
    set s [socket 127.0.0.1 $p]
    fconfigure $s -translation crlf
    puts $s "HEAD /plain.txt HTTP/1.0"
    puts $s "Host: 127.0.0.1"
    puts $s "Range: bytes=0-3"
    puts $s ""
    flush $s
    fconfigure $s -translation binary
    set teil [read $s]
    close $s
    list [status $datei] [koerperlaenge $datei] \
         [status $fehlt] [koerperlaenge $fehlt] \
         [status $teil]  [koerperlaenge $teil] [kopfwert $teil Content-Length]
} -cleanup {
    serverStop $h
} -result {200 0 404 0 206 0 4}

test xff-1 "ohne --trusted-proxy wird X-Forwarded-For nicht geglaubt" -setup {
    set h [serverStart $testDir]
    set p [serverPort $h]
} -body {
    holen $p /index.md {X-Forwarded-For 9.9.9.9}
    after 300
    set t [serverLog $h]
    expr {[string match "*9.9.9.9*" $t]
            ? "die gefaelschte Adresse steht im Protokoll" : 1}
} -cleanup {
    serverStop $h
} -result 1

test xff-2 "eine Gegenstelle, die nicht in der Liste steht, wird nicht geglaubt" -setup {
    # die Anfrage kommt von 127.0.0.1, vertraut wird nur 10.0.0.5
    set h [serverStart $testDir --trusted-proxy 10.0.0.5]
    set p [serverPort $h]
} -body {
    holen $p /index.md {X-Forwarded-For 9.9.9.9}
    after 300
    set t [serverLog $h]
    expr {[string match "*9.9.9.9*" $t]
            ? "die gefaelschte Adresse steht im Protokoll" : 1}
} -cleanup {
    serverStop $h
} -result 1

# xff-3 ist gegen 0.3.1 gruen -- 0.3.1 glaubt dem Kopf ohnehin immer. Die
# Waechter gegen die alte Fassung sind xff-1 und xff-2; xff-3 haelt fest, dass
# der erlaubte Fall weiterhin funktioniert.
test xff-3 "vom vertrauten Proxy zaehlt der erste Eintrag" -setup {
    set h [serverStart $testDir --trusted-proxy 127.0.0.1]
    set p [serverPort $h]
} -body {
    holen $p /index.md {X-Forwarded-For {192.168.17.42, 10.0.0.1}}
    after 300
    set t [serverLog $h]
    list [expr {[string match "*192.168.17.42 GET /index.md*" $t] ? 1 : "fehlt in: $t"}] \
         [expr {[string match "*10.0.0.1*" $t] ? "der zweite Eintrag steht im Protokoll" : 1}]
} -cleanup {
    serverStop $h
} -result {1 1}

# ============================================================
# If-Range (0.3.3)
# ============================================================
#
# Bis 0.3.2 wurde der Kopf nicht gelesen. Gemessen an einer Datei, die sich
# zwischen zwei Anfragen aenderte:
#
#   Last-Modified vorher  22:58:19
#   Datei neu geschrieben
#   GET  Range: bytes=0-99  If-Range: <22:58:19>
#   -> 206, Content-Range: bytes 0-99/20000, Last-Modified: 22:58:44
#
# Also ein Stueck der NEUEN Datei, im Content-Range als Teil der alten
# ausgegeben. Ein Viewer, der eine grosse PDF stueckweise holt, klebt daraus
# zwei Fassungen zusammen. Richtig ist 200 mit dem ganzen neuen Inhalt
# (RFC 9110 13.1.5).
#
# Die mtime wird hier gesetzt statt abgewartet -- sonst haengt der Test an
# der Uhr.

proc mitZeit {pfad sekunden} { file mtime $pfad $sekunden }

test ifrange-1 "passender Validator liefert den Bereich, ein alter die ganze Datei" -setup {
    set f [file join $testDir ir.bin]
    writeFile $f [string repeat x 5000]
    mitZeit $f 1700000000
    set h [serverStart $testDir --no-log]
    set p [serverPort $h]
} -body {
    set gueltig [kopfwert [mitMethode $p HEAD /ir.bin] Last-Modified]
    set passt [holen $p /ir.bin [list Range bytes=0-99 If-Range $gueltig]]
    # dieselbe Datei, neuer Stand -- der alte Validator passt nicht mehr
    mitZeit $f 1700000500
    set alt [holen $p /ir.bin [list Range bytes=0-99 If-Range $gueltig]]
    list [status $passt] [kopfwert $passt Content-Range] \
         [status $alt]   [kopfwert $alt Content-Range] [kopfwert $alt Content-Length]
} -cleanup {
    serverStop $h
    file delete -force $f
} -result {206 {bytes 0-99/5000} 200 {} 5000}

test ifrange-2 "ETag-Form, Unsinn und If-Range ohne Range fuehren nie zu 206" -setup {
    set f [file join $testDir ir2.bin]
    writeFile $f [string repeat y 5000]
    mitZeit $f 1700000000
    set h [serverStart $testDir --no-log]
    set p [serverPort $h]
} -body {
    # mdserver setzt keine ETags -- ein ETag-Validator kann nie passen
    set etag  [holen $p /ir2.bin [list Range bytes=0-99 If-Range {"abc123"}]]
    set schwach [holen $p /ir2.bin [list Range bytes=0-99 If-Range {W/"abc"}]]
    set murks [holen $p /ir2.bin [list Range bytes=0-99 If-Range quatsch]]
    # ohne Range-Kopf ist If-Range zu ignorieren
    set ohne  [holen $p /ir2.bin [list If-Range {Mon, 01 Jan 2020 00:00:00 GMT}]]
    list [status $etag] [status $schwach] [status $murks] [status $ohne]
} -cleanup {
    serverStop $h
    file delete -force $f
} -result {200 200 200 200}

test ifrange-3 "Range ohne If-Range bleibt unberuehrt" -setup {
    set h [serverStart $testDir --no-log]
    set p [serverPort $h]
} -body {
    set a [holen $p /plain.txt {Range bytes=0-3}]
    list [status $a] [kopfwert $a Content-Length]
} -cleanup {
    serverStop $h
} -result {206 4}

# ============================================================
# mkcert.tcl: subjectAltName (0.3.4)
# ============================================================
#
# Bis 0.3.3 setzte mkcert.tcl nur "-subj /CN=...". Aktuelle Browser lesen den
# CN nicht mehr als Hostnamen -- Chrome seit 58 (2017) -- sondern den
# subjectAltName. Gemessen an der alten Fassung:
#
#     tclsh mkcert.tcl --cn mdstack.example.lan
#     openssl x509 -noout -ext subjectAltName   ->  nichts
#
# Das Zertifikat wird abgelehnt, auch nach Import in den Zertifikatspeicher.
# Fuer diese Tests ein kleiner Schluessel: es geht um den SAN, nicht um die
# Schluessellaenge.

proc opensslDa {} { return [expr {[auto_execok openssl] ne ""}] }
proc mkcertRuf {verz args} {
    set skript [file normalize [file join [file dirname [info script]] .. mkcert.tcl]]
    set rc [catch {exec [info nameofexecutable] $skript --out $verz --bits 1024 \
        {*}$args 2>@1} ausgabe]
    return [list $rc $ausgabe]
}
proc sanImZert {verz} {
    set c [file join $verz server.crt]
    if {![file exists $c]} { return "KEIN ZERTIFIKAT" }
    if {[catch {exec openssl x509 -in $c -noout -ext subjectAltName} z]} { return "" }
    foreach zeile [split $z \n] {
        set zeile [string trim $zeile]
        if {[string match "DNS:*" $zeile] || [string match "IP*:*" $zeile]} { return $zeile }
    }
    return ""
}
proc frischesVerz {} {
    set d [file join [tcltest::configure -tmpdir] mkcert[pid][clock clicks]]
    file delete -force $d; file mkdir $d
    return $d
}

test mkcert-1 "der CN landet im subjectAltName, localhost auch als IP" -constraints {
} -setup {
    set d1 [frischesVerz]; set d2 [frischesVerz]
} -body {
    if {![opensslDa]} { return {ok ok} }
    lassign [mkcertRuf $d1] rc1 a1
    lassign [mkcertRuf $d2 --cn mdstack.example.lan] rc2 a2
    list [expr {$rc1 == 0 ? "ok" : "abgebrochen: $a1"}] \
         [sanImZert $d1] \
         [expr {$rc2 == 0 ? "ok" : "abgebrochen: $a2"}] \
         [sanImZert $d2]
} -cleanup {
    file delete -force $d1 $d2
} -result [expr {[auto_execok openssl] eq ""
    ? {ok ok}
    : {ok {DNS:localhost, IP Address:127.0.0.1} ok DNS:mdstack.example.lan}}]

test mkcert-2 "--san haengt Namen und IPs an, eine IP als CN wird IP:" -setup {
    set d1 [frischesVerz]; set d2 [frischesVerz]
} -body {
    if {![opensslDa]} { return {ok ok} }
    # der LAN-Fall: Aufruf per Name UND per Adresse
    lassign [mkcertRuf $d1 --cn mdstack --san 192.168.1.50 --san mdstack.lan] rc1 a1
    lassign [mkcertRuf $d2 --cn 192.168.1.50] rc2 a2
    list [sanImZert $d1] [sanImZert $d2]
} -cleanup {
    file delete -force $d1 $d2
} -result [expr {[auto_execok openssl] eq ""
    ? {ok ok}
    : {{DNS:mdstack, IP Address:192.168.1.50, DNS:mdstack.lan} {IP Address:192.168.1.50}}}]

test mkcert-3 "ein vorhandenes Zertifikat ohne SAN wird ersetzt, --check meldet es" -setup {
    set d [frischesVerz]
} -body {
    if {![opensslDa]} { return {ok ok ok} }
    # ein Zertifikat, wie mkcert.tcl es bis 0.3.3 erzeugt hat
    exec openssl req -x509 -newkey rsa:1024 -nodes \
        -keyout [file join $d server.key] -out [file join $d server.crt] \
        -days 365 -subj "/CN=alt.example.lan" 2>@1
    # --check darf das nicht als OK durchgehen lassen, obwohl das Datum stimmt
    lassign [mkcertRuf $d --check] rcCheck aCheck
    # und der naechste Aufruf ersetzt es, obwohl es noch nicht abgelaufen ist
    lassign [mkcertRuf $d --cn alt.example.lan] rcNeu aNeu
    list [expr {$rcCheck != 0 ? "gemeldet" : "als OK durchgelassen: $aCheck"}] \
         [expr {[string match "*ohne subjectAltName, wird neu erzeugt*" $aNeu]
                    ? "ersetzt" : "nicht ersetzt: $aNeu"}] \
         [expr {[sanImZert $d] eq "DNS:alt.example.lan" ? "ok" : [sanImZert $d]}]
} -cleanup {
    file delete -force $d
} -result [expr {[auto_execok openssl] eq "" ? {ok ok ok} : {gemeldet ersetzt ok}}]

test mkcert-4 "--no-san erzeugt bewusst eines ohne, und sagt das" -setup {
    set d [frischesVerz]
} -body {
    if {![opensslDa]} { return {ok ok} }
    lassign [mkcertRuf $d --cn nur-cn --no-san] rc a
    list [expr {[string match "*keiner*--no-san*" $a] ? "genannt" : "nicht genannt: $a"}] \
         [expr {[sanImZert $d] eq "" ? "ohne SAN" : [sanImZert $d]}]
} -cleanup {
    file delete -force $d
} -result [expr {[auto_execok openssl] eq "" ? {ok ok} : {genannt {ohne SAN}}}]

# ============================================================
# 0.4: Startmeldung, Health, Protokollzeile, Grenzen, Beenden
# ============================================================
#
# Fuenf Punkte aus der Durchsicht vom 28.09.2026. Alle am laufenden Prozess
# gemessen, nicht am Dict.

test start-1 "die Startmeldung nennt die Adresse, an die gebunden wurde" -setup {
    set h1 [serverStart $testDir]
    set h2 [serverStartOhneBind $testDir]
} -body {
    # Bis 0.3.4 stand hier immer "localhost" -- auch bei 0.0.0.0, also genau
    # im gefaehrlichen Fall das Gegenteil.
    after 300
    set mit  [serverLog $h1]
    set ohne [serverLog $h2]
    list [expr {[string match "*127.0.0.1:[serverPort $h1]*" $mit] ? 1 : "fehlt in: $mit"}] \
         [expr {[string match "*0.0.0.0:[serverPort $h2] (alle Schnittstellen)*" $ohne]
                    ? 1 : "fehlt in: $ohne"}]
} -cleanup {
    serverStop $h1
    serverStop $h2
} -result {1 1}

test health-1 "der Health-Endpunkt prueft die Wurzel, statt nur 200 zu sagen" -setup {
    set w [file join [tcltest::configure -tmpdir] mdgesund[pid]]
    file delete -force $w; file mkdir $w
    writeFile [file join $w index.md] "# Da\n"
    set h [serverStart $w --no-log]
    set p [serverPort $h]
} -body {
    set gut [holen $p /__mdserver/health]
    # Wurzel weg: ein Endpunkt, der jetzt noch 200 sagt, meldet "gesund",
    # waehrend der Server fuer alles 404 liefert.
    file delete -force $w
    set weg [holen $p /__mdserver/health]
    list [status $gut] [string trim [koerper $gut]] [status $weg]
} -cleanup {
    serverStop $h
    file delete -force $w
} -result {200 ok 503}

test log-2 "eine Zeile je Anfrage, mit Status und Bytes -- auch bei Markdown" -setup {
    set h [serverStart $testDir]
    set p [serverPort $h]
} -body {
    # Bis 0.3.4 waren es zwei Zeilen, und Bytes gab es nur bei statischen
    # Dateien; Markdown hatte keine.
    set md [holen $p /index.md]
    holen $p /gibtsnicht.md
    mitMethode $p POST /index.md
    after 400
    set t [serverLog $h]
    set laenge [kopfwert $md Content-Length]
    list [expr {[string match "*GET /index.md 200 $laenge markdown*" $t] ? 1 : "md fehlt in: $t"}] \
         [expr {[string match "*GET /gibtsnicht.md 404 *" $t] ? 1 : "404 fehlt"}] \
         [expr {[string match "*POST /index.md 405 *" $t] ? 1 : "405 ohne Pfad"}] \
         [expr {[string match "*-> 200 (markdown)*" $t] ? "die zweite Zeile ist noch da" : 1}]
} -cleanup {
    serverStop $h
} -result {1 1 1 1}

test grenze-1 "zu lange Anfragezeile 414, zu grosse Koepfe 431" -setup {
    set h [serverStart $testDir --no-log]
    set p [serverPort $h]
} -body {
    set lang [mitMethode $p GET "/[string repeat a 9000]"]
    # viele Koepfe, zusammen ueber der Vorgabe von 16 KiB
    set koepfe {}
    for {set i 0} {$i < 200} {incr i} { lappend koepfe X-Fuell-$i [string repeat z 100] }
    set viele [holen $p /index.md $koepfe]
    # und danach bedient der Server normal weiter
    set danach [holen $p /index.md]
    list [status $lang] [status $viele] [status $danach]
} -cleanup {
    serverStop $h
} -result {414 431 200}

test grenze-2 "die Grenzen sind einstellbar" -setup {
    set h [serverStart $testDir --no-log --maxline 200]
    set p [serverPort $h]
} -body {
    list [status [mitMethode $p GET "/[string repeat a 300]"]] \
         [status [mitMethode $p GET "/[string repeat a 50]"]]
} -cleanup {
    serverStop $h
} -result {414 404}

test beenden-2 "stop laesst laufende Verbindungen zu Ende, statt sie zu kappen" -setup {
    set ctrl [freierPort]
    set h [serverStart $testDir --control $ctrl]
    set p [serverPort $h]
} -body {
    # Bis 0.3.4 rief shutdown my stop, und das schliesst ALLE offenen
    # Verbindungen sofort und leert _conns -- wer gerade eine grosse PDF holte,
    # bekam sie mitten im Byte abgeschnitten, bei jedem systemctl restart.
    #
    # Hier haelt ein Klient eine Verbindung offen, ohne etwas zu senden. Der
    # Server muss auf sie warten, bis seine Frist ablaeuft, und das Abschneiden
    # dann protokollieren.
    set still [socket 127.0.0.1 $p]
    after 500
    set mdctl [file normalize [file join [file dirname [info script]] .. mdctl.tcl]]
    exec [info nameofexecutable] $mdctl --port $ctrl stop
    # bis zur Frist (5 s) plus Luft warten und das Protokoll lesen
    for {set i 0} {$i < 90} {incr i} {
        after 100
        if {[string match "*shutdown:*" [serverLog $h]]} break
    }
    catch {close $still}
    set t [serverLog $h]
    list [expr {[string match "*shutdown: 1 Verbindung(en) abgeschnitten*" $t]
                    ? 1 : "hat nicht gewartet: [string range $t end-200 end]"}]
} -cleanup {
    serverStop $h
} -result 1

test beenden-1 "stop antwortet und beendet, mdctl gibt 0 zurueck" -setup {
    set ctrl [freierPort]
    set h [serverStart $testDir --no-log --control $ctrl]
} -body {
    # Der Steuerport stand bis 0.4 auf -blocking 0, und ein close verwirft
    # dort, was nicht draussen ist: "pong" und "stopping" kamen nie an. Als
    # ExecStop= in einer systemd-Unit ist das unbrauchbar.
    set mdctl [file normalize [file join [file dirname [info script]] .. mdctl.tcl]]
    set rcP [catch {exec [info nameofexecutable] $mdctl --port $ctrl ping} pong]
    set rcS [catch {exec [info nameofexecutable] $mdctl --port $ctrl stop} stopp]
    # danach horcht niemand mehr
    after 500
    list [expr {$rcP == 0 ? $pong : "ping rc=$rcP: $pong"}] \
         [expr {$rcS == 0 ? $stopp : "stop rc=$rcS: $stopp"}] \
         [erreichbar 127.0.0.1 [serverPort $h]]
} -cleanup {
    serverStop $h
} -result {pong stopping 0}

# ============================================================
# Aufraumen
# ============================================================

$renderer destroy
$server   destroy

file delete -force $testDir
file delete -force $navDir
tcltest::cleanupTests
