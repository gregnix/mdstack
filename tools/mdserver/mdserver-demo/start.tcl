#!/usr/bin/env tclsh
# start.tcl -- Demo-Site starten
# ============================================================================
# Usage:
#   tclsh start.tcl                   -- HTTP only
#   tclsh start.tcl --https           -- HTTP + HTTPS (Zertifikat auto)
#   tclsh start.tcl --https --cn meinserver.local
#   tclsh start.tcl --port 8080 --theme dunkel
#
# --https: Erzeugt Zertifikat automatisch via mkcert.tcl falls noetig.
#          Zertifikat wird in ../server.crt gespeichert (tools/mdserver/)
#          damit es nicht in mdserver-demo/ landet.
#
# .gitignore: server.crt und server.key sollten ignoriert werden:
#   echo "tools/mdserver/server.crt" >> .gitignore
#   echo "tools/mdserver/server.key" >> .gitignore
# ============================================================================

set scriptDir [file dirname [file normalize [info script]]]
set docsDir   [file join $scriptDir docs]

# mdserver.tcl und mkcert.tcl suchen
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

# Zertifikat-Standardpfad: eine Ebene hoeher (tools/mdserver/)
# damit server.crt/key nicht in mdserver-demo/ landen
set certDir  [file normalize [file join $scriptDir ".."]]
set certFile [file join $certDir server.crt]
set keyFile  [file join $certDir server.key]

# ============================================================
# CLI-Argumente parsen
# ============================================================

set useHttps  0
set cn        "localhost"
set port      8080
set tlsport   8443
set extraArgs {}

set i 0
while {$i < [llength $argv]} {
    set arg [lindex $argv $i]
    switch $arg {
        --https   { set useHttps 1 }
        --cn      { set cn       [lindex $argv [incr i]] }
        --port    { set port     [lindex $argv [incr i]] }
        --tlsport { set tlsport  [lindex $argv [incr i]] }
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
# mdserver starten
# ============================================================

set args [list \
    --root  $docsDir \
    --title "mdserver Demo" \
    --port  $port]

foreach a $extraArgs { lappend args $a }

if {$useHttps} {
    lappend args --cert $certFile --key $keyFile --tlsport $tlsport
}

puts ""
puts "mdserver Demo-Site"
puts "  Docs:  $docsDir"
puts "  HTTP:  http://localhost:$port/"
if {$useHttps} {
    puts "  HTTPS: https://localhost:$tlsport/"
    puts "  Cert:  $certFile"
}
puts ""

exec tclsh $mdserverScript {*}$args >@stdout 2>@stderr
