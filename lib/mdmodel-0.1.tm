# mdmodel-0.1.tm
# (c) 2026 Gregor Ebbing -- MIT License (see LICENSE)
#
# Document model on top of Markdown-AST v1.
#
# Features:
# - headings/toc
# - anchors map (anchor -> heading dict)
# - find (regexp search)
#
package provide mdmodel 0.1

namespace eval mdmodel {
    namespace export new ast toc headings anchors find meta
}

proc mdmodel::new {ast} {
    mdmodel::validateAst $ast

    set headings {}
    set anchors {}

    foreach block [dict get $ast blocks] {
        if {[dict get $block type] eq "heading"} {
            set h [dict create \
                level  [dict get $block level] \
                text   [mdmodel::flattenInlines [dict get $block content]] \
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

proc mdmodel::ast {doc} {
    return [dict get $doc ast]
}

proc mdmodel::headings {doc} {
    return [dict get $doc headings]
}

proc mdmodel::anchors {doc} {
    return [dict get $doc anchors]
}

proc mdmodel::toc {doc} {
    return [dict get $doc headings]
}

proc mdmodel::meta {doc} {
    return [dict get [dict get $doc ast] meta]
}

proc mdmodel::find {doc pattern} {
    set ast [dict get $doc ast]
    set results {}

    foreach block [dict get $ast blocks] {
        set type [dict get $block type]
        switch -- $type {
            heading {
                set text [mdmodel::flattenInlines [dict get $block content]]
            }
            code_block {
                set text [dict get $block text]
            }
            paragraph {
                set text [mdmodel::flattenInlines [dict get $block content]]
            }
            list {
                set text ""
                foreach it [dict get $block items] {
                    set firstBlock [lindex [dict get $it blocks] 0]
                    if {[dict get $firstBlock type] eq "paragraph"} {
                        append text [mdmodel::flattenInlines [dict get $firstBlock content]] "\n"
                    }
                }
            }
            div {
                # Recurse into div blocks
                set text ""
                foreach subBlock [dict get $block blocks] {
                    if {[dict get $subBlock type] eq "paragraph"} {
                        append text [mdmodel::flattenInlines [dict get $subBlock content]] "\n"
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

proc mdmodel::flattenInlines {inlines} {
    set out ""
    foreach node $inlines {
        set t [dict get $node type]
        switch -- $t {
            text { append out [dict get $node value] }
            link { append out [mdmodel::flattenInlines [dict get $node label]] }
            inline_code { append out [dict get $node value] }
            strong -
            emphasis -
            strike -
            span { append out [mdmodel::flattenInlines [dict get $node content]] }
            default { }
        }
    }
    return $out
}

proc mdmodel::validateAst {ast} {
    if {![dict exists $ast type] || [dict get $ast type] ne "document"} {
        error "mdmodel::new: not a document AST"
    }
    if {![dict exists $ast version] || [dict get $ast version] != 1} {
        error "mdmodel::new: unsupported AST version"
    }
    if {![dict exists $ast blocks]} {
        error "mdmodel::new: missing blocks"
    }
    return 1
}
