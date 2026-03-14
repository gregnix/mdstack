#!/usr/bin/env wish
# test-font-debug.tcl
# Diagnostik: Welche Font-Spezifikationen funktionieren auf diesem System?

package require Tk

wm title . "Font-Diagnostik"
wm geometry . 700x600

set t .t
text $t -wrap word -font {TkDefaultFont 12}
pack $t -fill both -expand 1

# System-Info
set defFamily [font actual TkDefaultFont -family]
set defSize   [font actual TkDefaultFont -size]
set fixFamily [font actual TkFixedFont -family]
set fixSize   [font actual TkFixedFont -size]

$t insert end "=== System-Info ===\n" {bold}
$t insert end "TkDefaultFont: family=$defFamily, size=$defSize\n"
$t insert end "TkFixedFont:   family=$fixFamily, size=$fixSize\n"
$t insert end "\n"

# --- Test 1: Verschiedene Font-Spezifikationen ---
$t insert end "=== Font-Spec Tests ===\n" {bold}

# A: Liste-Format (problematisch?)
$t tag configure testA -font [list $defFamily 12 bold italic]
$t insert end "A) Liste: \[list \$family 12 bold italic\] → " {}
$t insert end "bold+italic?" testA
$t insert end " ← actual: [font actual [list $defFamily 12 bold italic]]\n"

# B: Option-Format (eindeutig)
$t tag configure testB -font [list -family $defFamily -size 12 -weight bold -slant italic]
$t insert end "B) Option: \[-family ... -weight bold -slant italic\] → " {}
$t insert end "bold+italic?" testB
$t insert end " ← actual: [font actual [list -family $defFamily -size 12 -weight bold -slant italic]]\n"

# C: String-Format
$t tag configure testC -font "$defFamily 12 bold italic"
$t insert end "C) String: \"family 12 bold italic\" → " {}
$t insert end "bold+italic?" testC
$t insert end "\n"

# D: Nur bold
$t tag configure testD -font [list -family $defFamily -size 12 -weight bold]
$t insert end "D) Option bold: → " {}
$t insert end "bold?" testD
$t insert end "\n"

# E: Nur italic
$t tag configure testE -font [list -family $defFamily -size 12 -slant italic]
$t insert end "E) Option italic: → " {}
$t insert end "italic?" testE
$t insert end "\n\n"

# --- Test 2: Tag priorities ---
$t insert end "=== Tag priority tests ===\n" {bold}

# Simuliere Blockquote: quote_d0 (italic) + strong_q (bold+italic)
$t tag configure sim_quote -font [list -family $defFamily -size 12 -slant italic] -foreground #555555
$t tag configure sim_strong_q -font [list -family $defFamily -size 12 -weight bold -slant italic]
$t tag raise sim_strong_q sim_quote

set pos1 [$t index end]
$t insert end "Normal italic blockquote text, " sim_quote
set pos2 [$t index end]
$t insert end "BOLD+ITALIC" sim_quote
set pos3 [$t index end]
$t insert end ", and back to normal italic." sim_quote
$t tag add sim_strong_q $pos2 $pos3
$t insert end "\n"
$t insert end "  → 'BOLD+ITALIC' should be bold AND italic (tag raise)\n\n"

# Simuliere Blockquote MIT tag remove
$t tag configure sim_quote2 -font [list -family $defFamily -size 12 -slant italic] -foreground #555555
$t tag configure sim_strong_q2 -font [list -family $defFamily -size 12 -weight bold -slant italic]

set pos4 [$t index end]
$t insert end "Text ohne quote-tag, " {}
set pos5 [$t index end]
$t insert end "BOLD+ITALIC" sim_strong_q2
set pos6 [$t index end]
$t insert end ", wieder ohne." {}
$t tag add sim_quote2 $pos4 $pos6
# Jetzt quote2 von strong_q2-Bereich entfernen (wie dein Code)
$t tag remove sim_quote2 $pos5 $pos6
$t insert end "\n"
$t insert end "  → 'BOLD+ITALIC' should be bold+italic (tag remove)\n\n"

# --- Test 3: FixedFont Kontext ---
$t insert end "=== FixedFont (Table) Tests ===\n" {bold}

$t tag configure sim_cell -font TkFixedFont -background #fafafa
$t tag configure sim_strong_t -font [list -family $fixFamily -size $fixSize -weight bold]
$t tag configure sim_em_t -font [list -family $fixFamily -size $fixSize -slant italic]
$t tag raise sim_strong_t sim_cell
$t tag raise sim_em_t sim_cell

$t insert end "| " sim_cell
set p1 [$t index end]
$t insert end "normal" sim_cell
$t insert end " | " sim_cell
set p2 [$t index end]
$t insert end "BOLD" sim_cell
set p3 [$t index end]
$t insert end " | " sim_cell
set p4 [$t index end]
$t insert end "ITALIC" sim_cell
set p5 [$t index end]
$t insert end " |\n" sim_cell
$t tag add sim_strong_t $p2 $p3
$t tag add sim_em_t $p4 $p5
$t insert end "  → BOLD should be bold, ITALIC italic (both monospace)\n"

# Bold-Tag
$t tag configure bold -font {TkDefaultFont 12 bold}

puts "=== Diagnostik ==="
puts "Default family: $defFamily"
puts "Fixed family:   $fixFamily"
puts "Font A actual: [font actual [list $defFamily 12 bold italic]]"
puts "Font B actual: [font actual [list -family $defFamily -size 12 -weight bold -slant italic]]"
puts ""
puts "Check window: are marked texts formatted correctly?"
