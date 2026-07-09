# mdmodel-0.1.tm
#
# Document model on top of Markdown-AST v1.
#
# Features:
# - headings/toc
# - anchors map (anchor -> heading dict)
# - find (regexp search)
#
package require Tcl 8.6-

package provide mdstack::model 0.1

namespace eval mdstack::model {
    namespace export new ast toc headings anchors find meta
}

proc mdstack::model::new {ast} {
    mdstack::model::validateAst $ast

    set headings {}
    set anchors {}

    foreach block [dict get $ast blocks] {
        if {[dict get $block type] eq "heading"} {
            set h [dict create \
                level  [dict get $block level] \
                text   [mdstack::model::flattenInlines [dict get $block content]] \
                anchor [dict get $block anchor]]
            lappend headings $h
            dict set anchors [dict get $h anchor] $h
        }
    }

    return [dict create \
        type mdmodel \
        version 1 \
        ast $ast \
        headings $headings \
        anchors $anchors]
}

proc mdstack::model::ast {doc} {
    return [dict get $doc ast]
}

proc mdstack::model::headings {doc} {
    return [dict get $doc headings]
}

proc mdstack::model::anchors {doc} {
    return [dict get $doc anchors]
}

proc mdstack::model::toc {doc} {
    return [dict get $doc headings]
}

proc mdstack::model::meta {doc} {
    return [dict get [dict get $doc ast] meta]
}

proc mdstack::model::find {doc pattern} {
    set ast [dict get $doc ast]
    set results {}

    foreach block [dict get $ast blocks] {
        set type [dict get $block type]
        switch -- $type {
            heading {
                set text [mdstack::model::flattenInlines [dict get $block content]]
            }
            code_block {
                set text [dict get $block text]
            }
            paragraph {
                set text [mdstack::model::flattenInlines [dict get $block content]]
            }
            list {
                set text ""
                foreach it [dict get $block items] {
                    set firstBlock [lindex [dict get $it blocks] 0]
                    if {[dict get $firstBlock type] eq "paragraph"} {
                        append text [mdstack::model::flattenInlines [dict get $firstBlock content]] "\n"
                    }
                }
            }
            div {
                # Recurse into div blocks
                set text ""
                foreach subBlock [dict get $block blocks] {
                    if {[dict get $subBlock type] eq "paragraph"} {
                        append text [mdstack::model::flattenInlines [dict get $subBlock content]] "\n"
                    }
                }
            }
            default {
                set text ""
            }
        }
        if {$text ne "" && [regexp -nocase -- $pattern $text]} {
            lappend results $block
        }
    }
    return $results
}

proc mdstack::model::flattenInlines {inlines} {
    set out ""
    foreach node $inlines {
        set t [dict get $node type]
        switch -- $t {
            text { append out [dict get $node value] }
            link { append out [mdstack::model::flattenInlines [dict get $node label]] }
            inline_code { append out [dict get $node value] }
            strong -
            emphasis -
            strike -
            span { append out [mdstack::model::flattenInlines [dict get $node content]] }
            default { }
        }
    }
    return $out
}

proc mdstack::model::validateAst {ast} {
    if {![dict exists $ast type] || [dict get $ast type] ne "document"} {
        error "mdstack::model::new: not a document AST"
    }
    if {![dict exists $ast version] || [dict get $ast version] != 1} {
        error "mdstack::model::new: unsupported AST version"
    }
    if {![dict exists $ast blocks]} {
        error "mdstack::model::new: missing blocks"
    }
    return 1
}
