#!/usr/bin/env tclsh
# mdserver.tcl -- Markdown web server (launcher)
# ============================================================================
# Starts mdserver. Requires mdserver-0.2.tm on the module path.
#
# Usage:
#   tclsh mdserver.tcl ?--port 8080? ?--bind 127.0.0.1? ?--root /path? ?--theme hell?
#
# Requires: mdserver 0.4 (mdserver-0.4.tm)
# ============================================================================

package require Tcl 8.6 9

# Modul-Pfad: lib/ relativ zum Skript (Regelbuch-Konvention)
set _scriptDir [file dirname [file normalize [info script]]]
foreach _candidate {lib ../lib} {
    set _d [file normalize [file join $_scriptDir $_candidate]]
    if {[file exists $_d]} { tcl::tm::path add $_d }
}
unset -nocomplain _scriptDir _candidate _d

if {[catch {package require mdserver 0.4} err]} {
    puts stderr "ERROR: mdserver 0.4 nicht gefunden: $err"
    puts stderr "       mdserver-0.2.tm muss in lib/ liegen."
    exit 1
}

# ============================================================
# CLI -- parse arguments
# ============================================================

proc parseArgs {argv} {
    set args {}
    set i 0
    while {$i < [llength $argv]} {
        set arg [lindex $argv $i]
        switch $arg {
            --port    -
            --bind    -
            --dotfiles -
            --maxline -
            --maxheader -
            --healthpath -
            --root    -
            --theme   -
            --title   -
            --toc     -
            --cert    -
            --key     -
            --control -
            --style   -
            --stylesdir -
            --navbg   -
            --navfg   -
            --navmax  -
            --tlsport { lappend args $arg [lindex $argv [incr i]] }
            --no-log  { lappend args --log 0 }
            --trusted-proxy {
                # Der Konstruktor macht aus "--x" den Schluessel "x"; sein
                # Schluessel heisst trustedproxy, in einem Wort wie alle
                # anderen. Mehrere Adressen als eine Liste:
                #   --trusted-proxy "127.0.0.1 10.0.0.5"
                lappend args --trustedproxy [lindex $argv [incr i]]
            }
            --help {
                puts "Usage: tclsh mdserver.tcl \[options\]"
                puts "  --port    PORT    HTTP port (default: 8080)"
                puts "  --bind    ADDR    Listen address (default: all interfaces;"
                puts "                    use 127.0.0.1 when a proxy does the auth)"
                puts "  --dotfiles 0|1   Serve hidden files and directories such as"
                puts "                    .git (default: 0 -- not served)"
                puts "  --trusted-proxy ADDR ... Peer addresses whose X-Forwarded-For"
                puts "                    is believed in the log. Exact match, no"
                puts "                    netmasks. Default: empty -- header ignored."
                puts "  --root    DIR     Document root (default: .)"
                puts "  --theme   NAME    hell|dunkel|solarized (default: hell)"
                puts "  --title   TEXT    Site title (default: mdserver)"
                puts "  --toc     0|1     Table of contents (default: 1)"
                puts "  --no-log          Disable request logging"
                puts "  --cert    FILE    TLS certificate (.crt/.pem)"
                puts "  --key     FILE    TLS private key (.key)"
                puts "  --tlsport PORT    HTTPS port (default: 8443)"
                puts "  --control PORT    Control port (localhost; stop/ping)."
                puts "                    Beenden: tclsh mdctl.tcl --port PORT stop"
                puts "  --maxline BYTES   Max. Bytes je Anfrage-/Kopfzeile -> 414"
                puts "                    (default: 8190; 0 = ohne Grenze)"
                puts "  --maxheader BYTES Max. Bytes aller Koepfe -> 431"
                puts "                    (default: 16384; 0 = ohne Grenze)"
                puts "  --healthpath PATH Pfad des Health-Endpunkts"
                puts "                    (default: /__mdserver/health)"
                puts "  --style   NAME    TOC style: plain|sidebar|sticky|collapsible"
                puts "  --stylesdir DIR   CSS style directory (default: ../styles)"
                puts "  --navbg   COLOR   Nav bar background color"
                puts "  --navfg   COLOR   Nav bar text color"
                puts "  --navmax  N       Max. sections shown inline; more fold into a"
                puts "                    dropdown (default: 6; 0 = never fold)"
                puts ""
                puts "Troubleshooting:"
                puts "  Port belegt: fuser -k 8080/tcp"
                exit 0
            }
        }
        incr i
    }
    return $args
}

# ============================================================
# Start the server
# ============================================================

set server [mdserver::Server new {*}[parseArgs $argv]]

try {
    $server start
} on error {msg} {
    puts stderr "ERROR: $msg"
    exit 1
}

# bgerror -- global error handler for event-loop errors (Tk convention)
proc bgerror {msg} {
    puts stderr "Background error: $msg"
}

catch { ;# intentional: signal is not available on all platforms
    signal trap SIGINT {
        puts "\nShutting down."
        exit 0
    }
}

vwait forever
