#!/usr/bin/env tclsh
# parser-hardbreak.tcl - Tests for hard line break support (mdparser 0.2)

package require tcltest
namespace import ::tcltest::*

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require mdparser 0.2

# ============================================================
# Hard break via two trailing spaces
# ============================================================

test hardbreak-spaces-1 "two trailing spaces produce linebreak node" -body {
    # Build markdown with explicit trailing spaces
    set md "line one  \nline two"
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set inlines [dict get $block content]
    # Should contain: text "line one" + linebreak + text "line two"
    set types {}
    foreach node $inlines {
        lappend types [dict get $node type]
    }
    expr {"linebreak" in $types}
} -result {1}

test hardbreak-spaces-2 "text before linebreak is trimmed" -body {
    set md "hello world  \nnext line"
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set inlines [dict get $block content]
    set firstText ""
    foreach node $inlines {
        if {[dict get $node type] eq "text"} {
            set firstText [dict get $node value]
            break
        }
    }
    # Should not contain trailing spaces
    expr {[string trimright $firstText] eq $firstText}
} -result {1}

test hardbreak-spaces-3 "without trailing spaces no linebreak" -body {
    set md "line one\nline two"
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set inlines [dict get $block content]
    set types {}
    foreach node $inlines {
        lappend types [dict get $node type]
    }
    expr {"linebreak" in $types}
} -result {0}

# ============================================================
# Hard break via trailing backslash
# ============================================================

test hardbreak-backslash-1 "trailing backslash produces linebreak" -body {
    set md "line one\\\nline two"
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set inlines [dict get $block content]
    set types {}
    foreach node $inlines {
        lappend types [dict get $node type]
    }
    expr {"linebreak" in $types}
} -result {1}

test hardbreak-backslash-2 "backslash itself is stripped" -body {
    set md "hello\\\nnext"
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set inlines [dict get $block content]
    set firstText ""
    foreach node $inlines {
        if {[dict get $node type] eq "text"} {
            set firstText [dict get $node value]
            break
        }
    }
    # Should not end with backslash
    expr {![string match "*\\" $firstText]}
} -result {1}

# ============================================================
# Multiple hard breaks
# ============================================================

test hardbreak-multi-1 "multiple hard breaks in one paragraph" -body {
    set md "line one  \nline two  \nline three"
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set inlines [dict get $block content]
    set breakCount 0
    foreach node $inlines {
        if {[dict get $node type] eq "linebreak"} {
            incr breakCount
        }
    }
    set breakCount
} -result {2}

# ============================================================
# Hard breaks with inline formatting
# ============================================================

test hardbreak-with-bold "hard break after bold text" -body {
    set md "**bold text**  \nnext line"
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set inlines [dict get $block content]
    set types {}
    foreach node $inlines {
        lappend types [dict get $node type]
    }
    expr {"linebreak" in $types && "strong" in $types}
} -result {1}

# ============================================================
# supports updated
# ============================================================

test supports-linebreak-1 "supports lists inline:linebreak" -body {
    expr {"inline:linebreak" in [mdparser::supports {}]}
} -result {1}

cleanupTests
