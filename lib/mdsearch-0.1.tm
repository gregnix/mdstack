# mdsearch-0.1.tm
# ============================================================
# Full-text search for mdstack
# ============================================================
# Search in viewer widget with highlighting and navigation.
#
# API:
#   mdsearch::find $viewerPath $pattern      → List of match positions
#   mdsearch::next $viewerPath               → jumps to next match
#   mdsearch::prev $viewerPath               → jumps to previous match
#   mdsearch::clearHighlight $viewerPath     → removes all highlights
#   mdsearch::count $viewerPath              → Number of current matches
#   mdsearch::current $viewerPath            → Index of current match (1-based)
#
# Tags:
#   searchmatch   – Background for all matches
#   searchcurrent – Background for current match
#
# Example:
#   package require mdsearch 0.1
#   set n [mdsearch::find .v "Tcl"]
#   puts "[llength $n] matches found"
#   mdsearch::next .v   ;# to first/next match
#

package require Tk
package provide mdsearch 0.1

namespace eval mdsearch {
    namespace export find next prev clearHighlight count current
    variable state
    # Pro Widget: matches (Positionsliste), currentIdx (0-based, -1=none)
}

proc mdsearch::_initTags {t} {
    # Configure tags only once
    if {"searchmatch" ni [$t tag names]} {
        $t tag configure searchmatch -background #FFEB3B -foreground #000000
        $t tag configure searchcurrent -background #FF9800 -foreground #000000
        # searchcurrent above searchmatch
        $t tag raise searchcurrent searchmatch
    }
}

proc mdsearch::find {viewerPath pattern} {
    # Sucht pattern im Viewer-Text-Widget.
    # Returns list of match start positions.
    variable state

    set t [mdviewer::widget $viewerPath]
    mdsearch::clearHighlight $viewerPath
    mdsearch::_initTags $t

    if {$pattern eq ""} {
        return {}
    }

    set matches {}
    # Text widget must briefly be normal for tag add
    set wasDisabled [expr {[$t cget -state] eq "disabled"}]
    if {$wasDisabled} { $t configure -state normal }

    set start 1.0
    while {1} {
        set pos [$t search -nocase -count len -- $pattern $start end]
        if {$pos eq ""} break
        $t tag add searchmatch $pos "$pos + $len chars"
        lappend matches $pos
        set start "$pos + $len chars"
    }

    if {$wasDisabled} { $t configure -state disabled }

    set state($viewerPath,matches) $matches
    set state($viewerPath,currentIdx) -1

    return $matches
}

proc mdsearch::next {viewerPath} {
    # Jumps to next match. Wraps around.
    # Returns 1-based index, or 0 if no matches.
    variable state

    if {![info exists state($viewerPath,matches)]} { return 0 }
    set matches $state($viewerPath,matches)
    if {[llength $matches] == 0} { return 0 }

    set idx $state($viewerPath,currentIdx)
    incr idx
    if {$idx >= [llength $matches]} { set idx 0 }

    mdsearch::_gotoIdx $viewerPath $idx
    return [expr {$idx + 1}]
}

proc mdsearch::prev {viewerPath} {
    # Jumps to previous match. Wraps around.
    variable state

    if {![info exists state($viewerPath,matches)]} { return 0 }
    set matches $state($viewerPath,matches)
    if {[llength $matches] == 0} { return 0 }

    set idx $state($viewerPath,currentIdx)
    incr idx -1
    if {$idx < 0} { set idx [expr {[llength $matches] - 1}] }

    mdsearch::_gotoIdx $viewerPath $idx
    return [expr {$idx + 1}]
}

proc mdsearch::_gotoIdx {viewerPath idx} {
    # Internal helper: sets currentIdx, highlights match, scrolls to it.
    variable state

    set t [mdviewer::widget $viewerPath]
    set matches $state($viewerPath,matches)
    set wasDisabled [expr {[$t cget -state] eq "disabled"}]
    if {$wasDisabled} { $t configure -state normal }

    # Remove old current tag
    $t tag remove searchcurrent 1.0 end

    # Neuen Current-Tag setzen
    set pos [lindex $matches $idx]
    # Determine length from searchmatch range
    set range [$t tag nextrange searchmatch $pos]
    if {$range ne ""} {
        $t tag add searchcurrent [lindex $range 0] [lindex $range 1]
    }

    if {$wasDisabled} { $t configure -state disabled }

    $t see $pos
    set state($viewerPath,currentIdx) $idx
}

proc mdsearch::clearHighlight {viewerPath} {
    # Removes all search highlights.
    variable state

    set t [mdviewer::widget $viewerPath]
    set wasDisabled [expr {[$t cget -state] eq "disabled"}]
    if {$wasDisabled} { $t configure -state normal }

    $t tag remove searchmatch 1.0 end
    $t tag remove searchcurrent 1.0 end

    if {$wasDisabled} { $t configure -state disabled }

    set state($viewerPath,matches) {}
    set state($viewerPath,currentIdx) -1
}

proc mdsearch::count {viewerPath} {
    # Number of current matches.
    variable state
    if {![info exists state($viewerPath,matches)]} { return 0 }
    return [llength $state($viewerPath,matches)]
}

proc mdsearch::current {viewerPath} {
    # 1-based Index of current match, 0 wenn keiner.
    variable state
    if {![info exists state($viewerPath,currentIdx)]} { return 0 }
    set idx $state($viewerPath,currentIdx)
    if {$idx < 0} { return 0 }
    return [expr {$idx + 1}]
}
