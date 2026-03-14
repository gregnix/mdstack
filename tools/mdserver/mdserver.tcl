#!/usr/bin/env tclsh
# mdserver.tcl -- Markdown-Web-Server (pure Tcl, kein Tk)
# ============================================================================
# Liefert Markdown-Dateien als HTML aus. Benoetigt nur Tcl 8.6+.
# Kein Tk, keine Fonts, kein Display.
#
# Usage:
#   tclsh mdserver.tcl ?--port 8080? ?--root /pfad? ?--theme hell?
#
# Requires: mdparser 0.2, mdtheme 0.1, mdhtml 0.1
# Optional: tls (fuer HTTPS)  -- apt install tcl-tls
#
# Features:
#   - Markdown-Dateien -> HTML (via mdhtml)
#   - Verzeichnis-Index mit Dateiliste
#   - Theme-Auswahl via URL-Parameter (?theme=dunkel)
#   - Statische Dateien (css, png, jpg, gif, js)
#   - HTTP immer aktiv
#   - HTTPS optional wenn tls-Paket und Zertifikat vorhanden
#   - Logging, Graceful Shutdown via Ctrl+C
#
# HTTPS Schnellstart (selbstsigniertes Zertifikat):
#   openssl req -x509 -newkey rsa:4096 -keyout server.key \
#               -out server.crt -days 365 -nodes \
#               -subj "/CN=localhost"
#   tclsh mdserver.tcl --cert server.crt --key server.key
# ============================================================================

package require Tcl 8.6

# ============================================================
# Konfiguration
# ============================================================

array set cfg {
    port    8080
    root    "."
    theme   "hell"
    title   "mdserver"
    index   "index.md"
    toc     1
    log     1
    cert    ""
    key     ""
    tlsport 8443
}

# CLI-Argumente parsen
set i 0
while {$i < [llength $argv]} {
    set arg [lindex $argv $i]
    switch $arg {
        --port    { set cfg(port)    [lindex $argv [incr i]] }
        --root    { set cfg(root)    [lindex $argv [incr i]] }
        --theme   { set cfg(theme)   [lindex $argv [incr i]] }
        --title   { set cfg(title)   [lindex $argv [incr i]] }
        --toc     { set cfg(toc)     [lindex $argv [incr i]] }
        --cert    { set cfg(cert)    [lindex $argv [incr i]] }
        --key     { set cfg(key)     [lindex $argv [incr i]] }
        --tlsport { set cfg(tlsport) [lindex $argv [incr i]] }
        --no-log  { set cfg(log)     0 }
        --help  {
            puts "Usage: tclsh mdserver.tcl \[options\]"
            puts "  --port    PORT    HTTP port (default: 8080)"
            puts "  --root    DIR     Document root (default: .)"
            puts "  --theme   NAME    mdtheme: hell|dunkel|solarized (default: hell)"
            puts "  --title   TEXT    Site title (default: mdserver)"
            puts "  --toc     0|1     Table of contents (default: 1)"
            puts "  --no-log          Disable request logging"
            puts "  --cert    FILE    TLS certificate file (.crt/.pem)"
            puts "  --key     FILE    TLS private key file (.key)"
            puts "  --tlsport PORT    HTTPS port (default: 8443)"
            puts ""
            puts "HTTPS example:"
            puts "  tclsh mdserver.tcl --cert server.crt --key server.key"
            puts "  (requires: package tls -- apt install tcl-tls)"
            exit 0
        }
    }
    incr i
}

# Pfade
set cfg(root) [file normalize $cfg(root)]

# ============================================================
# Module laden
# ============================================================

set libDir [file normalize [file join [file dirname [info script]] ../../ lib]]
if {[file exists $libDir]} {
    tcl::tm::path add $libDir
}

if {[catch {package require mdparser 0.2} err]} {
    puts stderr "ERROR: mdparser 0.2 not found: $err"
    exit 1
}
if {[catch {package require mdhtml 0.1} err]} {
    puts stderr "ERROR: mdhtml 0.1 not found: $err"
    exit 1
}
catch {package require mdtheme 0.1}

# TLS optional laden
set cfg(tls) 0
if {$cfg(cert) ne "" && $cfg(key) ne ""} {
    if {[catch {package require tls} tlsErr]} {
        puts stderr "WARNING: tls package not available -- HTTPS disabled"
        puts stderr "         Install with: apt install tcl-tls"
        puts stderr "         Error: $tlsErr"
    } else {
        set cfg(tls) 1
    }
}

# ============================================================
# MIME-Types
# ============================================================

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

# ============================================================
# Hilfsprozeduren
# ============================================================

proc log {msg} {
    global cfg
    if {$cfg(log)} {
        puts "\[[clock format [clock seconds] -format "%H:%M:%S"]\] $msg"
    }
}

proc urlDecode {str} {
    set str [string map {+ " "} $str]
    regsub -all {%([0-9A-Fa-f]{2})} $str {[binary format H2 \1]} str
    set str [subst $str]
    return [encoding convertfrom utf-8 $str]
}

proc parseQuery {query} {
    set result {}
    foreach pair [split $query &] {
        set kv [split $pair =]
        set k [urlDecode [lindex $kv 0]]
        set v [urlDecode [lindex $kv 1]]
        dict set result $k $v
    }
    return $result
}

proc safePath {root urlPath} {
    # Verhindert Directory Traversal
    set path [file normalize [file join $root [string trimleft $urlPath /]]]
    if {![string match "${root}*" $path]} {
        return ""
    }
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

# ============================================================
# HTML-Generierung
# ============================================================

proc renderMarkdown {path theme toc} {
    global cfg
    set md [readFile $path]
    set ast [mdparser::parse $md]
    set html [mdhtml::render $ast \
        -theme  $theme \
        -toc    $toc \
        -lang   de]
    return $html
}

proc renderIndex {dirPath urlPath theme} {
    global cfg

    set mdFiles {}
    set subdirs {}

    foreach f [lsort [glob -nocomplain -directory $dirPath *.md]] {
        lappend mdFiles [file tail $f]
    }
    foreach d [lsort [glob -nocomplain -directory $dirPath -type d *]] {
        set name [file tail $d]
        if {$name ni {. ..}} { lappend subdirs $name }
    }

    # CSS aus Theme oder Default
    set css ""
    catch {set css [mdtheme::toCSS $theme]}
    if {$css eq ""} { set css [mdhtml::_defaultCss] }

    set title "$cfg(title) -- [string trimright $urlPath /]/"
    set esc [mdhtml::escapeHtml $title]

    set body "<h1>Index: [mdhtml::escapeHtml $urlPath]</h1>\n"

    # Parent-Link
    if {$urlPath ne "/"} {
        set parent [file dirname [string trimright $urlPath /]]
        if {$parent eq ""} { set parent "/" }
        append body "<p><a href=\"$parent\">.. (up)</a></p>\n"
    }

    # Unterverzeichnisse
    if {[llength $subdirs] > 0} {
        append body "<h2>Directories</h2>\n<ul class=\"dirlist\">\n"
        foreach d $subdirs {
            set href [string trimright $urlPath /]/$d/
            append body "<li><a href=\"$href\">$d/</a></li>\n"
        }
        append body "</ul>\n"
    }

    # Markdown-Dateien
    if {[llength $mdFiles] > 0} {
        append body "<h2>Documents</h2>\n<ul class=\"filelist\">\n"
        foreach f $mdFiles {
            set href [string trimright $urlPath /]/$f
            # Titel aus erster Zeile extrahieren
            set fpath [file join $dirPath $f]
            set ftitle $f
            catch {
                set lines [split [readFile $fpath] "\n"]
                foreach line $lines {
                    set line [string trim $line]
                    if {[string match "# *" $line]} {
                        set ftitle [string range $line 2 end]
                        break
                    }
                }
            }
            append body "<li><a href=\"$href\">[mdhtml::escapeHtml $ftitle]</a> "
            append body "<small>($f)</small></li>\n"
        }
        append body "</ul>\n"
    }

    if {[llength $mdFiles] == 0 && [llength $subdirs] == 0} {
        append body "<p><em>No Markdown files found.</em></p>\n"
    }

    return "<!DOCTYPE html>
<html lang=\"de\">
<head>
<meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<title>$esc</title>
<style>
$css
.dirlist li::before { content: \"📁 \"; }
.filelist li::before { content: \"📄 \"; }
small { color: #888; font-size: 0.85em; }
</style>
</head>
<body>
<article>
$body</article>
</body>
</html>"
}

# ============================================================
# HTTP-Response
# ============================================================

proc sendResponse {chan status contentType body} {
    set len [string length [encoding convertto utf-8 $body]]
    puts $chan "HTTP/1.1 $status"
    puts $chan "Content-Type: $contentType"
    puts $chan "Content-Length: $len"
    puts $chan "Connection: close"
    puts $chan "Server: mdserver/0.1"
    puts $chan ""
    puts -nonewline $chan $body
}

proc sendBinaryResponse {chan status contentType data} {
    set len [string length $data]
    fconfigure $chan -translation binary
    puts $chan "HTTP/1.1 $status"
    puts $chan "Content-Type: $contentType"
    puts $chan "Content-Length: $len"
    puts $chan "Connection: close"
    puts $chan "Server: mdserver/0.1"
    puts $chan ""
    puts -nonewline $chan $data
}

proc send404 {chan path} {
    set body "<html><body><h1>404 Not Found</h1><p>$path</p></body></html>"
    sendResponse $chan "404 Not Found" "text/html; charset=utf-8" $body
}

proc send500 {chan msg} {
    set body "<html><body><h1>500 Internal Server Error</h1><pre>$msg</pre></body></html>"
    sendResponse $chan "500 Internal Server Error" "text/html; charset=utf-8" $body
}

# ============================================================
# Request-Handler
# ============================================================

proc handleRequest {chan addr port} {
    global cfg mimeTypes

    fconfigure $chan -translation crlf -encoding utf-8 -buffering full

    # Request-Line lesen
    if {[catch {gets $chan requestLine}]} {
        catch {close $chan}
        return
    }

    # Header lesen (bis Leerzeile)
    set headers {}
    while {1} {
        if {[catch {gets $chan line}]} break
        set line [string trimright $line]
        if {$line eq ""} break
        if {[regexp {^([^:]+):\s*(.*)$} $line -> k v]} {
            dict set headers [string tolower $k] $v
        }
    }

    # Method + URL + Query parsen
    if {![regexp {^(GET|HEAD)\s+(/[^\s]*)\s+HTTP} $requestLine -> method rawUrl]} {
        catch {close $chan}
        return
    }

    # URL und Query trennen
    set queryStr ""
    if {[string first ? $rawUrl] >= 0} {
        regexp {^([^?]*)(\?(.*))?$} $rawUrl -> urlPath _ queryStr
    } else {
        set urlPath $rawUrl
    }
    set urlPath [urlDecode $urlPath]
    set params [parseQuery $queryStr]

    # Theme aus Query-Parameter (?theme=dunkel)
    set theme $cfg(theme)
    if {[dict exists $params theme]} {
        set theme [dict get $params theme]
    }
    set toc $cfg(toc)
    if {[dict exists $params toc]} {
        set toc [dict get $params toc]
    }

    log "$method $urlPath"

    # Sicheren Dateipfad ermitteln
    set fsPath [safePath $cfg(root) $urlPath]
    if {$fsPath eq ""} {
        log "  -> 403 Forbidden (traversal)"
        sendResponse $chan "403 Forbidden" "text/html; charset=utf-8" \
            "<html><body><h1>403 Forbidden</h1></body></html>"
        catch {close $chan}
        return
    }

    # Verzeichnis
    if {[file isdirectory $fsPath]} {
        # index.md suchen
        set indexFile [file join $fsPath $cfg(index)]
        if {[file exists $indexFile]} {
            if {[catch {set html [renderMarkdown $indexFile $theme $toc]} err]} {
                log "  -> 500: $err"
                send500 $chan $err
            } else {
                log "  -> 200 (index.md)"
                sendResponse $chan "200 OK" "text/html; charset=utf-8" $html
            }
        } else {
            # Verzeichnis-Listing
            if {[catch {set html [renderIndex $fsPath $urlPath $theme]} err]} {
                log "  -> 500: $err"
                send500 $chan $err
            } else {
                log "  -> 200 (directory index)"
                sendResponse $chan "200 OK" "text/html; charset=utf-8" $html
            }
        }
        catch {close $chan}
        return
    }

    # Datei existiert nicht
    if {![file exists $fsPath]} {
        log "  -> 404"
        send404 $chan $urlPath
        catch {close $chan}
        return
    }

    set ext [string tolower [file extension $fsPath]]

    # Markdown-Datei -> HTML rendern
    if {$ext eq ".md"} {
        if {[catch {set html [renderMarkdown $fsPath $theme $toc]} err]} {
            log "  -> 500: $err"
            send500 $chan $err
        } else {
            log "  -> 200 (markdown)"
            sendResponse $chan "200 OK" "text/html; charset=utf-8" $html
        }
        catch {close $chan}
        return
    }

    # Statische Datei
    set mime "application/octet-stream"
    if {[info exists mimeTypes($ext)]} {
        set mime $mimeTypes($ext)
    }

    if {[catch {set data [readFileBin $fsPath]} err]} {
        log "  -> 500: $err"
        send500 $chan $err
    } else {
        log "  -> 200 ([file size $fsPath] bytes, $mime)"
        sendBinaryResponse $chan "200 OK" $mime $data
    }
    catch {close $chan}
}

# ============================================================
# Server starten
# ============================================================

# HTTP immer starten
if {[catch {
    set httpServer [socket -server handleRequest $cfg(port)]
} err]} {
    puts stderr "ERROR: Cannot bind to HTTP port $cfg(port): $err"
    exit 1
}

# HTTPS optional -- wenn cert + key angegeben und tls verfuegbar
if {$cfg(tls)} {
    # Zertifikat und Key pruefen
    if {![file exists $cfg(cert)]} {
        puts stderr "ERROR: Certificate not found: $cfg(cert)"
        exit 1
    }
    if {![file exists $cfg(key)]} {
        puts stderr "ERROR: Key not found: $cfg(key)"
        exit 1
    }

    if {[catch {
        tls::init \
            -certfile $cfg(cert) \
            -keyfile  $cfg(key) \
            -ssl2     0 \
            -ssl3     0 \
            -tls1     0 \
            -tls1.2   1

        set httpsServer [tls::socket -server handleRequest $cfg(tlsport)]
    } err]} {
        puts stderr "ERROR: Cannot start HTTPS on port $cfg(tlsport): $err"
        puts stderr "       Check certificate and key files."
        exit 1
    }
}

# Status ausgeben
puts "mdserver 0.2 -- Tcl Markdown Server"
puts "  Root:  $cfg(root)"
puts "  Theme: $cfg(theme)"
puts ""
puts "  HTTP:  http://localhost:$cfg(port)/"
if {$cfg(tls)} {
    puts "  HTTPS: https://localhost:$cfg(tlsport)/"
    puts "  Cert:  $cfg(cert)"
} else {
    puts "  HTTPS: nicht aktiv (--cert und --key angeben)"
}
puts ""
puts "Press Ctrl+C to stop."
puts ""

# Ctrl+C abfangen
proc bgerror {msg} {
    puts stderr "Background error: $msg"
}

catch {
    signal trap SIGINT {
        puts "\nShutting down."
        exit 0
    }
}

vwait forever
