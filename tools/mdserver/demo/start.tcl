#!/usr/bin/env tclsh
# start.tcl -- start the demo site
# ============================================================================
# Usage:
#   tclsh start.tcl                   -- HTTP only
#   tclsh start.tcl --https           -- HTTP + HTTPS (certificate auto)
#   tclsh start.tcl --https --cn meinserver.local
#   tclsh start.tcl --port 8080 --theme dunkel
#   tclsh start.tcl --style sidebar          -- TOC as sidebar
#   tclsh start.tcl --control 8099            -- control port (stop/ping)
#   tclsh start.tcl --navbg "#800000"         -- colour the nav bar
#
# --https: generates a certificate automatically via mkcert.tcl if needed.
#          the certificate is stored in ../server.crt (tools/mdserver/)
#          so it does not end up in mdserver-demo/.
#
# .gitignore: server.crt and server.key should be ignored:
#   echo "tools/mdserver/server.crt" >> .gitignore
#   echo "tools/mdserver/server.key" >> .gitignore
# ============================================================================

set scriptDir [file dirname [file normalize [info script]]]
set docsDir   [file join $scriptDir docs]

# locate mdserver.tcl and mkcert.tcl
proc findScript {scriptDir name} {
    foreach candidate [list \
        $name \
        "../$name" \
        "../../$name"] {
        set p [file normalize [file join $scriptDir $candidate]]
        if {[file exists $p]} { return $p }
    }
    return ""
}

set mdserverScript [findScript $scriptDir mdserver.tcl]
set mkcertScript   [findScript $scriptDir mkcert.tcl]

if {$mdserverScript eq ""} {
    puts stderr "ERROR: mdserver.tcl nicht gefunden."
    exit 1
}

# default certificate path: one level up (tools/mdserver/)
# so server.crt/key do not end up in mdserver-demo/
set certDir  [file normalize [file join $scriptDir ".."]]
set certFile [file join $certDir server.crt]
set keyFile  [file join $certDir server.key]

# ============================================================
# parse CLI arguments
# ============================================================

set useHttps  0
set cn        "localhost"
set port      8080
set tlsport   8443
set extraArgs {}
set style     ""
set ctrlPort  ""

set i 0
while {$i < [llength $argv]} {
    set arg [lindex $argv $i]
    switch $arg {
        --https   { set useHttps 1 }
        --cn      { set cn       [lindex $argv [incr i]] }
        --port    { set port     [lindex $argv [incr i]] }
        --tlsport { set tlsport  [lindex $argv [incr i]] }
        --style   { set style    [lindex $argv [incr i]] }
        --stylesdir { lappend extraArgs --stylesdir [lindex $argv [incr i]] }
        --control { set ctrlPort [lindex $argv [incr i]] }
        --cert    { set certFile [file normalize [lindex $argv [incr i]]] }
        --key     { set keyFile  [file normalize [lindex $argv [incr i]]] }
        --help {
            puts "Usage: tclsh start.tcl \[options\]"
            puts "  --https           HTTP + HTTPS (Zertifikat auto)"
            puts "  --cn    NAME      CN fuer Zertifikat (default: localhost)"
            puts "  --port  PORT      HTTP-Port (default: 8080)"
            puts "  --tlsport PORT    HTTPS-Port (default: 8443)"
            puts "  --cert  FILE      Vorhandenes Zertifikat verwenden"
            puts "  --key   FILE      Vorhandener Key verwenden"
            puts "  --theme NAME      Theme: hell|dunkel|solarized"
            puts "  --style NAME      TOC-Stil: plain|sidebar|sticky|collapsible"
            puts "  --control PORT    Control-Port (localhost; stop/ping)"
            puts "  --navbg COLOR     Navi-Leiste Hintergrundfarbe"
            puts "  --navfg COLOR     Navi-Leiste Textfarbe"
            puts ""
            puts "Zertifikat wird gespeichert in:"
            puts "  $certFile"
            puts "  $keyFile"
            puts ""
            puts ".gitignore Empfehlung:"
            puts "  tools/mdserver/server.crt"
            puts "  tools/mdserver/server.key"
            exit 0
        }
        default { lappend extraArgs $arg }
    }
    incr i
}

# ============================================================
# HTTPS: Zertifikat pruefen / erzeugen
# ============================================================

if {$useHttps} {
    if {$mkcertScript eq ""} {
        puts stderr "ERROR: mkcert.tcl nicht gefunden."
        puts stderr "       Lege mkcert.tcl neben mdserver.tcl."
        exit 1
    }

    set needCert 0
    if {![file exists $certFile] || ![file exists $keyFile]} {
        puts "Kein Zertifikat gefunden -- wird erzeugt..."
        set needCert 1
    } else {
        if {[catch {exec openssl x509 -in $certFile -noout -checkend 0}]} {
            puts "Zertifikat abgelaufen -- wird neu erzeugt..."
            set needCert 1
        } else {
            catch {exec openssl x509 -in $certFile -noout -enddate} enddate
            set until [string trim [lindex [split $enddate =] 1]]
            puts "Zertifikat gueltig bis: $until"
        }
    }

    if {$needCert} {
        set certName [file tail $certFile]
        set keyName  [file tail $keyFile]

        if {[catch {
            exec tclsh $mkcertScript \
                --cn   $cn \
                --out  $certDir \
                --cert $certName \
                --key  $keyName \
                >@stdout 2>@stderr
        } err]} {
            puts stderr "ERROR: Zertifikat konnte nicht erzeugt werden: $err"
            exit 1
        }

        if {![file exists $certFile] || ![file exists $keyFile]} {
            puts stderr "ERROR: Zertifikat-Dateien fehlen nach mkcert."
            exit 1
        }

        # .gitignore Hinweis
        puts ""
        puts "Hinweis .gitignore -- folgende Zeilen eintragen:"
        puts "  tools/mdserver/server.crt"
        puts "  tools/mdserver/server.key"
    }
}

# ============================================================
# start mdserver
# ============================================================

set args [list \
    --root  $docsDir \
    --title "mdserver Demo" \
    --port  $port]

foreach a $extraArgs { lappend args $a }

if {$style    ne ""} { lappend args --style   $style }
if {$ctrlPort ne ""} { lappend args --control $ctrlPort }

if {$useHttps} {
    lappend args --cert $certFile --key $keyFile --tlsport $tlsport
}

puts ""
puts "mdserver Demo-Site"
puts "  Docs:  $docsDir"
puts "  HTTP:  http://localhost:$port/"
if {$style    ne ""} { puts "  Style: $style" }
if {$ctrlPort ne ""} { puts "  Ctrl:  localhost:$ctrlPort (echo stop | nc localhost $ctrlPort)" }
if {$useHttps} {
    puts "  HTTPS: https://localhost:$tlsport/"
    puts "  Cert:  $certFile"
}
puts ""

exec tclsh $mdserverScript {*}$args >@stdout 2>@stderr
