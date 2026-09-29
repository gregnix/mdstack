#!/usr/bin/env tclsh
# mdctl.tcl -- mdserver ueber den Steuerport ansprechen
# ============================================================================
# Usage:
#   tclsh mdctl.tcl ?--port 8099? ?--host 127.0.0.1? stop|ping
#
# Gedacht als ExecStop= in einer systemd-Unit:
#
#   ExecStop=/usr/bin/tclsh /opt/mdstack/tools/mdserver/mdctl.tcl --port 8099 stop
#
# Warum ein Skript und nicht "echo stop | nc":
#
#   OpenBSD-netcat -- das Standard-nc auf Debian und Ubuntu -- schliesst die
#   Senderichtung nach EOF auf stdin NICHT und wartet weiter. Gemessen am
#   28.09.2026:
#
#     echo ping | nc 127.0.0.1 8099        -> leer, laeuft in den Timeout
#     echo ping | nc -N 127.0.0.1 8099     -> pong
#
#   Ein ExecStop= ohne -N laeuft damit in TimeoutStopSec, und systemd schickt
#   danach SIGKILL -- genau das, was ein sauberes Beenden vermeiden soll. Das
#   -N kennen andere netcat-Varianten wieder nicht. Tcl ist da, wo mdserver
#   laeuft, also braucht es das Raten nicht.
#
# Rueckgabewert: 0 wenn die Antwort kam, 1 sonst. systemd braucht die 0.
# ============================================================================

set cfg(host)    "127.0.0.1"
set cfg(port)    ""
set cfg(timeout) 10000
set befehl ""

for {set i 0} {$i < [llength $argv]} {incr i} {
    switch -- [lindex $argv $i] {
        --host    { set cfg(host) [lindex $argv [incr i]] }
        --port    { set cfg(port) [lindex $argv [incr i]] }
        --timeout { set cfg(timeout) [lindex $argv [incr i]] }
        --help {
            puts "Usage: tclsh mdctl.tcl \[--host ADDR\] --port PORT stop|ping"
            puts "  --host    ADDR  Steuerport-Adresse (default: 127.0.0.1)"
            puts "  --port    PORT  Steuerport von mdserver (--control)"
            puts "  --timeout MS    Wartezeit auf die Antwort (default: 10000)"
            puts ""
            puts "  stop            mdserver beenden"
            puts "  ping            erreichbar? -> pong"
            exit 0
        }
        default { set befehl [lindex $argv $i] }
    }
}

if {$cfg(port) eq "" || $befehl eq ""} {
    puts stderr "Usage: tclsh mdctl.tcl \[--host ADDR\] --port PORT stop|ping"
    exit 1
}

if {[catch {socket $cfg(host) $cfg(port)} sock]} {
    puts stderr "mdctl: $cfg(host):$cfg(port) nicht erreichbar: $sock"
    exit 1
}

# Blockierend, aber mit Obergrenze: ein haengender Steuerport darf ExecStop
# nicht endlos aufhalten.
fconfigure $sock -translation crlf -buffering line -blocking 0
puts $sock $befehl
flush $sock

set ::antwort ""
set ::fertig 0
fileevent $sock readable {
    if {[gets $::sock zeile] >= 0} {
        set ::antwort [string trim $zeile]
        set ::fertig 1
    } elseif {[eof $::sock]} {
        set ::fertig 1
    }
}
set ::sock $sock
set wecker [after $cfg(timeout) {set ::fertig 1}]
vwait ::fertig
after cancel $wecker
catch {close $sock}

if {$::antwort eq ""} {
    puts stderr "mdctl: keine Antwort von $cfg(host):$cfg(port)"
    exit 1
}
puts $::antwort
exit 0
