#!/usr/bin/env tclsh
# mdtext.tcl - Tests for mdtext-Widget

package require tcltest
namespace import ::tcltest::*

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

# Requires Tk for widget tests
if {[catch {package require Tk}]} {
    puts "Skipping mdtext tests (no Tk)"
    return
}

package require mdtext 0.1

# Test-Widget erstellen (versteckt)
wm withdraw .

test mdtext-1 "create widget" -body {
    set w [mdtext::create .t1]
    expr {$w eq ".t1"}
} -result {1} -cleanup {
    destroy .t1
}

test mdtext-2 "set and get text" -body {
    set w [mdtext::create .t2]
    $w set "Hello World"
    $w get
} -result {Hello World} -cleanup {
    destroy .t2
}

test mdtext-3 "clear" -body {
    set w [mdtext::create .t3]
    $w set "Some text"
    $w clear
    $w get
} -result {} -cleanup {
    destroy .t3
}

test mdtext-4 "modified flag" -body {
    set w [mdtext::create .t4]
    $w set "Text"
    set before [$w modified]
    $w insert end " more"
    after 10  ;# Wait for <<Modified>> event
    update
    set after [$w modified]
    list $before $after
} -result {0 1} -cleanup {
    destroy .t4
}

test mdtext-5 "lineType heading" -body {
    set w [mdtext::create .t5]
    $w set "# Heading"
    $w mark set insert 1.0
    $w lineType
} -result {heading} -cleanup {
    destroy .t5
}

test mdtext-6 "lineType list" -body {
    set w [mdtext::create .t6]
    $w set "- Item"
    $w mark set insert 1.0
    $w lineType
} -result {list} -cleanup {
    destroy .t6
}

test mdtext-7 "lineType checkbox" -body {
    set w [mdtext::create .t7]
    $w set "- \[ \] Task"
    $w mark set insert 1.0
    $w lineType
} -result {checkbox} -cleanup {
    destroy .t7
}

test mdtext-8 "lineType numlist" -body {
    set w [mdtext::create .t8]
    $w set "1. Item"
    $w mark set insert 1.0
    $w lineType
} -result {numlist} -cleanup {
    destroy .t8
}

test mdtext-9 "lineType quote" -body {
    set w [mdtext::create .t9]
    $w set "> Quote"
    $w mark set insert 1.0
    $w lineType
} -result {quote} -cleanup {
    destroy .t9
}

test mdtext-10 "getHeadings" -body {
    set w [mdtext::create .t10]
    $w set "# H1\n\n## H2\n\nText\n\n### H3"
    llength [$w getHeadings]
} -result {3} -cleanup {
    destroy .t10
}

test mdtext-11 "enableFeature" -body {
    set w [mdtext::create .t11]
    $w enableFeature smartReturn
    $w featureEnabled smartReturn
} -result {1} -cleanup {
    destroy .t11
}

test mdtext-12 "disableFeature" -body {
    set w [mdtext::create .t12]
    $w enableFeature indent
    $w disableFeature indent
    $w featureEnabled indent
} -result {0} -cleanup {
    destroy .t12
}

cleanupTests
