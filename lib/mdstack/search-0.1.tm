# mdsearch-0.1.tm
# ============================================================
# Full-text search for mdstack
# ============================================================
# Search in viewer widget with highlighting and navigation.
#
# API:
#   mdstack::search::find $viewerPath $pattern      → List of match positions
#   mdstack::search::next $viewerPath               → jumps to next match
#   mdstack::search::prev $viewerPath               → jumps to previous match
#   mdstack::search::clearHighlight $viewerPath     → removes all highlights
#   mdstack::search::count $viewerPath              → Number of current matches
#   mdstack::search::current $viewerPath            → Index of current match (1-based)
#
# Tags:
#   searchmatch   – Background for all matches
#   searchcurrent – Background for current match
#
# Example:
#   package require mdstack::search 0.1
#   set n [mdstack::search::find .v "Tcl"]
#   puts "[llength $n] matches found"
#   mdstack::search::next .v   ;# to first/next match
#

package require Tk
package provide mdstack::search 0.1

namespace eval mdstack::search {
    namespace export find next prev clearHighlight count current
    variable state
    # Pro Widget: matches (Positionsliste), currentIdx (0-based, -1=none)
}

proc mdstack::search::_initTags {t} {
    # Configure tags only once
    if {"searchmatch" ni [$t tag names]} {
        $t tag configure searchmatch -background #FFEB3B -foreground #000000
        $t tag configure searchcurrent -background #FF9800 -foreground #000000
        # searchcurrent above searchmatch
        $t tag raise searchcurrent searchmatch
    }
}

proc mdstack::search::find {viewerPath pattern} {
    # Sucht pattern im Viewer-Text-Widget.
    # Returns list of match start positions.
    variable state

    set t [mdstack::viewer::widget $viewerPath]
    mdstack::search::clearHighlight $viewerPath
    mdstack::search::_initTags $t

    if {$pattern eq ""} {
        return {}
    }

    set matches {}
    # Text widget must briefly be normal for tag add

    set start 1.0
    while {1} {
        set pos [$t search -nocase -count len -- $pattern $start end]
        if {$pos eq ""} break
        $t tag add searchmatch $pos "$pos + $len chars"
        lappend matches $pos
        set start "$pos + $len chars"
    }


    set state($viewerPath,matches) $matches
    set state($viewerPath,currentIdx) -1

    return $matches
}

proc mdstack::search::next {viewerPath} {
    # Jumps to next match. Wraps around.
    # Returns 1-based index, or 0 if no matches.
    variable state

    if {![info exists state($viewerPath,matches)]} { return 0 }
    set matches $state($viewerPath,matches)
    if {[llength $matches] == 0} { return 0 }

    set idx $state($viewerPath,currentIdx)
    incr idx
    if {$idx >= [llength $matches]} { set idx 0 }

    mdstack::search::_gotoIdx $viewerPath $idx
    return [expr {$idx + 1}]
}

proc mdstack::search::prev {viewerPath} {
    # Jumps to previous match. Wraps around.
    variable state

    if {![info exists state($viewerPath,matches)]} { return 0 }
    set matches $state($viewerPath,matches)
    if {[llength $matches] == 0} { return 0 }

    set idx $state($viewerPath,currentIdx)
    incr idx -1
    if {$idx < 0} { set idx [expr {[llength $matches] - 1}] }

    mdstack::search::_gotoIdx $viewerPath $idx
    return [expr {$idx + 1}]
}

proc mdstack::search::_gotoIdx {viewerPath idx} {
    # Internal helper: sets currentIdx, highlights match, scrolls to it.
    variable state

    set t [mdstack::viewer::widget $viewerPath]
    set matches $state($viewerPath,matches)

    # Remove old current tag
    $t tag remove searchcurrent 1.0 end

    # Neuen Current-Tag setzen
    set pos [lindex $matches $idx]
    # Determine length from searchmatch range
    set range [$t tag nextrange searchmatch $pos]
    if {$range ne ""} {
        $t tag add searchcurrent [lindex $range 0] [lindex $range 1]
    }


    $t see $pos
    set state($viewerPath,currentIdx) $idx
}

proc mdstack::search::clearHighlight {viewerPath} {
    # Removes all search highlights.
    variable state

    set t [mdstack::viewer::widget $viewerPath]

    $t tag remove searchmatch 1.0 end
    $t tag remove searchcurrent 1.0 end


    set state($viewerPath,matches) {}
    set state($viewerPath,currentIdx) -1
}

proc mdstack::search::count {viewerPath} {
    # Number of current matches.
    variable state
    if {![info exists state($viewerPath,matches)]} { return 0 }
    return [llength $state($viewerPath,matches)]
}

proc mdstack::search::current {viewerPath} {
    # 1-based Index of current match, 0 wenn keiner.
    variable state
    if {![info exists state($viewerPath,currentIdx)]} { return 0 }
    set idx $state($viewerPath,currentIdx)
    if {$idx < 0} { return 0 }
    return [expr {$idx + 1}]
}
