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
    san     {}
    nosan   0
}

# ============================================================
# subjectAltName
# ============================================================
#
# Bis hierher setzte mkcert.tcl nur "-subj /CN=...". Aktuelle Browser lesen
# den CN nicht mehr als Hostnamen -- Chrome seit 58 (2017) -- sondern den
# subjectAltName. Ein Zertifikat ohne SAN wird darum abgelehnt, auch wenn man
# es in den Zertifikatspeicher importiert:
#
#     tclsh mkcert.tcl --cn mdstack.example.lan
#     openssl x509 -text | grep "Alternative Name"   -> nichts
#
# Jetzt entsteht der SAN aus dem CN, und --san haengt weitere an. Wer das
# alte Verhalten braucht, sagt --no-san ausdruecklich.

proc istIP {name} {
    if {[regexp {^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$} $name]} { return 1 }
    # IPv6 kommt ohne Punkt und mit mindestens einem Doppelpunkt
    if {[string first : $name] >= 0 && [string first . $name] < 0} { return 1 }
    return 0
}

# Ein Name wird zu "DNS:name" oder "IP:adresse".
proc sanEintrag {name} {
    return [expr {[istIP $name] ? "IP:$name" : "DNS:$name"}]
}

# Die Liste fuer -addext, ohne Doppelte und in der Reihenfolge der Eingabe.
proc sanListe {cn weitere} {
    set teile {}
    foreach n [concat [list $cn] $weitere] {
        set n [string trim $n]
        if {$n eq ""} continue
        set e [sanEintrag $n]
        if {[lsearch -exact $teile $e] < 0} { lappend teile $e }
    }
    # localhost wird ueber beide Wege aufgerufen: als Name und als 127.0.0.1
    if {[lsearch -exact $teile "DNS:localhost"] >= 0
            && [lsearch -exact $teile "IP:127.0.0.1"] < 0} {
        lappend teile "IP:127.0.0.1"
    }
    return [join $teile ,]
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
        --san   { lappend cfg(san) [lindex $argv [incr i]] }
        --no-san { set cfg(nosan) 1 }
        --help  {
            puts "Usage: tclsh mkcert.tcl \[options\]"
            puts "  --cn    NAME   Common Name / Hostname (default: localhost)"
            puts "  --san   NAME   Weiterer Name oder IP im subjectAltName."
            puts "                 Mehrfach angebbar. Der CN steht immer drin."
            puts "  --no-san       Ohne subjectAltName erzeugen. Browser lehnen"
            puts "                 ein solches Zertifikat ab -- nur fuer Werkzeuge,"
            puts "                 die noch den CN lesen."
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
            puts "  tclsh mkcert.tcl --cn mdstack --san 192.168.1.50 --san mdstack.lan"
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

# -addext gibt es seit OpenSSL 1.1.1. Ohne das koennte hier nur ein
# Zertifikat ohne SAN entstehen -- und das lehnen Browser ab. Darum Abbruch
# mit dem Weg daran vorbei, nicht stillschweigend das Falsche bauen.
set hatAddext 0
catch { if {[string match "*-addext*" [exec openssl req -help 2>@1]]} { set hatAddext 1 } }

# Steht ein subjectAltName im Zertifikat? Gibt die Zeile zurueck oder "".
proc sanVon {certFile} {
    if {[catch {exec openssl x509 -in $certFile -noout -ext subjectAltName} z]} {
        # aeltere openssl kennen -ext nicht: dann im ganzen Text suchen
        if {[catch {exec openssl x509 -in $certFile -noout -text} t]} { return "" }
        set nimm 0
        foreach zeile [split $t \n] {
            if {$nimm} { return [string trim $zeile] }
            if {[string match "*Subject Alternative Name*" $zeile]} { set nimm 1 }
        }
        return ""
    }
    foreach zeile [split $z \n] {
        set zeile [string trim $zeile]
        if {[string match "DNS:*" $zeile] || [string match "IP*:*" $zeile]} { return $zeile }
    }
    return ""
}

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
    set san [sanVon $certFile]
    if {$san eq ""} {
        # Nicht "OK" sagen: das Zertifikat ist zwar gueltig, aber kein
        # aktueller Browser akzeptiert es -- ohne SAN gibt es keinen
        # Hostnamen, gegen den er pruefen koennte.
        puts "GUELTIG, ABER OHNE subjectAltName: $certFile"
        puts $result
        puts ""
        puts "Browser lehnen es ab (ERR_CERT_COMMON_NAME_INVALID), auch nach Import."
        puts "Neu erzeugen:"
        puts "  rm $certFile $keyFile"
        puts "  tclsh mkcert.tcl --cn <name> \[--san <weiterer name oder IP>\]"
        exit 1
    }
    puts "OK: $certFile"
    puts $result
    puts "  SAN: $san"
    exit 0
}

# ============================================================
# Vorhandenes Zertifikat pruefen
# ============================================================

if {[file exists $certFile] && [file exists $keyFile]} {
    puts "Vorhandenes Zertifikat gefunden: $certFile"

    # Ohne SAN ist es fuer Browser unbrauchbar -- dann nicht stehenlassen,
    # sondern neu erzeugen, auch wenn das Datum noch stimmt.
    if {!$cfg(nosan) && [sanVon $certFile] eq ""} {
        puts "  --> ohne subjectAltName, wird neu erzeugt."
    } elseif {![catch {
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

set san ""
if {!$cfg(nosan)} {
    if {!$hatAddext} {
        puts stderr "ERROR: dieses openssl kennt -addext nicht (seit 1.1.1)."
        puts stderr "       Ohne -addext entsteht ein Zertifikat ohne subjectAltName,"
        puts stderr "       das aktuelle Browser ablehnen."
        puts stderr "       Neueres openssl verwenden -- oder bewusst: --no-san"
        exit 1
    }
    set san [sanListe $cfg(cn) $cfg(san)]
}

puts ""
puts "Erzeuge selbstsigniertes Zertifikat:"
puts "  CN:   $cfg(cn)"
if {$san ne ""} {
    puts "  SAN:  $san"
} else {
    puts "  SAN:  (keiner -- --no-san; Browser lehnen das ab)"
}
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
if {$san ne ""} { lappend cmd -addext "subjectAltName=$san" }

if {[catch {exec {*}$cmd 2>@stdout} result]} {
    # openssl schreibt Fortschritt auf stderr -- kein echter Fehler
    # Zertifikat trotzdem pruefen
}

# Ergebnis pruefen
if {![file exists $certFile] || ![file exists $keyFile]} {
    puts stderr "ERROR: Zertifikat konnte nicht erzeugt werden."
    exit 1
}

# Nicht behaupten, sondern nachsehen: steht der SAN wirklich im Zertifikat?
if {$san ne ""} {
    set drin [sanVon $certFile]
    if {$drin eq ""} {
        puts stderr "ERROR: openssl hat den subjectAltName nicht gesetzt."
        puts stderr "       Angefordert war: $san"
        puts stderr "       Das Zertifikat waere fuer Browser unbrauchbar."
        exit 1
    }
    puts "SAN im Zertifikat: $drin"
}

puts "Fertig."
puts ""
puts "Dateien:"
puts "  $certFile  ([file size $certFile] Bytes)"
puts "  $keyFile   ([file size $keyFile] Bytes)"
puts ""
puts "mdserver starten:"
puts "  tclsh mdserver.tcl --cert $certFile --key $keyFile"
