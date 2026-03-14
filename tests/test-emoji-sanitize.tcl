#!/usr/bin/env tclsh
# test-emoji-sanitize.tcl
# ============================================================
# Testet preprocessBytes und sanitize.
#
# Tcl 8.6 kann Emojis (>U+FFFF) nicht als String darstellen.
# Deshalb testen wir preprocessBytes auf BINARY-Ebene.
#
# Aufruf: tclsh test-emoji-sanitize.tcl
# ============================================================

set scriptDir [file dirname [file normalize [info script]]]
set libDir [file normalize [file join $scriptDir .. lib]]
set vendorDir [file normalize [file join $scriptDir .. vendors tm]]
tcl::tm::path add $libDir
tcl::tm::path add $vendorDir
package require pdf4tcllib 0.1

catch {::pdf4tcllib::fonts::init}

# ============================================================
# UTF-8 Bytes manuell erzeugen (Tcl 8.6 kompatibel)
# ============================================================

proc utf8 {codepoint} {
    # Erzeugt rohe UTF-8 Bytes fuer einen Codepoint.
    # Funktioniert auch fuer > U+FFFF (4-Byte Sequenzen).
    if {$codepoint <= 0x7F} {
        return [binary format c $codepoint]
    } elseif {$codepoint <= 0x7FF} {
        set b1 [expr {0xC0 | ($codepoint >> 6)}]
        set b2 [expr {0x80 | ($codepoint & 0x3F)}]
        return [binary format cc $b1 $b2]
    } elseif {$codepoint <= 0xFFFF} {
        set b1 [expr {0xE0 | ($codepoint >> 12)}]
        set b2 [expr {0x80 | (($codepoint >> 6) & 0x3F)}]
        set b3 [expr {0x80 | ($codepoint & 0x3F)}]
        return [binary format ccc $b1 $b2 $b3]
    } else {
        set b1 [expr {0xF0 | ($codepoint >> 18)}]
        set b2 [expr {0x80 | (($codepoint >> 12) & 0x3F)}]
        set b3 [expr {0x80 | (($codepoint >> 6) & 0x3F)}]
        set b4 [expr {0x80 | ($codepoint & 0x3F)}]
        return [binary format cccc $b1 $b2 $b3 $b4]
    }
}

# ============================================================
# Test-Framework
# ============================================================

set passed 0
set failed 0

proc test {name rawBytes expected} {
    upvar passed passed failed failed

    # preprocessBytes auf rohe Bytes anwenden
    set processed [::pdf4tcllib::unicode::preprocessBytes $rawBytes]
    # Zu String konvertieren
    set result [encoding convertfrom utf-8 $processed]

    if {$result eq $expected} {
        incr passed
        puts "  OK:   $name -> '$result'"
    } else {
        incr failed
        puts "  FAIL: $name"
        puts "        Erwartet: '$expected'"
        puts "        Erhalten: '$result'"
        # Zeige Bytes
        binary scan $rawBytes H* hexIn
        binary scan $processed H* hexOut
        puts "        Input:  $hexIn"
        puts "        Output: $hexOut"
    }
}

# ============================================================
# Tests: preprocessBytes
# ============================================================

puts "=== preprocessBytes Tests ==="
puts "Tcl: [info patchlevel]"
puts ""

# --- Smiley-Gesichter ---
test "Grinning 0x1F600"     [utf8 0x1F600]                     ":-)"
test "Beaming 0x1F601"      [utf8 0x1F601]                     ":-D"
test "Joy 0x1F602"          [utf8 0x1F602]                     ":'D"
test "Winking 0x1F609"      [utf8 0x1F609]                     ";-)"
test "Smiling 0x1F60A"      [utf8 0x1F60A]                     ":-)"
test "Heart Eyes 0x1F60D"   [utf8 0x1F60D]                     "<3"
test "Sunglasses 0x1F60E"   [utf8 0x1F60E]                     "B-)"
test "Tongue 0x1F61C"       [utf8 0x1F61C]                     ":-P"
test "Crying 0x1F622"       [utf8 0x1F622]                     ":-("
test "Loudly Crying 0x1F62D" [utf8 0x1F62D]                    ":'("
test "Open Mouth 0x1F62E"   [utf8 0x1F62E]                     ":-O"
test "Thinking 0x1F914"     [utf8 0x1F914]                     "(?)"
test "ROFL 0x1F923"         [utf8 0x1F923]                     ":'D"

# --- Objekte ---
test "Party 0x1F389"        [utf8 0x1F389]                     "(!)"
test "Thumbs Up 0x1F44D"    [utf8 0x1F44D]                     "(+1)"
test "Thumbs Down 0x1F44E"  [utf8 0x1F44E]                     "(-1)"
test "Fire 0x1F525"         [utf8 0x1F525]                     "(*)"
test "Rocket 0x1F680"       [utf8 0x1F680]                     {[>]}
test "Light Bulb 0x1F4A1"   [utf8 0x1F4A1]                     "(!)"
test "Lock 0x1F512"         [utf8 0x1F512]                     {[L]}
test "Memo 0x1F4DD"         [utf8 0x1F4DD]                     {[doc]}
test "Folder 0x1F4C1"       [utf8 0x1F4C1]                     {[D]}

# --- Gemischt: Emoji + ASCII ---
test "Text + Emoji" "Hallo [utf8 0x1F600] Welt"                "Hallo :-) Welt"
test "Emoji am Anfang" "[utf8 0x1F600] Text"                   ":-) Text"
test "Emoji am Ende" "Text [utf8 0x1F600]"                     "Text :-)"
test "Drei am Stueck" "[utf8 0x1F600][utf8 0x1F601][utf8 0x1F602]"  ":-):-D:'D"
test "Drei mit Space" "[utf8 0x1F600] [utf8 0x1F389] [utf8 0x1F44D]" ":-) (!) (+1)"

# --- Range-Fallbacks ---
test "Zipper Mouth 0x1F910" [utf8 0x1F910]                     ":-)"
test "Clown 0x1F921"        [utf8 0x1F921]                     ":-)"
test "Gift 0x1F381"         [utf8 0x1F381]                     "(!)"

# --- BMP bleibt unveraendert ---
test "ASCII pur" "Hello 123"                                    "Hello 123"
test "Umlaut" "\xC3\x84rger \xC3\x96l"                         "\u00C4rger \u00D6l"

# --- Kein Emoji (2-Byte und 3-Byte UTF-8 bleiben) ---
test "BMP Arrow" "\xE2\x86\x92"                                "\u2192"
test "BMP Checkmark" "\xE2\x9C\x93"                            "\u2713"

# ============================================================
# Tests: sanitize mit BMP-Zeichen (funktioniert normal)
# ============================================================

puts ""
puts "=== sanitize BMP-Tests ==="

proc testSanitize {name input expected} {
    upvar passed passed failed failed

    set result [::pdf4tcllib::unicode::sanitize $input]

    if {$result eq $expected} {
        incr passed
        puts "  OK:   $name -> '$result'"
    } else {
        incr failed
        puts "  FAIL: $name"
        puts "        Erwartet: '$expected'"
        puts "        Erhalten: '$result'"
    }
}

testSanitize "ASCII"            "Hello World 123"         "Hello World 123"
testSanitize "Leerer String"    ""                        ""
testSanitize "Checkmark 2705"   "\u2705"                  "\u2713"
testSanitize "Warning 26A0"     "\u26A0"                  "(!)"
testSanitize "Heart 2764"       "\u2764"                  "<3"
testSanitize "Star 2728"        "\u2728"                  "\u2605"
testSanitize "Arrow 2192"       "\u2192"                  "\u2192"
testSanitize "Gedankenstrich"   "\u2013"                  "\u2013"
testSanitize "Em-Dash"          "\u2014"                  "\u2014"
testSanitize "Ellipse"          "\u2026"                  "\u2026"
testSanitize "U+FFFD Fallback"  "\uFFFD"                  "(?)"

# ============================================================
# Ergebnis
# ============================================================

puts ""
puts "=== Ergebnis ==="
puts "Bestanden: $passed  Fehlgeschlagen: $failed"
if {$failed == 0} {
    puts "\nALLES OK"
} else {
    puts "\n$failed FEHLER"
}
