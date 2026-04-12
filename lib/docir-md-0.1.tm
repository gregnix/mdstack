# docir-md-0.1.tm
# (c) 2026 Gregor Ebbing -- MIT License (see LICENSE)
#
# Mapper: mdparser-0.2 AST  →  DocIR 0.2
#
# Converts the nested mdparser tree into a flat
# DocIR sequence (depth-first, SAX-like).
#
# Namespace: ::docir::md
# Requires:  mdparser 0.2  (for the AST)
# Tcl 8.6+ / 9.x compatible

package provide docir-md 0.1

namespace eval docir::md {}

# ============================================================
# Public API
# ============================================================

# docir::md::fromAst ast
#   Converts an mdparser-AST (document-Root) to DocIR.
#   Returns a flat list of DocIR-Nodes.
proc docir::md::fromAst {ast} {
    if {![dict exists $ast type] || [dict get $ast type] ne "document"} {
        error "docir::md::fromAst: no document-AST"
    }

    set ir {}

    # doc_header from meta (YAML frontmatter)
    set meta [expr {[dict exists $ast meta] ? [dict get $ast meta] : {}}]
    set title [expr {[dict exists $meta title] ? [dict get $meta title] : ""}]
    lappend ir [dict create \
        type    doc_header \
        content {} \
        meta    [dict create \
            name    $title \
            section "" \
            version [expr {[dict exists $meta version] ? [dict get $meta version] : ""}] \
            part    [expr {[dict exists $meta part]    ? [dict get $meta part]    : ""}]]]

    # Process blocks
    set blocks [expr {[dict exists $ast blocks] ? [dict get $ast blocks] : {}}]
    foreach block $blocks {
        set ir [concat $ir [docir::md::_mapBlock $block]]
    }

    return $ir
}

# ============================================================
# Block-Mapping (internal, recursive)
# ============================================================

proc docir::md::_mapBlock {block} {
    set t [dict get $block type]
    switch $t {
        heading      { return [list [docir::md::_mapHeading $block]] }
        paragraph    { return [list [docir::md::_mapParagraph $block]] }
        code_block   { return [list [docir::md::_mapCodeBlock $block]] }
        list         { return [docir::md::_mapList $block] }
        blockquote   { return [docir::md::_mapBlockquote $block] }
        hr           { return [list [dict create type hr content {} meta {}]] }
        div          { return [docir::md::_mapDiv $block] }
        deflist      { return [docir::md::_mapDeflist $block] }
        table        { return [list [docir::md::_mapTable $block]] }
        footnote_section { return [docir::md::_mapFootnoteSection $block] }
        footnote_def { return {} }
        default      {
            # Unknown type: as Paragraph with type hint
            return [list [dict create \
                type    paragraph \
                content [list [dict create type text text "[$t]"]] \
                meta    {class unknown}]]
        }
    }
}

proc docir::md::_mapHeading {block} {
    set level  [dict get $block level]
    set anchor [expr {[dict exists $block anchor] ? [dict get $block anchor] : ""}]
    # content is Inline-list (like paragraph)
    set raw    [expr {[dict exists $block content] ? [dict get $block content] : {}}]
    set inlines [docir::md::_mapInlines $raw]
    return [dict create \
        type    heading \
        content $inlines \
        meta    [dict create level $level id $anchor]]
}

proc docir::md::_mapParagraph {block} {
    set inlines [docir::md::_mapInlines [dict get $block content]]
    return [dict create \
        type    paragraph \
        content $inlines \
        meta    {}]
}

proc docir::md::_mapCodeBlock {block} {
    set lang [expr {[dict exists $block language] ? [dict get $block language] : ""}]
    set text [expr {[dict exists $block text] ? [dict get $block text] : ""}]
    set inlines [list [dict create type text text $text]]
    return [dict create \
        type    pre \
        content $inlines \
        meta    [dict create kind code language $lang]]
}

proc docir::md::_mapList {block} {
    set style [dict get $block style]   ;# unordered | ordered
    set kind  [expr {$style eq "ordered" ? "ol" : "ul"}]
    set items {}

    foreach item [dict get $block items] {
        # list_item has blocks:[] – inline content from first paragraph
        set blocks [dict get $item blocks]
        set descInlines {}
        set restBlocks {}
        if {[llength $blocks] > 0} {
            set first [lindex $blocks 0]
            if {[dict get $first type] eq "paragraph"} {
                set descInlines [docir::md::_mapInlines [dict get $first content]]
                set restBlocks  [lrange $blocks 1 end]
            } else {
                set restBlocks $blocks
            }
        }
        lappend items [dict create \
            type    listItem \
            content $descInlines \
            meta    [dict create kind $kind term {}]]

        # Nested blocks (Sub-lists, Paragraphs) recursively inserted
        # are appended after the Item as additional Nodes
        # (DocIR is flat – no real Parent-Child-Link)
        foreach sub $restBlocks {
            # Sub-lists remain independent list-Nodes
            lappend items {*}[docir::md::_mapBlock $sub]
        }
    }

    return [list [dict create \
        type    list \
        content $items \
        meta    [dict create kind $kind indentLevel 0]]]
}

proc docir::md::_mapBlockquote {block} {
    # Blockquote → paragraph with class=blockquote (DocIR has no own type)
    set ir {}
    foreach sub [dict get $block blocks] {
        set nodes [docir::md::_mapBlock $sub]
        foreach n $nodes {
            # set class=blockquote in meta
            if {[dict exists $n meta]} {
                dict set n meta class blockquote
            }
            lappend ir $n
        }
    }
    return $ir
}

proc docir::md::_mapDiv {block} {
    set cls [expr {[dict exists $block class] ? [dict get $block class] : ""}]
    set ir {}
    foreach sub [dict get $block blocks] {
        set nodes [docir::md::_mapBlock $sub]
        foreach n $nodes {
            if {[dict exists $n meta]} {
                dict set n meta class $cls
            }
            lappend ir $n
        }
    }
    return $ir
}

proc docir::md::_mapDeflist {block} {
    set items {}
    foreach dl [dict get $block items] {
        set term [docir::md::_mapInlines [dict get $dl term]]
        set defs [expr {[dict exists $dl definitions] ? [dict get $dl definitions] : {}}]
        # First definition as desc
        set descInlines {}
        if {[llength $defs] > 0} {
            set firstDef [lindex $defs 0]
            if {[dict exists $firstDef content]} {
                set descInlines [docir::md::_mapInlines [dict get $firstDef content]]
            }
        }
        lappend items [dict create \
            type    listItem \
            content $descInlines \
            meta    [dict create kind dl term $term]]
    }
    return [list [dict create \
        type    list \
        content $items \
        meta    [dict create kind dl indentLevel 0]]]
}

proc docir::md::_mapTable {block} {
    # Table → pre with kind=table (simplified, until DocIR has table type)
    set lines {}
    set header [expr {[dict exists $block header] ? [dict get $block header] : {}}]
    lappend lines [join $header " | "]
    set rows [expr {[dict exists $block rows] ? [dict get $block rows] : {}}]
    foreach row $rows {
        lappend lines [join $row " | "]
    }
    set text [join $lines "\n"]
    return [dict create \
        type    pre \
        content [list [dict create type text text $text]] \
        meta    [dict create kind table]]
}

proc docir::md::_mapFootnoteSection {block} {
    set ir {}
    set fns [expr {[dict exists $block footnotes] ? [dict get $block footnotes] : {}}]
    foreach fn $fns {
        set id  [expr {[dict exists $fn id]  ? [dict get $fn id]  : ""}]
        set num [expr {[dict exists $fn num] ? [dict get $fn num] : ""}]
        set inlines [docir::md::_mapInlines \
            [expr {[dict exists $fn content] ? [dict get $fn content] : {}}]]
        # As paragraph with footnote prefix
        set prefix [dict create type text text "\[$num\] "]
        lappend ir [dict create \
            type    paragraph \
            content [concat [list $prefix] $inlines] \
            meta    [dict create class footnote id $id]]
    }
    return $ir
}

# ============================================================
# Inline-Mapping
# ============================================================
# mdparser-Inlines: {type text value "..."}, {type strong content [...]},
# {type emphasis content [...]}, {type link label [...] url "..."},
# {type image alt "..." url "..."}, {type linebreak}, {type code value "..."},
# {type footnote_ref id "..."}, {type emoji ...}

proc docir::md::_mapInlines {inlines} {
    set result {}
    foreach inline $inlines {
        set t [dict get $inline type]
        switch $t {
            text {
                set v [expr {[dict exists $inline value] ? [dict get $inline value] : ""}]
                lappend result [dict create type text text $v]
            }
            strong {
                set inner [docir::md::_mapInlines \
                    [expr {[dict exists $inline content] ? [dict get $inline content] : {}}]]
                foreach i $inner {
                    lappend result [dict create type strong text [_inlineText $i]]
                }
            }
            emphasis {
                set inner [docir::md::_mapInlines \
                    [expr {[dict exists $inline content] ? [dict get $inline content] : {}}]]
                foreach i $inner {
                    lappend result [dict create type emphasis text [_inlineText $i]]
                }
            }
            code -
            inline_code {
                set v [expr {[dict exists $inline value] ? [dict get $inline value] : ""}]
                lappend result [dict create type code text $v]
            }
            link {
                set url   [expr {[dict exists $inline url]   ? [dict get $inline url]   : ""}]
                set label [expr {[dict exists $inline label] ? [dict get $inline label] : {}}]
                set txt   [docir::md::_inlinesToText $label]
                lappend result [dict create type link text $txt name "" section "" href $url]
            }
            image {
                set alt [expr {[dict exists $inline alt] ? [dict get $inline alt] : ""}]
                set url [expr {[dict exists $inline url] ? [dict get $inline url] : ""}]
                lappend result [dict create type text text "\[img: $alt\]"]
            }
            linebreak {
                lappend result [dict create type text text "\n"]
            }
            footnote_ref {
                set id [expr {[dict exists $inline id] ? [dict get $inline id] : ""}]
                lappend result [dict create type text text "\[$id\]"]
            }
            default {
                # emoji, unbekannte Typen
                set v [expr {[dict exists $inline value] ? [dict get $inline value] : "[$t]"}]
                lappend result [dict create type text text $v]
            }
        }
    }
    return $result
}

# Helper: Extract text from a single DocIR-Inline
proc docir::md::_inlineText {inline} {
    if {[dict exists $inline text]} { return [dict get $inline text] }
    return ""
}

# Helper: All Inlines → plain text (for link-labels etc.)
proc docir::md::_inlinesToText {inlines} {
    set out ""
    foreach i $inlines {
        if {[dict exists $i value]} { append out [dict get $i value] }
        if {[dict exists $i content]} {
            append out [docir::md::_inlinesToText [dict get $i content]]
        }
    }
    return $out
}
