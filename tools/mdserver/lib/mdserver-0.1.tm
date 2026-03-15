# mdserver-0.1.tm -- Markdown-Web-Server Modul v0.4
# ============================================================================
# HTTP/HTTPS-Server fuer Markdown-Dokumente.
# Kein Tk, keine Fonts, kein Display. Benoetigt nur Tcl 8.6+.
#
# Klassen:
#   mdserver::Request  -- HTTP-Request parsen
#   mdserver::Renderer -- Markdown + Index -> HTML
#   mdserver::Server   -- HTTP/HTTPS-Server
#
# Requires: mdparser 0.2, mdhtml 0.1
# Optional: mdtheme 0.1, tls (fuer HTTPS)
# ============================================================================

package provide mdserver 0.1

package require Tcl 8.6
# ============================================================
# Module laden
# ============================================================

if {[catch {package require mdparser 0.2} err]} {
    puts stderr "ERROR: mdparser 0.2 not found: $err"
    exit 1
}
if {[catch {package require mdhtml 0.1} err]} {
    puts stderr "ERROR: mdhtml 0.1 not found: $err"
    exit 1
}
catch {package require mdtheme 0.1}

# ============================================================
# MIME-Types (global, unveraenderlich)
# ============================================================

namespace eval mdserver {
    variable mimeTypes {
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
}

# ============================================================
# mdserver::Request -- HTTP-Request parsen
# ============================================================

oo::class create mdserver::Request {

    variable _method _path _query _headers _params

    constructor {chan} {
        set _method  ""
        set _path    ""
        set _query   ""
        set _headers {}
        set _params  {}
        my _parse $chan
    }

    # Oeffentliche Accessor
    method method  {} { return $_method  }
    method path    {} { return $_path    }
    method headers {} { return $_headers }
    method params  {} { return $_params  }

    method header {name} {
        set key [string tolower $name]
        if {[dict exists $_headers $key]} {
            return [dict get $_headers $key]
        }
        return ""
    }

    method param {name {default ""}} {
        if {[dict exists $_params $name]} {
            return [dict get $_params $name]
        }
        return $default
    }

    # Privat: Request-Line + Header einlesen
    method _parse {chan} {
        # Request-Line
        gets $chan requestLine

        # Header bis Leerzeile
        while {1} {
            if {[catch {gets $chan line}]} break
            set line [string trimright $line]
            if {$line eq ""} break
            if {[regexp {^([^:]+):\s*(.*)$} $line -> k v]} {
                dict set _headers [string tolower $k] $v
            }
        }

        # Method + URL
        if {![regexp {^(GET|HEAD)\s+(/[^\s]*)\s+HTTP} $requestLine \
                -> _method rawUrl]} {
            throw {MDDOCS BADREQUEST} "Invalid request line: $requestLine"
        }

        # URL und Query trennen
        if {[string first ? $rawUrl] >= 0} {
            regexp {^([^?]*)(\?(.*))?$} $rawUrl -> _path _ _query
        } else {
            set _path $rawUrl
        }
        set _path   [my _urlDecode $_path]
        set _params [my _parseQuery $_query]
    }

    method _urlDecode {str} {
        set str [string map {+ " "} $str]
        regsub -all {%([0-9A-Fa-f]{2})} $str {[binary format H2 \1]} str
        set str [subst $str]
        return [encoding convertfrom utf-8 $str]
    }

    method _parseQuery {query} {
        set result {}
        foreach pair [split $query &] {
            if {$pair eq ""} continue
            set kv [split $pair =]
            set k [my _urlDecode [lindex $kv 0]]
            set v [my _urlDecode [lindex $kv 1]]
            dict set result $k $v
        }
        return $result
    }
}

# ============================================================
# mdserver::Renderer -- Markdown + Index -> HTML
# ============================================================

oo::class create mdserver::Renderer {

    variable _title

    constructor {title} {
        set _title $title
    }

    method markdown {path theme toc} {
        set md [my _readFile $path]
        set ast [mdparser::parse $md]
        return [mdhtml::render $ast \
            -theme $theme \
            -toc   $toc   \
            -lang  de]
    }

    method index {dirPath urlPath theme} {
        set mdFiles {}
        set subdirs {}

        foreach f [lsort [glob -nocomplain -directory $dirPath *.md]] {
            lappend mdFiles [file tail $f]
        }
        foreach d [lsort [glob -nocomplain -directory $dirPath -type d *]] {
            set name [file tail $d]
            if {$name ni {. ..}} { lappend subdirs $name }
        }

        # CSS
        set css ""
        catch {set css [mdtheme::toCSS $theme]} ;# intentional: mdtheme optional
        if {$css eq ""} { set css [mdhtml::_defaultCss] }

        set title "$_title -- [string trimright $urlPath /]/"
        set esc   [mdhtml::escapeHtml $title]
        set body  "<h1>Index: [mdhtml::escapeHtml $urlPath]</h1>\n"

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
                set href   [string trimright $urlPath /]/$f
                set fpath  [file join $dirPath $f]
                set ftitle $f
                catch { ;# intentional: Titel-Extraktion optional, Fehler ignoriert
                    foreach line [split [my _readFile $fpath] "\n"] {
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

    method _readFile {path} {
        set fh [open $path r]
        fconfigure $fh -encoding utf-8
        try {
            return [read $fh]
        } finally {
            close $fh
        }
    }
}

# ============================================================
# mdserver::Server -- HTTP/HTTPS-Server
# ============================================================

oo::class create mdserver::Server {

    variable _cfg _renderer _httpSock _httpsSock

    constructor {args} {
        # Defaults
        array set opts {
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
        # Argumente einlesen
        foreach {k v} $args {
            set opts([string trimleft $k -]) $v
        }
        set opts(root) [file normalize $opts(root)]
        set opts(tls)  0
        set _cfg [array get opts]

        set _renderer [mdserver::Renderer new [my cfg title]]
        set _httpSock  ""
        set _httpsSock ""
    }

    destructor {
        my stop
        $_renderer destroy
    }

    # Config-Accessor
    method cfg {key} {
        return [dict get $_cfg $key]
    }

    # Server starten
    method start {} {
        # TLS optional laden
        if {[my cfg cert] ne "" && [my cfg key] ne ""} {
            if {[catch {package require tls} err]} {
                puts stderr "WARNING: tls not available -- HTTPS disabled: $err"
            } else {
                dict set _cfg tls 1
            }
        }

        # HTTP
        try {
            set _httpSock [socket -server [list [self object] handleRequest] \
                [my cfg port]]
        } on error {err} {
            error "Cannot bind to HTTP port [my cfg port]: $err"
        }

        # HTTPS
        if {[my cfg tls]} {
            if {![file exists [my cfg cert]]} {
                error "Certificate not found: [my cfg cert]"
            }
            if {![file exists [my cfg key]]} {
                error "Key not found: [my cfg key]"
            }
            try {
                tls::init \
                    -certfile [my cfg cert] \
                    -keyfile  [my cfg key]  \
                    -ssl2 0 -ssl3 0 -tls1 0 -tls1.2 1

                set _httpsSock [tls::socket \
                    -server [list [self object] handleRequest] \
                    [my cfg tlsport]]
            } on error {err} {
                error "Cannot start HTTPS on port [my cfg tlsport]: $err"
            }
        }

        my _printStatus
    }

    method stop {} {
        catch { close $_httpSock  }
        catch { close $_httpsSock }
    }

    # Request-Handler -- wird von socket -server aufgerufen
    method handleRequest {chan addr port} {
        fconfigure $chan -translation crlf -encoding utf-8 -buffering full

        try {
            set req [mdserver::Request new $chan]

            my _log "[$req method] [$req path]"

            set theme [$req param theme [my cfg theme]]
            set toc   [$req param toc   [my cfg toc]]
            set path  [$req path]

            my _dispatch $chan $path $theme $toc

        } trap {MDDOCS BADREQUEST} {} {
            # Kaputte Verbindung / ungueltiger Request -- still ignorieren
        } on error {msg} {
            my _log "  -> bgerror: $msg"
            puts stderr "mdserver bgerror: $msg"
        } finally {
            catch {close $chan}
        }
    }

    # Routing
    method _dispatch {chan urlPath theme toc} {
        try {
            set fsPath [my _safePath $urlPath]

            if {[file isdirectory $fsPath]} {
                set indexFile [file join $fsPath [my cfg index]]
                if {[file exists $indexFile]} {
                    set html [$_renderer markdown $indexFile $theme $toc]
                    my _log "  -> 200 (index.md)"
                    my _send $chan "200 OK" "text/html; charset=utf-8" $html
                } else {
                    set html [$_renderer index $fsPath $urlPath $theme]
                    my _log "  -> 200 (directory index)"
                    my _send $chan "200 OK" "text/html; charset=utf-8" $html
                }

            } elseif {![file exists $fsPath]} {
                throw {MDDOCS NOTFOUND} $urlPath

            } else {
                set ext [string tolower [file extension $fsPath]]
                if {$ext eq ".md"} {
                    set html [$_renderer markdown $fsPath $theme $toc]
                    my _log "  -> 200 (markdown)"
                    my _send $chan "200 OK" "text/html; charset=utf-8" $html
                } else {
                    set mime [my _mime $ext]
                    set data [my _readBin $fsPath]
                    my _log "  -> 200 ([file size $fsPath] bytes, $mime)"
                    my _sendBin $chan "200 OK" $mime $data
                }
            }

        } trap {MDDOCS TRAVERSAL} {msg} {
            my _log "  -> 403 ($msg)"
            my _send $chan "403 Forbidden" "text/html; charset=utf-8" \
                "<html><body><h1>403 Forbidden</h1><p>$msg</p></body></html>"
        } trap {MDDOCS NOTFOUND} {msg} {
            my _log "  -> 404"
            my _send $chan "404 Not Found" "text/html; charset=utf-8" \
                "<html><body><h1>404 Not Found</h1><p>$msg</p></body></html>"
        } trap {POSIX ENOENT} {} {
            my _log "  -> 404 (ENOENT)"
            my _send $chan "404 Not Found" "text/html; charset=utf-8" \
                "<html><body><h1>404 Not Found</h1></body></html>"
        } on error {msg info} {
            my _log "  -> 500: $msg"
            my _send $chan "500 Internal Server Error" "text/html; charset=utf-8" \
                "<html><body><h1>500 Internal Server Error</h1><pre>$msg</pre></body></html>"
        }
    }

    # Hilfsmethoden
    method _safePath {urlPath} {
        set root [my cfg root]
        set path [file normalize [file join $root [string trimleft $urlPath /]]]
        if {![string match "${root}*" $path]} {
            throw {MDDOCS TRAVERSAL} "Directory traversal blocked: $urlPath"
        }
        return $path
    }

    method _mime {ext} {
        if {[dict exists $::mdserver::mimeTypes $ext]} {
            return [dict get $::mdserver::mimeTypes $ext]
        }
        return "application/octet-stream"
    }

    method _readBin {path} {
        set fh [open $path rb] ;# binary mode -- kein fconfigure -encoding noetig
        try {
            return [read $fh]
        } finally {
            close $fh
        }
    }

    method _send {chan status contentType body} {
        set len [string length [encoding convertto utf-8 $body]]
        puts $chan "HTTP/1.1 $status"
        puts $chan "Content-Type: $contentType"
        puts $chan "Content-Length: $len"
        puts $chan "Connection: close"
        puts $chan "Server: mdserver/0.4"
        puts $chan ""
        puts -nonewline $chan $body
    }

    method _sendBin {chan status contentType data} {
        set len [string length $data]
        fconfigure $chan -translation binary
        puts $chan "HTTP/1.1 $status"
        puts $chan "Content-Type: $contentType"
        puts $chan "Content-Length: $len"
        puts $chan "Connection: close"
        puts $chan "Server: mdserver/0.4"
        puts $chan ""
        puts -nonewline $chan $data
    }

    method _log {msg} {
        if {[my cfg log]} {
            puts "\[[clock format [clock seconds] -format "%H:%M:%S"]\] $msg"
        }
    }

    method _printStatus {} {
        puts "mdserver 0.4 -- Tcl Markdown Server"
        puts "  Root:  [my cfg root]"
        puts "  Theme: [my cfg theme]"
        puts ""
        puts "  HTTP:  http://localhost:[my cfg port]/"
        if {[my cfg tls]} {
            puts "  HTTPS: https://localhost:[my cfg tlsport]/"
            puts "  Cert:  [my cfg cert]"
        } else {
            puts "  HTTPS: nicht aktiv (--cert und --key angeben)"
        }
        puts ""
        puts "Press Ctrl+C to stop."
        puts ""
    }
}
