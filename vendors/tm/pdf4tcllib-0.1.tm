# pdf4tcllib-0.1.tm -- Extension library for pdf4tcl
#
# Single file: all modules in one file.
# No external dependencies except pdf4tcl itself.
#
# Modules (as namespaces):
#   pdf4tcllib::fonts    Font management (TTF + fallback)
#   pdf4tcllib::unicode  Unicode sanitization
#   pdf4tcllib::text     Text layout (wrapping, width, tabs)
#   pdf4tcllib::table    Table rendering
#   pdf4tcllib::image    Image integration (Tk)
#   pdf4tcllib::page     Page numbers, header/footer
#   pdf4tcllib::drawing  Drawing functions
#   pdf4tcllib::units    Unit conversion
#
# Usage:
#   package require pdf4tcllib 0.1
#   pdf4tcllib::fonts::init
#   set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]
#   $pdf startPage
#   $pdf setFont 12 [pdf4tcllib::fonts::fontSans]
#   pdf4tcllib::unicode::safeText $pdf "Text" -x 50 -y 50
#   $pdf write -file out.pdf
#   $pdf destroy

package require Tcl 8.6-
package provide pdf4tcllib 0.1

namespace eval ::pdf4tcllib {
    variable version 0.1
}

proc ::pdf4tcllib::version {} {
    variable version
    return $version
}

proc ::pdf4tcllib::validate_pdf {file} {
    # Checks if a PDF file is valid.
    # Returns a dict: valid (0/1), size, error.

    if {![file exists $file]} {
        return [dict create valid 0 size 0 error "File not found"]
    }
    set size [file size $file]
    if {$size == 0} {
        return [dict create valid 0 size 0 error "File is empty"]
    }
    set fp [open $file rb]
    set header [read $fp 8]
    close $fp
    if {![string match "%PDF-*" $header]} {
        return [dict create valid 0 size $size error "Invalid PDF header"]
    }
    return [dict create valid 1 size $size error ""]
}

# ================================================================
# Module: pdf4tcllib::units
# ================================================================

# pdf4tcllib::units -- Unit conversion for pdf4tcl
#
# PDF arbeitet intern in Points (1/72 Zoll).
# This module converts between points, millimeters, centimeters and inches.
#
# Usage:
#   package require pdf4tcllib::units 0.1
#   set x [pdf4tcllib::units::mm 25.4]    ;# -> 72.0 (1 Zoll)
#   set y [pdf4tcllib::units::cm 2.54]    ;# -> 72.0
#   set m [pdf4tcllib::units::to_mm 72.0] ;# -> 25.4


namespace eval ::pdf4tcllib::units {}

proc ::pdf4tcllib::units::mm {val} {
    # Millimeter -> Points
    return [expr {$val * 72.0 / 25.4}]
}

proc ::pdf4tcllib::units::cm {val} {
    # Zentimeter -> Points
    return [expr {$val * 72.0 / 2.54}]
}

proc ::pdf4tcllib::units::inch {val} {
    # Zoll -> Points
    return [expr {$val * 72.0}]
}

proc ::pdf4tcllib::units::to_mm {pt} {
    # Points -> Millimeter
    return [expr {$pt * 25.4 / 72.0}]
}

proc ::pdf4tcllib::units::to_cm {pt} {
    # Points -> Zentimeter
    return [expr {$pt * 2.54 / 72.0}]
}

proc ::pdf4tcllib::units::to_inch {pt} {
    # Points -> Zoll
    return [expr {$pt / 72.0}]
}

# ================================================================
# Module: pdf4tcllib::fonts
# ================================================================

# pdf4tcllib::fonts -- Font management for pdf4tcl
#
# Encapsulates TTF font handling:
#   - Cross-platform font search
#   - Automatic subset construction (256 characters)
#   - Registrierung in pdf4tcl
#   - Fallback to Helvetica/Courier
#
# Usage:
#   package require pdf4tcllib::fonts 0.1
#   pdf4tcllib::fonts::init ?-fontdir /pfad? ?-family DejaVuSansCondensed?
#   set fn [pdf4tcllib::fonts::fontSans]     ;# -> "Pdf4tclSans" or "Helvetica"
#   set ok [pdf4tcllib::fonts::inSubset 8594] ;# -> 1 (Pfeil rechts)

package require pdf4tcl

namespace eval ::pdf4tcllib::fonts {

    # Module directory (for relative font paths)
    variable moduleDir [file dirname [file normalize [info script]]]

    # Font names (set by init)
    variable fontSans           "Helvetica"
    variable fontSansBold       "Helvetica-Bold"
    variable fontSansItalic     "Helvetica-Oblique"
    variable fontSansBoldItalic "Helvetica-BoldOblique"
    variable fontMono           "Courier"
    variable hasTtf             0
    variable hasTtfItalic       0
    variable ready              0

    # Subset-Lookup (Array: codepoint -> 1)
    variable subsetSet
    array set subsetSet {}

    # Subset list (for external query)
    variable subsetList {}

    # Width factors for fonts (factor * fontSize = average character width)
    # Etwas grosszuegiger als exakt, damit wrap/truncate sicher passen.
    variable fontWidthFactor
    array set fontWidthFactor {
        Helvetica              0.58
        Helvetica-Bold         0.64
        Helvetica-Oblique      0.58
        Helvetica-BoldOblique  0.64
        Courier                0.60
        Pdf4tclSans            0.56
        Pdf4tclSansBold        0.60
        Pdf4tclSansItalic      0.56
        Pdf4tclSansBoldItalic  0.60
    }

    # Registered font base names (for cleanup)
    variable registeredFonts {}
}

# ============================================================
# Oeffentliche API
# ============================================================

proc ::pdf4tcllib::fonts::init {args} {
    # Initialize fonts. Only active on first call.
    #
    # Optionen:
    #   -fontdir  Directory with TTF fonts
    #   -family   Font family (default: DejaVuSansCondensed)
    #   -force    1 = nochmal initialisieren also if schon fertig

    variable ready
    variable moduleDir
    variable fontSans
    variable fontSansBold
    variable fontSansItalic
    variable fontSansBoldItalic
    variable fontMono
    variable hasTtf
    variable hasTtfItalic
    variable subsetSet
    variable subsetList
    variable registeredFonts

    array set opt {
        -fontdir  ""
        -family   "DejaVuSansCondensed"
        -force    0
    }
    array set opt $args

    if {$ready && !$opt(-force)} { return }

    # -- Search for TTF files --
    set family $opt(-family)
    set ttfRegular   ""
    set ttfBold      ""
    set ttfItalic    ""
    set ttfBoldItalic ""

    set searchPaths [_buildSearchPaths $opt(-fontdir)]

    foreach dir $searchPaths {
        if {![file isdirectory $dir]} { continue }
        set tryR [file join $dir "${family}.ttf"]
        set tryB [file join $dir "${family}-Bold.ttf"]
        if {[file exists $tryR] && [file exists $tryB]} {
            set ttfRegular $tryR
            set ttfBold    $tryB
            # Optional: Oblique variants (same dir)
            set tryI  [file join $dir "${family}-Oblique.ttf"]
            set tryBI [file join $dir "${family}-BoldOblique.ttf"]
            if {[file exists $tryI]}  { set ttfItalic    $tryI }
            if {[file exists $tryBI]} { set ttfBoldItalic $tryBI }
            break
        }
    }

    if {$ttfRegular eq ""} {
        # No TTF found -> fallback
        set fontSans           "Helvetica"
        set fontSansBold       "Helvetica-Bold"
        set fontSansItalic     "Helvetica-Oblique"
        set fontSansBoldItalic "Helvetica-BoldOblique"
        set fontMono           "Courier"
        set hasTtf             0
        set hasTtfItalic       0
        set ready              1
        puts stderr "pdf4tcllib::fonts: No TTF fonts found, falling back to Helvetica"
        puts stderr "pdf4tcllib::fonts: Gesucht in:"
        foreach dir $searchPaths {
            if {[file isdirectory $dir]} {set marker "exists"} else {set marker "---"}
            puts stderr "pdf4tcllib::fonts:   \[$marker\] $dir"
        }
        return
    }

    # -- Subset aufbauen --
    set subsetList [_buildSubset]
    array unset subsetSet
    foreach cp $subsetList {
        set subsetSet($cp) 1
    }

    # -- Register fonts in pdf4tcl --
    if {[catch {
        set existingFonts {}
        catch {set existingFonts [::pdf4tcl::getFonts]}

        if {"Pdf4tclSans" ni $existingFonts} {
            ::pdf4tcl::loadBaseTrueTypeFont _Pdf4tcl_Base_Regular $ttfRegular
            ::pdf4tcl::createFontSpecEnc _Pdf4tcl_Base_Regular Pdf4tclSans $subsetList
            lappend registeredFonts Pdf4tclSans
        }

        if {"Pdf4tclSansBold" ni $existingFonts} {
            ::pdf4tcl::loadBaseTrueTypeFont _Pdf4tcl_Base_Bold $ttfBold
            ::pdf4tcl::createFontSpecEnc _Pdf4tcl_Base_Bold Pdf4tclSansBold $subsetList
            lappend registeredFonts Pdf4tclSansBold
        }

        set fontSans     "Pdf4tclSans"
        set fontSansBold "Pdf4tclSansBold"
        set fontMono     "Courier"
        set hasTtf       1

        # Italic TTF (optional -- Oblique variants)
        set hasTtfItalic 0
        if {$ttfItalic ne "" && $ttfBoldItalic ne ""} {
            if {[catch {
                if {"Pdf4tclSansItalic" ni $existingFonts} {
                    ::pdf4tcl::loadBaseTrueTypeFont _Pdf4tcl_Base_Italic $ttfItalic
                    ::pdf4tcl::createFontSpecEnc _Pdf4tcl_Base_Italic Pdf4tclSansItalic $subsetList
                    lappend registeredFonts Pdf4tclSansItalic
                }
                if {"Pdf4tclSansBoldItalic" ni $existingFonts} {
                    ::pdf4tcl::loadBaseTrueTypeFont _Pdf4tcl_Base_BoldItalic $ttfBoldItalic
                    ::pdf4tcl::createFontSpecEnc _Pdf4tcl_Base_BoldItalic Pdf4tclSansBoldItalic $subsetList
                    lappend registeredFonts Pdf4tclSansBoldItalic
                }
                set fontSansItalic     "Pdf4tclSansItalic"
                set fontSansBoldItalic "Pdf4tclSansBoldItalic"
                set hasTtfItalic 1
                puts stderr "pdf4tcllib::fonts: TTF-Italic-Fonts geladen"
            } errI]} {
                set fontSansItalic     "Helvetica-Oblique"
                set fontSansBoldItalic "Helvetica-BoldOblique"
                puts stderr "pdf4tcllib::fonts: TTF-Italic Fehler: $errI -- Fallback Helvetica-Oblique"
            }
        } else {
            set fontSansItalic     "Helvetica-Oblique"
            set fontSansBoldItalic "Helvetica-BoldOblique"
        }

        puts stderr "pdf4tcllib::fonts: TTF-Fonts geladen from [file dirname $ttfRegular]"

    } err]} {
        set fontSans           "Helvetica"
        set fontSansBold       "Helvetica-Bold"
        set fontSansItalic     "Helvetica-Oblique"
        set fontSansBoldItalic "Helvetica-BoldOblique"
        set fontMono           "Courier"
        set hasTtf             0
        set hasTtfItalic       0
        puts stderr "pdf4tcllib::fonts: TTF error: $err"
        puts stderr "pdf4tcllib::fonts: Fallback on Helvetica"
    }

    set ready 1
}

proc ::pdf4tcllib::fonts::hasTtf {} {
    # Returns 1 if TTF fonts are loaded.
    variable hasTtf
    return $hasTtf
}

proc ::pdf4tcllib::fonts::hasTtfItalic {} {
    # Returns 1 if TTF italic fonts are loaded.
    variable hasTtfItalic
    return $hasTtfItalic
}

proc ::pdf4tcllib::fonts::fontSans {} {
    # Returns the name of the sans-serif font.
    variable fontSans
    return $fontSans
}

proc ::pdf4tcllib::fonts::fontSansBold {} {
    # Returns the name of the bold sans-serif font.
    variable fontSansBold
    return $fontSansBold
}

proc ::pdf4tcllib::fonts::fontSansItalic {} {
    # Returns the name of the italic sans-serif font.
    variable fontSansItalic
    return $fontSansItalic
}

proc ::pdf4tcllib::fonts::fontSansBoldItalic {} {
    # Returns the name of the bold-italic sans-serif font.
    variable fontSansBoldItalic
    return $fontSansBoldItalic
}

proc ::pdf4tcllib::fonts::fontMono {} {
    # Returns the name of the monospace font.
    variable fontMono
    return $fontMono
}

proc ::pdf4tcllib::fonts::isMonospace {fontName} {
    # Checks if a font is monospace.
    variable fontMono
    return [expr {$fontName eq $fontMono || $fontName eq "Courier"}]
}

proc ::pdf4tcllib::fonts::subset {} {
    # Returns the list of codepoints in the subset.
    variable subsetList
    return $subsetList
}

proc ::pdf4tcllib::fonts::inSubset {cp} {
    # Checks if a codepoint is in the subset.
    variable subsetSet
    return [info exists subsetSet($cp)]
}

proc ::pdf4tcllib::fonts::widthFactor {fontName} {
    # Returns the width factor for a font.
    # Factor * fontSize = average character width in points.
    variable fontWidthFactor
    if {[info exists fontWidthFactor($fontName)]} {
        return $fontWidthFactor($fontName)
    }
    return 0.52  ;# Default
}

proc ::pdf4tcllib::fonts::ready {} {
    # Returns 1 if init ausgefuehrt wurde.
    variable ready
    return $ready
}

# ============================================================
# Private Helfer
# ============================================================

proc ::pdf4tcllib::fonts::_buildSearchPaths {fontDir} {
    # Builds platform-specific list of font directories.
    variable moduleDir
    set paths {}

    # 1. Explicitly provided directory
    if {$fontDir ne "" && [file isdirectory $fontDir]} {
        lappend paths $fontDir
    }

    # 2. Relativ zum Modul
    lappend paths [file join $moduleDir .. fonts]
    lappend paths [file join $moduleDir fonts]

    # 3. Plattform-spezifisch
    switch -- $::tcl_platform(platform) {
        unix {
            # Debian/Ubuntu
            lappend paths "/usr/share/fonts/truetype/dejavu"
            # Fedora/RHEL
            lappend paths "/usr/share/fonts/dejavu-sans-fonts"
            # Arch
            lappend paths "/usr/share/fonts/TTF"
            # Generisch
            lappend paths "/usr/share/fonts/truetype"
            # User fonts
            if {[info exists ::env(HOME)]} {
                lappend paths [file join $::env(HOME) ".fonts"]
                lappend paths [file join $::env(HOME) ".local" "share" "fonts"]
            }
        }
        windows {
            if {[info exists ::env(SystemRoot)]} {
                lappend paths [file join $::env(SystemRoot) "Fonts"]
            }
            if {[info exists ::env(LOCALAPPDATA)]} {
                lappend paths [file join $::env(LOCALAPPDATA) "Microsoft" "Windows" "Fonts"]
            }
        }
    }
    # macOS (auch unix, but extra)
    if {$::tcl_platform(os) eq "Darwin"} {
        lappend paths "/Library/Fonts"
        lappend paths "/System/Library/Fonts"
        if {[info exists ::env(HOME)]} {
            lappend paths [file join $::env(HOME) "Library" "Fonts"]
        }
    }

    return $paths
}

proc ::pdf4tcllib::fonts::_buildSubset {} {
    # Builds the 256-character subset list for createFontSpecEnc.
    #
    # Aufbau:
    #   0x00-0x7F:  ASCII (128 characters)
    #   0xA0-0xFF:  Latin-1 supplement (96 characters)
    #   Rest:       Selected symbols (32 characters)
    #
    # Gesamt: 256 = Maximum for a pdf4tcl encoding

    set subset {}

    # ASCII (0-127)
    for {set i 0} {$i < 128} {incr i} {
        lappend subset $i
    }

    # Latin-1 Supplement (0xA0-0xFF): accents, copyright, degree etc.
    for {set i 0xA0} {$i <= 0xFF} {incr i} {
        lappend subset $i
    }

    # Erweiterte Symbole (32 Stueck)
    # Jeder Wert MUSS als Integer (nicht String) gespeichert werden!
    lappend subset [expr {0x20AC}]  ;# Euro
    lappend subset [expr {0x2013}]  ;# Halbgeviertstrich (en dash)
    lappend subset [expr {0x2014}]  ;# Geviertstrich (em dash)
    lappend subset [expr {0x2026}]  ;# Auslassungspunkte
    lappend subset [expr {0x2022}]  ;# Aufzaehlungspunkt (bullet)

    lappend subset [expr {0x2192}]  ;# Pfeil rechts
    lappend subset [expr {0x2190}]  ;# Pfeil links
    lappend subset [expr {0x2191}]  ;# Pfeil hoch
    lappend subset [expr {0x2193}]  ;# Pfeil runter

    lappend subset [expr {0x2500}]  ;# Horizontale Linie
    lappend subset [expr {0x2502}]  ;# Vertikale Linie
    lappend subset [expr {0x250C}]  ;# Ecke oben links
    lappend subset [expr {0x2510}]  ;# Ecke oben rechts
    lappend subset [expr {0x2514}]  ;# Ecke unten links
    lappend subset [expr {0x2518}]  ;# Ecke unten rechts
    lappend subset [expr {0x251C}]  ;# T links
    lappend subset [expr {0x2524}]  ;# T rechts
    lappend subset [expr {0x252C}]  ;# T oben
    lappend subset [expr {0x2534}]  ;# T unten
    lappend subset [expr {0x253C}]  ;# Kreuz

    lappend subset [expr {0x2713}]  ;# Haekchen
    lappend subset [expr {0x2717}]  ;# Kreuzchen
    lappend subset [expr {0x2611}]  ;# Checkbox angehakt
    lappend subset [expr {0x2610}]  ;# Checkbox leer

    lappend subset [expr {0x25A0}]  ;# Schwarzes Quadrat
    lappend subset [expr {0x25A1}]  ;# Weisses Quadrat
    lappend subset [expr {0x25CF}]  ;# Schwarzer Kreis
    lappend subset [expr {0x25CB}]  ;# Weisser Kreis

    lappend subset [expr {0x2264}]  ;# Kleiner gleich
    lappend subset [expr {0x2265}]  ;# Groesser gleich
    lappend subset [expr {0x2605}]  ;# Schwarzer Stern
    lappend subset [expr {0x2606}]  ;# Weisser Stern

    return $subset
}

# ================================================================
# Module: pdf4tcllib::unicode
# ================================================================

# pdf4tcllib::unicode -- Unicode sanitization for pdf4tcl
#
# Prevents crashes from characters that pdf4tcl cannot render.
# Zwei Strategien:
#   1. Replace known symbols with ASCII equivalents
#   2. Unknown characters as "?" render
#
# Usage:
#   package require pdf4tcllib::unicode 0.1
#   set clean [pdf4tcllib::unicode::sanitize $text]
#   set clean [pdf4tcllib::unicode::sanitize $text -mono 1]
#   pdf4tcllib::unicode::safeText $pdfObj $text -x 50 -y 100


namespace eval ::pdf4tcllib::unicode {}

# ============================================================
# Oeffentliche API
# ============================================================

proc ::pdf4tcllib::unicode::sanitize {line args} {
    # Replaces/removes Unicode characters that the current font
    # not darstellbar sind.
    #
    # Optionen:
    #   -mono 0/1   Monospace mode (Courier): always ASCII replacement
    #
    # Zwei Modi:
    #   TTF-Modus (hasTtf=1, mono=0):
    #     Subset characters native, map variants to subset,
    #     unbekannte -> "?"
    #   Base-Modus (hasTtf=0 or mono=1):
    #     Replace all symbols > U+00FF with ASCII,
    #     only WinAnsi-Bereich durchlassen

    array set opt {-mono 0}
    array set opt $args

    set hasTtf [::pdf4tcllib::fonts::hasTtf]
    set effectiveTtf [expr {$hasTtf && !$opt(-mono)}]

    # -- Stage 1: Replace known symbols --

    if {!$effectiveTtf} {
        # Base mode: replace everything that doesn't fit WinAnsi

        # Box-drawing characters
        set line [string map {
            "\u2500" "-"
            "\u2501" "-"
            "\u2502" "|"
            "\u2503" "|"
            "\u250C" "+"
            "\u2510" "+"
            "\u2514" "+"
            "\u2518" "+"
            "\u251C" "|"
            "\u2524" "|"
            "\u252C" "+"
            "\u2534" "+"
            "\u253C" "+"
        } $line]

        # Haeufige Unicode-Symbole
        set line [string map {
            "\u2192" "->"
            "\u2190" "<-"
            "\u2191" "^"
            "\u2193" "v"
            "\u2022" "*"
            "\u00B7" "."
            "\u2026" "..."
            "\u2014" "--"
            "\u2013" "-"
            "\u2713" "[x]"
            "\u2717" "[ ]"
            "\u2611" "[x]"
            "\u2610" "[ ]"
            "\u2605" "*"
            "\u2606" "*"
            "\u25B6" ">"
            "\u25C0" "<"
            "\u25BA" ">"
            "\u25C4" "<"
            "\u25CF" "o"
            "\u25CB" "o"
            "\u25A0" "#"
            "\u25A1" "#"
            "\u25AA" "-"
            "\u25AB" "-"
        } $line]

        # Common emojis and special characters
        set line [string map {
            "\u274C" "(X)"
            "\u274E" "(X)"
            "\u2705" "(OK)"
            "\u2714" "(OK)"
            "\u26A0" "(!)"
            "\u2757" "(!)"
            "\u2753" "(?)"
            "\u2139" "(i)"
            "\u27A1" "->"
            "\u2B05" "<-"
            "\u2B06" "^"
            "\u2B07" "v"
            "\u2764" "<3"
            "\u2728" "*"
            "\u26A1" "*"
            "\u2699" "[*]"
            "\u267B" "[R]"
            "\u00A9" "(c)"
            "\u00AE" "(R)"
            "\u2122" "(TM)"
            "\u20AC" "EUR"
            "\u201E" "\""
            "\u201C" "\""
            "\u201D" "\""
            "\u201A" "'"
            "\u2018" "'"
            "\u2019" "'"
        } $line]
    } else {
        # TTF-Modus: Nur Varianten on Subset-Zeichen mappen.
        # character im Subset werden nativ dargestellt.

        set line [string map {
            "\u2501" "\u2500"
            "\u2503" "\u2502"
            "\u25BA" ">"
            "\u25C4" "<"
            "\u25AA" "\u25A0"
            "\u25AB" "\u25A1"
            "\u274C" "(X)"
            "\u274E" "(X)"
            "\u2705" "\u2713"
            "\u2714" "\u2713"
            "\u2757" "(!)"
            "\u2753" "(?)"
            "\u2139" "(i)"
            "\u27A1" "\u2192"
            "\u2B05" "\u2190"
            "\u2B06" "\u2191"
            "\u2B07" "\u2193"
            "\u2764" "<3"
            "\u2728" "\u2605"
            "\u26A0" "(!)"
            "\u26A1" "\u2605"
            "\u2699" "[*]"
            "\u267B" "[R]"
            "\u2122" "(TM)"
            "\u201E" "\""
            "\u201C" "\""
            "\u201D" "\""
            "\u201A" "'"
            "\u2018" "'"
            "\u2019" "'"
        } $line]
    }

    # -- Stage 2: Catch-All --
    # Check each character individually.
    # Only pass through characters the active font can render.
    # Surrogate-Paare (Tcl 8.6, TCL_UTF_MAX=3) werden als Emoji erkannt.

    set result ""
    set chars [split $line ""]
    set len [llength $chars]
    for {set i 0} {$i < $len} {incr i} {
        set c [lindex $chars $i]
        set cp [scan $c %c]

        # Unsichtbare Steuerzeichen entfernen
        if {($cp >= 0xFE00 && $cp <= 0xFE0F) ||
            ($cp >= 0x200B && $cp <= 0x200F) ||
            $cp == 0xFEFF} {
            continue
        }

        # Surrogate-Paar erkennen (Tcl 8.6 Emoji-Handling)
        if {$cp >= 0xD800 && $cp <= 0xDBFF} {
            # High surrogate — after Low surrogate schauen
            set j [expr {$i + 1}]
            if {$j < $len} {
                set c2 [lindex $chars $j]
                set cp2 [scan $c2 %c]
                if {$cp2 >= 0xDC00 && $cp2 <= 0xDFFF} {
                    # Gueltige Surrogate-Pair -> echten Codepoint berechnen
                    set fullCp [expr {(($cp - 0xD800) << 10) + ($cp2 - 0xDC00) + 0x10000}]
                    append result [::pdf4tcllib::unicode::_emojiFallback $fullCp]
                    incr i  ;# Low surrogate ueberspringen
                    continue
                }
            }
            # Single high surrogate -> skip
            continue
        } elseif {$cp >= 0xDC00 && $cp <= 0xDFFF} {
            # Single low surrogate -> skip
            continue
        }

        if {$effectiveTtf} {
            # U+FFFD: Tcl 8.6 hat ein Emoji zerstoert.
            # Kann not mehr rekonstruiert werden.
            # Tipp: preprocessBytes vor encoding convertfrom verwenden.
            if {$cp == 0xFFFD} {
                append result "(?)"
                continue
            }
            # Nicht-BMP character (TCL_UTF_MAX=4: direkte Codepoints > 0xFFFF)
            # Bei TCL_UTF_MAX=3 kommen diese als Surrogate-Paare (oben behandelt)
            if {$cp > 0xFFFF} {
                append result [::pdf4tcllib::unicode::_emojiFallback $cp]
                continue
            }
            # TTF-Modus: Nur Subset-Zeichen durchlassen
            if {[::pdf4tcllib::fonts::inSubset $cp]} {
                append result $c
            } else {
                append result "?"
            }
        } else {
            # U+FFFD also im Base-Modus abfangen
            if {$cp == 0xFFFD} {
                append result "(?)"
                continue
            }
            # Nicht-BMP character also im Base-Modus abfangen
            if {$cp > 0xFFFF} {
                append result [::pdf4tcllib::unicode::_emojiFallback $cp]
                continue
            }
            # Base-Modus (WinAnsiEncoding):
            # ASCII druckbar (0x20-0x7E) + Latin-1 Supplement (0xA0-0xFF)
            if {($cp >= 0x20 && $cp <= 0x7E) ||
                ($cp >= 0xA0 && $cp <= 0xFF)} {
                append result $c
            } elseif {$cp == 0x09 || $cp == 0x0A || $cp == 0x0D} {
                # Tab, Newline, CR
                append result $c
            } else {
                append result "?"
            }
        }
    }

    return $result
}

proc ::pdf4tcllib::unicode::_emojiFallback {cp} {
    # Returns ASCII fallback for an emoji codepoint.
    # Wird aufgerufen if Surrogate-Paare in Tcl 8.6 erkannt werden.

    # Spezifische Mappings (haeufigste Emojis)
    switch -exact -- $cp {
        128512 { return ":-)" }
        128513 { return ":-D" }
        128514 { return ":'D" }
        128515 { return ":-D" }
        128516 { return ":-D" }
        128521 { return ";-)" }
        128522 { return ":-)" }
        128525 { return "<3" }
        128526 { return "B-)" }
        128536 { return ":-*" }
        128540 { return ":-P" }
        128542 { return ":-(" }
        128546 { return ":-(" }
        128557 { return ":'(" }
        128558 { return ":-O" }
        128561 { return ":-O" }
        128563 { return ":-/" }
        128566 { return ":-|" }
        128567 { return ":-|" }
        128568 { return ":-)" }
        128580 { return ":-/" }
        129300 { return "(?)" }
        129315 { return ":'D" }
        127881 { return "(!)" }
        127882 { return "(!)" }
        128077 { return "(+1)" }
        128078 { return "(-1)" }
        128075 { return "(*)" }
        128293 { return "(*)" }
        128161 { return "(!)" }
        128640 { return {[>]} }
        128175 { return "(100)" }
        128591 { return "(*)" }
        128170 { return "(*)" }
        128193 { return {[D]} }
        128196 { return {[doc]} }
        128221 { return {[doc]} }
        128231 { return {[@]} }
        128274 { return {[L]} }
        128275 { return {[U]} }
        10024  { return "*" }
        9989   { return "(OK)" }
    }

    # Range-basierte Fallbacks
    if {$cp >= 0x1F600 && $cp <= 0x1F64F} { return ":-)" }
    if {$cp >= 0x1F380 && $cp <= 0x1F3FF} { return "(!)" }
    if {$cp >= 0x1F440 && $cp <= 0x1F4FF} { return "(*)" }
    if {$cp >= 0x1F500 && $cp <= 0x1F5FF} { return "(*)" }
    if {$cp >= 0x1F680 && $cp <= 0x1F6FF} { return {[>]} }
    if {$cp >= 0x1F900 && $cp <= 0x1F9FF} { return ":-)" }
    if {$cp >= 0x1FA00 && $cp <= 0x1FAFF} { return "(*)" }

    return "(?)"
}

proc ::pdf4tcllib::unicode::preprocessBytes {data} {
    # Replaces 4-Byte UTF-8 Sequenzen (Emoji, BMP+) durch ASCII-Fallbacks.
    #
    # MUST be called on BINARY data BEFORE Tcl corrupts the bytes
    # in seinen internen String konvertiert (encoding convertfrom).
    #
    # Tcl 8.6 kann Codepoints > U+FFFF not render und
    # konvertiert sie zu U+FFFD. Diese Funktion faengt die
    # rohen UTF-8 Bytes vorher ab.
    #
    # Usage:
    #   set f [open $file rb]
    #   set raw [read $f]; close $f
    #   set clean [::pdf4tcllib::unicode::preprocessBytes $raw]
    #   set text [encoding convertfrom utf-8 $clean]

    set result {}
    set len [string length $data]
    set i 0

    while {$i < $len} {
        set byte [scan [string index $data $i] %c]

        # 4-Byte UTF-8: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
        if {($byte & 0xF8) == 0xF0 && ($i + 3) < $len} {
            set b2 [scan [string index $data [expr {$i+1}]] %c]
            set b3 [scan [string index $data [expr {$i+2}]] %c]
            set b4 [scan [string index $data [expr {$i+3}]] %c]

            if {($b2 & 0xC0) == 0x80 && ($b3 & 0xC0) == 0x80 && ($b4 & 0xC0) == 0x80} {
                set cp [expr {(($byte & 0x07) << 18) | (($b2 & 0x3F) << 12) | (($b3 & 0x3F) << 6) | ($b4 & 0x3F)}]
                append result [::pdf4tcllib::unicode::_emojiFallback $cp]
                incr i 4
                continue
            }
        }

        append result [string index $data $i]
        incr i
    }

    return $result
}

proc ::pdf4tcllib::unicode::readFile {filename} {
    # Reads a UTF-8 file with emoji preprocessing.
    # Returns a clean Tcl string.
    set f [open $filename rb]
    set raw [read $f]
    close $f
    set clean [::pdf4tcllib::unicode::preprocessBytes $raw]
    return [encoding convertfrom utf-8 $clean]
}

proc ::pdf4tcllib::unicode::safeText {pdf txt args} {
    # Returns Text sicher an pdf4tcl aus.
    # Sanitized den Text and faengt error ab.
    #
    # Argumente:
    #   pdf   - pdf4tcl-Objekt
    #   txt   - Auszugebender Text
    #   args  - Werden an $pdf text weitergereicht (-x, -y, -align, ...)
    #
    # Optionale Steuerung:
    #   -mono 0/1   Wird from args extrahiert and an sanitize durchgereicht

    # -mono extrahieren falls vorhanden
    set mono 0
    set passArgs {}
    set i 0
    foreach {k v} $args {
        if {$k eq "-mono"} {
            set mono $v
        } else {
            lappend passArgs $k $v
        }
    }

    set clean [sanitize $txt -mono $mono]

    if {[catch {$pdf text $clean {*}$passArgs} err]} {
        # Notfall: Alles on druckbares ASCII reduzieren
        set safe ""
        foreach c [split $clean ""] {
            set cp [scan $c %c]
            if {($cp >= 0x20 && $cp <= 0x7E) ||
                $cp == 0x09 || $cp == 0x0A || $cp == 0x0D} {
                append safe $c
            } else {
                append safe "?"
            }
        }
        catch {$pdf text $safe {*}$passArgs}
    }
}

# ================================================================
# Module: pdf4tcllib::text
# ================================================================

# pdf4tcllib::text -- Text-Layout for pdf4tcl
#
# linesumbruch, widthnmessung, Tab-Expansion.
# Arbeitet with den Fonts from pdf4tcllib::fonts.
#
# Usage:
#   package require pdf4tcllib::text 0.1
#   set lines [pdf4tcllib::text::wrap $text $maxW $fontSize $fontName]
#   set w [pdf4tcllib::text::width $text $fontSize $fontName]


namespace eval ::pdf4tcllib::text {}

# ============================================================
# Oeffentliche API
# ============================================================

proc ::pdf4tcllib::text::width {text fontSize fontName} {
    # Calculates the approximate width of a text in points.
    #
    # Verwendet den widthnfaktor des Fonts.
    # For monospace fonts every character is assumed equal width.
    # For proportional fonts: character class estimation.

    set factor [::pdf4tcllib::fonts::widthFactor $fontName]
    set isCode [::pdf4tcllib::fonts::isMonospace $fontName]

    if {$isCode} {
        return [expr {[string length $text] * $fontSize * $factor}]
    }

    # Proportional: character width classes
    set len 0.0
    foreach c [split $text ""] {
        switch -exact -- $c {
            "i" - "l" - "j" - "f" - "t" - "r" {
                set len [expr {$len + 0.55}]
            }
            "." - "," - ":" - ";" - "!" - "|" - "'" - " " {
                set len [expr {$len + 0.40}]
            }
            "m" - "w" {
                set len [expr {$len + 1.35}]
            }
            "M" - "W" {
                set len [expr {$len + 1.45}]
            }
            "A" - "B" - "C" - "D" - "G" - "H" - "K" - "N" - "O" - "P" - "Q" - "R" - "U" - "V" - "X" - "Y" - "Z" {
                set len [expr {$len + 1.15}]
            }
            "0" - "1" - "2" - "3" - "4" - "5" - "6" - "7" - "8" - "9" {
                set len [expr {$len + 1.0}]
            }
            default {
                set len [expr {$len + 1.0}]
            }
        }
    }
    return [expr {$len * $fontSize * $factor}]
}

proc ::pdf4tcllib::text::wrap {line maxW fontSize fontName {codeContinuation 0}} {
    # Wraps a line at word boundaries.
    #
    # Returns a list of sub-lines that each fit within maxW.
    # Zu lange Woerter werden an maxW abgeschnitten.
    #
    # codeContinuation: if 1, wrapped code lines get
    # with " \" am Ende markiert (Tcl-Stil).

    if {[width $line $fontSize $fontName] <= $maxW} {
        return [list $line]
    }

    # Bei Code-Continuation Platz for " \" reservieren
    if {$codeContinuation} {
        set wrapMaxW [expr {$maxW - [width " \\" $fontSize $fontName]}]
    } else {
        set wrapMaxW $maxW
    }

    set words [split $line " "]
    set lines {}
    set current ""

    foreach word $words {
        if {$current eq ""} {
            set test $word
        } else {
            set test "$current $word"
        }

        if {[width $test $fontSize $fontName] <= $wrapMaxW} {
            set current $test
        } else {
            if {$current ne ""} {
                lappend lines $current
            }
            # Check word alone
            if {[width $word $fontSize $fontName] > $wrapMaxW} {
                set current [truncate $word $wrapMaxW $fontSize $fontName]
            } else {
                set current $word
            }
        }
    }

    if {$current ne ""} {
        lappend lines $current
    }

    if {[llength $lines] == 0} {
        return [list $line]
    }

    # Code continuation: append backslash to all lines except last
    if {$codeContinuation && [llength $lines] > 1} {
        set result {}
        set lastIdx [expr {[llength $lines] - 1}]
        for {set i 0} {$i < [llength $lines]} {incr i} {
            if {$i < $lastIdx} {
                lappend result "[lindex $lines $i] \\"
            } else {
                lappend result [lindex $lines $i]
            }
        }
        return $result
    }

    return $lines
}

proc ::pdf4tcllib::text::truncate {text maxW fontSize fontName} {
    # Truncates text if wider than maxW.
    #
    # Adds "..." am Ende an.

    if {[width $text $fontSize $fontName] <= $maxW} {
        return $text
    }

    # Binary search for the maximum length
    set lo 0
    set hi [string length $text]
    while {$lo < $hi} {
        set mid [expr {($lo + $hi + 1) / 2}]
        set try "[string range $text 0 $mid-1]..."
        if {[width $try $fontSize $fontName] <= $maxW} {
            set lo $mid
        } else {
            set hi [expr {$mid - 1}]
        }
    }

    if {$lo == 0} {
        return "..."
    }

    return "[string range $text 0 $lo-1]..."
}

proc ::pdf4tcllib::text::expandTabs {line {tabWidth 4}} {
    # Expandiert Tabs zu Leerzeichen.
    #
    # Each tab is replaced with enough spaces to reach the next
    # Tab-Position zu erreichen.

    set result ""
    set col 0
    foreach c [split $line ""] {
        if {$c eq "\t"} {
            set spaces [expr {$tabWidth - ($col % $tabWidth)}]
            append result [string repeat " " $spaces]
            incr col $spaces
        } else {
            append result $c
            incr col
        }
    }
    return $result
}

proc ::pdf4tcllib::text::detectFont {line} {
    # Detects if a line has monospace formatting.
    #
    # Returns den passenden Font-Namen from pdf4tcllib::fonts.
    # Kriterien for Monospace:
    #   - line beginnt with Tab
    #   - line starts with 4+ spaces (code indentation)
    #   - line enthaelt Tcl-Syntax ($var, ::, ->)

    if {[string first "\t" $line] >= 0} {
        return [::pdf4tcllib::fonts::fontMono]
    }
    if {[regexp {^    } $line]} {
        return [::pdf4tcllib::fonts::fontMono]
    }
    if {[regexp {^\s*\|} $line]} {
        return [::pdf4tcllib::fonts::fontMono]
    }
    if {[regexp {\$\w+|::|->|\{.*\}} $line]} {
        return [::pdf4tcllib::fonts::fontMono]
    }
    return [::pdf4tcllib::fonts::fontSans]
}

proc ::pdf4tcllib::text::writeParagraph {pdf text x y width {size 12} {align left}} {
    # Writes a paragraph with automatic line wrapping.
    # Verwendet drawTextBox intern.
    # Returns the next Y position.

    set lh [::pdf4tcllib::page::lineheight $size]
    $pdf setFont $size Helvetica

    set lines_var ::pdf4tcllib::text::_temp_lines
    $pdf drawTextBox $x $y $width 10000 $text \
        -align $align \
        -linesvar $lines_var

    if {[info exists $lines_var]} {
        set num_lines [set $lines_var]
    } else {
        set num_lines [expr {[string length $text] / 50 + 1}]
    }

    return [expr {$y + $num_lines * $lh}]
}


# ================================================================
# Module: pdf4tcllib::page
# ================================================================

# pdf4tcllib::page -- pagenkontext and pagenmoeblierung for pdf4tcl
#
# Zentrales Konzept: PageContext-Dictionary
# Wird einmal pro Dokument erzeugt and enthaelt alle berechneten
# pagenabmessungen (Margins, druckbarer Bereich etc.)
#
# Usage:
#   package require pdf4tcllib::page 0.1
#   set ctx [pdf4tcllib::page::context a4 -margin 20]
#   dict get $ctx page_w     ;# page width in points
#   dict get $ctx left        ;# Linker Rand in Points
#   dict get $ctx text_w      ;# Druckbare width
#
#   pdf4tcllib::page::number $pdf $ctx 1 10
#   pdf4tcllib::page::header $pdf $ctx "Mein Dokument"
#   pdf4tcllib::page::footer $pdf $ctx "Vertraulich" 3


namespace eval ::pdf4tcllib::page {
    # Paper sizes in points {width height}
    variable paperSizes
    array set paperSizes {
        a4      {595.28  841.89}
        a3      {841.89  1190.55}
        a5      {419.53  595.28}
        letter  {612     792}
        legal   {612     1008}
        b5      {498.90  708.66}
    }
}

proc ::pdf4tcllib::page::context {paper args} {
    # Generates ein PageContext-Dictionary.
    #
    # Args:
    #   paper  - Papiergroesse: a4, a3, a5, letter, legal, b5
    #
    # Optionen (Keyword or Positional):
    #   context a4 -margin 20 -orient true   ;# Keyword
    #   context a4 20 true                   ;# Positional (Kompatibilitaet)
    #   context a4                           ;# Defaults

    variable paperSizes

    array set opt {
        -margin    20
        -landscape 0
        -orient    true
    }

    # Positional args erkennen (erstes arg beginnt not with -)
    if {[llength $args] > 0 && ![string match "-*" [lindex $args 0]]} {
        if {[llength $args] >= 1} { set opt(-margin) [lindex $args 0] }
        if {[llength $args] >= 2} { set opt(-orient) [lindex $args 1] }
    } else {
        array set opt $args
    }

    set paperKey [string tolower $paper]
    if {![info exists paperSizes($paperKey)]} {
        error "Unbekannte Papiergroesse: $paper (erlaubt: [array names paperSizes])"
    }

    lassign $paperSizes($paperKey) pw ph

    if {$opt(-landscape)} {
        set tmp $pw
        set pw $ph
        set ph $tmp
    }

    set margin_pt [::pdf4tcllib::units::mm $opt(-margin)]

    set ctx [dict create \
        paper      $paperKey \
        page_w     $pw \
        page_h     $ph \
        PW         $pw \
        PH         $ph \
        margin     $margin_pt \
        margin_mm  $opt(-margin) \
        margin_pt  $margin_pt \
        left       $margin_pt \
        right      [expr {$pw - $margin_pt}] \
        top        $margin_pt \
        bottom     [expr {$ph - $margin_pt}] \
        text_w     [expr {$pw - 2 * $margin_pt}] \
        text_h     [expr {$ph - 2 * $margin_pt}] \
        SX         $margin_pt \
        SY         $margin_pt \
        SW         [expr {$pw - 2 * $margin_pt}] \
        SH         [expr {$ph - 2 * $margin_pt}] \
        landscape  $opt(-landscape) \
        orient     $opt(-orient) \
    ]

    return $ctx
}

proc ::pdf4tcllib::page::lineheight {fontSize {factor 1.4}} {
    # Calculates the line height for a font size.
    return [expr {int(ceil($fontSize * $factor))}]
}

proc ::pdf4tcllib::page::number {pdf ctx current {total ""} {size 9}} {
    # Writes the page number centered at bottom.
    #
    # Format: "- 3 -" or "- 3 / 10 -"


    set x [expr {[dict get $ctx page_w] / 2.0}]
    set y [expr {[dict get $ctx page_h] - [dict get $ctx margin] * 0.5}]

    if {$total ne ""} {
        set text "- $current / $total -"
    } else {
        set text "- $current -"
    }

    $pdf setFont $size Helvetica
    ::pdf4tcllib::unicode::safeText $pdf $text -x $x -y $y -align center
}

proc ::pdf4tcllib::page::header {pdf ctx text {size 10}} {
    # Writes a header centered at top.


    set x [expr {[dict get $ctx page_w] / 2.0}]
    set y [expr {[dict get $ctx margin] * 0.5}]

    $pdf setFont $size Helvetica
    ::pdf4tcllib::unicode::safeText $pdf $text -x $x -y $y -align center

    # Trennlinie
    set lx [dict get $ctx left]
    set rx [dict get $ctx right]
    set ly [expr {[dict get $ctx top] - 2}]
    $pdf setStrokeColor 0.7 0.7 0.7
    $pdf setLineWidth 0.5
    $pdf line $lx $ly $rx $ly
    $pdf setStrokeColor 0 0 0
}

proc ::pdf4tcllib::page::footer {pdf ctx text pageNo {size 9}} {
    # Writes a footer: text left, page number right.


    set y [expr {[dict get $ctx page_h] - [dict get $ctx margin] * 0.5}]

    # Trennlinie
    set lx [dict get $ctx left]
    set rx [dict get $ctx right]
    set ly [expr {[dict get $ctx bottom] + 2}]
    $pdf setStrokeColor 0.7 0.7 0.7
    $pdf setLineWidth 0.5
    $pdf line $lx $ly $rx $ly
    $pdf setStrokeColor 0 0 0

    # Text links
    $pdf setFont $size Helvetica
    ::pdf4tcllib::unicode::safeText $pdf $text -x $lx -y $y

    # pagennummer rechts
    ::pdf4tcllib::unicode::safeText $pdf "Seite $pageNo" -x $rx -y $y -align right
}

proc ::pdf4tcllib::page::centerText {pdf ctx text y {size 12} {font "Helvetica"}} {
    # Writes Text horizontal zentriert.


    set x [expr {[dict get $ctx page_w] / 2.0}]
    $pdf setFont $size $font
    ::pdf4tcllib::unicode::safeText $pdf $text -x $x -y $y -align center
}

proc ::pdf4tcllib::page::grid {pdf args} {
    # Draws a helper grid on the page (for debugging).
    #
    # Aufruf:
    #   page::grid $pdf $ctx          ;# spacing=50
    #   page::grid $pdf $ctx 25       ;# spacing=25
    #   page::grid $pdf 50            ;# ohne ctx, spacing=50 (Kompatibilitaet)

    set spacing 50
    set pw 595.28
    set ph 841.89

    if {[llength $args] == 0} {
        # page::grid $pdf
    } elseif {[llength $args] == 1} {
        set arg [lindex $args 0]
        if {[string is double -strict $arg]} {
            set spacing [expr {int($arg)}]
        } else {
            set pw [dict get $arg page_w]
            set ph [dict get $arg page_h]
        }
    } elseif {[llength $args] == 2} {
        set ctx [lindex $args 0]
        set spacing [lindex $args 1]
        set pw [dict get $ctx page_w]
        set ph [dict get $ctx page_h]
    }

    $pdf setStrokeColor 0.85 0.85 0.85
    $pdf setLineWidth 0.25

    # Vertikale Linien
    for {set x 0} {$x <= $pw} {set x [expr {$x + $spacing}]} {
        $pdf line $x 0 $x $ph
        $pdf setFont 6 Helvetica
        $pdf setFillColor 0.6 0.6 0.6
        $pdf text "[expr {int($x)}]" -x [expr {$x + 2}] -y 8
    }

    # Horizontale Linien
    for {set y 0} {$y <= $ph} {set y [expr {$y + $spacing}]} {
        $pdf line 0 $y $pw $y
        $pdf setFont 6 Helvetica
        $pdf setFillColor 0.6 0.6 0.6
        $pdf text "[expr {int($y)}]" -x 2 -y [expr {$y + 8}]
    }

    $pdf setStrokeColor 0 0 0
    $pdf setFillColor 0 0 0
}

proc ::pdf4tcllib::page::orientationLegend {pdf ctx} {
    # Zeigt Orientierungs-Info (Papier, orient, y-Ursprung) am oberen Rand.

    set pw [dict get $ctx page_w]
    set ph [dict get $ctx page_h]
    set orient [dict get $ctx orient]
    set paper [dict get $ctx paper]

    $pdf gsave
    $pdf setFont 8 Courier
    $pdf setFillColor 0.5 0.5 0.5

    set text "$paper | orient=$orient | y-origin=[expr {$orient ? {top} : {bottom}}] | unit=pt"

    $pdf text $text \
        -align right \
        -x [expr {$pw - 10}] \
        -y [expr {$ph - 10}]

    $pdf grestore
}


# ================================================================
# Module: pdf4tcllib::table
# ================================================================

# pdf4tcllib::table -- Table rendering for pdf4tcl
#
# Renders tablen with Header, columnnausrichtung, Zebra-Streifen
# and automaticallyem Page break.
#
# Usage:
#   package require pdf4tcllib::table 0.1
#   pdf4tcllib::table::render $pdf $tableData \
#       -x 50 -y yVar -maxwidth 500 \
#       -fontsize 11 -pagebreak [list $yTop $yBot pageNoVar $pageW $pageH $margin]


namespace eval ::pdf4tcllib::table {}

# ============================================================
# Oeffentliche API
# ============================================================

proc ::pdf4tcllib::table::render {pdf tableData x0 yVar maxW yTop yBot pageNoVar pageW pageH margin fontSize lineH {debug 0}} {
    # Renders a table into the PDF.
    #
    # tableData akzeptiert zwei Formate:
    #
    # 1. Listen-Format: {header aligns row1 row2 ...}
    #      header:  {Column1 column2 ...}
    #      aligns:  {left center right ...}
    #      rows:    {Wert1 Wert2 ...}
    #
    # 2. Dict-Format: {header {..} rows {{..} {..}} aligns {..} cols N}
    #      Wie of mdhelp_pdf::_extractFrameTable geliefert.
    #
    # yVar, pageNoVar: upvar-Variablen for Position and pagenzahl

    upvar $yVar y
    upvar $pageNoVar pageNo

    set fontSans     [::pdf4tcllib::fonts::fontSans]
    set fontSansBold [::pdf4tcllib::fonts::fontSansBold]

    # -- Format erkennen and normalisieren --
    if {[_isDictFormat $tableData]} {
        # Dict-Format: {header {..} rows {{..}} aligns {..}}
        set header [dict get $tableData header]
        set rows   [dict get $tableData rows]
        set aligns [dict get $tableData aligns]
    } else {
        # Listen-Format: {header aligns row1 row2 ...}
        if {[llength $tableData] < 2} { return }
        set header [lindex $tableData 0]
        set aligns [lindex $tableData 1]
        set rows   [lrange $tableData 2 end]
    }

    set nCols [llength $header]
    if {$nCols == 0 && [llength $rows] > 0} {
        set nCols [llength [lindex $rows 0]]
    }
    if {$nCols == 0} { return }

    set hasHdr [expr {[llength $header] > 0}]

    # -- Calculate column widths --
    set colWidths [_calcColWidths $header $aligns $rows $maxW $fontSize $fontSans $fontSansBold]
    set totalW 0
    foreach w $colWidths { set totalW [expr {$totalW + $w}] }

    set cellH   [expr {int($fontSize * 2.0)}]
    set cellPad 4

    # -- Check page break --
    set tableMinH [expr {$cellH * (1 + min([llength $rows], 2))}]
    if {($y + $tableMinH) > $yBot} {
        _pageBreak $pdf pageNo $pageW $pageH $margin $fontSize
        set y $yTop
    }

    set tableStartY $y
    set rowYs [list $y]
    set hdrBottom ""

    # -- Header --
    if {$hasHdr} {
        $pdf setLineWidth 0.5
        $pdf setFillColor 0.88 0.88 0.88
        $pdf rectangle $x0 $y $totalW $cellH -filled 1
        $pdf setFillColor 0.0 0.0 0.0

        $pdf setFont $fontSize $fontSansBold
        _drawCells $pdf $x0 $y $cellH $colWidths $aligns $cellPad $fontSize $fontSansBold $header

        set y [expr {$y + $cellH}]
        lappend rowYs $y
        set hdrBottom $y
    }

    # -- Data rows --
    $pdf setFont $fontSize $fontSans
    set rowIdx 0
    foreach row $rows {
        # Page break
        if {($y + $cellH) > $yBot} {
            _drawVLines $pdf $x0 $tableStartY $y $colWidths
            _pageBreak $pdf pageNo $pageW $pageH $margin $fontSize
            set y $yTop
            $pdf setFont $fontSize $fontSans
            $pdf setLineWidth 0.5
            set tableStartY $y
            set rowYs [list $y]
            set hdrBottom ""
        }

        # Zebra-Streifen
        if {$rowIdx % 2 == 1} {
            $pdf setFillColor 0.97 0.97 0.97
            $pdf rectangle $x0 $y $totalW $cellH -filled 1
            $pdf setFillColor 0.0 0.0 0.0
        }

        _drawCells $pdf $x0 $y $cellH $colWidths $aligns $cellPad $fontSize $fontSans $row
        set y [expr {$y + $cellH}]
        lappend rowYs $y
        incr rowIdx
    }

    # -- Linien zeichnen --
    $pdf setStrokeColor 0.6 0.6 0.6

    # Obere Linie
    $pdf line $x0 $tableStartY [expr {$x0 + $totalW}] $tableStartY

    # Header-Trennlinie (dicker)
    if {$hdrBottom ne ""} {
        $pdf setLineWidth 1.0
        $pdf line $x0 $hdrBottom [expr {$x0 + $totalW}] $hdrBottom
        $pdf setLineWidth 0.5
    }

    # lines-Trennlinien
    foreach ly [lrange $rowYs 2 end] {
        $pdf line $x0 $ly [expr {$x0 + $totalW}] $ly
    }

    # Vertikale Linien
    _drawVLines $pdf $x0 $tableStartY $y $colWidths

    # Reset
    $pdf setStrokeColor 0.0 0.0 0.0
    $pdf setFillColor 0.0 0.0 0.0
    $pdf setFont $fontSize $fontSans
}

# ============================================================
# Private Helfer
# ============================================================

proc ::pdf4tcllib::table::_isDictFormat {tableData} {
    # Checks ob tableData ein Dict with keys header/rows/aligns ist.
    if {[catch {dict get $tableData rows}]} { return 0 }
    if {[catch {dict get $tableData aligns}]} { return 0 }
    return 1
}

proc ::pdf4tcllib::table::_calcColWidths {header aligns rows maxW fontSize fontSans fontSansBold} {
    # Calculates column widths based on content.
    set nCols [llength $header]
    if {$nCols == 0 && [llength $rows] > 0} {
        set nCols [llength [lindex $rows 0]]
    }
    if {$nCols == 0} { return {} }
    set minW [expr {$maxW / $nCols}]

    # Maximale width pro column
    set maxWidths {}
    for {set i 0} {$i < $nCols} {incr i} {
        set colMax 0
        if {[llength $header] > 0} {
            set colMax [::pdf4tcllib::text::width [lindex $header $i] $fontSize $fontSansBold]
        }
        foreach row $rows {
            set cellW [::pdf4tcllib::text::width [lindex $row $i] $fontSize $fontSans]
            if {$cellW > $colMax} { set colMax $cellW }
        }
        lappend maxWidths [expr {$colMax + 20}]  ;# Padding (2*cellPad + Sicherheit)
    }

    # Auf maxW normieren
    set total 0.0
    foreach w $maxWidths { set total [expr {$total + $w}] }
    set colWidths {}
    if {$total <= $maxW} {
        # Gleichmaessig auffuellen
        set extra [expr {($maxW - $total) / $nCols}]
        foreach w $maxWidths {
            lappend colWidths [expr {int($w + $extra)}]
        }
    } else {
        # Proportional schrumpfen
        foreach w $maxWidths {
            lappend colWidths [expr {int($w * $maxW / $total)}]
        }
    }

    return $colWidths
}

proc ::pdf4tcllib::table::_drawCells {pdf x0 y0 cellH colWidths aligns cellPad fontSize fontName texts} {
    # Draws the cells of a table row.
    set x $x0
    # Vertical centering: baseline approx. at cell center + half font height
    set textY [expr {$y0 + ($cellH + $fontSize) / 2 - 2}]

    foreach text $texts colW $colWidths align $aligns {
        set text [::pdf4tcllib::unicode::sanitize $text]
        set availW [expr {$colW - 2 * $cellPad}]

        if {$align eq "center"} {
            set tw [::pdf4tcllib::text::width $text $fontSize $fontName]
            set textX [expr {$x + ($colW - $tw) / 2.0}]
        } elseif {$align eq "right"} {
            set tw [::pdf4tcllib::text::width $text $fontSize $fontName]
            set textX [expr {$x + $colW - $cellPad - $tw}]
        } else {
            set textX [expr {$x + $cellPad}]
        }

        set text [::pdf4tcllib::text::truncate $text $availW $fontSize $fontName]
        ::pdf4tcllib::unicode::safeText $pdf $text -x $textX -y $textY
        set x [expr {$x + $colW}]
    }
}

proc ::pdf4tcllib::table::_drawVLines {pdf x0 yStart yEnd colWidths} {
    # Draws vertikale Trennlinien.
    set x $x0
    $pdf line $x $yStart $x $yEnd
    foreach colW $colWidths {
        set x [expr {$x + $colW}]
        $pdf line $x $yStart $x $yEnd
    }
}

proc ::pdf4tcllib::table::_pageBreak {pdf pageNoVar pageW pageH margin fontSize} {
    # Performs a page break.
    upvar $pageNoVar pageNo
    set fontSans [::pdf4tcllib::fonts::fontSans]
    set y [expr {$pageH - $margin * 0.5}]
    set x [expr {$pageW - $margin}]
    $pdf setFont [expr {$fontSize - 2}] $fontSans
    ::pdf4tcllib::unicode::safeText $pdf "- $pageNo -" -x $x -y $y -align right
    $pdf endPage
    incr pageNo
    $pdf startPage
}

proc ::pdf4tcllib::table::simpleTable {pdf x y col_widths rows args} {
    # Simple table with column widths and row lists.
    # For testitpdf examples. For complex tables: table::render.
    #
    # Argumente:
    #   col_widths  List of column widths in points
    #   rows        List of rows, each row a list of cell texts
    #   -zebra 0/1  Zebra-Streifen
    #   -pad N      Cell padding (default: 5)
    #   -header_bg  RGB list for header (default: {0.9 0.9 0.9})
    #   -row_height Row height (default: 20)
    #   -font_size  Font size (default: 10)
    #
    # Returns the next Y position.

    array set opts {
        -zebra 0
        -pad 5
        -header_bg {0.9 0.9 0.9}
        -row_height 20
        -font_size 10
    }
    array set opts $args

    set num_cols [llength $col_widths]
    set num_rows [llength $rows]
    set row_height $opts(-row_height)
    set pad $opts(-pad)

    # Total width
    set table_w 0
    foreach w $col_widths { set table_w [expr {$table_w + $w}] }

    # Zebra-Streifen
    if {$opts(-zebra)} {
        for {set r 0} {$r < $num_rows} {incr r} {
            if {$r % 2 == 1} {
                set row_y [expr {$y + $r * $row_height}]
                $pdf setFillColor 0.95 0.95 0.95
                $pdf rectangle $x $row_y $table_w $row_height -filled 1
                $pdf setFillColor 0 0 0
            }
        }
    }

    # Header background (first row)
    if {[llength $opts(-header_bg)] == 3} {
        lassign $opts(-header_bg) r g b
        $pdf setFillColor $r $g $b
        $pdf rectangle $x $y $table_w $row_height -filled 1
        $pdf setFillColor 0 0 0
    }

    # Grid lines
    $pdf setLineWidth 0.5
    for {set r 0} {$r <= $num_rows} {incr r} {
        set line_y [expr {$y + $r * $row_height}]
        $pdf line $x $line_y [expr {$x + $table_w}] $line_y
    }
    set col_x $x
    $pdf line $col_x $y $col_x [expr {$y + $num_rows * $row_height}]
    foreach w $col_widths {
        set col_x [expr {$col_x + $w}]
        $pdf line $col_x $y $col_x [expr {$y + $num_rows * $row_height}]
    }

    # Cell contents
    $pdf setFont $opts(-font_size) Helvetica
    for {set r 0} {$r < $num_rows} {incr r} {
        set row [lindex $rows $r]
        set text_y [expr {$y + $r * $row_height + $row_height/2 + $opts(-font_size)/3}]
        set col_x $x
        for {set c 0} {$c < $num_cols} {incr c} {
            set cell_text [lindex $row $c]
            $pdf text $cell_text -x [expr {$col_x + $pad}] -y $text_y
            set col_x [expr {$col_x + [lindex $col_widths $c]}]
        }
    }

    return [expr {$y + $num_rows * $row_height + $pad}]
}


# ================================================================
# Module: pdf4tcllib::drawing
# ================================================================

# pdf4tcllib::drawing -- Drawing functions for pdf4tcl
#
# Erweiterte geometrische Formen, Farbverlaeufe, Muster.
# Builds on pdf4tcl-Grundprimitiven auf.
#
# Usage:
#   package require pdf4tcllib::drawing 0.1
#   pdf4tcllib::drawing::gradient_v $pdf 50 100 200 300 {1 0 0} {0 0 1}
#   pdf4tcllib::drawing::polygon $pdf 200 200 50 6
#   pdf4tcllib::drawing::star $pdf 300 300 40


namespace eval ::pdf4tcllib::drawing {}

# ============================================================
# Farbverlaeufe
# ============================================================

proc ::pdf4tcllib::drawing::interpolate {c1 c2 t} {
    # Interpolates between two RGB colors.
    # c1, c2: {r g b} with Werten 0.0-1.0
    # t: Position 0.0 (=c1) bis 1.0 (=c2)
    lassign $c1 r1 g1 b1
    lassign $c2 r2 g2 b2
    list \
        [expr {$r1 + ($r2 - $r1) * $t}] \
        [expr {$g1 + ($g2 - $g1) * $t}] \
        [expr {$b1 + ($b2 - $b1) * $t}]
}

proc ::pdf4tcllib::drawing::gradient_v {pdf x y w h c1 c2 {steps 100}} {
    # Vertikaler Farbverlauf (oben after unten).
    # c1: start color top, c2: end color bottom.
    if {$steps < 1} { set steps 1 }
    set dh [expr {$h / double($steps)}]
    for {set i 0} {$i < $steps} {incr i} {
        set t [expr {$i / double($steps)}]
        set rgb [interpolate $c1 $c2 $t]
        $pdf setFillColor {*}$rgb
        set yy [expr {$y + $i * $dh}]
        $pdf rectangle $x $yy $w $dh -filled 1
    }
}

proc ::pdf4tcllib::drawing::gradient_h {pdf x y w h c1 c2 {steps 100}} {
    # Horizontaler Farbverlauf (links after rechts).
    if {$steps < 1} { set steps 1 }
    set dw [expr {$w / double($steps)}]
    for {set i 0} {$i < $steps} {incr i} {
        set t [expr {$i / double($steps)}]
        set rgb [interpolate $c1 $c2 $t]
        $pdf setFillColor {*}$rgb
        set xx [expr {$x + $i * $dw}]
        $pdf rectangle $xx $y $dw $h -filled 1
    }
}

# ============================================================
# Formen
# ============================================================

proc ::pdf4tcllib::drawing::polygon {pdf cx cy radius sides {stroke 1} {fill 0}} {
    # Regelmaessiges Polygon.
    # cx, cy: Mittelpunkt, radius: Umkreisradius, sides: Anzahl Ecken
    if {$sides < 3} { return }
    set pts {}
    set pi [expr {acos(-1)}]
    for {set k 0} {$k < $sides} {incr k} {
        set ang [expr {2.0 * $pi * $k / $sides - $pi / 2.0}]
        lappend pts [expr {$cx + $radius * cos($ang)}]
        lappend pts [expr {$cy + $radius * sin($ang)}]
    }
    $pdf polygon {*}$pts -stroke $stroke -filled $fill
}

proc ::pdf4tcllib::drawing::star {pdf cx cy radius {points 5} {ratio 0.5} {stroke 1} {fill 0}} {
    # Stern.
    # radius: Aussenradius, ratio: Innen/Aussen-Verhaeltnis
    if {$points < 2} { return }
    set pi [expr {acos(-1)}]
    set pts {}
    for {set k 0} {$k < 2 * $points} {incr k} {
        set r [expr {($k % 2) ? $radius * $ratio : $radius}]
        set ang [expr {-$pi / 2.0 + $k * $pi / $points}]
        lappend pts [expr {$cx + $r * cos($ang)}]
        lappend pts [expr {$cy + $r * sin($ang)}]
    }
    $pdf polygon {*}$pts -stroke $stroke -filled $fill
}

proc ::pdf4tcllib::drawing::roundedRect {pdf x y w h r {stroke 1} {fill 0}} {
    # Rechteck with abgerundeten Ecken.
    # r: Eckradius
    #
    # Uses Bezier curves for the corners (kappa = 0.5522847498).

    set k [expr {$r * 0.5522847498}]

    # Startpunkt: Mitte obere Kante
    set x1 [expr {$x + $r}]
    set x2 [expr {$x + $w - $r}]
    set y1 [expr {$y + $r}]
    set y2 [expr {$y + $h - $r}]

    # path als Koordinatenliste for polygon (Annaeherung)
    # Echte Bezier-Kurven waeren besser, but pdf4tcl hat keine
    # einfache path-API -- nutze Segmente
    set segs 8
    set pts {}

    # Obere Kante links after rechts
    lappend pts $x1 $y
    lappend pts $x2 $y

    # Ecke oben rechts
    _arcPoints pts [expr {$x + $w - $r}] [expr {$y + $r}] $r 270 360 $segs

    # Rechte Kante oben after unten
    lappend pts [expr {$x + $w}] $y2

    # Ecke unten rechts
    _arcPoints pts [expr {$x + $w - $r}] [expr {$y + $h - $r}] $r 0 90 $segs

    # Untere Kante rechts after links
    lappend pts $x2 [expr {$y + $h}]
    lappend pts $x1 [expr {$y + $h}]

    # Ecke unten links
    _arcPoints pts [expr {$x + $r}] [expr {$y + $h - $r}] $r 90 180 $segs

    # Linke Kante unten after oben
    lappend pts $x $y2
    lappend pts $x $y1

    # Ecke oben links
    _arcPoints pts [expr {$x + $r}] [expr {$y + $r}] $r 180 270 $segs

    $pdf polygon {*}$pts -stroke $stroke -filled $fill
}

proc ::pdf4tcllib::drawing::frame {pdf x y w h {lineWidth 1}} {
    # Einfacher Rahmen.
    $pdf setLineWidth $lineWidth
    $pdf rectangle $x $y $w $h -stroke 1
}

proc ::pdf4tcllib::drawing::separator {pdf x y w {color {0.7 0.7 0.7}} {lineWidth 0.5}} {
    # Horizontale Trennlinie.
    $pdf setStrokeColor {*}$color
    $pdf setLineWidth $lineWidth
    $pdf line $x $y [expr {$x + $w}] $y
    $pdf setStrokeColor 0 0 0
}

# ============================================================
# Text-Transformationen
# ============================================================

proc ::pdf4tcllib::drawing::textRotated {pdf txt x y angle size {font Helvetica}} {
    # Rotierter Text.
    # angle: Drehwinkel in Grad (gegen Uhrzeigersinn)
    $pdf setFont $size $font
    if {![catch {$pdf text $txt -x $x -y $y -angle $angle}]} { return }

    # Fallback: characterweise positionieren
    set pi [expr {acos(-1)}]
    set dx [expr {cos($angle * $pi / 180.0)}]
    set dy [expr {sin($angle * $pi / 180.0)}]
    set spacing [expr {$size * 0.6}]
    set cx $x; set cy $y
    foreach c [split $txt ""] {
        $pdf text $c -x $cx -y $cy
        set cx [expr {$cx + $spacing * $dx}]
        set cy [expr {$cy - $spacing * $dy}]
    }
}

proc ::pdf4tcllib::drawing::textScaled {pdf txt x y sx sy size {font Helvetica}} {
    # Skalierter Text.
    # sx, sy: Skalierungsfaktoren
    if {![catch {$pdf text $txt -x $x -y $y -scale $sx $sy -size $size -font $font}]} { return }

    # Fallback
    set spacing [expr {$size * 0.6 * $sx}]
    $pdf setFont [expr {$size * $sy}] $font
    set cx $x
    foreach c [split $txt ""] {
        $pdf text $c -x $cx -y $y
        set cx [expr {$cx + $spacing}]
    }
}

proc ::pdf4tcllib::drawing::textSkewed {pdf txt x y skewX skewY size {font Helvetica}} {
    # Geneigter Text (Pseudo-Italic).
    # skewX, skewY: Neigungswinkel in Grad
    if {![catch {$pdf text $txt -x $x -y $y -skew $skewX $skewY -size $size -font $font}]} { return }

    # Fallback
    set pi [expr {acos(-1)}]
    set tanx [expr {tan($skewX * $pi / 180.0)}]
    set spacing [expr {$size * 0.6}]
    $pdf setFont $size $font
    set cx $x
    foreach c [split $txt ""] {
        set oy [expr {$tanx * ($cx - $x)}]
        $pdf text $c -x $cx -y [expr {$y + $oy}]
        set cx [expr {$cx + $spacing}]
    }
}

# ============================================================
# Private Helfer
# ============================================================

proc ::pdf4tcllib::drawing::_arcPoints {ptsVar cx cy r startDeg endDeg segments} {
    # Adds Kreisbogen-Punkte zur Liste hinzu.
    upvar $ptsVar pts
    set pi [expr {acos(-1)}]
    for {set i 0} {$i <= $segments} {incr i} {
        set ang [expr {($startDeg + ($endDeg - $startDeg) * $i / double($segments)) * $pi / 180.0}]
        lappend pts [expr {$cx + $r * cos($ang)}]
        lappend pts [expr {$cy + $r * sin($ang)}]
    }
}

# ================================================================
# Module: pdf4tcllib::image
# ================================================================

# pdf4tcllib::image -- Image integration for pdf4tcl
#
# Adds Tk-Bilder in PDF-Dokumente ein.
# Requires Tk (for photo image).
#
# Usage:
#   package require pdf4tcllib::image 0.1
#   pdf4tcllib::image::insert $pdf $tkImg -x 50 -y yVar -maxwidth 500

# Tk is benoetigt for image-Funktionen.
# In GUI-Apps (mdhelp4) immer vorhanden.
catch {package require Tk}

namespace eval ::pdf4tcllib::image {}

# ============================================================
# Oeffentliche API
# ============================================================

proc ::pdf4tcllib::image::insert {pdf tkImg x yVar maxW yTop yBot pageNoVar pageW pageH margin fontSize {debug 0}} {
    # Adds a Tk image centered (full width) to the PDF.
    #
    # The image is proportionally scaled to maxW.
    # On page break a new page is started.

    upvar $yVar y
    upvar $pageNoVar pageNo

    if {[catch {
        set imgW [image width $tkImg]
        set imgH [image height $tkImg]
    }]} {
        return 0
    }

    if {$imgW == 0 || $imgH == 0} { return 0 }

    # Skalierung
    set scale [expr {$maxW / double($imgW)}]
    set pdfW  [expr {int($imgW * $scale)}]
    set pdfH  [expr {int($imgH * $scale)}]

    # Maximale height begrenzen
    set maxImgH [expr {($yBot - $yTop) * 0.7}]
    if {$pdfH > $maxImgH} {
        set scale [expr {$maxImgH / double($imgH)}]
        set pdfW  [expr {int($imgW * $scale)}]
        set pdfH  [expr {int($imgH * $scale)}]
    }

    # Page break if noetig
    if {($y + $pdfH + 10) > $yBot} {
        _pageBreak $pdf pageNo $pageW $pageH $margin $fontSize
        set y $yTop
    }

    # Bilddaten extrahieren
    set imgData [_extractImageData $tkImg]
    if {$imgData eq ""} { return 0 }

    set pdfImg [$pdf addRawImage $imgData]
    $pdf putImage $pdfImg $x $y -width $pdfW -height $pdfH

    set y [expr {$y + $pdfH + 10}]

    if {$debug} {
        puts "PDF Image: ${imgW}x${imgH} -> ${pdfW}x${pdfH} pt"
    }

    return $pdfH
}

proc ::pdf4tcllib::image::insertAt {pdf tkImg xPos yVar maxW yTop yBot pageNoVar pageW pageH margin fontSize {debug 0}} {
    # Adds a Tk image at a specific X position.
    #
    # Wie insert, but with freier X-Positionierung.

    upvar $yVar y
    upvar $pageNoVar pageNo

    if {[catch {
        set imgW [image width $tkImg]
        set imgH [image height $tkImg]
    }]} {
        return 0
    }

    if {$imgW == 0 || $imgH == 0} { return 0 }

    # Available width from xPos
    set availW [expr {$maxW - ($xPos - 50)}]
    if {$availW < 50} { set availW $maxW }

    set scale [expr {$availW / double($imgW)}]
    if {$scale > 1.0} { set scale 1.0 }
    set pdfW  [expr {int($imgW * $scale)}]
    set pdfH  [expr {int($imgH * $scale)}]

    # Maximale height
    set maxImgH [expr {($yBot - $yTop) * 0.7}]
    if {$pdfH > $maxImgH} {
        set scale [expr {$maxImgH / double($imgH)}]
        set pdfW  [expr {int($imgW * $scale)}]
        set pdfH  [expr {int($imgH * $scale)}]
    }

    # Page break
    if {($y + $pdfH + 10) > $yBot} {
        _pageBreak $pdf pageNo $pageW $pageH $margin $fontSize
        set y $yTop
    }

    set imgData [_extractImageData $tkImg]
    if {$imgData eq ""} { return 0 }

    set pdfImg [$pdf addRawImage $imgData]
    $pdf putImage $pdfImg $xPos $y -width $pdfW -height $pdfH

    # y is NOT updated -- caller decides
    # (ermoeglicht nebeneinanderliegende Bilder)
    return $pdfH
}

# ============================================================
# Private Helfer
# ============================================================

proc ::pdf4tcllib::image::_extractImageData {tkImg} {
    # Extracts RGB data from a Tk photo image.
    #
    # Returns Liste: width height RGB-Bytes (als Hex)

    if {[catch {
        set w [image width $tkImg]
        set h [image height $tkImg]
    }]} {
        return ""
    }

    if {$w == 0 || $h == 0} { return "" }

    set data [list $w $h]
    for {set row 0} {$row < $h} {incr row} {
        set rowData ""
        for {set col 0} {$col < $w} {incr col} {
            set pixel [$tkImg get $col $row]
            lassign $pixel r g b
            append rowData [format "%02x%02x%02x" $r $g $b]
        }
        lappend data $rowData
    }

    return $data
}

proc ::pdf4tcllib::image::_pageBreak {pdf pageNoVar pageW pageH margin fontSize} {
    # Page break.
    upvar $pageNoVar pageNo
    set fontSans [::pdf4tcllib::fonts::fontSans]
    set y [expr {$pageH - $margin * 0.5}]
    set x [expr {$pageW - $margin}]
    $pdf setFont [expr {$fontSize - 2}] $fontSans
    ::pdf4tcllib::unicode::safeText $pdf "- $pageNo -" -x $x -y $y -align right
    $pdf endPage
    incr pageNo
    $pdf startPage
}
