# mdtext.tm
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

package require Tcl 8.6-
package require Tk 8.6-

package provide mdstack::text 0.1

namespace eval mdstack::text {
    namespace export create gettext settext getHeadings
    variable version 0.1
    variable features
    array set features {}
    variable widgets
    array set widgets {}
}

# Helper function to get original widget
proc mdstack::text::_t {w} {
    variable widgets
    return $widgets($w)
}

# ------------------------------------------------------------
# create - Creates mdtext widget
# ------------------------------------------------------------
# Options are passed through to text widget
#
proc mdstack::text::create {w args} {
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
    set origCmd "::mdstack::text::_w_$safeName"
    rename $w $origCmd
    set widgets($w) $origCmd
    
    # Dispatcher as alias
    interp alias {} $w {} mdstack::text::dispatch $w
    
    # Define base tags
    _defineTags $w
    
    # Initialize state
    variable state
    set state($w,file) ""
    set state($w,modified) 0
    set state($w,onchange) ""
    
    # Modified-Tracking - bind to Widget-PATH, not command!
    bind $w <<Modified>> [list mdstack::text::_onModified $w]
    
    # Smart bindings (feature-dependent)
    # IMPORTANT: break must be in bind-script, not in proc return!
    bind $w <Return> "mdstack::text::_handleReturn $w; break"
    bind $w <Tab> "mdstack::text::_handleTab $w; break"
    bind $w <Shift-Tab> "mdstack::text::_handleShiftTab $w; break"
    
    return $w
}

# ------------------------------------------------------------
# _defineTags - Base Styles
# ------------------------------------------------------------
proc mdstack::text::_defineTags {w} {
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
proc mdstack::text::dispatch {w cmd args} {
    switch -- $cmd {
        widget        { return $w }
        text          { return [_t $w] }
        get           { return [mdstack::text::gettext $w {*}$args] }
        set           { return [mdstack::text::settext $w {*}$args] }
        clear         { return [mdstack::text::clear $w] }
        
        wrap          { return [mdstack::text::wrapSelection $w {*}$args] }
        prefix        { return [mdstack::text::prefixLine $w {*}$args] }
        heading       { return [mdstack::text::insertHeading $w {*}$args] }
        codeblock     { return [mdstack::text::insertCodeBlock $w {*}$args] }
        checkbox      { return [mdstack::text::toggleCheckbox $w] }
        table         { return [mdstack::text::insertTable $w {*}$args] }
        
        currentLine   { return [mdstack::text::currentLine $w] }
        lineType      { return [mdstack::text::lineType $w] }
        getHeadings   { return [mdstack::text::getHeadings $w] }
        
        enableFeature  { return [mdstack::text::enableFeature $w {*}$args] }
        disableFeature { return [mdstack::text::disableFeature $w {*}$args] }
        featureEnabled { return [mdstack::text::featureEnabled $w {*}$args] }
        
        load          { return [mdstack::text::load $w {*}$args] }
        save          { return [mdstack::text::save $w {*}$args] }
        
        file          { return [mdstack::text::file $w {*}$args] }
        modified      { return [mdstack::text::modified $w {*}$args] }
        onchange      { return [mdstack::text::onchange $w {*}$args] }
        
        tag           { return [[_t $w] tag {*}$args] }
        
        default {
            return [[_t $w] $cmd {*}$args]
        }
    }
}

# ------------------------------------------------------------
# Basis-Operationen
# ------------------------------------------------------------

proc mdstack::text::gettext {w args} {
    if {[llength $args] == 0} {
        return [[_t $w] get 1.0 end-1c]
    }
    return [[_t $w] get {*}$args]
}

proc mdstack::text::settext {w text} {
    [_t $w] delete 1.0 end
    [_t $w] insert 1.0 $text
    [_t $w] edit modified false
    variable state
    set state($w,modified) 0
}

proc mdstack::text::clear {w} {
    [_t $w] delete 1.0 end
    [_t $w] edit modified false
    variable state
    set state($w,modified) 0
    set state($w,file) ""
}

# ------------------------------------------------------------
# Format-Operationen
# ------------------------------------------------------------

proc mdstack::text::wrapSelection {w left {right ""}} {
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

proc mdstack::text::prefixLine {w prefix} {
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

proc mdstack::text::insertHeading {w level} {
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

proc mdstack::text::insertCodeBlock {w {lang ""}} {
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

proc mdstack::text::toggleCheckbox {w} {
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

proc mdstack::text::load {w filepath} {
    if {![file exists $filepath]} {
        return -code error "File not found: $filepath"
    }
    
    set f [open $filepath r]
    fconfigure $f -encoding utf-8
    set content [read $f]
    close $f
    
    mdstack::text::set $w $content
    
    variable state
    set state($w,file) $filepath
    set state($w,modified) 0
    
    return $filepath
}

proc mdstack::text::save {w {filepath ""}} {
    variable state
    
    if {$filepath eq ""} {
        set filepath $state($w,file)
    }
    
    if {$filepath eq ""} {
        return -code error "No file path specified"
    }
    
    set content [mdstack::text::get $w]
    
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

proc mdstack::text::file {w args} {
    variable state
    
    if {[llength $args] == 0} {
        return $state($w,file)
    }
    
    set state($w,file) [lindex $args 0]
}

proc mdstack::text::modified {w args} {
    variable state
    
    if {[llength $args] == 0} {
        return $state($w,modified)
    }
    
    set state($w,modified) [lindex $args 0]
}

proc mdstack::text::onchange {w args} {
    variable state
    
    if {[llength $args] == 0} {
        return $state($w,onchange)
    }
    
    set state($w,onchange) [lindex $args 0]
}

proc mdstack::text::_onModified {w} {
    variable state
    
    set t [_t $w]
    if {[$t edit modified]} {
        set state($w,modified) 1
        $t edit modified false
        
        # Execute callback
        mdstack::text::_fireOnChange $w
    }
}

# Execute callback (also callable from smart functions)
proc mdstack::text::_fireOnChange {w} {
    variable state
    if {[info exists state($w,onchange)] && $state($w,onchange) ne ""} {
        after idle [list catch [list uplevel #0 $state($w,onchange)]]
    }
}

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

proc mdstack::text::destroy {w} {
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

proc mdstack::text::enableFeature {w name} {
    variable features
    set features($w,$name) 1
}

proc mdstack::text::disableFeature {w name} {
    variable features
    set features($w,$name) 0
}

proc mdstack::text::featureEnabled {w name} {
    variable features
    return [expr {[info exists features($w,$name)] && $features($w,$name)}]
}

# ------------------------------------------------------------
# Kontext-Abfragen
# ------------------------------------------------------------

proc mdstack::text::currentLine {w} {
    set t [_t $w]
    set lineStart [$t index "insert linestart"]
    return [$t get $lineStart "$lineStart lineend"]
}

proc mdstack::text::lineType {w} {
    set txt [mdstack::text::currentLine $w]
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

proc mdstack::text::getHeadings {w} {
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
proc mdstack::text::_handleReturn {w} {
    mdstack::text::_onReturn $w
    mdstack::text::_fireOnChange $w
}

proc mdstack::text::_onReturn {w} {
    set t [_t $w]
    
    # Check if feature enabled
    if {![mdstack::text::featureEnabled $w smartReturn]} {
        # Default-Verhalten
        $t insert insert "\n"
        return
    }
    
    set type [mdstack::text::lineType $w]
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
proc mdstack::text::_handleTab {w} {
    mdstack::text::_onTab $w
    mdstack::text::_fireOnChange $w
}

proc mdstack::text::_handleShiftTab {w} {
    mdstack::text::_onShiftTab $w
    mdstack::text::_fireOnChange $w
}

proc mdstack::text::_onTab {w} {
    set t [_t $w]
    
    # Check if feature enabled
    if {![mdstack::text::featureEnabled $w indent]} {
        # Default: insert tab character
        $t insert insert "\t"
        return
    }
    
    set type [mdstack::text::lineType $w]
    
    # Only indent for lists and checkboxes
    if {$type in {list numlist checkbox quote}} {
        set lineStart [$t index "insert linestart"]
        $t insert $lineStart "  "
        return
    }
    
    # Sonst: 2 Spaces
    $t insert insert "  "
}

proc mdstack::text::_onShiftTab {w} {
    set t [_t $w]
    
    # Check if feature enabled
    if {![mdstack::text::featureEnabled $w indent]} {
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

proc mdstack::text::insertTable {w {rows 3} {cols 3}} {
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
