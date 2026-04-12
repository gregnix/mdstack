# mdtext.tm
# (c) 2026 Gregor Ebbing -- MIT License (see LICENSE)
# ------------------------------------------------------------
# mdtext – structured text widget core
# ------------------------------------------------------------
# A minimal, extensible text editor core.
# Wrapper around the Tk text widget with clean API.
#
# Features:
# - Clean API (get, set, wrap, prefix, heading...)
# - Smart Return (list continuation)
# - Tab/Shift-Tab indentation
# - lineType context recognition
# - Feature flags (all can be disabled)
#

package provide mdtext 0.1

namespace eval mdtext {
    namespace export create gettext settext getHeadings
    variable version 0.1
    variable features
    array set features {}
    variable widgets
    array set widgets {}
}

# Helper function to get original widget
proc mdtext::_t {w} {
    variable widgets
    return $widgets($w)
}

# ------------------------------------------------------------
# create - Creates mdtext widget
# ------------------------------------------------------------
# Options are passed through to text widget
#
proc mdtext::create {w args} {
    variable widgets
    
    # Defaults
    array set opts {
        -undo 1
        -wrap word
        -font TkFixedFont
        -insertwidth 2
        -padx 5
        -pady 5
    }
    
    # Override user options
    foreach {key val} $args {
        set opts($key) $val
    }
    
    # Create text widget
    text $w {*}[array get opts]
    
    # Rename original command (safe name without :: and .)
    # Remove leading dot and replace remaining dots with underscores
    set safeName [string trimleft $w .]
    set safeName [string map {. _} $safeName]
    set origCmd "::mdtext::_w_$safeName"
    rename $w $origCmd
    set widgets($w) $origCmd
    
    # Dispatcher as alias
    interp alias {} $w {} mdtext::dispatch $w
    
    # Define base tags
    _defineTags $w
    
    # Initialize state
    variable state
    set state($w,file) ""
    set state($w,modified) 0
    set state($w,onchange) ""
    
    # Modified-Tracking - bind to Widget-PATH, not command!
    bind $w <<Modified>> [list mdtext::_onModified $w]
    
    # Smart bindings (feature-dependent)
    # IMPORTANT: break must be in bind-script, not in proc return!
    bind $w <Return> "mdtext::_handleReturn $w; break"
    bind $w <Tab> "mdtext::_handleTab $w; break"
    bind $w <Shift-Tab> "mdtext::_handleShiftTab $w; break"
    
    return $w
}

# ------------------------------------------------------------
# _defineTags - Base Styles
# ------------------------------------------------------------
proc mdtext::_defineTags {w} {
    set t [_t $w]
    
    # Headings
    $t tag configure heading1 -font {TkDefaultFont 18 bold} -spacing1 8 -spacing3 4
    $t tag configure heading2 -font {TkDefaultFont 16 bold} -spacing1 6 -spacing3 3
    $t tag configure heading3 -font {TkDefaultFont 14 bold} -spacing1 4 -spacing3 2
    $t tag configure heading4 -font {TkDefaultFont 12 bold}
    $t tag configure heading5 -font {TkDefaultFont 11 bold}
    $t tag configure heading6 -font {TkDefaultFont 10 bold}
    
    # Inline formatting
    $t tag configure bold -font {TkDefaultFont -1 bold}
    $t tag configure italic -font {TkDefaultFont -1 italic}
    $t tag configure code -font TkFixedFont -background #f5f5f5 -foreground #c7254e
    
    # Block elements
    $t tag configure codeblock -font TkFixedFont -background #f8f8f8 \
        -lmargin1 20 -lmargin2 20 -rmargin 20
    $t tag configure quote -foreground #666666 -lmargin1 20 -lmargin2 20 \
        -font {TkDefaultFont -1 italic}
    
    # Lists
    $t tag configure list -lmargin1 20 -lmargin2 40
    
    # Link
    $t tag configure link -foreground #0066cc -underline 1
}

# ------------------------------------------------------------
# dispatch - Kommando-Dispatcher
# ------------------------------------------------------------
proc mdtext::dispatch {w cmd args} {
    switch -- $cmd {
        widget        { return $w }
        text          { return [_t $w] }
        get           { return [mdtext::gettext $w {*}$args] }
        set           { return [mdtext::settext $w {*}$args] }
        clear         { return [mdtext::clear $w] }
        
        wrap          { return [mdtext::wrapSelection $w {*}$args] }
        prefix        { return [mdtext::prefixLine $w {*}$args] }
        heading       { return [mdtext::insertHeading $w {*}$args] }
        codeblock     { return [mdtext::insertCodeBlock $w {*}$args] }
        checkbox      { return [mdtext::toggleCheckbox $w] }
        table         { return [mdtext::insertTable $w {*}$args] }
        
        currentLine   { return [mdtext::currentLine $w] }
        lineType      { return [mdtext::lineType $w] }
        getHeadings   { return [mdtext::getHeadings $w] }
        
        enableFeature  { return [mdtext::enableFeature $w {*}$args] }
        disableFeature { return [mdtext::disableFeature $w {*}$args] }
        featureEnabled { return [mdtext::featureEnabled $w {*}$args] }
        
        load          { return [mdtext::load $w {*}$args] }
        save          { return [mdtext::save $w {*}$args] }
        
        file          { return [mdtext::file $w {*}$args] }
        modified      { return [mdtext::modified $w {*}$args] }
        onchange      { return [mdtext::onchange $w {*}$args] }
        
        tag           { return [[_t $w] tag {*}$args] }
        
        default {
            return [[_t $w] $cmd {*}$args]
        }
    }
}

# ------------------------------------------------------------
# Basis-Operationen
# ------------------------------------------------------------

proc mdtext::gettext {w args} {
    if {[llength $args] == 0} {
        return [[_t $w] get 1.0 end-1c]
    }
    return [[_t $w] get {*}$args]
}

proc mdtext::settext {w text} {
    [_t $w] delete 1.0 end
    [_t $w] insert 1.0 $text
    [_t $w] edit modified false
    variable state
    set state($w,modified) 0
}

proc mdtext::clear {w} {
    [_t $w] delete 1.0 end
    [_t $w] edit modified false
    variable state
    set state($w,modified) 0
    set state($w,file) ""
}

# ------------------------------------------------------------
# Format-Operationen
# ------------------------------------------------------------

proc mdtext::wrapSelection {w left {right ""}} {
    if {$right eq ""} {
        set right $left
    }
    
    set t [_t $w]
    
    if {[$t tag ranges sel] eq ""} {
        # No selection - insert placeholder
        set pos [$t index insert]
        $t insert insert "${left}text${right}"
        # Select "text"
        $t tag add sel "$pos + [string length $left] chars" \
                       "$pos + [expr {[string length $left] + 4}] chars"
    } else {
        set txt [$t get sel.first sel.last]
        
        # Check if already wrapped
        if {[string match "${left}*${right}" $txt]} {
            # Remove
            set inner [string range $txt [string length $left] end-[string length $right]]
            $t delete sel.first sel.last
            $t insert insert $inner
        } else {
            # Add
            $t delete sel.first sel.last
            $t insert insert "${left}${txt}${right}"
        }
    }
}

proc mdtext::prefixLine {w prefix} {
    set t [_t $w]
    set lineStart [$t index "insert linestart"]
    set lineEnd [$t index "insert lineend"]
    set line [$t get $lineStart $lineEnd]
    
    # Check if prefix already present
    if {[string match "${prefix}*" $line]} {
        # Remove
        $t delete $lineStart "$lineStart + [string length $prefix] chars"
    } else {
        # Add
        $t insert $lineStart $prefix
    }
}

proc mdtext::insertHeading {w level} {
    set t [_t $w]
    set lineStart [$t index "insert linestart"]
    set lineEnd [$t index "insert lineend"]
    set line [$t get $lineStart $lineEnd]
    
    # Remove existing heading markers
    set cleanLine [string trimleft $line "# "]
    
    # Neuen Marker setzen
    set hashes [string repeat "#" $level]
    $t delete $lineStart $lineEnd
    $t insert $lineStart "$hashes $cleanLine"
}

proc mdtext::insertCodeBlock {w {lang ""}} {
    set t [_t $w]
    
    if {[$t tag ranges sel] eq ""} {
        $t insert insert "\n\`\`\`$lang\n\n\`\`\`\n"
        # Cursor in den Block
        $t mark set insert "insert - 5 chars"
    } else {
        set txt [$t get sel.first sel.last]
        $t delete sel.first sel.last
        $t insert insert "\n\`\`\`$lang\n${txt}\n\`\`\`\n"
    }
}

proc mdtext::toggleCheckbox {w} {
    set t [_t $w]
    set lineStart [$t index "insert linestart"]
    set lineEnd [$t index "insert lineend"]
    set line [$t get $lineStart $lineEnd]
    
    # Checkbox-Pattern: - [ ] oder - [x]
    if {[regexp {^- \[ \] (.*)$} $line -> rest]} {
        # Unchecked → Checked
        $t delete $lineStart $lineEnd
        $t insert $lineStart "- \[x\] $rest"
    } elseif {[regexp {^- \[x\] (.*)$} $line -> rest]} {
        # Checked → Unchecked
        $t delete $lineStart $lineEnd
        $t insert $lineStart "- \[ \] $rest"
    } elseif {[regexp {^- (.*)$} $line -> rest]} {
        # List → Checkbox
        $t delete $lineStart $lineEnd
        $t insert $lineStart "- \[ \] $rest"
    } else {
        # Kein Prefix → Neue Checkbox
        $t insert $lineStart "- \[ \] "
    }
}

# ------------------------------------------------------------
# File operations
# ------------------------------------------------------------

proc mdtext::load {w filepath} {
    if {![file exists $filepath]} {
        return -code error "File not found: $filepath"
    }
    
    set f [open $filepath r]
    fconfigure $f -encoding utf-8
    set content [read $f]
    close $f
    
    mdtext::set $w $content
    
    variable state
    set state($w,file) $filepath
    set state($w,modified) 0
    
    return $filepath
}

proc mdtext::save {w {filepath ""}} {
    variable state
    
    if {$filepath eq ""} {
        set filepath $state($w,file)
    }
    
    if {$filepath eq ""} {
        return -code error "No file path specified"
    }
    
    set content [mdtext::get $w]
    
    set f [open $filepath w]
    fconfigure $f -encoding utf-8
    puts -nonewline $f $content
    close $f
    
    set state($w,file) $filepath
    set state($w,modified) 0
    [_t $w] edit modified false
    
    return $filepath
}

# ------------------------------------------------------------
# State-Operationen
# ------------------------------------------------------------

proc mdtext::file {w args} {
    variable state
    
    if {[llength $args] == 0} {
        return $state($w,file)
    }
    
    set state($w,file) [lindex $args 0]
}

proc mdtext::modified {w args} {
    variable state
    
    if {[llength $args] == 0} {
        return $state($w,modified)
    }
    
    set state($w,modified) [lindex $args 0]
}

proc mdtext::onchange {w args} {
    variable state
    
    if {[llength $args] == 0} {
        return $state($w,onchange)
    }
    
    set state($w,onchange) [lindex $args 0]
}

proc mdtext::_onModified {w} {
    variable state
    
    set t [_t $w]
    if {[$t edit modified]} {
        set state($w,modified) 1
        $t edit modified false
        
        # Execute callback
        mdtext::_fireOnChange $w
    }
}

# Execute callback (also callable from smart functions)
proc mdtext::_fireOnChange {w} {
    variable state
    if {[info exists state($w,onchange)] && $state($w,onchange) ne ""} {
        after idle [list catch [list uplevel #0 $state($w,onchange)]]
    }
}

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

proc mdtext::destroy {w} {
    variable state
    variable features
    
    catch {::destroy [_t $w]}
    catch {interp alias {} $w {}}
    
    array unset state $w,*
    array unset features $w,*
}

# ------------------------------------------------------------
# Feature-System
# ------------------------------------------------------------

proc mdtext::enableFeature {w name} {
    variable features
    set features($w,$name) 1
}

proc mdtext::disableFeature {w name} {
    variable features
    set features($w,$name) 0
}

proc mdtext::featureEnabled {w name} {
    variable features
    return [expr {[info exists features($w,$name)] && $features($w,$name)}]
}

# ------------------------------------------------------------
# Kontext-Abfragen
# ------------------------------------------------------------

proc mdtext::currentLine {w} {
    set t [_t $w]
    set lineStart [$t index "insert linestart"]
    return [$t get $lineStart "$lineStart lineend"]
}

proc mdtext::lineType {w} {
    set txt [mdtext::currentLine $w]
    set trimmed [string trim $txt]
    
    if {$trimmed eq ""} {
        return empty
    }
    if {[regexp {^#{1,6}\s} $txt]} {
        return heading
    }
    if {[regexp {^- \[[ x]\]} $txt]} {
        return checkbox
    }
    if {[regexp {^\d+\.\s} $txt]} {
        return numlist
    }
    if {[regexp {^[-*+]\s} $txt]} {
        return list
    }
    if {[regexp {^>\s} $txt]} {
        return quote
    }
    if {[regexp {^```} $txt]} {
        return codeblock
    }
    if {[regexp {^\s{4}} $txt]} {
        return code
    }
    return text
}

proc mdtext::getHeadings {w} {
    set t [_t $w]
    set result {}
    set lineNum 1
    
    foreach line [split [$t get 1.0 end-1c] "\n"] {
        if {[regexp {^(#{1,6})\s+(.*)$} $line -> hashes text]} {
            set level [string length $hashes]
            lappend result [list $level $text "$lineNum.0"]
        }
        incr lineNum
    }
    
    return $result
}

# ------------------------------------------------------------
# Smart Return
# ------------------------------------------------------------

# Handler for binding
proc mdtext::_handleReturn {w} {
    mdtext::_onReturn $w
    mdtext::_fireOnChange $w
}

proc mdtext::_onReturn {w} {
    set t [_t $w]
    
    # Check if feature enabled
    if {![mdtext::featureEnabled $w smartReturn]} {
        # Default-Verhalten
        $t insert insert "\n"
        return
    }
    
    set type [mdtext::lineType $w]
    set lineStart [$t index "insert linestart"]
    set lineText [$t get $lineStart "$lineStart lineend"]
    
    # Keep leading whitespace
    regexp {^(\s*)} $lineText -> indent
    
    switch -- $type {
        list {
            # Leere Liste beenden
            if {[regexp {^(\s*)[-*+]\s*$} $lineText]} {
                $t delete $lineStart "$lineStart lineend"
                return
            }
            # List fortsetzen
            regexp {^(\s*)([-*+])\s} $lineText -> indent marker
            $t insert insert "\n$indent$marker "
            return
        }
        numlist {
            # Leere nummerierte Liste beenden
            if {[regexp {^(\s*)\d+\.\s*$} $lineText]} {
                $t delete $lineStart "$lineStart lineend"
                return
            }
            # Increment number
            if {[regexp {^(\s*)(\d+)\.\s} $lineText -> indent num]} {
                set nextNum [expr {$num + 1}]
                $t insert insert "\n$indent$nextNum. "
                return
            }
        }
        checkbox {
            # Leere Checkbox beenden
            if {[regexp {^(\s*)- \[[ x]\]\s*$} $lineText]} {
                $t delete $lineStart "$lineStart lineend"
                return
            }
            # Checkbox fortsetzen
            regexp {^(\s*)} $lineText -> indent
            $t insert insert "\n$indent- \[ \] "
            return
        }
        quote {
            # Leeres Zitat beenden
            if {[regexp {^(\s*)>\s*$} $lineText]} {
                $t delete $lineStart "$lineStart lineend"
                return
            }
            # Blockquote fortsetzen
            regexp {^(\s*)} $lineText -> indent
            $t insert insert "\n$indent> "
            return
        }
    }
    
    # Default
    $t insert insert "\n"
}

# ------------------------------------------------------------
# Tab / Shift-Tab (indentation)
# ------------------------------------------------------------

# Handler for binding
proc mdtext::_handleTab {w} {
    mdtext::_onTab $w
    mdtext::_fireOnChange $w
}

proc mdtext::_handleShiftTab {w} {
    mdtext::_onShiftTab $w
    mdtext::_fireOnChange $w
}

proc mdtext::_onTab {w} {
    set t [_t $w]
    
    # Check if feature enabled
    if {![mdtext::featureEnabled $w indent]} {
        # Default: insert tab character
        $t insert insert "\t"
        return
    }
    
    set type [mdtext::lineType $w]
    
    # Only indent for lists and checkboxes
    if {$type in {list numlist checkbox quote}} {
        set lineStart [$t index "insert linestart"]
        $t insert $lineStart "  "
        return
    }
    
    # Sonst: 2 Spaces
    $t insert insert "  "
}

proc mdtext::_onShiftTab {w} {
    set t [_t $w]
    
    # Check if feature enabled
    if {![mdtext::featureEnabled $w indent]} {
        return
    }
    
    set lineStart [$t index "insert linestart"]
    set txt [$t get $lineStart "$lineStart + 2 chars"]
    
    # Remove 2 leading spaces
    if {$txt eq "  "} {
        $t delete $lineStart "$lineStart + 2 chars"
        return
    }
    
    # Oder 1 Tab
    set txt [$t get $lineStart "$lineStart + 1 chars"]
    if {$txt eq "\t"} {
        $t delete $lineStart "$lineStart + 1 chars"
    }
}

# ------------------------------------------------------------
# Tablen
# ------------------------------------------------------------

proc mdtext::insertTable {w {rows 3} {cols 3}} {
    set t [_t $w]
    
    # Header
    set header "|"
    set separator "|"
    for {set c 1} {$c <= $cols} {incr c} {
        append header " Spalte$c |"
        append separator " --- |"
    }
    
    # Lines
    set body ""
    for {set r 1} {$r < $rows} {incr r} {
        append body "|"
        for {set c 1} {$c <= $cols} {incr c} {
            append body "   |"
        }
        append body "\n"
    }
    
    $t insert insert "\n$header\n$separator\n$body"
}
