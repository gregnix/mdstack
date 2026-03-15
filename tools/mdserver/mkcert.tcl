#!/usr/bin/env tclsh
# mkcert.tcl -- Selbstsigniertes TLS-Zertifikat erzeugen
# ============================================================================
# Erzeugt server.crt und server.key fuer mdserver HTTPS.
#
# Usage:
#   tclsh mkcert.tcl
#   tclsh mkcert.tcl --cn localhost
#   tclsh mkcert.tcl --cn example.com --days 730 --out /pfad/
#   tclsh mkcert.tcl --check   (nur pruefen ob Zertifikat noch gueltig)
# ============================================================================

# ============================================================
# Defaults
# ============================================================

array set cfg {
    cn      "localhost"
    days    365
    bits    4096
    out     "."
    cert    "server.crt"
    key     "server.key"
    check   0
}

# CLI-Argumente
set i 0
while {$i < [llength $argv]} {
    switch [lindex $argv $i] {
        --cn    { set cfg(cn)   [lindex $argv [incr i]] }
        --days  { set cfg(days) [lindex $argv [incr i]] }
        --bits  { set cfg(bits) [lindex $argv [incr i]] }
        --out   { set cfg(out)  [lindex $argv [incr i]] }
        --cert  { set cfg(cert) [lindex $argv [incr i]] }
        --key   { set cfg(key)  [lindex $argv [incr i]] }
        --check { set cfg(check) 1 }
        --help  {
            puts "Usage: tclsh mkcert.tcl \[options\]"
            puts "  --cn    NAME   Common Name / Hostname (default: localhost)"
            puts "  --days  N      Gueltigkeitsdauer in Tagen (default: 365)"
            puts "  --bits  N      RSA-Schluesselbits (default: 4096)"
            puts "  --out   DIR    Ausgabeverzeichnis (default: .)"
            puts "  --cert  FILE   Zertifikat-Dateiname (default: server.crt)"
            puts "  --key   FILE   Key-Dateiname (default: server.key)"
            puts "  --check        Nur Gueltigkeit pruefen, nicht neu erzeugen"
            puts ""
            puts "Beispiel:"
            puts "  tclsh mkcert.tcl"
            puts "  tclsh mkcert.tcl --cn meinserver.local --days 730"
            exit 0
        }
    }
    incr i
}

set certFile [file normalize [file join $cfg(out) $cfg(cert)]]
set keyFile  [file normalize [file join $cfg(out) $cfg(key)]]

# ============================================================
# openssl pruefen
# ============================================================

if {[catch {exec openssl version} opensslVersion]} {
    puts stderr "ERROR: openssl nicht gefunden."
    puts stderr "       apt install openssl  (Debian/Ubuntu)"
    puts stderr "       brew install openssl (macOS)"
    exit 1
}
puts "openssl: [string trim $opensslVersion]"

# ============================================================
# --check: nur Gueltigkeit pruefen
# ============================================================

if {$cfg(check)} {
    if {![file exists $certFile]} {
        puts "FEHLT: $certFile"
        exit 1
    }
    if {[catch {
        exec openssl x509 -in $certFile -noout \
            -subject -enddate -checkend 0
    } result]} {
        puts "ABGELAUFEN oder ungueltig: $certFile"
        puts $result
        exit 1
    }
    puts "OK: $certFile"
    puts $result
    exit 0
}

# ============================================================
# Vorhandenes Zertifikat pruefen
# ============================================================

if {[file exists $certFile] && [file exists $keyFile]} {
    puts "Vorhandenes Zertifikat gefunden: $certFile"

    # Noch gueltig?
    if {![catch {
        exec openssl x509 -in $certFile -noout -checkend 0
    }]} {
        # Ablaufdatum lesen
        catch {
            exec openssl x509 -in $certFile -noout -enddate
        } enddate
        puts "  Gueltig bis: [string trim [lindex [split $enddate =] 1]]"
        puts ""
        puts "Zertifikat ist noch gueltig."
        puts "Zum Neuerstellen: Dateien loeschen und erneut ausfuehren."
        puts "  rm $certFile $keyFile"
        exit 0
    } else {
        puts "  --> abgelaufen, wird neu erzeugt."
    }
}

# ============================================================
# Zertifikat erzeugen
# ============================================================

puts ""
puts "Erzeuge selbstsigniertes Zertifikat:"
puts "  CN:   $cfg(cn)"
puts "  Tage: $cfg(days)"
puts "  Bits: $cfg(bits)"
puts "  Cert: $certFile"
puts "  Key:  $keyFile"
puts ""

set cmd [list openssl req \
    -x509 \
    -newkey rsa:$cfg(bits) \
    -keyout $keyFile \
    -out    $certFile \
    -days   $cfg(days) \
    -nodes \
    -subj   "/CN=$cfg(cn)"]

if {[catch {exec {*}$cmd 2>@stdout} result]} {
    # openssl schreibt Fortschritt auf stderr -- kein echter Fehler
    # Zertifikat trotzdem pruefen
}

# Ergebnis pruefen
if {![file exists $certFile] || ![file exists $keyFile]} {
    puts stderr "ERROR: Zertifikat konnte nicht erzeugt werden."
    exit 1
}

puts "Fertig."
puts ""
puts "Dateien:"
puts "  $certFile  ([file size $certFile] Bytes)"
puts "  $keyFile   ([file size $keyFile] Bytes)"
puts ""
puts "mdserver starten:"
puts "  tclsh mdserver.tcl --cert $certFile --key $keyFile"
